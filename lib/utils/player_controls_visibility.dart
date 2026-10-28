/// 播放页控制层显隐的判定（横竖屏两页共用，纯函数可单测）。
library;

/// 位置是否已到结尾（与播放完成判定同一口径：留 1 秒容差）。
///
/// 用位置而不是只看 `completed`：mpv 开 `keep-open` 播完时**先把 `pause`
/// 置真、再置 `eof-reached`**，暂停事件可能先到，此刻 `completed` 还是
/// false —— 只有位置能说明"这次暂停是播完了"。
bool isNearPlaybackEnd(Duration position, Duration duration) {
  if (duration <= Duration.zero) return false;
  return position >= duration - const Duration(seconds: 1);
}

/// 播放状态变为「暂停」时，是否应自动呼出控制层。
///
/// 播到结尾引起的暂停**一律不呼出**：
/// - 单集循环随即 seek 0 重播，呼出会让每一遍循环都闪一下 UI；
/// - 自动连播 / 列表循环 / 自动退出同样在换集/退出，没有"暂停"可言。
///
/// 自动暂停停在结尾是例外：它在播放页里显式呼出控制层（`pauseAtEnd`
/// 分支调用 ``_revealControls``），不依赖本函数。
///
/// [suppressed] 是双击暂停的一次性抑制标志（见播放页 `_suppressControlsOnNextPause`）。
///
/// 锁定态、退出中由各页在调用处另行判断（竖屏页没有「退出中」这条）。
bool shouldRevealControlsOnPause({
  required bool completed,
  required bool atEnd,
  required bool suppressed,
}) {
  return !completed && !atEnd && !suppressed;
}
