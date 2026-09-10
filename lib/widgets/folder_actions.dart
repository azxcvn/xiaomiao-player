import 'package:flutter/material.dart';
import 'package:moumou/services/file_operations_service.dart';
import 'package:moumou/services/pinned_folders_settings.dart';
import 'package:moumou/utils/file_ops.dart';
import 'package:moumou/utils/file_selection.dart';
import 'package:moumou/widgets/directory_picker_dialog.dart';
import 'package:moumou/widgets/file_operations_ui.dart';

/// 文件管理动作编排：把「长按菜单 → 弹窗 → 服务 → 刷新」串成一个入口。
///
/// 首页列表视图、树状视图一级界面、树状目录页、列表模式文件夹详情页
/// **共用本函数**，保证菜单项（固定/复制/移动/重命名/删除/多选）在各页面行为一致。
///
/// [onMutated] 由调用方提供**本地刷新**逻辑（重扫目录树、重建当前页数据）；
/// 返回 true 表示「当前页展示的对象已被重命名或删除，调用方需要自行退出该页」。
///
/// [onMultiSelect] 在用户选了「多选」时回调（调用方据此进入多选态并选中长按项）。
Future<bool> showFileManagementFlow(
  BuildContext context, {
  required String title,
  required bool isDirectory,
  required String sourcePath,
  required Future<void> Function() onMutated,
  VoidCallback? onMultiSelect,
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
    case FileAction.multiSelect:
      onMultiSelect?.call();
      return false;
  }
}

/// 多选批量入口：对**已选中的 N 项**弹出与长按同一个菜单，再串行执行。
///
/// [items] 由调用方按当前选中顺序给出（`utils/file_selection.dart` 负责索引与取值）。
///
/// 返回 true 表示**真的执行了批量操作**（调用方应退出多选态）；
/// 用户只是关掉菜单 / 取消了目标目录 / 取消了删除确认 → 返回 false（留在多选态）。
///
/// 与单选入口的差异（用户定稿）：
/// - 菜单撤掉「重命名」（一次只能改一个名字）；
/// - 「固定」仅在**选中项全是文件夹**时出现（`isDirectory` 传全集判定结果）；
/// - 删除沿用同一个确认弹窗：默认只删文件夹内的视频，勾「删除所有文件」对全部
///   选中文件夹一次性生效；
/// - 批量传输逐项**预校验**，任一项目标非法就整体中止（不会「搬了一半才发现」）；
/// - 单项失败**不中断整批**，最后汇总提示（一把文件里有一个被占用不该连累其它）。
Future<bool> showBatchFileManagementFlow(
  BuildContext context, {
  required List<FileSelectionItem> items,
  required Future<void> Function() onMutated,
}) async {
  if (items.isEmpty) return false;

  final pinned = PinnedFoldersSettings.instance;
  final allFolders = items.every((e) => e.isDirectory);
  final allPinned = allFolders && items.every((e) => pinned.isPinned(e.path));

  final action = await showFileActionMenu(
    context,
    isDirectory: allFolders,
    isPinned: allPinned,
    selectionCount: items.length,
  );
  if (action == null || !context.mounted) return false;

  switch (action) {
    case FileAction.pin:
      await pinned.setPinnedAll(items.map((e) => e.path), pinned: !allPinned);
      // 固定只改展示顺序：**不退出多选**，方便连续固定多个文件夹
      return false;
    case FileAction.copy:
      return _batchTransfer(context, items, onMutated, move: false);
    case FileAction.move:
      return _batchTransfer(context, items, onMutated, move: true);
    case FileAction.delete:
      return _batchDelete(context, items, onMutated);
    case FileAction.rename:
    case FileAction.multiSelect:
      // 多选菜单不会给出这两项（见 showFileActionMenu），兜底忽略
      return false;
  }
}

Future<void> _notify(BuildContext context, String message) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 传输进度弹窗的显示 / 关闭句柄。
///
/// **必须保证只 pop 一次**：曾经在 `onCancel` 里 `dialog.pop()`，传输循环随后
/// 抛「已取消」进入 `finally` 又 pop 一次 —— 第二次 pop 掉的是**页面本身**
/// （详情页 / 目录页被直接退出）。
///
/// [dispose] 与 [dismiss] 分开：取消时弹窗立刻关掉，但传输循环可能还有一次
/// 在途进度回调，此时写已释放的 [ValueNotifier] 会触发调试断言；
/// 因此通知器只在循环彻底结束后由调用方释放。
class _ProgressHandle {
  final FileOpCancelToken token = FileOpCancelToken();
  final ValueNotifier<FileOpProgress> progress =
      ValueNotifier<FileOpProgress>(FileOpProgress.idle);

  NavigatorState? _navigator;
  bool _open = false;
  bool _disposed = false;

  /// 弹出进度弹窗并返回句柄
  static _ProgressHandle show(BuildContext context, String title) {
    final handle = _ProgressHandle();
    final navigator = Navigator.of(context, rootNavigator: true);
    handle._navigator = navigator;
    handle._open = true;
    navigator.push(
      DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FileOpProgressDialog(
          title: title,
          progress: handle.progress,
          onCancel: () {
            handle.token.cancel();
            handle.dismiss();
          },
        ),
      ),
    );
    return handle;
  }

  /// 汇报进度（释放后静默忽略，兼容「已取消」的竞态）
  void report(FileOpProgress p) {
    if (_disposed) return;
    progress.value = p;
  }

  /// 关闭弹窗（重复调用安全）
  void dismiss() {
    if (!_open) return;
    _open = false;
    _navigator?.pop();
  }

  /// 释放进度通知器（调用方在传输循环结束后调用）
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    progress.dispose();
  }
}

/// 把单项传输进度映射成批量进度：条目数换成「整批第几项」，字节数仍是当前项。
FileOpProgress _asBatch(
  FileOpProgress p,
  int index,
  int total,
  String name,
) {
  return FileOpProgress(
    currentName: name,
    bytesDone: p.bytesDone,
    bytesTotal: p.bytesTotal,
    itemsDone: index,
    itemsTotal: total,
  );
}

/// 批量结果汇总：失败项 ≤ 3 全部列出，超出只列前 3 条并给出剩余数量
String _batchSummary({
  required String verb,
  required int done,
  required int total,
  required List<String> failures,
}) {
  final head = '已$verb $done/$total 项';
  if (failures.length <= 3) return '$head，失败：${failures.join('；')}';
  return '$head，失败：${failures.take(3).join('；')} 等 ${failures.length} 项';
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

  final handle = _ProgressHandle.show(context, move ? '正在移动…' : '正在复制…');
  String? failure;
  String? target;
  try {
    target = move
        ? await FileOperationsService.move(
            sourcePath,
            destination,
            cancelToken: handle.token,
            onProgress: handle.report,
          )
        : await FileOperationsService.copy(
            sourcePath,
            destination,
            cancelToken: handle.token,
            onProgress: handle.report,
          );
  } on FileOpException catch (e) {
    failure = e.message;
  } catch (e) {
    failure = '$e';
  } finally {
    handle.dismiss();
    handle.dispose();
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

/// 批量复制 / 移动：目标目录选一次，逐项串行执行，单项失败不中断整批。
Future<bool> _batchTransfer(
  BuildContext context,
  List<FileSelectionItem> items,
  Future<void> Function() onMutated, {
  required bool move,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 120));
  if (!context.mounted) return false;

  final destination = await showDirectoryPickerDialog(context);
  if (destination == null || !context.mounted) return false;

  // 逐项预校验：任一项不合法就整体中止（避免「搬了一半才发现目标非法」）
  for (final item in items) {
    final invalid = FileOps.validateMoveTarget(
      sourcePath: item.path,
      sourceIsDirectory: item.isDirectory,
      destinationDir: destination,
    );
    if (invalid != null) {
      if (!context.mounted) return false;
      await _notify(context, '「${item.name}」$invalid');
      return false;
    }
  }

  final verb = move ? '移动' : '复制';
  final handle = _ProgressHandle.show(context, move ? '正在移动…' : '正在复制…');
  final failures = <String>[];
  var done = 0;
  try {
    for (var i = 0; i < items.length; i++) {
      if (handle.token.isCancelled) break;
      final item = items[i];
      handle.report(FileOpProgress(
        currentName: item.name,
        bytesDone: 0,
        bytesTotal: 0,
        itemsDone: i,
        itemsTotal: items.length,
      ));
      try {
        if (move) {
          await FileOperationsService.move(
            item.path,
            destination,
            cancelToken: handle.token,
            onProgress: (p) => handle.report(_asBatch(p, i, items.length, item.name)),
          );
        } else {
          await FileOperationsService.copy(
            item.path,
            destination,
            cancelToken: handle.token,
            onProgress: (p) => handle.report(_asBatch(p, i, items.length, item.name)),
          );
        }
        done++;
      } on FileOpException catch (e) {
        if (e.message == '已取消') break;
        failures.add('${item.name}：${e.message}');
      } catch (e) {
        failures.add('${item.name}：$e');
      }
    }
  } finally {
    handle.dismiss();
    handle.dispose();
  }

  final cancelled = handle.token.isCancelled;
  if (done == 0 && failures.isEmpty) {
    // 一项都没做成（用户一开始就取消）
    if (!context.mounted) return false;
    await _notify(context, '已取消');
    return false;
  }

  await PinnedFoldersSettings.instance.retainExisting();
  await onMutated();
  if (!context.mounted) return true;

  if (failures.isEmpty) {
    if (cancelled && done < items.length) {
      await _notify(context, '已取消（已$verb $done 项）');
    } else {
      await _notify(
        context,
        '已$verb $done 项到 ${FileOps.baseName(destination)}',
      );
    }
    return true;
  }
  await _notify(
    context,
    _batchSummary(
      verb: verb,
      done: done,
      total: items.length,
      failures: failures,
    ),
  );
  return true;
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

/// 批量删除：确认一次、串行删除，单项失败不中断整批。
Future<bool> _batchDelete(
  BuildContext context,
  List<FileSelectionItem> items,
  Future<void> Function() onMutated,
) async {
  final folderCount = items.where((e) => e.isDirectory).length;
  final onlyOne = items.length == 1;
  final confirm = await showDeleteConfirmDialog(
    context,
    title: onlyOne ? items.first.name : '',
    isDirectory: onlyOne && items.first.isDirectory,
    itemCount: items.length,
    folderCount: folderCount,
  );
  if (confirm == null || !confirm.confirmed || !context.mounted) return false;

  final failures = <String>[];
  var done = 0;
  for (final item in items) {
    try {
      if (item.isDirectory) {
        await FileOperationsService.deleteFolder(
          item.path,
          deleteWholeFolder: confirm.deleteAllFiles,
        );
      } else {
        await FileOperationsService.deleteFile(item.path);
      }
      done++;
    } on FileOpException catch (e) {
      failures.add('${item.name}：${e.message}');
    } catch (e) {
      failures.add('${item.name}：$e');
    }
  }

  await PinnedFoldersSettings.instance.retainExisting();
  await onMutated();
  if (!context.mounted) return true;

  if (failures.isEmpty) {
    await _notify(context, onlyOne ? '已删除「${items.first.name}」' : '已删除 $done 项');
  } else {
    await _notify(
      context,
      _batchSummary(
        verb: '删除',
        done: done,
        total: items.length,
        failures: failures,
      ),
    );
  }
  return true;
}
