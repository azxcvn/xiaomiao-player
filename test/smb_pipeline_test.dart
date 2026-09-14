import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/network/smb_pipeline.dart';

/// 预读管线的统计，用来断言「取消/出错后不再读、句柄都关了、在途块数有上限」。
class _Stats {
  int opened = 0;
  int closed = 0;
  int reads = 0;

  int get inFlight => opened - closed;
}

/// 内存版 `RandomAccessFile`：只实现管线真正用到的那几个成员。
class _FakeRaf implements RandomAccessFile {
  _FakeRaf(this.bytes, this.stats, {this.failAtOffset, this.delay});

  final List<int> bytes;
  final _Stats stats;
  final int? failAtOffset;
  final Duration? delay;

  int _position = 0;
  bool _closed = false;

  @override
  Future<RandomAccessFile> setPosition(int position) async {
    _position = position;
    return this;
  }

  @override
  Future<Uint8List> read(int count) async {
    stats.reads++;
    if (delay != null) await Future<void>.delayed(delay!);
    if (failAtOffset != null && _position == failAtOffset) {
      throw StateError('模拟 SMB 读失败');
    }
    if (_position >= bytes.length) return Uint8List(0);
    final end = (_position + count).clamp(0, bytes.length);
    final chunk = Uint8List.fromList(bytes.sublist(_position, end));
    _position = end;
    return chunk;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    stats.closed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 未在测试里实现');
}

List<int> _payload(int length) => List<int>.generate(length, (i) => i % 251);

Future<List<int>> _drain(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final chunk in stream) {
    out.addAll(chunk);
  }
  return out;
}

/// 收到流的第一个错误（忽略之前的正常数据块）。
Future<Object?> _errorOf(Stream<List<int>> stream) {
  final completer = Completer<Object?>();
  stream.listen(
    (_) {},
    onError: (Object error) {
      if (!completer.isCompleted) completer.complete(error);
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(null);
    },
    cancelOnError: true,
  );
  return completer.future;
}

void main() {
  test('多句柄并发预读：内容与顺序完整（含非整除的尾块）', () async {
    final bytes = _payload(1000);
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(bytes, stats);
      },
      size: bytes.length,
      workers: 4,
      blockSize: 64, // 16 块（最后一块不足）
    );
    expect(await _drain(stream), bytes);
    expect(stats.opened, 4, reason: '4 个 worker 各持一个句柄');
    expect(stats.closed, 4, reason: '读完必须关掉所有句柄');
  });

  test('offset 起读：只输出区间内的字节', () async {
    final bytes = _payload(500);
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(bytes, stats);
      },
      size: bytes.length,
      offset: 200,
      workers: 3,
      blockSize: 64,
    );
    expect(await _drain(stream), bytes.sublist(200));
  });

  test('零长度区间：直接结束，不开句柄', () async {
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(const [], stats);
      },
      size: 100,
      offset: 100,
    );
    expect(await _drain(stream), isEmpty);
    expect(stats.opened, 0);
  });

  test('消费者取消 → worker 立刻停手、句柄全关、不再往文件末尾读', () async {
    final bytes = _payload(64 * 200); // 200 块
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(bytes, stats, delay: const Duration(milliseconds: 1));
      },
      size: bytes.length,
      workers: 4,
      blockSize: 64,
      maxBlocksAhead: 8,
    );

    final received = <int>[];
    late StreamSubscription<List<int>> sub;
    sub = stream.listen((chunk) {
      received.addAll(chunk);
      sub.cancel(); // 第一块到手就取消（模拟 mpv seek / 退出）
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final readsAtCancel = stats.reads;
    expect(readsAtCancel, lessThan(200), reason: '不能把整份文件读完');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(stats.reads, readsAtCancel, reason: '取消后不得再发起读请求');
    expect(stats.closed, stats.opened, reason: '取消后句柄必须全部释放');
    expect(stats.inFlight, 0);
  });

  test('某块读失败 → 流报错、其它 worker 停止、句柄全关、缓存清空', () async {
    final bytes = _payload(64 * 200);
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(
          bytes,
          stats,
          failAtOffset: 64 * 3,
          delay: const Duration(milliseconds: 1),
        );
      },
      size: bytes.length,
      workers: 4,
      blockSize: 64,
    );

    await expectLater(_errorOf(stream), completion(isA<StateError>()));
    final readsAtError = stats.reads;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(stats.reads, readsAtError, reason: '出错后其它 worker 必须停手');
    expect(stats.closed, stats.opened, reason: '出错后句柄必须全部释放');
  });

  test('背压：消费者暂停时停手、恢复后读完（不死锁）', () async {
    final bytes = _payload(64 * 500); // 500 块
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _FakeRaf(bytes, stats);
      },
      size: bytes.length,
      workers: 4,
      blockSize: 64,
      maxBlocksAhead: 8,
    );

    final received = <int>[];
    var delivered = 0;
    final done = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = stream.listen(
      (chunk) {
        received.addAll(chunk);
        delivered++;
        if (delivered == 3) sub.pause(); // 模拟 mpv 暂时不拉数据
      },
      onDone: done.complete,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(delivered, 3);
    expect(
      stats.reads,
      lessThanOrEqualTo(3 + 8 + 4),
      reason: '窗口 8 块 + 最多 4 个在途 worker，不能把 500 块全读进内存',
    );

    sub.resume();
    await done.future.timeout(const Duration(seconds: 5));
    expect(received.length, bytes.length, reason: '恢复后必须读完，背压不能把流卡死');
    expect(stats.closed, stats.opened);
  });

  test('单次块读取超时 → 流报错而不是永久挂起', () async {
    final bytes = _payload(64 * 10);
    final stats = _Stats();
    final stream = pipelinedSmbStream(
      open: () async {
        stats.opened++;
        return _NeverReads(stats);
      },
      size: bytes.length,
      workers: 1,
      blockSize: 64,
      readTimeout: const Duration(milliseconds: 50),
    );
    await expectLater(stream, emitsError(isA<TimeoutException>()));
    expect(stats.closed, stats.opened, reason: '超时后句柄也要释放');
  });
}

/// 永不返回的句柄：验证单次读超时。
class _NeverReads implements RandomAccessFile {
  _NeverReads(this.stats);

  final _Stats stats;

  @override
  Future<RandomAccessFile> setPosition(int position) async => this;

  @override
  Future<Uint8List> read(int count) => Completer<Uint8List>().future;

  @override
  Future<void> close() async => stats.closed++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 未在测试里实现');
}
