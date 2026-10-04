/// mpv 移动端缓存/网络调参模板（对齐 mpvRx `MPVView.initOptions`）。
///
/// 纯函数返回「mpv 属性名 → 值」表，由播放页在 **open 之前**写入（open 之后再
/// 写对当前文件的解封装器无效）。本地与在线来源走不同档：在线加大解封装缓存、
/// 开启有界重连、放宽连接超时；本地只做与来源无关的播放平滑项。
///
/// ⚠️ **`demuxer-lavf-o` 必须整串重建，不能「读回来再合并」**（2026-10 实测教训）：
/// 该属性是 keyvalue-list，mpv 读回来时**方括号会丢**，实测得到
/// `protocol_whitelist=udp,rtp,tcp,...`；按「括号内逗号不切分」去合并会把列表值
/// 切碎，写回去只剩 `protocol_whitelist=udp` —— 之后**所有 http/https 都被 ffmpeg
/// 拒掉**（`Protocol 'https' not on whitelist 'udp'`），在线播放全军覆没。
/// 本地文件不走这条路，所以这个坑藏了很久。
/// 现在按 [kPlaybackProtocolWhitelist] 显式重建：[buildDemuxerLavfO]。
library;

/// 本地文件解封装缓存上限（字节）：沿用 media_kit 默认 32MiB，显式写入保证确定性。
const int kLocalDemuxerMaxBytes = 32 * 1024 * 1024;

/// 在线来源解封装缓存上限（字节，64MiB）：弱网下多攒一点，减少卡顿。
const int kOnlineDemuxerMaxBytes = 64 * 1024 * 1024;

/// 在线来源「回看缓存」上限（字节，32MiB）：拖动回退时不必重新拉流。
const int kOnlineDemuxerBackBytes = 32 * 1024 * 1024;

/// 本地「回看缓存」上限（字节）：与 media_kit 默认一致。
const int kLocalDemuxerBackBytes = 32 * 1024 * 1024;

/// 允许的协议白名单（写入 `demuxer-lavf-o` 时必须用 `[...]` 包起来）。
///
/// 前 9 项与 media_kit 的 `PlayerConfiguration.protocolWhitelist` **默认值一致**
/// （`third_party/media_kit/lib/src/player/platform_player.dart`）；后 8 项是本项目
/// 「打开链接 / 外部直链」允许直接播放的协议（见 `utils/url_media.dart`）。
///
/// [kPlaybackProtocolWhitelist] 同时传给 `PlayerConfiguration.protocolWhitelist`
/// （创建播放器时 media_kit 自己会写一次），保证「创建期」与「open 前重建」两处
/// 白名单始终一致。
const List<String> kPlaybackProtocolWhitelist = [
  // media_kit 默认（勿删：udp/rtp 是它特意补上的）
  'udp',
  'rtp',
  'tcp',
  'tls',
  'data',
  'file',
  'http',
  'https',
  'crypto',
  // 本项目直接播放协议白名单
  'rtmp',
  'rtmps',
  'rtsp',
  'rtsps',
  'mms',
  'mmst',
  'mmsh',
  'ftp',
];

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

/// 重建 `demuxer-lavf-o` 整串（整串覆盖是安全的：内容我们自己拼，白名单在 [kPlaybackProtocolWhitelist]）。
///
/// 组成：media_kit 的三项默认值（`seg_max_retry` / `strict` / `allowed_extensions`）
/// + 协议白名单 +（在线档）[kOnlineLavfOverrides]。
String buildDemuxerLavfO({required bool isOnline}) {
  final entries = <String>[
    'seg_max_retry=5',
    'strict=experimental',
    'allowed_extensions=ALL',
    'protocol_whitelist=[${kPlaybackProtocolWhitelist.join(',')}]',
  ];
  if (isOnline) {
    for (final entry in kOnlineLavfOverrides.entries) {
      entries.add('${entry.key}=${entry.value}');
    }
  }
  return entries.join(',');
}

/// 构造本次 open 要写入的 mpv 调参表。
///
/// [tlsCaFile] 为沙盒内 CA 证书库的绝对路径（见 `TlsCaBundle`）：自编 libmpv 的
/// mbedTLS 后端没有默认证书库路径，不给它就会让**所有 https 在证书校验阶段失败**
/// （http 正常）。为空/null 时该键不写入。
Map<String, String> buildMpvTuning({
  required bool isOnline,
  String? tlsCaFile,
}) {
  final tuning = <String, String>{
    // 以音频为主时钟：24fps 内容在 60Hz 屏上不再周期性丢帧/抖动。
    'video-sync': 'audio',
    // 只丢「已晚于显示窗口」的帧：渲染跟不上时不再让抖动持续累积。
    'framedrop': 'vo',
  };
  // CA 证书库：与来源无关（本地用不到，但设了无害），统一在这里写入。
  if (tlsCaFile != null && tlsCaFile.isNotEmpty) {
    tuning['tls-ca-file'] = tlsCaFile;
  }
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
      // 解封装器与协议白名单：**整串重建**（见文件头说明），不能读回来再合并。
      'demuxer-lavf-o': buildDemuxerLavfO(isOnline: true),
    });
  } else {
    tuning.addAll({
      'demuxer-max-bytes': '$kLocalDemuxerMaxBytes',
      'demuxer-max-back-bytes': '$kLocalDemuxerBackBytes',
    });
  }
  return tuning;
}
