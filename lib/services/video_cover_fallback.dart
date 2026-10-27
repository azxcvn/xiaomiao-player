import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moumou/services/fast_thumbnails.dart';
import 'package:moumou/services/video_info_service.dart';

/// 本地视频封面兜底（列表卡片）。
///
/// 为什么需要：列表封面由原生 `getVideoInfo` 用 `MediaMetadataRetriever` 生成，
/// 而它只有系统抽取器可用 —— AVI（RIFF）/ ASF（WMV）这类老容器系统根本不认，
/// 那几个文件就只能显示占位图。自建 libmpv 里的 FFmpeg 认得这些格式（进度条
/// 预览、听视频封面走的是同一条链），所以这里在原生拿不到封面时补一帧：
/// 抓帧（RGBA）→ 交原生裁剪压缩成 384×216 的 JPEG 落进 `cacheDir/thumbs/`，
/// 之后就和普通封面一样，走原生的磁盘缓存与缓存清理，不用另开一套。
///
/// 调度要点：自建内核的抓帧队列是「后来的顶掉排队的」（为拖动预览设计），
/// 这里必须**自己串行**，否则一屏卡片的请求会互相顶掉、几乎全都拿不到图；
/// 真被顶掉（stale）的按退避重排，不当失败。
class VideoCoverFallback {
  VideoCoverFallback._();

  static const _channel = MethodChannel('moumou/video_info');

  /// 抓帧最长边：封面目标 384×216。取 640 是为了竖屏源裁成 16:9 时宽度也够
  /// （要填满 384 宽，竖屏 9:16 的源最长边得 683）。
  static const int _grabDimension = 640;

  /// 抓帧被顶掉后的重排次数上限（拖动预览一停就轮得到）
  static const int _maxStaleRetries = 3;

  /// 生成失败后的冷却：同一文件短时间内不再重抓（卡片重建、滚动往返都会重挂）
  static const int _failureCooldownMs = 10 * 60 * 1000;

  /// 已生成的封面：视频路径 → 封面文件绝对路径（文件被清掉时按不存在重来）
  static final Map<String, String> _covers = {};

  /// 生成失败时刻：视频路径 → 毫秒时间戳（见 [_failureCooldownMs]）
  static final Map<String, int> _failures = {};

  /// 在途/排队请求：同一路径合并成一次（卡片重建不重复抓帧）
  static final Map<String, Completer<String?>> _inflight = {};

  static final Queue<_CoverRequest> _queue = Queue();

  static bool _running = false;

  /// 测试用：替换抓帧入口（宿主环境没有 Android libmpv，默认必然拿不到帧）
  @visibleForTesting
  static Future<GrabOutcome> Function(String path, double seconds)?
      debugGrabOverride;

  /// 取 [path] 的封面（本地视频）。返回封面文件绝对路径，拿不到返回 null。
  ///
  /// [durationMs] 是已知片长（抓帧位置取 1/4 处），未知传 0，内部会问一次原生
  /// 时长（`getVideoDuration`，与卡片同一条缓存）。
  static Future<String?> resolve(String path, {int durationMs = 0}) {
    final cached = _covers[path];
    if (cached != null) {
      // 缓存清理 / 文件被删都可能让旧封面消失：还在才认，否则重新生成
      if (File(cached).existsSync()) return Future.value(cached);
      _covers.remove(path);
    }
    final failedAt = _failures[path];
    if (failedAt != null &&
        DateTime.now().millisecondsSinceEpoch - failedAt <
            _failureCooldownMs) {
      return Future.value(null);
    }
    final pending = _inflight[path];
    if (pending != null) return pending.future;

    final completer = Completer<String?>();
    _inflight[path] = completer;
    _queue.add(_CoverRequest(path, durationMs, completer));
    _pump();
    return completer.future;
  }

  /// 清掉 Dart 侧记录（清缓存 / 文件操作后调用）；不传 [path] 清全部。
  ///
  /// 只管内存映射，磁盘上的封面文件由原生 `clearCache` 的 listThumbs 分支删。
  static void clearCache([String? path]) {
    if (path != null) {
      _covers.remove(path);
      _failures.remove(path);
      return;
    }
    _covers.clear();
    _failures.clear();
  }

  /// 测试用：清空缓存、队列与抓帧覆盖
  @visibleForTesting
  static void debugReset() {
    for (final request in _queue) {
      if (!request.completer.isCompleted) request.completer.complete(null);
    }
    _queue.clear();
    _covers.clear();
    _failures.clear();
    _inflight.clear();
    _running = false;
    debugGrabOverride = null;
  }

  static void _pump() {
    if (_running || _queue.isEmpty) return;
    _running = true;
    _process(_queue.removeFirst());
  }

  static Future<void> _process(_CoverRequest request) async {
    String? cover;
    try {
      cover = await _generate(request);
    } catch (e) {
      debugPrint('[CoverFallback] ${request.path} 生成失败: $e');
      cover = null;
    }
    if (cover != null) {
      _covers[request.path] = cover;
      _failures.remove(request.path);
    } else {
      _failures[request.path] = DateTime.now().millisecondsSinceEpoch;
    }
    _inflight.remove(request.path);
    if (!request.completer.isCompleted) request.completer.complete(cover);
    _running = false;
    _pump();
  }

  static Future<String?> _generate(_CoverRequest request) async {
    if (!_engineReady) return null;
    var durationMs = request.durationMs;
    if (durationMs <= 0) {
      durationMs = await VideoInfoService.getDuration(request.path);
    }
    // 与原生封面同一位置：片长 1/4 处（第 0 秒常是黑场/台标）；
    // 时长未知就退回第 0 秒——算不出 1/4 也不能不抓
    final seconds = durationMs > 0 ? durationMs / 4000.0 : 0.0;
    for (var attempt = 0; attempt <= _maxStaleRetries; attempt++) {
      final outcome = await _grab(request.path, seconds);
      if (outcome.stale) {
        // 被并发的抓帧请求顶掉：稍等重排，不算失败
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }
      final frame = outcome.frame;
      if (frame == null) return null;
      return _save(request.path, frame);
    }
    return null;
  }

  /// 抓帧引擎是否可用。测试注入 [debugGrabOverride] 时视为可用
  /// （宿主环境没有 Android libmpv.so，否则整条链路在测试里永远走不到）。
  static bool get _engineReady =>
      debugGrabOverride != null || FastThumbnails.isAvailable;

  static Future<GrabOutcome> _grab(String path, double seconds) {
    final override = debugGrabOverride;
    if (override != null) return override(path, seconds);
    // 单帧封面走软解：这类老容器里的 DivX / WMV3 在 MediaCodec 上没有解码器，
    // 硬解先失败再回退既慢又多一次不确定性，软解一帧的成本可以忽略
    return FastThumbnails.grab(
      path,
      seconds,
      dimension: _grabDimension,
      useHwdec: false,
    );
  }

  /// 把抓到的一帧交给原生：裁剪 + JPEG 编码 + 写进列表封面缓存。
  static Future<String?> _save(String path, FastThumbFrame frame) async {
    try {
      return await _channel.invokeMethod<String>('saveVideoCover', {
        'path': path,
        'rgba': frame.rgba,
        'width': frame.width,
        'height': frame.height,
      });
    } catch (_) {
      return null;
    }
  }
}

/// 一次封面生成请求（串行队列的节点）。
class _CoverRequest {
  _CoverRequest(this.path, this.durationMs, this.completer);

  final String path;
  final int durationMs;
  final Completer<String?> completer;
}
