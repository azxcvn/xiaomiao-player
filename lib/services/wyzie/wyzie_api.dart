/// Wyzie 字幕 API 客户端（https://sub.wyzie.io）。
///
/// 封装来源列表 / 关键词搜索 / 字幕文件下载三个接口，统一处理：
/// - 响应体按 UTF-8 解码（不依赖 Content-Type 的 charset）；
/// - 非 2xx 抛 [WyzieApiException]，`/search` 的 400「无字幕」特判为空列表；
/// - 关键词搜索先经 `/api/tmdb/search` 解析媒体 ID（tt 号 / 纯数字 id 直用），
///   再请求 `/search`。
/// 对齐 mpvRx `WyzieSearchRepository.kt`。
///
/// 可靠性（§4.28）：所有请求走 `utils/retry_policy.dart` 的**统一重试 +
/// 超时分级 + 体积上限**——连接类失败指数退避重试，文本响应超 2MB 快速失败，
/// 字幕文件下载 30s 超时 + 64MB 上限。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/utils/retry_policy.dart';

/// API 请求失败异常（网络错误 / 非 2xx / 无匹配媒体统一抛出）。
class WyzieApiException implements Exception {
  final String message;
  const WyzieApiException(this.message);

  @override
  String toString() => 'WyzieApiException: $message';
}

class WyzieApi {
  WyzieApi({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = 'https://sub.wyzie.io';

  static const String _userAgent = 'Mozilla/5.0 (Linux; Android 14)';

  final http.Client _client;

  /// 重试日志（重试不改变用户可见语义，但排障需要知道发生过）
  void _logRetry(Object error, int nextAttempt) {
    debugPrint('WyzieApi: 第 $nextAttempt 次尝试（$error）');
  }

  /// 拉取来源列表（含免费/付费分层与密钥信息），密钥非空时随查询下发。
  Future<WyzieSourcesResponse> getSources({String apiKey = ''}) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/sources',
      queryParameters: {if (apiKey.isNotEmpty) 'key': apiKey},
    );
    final text = await _getText(uri, headers: {'User-Agent': _userAgent});
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const WyzieSourcesResponse();
      return WyzieSourcesResponse.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const WyzieSourcesResponse();
    }
  }

  /// 关键词搜索字幕。
  ///
  /// [language]/[format]/[encoding] 为已逗号拼接的查询值（由设置经
  /// `utils/wyzie_query.dart` 生成）；[source] 为 `all` 或逗号拼接来源。
  Future<List<WyzieSubtitle>> search({
    required String query,
    String apiKey = '',
    String? language,
    String? format,
    String? encoding,
    String source = 'all',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final searchId = await _resolveSearchId(trimmed);
    final uri = Uri.parse(baseUrl).replace(
      path: '/search',
      queryParameters: {
        'id': searchId,
        if (language != null && language.isNotEmpty) 'language': language,
        if (format != null && format.isNotEmpty) 'format': format,
        if (encoding != null && encoding.isNotEmpty) 'encoding': encoding,
        if (source != 'all') 'source': source,
        'unzip': 'true',
        if (apiKey.isNotEmpty) 'key': apiKey,
      },
    );

    final http.StreamedResponse response;
    try {
      response = await sendGet(
        _client,
        uri,
        tier: NetworkTimeoutTier.api,
        onRetry: _logRetry,
      );
    } catch (e) {
      throw WyzieApiException('网络请求失败: $e');
    }
    // Wyzie 对合法参数但无字幕时返回 400 + No subtitles found，视为空结果。
    if (response.statusCode == 400) {
      final text = await _readText(response);
      if (text.toLowerCase().contains('no subtitles found')) {
        return const [];
      }
      throw WyzieApiException('搜索失败（HTTP 400）');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await drainStreamCapped(response.stream).catchError((Object _) {});
      throw WyzieApiException('搜索失败（HTTP ${response.statusCode}）');
    }
    // 结果列表可能较长：JSON 用较大上限（仍为硬上限，§4.28）
    final text = await _readText(response, maxBytes: kMaxJsonResponseBytes);
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return const [];
      final result = <WyzieSubtitle>[];
      for (final item in decoded) {
        if (item is Map) {
          final sub = WyzieSubtitle.fromJson(item.cast<String, dynamic>());
          if (sub != null) result.add(sub);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// 下载字幕文件字节（字幕体积小，一次性读回内存再落盘）。
  ///
  /// 30s 下载档超时 + 重试 + 64MB 上限（防上游无限流）。
  Future<Uint8List> fetchBytes(String url) async {
    final http.StreamedResponse response;
    try {
      response = await sendGet(
        _client,
        Uri.parse(url),
        tier: NetworkTimeoutTier.download,
        onRetry: _logRetry,
      );
    } catch (e) {
      throw WyzieApiException('下载失败: $e');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await drainStreamCapped(response.stream).catchError((Object _) {});
      throw WyzieApiException('下载失败（HTTP ${response.statusCode}）');
    }
    try {
      return await readBodyCapped(response, maxBytes: kMaxDownloadBytes);
    } on ResponseTooLargeException catch (e) {
      throw WyzieApiException('下载失败：文件过大（${e.receivedBytes} 字节）');
    }
  }

  /// 读取响应体文本（体积上限保护 + UTF-8 解码）。
  Future<String> _readText(
    http.StreamedResponse response, {
    int maxBytes = kMaxTextResponseBytes,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await readBodyCapped(response, maxBytes: maxBytes);
    } on ResponseTooLargeException catch (e) {
      throw WyzieApiException(
        '响应异常（已读 ${e.receivedBytes} 字节，超过 ${e.maxBytes} 上限）',
      );
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 把关键词解析成可喂给 `/search` 的媒体 ID：tt 号 / 纯数字 id 直用，
  /// 否则经 TMDB 搜索取首个命中（对齐 mpvRx `search`）。
  Future<String> _resolveSearchId(String query) async {
    final isImdbId = query.toLowerCase().startsWith('tt');
    final isNumeric = RegExp(r'^\d+$').hasMatch(query);
    if (isImdbId || isNumeric) return query;
    final results = await _tmdbSearch(query);
    if (results.isEmpty) {
      throw const WyzieApiException('未找到匹配的影视，请换个关键词');
    }
    return results.first.id.toString();
  }

  Future<List<WyzieTmdbResult>> _tmdbSearch(String query) async {
    final uri = Uri.parse(baseUrl).replace(
      path: '/api/tmdb/search',
      queryParameters: {'q': query},
    );
    final text = await _getText(uri, headers: {'User-Agent': _userAgent});
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const [];
      return WyzieTmdbResponse.fromJson(decoded.cast<String, dynamic>()).results;
    } catch (_) {
      return const [];
    }
  }

  /// GET 请求，返回 UTF-8 解码后的响应体文本（分级超时 + 重试 + 体积上限）。
  Future<String> _getText(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final http.StreamedResponse response;
    try {
      response = await sendGet(
        _client,
        uri,
        headers: headers,
        tier: NetworkTimeoutTier.api,
        onRetry: _logRetry,
      );
    } catch (e) {
      throw WyzieApiException('网络请求失败: $e');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await drainStreamCapped(response.stream).catchError((Object _) {});
      throw WyzieApiException('请求失败（HTTP ${response.statusCode}）');
    }
    return _readText(response);
  }
}