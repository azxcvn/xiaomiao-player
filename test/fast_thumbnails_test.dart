import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/fast_thumbnails.dart';

void main() {
  setUp(() {
    FastThumbnails.debugReset();
  });

  tearDown(() {
    FastThumbnails.debugReset();
  });

  group('FastThumbnails 缩略图引擎与调度测试', () {
    test('非 Android 环境或未替换内核时 isAvailable 为 false，不抛异常', () {
      // 测试运行在宿主机器上，非 Android libmpv.so 环境
      expect(FastThumbnails.isAvailable, isFalse);
    });

    test('isAvailable 为 false 时 grab 返回 frame: null, stale: false', () async {
      final outcome = await FastThumbnails.grab('/path/to/video.mp4', 10.0);
      expect(outcome.frame, isNull);
      expect(outcome.stale, isFalse);
    });

    test('参数保护：非法或极端时间与尺寸不抛异常', () async {
      final outcome1 = await FastThumbnails.grab('/path/to/video.mp4', -5.0);
      expect(outcome1.frame, isNull);

      final outcome2 = await FastThumbnails.grab('/path/to/video.mp4', double.nan);
      expect(outcome2.frame, isNull);

      final outcome3 = await FastThumbnails.grab(
        '/path/to/video.mp4',
        10.0,
        dimension: -100,
      );
      expect(outcome3.frame, isNull);

      final outcome4 = await FastThumbnails.grab(
        '/path/to/video.mp4',
        10.0,
        dimension: 99999,
      );
      expect(outcome4.frame, isNull);
    });

    test('grabImage 在引擎不可用时返回 null', () async {
      final img = await FastThumbnails.grabImage('/path/to/video.mp4', 10.0);
      expect(img, isNull);
    });

    test('clearNativeCache 在引擎不可用或空闲时调用不抛异常', () {
      expect(() => FastThumbnails.clearNativeCache(), returnsNormally);
    });
  });
}
