import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/fast_thumbnails.dart';
import 'package:moumou/services/video_cover_fallback.dart';
import 'package:moumou/services/video_info_service.dart';

/// 列表封面兜底：系统抽取器不认的容器（AVI / WMV 等）由自建内核抓帧补上。
///
/// 宿主环境没有 Android libmpv.so，引擎恒不可用，所以用
/// [VideoCoverFallback.debugGrabOverride] 注入假帧；原生编码那一步走
/// 通道 mock（`saveVideoCover`）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');
  const path = '/storage/emulated/0/Movies/old.avi';

  var durationCalls = 0;
  var nativeDurationMs = 100000;
  var saveCalls = 0;
  String? saveResult = '/cache/thumbs/cover.jpg';
  bool saveThrows = false;
  final savedRgba = <int>[];
  var savedWidth = 0;
  var savedHeight = 0;
  var grabCalls = 0;
  var grabSeconds = <double>[];

  setUp(() {
    VideoCoverFallback.debugReset();
    VideoInfoService.clearCache();
    durationCalls = 0;
    nativeDurationMs = 100000;
    saveCalls = 0;
    saveResult = '/cache/thumbs/cover.jpg';
    saveThrows = false;
    savedRgba.clear();
    savedWidth = 0;
    savedHeight = 0;
    grabCalls = 0;
    grabSeconds = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getVideoDuration':
          durationCalls++;
          return nativeDurationMs;
        case 'saveVideoCover':
          saveCalls++;
          final args = Map<String, Object?>.from(call.arguments as Map);
          savedRgba
            ..clear()
            ..addAll(args['rgba'] as Uint8List);
          savedWidth = args['width'] as int;
          savedHeight = args['height'] as int;
          if (saveThrows) throw PlatformException(code: 'FAIL');
          return saveResult;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    VideoCoverFallback.debugReset();
    VideoInfoService.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// 注入一帧假画面（尺寸只为覆盖传参，不是真实画面）
  void injectFrame({int width = 640, int height = 360}) {
    VideoCoverFallback.debugGrabOverride = (p, seconds) async {
      grabCalls++;
      grabSeconds.add(seconds);
      return (
        frame: FastThumbFrame(Uint8List(width * height * 4), width, height),
        stale: false,
      );
    };
  }

  group('封面兜底', () {
    test('引擎不可用：不抓帧、不落盘，直接回 null', () async {
      final cover = await VideoCoverFallback.resolve(path);

      expect(cover, isNull);
      expect(grabCalls, 0);
      expect(saveCalls, 0);
      expect(durationCalls, 0, reason: '连时长都不该问');
    });

    test('抓到帧：按片长 1/4 处抓，交原生编码，返回封面路径', () async {
      injectFrame();

      final cover = await VideoCoverFallback.resolve(path);

      expect(cover, '/cache/thumbs/cover.jpg');
      expect(durationCalls, 1);
      expect(grabCalls, 1);
      expect(grabSeconds.single, 25.0);
      expect(saveCalls, 1);
      expect(savedWidth, 640);
      expect(savedHeight, 360);
      expect(savedRgba.length, 640 * 360 * 4);
    });

    test('已知时长：不再向原生问时长', () async {
      injectFrame();

      await VideoCoverFallback.resolve(path, durationMs: 400000);

      expect(durationCalls, 0);
      expect(grabSeconds.single, 100.0);
    });

    test('时长也拿不到：退回第 0 秒抓帧', () async {
      injectFrame();
      nativeDurationMs = 0;

      await VideoCoverFallback.resolve(path);

      expect(grabSeconds.single, 0.0);
    });

    test('同一路径并发只抓一次，两个调用拿到同一个结果', () async {
      injectFrame();

      final covers = await Future.wait([
        VideoCoverFallback.resolve(path),
        VideoCoverFallback.resolve(path),
      ]);

      expect(covers, ['/cache/thumbs/cover.jpg', '/cache/thumbs/cover.jpg']);
      expect(grabCalls, 1);
      expect(saveCalls, 1);
    });

    test('生成成功后命中缓存：不再抓帧、不再落盘', () async {
      injectFrame();
      // 缓存命中要求封面文件真实存在（被清掉就重来）
      final dir = await Directory.systemTemp.createTemp('cover_fallback');
      final file = File('${dir.path}/cover.jpg')..writeAsBytesSync([1, 2, 3]);
      saveResult = file.path;

      await VideoCoverFallback.resolve(path);
      final again = await VideoCoverFallback.resolve(path);

      expect(again, file.path);
      expect(grabCalls, 1);
      expect(saveCalls, 1);
      await dir.delete(recursive: true);
    });

    test('封面文件被清掉：缓存作废，重新抓一次', () async {
      injectFrame();
      final dir = await Directory.systemTemp.createTemp('cover_fallback');
      final file = File('${dir.path}/cover.jpg')..writeAsBytesSync([1, 2, 3]);
      saveResult = file.path;

      await VideoCoverFallback.resolve(path);
      file.deleteSync();
      await VideoCoverFallback.resolve(path);

      expect(grabCalls, 2);
      await dir.delete(recursive: true);
    });

    test('被并发抓帧顶掉（stale）：重排重试，不当失败', () async {
      var staleOnce = false;
      VideoCoverFallback.debugGrabOverride = (p, seconds) async {
        grabCalls++;
        if (!staleOnce) {
          staleOnce = true;
          return (frame: null, stale: true);
        }
        return (
          frame: FastThumbFrame(Uint8List(4), 1, 1),
          stale: false,
        );
      };

      final cover = await VideoCoverFallback.resolve(path, durationMs: 1000);

      expect(cover, '/cache/thumbs/cover.jpg');
      expect(grabCalls, 2);
      expect(saveCalls, 1);
    });

    test('原生编码失败：回 null 并进冷却，冷却期内不再重抓', () async {
      injectFrame();
      saveThrows = true;

      final first = await VideoCoverFallback.resolve(path);
      final second = await VideoCoverFallback.resolve(path);

      expect(first, isNull);
      expect(second, isNull);
      expect(grabCalls, 1);
      expect(durationCalls, 1);
    });

    test('抓帧拿不到画面：回 null，不进缓存只进冷却', () async {
      VideoCoverFallback.debugGrabOverride = (p, seconds) async {
        grabCalls++;
        return (frame: null, stale: false);
      };

      final cover = await VideoCoverFallback.resolve(path, durationMs: 1000);

      expect(cover, isNull);
      expect(saveCalls, 0);
      // 再问一次：冷却生效，不再抓
      expect(await VideoCoverFallback.resolve(path, durationMs: 1000), isNull);
      expect(grabCalls, 1);
    });

    test('clearCache(path) 只清该路径的记录', () async {
      injectFrame();
      final dir = await Directory.systemTemp.createTemp('cover_fallback');
      final file = File('${dir.path}/cover.jpg')..writeAsBytesSync([1, 2, 3]);
      saveResult = file.path;

      await VideoCoverFallback.resolve(path, durationMs: 1000);
      VideoCoverFallback.clearCache(path);
      await VideoCoverFallback.resolve(path, durationMs: 1000);

      expect(grabCalls, 2);
      await dir.delete(recursive: true);
    });
  });
}
