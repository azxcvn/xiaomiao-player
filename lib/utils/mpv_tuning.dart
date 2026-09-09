/// mpv 移动端缓存/网络调参模板（对齐 mpvRx `MPVView.initOptions`）。
///
/// 纯函数返回「mpv 属性名 → 值」表，由播放页在 **open 之前**写入（open 之后再
/// 写对当前文件的解封装器无效）。本地与在线来源走不同档：在线加大解封装缓存、
/// 开启有界重连、放宽连接超时；本地只做与来源无关的播放平滑项。
///
/// ⚠️ `demuxer-lavf-o` 必须与 media_kit 已写入的值**合并**再设置——该属性是
/// 整串覆盖，而 media_kit 在里面放了 `protocol_whitelist=[udp,rtp,...]`
/// （值内含逗号）。直接覆盖会让 m3u8/自定义协议失效；读不到旧值时**宁可不设**
/// 也不冒险覆盖（[mergeDemuxerLavfOptions] 返回 null）。
library;

/// 本地文件解封装缓存上限（字节）：沿用 media_kit 默认 32MiB，显式写入保证确定性。
const int kLocalDemuxerMaxBytes = 32 * 1024 * 1024;

/// 在线来源解封装缓存上限（字节，64MiB）：弱网下多攒一点，减少卡顿。
const int kOnlineDemuxerMaxBytes = 64 * 1024 * 1024;

/// 在线来源「回看缓存」上限（字节，32MiB）：拖动回退时不必重新拉流。
const int kOnlineDemuxerBackBytes = 32 * 1024 * 1024;

/// 本地「回看缓存」上限（字节）：与 media_kit 默认一致。
const int kLocalDemuxerBackBytes = 32 * 1024 * 1024;

/// 在线来源写入 `demuxer-lavf-o` 的有界重连参数（FFmpeg http 协议 AVOption）。
///
/// **明确不用 `reconnect_at_eof`**：合法 VOD 的 EOF 必须正常结束，
/// 否则播完会一直重连、永远不触发「播放完毕」（mpvRx 同款决策）。
const Map<String, String> kOnlineLavfOverrides = {
  'http_persistent': '0',
  'reconnect': '1',
  'reconnect_on_network_error': '1',
  'reconnect_streamed': '1',
  'reconnect_delay_max': '5',
  'reconnect_max_retries': '5',
  'reconnect_delay_total_max': '20',
};

/// 构造本次 open 要写入的 mpv 调参表。
///
/// [existingDemuxerLavfO] 为当前 `demuxer-lavf-o` 的值（读取失败传 null）——
/// 仅在线档需要合并重连参数；读不到时该键整体不写入。
Map<String, String> buildMpvTuning({
  required bool isOnline,
  String? existingDemuxerLavfO,
}) {
  final tuning = <String, String>{
    // 以音频为主时钟：24fps 内容在 60Hz 屏上不再周期性丢帧/抖动。
    'video-sync': 'audio',
    // 只丢「已晚于显示窗口」的帧：渲染跟不上时不再让抖动持续累积。
    'framedrop': 'vo',
  };
  if (isOnline) {
    tuning.addAll({
      // 流式播放开缓存 + 缓冲不足时暂停（避免「播一点卡一下」）。
      'cache': 'yes',
      'cache-pause': 'yes',
      'cache-pause-wait': '2',
      // media_kit 默认 5s 对弱网过于激进，放宽到 15s。
      'network-timeout': '15',
      'demuxer-max-bytes': '$kOnlineDemuxerMaxBytes',
      'demuxer-max-back-bytes': '$kOnlineDemuxerBackBytes',
      // 跟随 3xx（直链常见）。
      'http-allow-redirect': 'yes',
      // HLS 自适应码率，不强制拉最高码率（省流量/降发热）。
      'hls-bitrate': 'no',
    });
    final merged =
        mergeDemuxerLavfOptions(existingDemuxerLavfO, kOnlineLavfOverrides);
    if (merged != null) tuning['demuxer-lavf-o'] = merged;
  } else {
    tuning.addAll({
      'demuxer-max-bytes': '$kLocalDemuxerMaxBytes',
      'demuxer-max-back-bytes': '$kLocalDemuxerBackBytes',
    });
  }
  return tuning;
}

/// 把 [overrides] 合并进已有的 `demuxer-lavf-o` 串（保留其余键与原顺序）。
///
/// 返回 null 表示 [existing] 不可用（null/空）——此时调用方**必须**放弃设置该
/// 属性，否则会抹掉 media_kit 的 `protocol_whitelist`。
String? mergeDemuxerLavfOptions(
  String? existing,
  Map<String, String> overrides,
) {
  if (existing == null || existing.trim().isEmpty) return null;
  final entries = <String, String>{};
  for (final token in splitLavfOptions(existing)) {
    final eq = token.indexOf('=');
    if (eq < 0) {
      entries[token.trim()] = '';
    } else {
      entries[token.substring(0, eq).trim()] = token.substring(eq + 1).trim();
    }
  }
  for (final entry in overrides.entries) {
    // 覆盖已存在的键时保持原位置（LinkedHashMap 语义），新键追加到末尾
    entries[entry.key] = entry.value;
  }
  return entries.entries
      .map((e) => e.value.isEmpty ? e.key : '${e.key}=${e.value}')
      .join(',');
}

/// 按**顶层**逗号切分 `demuxer-lavf-o` 串（`[...]` 内的逗号不算分隔符）。
///
/// 例：`a=1,protocol_whitelist=[udp,rtp,tcp],b=2` → 3 段，
/// `protocol_whitelist=[udp,rtp,tcp]` 保持完整。
List<String> splitLavfOptions(String raw) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    if (ch == '[' || ch == '{' || ch == '(') {
      depth++;
    } else if (ch == ']' || ch == '}' || ch == ')') {
      if (depth > 0) depth--;
    }
    if (ch == ',' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  parts.add(buffer.toString());
  return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}
