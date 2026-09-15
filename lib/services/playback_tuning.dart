/// 每次 `open` 之前的 mpv 缓存/网络调参（§4.26，对齐 mpvRx `initOptions`）。
///
/// 抽成独立函数而不是留在播放页：**任何**打开媒体的地方（横屏播放页、
/// 听视频切歌……）都必须在 `open` 之前写一次——解封装缓存与重连参数只在
/// 打开文件时生效，漏写就会沿用上一首/上一档的参数（本地↔在线切换尤其明显）。
///
/// **同一次调用也会写入播放器级固定属性**（[applyPreOpenPlayerProperties]：
/// `hr-seek` / `gpu-api` / `profile`）——它们是同一类「必须早于 open」的属性，
/// 收口在一处就不会再出现「有的属性在 open 前、有的在 open 后」的竞速
/// （历史 bug：`gpu-api=vulkan` 落在 open 之后 → 播放中途重配视频输出）。
library;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/player_renderer_settings.dart';
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
  // 播放器级固定属性（渲染后端 / profile / 精确 seek）：与调参同一时机，
  // 保证在随后的 open 之前完成（见文件头说明）。
  //
  // ⚠️ 必须先 `ensureLoaded()`：DecodeSettings 在 main.dart 里是**异步**载入的，
  // 直接读会拿到默认值（gpuNext=false）→ 用户开了 GPU-next/Vulkan 却不生效。
  // 原先读它的地方在 initState 的更晚阶段，偶然避开了这个窗口；收口到这里后
  // 变成必然要等（本函数每次 open 前都会 await，成本仅首次一次读盘）。
  final decode = DecodeSettings.instance;
  await decode.ensureLoaded();
  await applyPreOpenPlayerProperties(
    player,
    gpuNext: decode.gpuNext,
    useVulkan: decode.useVulkan,
    presetProfile: decode.preset.profile,
  );

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
