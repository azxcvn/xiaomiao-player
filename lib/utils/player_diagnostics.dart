/// 播放诊断的纯函数层：采样属性清单 + 数值格式化 + 健康判定。
///
/// 面板（`pages/player/views/player_diagnostics_panel.dart`）只负责定时调用
/// 属性读取回调并渲染，本文件所有函数无状态、可单测（§5.5 约定）。
library;

import 'package:moumou/models/player_diagnostics.dart';

/// 播放诊断需要读取的 mpv 属性（一次采样全读一遍）。
///
/// 全部是 mpv 公开属性，缺失/不支持时读取回调返回 null，面板显示 `—`。
const List<String> kPlayerDiagnosticsProperties = [
  'media-title',
  'file-format',
  'video-codec',
  'audio-codec-name',
  'width',
  'height',
  'video-params/pixelformat',
  'container-fps',
  'estimated-vf-fps',
  'display-fps',
  'hwdec-current',
  'current-vo',
  'video-sync',
  'drop-frame-count',
  'decoder-frame-drop-count',
  'vo-delayed-frame-count',
  'vo-delayed-frame-average-ms',
  'mistimed-frame-count',
  'demuxer-cache-duration',
  'demuxer-cache-time',
  'cache-used',
  'cache-speed',
  'video-bitrate',
  'audio-bitrate',
  'audio-params',
  'avsync',
];

/// 空值占位符（属性缺失 / 播放器未就绪）
const String kDiagnosticPlaceholder = '—';

/// 文本：空/占位归一。
String formatDiagnosticText(String? value) {
  if (value == null) return kDiagnosticPlaceholder;
  final t = value.trim();
  if (t.isEmpty || t == '--') return kDiagnosticPlaceholder;
  return t;
}

/// 字节数 → `12.3 MB`（1024 进制，保留 1 位小数）。
String formatDiagnosticBytes(int? bytes) {
  if (bytes == null || bytes < 0) return kDiagnosticPlaceholder;
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

/// 码率（bit/s）→ `1.42 Mb/s`。
String formatDiagnosticBitrate(int? bitsPerSecond) {
  if (bitsPerSecond == null || bitsPerSecond < 0) {
    return kDiagnosticPlaceholder;
  }
  if (bitsPerSecond < 1000) return '$bitsPerSecond b/s';
  final kbps = bitsPerSecond / 1000;
  if (kbps < 1000) return '${kbps.toStringAsFixed(0)} kb/s';
  return '${(kbps / 1000).toStringAsFixed(2)} Mb/s';
}

/// 下行速率（字节/秒）→ `2.10 MB/s`（与顶部信息行网速口径一致）。
String formatDiagnosticSpeed(double? bytesPerSecond) {
  if (bytesPerSecond == null || bytesPerSecond < 0) {
    return kDiagnosticPlaceholder;
  }
  final kb = bytesPerSecond / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(2)} KB/s';
  return '${(kb / 1024).toStringAsFixed(2)} MB/s';
}

/// 秒 → `3.2 s`。
String formatDiagnosticSeconds(double? seconds) {
  if (seconds == null || seconds < 0) return kDiagnosticPlaceholder;
  if (seconds < 60) return '${seconds.toStringAsFixed(1)} s';
  final m = seconds ~/ 60;
  final s = (seconds - m * 60).toStringAsFixed(0);
  return '$m 分 $s 秒';
}

/// 毫秒 → `12.3 ms`。
String formatDiagnosticMillis(double? ms) {
  if (ms == null || ms < 0) return kDiagnosticPlaceholder;
  return '${ms.toStringAsFixed(1)} ms';
}

/// 帧率 → `23.98 fps`。
String formatDiagnosticFps(double? fps) {
  if (fps == null || fps <= 0) return kDiagnosticPlaceholder;
  return '${fps.toStringAsFixed(2)} fps';
}

/// 分辨率 → `1920×1080`。
String formatDiagnosticResolution(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return kDiagnosticPlaceholder;
  }
  return '$width×$height';
}

/// 音画同步偏差（秒）→ `+12 ms 音频超前` / `-8 ms 视频超前`。
String formatDiagnosticAvsync(double? seconds) {
  if (seconds == null) return kDiagnosticPlaceholder;
  final ms = seconds * 1000;
  final sign = ms >= 0 ? '+' : '-';
  final label = ms >= 0 ? '音频超前' : '视频超前';
  return '$sign${ms.abs().toStringAsFixed(0)} ms $label';
}

/// 渲染延迟告警阈值（mpv `vo-delayed-frame-average-ms`）：超过即说明
/// 显示管线吃紧，配合「丢帧」可判断是否需要降档（超分/解码）。
const double kDelayedFrameWarnMs = 20;

/// 音画同步偏差告警阈值（秒）：超过 100ms 人耳可感知。
const double kAvsyncWarnSec = 0.1;

/// 健康提示（纯函数）：按优先级返回需要用户注意的现象，无异常返回空列表。
///
/// 用于面板顶部把「哪里不健康」直接讲清楚，排障不必逐行读数字（§4.27）。
List<String> diagnosticsWarnings(PlayerDiagnosticsSnapshot s) {
  final warnings = <String>[];
  final dropped = s.droppedFrames ?? 0;
  if (dropped > 0) {
    warnings.add('已丢帧 $dropped 帧：渲染跟不上，可尝试降超分档位或改硬解');
  }
  final delayedAvg = s.delayedFrameAverageMs;
  if (delayedAvg != null && delayedAvg > kDelayedFrameWarnMs) {
    warnings.add('渲染延迟偏高（平均 ${delayedAvg.toStringAsFixed(1)} ms）');
  }
  if (s.hwdec.trim().toLowerCase() == 'no') {
    warnings.add('当前为软解（CPU 解码）：高码率/高分辨率可能掉帧发热');
  }
  final avsync = s.avsync;
  if (avsync != null && avsync.abs() > kAvsyncWarnSec) {
    warnings.add('音画不同步：${formatDiagnosticAvsync(avsync)}');
  }
  final mistimed = s.mistimedFrames ?? 0;
  if (mistimed > 0) {
    warnings.add('时间戳异常帧 $mistimed 帧：源本身可能有问题');
  }
  return warnings;
}
