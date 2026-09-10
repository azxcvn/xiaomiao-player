import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/services/file_operations_service.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/utils/file_ops.dart';
import 'package:moumou/utils/formatters.dart';

/// 文件管理统一 UI：长按动作菜单（固定/复制/移动/重命名/删除）+ 重命名弹窗 +
/// 删除确认弹窗（默认只删视频，「删除所有文件」为可选勾选）+ 传输进度弹窗。
///
/// 工作.md 定稿：**固定（置顶）与四个文件动作放在同一个长按菜单里**——
/// 文件夹长按出五项（固定/取消固定 + 复制/移动/重命名/删除），
/// 视频长按出四项（视频没有「固定」概念）。
///
/// 删除文件夹的默认语义是**只删文件夹内的视频文件**，弹窗只给一句话说明 +
/// 一个默认不勾的「删除所有文件」；勾上才递归删除整个文件夹。

/// 统一的文件管理动作
enum FileAction { pin, copy, move, rename, delete }

/// 弹出长按动作菜单；返回用户选择（点空白关闭返回 null）。
///
/// 文件夹入口与视频入口**共用本函数**：菜单项顺序一致，仅文件夹多一项
/// [FileAction.pin]（文案随 [isPinned] 在「固定」/「取消固定」间切换）。
///
/// 不显示标题行（长按的卡片就在用户眼前，标题属冗余，且会挤掉菜单高度）；
/// 内容用 `ListView` 承载 + `isScrollControlled`：矮屏（可用高度 < 五项自然高度）
/// 或大字号时不会 RenderFlex 溢出，超出部分可滚动。
Future<FileAction?> showFileActionMenu(
  BuildContext context, {
  required bool isDirectory,
  bool isPinned = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<FileAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            if (isDirectory)
              _tile(context, scheme, isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  isPinned ? '取消固定' : '固定', FileAction.pin),
            _tile(context, scheme, Icons.copy_all_outlined, '复制', FileAction.copy),
            _tile(context, scheme, Icons.drive_file_move_outline, '移动',
                FileAction.move),
            _tile(context, scheme, Icons.drive_file_rename_outline, '重命名',
                FileAction.rename),
            _tile(context, scheme, Icons.delete_outline, '删除', FileAction.delete,
                destructive: true),
          ],
        ),
      );
    },
  );
}

Widget _tile(
  BuildContext context,
  ColorScheme scheme,
  IconData icon,
  String label,
  FileAction action, {
  bool destructive = false,
}) {
  final color = destructive ? scheme.error : null;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color)),
    onTap: () => Navigator.of(context).pop(action),
  );
}

/// 重命名弹窗：返回用户输入的**新名字**（取消返回 null）。
///
/// - [originalName] 传当前名字：视频/文件会**锁死扩展名**——输入框预填主体
///   （`123.mp4` → 只填 `123`）、右侧固定显示 `.mp4`，用户只能改扩展名之前的文本；
/// - [isDirectory] 为 true 时不锁扩展名（文件夹名允许带点），预填完整名字；
/// - 名字合法性实时校验（空 / 路径分隔符 / 非法字符 / 主体为空），不合法时
///   确认按钮置灰并显示原因。
Future<String?> showRenameDialog(
  BuildContext context, {
  required String originalName,
  bool isDirectory = false,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(
      originalName: originalName,
      isDirectory: isDirectory,
    ),
  );
}

class _RenameDialog extends StatefulWidget {
  final String originalName;
  final bool isDirectory;

  const _RenameDialog({
    required this.originalName,
    required this.isDirectory,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  /// 文件：锁死的扩展名（含点，小写；无扩展名为空串）
  late final String _lockedExt = widget.isDirectory
      ? ''
      : FileOps.extensionOf(widget.originalName);

  late final TextEditingController _controller = TextEditingController(
    text: FileOps.renameInitialInput(
      currentName: widget.originalName,
      isDirectory: widget.isDirectory,
    ),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final check = FileOps.validateRenameInput(
      value,
      originalExtension: _lockedExt,
    );
    setState(() => _error = check.ok ? null : check.error);
  }

  void _submit() {
    final check = FileOps.validateRenameInput(
      _controller.text,
      originalExtension: _lockedExt,
    );
    if (!check.ok) {
      setState(() => _error = check.error);
      return;
    }
    // 交给调用方拼最终文件名（扩展名由 FileOps.renameTargetName 保证不变）
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('重命名'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: _onChanged,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: '新名称',
          hintText: '扩展名之前的名称',
          helperText: _lockedExt.isEmpty ? null : '扩展名固定为 $_lockedExt，不可修改',
          helperStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          suffixText: _lockedExt.isEmpty ? null : _lockedExt,
          suffixStyle: const TextStyle(fontWeight: FontWeight.w600),
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _error == null ? _submit : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 删除确认结果
class DeleteConfirmResult {
  /// 是否确认删除
  final bool confirmed;

  /// 仅文件夹有意义：true = 删除文件夹内**所有文件**（递归整目录）；
  /// false（默认）= 只删除文件夹内的视频文件，保留其它文件与文件夹本身
  final bool deleteAllFiles;

  const DeleteConfirmResult({
    required this.confirmed,
    this.deleteAllFiles = false,
  });
}

/// 删除确认弹窗。
///
/// 文件夹：默认语义是**只删视频文件**，用一句正文说清 + 一个默认不勾的
/// 「删除所有文件」勾选框（勾上 = 整个文件夹连同其它文件一起删）。
/// 视频：只有一句确认，没有勾选框。
Future<DeleteConfirmResult?> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required bool isDirectory,
}) {
  return showAppDialog<DeleteConfirmResult>(
    context: context,
    builder: (_) => _DeleteConfirmDialog(
      title: title,
      isDirectory: isDirectory,
    ),
  );
}

class _DeleteConfirmDialog extends StatefulWidget {
  final String title;
  final bool isDirectory;

  const _DeleteConfirmDialog({
    required this.title,
    required this.isDirectory,
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _deleteAll = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('删除'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isDirectory)
            const Text('仅删除该文件夹内的视频文件，其它文件不会被删除。')
          else
            Text('确定删除「${widget.title}」吗？'),
          if (widget.isDirectory)
            CheckboxListTile(
              value: _deleteAll,
              onChanged: (v) => setState(() => _deleteAll = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('删除所有文件'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const DeleteConfirmResult(confirmed: false),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: () => Navigator.of(context).pop(
            DeleteConfirmResult(
              confirmed: true,
              deleteAllFiles: widget.isDirectory && _deleteAll,
            ),
          ),
          child: const Text('删除'),
        ),
      ],
    );
  }
}

/// 传输进度弹窗（复制 / 移动）：阻塞式（点遮罩不关闭），完成后由调用方 pop。
///
/// 用 [ValueNotifier] 局部刷新进度，避免每块数据都重建整个弹窗树。
class FileOpProgressDialog extends StatelessWidget {
  final String title;
  final ValueNotifier<FileOpProgress> progress;
  final VoidCallback onCancel;

  const FileOpProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<FileOpProgress>(
        valueListenable: progress,
        builder: (context, value, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: value.bytesTotal > 0 ? value.fraction : null,
              ),
              const SizedBox(height: 12),
              Text(
                value.currentName.isEmpty ? '准备中…' : value.currentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _describe(value),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('取消')),
      ],
    );
  }

  static String _describe(FileOpProgress p) {
    if (p.bytesTotal > 0) {
      return '${formatFileSize(p.bytesDone)} / ${formatFileSize(p.bytesTotal)}'
          '（${(p.fraction * 100).toStringAsFixed(0)}%）';
    }
    if (p.itemsTotal > 0) {
      return '${p.itemsDone} / ${p.itemsTotal} 项';
    }
    return '处理中…';
  }
}
