/// 弹弹Play 开放弹幕网络 API 客户端（签名验证模式）。
///
/// 封装搜索 / 拉取弹幕 / 文件匹配三个公开接口，统一处理：
/// - 请求头（X-AppId / X-Timestamp / X-Signature，签名算法见
///   `utils/dandan_signature.dart`）；
/// - 响应体按 UTF-8 解码（不依赖 Content-Type 的 charset）；
/// - 非 200 / 业务错误（success=false）抛出 [DandanApiException]。
///
/// 自建服务器通过 [baseUrl] 参数指定（默认官方地址）；密钥读取自
/// `dandan_play_keys.dart`（gitignored 私有文件）。
///
/// **生命周期（P2-11）**：不传 `client` 时本类自建一个 `http.Client`，用完
/// 必须 [close]（`DanmakuNetworkService.dispose` → `DanmakuController.dispose`
/// / 网络弹幕面板 dispose 逐级调用）——否则连接池与 keep-alive socket 泄漏。
///
/// 可靠性（§4.28）：请求走 `utils/retry_policy.dart` 的统一重试（连接类失败
/// 指数退避，响应中断不重试防重复提交）+ 12s 常规 API 超时档；响应体额外做
/// 硬上限检查（弹幕评论可能较大，超限即弃而不是解析垃圾数据）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/services/dandan_play_keys.dart';
import 'package:moumou/utils/dandan_signature.dart';
import 'package:moumou/utils/retry_policy.dart';

/// API 请求失败异常（网络错误 / 非 200 / 业务错误统一抛出）
class DandanApiException implements Exception {
  final String message;
  const DandanApiException(this.message);

  @override
  String toString() => 'DandanApiException: $message';
}

class DandanPlayApi {
  DandanPlayApi({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const String defaultBaseUrl = 'https://api.dandanplay.net';

  final http.Client _client;

  /// 是否由本实例创建了 [_client]（P2-11）：只有自建的那个才归本实例关闭——
  /// 注入进来的 client 由调用方（测试 / 共享池）自己负责生命周期，
  /// 否则关闭别人的连接池会让持有方后续请求全部失败。
  final bool _ownsClient;

  bool _closed = false;

  /// 是否已关闭（诊断/测试用）
  bool get isClosed => _closed;

  /// 释放自建连接池（幂等）。不关就是每个实例泄漏一个 `http.Client`
  /// （连接池 + keep-alive socket）：播放器进一次、网络弹幕面板开一次各一个。
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }

  /// 重试日志（排障用）
  void _logRetry(Object error, int nextAttempt) {
    debugPrint('DandanPlayApi: 第 $nextAttempt 次尝试（$error）');
  }

  /// 解析实际请求地址：自建服务器优先，无 scheme 视为非法回退官方。
  String _resolveBase(String? baseUrl) {
    final url = baseUrl?.trim();
    if (url == null || url.isEmpty) return defaultBaseUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw DandanApiException('服务器地址无效（需以 http/https 开头）: $url');
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// 生成签名请求头（时间戳取当前 UTC 秒）
  Map<String, String> _authHeaders(String path) {
    final timestamp =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    return {
      'X-AppId': kDandanPlayAppId,
      'X-Timestamp': '$timestamp',
      'X-Signature': dandanSignature(
        appId: kDandanPlayAppId,
        timestamp: timestamp,
        path: path,
        appSecret: kDandanPlayAppSecret,
      ),
    };
  }

  /// GET 请求，返回 UTF-8 解码后的响应体文本（非 200 抛异常）。
  Future<String> _get(String url, String path) async {
    final http.Response response;
    try {
      response = await withRetry(
        () => _client
            .get(
              Uri.parse(url),
              headers: {'Accept': 'application/json', ..._authHeaders(path)},
            )
            .timeout(NetworkTimeoutTier.api.timeout),
        onRetry: _logRetry,
      );
    } catch (e) {
      throw DandanApiException('网络请求失败: $e');
    }
    return _decode(response);
  }

  /// POST 请求（JSON），返回 UTF-8 解码后的响应体文本（非 200 抛异常）。
  Future<String> _post(String url, String path, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await withRetry(
        () => _client
            .post(
              Uri.parse(url),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                ..._authHeaders(path),
              },
              body: jsonEncode(body),
            )
            .timeout(NetworkTimeoutTier.api.timeout),
        onRetry: _logRetry,
      );
    } catch (e) {
      throw DandanApiException('网络请求失败: $e');
    }
    return _decode(response);
  }

  /// 统一响应解码：非 2xx 或业务 success=false 抛 [DandanApiException]。
  String _decode(http.Response response) {
    if (response.bodyBytes.length > kMaxJsonResponseBytes) {
      throw DandanApiException(
        '响应过大（${response.bodyBytes.length} 字节），已放弃解析',
      );
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DandanApiException('请求失败（HTTP ${response.statusCode}）');
    }
    // 业务错误：{ "success": false, "errorCode": .., "errorMessage": .. }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['success'] == false) {
        final msg = decoded['errorMessage'];
        throw DandanApiException(msg is String && msg.isNotEmpty ? msg : '服务器返回错误');
      }
    } catch (e) {
      if (e is DandanApiException) rethrow;
      // 非 JSON 响应按成功文本返回
    }
    return text;
  }

  /// 搜索番剧：GET /api/v2/search/episodes?anime=KEYWORD
  Future<List<DandanAnime>> searchAnime(
    String keyword, {
    String? baseUrl,
  }) async {
    final path = '/api/v2/search/episodes';
    final url =
        '${_resolveBase(baseUrl)}$path?anime=${Uri.encodeQueryComponent(keyword)}';
    final text = await _get(url, path);
    final decoded = jsonDecode(text);
    if (decoded is! Map) return const [];
    final raw = decoded['animes'];
    if (raw is! List) return const [];
    final result = <DandanAnime>[];
    for (final item in raw) {
      if (item is Map) {
        final anime = DandanAnime.fromJson(item.cast<String, dynamic>());
        if (anime != null) result.add(anime);
      }
    }
    return result;
  }

  /// 拉取单集弹幕：GET /api/v2/comment/{episodeId}?withRelated=true
  Future<List<DandanComment>> getComments(
    int episodeId, {
    String? baseUrl,
  }) async {
    final path = '/api/v2/comment/$episodeId';
    final url = '${_resolveBase(baseUrl)}$path?withRelated=true';
    final text = await _get(url, path);
    final decoded = jsonDecode(text);
    if (decoded is! Map) return const [];
    final raw = decoded['comments'];
    if (raw is! List) return const [];
    final result = <DandanComment>[];
    for (final item in raw) {
      if (item is Map) {
        final comment = DandanComment.fromJson(item.cast<String, dynamic>());
        if (comment != null) result.add(comment);
      }
    }
    return result;
  }

  /// 文件匹配：POST /api/v2/match（文件前 16MB 的 MD5 + 文件名 + 大小）。
  Future<List<DandanMatchInfo>> matchDanmaku({
    required String fileName,
    required String fileHash,
    required int fileSize,
    String? baseUrl,
  }) async {
    final path = '/api/v2/match';
    final url = _resolveBase(baseUrl) + path;
    final text = await _post(url, path, {
      'fileName': fileName,
      'fileHash': fileHash,
      'fileSize': fileSize,
    });
    final decoded = jsonDecode(text);
    if (decoded is! Map) return const [];
    if (decoded['isMatched'] != true) return const [];
    final raw = decoded['matches'];
    if (raw is! List) return const [];
    final result = <DandanMatchInfo>[];
    for (final item in raw) {
      if (item is Map) {
        final match = DandanMatchInfo.fromJson(item.cast<String, dynamic>());
        if (match != null) result.add(match);
      }
    }
    return result;
  }
}
