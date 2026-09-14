/// 播放历史写入入口（横屏 / 竖屏播放页共用，B4/P1-3）。
///
/// 历史：原先只有横屏页 `_recordPlaybackHistory` 一份实现，竖屏页切集
/// （「下一集」/播放列表面板）完全不写历史、也不回填时长——竖屏连看多集时
/// 只有进入播放器那一集进历史。把「可重放来源过滤 + 记录 + 时长回填」收敛
/// 到这里，两页调用同一入口，杜绝再次漂移。
library;

import 'dart:async';

import 'package:moumou/services/playback_history_service.dart';
import 'package:moumou/utils/formatters.dart';

/// 是否为本机回环代理 URL（网络存储 / B 站的 `127.0.0.1` 流）。
///
/// 这类地址只在播放会话内有效，退出即失效，**写入历史也无法重放**，
/// 故一律跳过（本地真实路径与在线直链才记录）。
bool isLoopbackProxyUrl(String path) {
  final lower = path.toLowerCase();
  return lower.startsWith('http://127.0.0.1') ||
      lower.startsWith('http://localhost') ||
      lower.startsWith('https://127.0.0.1') ||
      lower.startsWith('https://localhost');
}

/// 记录一次播放（去重置顶由服务层完成；记录开关关闭时静默跳过）。
///
/// [durationMs] 为已知时长（优先取播放列表 MediaStore 的 `durationMs`，
/// open 前就可知）；未知传 0，退出/切集时由
/// [backfillPlaybackHistoryDuration] 回填。
void recordPlaybackHistory(String path, String title, {int durationMs = 0}) {
  if (path.isEmpty || isLoopbackProxyUrl(path)) return;
  unawaited(
    PlaybackHistoryService.instance.record(
      path,
      title,
      isUrl: isOnlineMedia(path),
      durationMs: durationMs,
    ),
  );
}

/// 回填历史条目时长（记录时未知、播放后已知；条目不存在时服务层静默忽略）。
void backfillPlaybackHistoryDuration(String path, Duration duration) {
  final ms = duration.inMilliseconds;
  if (path.isEmpty || ms <= 0) return;
  unawaited(PlaybackHistoryService.instance.updateDuration(path, ms));
}
