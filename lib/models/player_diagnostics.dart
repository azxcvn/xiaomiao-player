/// 播放器运行时诊断快照（mpv 属性 → 纯数据模型）。
///
/// 只做容错解析（数字字段可能是字符串/缺失/NaN），不含任何业务逻辑与 UI 依赖；
/// 展示格式化与健康判定在 `utils/player_diagnostics.dart`。
library;

/// 一次采样得到的播放诊断快照（字段缺失为 null，字符串缺失为 `--`）。
class PlayerDiagnosticsSnapshot {
  /// 媒体标题（mpv `media-title`）
  final String mediaTitle;

  /// 容器/文件格式（mpv `file-format`）
  final String fileFormat;

  /// 视频编码（含 profile，mpv `video-codec`）
  final String videoCodec;

  /// 音频编码（mpv `audio-codec-name`）
  final String audioCodec;

  /// 视频宽度 / 高度（mpv `width` / `height`，像素）
  final int? width;
  final int? height;

  /// 像素格式（mpv `video-params/pixelformat`，如 yuv420p / p010）
  final String pixelFormat;

  /// 容器声明的帧率（mpv `container-fps`）
  final double? containerFps;

  /// 解码+滤镜后实际输出帧率（mpv `estimated-vf-fps`）
  final double? estimatedFps;

  /// 显示刷新率（mpv `display-fps`）
  final double? displayFps;

  /// 当前生效的硬解模式（mpv `hwdec-current`；`no` = 软解）
  final String hwdec;

  /// 当前视频输出驱动（mpv `current-vo`）
  final String vo;

  /// 视频同步方式（mpv `video-sync`）
  final String videoSync;

  /// 累计丢帧数（mpv `drop-frame-count`）
  final int? droppedFrames;

  /// 解码器丢帧数（mpv `decoder-frame-drop-count`）
  final int? decoderDroppedFrames;

  /// 显示队列中延迟的帧数（mpv `vo-delayed-frame-count`）
  final int? delayedFrames;

  /// 延迟帧平均等待时长（mpv `vo-delayed-frame-average-ms`，毫秒）
  final double? delayedFrameAverageMs;

  /// 时间戳错乱帧数（mpv `mistimed-frame-count`）
  final int? mistimedFrames;

  /// 解封装缓存已缓冲的时长（mpv `demuxer-cache-duration`，秒）
  final double? demuxerCacheDurationSec;

  /// 当前位置在缓存中的剩余可播时长（mpv `demuxer-cache-time`，秒）
  final double? demuxerCacheTimeSec;

  /// 已占用的解封装缓存字节（mpv `cache-used`）
  final int? cacheUsedBytes;

  /// 当前下行速率估计（mpv `cache-speed`，字节/秒）
  final double? cacheSpeedBytesPerSec;

  /// 视频码率（mpv `video-bitrate`，bit/s）
  final int? videoBitrate;

  /// 音频码率（mpv `audio-bitrate`，bit/s）
  final int? audioBitrate;

  /// 音频参数描述（mpv `audio-params`，如 `48000Hz stereo float`）
  final String audioParams;

  /// 音画同步偏差（mpv `avsync`，秒；正 = 音频超前）
  final double? avsync;

  const PlayerDiagnosticsSnapshot({
    this.mediaTitle = '--',
    this.fileFormat = '--',
    this.videoCodec = '--',
    this.audioCodec = '--',
    this.width,
    this.height,
    this.pixelFormat = '--',
    this.containerFps,
    this.estimatedFps,
    this.displayFps,
    this.hwdec = '--',
    this.vo = '--',
    this.videoSync = '--',
    this.droppedFrames,
    this.decoderDroppedFrames,
    this.delayedFrames,
    this.delayedFrameAverageMs,
    this.mistimedFrames,
    this.demuxerCacheDurationSec,
    this.demuxerCacheTimeSec,
    this.cacheUsedBytes,
    this.cacheSpeedBytesPerSec,
    this.videoBitrate,
    this.audioBitrate,
    this.audioParams = '--',
    this.avsync,
  });

  /// 从 mpv 属性表构造（键为属性名，值为 [NativePlayer.getProperty] 结果）。
  ///
  /// 所有字段容错：缺失/null/空串 → 默认值；数字兼容字符串（`String is not a
  /// subtype of num` 类崩溃防护，对齐 `bili_bangumi.dart` 的 `_asInt/_asDouble`）。
  factory PlayerDiagnosticsSnapshot.fromProperties(
    Map<String, String?> properties,
  ) {
    String text(String key, {String fallback = '--'}) {
      final v = properties[key];
      if (v == null) return fallback;
      final t = v.trim();
      return t.isEmpty ? fallback : t;
    }

    return PlayerDiagnosticsSnapshot(
      mediaTitle: text('media-title'),
      fileFormat: text('file-format'),
      videoCodec: text('video-codec'),
      audioCodec: text('audio-codec-name'),
      width: _asInt(properties['width']),
      height: _asInt(properties['height']),
      pixelFormat: text('video-params/pixelformat'),
      containerFps: _asDouble(properties['container-fps']),
      estimatedFps: _asDouble(properties['estimated-vf-fps']),
      displayFps: _asDouble(properties['display-fps']),
      hwdec: text('hwdec-current'),
      vo: text('current-vo'),
      videoSync: text('video-sync'),
      droppedFrames: _asInt(properties['drop-frame-count']),
      decoderDroppedFrames: _asInt(properties['decoder-frame-drop-count']),
      delayedFrames: _asInt(properties['vo-delayed-frame-count']),
      delayedFrameAverageMs:
          _asDouble(properties['vo-delayed-frame-average-ms']),
      mistimedFrames: _asInt(properties['mistimed-frame-count']),
      demuxerCacheDurationSec: _asDouble(properties['demuxer-cache-duration']),
      demuxerCacheTimeSec: _asDouble(properties['demuxer-cache-time']),
      cacheUsedBytes: _asInt(properties['cache-used']),
      cacheSpeedBytesPerSec: _asDouble(properties['cache-speed']),
      videoBitrate: _asInt(properties['video-bitrate']),
      audioBitrate: _asInt(properties['audio-bitrate']),
      audioParams: text('audio-params'),
      avsync: _asDouble(properties['avsync']),
    );
  }

  static int? _asInt(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final parsed = int.tryParse(t);
    if (parsed != null) return parsed;
    final d = double.tryParse(t);
    if (d == null || !d.isFinite) return null;
    return d.round();
  }

  static double? _asDouble(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || !d.isFinite) return null;
    return d;
  }
}
