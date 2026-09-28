import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moumou/utils/async_single_flight.dart';

/// 视频信息：时长 + 缩略图路径
class VideoInfo {
  final int durationMs;
  final String? thumbPath;

  const VideoInfo({required this.durationMs, this.thumbPath});
}

/// 视频基本媒体元数据（来自 MediaInfoLib 快速解析，列表字段用）：
/// 帧率 + 内嵌字幕信息。
class VideoBasicMetadata {
  final double frameRate;
  final bool hasEmbeddedSubtitles;
  final String subtitleCodec;

  const VideoBasicMetadata({
    this.frameRate = 0,
    this.hasEmbeddedSubtitles = false,
    this.subtitleCodec = '',
  });

  bool get hasAnyInfo => frameRate > 0 || hasEmbeddedSubtitles;
}

/// 通过原生 MediaMetadataRetriever / MediaInfoLib 获取视频信息
class VideoInfoService {
  static const _channel = MethodChannel('moumou/video_info');

  /// 内存缓存：避免列表滚动往返时重复跨进程调用
  static final Map<String, VideoInfo> _cache = {};

  /// 基本元数据内存缓存（帧率 / 字幕）
  static final Map<String, VideoBasicMetadata> _metaCache = {};

  /// 时长兜底内存缓存（`getVideoDuration`，见 [getDuration]）
  static final Map<String, int> _durationCache = {};

  /// 「问过、拿不到」的**负结果记忆**（`getVideoDuration` 返回 0），记的是
  /// **失败时刻**而不是「永久拉黑」（路径 → 失败时刻毫秒）。
  ///
  /// 有一类文件（损坏 / 非标准容器，真机日志里的 `csd0 too small`）抽时长必定
  /// 失败：原生先试 MediaInfoLib、失败再退系统 `MediaMetadataRetriever`，两边都
  /// 拿不到。不记住的话，卡片每次被重建（滚走再滚回来）都会再完整问一遍原生 ——
  /// 滚动往返就是反复无意义的读取（issue #4）。
  ///
  /// 但**不能永久记**：卡一时忙、瞬间读失败这类是**瞬时**失败，永久钉死就表现为
  /// 「这部片子永远显示未观看」（静默数据损坏）。所以只在 [durationMissTtlMs] 内
  /// 沿用，过期允许再试一次；原生侧同一份磁盘缓存也是同样的 TTL。
  ///
  /// 只活在进程内（不落盘）；通道异常**不**记负结果（那是原生还没起来之类的
  /// 临时故障，下次该重试）。
  static final Map<String, int> _durationMisses = {};

  /// 「拿不到时长」这个结论的沿用时长，与原生侧 `durationFailureTtlMs` 同一套语义。
  ///
  /// 不是 `const`：测试要能把它调成 0 来验证「过期就允许再试」，否则这条路径
  /// 只能靠等 24 小时才能测到。
  @visibleForTesting
  static int durationMissTtlMs = 24 * 60 * 60 * 1000;

  /// [path]「拿不到时长」的结论是否还在 TTL 内（过期就顺手清掉，允许重试）
  static bool _isDurationMissFresh(String path) {
    final failedAtMs = _durationMisses[path];
    if (failedAtMs == null) return false;
    if (DateTime.now().millisecondsSinceEpoch - failedAtMs < durationMissTtlMs) {
      return true;
    }
    _durationMisses.remove(path);
    return false;
  }

  /// 在飞去重：同 path 的并发请求共享同一个 Future（列表首屏几十张卡片
  /// 同时发起时只发一次跨进程调用，见 risk_audit #5）。
  /// 走公共原语 [AsyncSingleFlight]（§4.29）。
  static final AsyncSingleFlight<VideoInfo> _infoFlight = AsyncSingleFlight();

  /// 基本元数据在飞去重（同上）
  static final AsyncSingleFlight<VideoBasicMetadata> _metaFlight =
      AsyncSingleFlight();

  /// 时长兜底在飞去重（同上）
  static final AsyncSingleFlight<int> _durationFlight = AsyncSingleFlight();

  /// 清理视频信息与基本元数据内存缓存。
  /// 若指定 [path]，只清理该路径对应的缓存项；若为 null，则清空全部内存缓存。
  static void clearCache([String? path]) {
    if (path != null) {
      _cache.remove(path);
      _metaCache.remove(path);
      _durationCache.remove(path);
      _durationMisses.remove(path);
    } else {
      _cache.clear();
      _metaCache.clear();
      _durationCache.clear();
      _durationMisses.clear();
    }
  }

  static Future<VideoInfo> get(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    return _infoFlight.run(path, () => _fetchInfo(path));
  }

  static Future<VideoInfo> _fetchInfo(String path) async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getVideoInfo', {'path': path});
      final info = VideoInfo(
        durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
        thumbPath: result?['thumbPath'] as String?,
      );
      _cache[path] = info;
      return info;
    } catch (_) {
      // 原生异常（文件不存在、权限或解析失败）：返回安全兜底，且不存入 _cache 允许后续重试
      return const VideoInfo(durationMs: 0, thumbPath: null);
    }
  }

  /// 获取视频时长（毫秒；失败 / 未知返回 0）。
  ///
  /// 用途：`VideoScanner` 的时长来自 MediaStore，而 `.nomedia` / 隐藏文件夹 /
  /// 外置卷里的视频靠原生**文件系统补扫**只拿到路径与大小（补扫只枚举、不开容器，
  /// 见 `FsVideoWalker`），那些条目时长恒为 0。列表卡片的「未观看 / 进度条 /
  /// 时长标签」全靠时长判定，所以卡片对时长未知的视频按需调这里补一次
  /// ——只读容器元数据、不抓帧/不解码，且原生侧带磁盘缓存与单文件超时。
  ///
  /// 缓存与 [get] 同纪律：成功才入内存缓存（失败允许下次重试）。
  /// 另有一条**带 TTL 的负结果记忆**：原生明确回 0（问过了、真拿不到）时记下
  /// 失败时刻，[durationMissTtlMs] 内不再重复问（见 [_durationMisses]）；
  /// 通道异常不记。
  static Future<int> getDuration(String path) async {
    final cached = _durationCache[path];
    if (cached != null) return cached;
    if (_isDurationMissFresh(path)) return 0;
    return _durationFlight.run(path, () => _fetchDuration(path));
  }

  static Future<int> _fetchDuration(String path) async {
    try {
      // 原生直接回毫秒整数（与 getVideoInfo 的 map 不同：这里只有一个值）
      final ms = await _channel.invokeMethod<int>('getVideoDuration', {
        'path': path,
      });
      final value = ms ?? 0;
      if (value > 0) {
        _durationCache[path] = value;
        _durationMisses.remove(path);
      } else {
        // 记失败**时刻**：TTL 内不再问，过期允许再试（见 [_durationMisses]）
        _durationMisses[path] = DateTime.now().millisecondsSinceEpoch;
      }
      return value;
    } catch (_) {
      return 0;
    }
  }

  /// 获取视频基本媒体元数据（帧率 / 内嵌字幕，MediaInfoLib 快速解析 + 磁盘缓存）。
  /// 失败返回空元数据，调用方自行降级（不显示字段）。
  static Future<VideoBasicMetadata> getBasicMetadata(String path) async {
    final cached = _metaCache[path];
    if (cached != null) return cached;
    return _metaFlight.run(path, () => _fetchBasicMetadata(path));
  }

  static Future<VideoBasicMetadata> _fetchBasicMetadata(String path) async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getVideoBasicMetadata', {
        'path': path,
      });
      final meta = VideoBasicMetadata(
        frameRate: (result?['frameRate'] as num?)?.toDouble() ?? 0,
        hasEmbeddedSubtitles: result?['hasSubtitles'] as bool? ?? false,
        subtitleCodec: result?['subtitleCodec'] as String? ?? '',
      );
      _metaCache[path] = meta;
      return meta;
    } catch (_) {
      return const VideoBasicMetadata();
    }
  }

  /// 获取视频完整媒体信息（MediaInfoLib，用于媒体信息页）
  static Future<Map<String, dynamic>?> getMediaInfo(String path) async {
    try {
      return await _channel
          .invokeMapMethod<String, dynamic>('getMediaInfo', {'path': path});
    } catch (_) {
      return null;
    }
  }

  /// 检测视频是否包含杜比视界（Dolby Vision）视频轨（MediaInfoLib）。
  /// 返回 (是否杜比视界, 命中的 HDR 描述)；失败返回 (false, '')。
  static Future<({bool isDolbyVision, String hdrFormat})> detectDolbyVision(
    String path,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'detectDolbyVision',
        {'path': path},
      );
      return (
        isDolbyVision: result?['isDolbyVision'] as bool? ?? false,
        hdrFormat: result?['hdrFormat'] as String? ?? '',
      );
    } catch (_) {
      return (isDolbyVision: false, hdrFormat: '');
    }
  }
}
