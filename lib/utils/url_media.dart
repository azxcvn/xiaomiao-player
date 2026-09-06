/// 在线媒体链接纯函数（工作.md：打开链接播放功能）：
/// URL 规范化 / 可播放协议判定 / 从 URL 提取展示标题。
/// 参考 mpvRx `HttpUtils.isNetworkStream / extractFilenameFromUrl`。
library;

/// mpv 支持的流媒体协议（判定「可作为媒体链接播放」的白名单）
const Set<String> kPlayableUrlSchemes = {
  'http',
  'https',
  'rtmp',
  'rtmps',
  'rtsp',
  'rtsps',
  'rtp',
  'mms',
  'mmst',
  'mmsh',
  'ftp',
  'ftps',
};

/// 规范化用户输入的链接：
/// - 去首尾空白；含内部空白（非 URL 形态，如自然语言）返回 null；
/// - 裸域名（无 scheme）自动补 `https://`（用户常只粘贴 `example.com/a.mp4`）；
///   已带 `scheme:` 形态（mailto:/content: 等）不补——补出来会把 scheme 错位
///   成 userinfo，交给 [isPlayableMediaUrl] 的白名单判定为非法；
/// - 解析失败 / 无 host 返回 null。
String? normalizeMediaUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  // URL 不含原始空白（自然语言/半截句子直接判非法）
  if (s.contains(RegExp(r'\s'))) return null;
  if (!s.contains('://')) {
    final colon = s.indexOf(':');
    final slash = s.indexOf('/');
    final hasScheme = colon > 0 && (slash < 0 || colon < slash);
    if (!hasScheme) {
      s = 'https://$s';
    }
  }
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return null;
  return s;
}

/// 判定是否为可播放的媒体链接（scheme 白名单 + 非空 host）
bool isPlayableMediaUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  return kPlayableUrlSchemes.contains(uri.scheme.toLowerCase());
}

/// 从 URL 提取展示标题：取最后一段非空路径（去掉 query/fragment、
/// 百分号解码）；路径为空时回退 host；再兜底整个 URL。
String mediaTitleFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty) {
    var name = segments.last;
    try {
      name = Uri.decodeComponent(name);
    } catch (_) {
      // 非法百分号序列：保留原文
    }
    if (name.trim().isNotEmpty) return name;
  }
  if (uri.host.isNotEmpty) return uri.host;
  return url;
}
