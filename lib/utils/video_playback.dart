import 'dart:math';

import 'package:media_kit/media_kit.dart';
import 'package:moumou/utils/playback_restore.dart';

bool hasNextVideo({
  required int length,
  required int currentIndex,
  bool randomPlayback = false,
}) =>
    length > 0 &&
    (randomPlayback || (currentIndex >= 0 && currentIndex < length - 1));

/// 随机模式每次重新抽取完整列表，允许重复当前项，不按观看状态过滤。
int? nextVideoIndex({
  required int length,
  required int currentIndex,
  bool randomPlayback = false,
  Random? random,
}) {
  if (!hasNextVideo(
    length: length,
    currentIndex: currentIndex,
    randomPlayback: randomPlayback,
  )) {
    return null;
  }
  return randomPlayback
      ? (random ?? Random()).nextInt(length)
      : currentIndex + 1;
}

/// 随机播放不恢复历史位置；普通播放沿用已有的进度阈值规则。
Duration? videoResumePosition({
  required Duration? saved,
  required Duration? duration,
  required double watchThreshold,
  bool randomPlayback = false,
}) {
  if (randomPlayback || saved == null || saved <= Duration.zero) return null;
  if (duration != null &&
      !shouldRestorePosition(
        duration,
        saved,
        maxRestoreRatio: watchThreshold,
      )) {
    return null;
  }
  return saved;
}

/// 再次抽到当前视频时原地重播，保留已挂载字幕；EOF 后需显式恢复播放。
Future<void> restartVideoFromBeginning(Player player) async {
  await player.seek(Duration.zero);
  await player.play();
}
