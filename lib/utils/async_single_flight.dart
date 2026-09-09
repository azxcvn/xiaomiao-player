/// 在飞去重（single-flight）：同一 key 的并发请求只执行一次，后来者共享
/// 同一个 Future（对齐 Kazumi `AsyncSingleFlight`）。
///
/// 适用场景：列表首屏几十张卡片同时请求同一文件的元数据、同一 cid 的弹幕被
/// 多个入口同时拉取……没有它就会重复跨进程/跨网络调用（本项目此前在
/// `VideoInfoService` 手写了两个 Map + try/finally 版本，§4.29 收敛到本原语）。
///
/// 语义要点：
/// - **失败不缓存**：任务抛异常时在途记录立即清除，下一次调用会重新执行
///   （不把错误粘住）；
/// - **不吞异常**：每个调用方都拿到原始错误；
/// - 泛型按 key 空间使用：一个 [AsyncSingleFlight] 只服务一种返回类型。
class AsyncSingleFlight<T> {
  final Map<String, Future<T>> _inflight = {};

  /// 当前是否有在途任务
  bool get hasInFlight => _inflight.isNotEmpty;

  /// 在途 key 数量（测试/诊断用）
  int get inFlightCount => _inflight.length;

  /// 执行 [task]：同 key 已有在途任务时直接返回它的 Future。
  Future<T> run(String key, Future<T> Function() task) {
    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = task();
    _inflight[key] = future;
    // 完成（成功或失败）后清除在途记录；用 identical 防止误删后来者新建的
    // 同 key 任务（极端时序：前一个刚完成、下一个已开始）
    return future.whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
  }

  /// 丢弃所有在途记录（不取消任务本身；测试/切库时用）
  void clear() => _inflight.clear();
}
