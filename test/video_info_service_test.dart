import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/cache_manager_service.dart';
import 'package:moumou/services/video_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');
  var callCount = 0;
  var shouldThrow = false;

  setUp(() {
    callCount = 0;
    shouldThrow = false;
    VideoInfoService.clearCache();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      callCount++;
      if (shouldThrow) {
        throw PlatformException(code: 'ERROR', message: 'Failed to retrieve info');
      }
      if (call.method == 'getVideoInfo') {
        final path = (call.arguments as Map)['path'] as String;
        return {
          'durationMs': 120000,
          'thumbPath': '/cache/thumb_$path.jpg',
        };
      }
      if (call.method == 'getVideoBasicMetadata') {
        return {
          'frameRate': 24.0,
          'hasSubtitles': true,
          'subtitleCodec': 'subrip',
        };
      }
      if (call.method == 'clearCache' || call.method == 'clearAllCaches') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoInfoService.clearCache();
  });

  group('VideoInfoService 内存缓存与失效（P1-27）', () {
    test('重复请求同一路径命中内存缓存，只调用一次通道', () async {
      final info1 = await VideoInfoService.get('/video/a.mp4');
      final info2 = await VideoInfoService.get('/video/a.mp4');

      expect(info1.durationMs, 120000);
      expect(info1.thumbPath, '/cache/thumb_/video/a.mp4.jpg');
      expect(identical(info1, info2), isTrue);
      expect(callCount, 1);
    });

    test('clearCache(path) 可精准失效指定单项缓存', () async {
      await VideoInfoService.get('/video/a.mp4');
      await VideoInfoService.get('/video/b.mp4');
      expect(callCount, 2);

      // 仅失效 a.mp4
      VideoInfoService.clearCache('/video/a.mp4');

      // b 依然命中缓存
      await VideoInfoService.get('/video/b.mp4');
      expect(callCount, 2);

      // a 重新调用通道
      await VideoInfoService.get('/video/a.mp4');
      expect(callCount, 3);
    });

    test('clearCache() 无参清理全部缓存', () async {
      await VideoInfoService.get('/video/a.mp4');
      await VideoInfoService.get('/video/b.mp4');
      expect(callCount, 2);

      VideoInfoService.clearCache();

      await VideoInfoService.get('/video/a.mp4');
      expect(callCount, 3);
      await VideoInfoService.get('/video/b.mp4');
      expect(callCount, 4);
    });

    test('异常安全与不缓存失败结果（P1-27）', () async {
      shouldThrow = true;

      // 原生异常时，不崩溃，返回安全兜底
      final fallback = await VideoInfoService.get('/video/broken.mp4');
      expect(fallback.durationMs, 0);
      expect(fallback.thumbPath, isNull);
      expect(callCount, 1);

      // 异常恢复后，再次调用应能重试而非被永久死锁在空缓存上
      shouldThrow = false;
      final recovered = await VideoInfoService.get('/video/broken.mp4');
      expect(recovered.durationMs, 120000);
      expect(recovered.thumbPath, contains('broken.mp4'));
      expect(callCount, 2);
    });

    test('CacheManagerService 清理封面缓存时联动清理 VideoInfoService 缓存', () async {
      await VideoInfoService.get('/video/a.mp4');
      expect(callCount, 1);

      // 清理封面类别
      await CacheManagerService.clearCategory(CacheManagerService.listThumbs);

      // a.mp4 应重新发起获取
      await VideoInfoService.get('/video/a.mp4');
      // callCount: 1 (get) + 1 (clearCache invoke) + 1 (get again) = 3
      expect(callCount, 3);

      // 一键清除全部缓存
      await CacheManagerService.clearAll();
      await VideoInfoService.get('/video/a.mp4');
      // 3 + 1 (clearAllCaches invoke) + 1 (get again) = 5
      expect(callCount, 5);
    });
  });
}
