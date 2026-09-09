import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/utils/retry_policy.dart';

/// 统一网络重试 / 超时分级 / 内容嗅探快速失败纯函数测试（§4.28）：
/// - 超时分级表；
/// - 可重试判定（连接类失败重试，响应中断/业务异常不重试）；
/// - 指数退避；
/// - withRetry 行为（成功/重试后成功/耗尽/不重试/流式不重试/回调）；
/// - 体积上限（content-length 预判 + 边读边判 + 快速失败不重试）；
/// - fetchTextCapped / fetchBytesCapped 端到端（MockClient）。
void main() {
  group('超时分级', () {
    test('四档时长与标签', () {
      expect(NetworkTimeoutTier.api.timeout, const Duration(seconds: 12));
      expect(NetworkTimeoutTier.text.timeout, const Duration(seconds: 15));
      expect(NetworkTimeoutTier.download.timeout, const Duration(seconds: 30));
      expect(NetworkTimeoutTier.stream.timeout, const Duration(minutes: 30));
      expect(NetworkTimeoutTier.api.label, '常规 API');
    });
  });

  group('isRetryableNetworkError', () {
    test('连接类失败可重试', () {
      expect(isRetryableNetworkError(const SocketException('refused')), isTrue);
      expect(isRetryableNetworkError(TimeoutException('timeout')), isTrue);
      expect(isRetryableNetworkError(const HttpException('bad')), isTrue);
      expect(isRetryableNetworkError(const OSError('io')), isTrue);
      expect(isRetryableNetworkError(http.ClientException('Failed to connect')),
          isTrue);
    });

    test('「请求可能已被服务端接收」不重试（防重复提交）', () {
      expect(
        isRetryableNetworkError(http.ClientException(
            'Connection closed before full header was received')),
        isFalse,
      );
      expect(
        isRetryableNetworkError(
            http.ClientException('Connection closed while receiving data')),
        isFalse,
      );
      expect(
        isRetryableNetworkError(
            http.ClientException('Connection terminated during response')),
        isFalse,
      );
      expect(
        isRetryableNetworkError(
            http.ClientException('Connection reset by peer')),
        isFalse,
      );
    });

    test('业务/解析/超限异常不重试', () {
      expect(isRetryableNetworkError(const FormatException('bad json')), isFalse);
      expect(isRetryableNetworkError(StateError('domain')), isFalse);
      expect(
        isRetryableNetworkError(const ResponseTooLargeException(10, 5)),
        isFalse,
      );
    });
  });

  group('retryDelayForAttempt', () {
    test('指数退避且封顶', () {
      expect(retryDelayForAttempt(0), Duration.zero);
      expect(retryDelayForAttempt(1), const Duration(milliseconds: 400));
      expect(retryDelayForAttempt(2), const Duration(milliseconds: 800));
      expect(retryDelayForAttempt(3), const Duration(milliseconds: 1600));
      expect(retryDelayForAttempt(4), const Duration(milliseconds: 3200));
      expect(retryDelayForAttempt(5), const Duration(seconds: 4)); // 封顶
      expect(retryDelayForAttempt(50), const Duration(seconds: 4));
    });

    test('自定义基数与上限', () {
      expect(
        retryDelayForAttempt(2,
            baseDelay: const Duration(milliseconds: 10),
            maxDelay: const Duration(milliseconds: 15)),
        const Duration(milliseconds: 15),
      );
    });
  });

  group('withRetry', () {
    test('首次成功不重试', () async {
      var calls = 0;
      final result = await withRetry(() async {
        calls++;
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('连接失败重试后成功', () async {
      var calls = 0;
      final result = await withRetry(
        () async {
          calls++;
          if (calls < 3) throw const SocketException('refused');
          return calls;
        },
        policy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      expect(result, 3);
      expect(calls, 3);
    });

    test('耗尽尝试后抛出最后一次异常', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          () async {
            calls++;
            throw const SocketException('refused');
          },
          policy: const RetryPolicy(
            maxAttempts: 2,
            baseDelay: Duration.zero,
            maxDelay: Duration.zero,
          ),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 2);
    });

    test('不可重试异常立即抛出（不浪费尝试）', () async {
      var calls = 0;
      await expectLater(
        withRetry(() async {
          calls++;
          throw const FormatException('bad');
        }),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('streaming=true 只执行一次', () async {
      var calls = 0;
      await expectLater(
        withRetry(
          () async {
            calls++;
            throw const SocketException('refused');
          },
          streaming: true,
          policy: const RetryPolicy(maxAttempts: 5, baseDelay: Duration.zero),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 1);
    });

    test('onRetry 回调带下次尝试序号', () async {
      final seen = <int>[];
      await withRetry(
        () async {
          if (seen.isEmpty) throw const SocketException('refused');
          return 'ok';
        },
        policy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
        onRetry: (error, next) => seen.add(next),
      );
      expect(seen, [2]);
    });
  });

  group('readBodyCapped / drainStreamCapped', () {
    http.StreamedResponse streamed(
      List<List<int>> chunks, {
      int? contentLength,
    }) =>
        http.StreamedResponse(
          Stream.fromIterable(chunks),
          200,
          contentLength: contentLength,
        );

    test('未超限正常读回', () async {
      final bytes = await readBodyCapped(
        streamed([utf8.encode('hello'), utf8.encode(' world')]),
        maxBytes: 100,
      );
      expect(utf8.decode(bytes), 'hello world');
    });

    test('content-length 声明超限 → 不读一个字节就失败', () async {
      var listened = false;
      final response = http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          [1, 2, 3],
        ]).map((c) {
          listened = true;
          return c;
        }),
        200,
        contentLength: 999,
      );
      await expectLater(
        readBodyCapped(response, maxBytes: 10),
        throwsA(isA<ResponseTooLargeException>()),
      );
      expect(listened, isFalse);
    });

    test('边读边判：实际超限即失败', () async {
      await expectLater(
        readBodyCapped(
          streamed([List.filled(8, 1), List.filled(8, 2)]),
          maxBytes: 10,
        ),
        throwsA(isA<ResponseTooLargeException>()),
      );
    });

    test('drainStreamCapped 超限抛出', () async {
      await expectLater(
        drainStreamCapped(
          Stream.fromIterable([List.filled(6, 1), List.filled(6, 2)]),
          maxBytes: 10,
        ),
        throwsA(isA<ResponseTooLargeException>()),
      );
      // 未超限正常结束
      await drainStreamCapped(Stream.fromIterable([List.filled(4, 1)]),
          maxBytes: 10);
    });
  });

  group('fetchTextCapped / fetchBytesCapped', () {
    test('文本按 UTF-8 解码（不依赖 charset）', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/text');
        return http.Response.bytes(
          utf8.encode('中文内容'),
          200,
          headers: {'content-type': 'text/plain'},
        );
      });
      final text = await fetchTextCapped(
        client,
        Uri.parse('https://example.com/text'),
        tier: NetworkTimeoutTier.text,
      );
      expect(text, '中文内容');
    });

    test('文本超限快速失败（不重试）', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response.bytes(List.filled(64, 65), 200);
      });
      await expectLater(
        fetchTextCapped(
          client,
          Uri.parse('https://example.com/big'),
          maxBytes: 16,
          policy: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            maxDelay: Duration.zero,
          ),
        ),
        throwsA(isA<ResponseTooLargeException>()),
      );
      expect(calls, 1);
    });

    test('连接失败按策略重试', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) throw const SocketException('refused');
        return http.Response('ok', 200);
      });
      final text = await fetchTextCapped(
        client,
        Uri.parse('https://example.com/retry'),
        policy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
      expect(text, 'ok');
      expect(calls, 2);
    });

    test('二进制下载带体积上限', () async {
      final client = MockClient((request) async {
        return http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200);
      });
      final bytes = await fetchBytesCapped(
        client,
        Uri.parse('https://example.com/file'),
        maxBytes: 16,
      );
      expect(bytes, [1, 2, 3, 4]);
      await expectLater(
        fetchBytesCapped(
          client,
          Uri.parse('https://example.com/file'),
          maxBytes: 2,
        ),
        throwsA(isA<ResponseTooLargeException>()),
      );
    });
  });
}
