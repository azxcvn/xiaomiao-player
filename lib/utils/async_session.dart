/// 可替换异步任务的「会话号」令牌（对齐 Kazumi `AsyncSession`）。
///
/// 适用场景：**同一个位置会被反复重新发起**的异步任务——快速切集时的弹幕装载、
/// 快速改关键词的搜索、连续切换的画质解析……任务完成后先比对令牌，不是最新的
/// 就丢弃结果，避免「旧请求后到、覆盖新状态」。
///
/// 本项目此前在 `DanmakuController._loadSession`、`DanmakuScheduler._generation`
/// 各写了一份等价实现；抽成公共原语后带单测、新功能直接复用（§4.29）。
///
/// ```dart
/// final session = _loadSession.start();
/// final data = await fetch();
/// if (!_loadSession.isCurrent(session)) return;   // 已被更新的请求取代
/// apply(data);
/// ```
class AsyncSession {
  int _generation = 0;

  /// 当前令牌（每次 [start]/[invalidate] 都会变）
  int get generation => _generation;

  /// 开启新一轮任务并返回本次令牌
  int start() => ++_generation;

  /// 该令牌是否仍是最新（false = 已被后续任务取代，结果应丢弃）
  bool isCurrent(int token) => token == _generation;

  /// 作废所有在途任务（不发起新任务；清屏/销毁时用）
  void invalidate() => _generation++;

  /// 回到初始状态（测试用）
  void reset() => _generation = 0;
}
