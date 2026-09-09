/// B 站分享短链展开（b23.tv 等）纯工具。
///
/// 分享出来的短链（如 `https://b23.tv/NkRjTgm`）本身不含 BV/av/ss/ep 令牌，
/// 需要先跟随 302 重定向拿到真实 URL 才能被 [parseBiliBangumiUrl] 识别。
/// 手动逐跳跟随（≤5 跳）而非让 http 客户端自动跟随：命中 [isTarget]
/// 即提前返回，不发起下一跳请求、不下载整页 body。
///
/// 可靠性（§4.28）：每跳走统一重试（连接类失败退避重试）+ 文本档超时；
/// 重定向响应体用**带上限的丢弃**（`drainStreamCapped`）——302 的 body
/// 本应极小，上游若塞巨量数据即快速失败，不把整页拉下来。
library;

import 'package:http/http.dart' as http;
import 'package:moumou/services/bilibili/bili_constants.dart';
import 'package:moumou/utils/retry_policy.dart';

/// 带协议的 b23.tv 短链（App 分享格式恒带 https）。
final RegExp _b23WithScheme = RegExp(
  r'https?://b23\.tv/[0-9A-Za-z]+',
  caseSensitive: false,
);

/// 裸短链（用户手打可能不带协议）。
final RegExp _b23Bare = RegExp(
  r'b23\.tv/[0-9A-Za-z]+',
  caseSensitive: false,
);

/// 从**任意文本**中提取 b23.tv 短链；找不到返回 null。
///
/// App 分享复制出来的是 `【标题】 https://b23.tv/xxx` 带中文前缀的整串，
/// 不能按整串 `startsWith('http')` 判定（对齐小喵：`contains("b23.tv/")` +
/// 正则提取）。带协议的优先原样返回；裸短链（`b23.tv/xxx`）自动补 `https://`。
String? extractBiliShortLink(String input) {
  final m = _b23WithScheme.firstMatch(input);
  if (m != null) return m.group(0);
  final bare = _b23Bare.firstMatch(input);
  if (bare != null) return 'https://${bare.group(0)}';
  return null;
}

/// 展开分享短链，返回跳转后的真实 URL。
///
/// - 输入文本中提取不到 b23.tv 短链、请求失败或超过跳数上限时返回 null；
/// - [isTarget] 每跳解析出新的 URL 后先判定，命中即不再请求（避免下载页面体），
///   未命中继续跟随重定向；非重定向响应（200 等）直接返回当前 URL；
/// - 重定向响应的 body 极小，drain 掉以便复用连接；最终响应不读 body。
Future<String?> expandBiliShortLink(
  String input, {
  http.Client? client,
  bool Function(String url)? isTarget,
}) async {
  final link = extractBiliShortLink(input);
  if (link == null) return null;
  final uri = Uri.tryParse(link);
  if (uri == null) return null;

  final c = client ?? http.Client();
  final owned = client == null;
  try {
    var current = uri;
    for (var hop = 0; hop < 5; hop++) {
      if (isTarget != null && isTarget(current.toString())) {
        return current.toString();
      }
      // 每跳独立重试（连接类失败才重试；文本档超时）。
      // ⚠️ Request 必须每跳新建：http.Request 的 body 流只能发送一次，
      // 复用同一个对象重试会抛「Request has already been sent」。
      final resp = await withRetry(() {
        final req = http.Request('GET', current)
          ..followRedirects = false
          ..headers['User-Agent'] = BiliConstants.webUserAgent;
        return c.send(req).timeout(NetworkTimeoutTier.text.timeout);
      });
      final status = resp.statusCode;
      final location = resp.headers['location'];
      final isRedirectStatus = status == 301 ||
          status == 302 ||
          status == 303 ||
          status == 307 ||
          status == 308;
      if (isRedirectStatus && location != null && location.isNotEmpty) {
        // 302 的 body 极小：带上限丢弃（超限即弃，防上游塞巨量数据）
        await drainStreamCapped(resp.stream);
        current = current.resolve(location);
        continue;
      }
      // 非重定向：已到达真实页面，返回当前 URL（不读 body）
      return current.toString();
    }
    return current.toString();
  } catch (_) {
    return null;
  } finally {
    if (owned) c.close();
  }
}
