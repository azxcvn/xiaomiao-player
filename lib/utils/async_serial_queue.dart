import 'dart:async';

/// 串行异步队列：并发提交的任务按提交顺序**依次**执行（对齐 Kazumi
/// `AsyncSerialQueue`）。
///
/// 适用场景：写盘/写偏好设置等「必须按顺序、不能并发」的操作——本项目此前在
/// `PlaybackProgressService._writeChain` 手写了 `_writeChain = _writeChain.then(...)`
/// 版本，抽成原语后带单测（§4.29）。
///
/// 语义要点：
/// - **任务抛异常不打断队列**：错误通过各自返回的 Future 抛出，后续任务照常执行
///   （否则一次写盘失败会让整条链变成 rejected，后续写入全部丢失）；
/// - ⚠️ **调用方必须接收返回的 Future**：异常只走这条返回的 Future，`await` 之后
///   它才不是未处理错误；[idle] 只等排空、**从不抛错**，所以「`add` 后只
///   `await idle`」会把写盘失败静默吞掉（P1-34）。不需要等待时用
///   `unawaited(queue.add(...).catchError(记日志))`；
/// - 队列为空时提交的任务立即执行（无额外延迟）；
/// - [idle] 可用于等待队列排空（测试/退出前落盘）。
class AsyncSerialQueue {
  Future<void> _tail = Future<void>.value();

  /// 追加一个任务，返回其结果 Future（异常原样抛出给调用方）。
  Future<T> add<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// 等待队列中所有任务执行完毕（异常已被各调用方各自接收，不会在这里抛出）
  Future<void> get idle => _tail;
}
