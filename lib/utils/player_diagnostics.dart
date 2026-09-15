/// 播放诊断的纯函数层：采样属性清单 + 数值格式化 + 健康判定。
///
/// 面板（`pages/player/views/player_diagnostics_panel.dart`）只负责定时调用
/// 属性读取回调并渲染，本文件所有函数无状态、可单测（§5.5 约定）。
library;

import 'dart:convert';

import 'package:moumou/models/player_diagnostics.dart';

/// 播放诊断需要读取的 mpv 属性（一次采样全读一遍）。
///
/// 全部是 mpv 公开属性，缺失/不支持时读取回调返回 null，面板显示 `—`。
///
/// 已移除（真机实测在该 libmpv 构建 + Android 纹理输出下**永远读不到**）：
/// `display-fps`（屏幕刷新率）、`mistimed-frame-count`（时间戳异常帧）、
/// `vsync-jitter`（VSync 抖动）、`video-codec`（视频编码——MediaCodec 解码
/// 路径下 mpv 不填充该属性；需要编码信息请走 `video_info_service`（MediaInfo））。
const List<String> kPlayerDiagnosticsProperties = [
  'media-title',
  'file-format',
  'audio-codec-name',
  'width',
  'height',
  'video-params/pixelformat',
  'container-fps',
  'estimated-vf-fps',
  'hwdec-current',
  'current-vo',
  // 实际生效的图形后端（`android` = OpenGL ES / `androidvk` = Vulkan）。
  // 这是**运行时实测值**而非设置值：用户开了 Vulkan 后，本项仍可能是
  // `android`（未生效或已回退），是判断「Vulkan 开关到底有没有用」的唯一依据。
  'current-gpu-context',
  'video-sync',
  // ⚠️ 是 frame-drop-count（丢帧数），**不是** drop-frame-count。
  // mpv 从未有过 drop-frame-count 属性，写错会永远读到空值（历史 bug）。
  'frame-drop-count',
  'decoder-frame-drop-count',
  'vo-delayed-frame-count',
  'demuxer-cache-duration',
  'demuxer-cache-time',
  // ⚠️ 缓存字节数取自**整表 JSON**（`fw-bytes` 字段）：实测该构建下
  // `demuxer-cache-state/fw-bytes` 这类 map 子属性路径一律返回空串
  // （详见 [parseDemuxerCacheBytes]）。注意缓存状态仅在**流式缓存启用**
  // 时才有值。
  'demuxer-cache-state',
  'cache-speed',
  'video-bitrate',
  'audio-bitrate',
  'audio-params',
  'avsync',
];

/// 属性清单里**读取失败时**用这个哨兵值，而不是 null 或 `'--'`。
///
/// 为了能在真机日志里区分三种状态：
/// - `null`：没读（该键根本不在清单里）
/// - `kDiagnosticUnreadable`：读了，但 mpv 返回不可用
/// - 其它值：真的读到了
///
/// 排查缓存字段时正因缺了这一层，才分不清"读不到"与"读到了但是空串"。
const String kDiagnosticUnreadable = '<unreadable>';

/// 空值占位符（属性缺失 / 播放器未就绪）
const String kDiagnosticPlaceholder = '—';

/// 该值是否算「读到了」：非 null、非空串、非 `--`（mpv 的不可用占位）、
/// 非 [kDiagnosticUnreadable]（读取失败哨兵）。
///
/// ⚠️ 面板注入的读取回调**不可读时必须返回 [kDiagnosticUnreadable]**（或 null），
/// 否则空串会被当成"合法值"覆盖掉上一次的好值（历史 bug）。
bool isDiagnosticValueAvailable(String? value) {
  if (value == null) return false;
  if (value == kDiagnosticUnreadable) return false;
  final t = value.trim();
  return t.isNotEmpty && t != '--';
}

/// 合并两次采样：**当前读到值就用当前值，否则保留上一次的值**。
///
/// 仅遍历 [kPlayerDiagnosticsProperties]（声明过的键），保证兜底值不会来自
/// 未知键；同时让键序稳定（便于快照解析与测试断言）。
///
/// 用途：mpv 在播放管线异常时会成片返回不可读属性，此时面板若把空值直接
/// 覆盖进快照，就会从「一串正常数值」瞬间变成「一片横杠」——**用户无法区分
/// "属性真的变成空了" 和 "这次没读到"**。保留上次值 + 顶部列出失败键名，
/// 排障信息才可信。
Map<String, String?> mergeDiagnosticsRaw({
  required Map<String, String?> previous,
  required Map<String, String?> current,
}) {
  final out = <String, String?>{};
  for (final key in kPlayerDiagnosticsProperties) {
    final v = current[key];
    if (isDiagnosticValueAvailable(v)) {
      out[key] = v;
    } else {
      // 本次不可读：保留上一次的值；没有则写 null（面板显示占位符）。
      // 注意不能把 [kDiagnosticUnreadable] 哨兵透传进快照（会显示成怪字符串）。
      final prev = previous[key];
      out[key] = isDiagnosticValueAvailable(prev) ? prev : null;
    }
  }
  return out;
}

/// 从 mpv `demuxer-cache-state` 的 **JSON 字符串**里取缓存占用字节。
///
/// ## 为什么不用子属性路径
///
/// ⚠️ 实测（真机 debug 日志，2026-09）：`mpv_get_property_string` 读
/// `demuxer-cache-state/fw-bytes`、`.../file-cache-bytes`、`.../cache-duration`
/// **一律返回空串**，而读整表 `demuxer-cache-state` 会返回一段完整 JSON
/// （字段名带连字符）：
///
/// ```json
/// {"cache-end":116.1,"cache-duration":100.2,"total-bytes":76388800,
///  "fw-bytes":67109120,"raw-input-rate":912160, ...}
/// ```
///
/// 即**该构建下 map 型属性的子属性访问不可用**（`video-params/pixelformat`
/// 之类的原生子属性不受影响）。所以取字节数只能读整表再解析。
///
/// 优先 `fw-bytes`（前向缓存，即"已缓冲可播"部分；旧版 mpv 名
/// `file-cache-bytes`，当前构建里没有该字段），缺失时退回 `total-bytes`。
/// 解析失败/字段缺失返回 null（面板显示占位符）。
int? parseDemuxerCacheBytes(String? demuxerCacheStateJson) {
  if (demuxerCacheStateJson == null) return null;
  final text = demuxerCacheStateJson.trim();
  if (text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;
    // 字段名兼容连字符与下划线两种写法（mpv 版本差异）
    for (final key in const ['fw-bytes', 'fw_bytes', 'file-cache-bytes',
      'file_cache_bytes', 'total-bytes', 'total_bytes']) {
      final v = decoded[key];
      if (v is int) return v;
      if (v is num) return v.round();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// 本次采样中**不可读**的属性名（已排序，供面板警示卡列出）。
///
/// 入参是页面读到的原始表（不可读值为 [kDiagnosticUnreadable] 或 null）。
List<String> failedDiagnosticsKeys(Map<String, String?> raw) {
  final failed = <String>[
    for (final key in kPlayerDiagnosticsProperties)
      if (!isDiagnosticValueAvailable(raw[key])) key,
  ];
  failed.sort();
  return failed;
}

/// 把不可读项的**原始值**附在键名后（真机日志用）：`key=<unreadable>` /
/// `key=''` / `key='value'`，一眼分清"读不到"与"读到了但是空串"。
String describeDiagnosticKeys(
  Map<String, String?> raw,
  List<String> keys,
) {
  return keys.map((k) {
    final v = raw[k];
    if (v == null) return '$k=<missing>';
    return "$k='$v'";
  }).join(', ');
}

/// 带**别名回退**的属性：按顺序取第一个读到的值（都读不到返回 null）。
///
/// 目前为空（原缓存字节字段的别名回退已被 [parseDemuxerCacheBytes] 的
/// 整表 JSON 解析取代——实测子属性路径在该构建下不可用）。保留此机制，
/// 便于将来遇到同类「同一字段不同 mpv 版本不同名」的情况。
const Map<String, List<String>> kDiagnosticPropertyFallbacks = {};

/// 读取一组属性时的**实际**属性名清单：把 [kDiagnosticPropertyFallbacks]
/// 里的别名展开进去（去重、保持声明顺序）。
///
/// 面板侧只需按本清单逐个读、再交给 [pickDiagnosticValue] 取首个可用值，
/// 不必自己处理别名。主键名与别名都会被读取（成本可忽略：一次采样几十次
/// 属性读取，且别名读不到时 mpv 立即返回空）。
List<String> expandDiagnosticPropertyNames() {
  final out = <String>[];
  for (final key in kPlayerDiagnosticsProperties) {
    final aliases = kDiagnosticPropertyFallbacks[key];
    if (aliases == null) {
      out.add(key);
    } else {
      for (final a in aliases) {
        if (!out.contains(a)) out.add(a);
      }
    }
  }
  return out;
}

/// 按 [kDiagnosticPropertyFallbacks] 的别名顺序取首个可用值。
///
/// 返回 `主键名 → 值`（都读不到则为 null），结果统一挂在**主键名**上，
/// 供快照解析读取（读取时用到的别名不会泄漏进快照）。
Map<String, String?> pickDiagnosticValue(Map<String, String?> raw, String key) {
  final aliases = kDiagnosticPropertyFallbacks[key] ?? [key];
  for (final a in aliases) {
    final v = raw[a];
    if (isDiagnosticValueAvailable(v)) return {key: v};
  }
  return {key: null};
}

/// 文本：空/占位归一（与 [isDiagnosticValueAvailable] 同一套判定）。
String formatDiagnosticText(String? value) {
  if (!isDiagnosticValueAvailable(value)) return kDiagnosticPlaceholder;
  return value!.trim();
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
///
/// 目前运行时无调用点（原唯一使用者是已移除的「VSync 抖动」行），保留供面板
/// 将来新增毫秒口径指标时复用；格式化函数属纯函数层，保留成本低。
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

/// 视频输出 + 实际图形后端 → `gpu-next · androidvk`。
///
/// 两者都缺失时返回占位符；只有其一可用时只显示可用的那个（不显示
/// `gpu-next · —` 这类半截值，避免误读成「后端未知」）。
///
/// [gpuContext] 是 mpv `current-gpu-context` 的实测值：`android` = OpenGL ES、
/// `androidvk` = Vulkan。这是判断「Vulkan 开关是否真的生效」的唯一依据。
String formatVideoOutput(String? vo, String? gpuContext) {
  final v = formatDiagnosticText(vo);
  final g = formatDiagnosticText(gpuContext);
  final hasV = v != kDiagnosticPlaceholder;
  final hasG = g != kDiagnosticPlaceholder;
  if (hasV && hasG) return '$v · $g';
  if (hasV) return v;
  if (hasG) return g;
  return kDiagnosticPlaceholder;
}

/// 音画同步偏差（秒）→ `+12 ms 音频超前` / `-8 ms 视频超前`。
String formatDiagnosticAvsync(double? seconds) {
  if (seconds == null) return kDiagnosticPlaceholder;
  final ms = seconds * 1000;
  final sign = ms >= 0 ? '+' : '-';
  final label = ms >= 0 ? '音频超前' : '视频超前';
  return '$sign${ms.abs().toStringAsFixed(0)} ms $label';
}

/// 音画同步偏差告警阈值（秒）：超过 100ms 人耳可感知。
const double kAvsyncWarnSec = 0.1;

/// 健康提示（纯函数）：按优先级返回需要用户注意的现象，无异常返回空列表。
///
/// 用于面板顶部把「哪里不健康」直接讲清楚，排障不必逐行读数字（§4.27）。
///
/// 注：原「VSync 抖动偏高」与「时间戳异常帧」两条告警已移除——它们依赖的
/// `vsync-jitter` / `mistimed-frame-count` 在 Android 纹理输出下**永远读不到**
/// （真机实测），告警无从触发。
List<String> diagnosticsWarnings(PlayerDiagnosticsSnapshot s) {
  final warnings = <String>[];
  final dropped = s.droppedFrames ?? 0;
  if (dropped > 0) {
    warnings.add('已丢帧 $dropped 帧：渲染跟不上，可尝试降超分档位或改硬解');
  }
  if (s.hwdec.trim().toLowerCase() == 'no') {
    warnings.add('当前为软解（CPU 解码）：高码率/高分辨率可能掉帧发热');
  }
  final avsync = s.avsync;
  if (avsync != null && avsync.abs() > kAvsyncWarnSec) {
    warnings.add('音画不同步：${formatDiagnosticAvsync(avsync)}');
  }
  return warnings;
}
