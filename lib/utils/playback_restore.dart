import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// 播放进度恢复的可靠性工具（横屏/竖屏共用）。
///
/// 背景（历史 bug：重启软件后恢复进度"读到了但跳不过去"）：
/// mpv 只有在时间线激活（播放真正开始）后才接受 seek——冷启动加载窗口内
/// 的 seek 会被**静默丢弃**，且时长上报也可能明显晚于热启动。因此恢复
/// 必须：等时长就绪 → 等播放开始（首个 position>0 事件）→ seek → 用位置流
/// 确认生效（失败重试）。

/// 等待播放真正开始（时间线激活），最多 [timeout]。
///
/// 返回 false 表示超时（播放未能开始，放弃恢复）。
///
/// 工作.md 第 9 点加固：不再以「首个 position > 0」为唯一信号——冷启动 /
/// 快速进出循环时，首个微小 tick 可能出现在 mpv 加载期的临时时间线上，
/// 此时 seek 会被后续加载重置。要求位置推进到 [minStablePosition]
/// （默认 0.5s），说明时间线已稳定激活才返回 true。
Future<bool> waitForPlaybackStart(
  Player player, {
  Duration timeout = const Duration(seconds: 15),
  Duration minStablePosition = const Duration(milliseconds: 500),
}) async {
  if (player.state.position >= minStablePosition) return true;
  final completer = Completer<bool>();
  late final StreamSubscription<Duration> sub;
  sub = player.stream.position.listen((p) {
    if (p >= minStablePosition && !completer.isCompleted) {
      completer.complete(true);
    }
  });
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(false);
  });
  final ok = await completer.future;
  timer.cancel();
  await sub.cancel();
  return ok;
}

/// 等待位置到达 [target] 附近（`>= target - 1s`），用于确认 seek 生效。
///
/// 位置必须 `> 0`（过滤未开始的 0 位置事件），避免目标极小（<1s）时
/// 未 seek 也误判成功。返回 false 表示超时（seek 可能被丢弃）。
Future<bool> waitForPositionReaching(
  Player player,
  Duration target, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final threshold = target - const Duration(seconds: 1);
  final completer = Completer<bool>();
  late final StreamSubscription<Duration> sub;
  sub = player.stream.position.listen((p) {
    if (p > Duration.zero && p >= threshold && !completer.isCompleted) {
      completer.complete(true);
    }
  });
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(false);
  });
  final ok = await completer.future;
  timer.cancel();
  await sub.cancel();
  return ok;
}

/// 等待位置**严格越过** [target]（`> target`），用于确认恢复点那一帧
/// 已经解码上屏。
///
/// 背景（用户反馈：恢复封层揭开瞬间先闪 ~100ms 第一帧）：seek 到位时
/// mpv 已把 time-pos 更新为目标位置，但 Flutter 纹理上可能仍是恢复期间
/// 从 0 起播的旧帧，要等目标帧真正呈现后才追上。time-pos 随帧呈现更新，
/// 于是「越过 target 一 tick」= 目标帧之后的新帧已呈现——此时揭开
/// 封层看到的就是目标画面，不再有开头帧闪现。
///
/// 超时返回 true（不阻塞恢复：宁可提前揭开也不让封层卡死）。
Future<bool> waitForPositionAdvancing(
  Player player,
  Duration target, {
  Duration timeout = const Duration(milliseconds: 800),
}) async {
  if (player.state.position > target) return true;
  final completer = Completer<bool>();
  late final StreamSubscription<Duration> sub;
  sub = player.stream.position.listen((p) {
    if (p > target && !completer.isCompleted) completer.complete(true);
  });
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete(true);
  });
  final ok = await completer.future;
  timer.cancel();
  await sub.cancel();
  return ok;
}

/// 是否应恢复播放位置（纯函数，可单测）。
///
/// 阈值规则（v3 用户反馈：循环播放时"无限恢复已看完视频的进度"）：
/// - 时长未知 / 无进度 / 进度 ≥ 时长（已看完）：不恢复；
/// - `saved / duration < [minRestoreRatio]`（默认 5%）：几乎没看，从头播；
/// - `saved / duration >= [maxRestoreRatio]`（默认 90%，调用方可传
///   「已观看进度阈值」设置）：已看完，不恢复（EOF 循环回该视频时
///   若恢复会立即触发下一次 EOF，造成无限跳集）。
bool shouldRestorePosition(
  Duration duration,
  Duration saved, {
  double minRestoreRatio = 0.05,
  double maxRestoreRatio = 0.9,
}) {
  if (duration <= Duration.zero || saved <= Duration.zero) return false;
  if (saved >= duration) return false;
  final ratio = saved.inMilliseconds / duration.inMilliseconds;
  return ratio >= minRestoreRatio && ratio < maxRestoreRatio;
}

/// 「已看完」标记应写入的时长 = 「播放器时长」与「列表登记时长」的**较大者**
/// （纯函数，可单测）。
///
/// 背景（B3 真机实测，同一阈值下**不同文件夹表现不同**）：视频卡片用
/// `VideoFile.durationMs`（扫描器 / MediaStore，毫秒精度）判定
/// `progress / durationMs >= 阈值`，而 EOF 标记原先只写 mpv 的时长 —— 两者
/// 并不总相等（实测紫罗兰那批 mpv 时长 ≥ MediaStore，其他文件反之）。
/// 差一毫秒就表现为：百分比四舍五入仍显示「100%」，却**不是**「已看完」，
/// 而且够格触发恢复 → 重进定位到片尾直接 EOF 退出。
///
/// 取较大者，让卡片判定（`progress >= durationMs`）与恢复判定
/// （[shouldRestorePosition] 的 `saved >= duration` → 不恢复、从头播）同时成立。
Duration completedMarkDuration(
  Duration playerDuration, {
  int listDurationMs = 0,
}) {
  if (listDurationMs <= 0) return playerDuration;
  final list = Duration(milliseconds: listDurationMs);
  return list > playerDuration ? list : playerDuration;
}

/// 打开媒体并恢复到 [saved]（**v5.1 重写，修复「指示器显示但视频仍从头播」**）。
///
/// ⚠️ v5.3 注：v5.2 曾改用「open 前 `setProperty('start')` 加载期定位」，
/// 实测恢复进度失效（start 在 media_kit open 的内部 stop/加载序列下未能
/// 稳定生效），故还原为 v5.1 的确定性恢复流程。
///
/// 根因（v5 实测反馈）：v5 在 `open(play: false)` 暂停态直接 seek——mpv 暂停
/// 态 seek 只更新了 `time-pos` 属性（位置流确认到位、指示器照常显示），但
/// 解码器尚未真正重定位；随后 `play()` 从 0 开始解码，出现「指示器跳出、
/// 视频却从头播」。旧代码注释「时间线激活后 seek 才稳定」正是此坑。
///
/// 确定性恢复（v5.1）：
/// 1. `open(play: false)` 暂停加载 + 等时长就绪（不播开头）；
/// 2. `prepare`（倍速/超分）在播放前完成，避免 shader 变化重置位置；
/// 3. **静音** + `play()` 激活时间线（mpv 真正开始解码/播放）；
/// 4. 等位置推进 ≥150ms（播放确已开始、时间线激活）后 **再 seek**；
/// 5. 位置流确认到位（失败重试一次）；
/// 6. 再等位置**越过恢复点一 tick**（目标帧已解码上屏）才返回——调用方
///    据此揭开封层，揭开即目标画面，无「先闪 100ms 第一帧」；随后取消静音。
///
/// 全程由调用方用不透明封层盖住视频，静音则保证激活窗口内「从 0 短暂播放」
/// 不出声——首帧即目标帧、无开头闪现、无开头声音。
///
/// 返回 true = 已恢复到 [saved]；false = 无需恢复或恢复失败（从 0 播）。
Future<bool> openAndRestore(
  Player player,
  String path, {
  Duration? saved,
  Future<void> Function()? prepare,
  Future<void> Function()? beforePlay,
  Duration confirmTimeout = const Duration(seconds: 4),
}) async {
  final restore = saved != null && saved > Duration.zero;
  // 统一暂停加载，等文件就绪（不播开头）
  await player.open(Media(path), play: false);
  await _waitDuration(player);
  // 倍速 / 超分等准备（播放前完成）
  if (prepare != null) await prepare();
  // 播放前钩子（B 站双流：外挂音轨在 play 前挂载，避免开头无声音）
  if (beforePlay != null) await beforePlay();
  if (!restore) {
    await player.play();
    return false;
  }
  final native = player.platform as NativePlayer;
  // 静音：激活时间线期间「从 0 短暂播放」不出声（用户无感）
  await native.setProperty('mute', 'yes');
  try {
    await player.play();
    // 等播放真正开始（位置推进 ≥150ms 证明时间线已激活，seek 才稳定）
    await waitForPlaybackStart(
      player,
      minStablePosition: const Duration(milliseconds: 150),
      timeout: const Duration(seconds: 3),
    );
    // 时间线已激活，seek 必然生效
    await player.seek(saved);
    var ok =
        await waitForPositionReaching(player, saved, timeout: confirmTimeout);
    if (!ok) {
      await player.seek(saved);
      ok = await waitForPositionReaching(player, saved, timeout: confirmTimeout);
    }
    if (!ok) return false;
    // 位置确认到位后，再等位置越过恢复点一 tick（目标帧已解码上屏），
    // 调用方此时才揭开恢复封层——揭开即目标画面，无开头帧闪现
    await waitForPositionAdvancing(player, saved);
    return true;
  } finally {
    // 任何路径（含播放器销毁异常）都恢复静音状态，避免残留静音
    try {
      await native.setProperty('mute', 'no');
    } on AssertionError {
      // 播放器已销毁：忽略
    }
  }
}

/// 等待播放器上报时长（文件加载完成的信号），最多 [timeout]。
///
/// 超时也返回（不抛异常），调用方在时长仍未知时 seek 会自然失败，
/// 由 [openAndRestore] 的重试与调用方的「未恢复则从头播」兜底。
Future<void> _waitDuration(
  Player player, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (player.state.duration > Duration.zero) return;
  final completer = Completer<void>();
  late final StreamSubscription<Duration> sub;
  sub = player.stream.duration.listen((d) {
    if (d > Duration.zero && !completer.isCompleted) completer.complete();
  });
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;
  timer.cancel();
  await sub.cancel();
}
