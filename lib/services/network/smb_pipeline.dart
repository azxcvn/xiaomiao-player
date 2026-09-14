/// SMB 并发预读管线（纯逻辑，不依赖 `smb_connect`，可单测）。
///
/// `smb_connect` 的底层读取是「发一个 64KB 读请求 → 等响应 → 再发下一个」，
/// 全串行，吞吐被压在 `单块 ÷ 往返延迟`（≈1.5MB/s）。本管线用 [workers] 个独立
/// 文件句柄各自读不同块、按块序号合并输出，让多个读请求**同时在途**——依赖 fork
/// 里去掉全局串行锁的能力（见 `third_party/smb_connect/FORK.md`）。
///
/// 这里同时是流式路径的**取消与背压**实现处（P1-22），三条纪律：
/// 1. **消费者取消即停手**（mpv seek/退出、代理 `_limitBytes` 提前 close）：
///    worker 立刻跳出循环、关闭自己的句柄，绝不再往文件末尾读；
/// 2. **出错即停其它 worker** 并清掉已缓存块：旧实现里 `deliver()` 因 `isClosed`
///    直接返回、但 `completed[i] = data` 照旧执行 → 出错后整文件堆在内存里（OOM）；
/// 3. **在途块数有上限**（[maxBlocksAhead]）：消费者读得慢时 worker 会挂起等待，
///    不会把整个文件预读进内存；消费者**暂停**订阅（mpv 缓冲/暂停）时同样停手。
library;

import 'dart:async';
import 'dart:io';

/// 用多句柄并发预读 [size] 字节文件的 [offset] 起始区间，按序输出。
///
/// [open] 每次调用都必须返回**独立的**文件句柄（并发读靠多个句柄在途）。
/// [readTimeout] 是单次块读取的上限：传输层卡死时不能永久挂起（拔出网线/服务端
/// 半开时，上层要么报错要么重连，见 §4.28）。
Stream<List<int>> pipelinedSmbStream({
  required Future<RandomAccessFile> Function() open,
  required int size,
  int offset = 0,
  int workers = 4,
  int blockSize = 64000,
  int maxBlocksAhead = 8,
  Duration readTimeout = const Duration(seconds: 30),
}) {
  final total = size - offset;
  final totalBlocks = total <= 0 ? 0 : (total + blockSize - 1) ~/ blockSize;
  final controller = StreamController<List<int>>();

  final completed = <int, List<int>>{};
  final waiters = <Completer<void>>[];
  var nextToYield = 0;
  var cancelled = false;
  var failed = false;
  var paused = false;
  var started = false;

  /// 唤醒所有「窗口已满」的等待者，让它们重新判断（窗口只在 [nextToYield] 前进
  /// 或终止时变大）。
  void wakeAll() {
    final pending = List<Completer<void>>.of(waiters);
    waiters.clear();
    for (final waiter in pending) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void deliver() {
    while (!cancelled && completed.containsKey(nextToYield)) {
      final chunk = completed.remove(nextToYield)!;
      nextToYield++;
      if (!controller.isClosed) controller.add(chunk);
    }
    if (nextToYield >= totalBlocks && !controller.isClosed) {
      unawaited(controller.close());
    }
    wakeAll();
  }

  /// 背压：只允许读「离下一个待输出块不超过 [maxBlocksAhead] 块」的块，
  /// 且消费者暂停期间**一块都不读**。
  ///
  /// 待输出块的属主永远不会被卡住（偏移为 0，恒在窗口内），所以窗口满时
  /// 仍然有 worker 能推进 → 不会死锁；而窗口一旦推进就唤醒等待者。
  Future<void> waitForWindow(int index) async {
    while (!cancelled &&
        !failed &&
        (paused || index - nextToYield >= maxBlocksAhead)) {
      final waiter = Completer<void>();
      waiters.add(waiter);
      await waiter.future;
    }
  }

  Future<void> worker(int seed) async {
    RandomAccessFile? raf;
    try {
      raf = await open();
      for (var i = seed; i < totalBlocks; i += workers) {
        await waitForWindow(i);
        if (cancelled || failed) break;
        final start = offset + i * blockSize;
        final want = (i == totalBlocks - 1) ? total - i * blockSize : blockSize;
        await raf.setPosition(start);
        final data = await raf.read(want).timeout(readTimeout);
        if (cancelled || failed) break;
        completed[i] = data;
        deliver();
      }
    } catch (error, stack) {
      if (!failed && !cancelled) {
        failed = true;
        completed.clear();
        if (!controller.isClosed) {
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      }
    } finally {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {
          // 句柄关闭异常不影响已交付的数据
        }
      }
      // 让其它 worker 从窗口等待中醒来，看到 cancelled/failed 后收工
      wakeAll();
    }
  }

  controller.onListen = () {
    if (started) return;
    started = true;
    if (totalBlocks == 0) {
      unawaited(controller.close());
      return;
    }
    for (var i = 0; i < workers && i < totalBlocks; i++) {
      unawaited(worker(i));
    }
  };
  controller.onCancel = () {
    cancelled = true;
    completed.clear();
    wakeAll();
  };
  controller.onPause = () {
    // 消费者暂停（mpv 缓冲/暂停、代理侧限速）→ worker 停在窗口外等恢复
    paused = true;
  };
  controller.onResume = () {
    paused = false;
    wakeAll();
  };

  return controller.stream;
}
