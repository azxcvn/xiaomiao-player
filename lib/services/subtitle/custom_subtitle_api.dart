/// 自定义字幕源客户端：用户自填地址 → 通用 HTTP GET → 自动嗅探解析。
///
/// ⚠️ **本文件不内置任何第三方域名**：地址完全来自用户在设置里填写的模板
/// （见 `services/subtitle/subtitle_source_settings.dart`）。片名会发送到用户
/// 填写的那个地址，具体服务的条款与可用性由用户自行确认（隐私政策已披露）。
///
/// 可靠性沿用 `WyzieApi` 那一套（§4.28）：统一重试 + 分级超时 + 体积上限；
/// 响应体按 UTF-8 解码；解析交给纯函数 [parseCustomSubtitleResponse]。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:moumou/models/subtitle_entry.dart';
import 'package:moumou/utils/custom_subtitle_parser.dart';
import 'package:moumou/utils/error_codes.dart';
import 'package:moumou/utils/retry_policy.dart';

/// 自定义源请求失败（地址非法 / 网络错误 / 非 2xx / 解析失败统一抛出）
class CustomSubtitleApiException implements Exception {
  /// 错误码
  final CustomSubtitleApiErrorCode code;

  /// 参数（键名与 ARB placeholder 一致：`status` / `received` / `max` / `error` / `reason`）
  final Map<String, Object?> args;

  const CustomSubtitleApiException(this.code, {this.args = const {}});

  @override
  String toString() => 'CustomSubtitleApiException(${code.name})';
}

class CustomSubtitleApi {
  /// [client] 注入的 client 归调用方（[close] 不关它）；[clientFactory] 供测试
  /// 观察「自建 client 是否被关掉」——与 `WyzieApi` 同一约定。
  CustomSubtitleApi({http.Client? client, http.Client Function()? clientFactory})
      : _client = client ?? (clientFactory ?? http.Client.new)(),
        _ownsClient = client == null;

  /// 默认 UA：用本应用自己的名字，**不伪装成别的客户端**
  static const String _userAgent = 'MoumouPlayer';

  final http.Client _client;
  final bool _ownsClient;
  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }

  void _logRetry(Object error, int nextAttempt) {
    debugPrint('CustomSubtitleApi: 第 $nextAttempt 次尝试（$error）');
  }

  /// 按用户填写的 [urlTemplate] 搜索 [query]（片名）对应的字幕。
  Future<List<SubtitleEntry>> search({
    required String urlTemplate,
    required String query,
  }) async {
    final url = expandSubtitleUrlTemplate(urlTemplate, query);
    final uri = Uri.tryParse(url);
    final schemeOk = uri != null && (uri.isScheme('http') || uri.isScheme('https'));
    if (url.isEmpty || !schemeOk) {
      throw const CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.urlInvalid,
      );
    }

    final http.StreamedResponse response;
    try {
      response = await sendGet(
        _client,
        uri,
        headers: {'User-Agent': _userAgent},
        tier: NetworkTimeoutTier.api,
        onRetry: _logRetry,
      );
    } catch (e) {
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.networkFailed,
        args: {'error': '$e'},
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await drainStreamCapped(response.stream).catchError((Object _) {});
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.searchHttpFailed,
        args: {'status': '${response.statusCode}'},
      );
    }

    final String text;
    try {
      final bytes = await readBodyCapped(
        response,
        maxBytes: kMaxJsonResponseBytes,
      );
      text = utf8.decode(bytes, allowMalformed: true);
    } on ResponseTooLargeException catch (e) {
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.responseTooLarge,
        args: {
          'received': '${e.receivedBytes}',
          'max': '${e.maxBytes}',
        },
      );
    }

    try {
      return parseCustomSubtitleResponse(text);
    } on CustomSubtitleParseException catch (e) {
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.responseUnparsable,
        args: {'reason': e.code},
      );
    }
  }

  /// 下载字幕文件字节（30s 下载档超时 + 重试 + 64MB 上限，与 Wyzie 一致）。
  Future<Uint8List> fetchBytes(String url) async {
    final http.StreamedResponse response;
    try {
      response = await sendGet(
        _client,
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
        tier: NetworkTimeoutTier.download,
        onRetry: _logRetry,
      );
    } catch (e) {
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.downloadFailed,
        args: {'error': '$e'},
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await drainStreamCapped(response.stream).catchError((Object _) {});
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.downloadHttpFailed,
        args: {'status': '${response.statusCode}'},
      );
    }
    try {
      return await readBodyCapped(response, maxBytes: kMaxDownloadBytes);
    } on ResponseTooLargeException catch (e) {
      throw CustomSubtitleApiException(
        CustomSubtitleApiErrorCode.downloadTooLarge,
        args: {'received': '${e.receivedBytes}'},
      );
    }
  }
}
