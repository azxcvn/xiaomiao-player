import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/utils/url_media.dart';

/// 「打开链接」弹窗（工作.md：链接播放功能）：输入在线视频直链 → 确认播放。
///
/// - 入口：首页右下角速拨 FAB 第二项「打开链接」（参考 mpvRx 的链接播放）；
/// - 粘贴按钮读取剪贴板（从其他 App 复制播放地址后一键填入）；
/// - 校验：[normalizeMediaUrl] 规范化 + [isPlayableMediaUrl] 协议白名单
///   （http/https/rtmp/rtsp/mms 等 mpv 支持的流媒体协议），非法输入行内
///   提示不关弹窗；
/// - 确认后回调规范化 URL，由调用方 push 播放页（在线直链的章节信息由
///   mpv 解封装远程容器原生读取，无需额外解析）。
Future<void> showOpenLinkDialog(
  BuildContext context, {
  required void Function(String url) onPlay,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => _OpenLinkDialog(onPlay: onPlay),
  );
}

class _OpenLinkDialog extends StatefulWidget {
  final void Function(String url) onPlay;

  const _OpenLinkDialog({required this.onPlay});

  @override
  State<_OpenLinkDialog> createState() => _OpenLinkDialogState();
}

class _OpenLinkDialogState extends State<_OpenLinkDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 粘贴剪贴板内容到输入框（复制播放地址后一键填入）
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _errorText = '剪贴板为空');
      return;
    }
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      _errorText = null;
    });
  }

  void _confirm() {
    final normalized = normalizeMediaUrl(_controller.text);
    if (normalized == null || !isPlayableMediaUrl(normalized)) {
      setState(
        () => _errorText = '链接无效，支持 http/https/rtmp/rtsp 等流媒体协议',
      );
      return;
    }
    // ⚠️ 必须先 pop 弹窗再回调：Navigator.pop() 弹的是**栈顶**路由——
    // 若先回调（push 播放页）再 pop，被弹掉的是刚 push 的播放页，
    // 表现为「点播放毫无反应」（历史 bug，所有链接都中招，非 m3u8 特有）。
    Navigator.of(context).pop();
    widget.onPlay(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('打开链接'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('输入视频直链，将在线播放'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.url,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'https://example.com/video.mp4',
              errorText: _errorText,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: '粘贴',
                onPressed: _pasteFromClipboard,
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('播放'),
        ),
      ],
    );
  }
}
