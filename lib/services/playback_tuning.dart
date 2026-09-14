/// 每次 `open` 之前的 mpv 缓存/网络调参（§4.26，对齐 mpvRx `initOptions`）。
///
/// 抽成独立函数而不是留在播放页：**任何**打开媒体的地方（横屏播放页、
/// 听视频切歌……）都必须在 `open` 之前写一次——解封装缓存与重连参数只在
/// 打开文件时生效，漏写就会沿用上一首/上一档的参数（本地↔在线切换尤其明显）。
library;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/utils/mpv_tuning.dart';

/// 把 [buildMpvTuning] 的结果写进 [player]；[path] 用于判定本地/在线档。
///
/// `demuxer-lavf-o` 先读旧值再合并（media_kit 在里面放了
/// `protocol_whitelist`，整串覆盖会让 m3u8 等协议失效）；读不到旧值则
/// **不写该键**（[buildMpvTuning] 返回的表里不含它）。
///
/// 失败一律静默（播放器未就绪 / 属性不支持）：调参是优化项，不该阻断起播。
Future<void> applyPlaybackTuning(Player player, String path) async {
  try {
    final native = player.platform as NativePlayer;
    await native.waitForPlayerInitialization;
    String? lavfO;
    try {
      lavfO = await native.getProperty('demuxer-lavf-o');
    } catch (_) {
      lavfO = null;
    }
    final tuning = buildMpvTuning(
      isOnline: isOnlineMedia(path),
      existingDemuxerLavfO: lavfO,
    );
    for (final entry in tuning.entries) {
      await native.setProperty(entry.key, entry.value);
    }
  } catch (e) {
    // 播放器未就绪 / 属性不支持时静默失败，不影响播放
    debugPrint('applyPlaybackTuning: failed: $e');
  }
}
