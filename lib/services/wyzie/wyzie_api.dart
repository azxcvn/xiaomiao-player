/// Wyzie 字幕 API 客户端（https://sub.wyzie.io）。
///
/// 封装来源列表 / 关键词搜索 / 字幕文件下载三个接口，统一处理：
/// - 响应体按 UTF-8 解码（不依赖 Content-Type 的 charset）；
/// - 非 2xx 抛 [WyzieApiException]，`/search` 的 400「无字幕」特判为空列表；
/// - 关键词搜索先经 `/api/tmdb/search` 解析媒体 ID（tt 号 / 纯数字 id 直用），
///   再请求 `/search`。
/// 对齐 mpvRx `WyzieSearchRepository.kt`。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:moumou/models/wyzie_models.dart';

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

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw WyzieApiException('网络请求失败: $e');
    }
    final text = utf8.decode(response.bodyBytes);
    // Wyzie 对合法参数但无字幕时返回 400 + No subtitles found，视为空结果。
    if (response.statusCode == 400 &&
        text.toLowerCase().contains('no subtitles found')) {
      return const [];
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WyzieApiException('搜索失败（HTTP ${response.statusCode}）');
    }
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
  Future<Uint8List> fetchBytes(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    } catch (e) {
      throw WyzieApiException('下载失败: $e');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WyzieApiException('下载失败（HTTP ${response.statusCode}）');
    }
    return response.bodyBytes;
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

  /// GET 请求，返回 UTF-8 解码后的响应体文本（非 2xx 抛异常）。
  Future<String> _getText(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final http.Response response;
    try {
      response =
          await _client.get(uri, headers: headers).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw WyzieApiException('网络请求失败: $e');
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WyzieApiException('请求失败（HTTP ${response.statusCode}）');
    }
    return text;
  }
}
