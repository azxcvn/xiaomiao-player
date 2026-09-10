import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/services/file_operations_service.dart';
import 'package:moumou/services/pinned_folders_settings.dart';
import 'package:moumou/utils/file_ops.dart';
import 'package:moumou/widgets/directory_picker_dialog.dart';
import 'package:moumou/widgets/file_operations_ui.dart';

/// 文件管理动作编排：把「长按菜单 → 弹窗 → 服务 → 刷新」串成一个入口。
///
/// 首页列表视图、树状视图一级界面、树状目录页、列表模式文件夹详情页
/// **共用本函数**，保证菜单项（固定/复制/移动/重命名/删除）在各页面行为一致。
///
/// [onMutated] 由调用方提供**本地刷新**逻辑（重扫目录树、重建当前页数据）；
/// 返回 true 表示「当前页展示的对象已被重命名或删除，调用方需要自行退出该页」。
Future<bool> showFileManagementFlow(
  BuildContext context, {
  required String title,
  required bool isDirectory,
  required String sourcePath,
  required Future<void> Function() onMutated,
}) async {
  final pinned = PinnedFoldersSettings.instance;
  final action = await showFileActionMenu(
    context,
    isDirectory: isDirectory,
    isPinned: isDirectory && pinned.isPinned(sourcePath),
  );
  if (action == null || !context.mounted) return false;

  switch (action) {
    // 固定只影响展示顺序（列表稳定前置），不动磁盘、不需要刷新目录
    case FileAction.pin:
      await pinned.toggle(sourcePath);
      return false;
    case FileAction.copy:
      return _transfer(context, title, isDirectory, sourcePath, onMutated,
          move: false);
    case FileAction.move:
      return _transfer(context, title, isDirectory, sourcePath, onMutated,
          move: true);
    case FileAction.rename:
      return _rename(context, title, isDirectory, sourcePath, onMutated);
    case FileAction.delete:
      return _delete(context, title, isDirectory, sourcePath, onMutated);
  }
}

Future<void> _notify(BuildContext context, String message) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 进度回调（服务层 `onProgress` → 弹窗 `ValueNotifier`）
void _onProgress(ValueNotifier<FileOpProgress> notifier, FileOpProgress p) {
  notifier.value = p;
}

// ───────────────────────── 复制 / 移动 ─────────────────────────

Future<bool> _transfer(
  BuildContext context,
  String title,
  bool isDirectory,
  String sourcePath,
  Future<void> Function() onMutated, {
  required bool move,
}) async {
  // 撤销长按留下的按压高亮，避免「弹窗已关、卡片仍发灰」
  await Future<void>.delayed(const Duration(milliseconds: 120));
  if (!context.mounted) return false;

  final destination = await showDirectoryPickerDialog(context);
  if (destination == null || !context.mounted) return false;

  final invalid = FileOps.validateMoveTarget(
    sourcePath: sourcePath,
    sourceIsDirectory: isDirectory,
    destinationDir: destination,
  );
  if (invalid != null) {
    await _notify(context, invalid);
    return false;
  }

  final token = FileOpCancelToken();
  final progress = ValueNotifier<FileOpProgress>(FileOpProgress.idle);
  final dialog = Navigator.of(context, rootNavigator: true);
  dialog.push(
    DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FileOpProgressDialog(
        title: move ? '正在移动…' : '正在复制…',
        progress: progress,
        onCancel: () {
          token.cancel();
          dialog.pop();
        },
      ),
    ),
  );

  String? failure;
  String? target;
  try {
    target = move
        ? await FileOperationsService.move(
            sourcePath,
            destination,
            cancelToken: token,
            onProgress: (p) => _onProgress(progress, p),
          )
        : await FileOperationsService.copy(
            sourcePath,
            destination,
            cancelToken: token,
            onProgress: (p) => _onProgress(progress, p),
          );
  } on FileOpException catch (e) {
    failure = e.message;
  } catch (e) {
    failure = '$e';
  } finally {
    progress.dispose();
    dialog.pop();
  }

  if (failure == '已取消') {
    if (!context.mounted) return false;
    await _notify(context, '已取消');
    return false;
  }
  if (failure != null) {
    if (!context.mounted) return false;
    await _notify(context, failure);
    return false;
  }

  await PinnedFoldersSettings.instance.retainExisting();
  await onMutated();
  if (!context.mounted) return false;
  final targetName = target == null ? '' : '：${FileOps.baseName(target)}';
  await _notify(
    context,
    move
        ? '已移动「$title」到 ${FileOps.baseName(destination)}$targetName'
        : '已复制「$title」到 ${FileOps.baseName(destination)}$targetName',
  );
  return false;
}

// ───────────────────────── 重命名 ─────────────────────────

Future<bool> _rename(
  BuildContext context,
  String title,
  bool isDirectory,
  String sourcePath,
  Future<void> Function() onMutated,
) async {
  final input = await showRenameDialog(
    context,
    originalName: title,
    isDirectory: isDirectory,
  );
  if (input == null || !context.mounted) return false;

  // 视频/文件的扩展名锁死：输入框只给主体，这里拼回原扩展名
  final newName = FileOps.renameTargetName(
    input: input,
    originalName: title,
    isDirectory: isDirectory,
  );
  if (newName == title) {
    await _notify(context, '名称没有变化');
    return false;
  }

  final pinned = PinnedFoldersSettings.instance;
  // 固定状态必须在清理前读取：retainExisting 会把旧路径从集合里摘掉
  final wasPinned = isDirectory && pinned.isPinned(sourcePath);
  try {
    final newPath = await FileOperationsService.rename(sourcePath, newName);
    if (isDirectory) {
      // 旧路径（及其子孙）的固定记录已失效；新路径沿用「原来是固定的」意图
      final stale = FileOps.stalePinnedPaths(
        oldPath: sourcePath,
        pinnedPaths: pinned.paths,
        includeDescendants: true,
      );
      await pinned.retainExisting(additionalStale: stale);
      if (wasPinned) await pinned.setPinned(newPath, true);
    }
    await onMutated();
    if (!context.mounted) return true;
    await _notify(context, '已重命名为 $newName');
    return true;
  } on FileOpException catch (e) {
    if (!context.mounted) return false;
    await _notify(context, e.message);
    return false;
  }
}

// ───────────────────────── 删除 ─────────────────────────

Future<bool> _delete(
  BuildContext context,
  String title,
  bool isDirectory,
  String sourcePath,
  Future<void> Function() onMutated,
) async {
  final confirm = await showDeleteConfirmDialog(
    context,
    title: title,
    isDirectory: isDirectory,
  );
  if (confirm == null || !confirm.confirmed || !context.mounted) return false;

  try {
    if (isDirectory) {
      await FileOperationsService.deleteFolder(
        sourcePath,
        deleteWholeFolder: confirm.deleteAllFiles,
      );
    } else {
      await FileOperationsService.deleteFile(sourcePath);
    }
    await PinnedFoldersSettings.instance.retainExisting();
    await onMutated();
    if (!context.mounted) return true;
    await _notify(context, '已删除「$title」');
    return true;
  } on FileOpException catch (e) {
    if (!context.mounted) return false;
    await _notify(context, e.message);
    return false;
  }
}
