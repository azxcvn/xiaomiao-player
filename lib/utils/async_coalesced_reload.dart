/// 串行合并的「等待式」重跑器（P1-11，纯 Dart、可单测）。
///
/// **解决什么**：`SubtitleController.reload()` 旧实现是「丢弃式」——
/// ```dart
/// if (_loading) return;   // 在飞时直接返回，调用方以为已经刷新完了
/// ```
/// 而 mpv 的 `stream.tracks` 事件、`sub-add`/`sub-remove`/`sub-reload` 之后
/// 的显式刷新会**并发**发生。丢弃式的后果是调用方（如「恢复上次选中字幕」）
/// 拿到的是**半新半旧的轨道快照**，解析不出目标轨道 → 静默不选中；
/// 极端时序下 `fetchTracks` 被打断还会把整批置空，UI 显示「当前视频没有字幕」。
///
/// **为什么不用 [AsyncSingleFlight]（§4.29）**：single-flight 让后来者共享
/// **已经开跑**的那个 Future —— 后来者拿到的仍是「自己那次改动之前」开始的
/// 快照（例如 `sub-add` 之后 join 了 `sub-add` 之前的那一轮），问题原样存在。
/// 这里需要的是「**不早于我的请求**开跑的那一轮」：在跑时只登记一次「待补跑」，
/// 等当前轮结束后立刻补跑一轮，所有等待者（含首个调用方）在补跑完成时一起完成。
///
/// 语义要点：
/// - 空闲调用 → 立刻开跑，返回该轮 Future；
/// - 在跑期间调用（不论几次）→ 合并成**一轮**补跑，一起等它完成；
/// - 任务抛错 → 错误交给本轮所有等待者（不静默吞掉、也不打断补跑）；
/// - 永不并发执行 [task]（同一实例内部串行）。
library;

import 'dart:async';

/// 串行合并的「等待式」重跑器：并发请求合并为「当前轮 + 一轮补跑」。
class AsyncCoalescedReload {
  AsyncCoalescedReload(this._task);

  final Future<void> Function() _task;

  bool _pumping = false;
  bool _requested = false;
  Completer<void>? _waiter;
  int _runCount = 0;

  /// 是否有任务正在执行（诊断/测试用）。
  bool get isRunning => _pumping;

  /// 累计实际执行 [task] 的次数（诊断/测试用，验证「合并成补跑」）。
  int get runCount => _runCount;

  /// 请求一次（或加入下一次）重跑，返回在**不早于本次请求**的那一轮完成后
  /// 才完结的 Future。
  Future<void> run() {
    _requested = true;
    final waiter = _waiter ??= Completer<void>();
    if (!_pumping) unawaited(_pump());
    return waiter.future;
  }

  Future<void> _pump() async {
    _pumping = true;
    Object? error;
    StackTrace? stack;
    try {
      while (_requested) {
        _requested = false;
        _runCount++;
        try {
          await _task();
        } catch (e, st) {
          // 记住本轮错误：等待者要拿到它，但补跑仍要继续（否则「已经有人等」
          // 的那一轮消失，调用方会永远挂住）。
          error = e;
          stack = st;
        }
      }
    } finally {
      // 先落下 _pumping，再取走 waiter：这两行之间没有 await，
      // 单线程下不会被新的 run() 插进来（否则会挂住新一轮等待者）。
      _pumping = false;
      final waiter = _waiter;
      _waiter = null;
      if (waiter != null) {
        if (error != null) {
          waiter.completeError(error, stack ?? StackTrace.current);
        } else {
          waiter.complete();
        }
      }
    }
  }
}
