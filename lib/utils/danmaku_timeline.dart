/// 弹幕时间轴纯函数（同秒多条错峰发射 + 时间轴偏移，对齐 Kazumi
/// `DanmakuTimeline`）。
library;

/// 同一秒桶内的多条弹幕在 1 秒内错峰发射的延迟（毫秒）。
///
/// [index] / [total] 为该批弹幕在本次发射中的序号与总数；
/// 例如 4 条同秒弹幕的延迟分别为 0 / 250 / 500 / 750 毫秒，
/// 避免同一秒的全部弹幕在同一瞬间扎堆上屏。
int staggerDelayMilliseconds({required int index, required int total}) {
  if (total <= 0) return 0;
  return index * 1000 ~/ total;
}

/// 时间轴偏移后的源时间位置（对齐 Kazumi `resolveSourceSecond`）：
/// source = playback − offset（正 = 延后、负 = 提前）。
/// 返回值可为负（负秒桶在调度器中视为空，即「该偏移下片头前无弹幕」）。
Duration sourceDanmakuPosition(Duration playbackPosition, double offsetSeconds) {
  final sourceMs =
      playbackPosition.inMilliseconds - (offsetSeconds * 1000).round();
  return Duration(milliseconds: sourceMs);
}

/// 时间轴偏移时长的 ASCII 文本（`MM:SS`）。
///
/// 偏移的**方向与整句**属界面文案，在 UI 层拼：见
/// `label_maps.danmakuOffsetText`（0 → 无偏移，正 → 延后，负 → 提前）。
String formatDanmakuOffsetDuration(double value) {
  final total = value.abs().round();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
