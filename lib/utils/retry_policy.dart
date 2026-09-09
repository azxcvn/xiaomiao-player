/// 统一网络重试 + 超时分级 + 内容嗅探快速失败（纯工具层）。
///
/// 借鉴来源：
/// - **重试**：PiliPlus `retry_interceptor.dart`——只对**连接类**失败重试
///   （连接失败/超时），显式排除「请求可能已被服务端接收」的情况防重复提交，
///   指数退避，**流式响应一律不重试**；
/// - **超时分级**：Kazumi——常规 API 12s / 文本 15s / 下载 30s / 媒体流 30 分钟，
///   单请求可按需覆盖；
/// - **快速失败**：Kazumi 的「下载 m3u8 超过 2MB 主动取消」——文本响应设体积
///   上限，超限即弃（这显然不是文本/清单），成本几乎为零。
///
/// 本文件不依赖任何具体 API 客户端，可单测（§5.5）；调用方负责把底层异常
/// 包装成自己的语义化异常（本项目 `BiliApiException` / `DandanApiException` /
/// `WyzieApiException` 的三层语义不变）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 超时分级（每条请求按用途选档，不再各客户端各自为政）。
enum NetworkTimeoutTier {
  /// 常规 API（JSON 接口）
  api(Duration(seconds: 12), '常规 API'),

  /// 文本响应（m3u8 清单 / 短链展开 / 关键词搜索）
  text(Duration(seconds: 15), '文本响应'),

  /// 文件下载（字幕等）
  download(Duration(seconds: 30), '文件下载'),

  /// 媒体流（直链视频，允许长时间空闲）
  stream(Duration(minutes: 30), '媒体流');

  const NetworkTimeoutTier(this.timeout, this.label);

  /// 该档位对应的超时时长
  final Duration timeout;

  /// 展示名（日志/提示用）
  final String label;
}

/// 文本响应体上限（2MB）：超过即判定「不是文本/清单」并快速失败。
const int kMaxTextResponseBytes = 2 * 1024 * 1024;

/// JSON 响应体上限（16MB）：弹幕/列表类接口可能较大，仍给硬上限。
const int kMaxJsonResponseBytes = 16 * 1024 * 1024;

/// 文件下载上限（64MB）：字幕/封面等小文件，防上游无限流。
const int kMaxDownloadBytes = 64 * 1024 * 1024;

/// 响应体超限异常（快速失败信号，**不重试**）。
class ResponseTooLargeException implements Exception {
  const ResponseTooLargeException(this.receivedBytes, this.maxBytes);

  /// 已读到的字节数（content-length 已知时为声明值）
  final int receivedBytes;

  /// 允许的上限
  final int maxBytes;

  @override
  String toString() =>
      'ResponseTooLargeException: $receivedBytes > $maxBytes bytes';
}

/// 重试策略（总尝试次数含首次）。
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 4),
  });

  /// 不重试（只尝试一次）
  static const RetryPolicy none = RetryPolicy(maxAttempts: 1);

  /// 总尝试次数（≥1）
  final int maxAttempts;

  /// 首次退避时长（此后按 2 倍指数增长）
  final Duration baseDelay;

  /// 退避上限
  final Duration maxDelay;
}

/// 是否值得重试（纯函数）。
///
/// 只认**连接类**失败：请求根本没到服务端（连接失败/建立超时），重发安全。
/// 「请求已发出但响应中断」的情况（`Connection closed before full header was
/// received` 等）**不重试**——服务端可能已经处理过，重发可能重复提交
/// （对齐 PiliPlus 排除 `TransportConnectionException` 的决策）。
/// 业务/解析类异常（格式错误、非 2xx 包装后的领域异常）一律不重试。
bool isRetryableNetworkError(Object error) {
  if (error is ResponseTooLargeException) return false;
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;
  if (error is HttpException) return true;
  if (error is OSError) return true;
  if (error is http.ClientException) {
    return !_mayHaveReachedServer(error.message);
  }
  return false;
}

/// 响应中断类消息 → 请求可能已被服务端接收
bool _mayHaveReachedServer(String message) {
  final m = message.toLowerCase();
  return m.contains('connection closed before full header') ||
      m.contains('connection closed while receiving') ||
      m.contains('connection terminated') ||
      m.contains('connection reset by peer');
}

/// 指数退避：第 [attempt] 次失败后的等待时长（attempt 从 1 开始）。
///
/// `baseDelay × 2^(attempt-1)`，不超过 [maxDelay]。
Duration retryDelayForAttempt(
  int attempt, {
  Duration baseDelay = const Duration(milliseconds: 400),
  Duration maxDelay = const Duration(seconds: 4),
}) {
  if (attempt < 1) return Duration.zero;
  var ms = baseDelay.inMilliseconds;
  for (var i = 1; i < attempt; i++) {
    ms *= 2;
    if (ms >= maxDelay.inMilliseconds) return maxDelay;
  }
  return ms >= maxDelay.inMilliseconds ? maxDelay : Duration(milliseconds: ms);
}

/// 执行一次可能失败的网络操作，按 [policy] 重试可重试的失败。
///
/// [streaming] 为 true 时**直接单次执行**（流式响应/下载 Range 重试会造成
/// 重复拉流或数据错乱）。
/// [onRetry] 在每次决定重试后、等待退避前回调（记录日志用）。
Future<T> withRetry<T>(
  Future<T> Function() run, {
  RetryPolicy policy = const RetryPolicy(),
  bool streaming = false,
  void Function(Object error, int nextAttempt)? onRetry,
}) async {
  if (streaming) return run();
  var attempt = 1;
  while (true) {
    try {
      return await run();
    } catch (error) {
      final canRetry = attempt < policy.maxAttempts &&
          isRetryableNetworkError(error);
      if (!canRetry) rethrow;
      onRetry?.call(error, attempt + 1);
      await Future<void>.delayed(retryDelayForAttempt(
        attempt,
        baseDelay: policy.baseDelay,
        maxDelay: policy.maxDelay,
      ));
      attempt++;
    }
  }
}

/// 读取响应体并强制体积上限（超过上限抛 [ResponseTooLargeException]）。
///
/// 先看 `content-length`（声明超限直接放弃，不读一个字节），再边读边计数；
/// 超限时抛异常会**自动取消**上游流订阅（`await for` 语义），不再继续下载。
Future<Uint8List> readBodyCapped(
  http.StreamedResponse response, {
  int maxBytes = kMaxTextResponseBytes,
}) async {
  final declared = response.contentLength;
  if (declared != null && declared > maxBytes) {
    // 声明就超限：**一个字节都不读**，直接取消订阅断开连接
    //（不能 drain——那会把上游的巨量响应全部下载下来）
    await response.stream.listen(null).cancel();
    throw ResponseTooLargeException(declared, maxBytes);
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response.stream) {
    builder.add(chunk);
    if (builder.length > maxBytes) {
      throw ResponseTooLargeException(builder.length, maxBytes);
    }
  }
  return builder.takeBytes();
}

/// 丢弃响应流但同样受体积上限保护（重定向响应/探测请求用）。
Future<void> drainStreamCapped(
  Stream<List<int>> stream, {
  int maxBytes = kMaxTextResponseBytes,
}) async {
  var read = 0;
  await for (final chunk in stream) {
    read += chunk.length;
    if (read > maxBytes) {
      throw ResponseTooLargeException(read, maxBytes);
    }
  }
}

/// GET 请求并返回**受上限保护**的原始字节。
///
/// 分级超时 + 指数退避重试 + 体积上限三件事一次做完；非 2xx 不在这里判定，
/// 由调用方按自己的错误语义处理（各 API 客户端的错误文案不同）。
Future<http.StreamedResponse> sendGet(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  NetworkTimeoutTier tier = NetworkTimeoutTier.text,
  RetryPolicy policy = const RetryPolicy(),
  void Function(Object error, int nextAttempt)? onRetry,
}) {
  return withRetry(
    () {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      return client.send(request).timeout(tier.timeout);
    },
    policy: policy,
    onRetry: onRetry,
  );
}

/// GET 文本响应：分级超时 + 重试 + 体积上限，UTF-8 解码（不依赖 charset）。
Future<String> fetchTextCapped(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  NetworkTimeoutTier tier = NetworkTimeoutTier.text,
  int maxBytes = kMaxTextResponseBytes,
  RetryPolicy policy = const RetryPolicy(),
  void Function(Object error, int nextAttempt)? onRetry,
}) async {
  final response = await sendGet(
    client,
    uri,
    headers: headers,
    tier: tier,
    policy: policy,
    onRetry: onRetry,
  );
  final bytes = await readBodyCapped(response, maxBytes: maxBytes);
  return utf8.decode(bytes, allowMalformed: true);
}

/// GET 二进制响应：分级超时 + 重试 + 体积上限。
Future<Uint8List> fetchBytesCapped(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  NetworkTimeoutTier tier = NetworkTimeoutTier.download,
  int maxBytes = kMaxDownloadBytes,
  RetryPolicy policy = const RetryPolicy(),
  void Function(Object error, int nextAttempt)? onRetry,
}) async {
  final response = await sendGet(
    client,
    uri,
    headers: headers,
    tier: tier,
    policy: policy,
    onRetry: onRetry,
  );
  return readBodyCapped(response, maxBytes: maxBytes);
}
