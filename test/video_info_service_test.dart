import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/cache_manager_service.dart';
import 'package:moumou/services/video_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');
  var callCount = 0;
  var shouldThrow = false;
  var durationResult = 300000;

  setUp(() {
    callCount = 0;
    shouldThrow = false;
    durationResult = 300000;
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
      if (call.method == 'getVideoDuration') {
        return durationResult;
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

  group('VideoInfoService 时长兜底（.nomedia / 隐藏文件夹条目）', () {
    test('读取时长并命中内存缓存，只调一次通道', () async {
      final ms = await VideoInfoService.getDuration('/video/nomedia.mp4');
      expect(ms, 300000);

      final again = await VideoInfoService.getDuration('/video/nomedia.mp4');
      expect(again, 300000);
      expect(callCount, 1);
    });

    test('异常时不缓存失败结果（下次仍可重试）', () async {
      shouldThrow = true;
      expect(await VideoInfoService.getDuration('/video/x.mp4'), 0);

      shouldThrow = false;
      expect(await VideoInfoService.getDuration('/video/x.mp4'), 300000);
      expect(callCount, 2);
    });

    test('clearCache(path) 同步失效时长缓存', () async {
      await VideoInfoService.getDuration('/video/a.mp4');
      expect(callCount, 1);

      VideoInfoService.clearCache('/video/a.mp4');
      await VideoInfoService.getDuration('/video/a.mp4');
      expect(callCount, 2);
    });

    test('原生回 0 记负结果：滚动往返不再重复问原生（issue #4）', () async {
      durationResult = 0;

      expect(await VideoInfoService.getDuration('/video/broken.mkv'), 0);
      expect(callCount, 1);

      // 卡片被重建（滚走再滚回来）会再问一次：这次必须命中负结果，不再走通道
      expect(await VideoInfoService.getDuration('/video/broken.mkv'), 0);
      expect(await VideoInfoService.getDuration('/video/broken.mkv'), 0);
      expect(callCount, 1, reason: '坏文件抽不到时长，问过就不该再问');

      // 别的文件不受影响（负结果按路径记）
      durationResult = 300000;
      expect(await VideoInfoService.getDuration('/video/ok.mkv'), 300000);
      expect(callCount, 2);
    });

    test('负结果可被 clearCache 清掉（重开 App / 用户清缓存后允许再试）', () async {
      durationResult = 0;
      await VideoInfoService.getDuration('/video/broken.mkv');
      expect(callCount, 1);

      VideoInfoService.clearCache('/video/broken.mkv');
      await VideoInfoService.getDuration('/video/broken.mkv');
      expect(callCount, 2);

      // 无参清空同样清负结果
      VideoInfoService.clearCache();
      await VideoInfoService.getDuration('/video/broken.mkv');
      expect(callCount, 3);
    });

    test('负结果带 TTL：过期后重试，不会把瞬时失败钉成永久结论（P0-1）', () async {
      final originalTtl = VideoInfoService.durationMissTtlMs;
      addTearDown(() => VideoInfoService.durationMissTtlMs = originalTtl);

      durationResult = 0;
      await VideoInfoService.getDuration('/video/busy.mkv');
      expect(callCount, 1);

      // TTL 内：沿用负结果，不再问原生
      VideoInfoService.durationMissTtlMs = 60 * 1000;
      expect(await VideoInfoService.getDuration('/video/busy.mkv'), 0);
      expect(callCount, 1, reason: 'TTL 内不该重复问原生');

      // 卡不忙了（同一个文件现在能拿到时长）：TTL 过期后必须再试一次并拿到
      VideoInfoService.durationMissTtlMs = 0;
      durationResult = 300000;
      expect(await VideoInfoService.getDuration('/video/busy.mkv'), 300000);
      expect(callCount, 2, reason: 'TTL 过期必须允许重试');
    });
  });
}
