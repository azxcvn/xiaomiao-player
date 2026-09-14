import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart' show malloc;
import 'package:flutter/foundation.dart';

/// 快速进度条缩略图引擎（FFI 直连自建 libmpv.so 内核中的 mk_thumbnail_*）。
///
/// 内核来源：https://github.com/azxcvn/libmpv-android-video-build
/// （mk-thumbnail 分支，补丁 mk_thumbnail.patch，接口声明见 mpv libmpv/client.h）
///
 /// 工作方式与 mpvRx 的 FastThumbnails 相同：独立 FFmpeg 解码器实例，
/// 与播放内核完全并行；MediaCodec 硬解优先，失败自动回退软解。
///
 /// JavaVM 已由 media_kit 启动时的 mpv_lavc_set_java_vm() 注册，无需额外初始化。
class FastThumbnails {
  FastThumbnails._();

  static DynamicLibrary? _lib;
  static bool _initialized = false;

  /// 自建内核是否可用（libmpv.so 中能找到 mk_thumbnail_grab 符号）。
  /// false = APK 里还是官方内核（没换 jar / 换错了）。
  static bool get isAvailable {
    if (!_initialized) {
      _initialized = true;
      if (Platform.isAndroid) {
        try {
          _lib = DynamicLibrary.open('libmpv.so');
          _lib!.lookupFunction<_GrabC, _GrabDart>('mk_thumbnail_grab');
        } catch (_) {
          _lib = null;
          debugPrint('[FastThumb] libmpv.so 中没有 mk_thumbnail_grab —— '
              '内核未替换为自建版本');
        }
      }
    }
    return _lib != null;
  }

  /// 抓取一帧缩略图，返回紧密排列的 RGBA8888 像素。
  ///
  /// [path] 本地视频绝对路径；[positionSec] 秒（0 = 首帧）；
  /// [dimension] 输出图像最长边像素；[useHwdec] MediaCodec 硬解（失败自动软解）。
  /// 返回 [GrabOutcome]：[frame] 为 null 表示没抓到图（不抛异常）；
  /// [stale] 为 true 表示请求被更新的请求顶掉（被抢占，非真实失败）。
  ///
  /// 调度（对齐 mpvRx）：最多 1 个解码在跑 + 1 个待跑；拖动时新请求
  /// 直接顶掉旧的待跑请求（旧帧对预览无价值），被顶掉的以 stale=true 完成。
  /// 任何时刻最多占用一个核，不会与播放内核抢 CPU。
  static Future<GrabOutcome> grab(
    String path,
    double positionSec, {
    int dimension = 320,
    bool useHwdec = true,
  }) async {
    if (!isAvailable) return (frame: null, stale: false);
    if (positionSec.isNaN || positionSec < 0) positionSec = 0;
    if (dimension <= 0 || dimension > 4096) dimension = 320;

    final job = _GrabJob(
      path: path,
      positionSec: positionSec,
      dimension: dimension,
      useHwdec: useHwdec ? 1 : 0,
    );
    // 新请求顶掉旧的待跑请求（其 future 以 stale=true 完成，表示「被抢占」，
    // 与真实解码失败区分开，供上层决定是否记录失败冷却）
    final stale = _waiting;
    _waiting = job;
    stale?._complete((frame: null, stale: true));
    _pump();
    return job.completer.future;
  }

  static _GrabJob? _running;
  static _GrabJob? _waiting;
  static Isolate? _workerIsolate;
  static SendPort? _workerPort;
  static Completer<SendPort?>? _workerInitCompleter;

  static void _pump() {
    while (_running == null && _waiting != null) {
      final job = _waiting!;
      _waiting = null;
      _running = job;
      _runGrab(job.path, job.positionSec, job.dimension, job.useHwdec)
          .then((frame) => job._complete((frame: frame, stale: false)))
          .catchError((Object e) {
        debugPrint('[FastThumb] grab error: $e');
        job._complete((frame: null, stale: false));
      }).whenComplete(() {
        _running = null;
        _pump();
      });
    }
  }

  /// 长驻 worker isolate 调度（P1-14）：避免每帧 Isolate.run 创建/销毁
  /// 与反复 DynamicLibrary.open('libmpv.so') 的固定开销。
  static Future<SendPort?> _ensureWorker() async {
    if (_workerPort != null) return _workerPort;
    if (_workerInitCompleter != null) return _workerInitCompleter!.future;
    final completer = Completer<SendPort?>();
    _workerInitCompleter = completer;

    final initPort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    try {
      final isolate = await Isolate.spawn(
        _workerMain,
        initPort.sendPort,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );

      errorPort.listen((message) {
        debugPrint('[FastThumb] worker error: $message');
        _resetWorker();
      });
      exitPort.listen((_) {
        _resetWorker();
      });

      final dynamic port = await initPort.first;
      initPort.close();
      if (port is SendPort) {
        _workerIsolate = isolate;
        _workerPort = port;
        completer.complete(port);
        return port;
      } else {
        _resetWorker();
        completer.complete(null);
        return null;
      }
    } catch (e) {
      debugPrint('[FastThumb] failed to spawn worker: $e');
      _resetWorker();
      completer.complete(null);
      return null;
    } finally {
      _workerInitCompleter = null;
    }
  }

  static void _resetWorker() {
    _workerPort = null;
    try {
      _workerIsolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
    _workerIsolate = null;
  }

  /// 在长驻 worker isolate 执行抓帧。
  static Future<FastThumbFrame?> _runGrab(
      String path, double positionSec, int dimension, int useHwdec) async {
    final workerPort = await _ensureWorker();
    if (workerPort == null) return null;

    final responsePort = ReceivePort();
    try {
      workerPort.send([
        responsePort.sendPort,
        path,
        positionSec,
        dimension,
        useHwdec,
      ]);
      final dynamic response = await responsePort.first;
      if (response is FastThumbFrame) {
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('[FastThumb] worker grab failed: $e');
      return null;
    } finally {
      responsePort.close();
    }
  }

  /// 测试用：重置调度队列与 worker isolate
  @visibleForTesting
  static void debugReset() {
    _running = null;
    _waiting = null;
    _resetWorker();
  }

  // ---- native 调用（跑在长驻 Isolate 中，库与符号仅初始化一次）----

  static void _workerMain(SendPort initSendPort) {
    DynamicLibrary? lib;
    _GrabDart? grab;
    _FreeDart? free;

    if (Platform.isAndroid) {
      try {
        lib = DynamicLibrary.open('libmpv.so');
        grab = lib.lookupFunction<_GrabC, _GrabDart>('mk_thumbnail_grab');
        free = lib.lookupFunction<_FreeC, _FreeDart>('mk_thumbnail_free');
      } catch (e) {
        initSendPort.send(null);
        return;
      }
    } else {
      initSendPort.send(null);
      return;
    }

    final commandPort = ReceivePort();
    initSendPort.send(commandPort.sendPort);

    commandPort.listen((dynamic message) {
      if (message is List && message.length >= 5) {
        final replyPort = message[0] as SendPort;
        final path = message[1] as String;
        final positionSec = (message[2] as num).toDouble();
        final dimension = message[3] as int;
        final useHwdec = message[4] as int;

        FastThumbFrame? frame;
        try {
          frame = _grabSync(grab!, free!, path, positionSec, dimension, useHwdec);
        } catch (e) {
          frame = null;
        }
        replyPort.send(frame);
      } else if (message == 'clear_cache') {
        try {
          lib?.lookupFunction<Void Function(), void Function()>(
              'mk_thumbnail_clear_cache')();
        } catch (_) {}
      }
    });
  }

  static FastThumbFrame? _grabSync(
      _GrabDart grab,
      _FreeDart free,
      String path,
      double positionSec,
      int dimension,
      int useHwdec) {
    final units = utf8.encode(path);
    final pathPtr = malloc<Uint8>(units.length + 1);
    pathPtr.asTypedList(units.length + 1)
      ..setRange(0, units.length, units)
      ..[units.length] = 0;

    final outData = malloc<Pointer<Uint8>>();
    final outWidth = malloc<Int32>();
    final outHeight = malloc<Int32>();

    FastThumbFrame? result;
    try {
      final rc = grab(pathPtr, positionSec, dimension, useHwdec,
          outData, outWidth, outHeight);
      if (rc == 0) {
        final w = outWidth.value;
        final h = outHeight.value;
        final data = outData.value;
        if (data != nullptr && w > 0 && h > 0) {
          // 拷贝到 Dart 堆后立刻释放 native 缓冲
          final bytes = Uint8List.fromList(data.asTypedList(w * h * 4));
          result = FastThumbFrame(bytes, w, h);
        }
        free(data);
      }
    } finally {
      malloc.free(outHeight);
      malloc.free(outWidth);
      malloc.free(outData);
      malloc.free(pathPtr);
    }
    return result;
  }
}

/// 一帧缩略图：RGBA8888 紧密像素 + 尺寸。
class FastThumbFrame {
  const FastThumbFrame(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}

/// 抓帧结果：[frame] 为 null 表示没抓到图；[stale] 为 true 表示请求被更新的
/// 请求顶掉（被抢占，而非真实解码失败），供上层区分是否记录失败冷却。
typedef GrabOutcome = ({FastThumbFrame? frame, bool stale});

/// 一次抓帧请求（单飞队列的节点）。
class _GrabJob {
  _GrabJob({
    required this.path,
    required this.positionSec,
    required this.dimension,
    required this.useHwdec,
  });

  final String path;
  final double positionSec;
  final int dimension;
  final int useHwdec;
  final completer = Completer<GrabOutcome>();
  bool _done = false;

  void _complete(GrabOutcome outcome) {
    if (_done) return;
    _done = true;
    completer.complete(outcome);
  }
}

typedef _GrabC = Int32 Function(
    Pointer<Uint8> path,
    Double position,
    Int32 dimension,
    Int32 useHwdec,
    Pointer<Pointer<Uint8>> outData,
    Pointer<Int32> outWidth,
    Pointer<Int32> outHeight);
typedef _GrabDart = int Function(
    Pointer<Uint8> path,
    double position,
    int dimension,
    int useHwdec,
    Pointer<Pointer<Uint8>> outData,
    Pointer<Int32> outWidth,
    Pointer<Int32> outHeight);
typedef _FreeC = Void Function(Pointer<Uint8> data);
typedef _FreeDart = void Function(Pointer<Uint8> data);
