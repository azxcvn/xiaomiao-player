import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:moumou/models/update_info.dart';
import 'package:moumou/services/update/update_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// 更新弹窗动作（底部三按钮）
enum _UpdateAction { ignore, remindLater, update }

/// 下载方式（主 / 备用下载站）
enum _DownloadSource { primary, backup }

/// 显示更新弹窗（工作.md：更新功能）。
///
/// 布局：固定尺寸弹窗，标题 + 可滚动 Markdown 更新内容 + 底部三按钮
/// （忽略本版本 / 稍后提醒 / 立即更新）。点「立即更新」弹出子菜单选择
/// 主下载站 / 备用下载站（链接待接入时 Toast 提示）。
Future<void> showUpdateDialog(
  BuildContext context, {
  required UpdateInfo info,
  required UpdateSettings settings,
}) async {
  final action = await showAppDialog<_UpdateAction>(
    context: context,
    builder: (_) => UpdateDialog(info: info),
  );
  if (action == null) return;
  if (!context.mounted) return;
  switch (action) {
    case _UpdateAction.ignore:
      await settings.ignoreVersion(info.version);
      break;
    case _UpdateAction.update:
      await _chooseDownloadSource(context, info);
      break;
    case _UpdateAction.remindLater:
      break;
  }
}

/// 「立即更新」子菜单：选择主 / 备用下载站
Future<void> _chooseDownloadSource(BuildContext context, UpdateInfo info) async {
  final source = await showAppDialog<_DownloadSource>(
    context: context,
    builder: (_) => _DownloadSourceDialog(info: info),
  );
  if (source == null || !context.mounted) return;
  _openDownloadSource(context, source, info);
}

/// 打开下载站链接（待接入时 Toast 提示）
Future<void> _openDownloadSource(
  BuildContext context,
  _DownloadSource source,
  UpdateInfo info,
) async {
  final isPrimary = source == _DownloadSource.primary;
  final url = isPrimary ? info.primaryDownloadUrl : info.backupDownloadUrl;
  final label = isPrimary ? '主下载站' : '备用下载站';
  if (url.isEmpty) {
    _toast(context, '$label链接待接入');
    return;
  }
  final uri = Uri.parse(url);
  final canLaunch = await canLaunchUrl(uri);
  if (!context.mounted) return;
  if (canLaunch) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    _toast(context, '无法打开$label链接');
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// 更新弹窗内容：固定尺寸 + 可滚动 Markdown + 三按钮。
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  /// 忽略本版本按钮（测试定位用）
  static const ignoreButtonKey = Key('updateIgnoreButton');

  /// 稍后提醒按钮（测试定位用）
  static const remindButtonKey = Key('updateRemindButton');

  /// 立即更新按钮（测试定位用）
  static const updateButtonKey = Key('updateUpdateButton');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markdownStyle = MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(
          p: TextStyle(fontSize: 14, height: 1.6, color: scheme.onSurface),
          h2: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          h3: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          listBullet: TextStyle(fontSize: 14, color: scheme.onSurface),
          blockquoteDecoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          blockquotePadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                '发现新版本 ${info.version}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            // Markdown 更新内容（可滚动，按钮固定在外）
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: MarkdownBody(data: info.body, styleSheet: markdownStyle),
              ),
            ),
            const Divider(height: 1),
            // 底部三按钮：忽略 / 稍后提醒 / 立即更新
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: UpdateDialog.ignoreButtonKey,
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.ignore),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('忽略'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextButton(
                      key: UpdateDialog.remindButtonKey,
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.remindLater),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('稍后提醒'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      key: UpdateDialog.updateButtonKey,
                      onPressed: () =>
                          Navigator.of(context).pop(_UpdateAction.update),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('立即更新'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 下载方式子菜单（主 / 备用下载站）
class _DownloadSourceDialog extends StatelessWidget {
  const _DownloadSourceDialog({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择下载方式'),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sourceTile(
            context,
            icon: Icons.cloud_download_outlined,
            title: '主下载站',
            url: info.primaryDownloadUrl,
            source: _DownloadSource.primary,
          ),
          _sourceTile(
            context,
            icon: Icons.cloud_queue_outlined,
            title: '备用下载站',
            url: info.backupDownloadUrl,
            source: _DownloadSource.backup,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  Widget _sourceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String url,
    required _DownloadSource source,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        url.isEmpty ? '待接入' : url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}
