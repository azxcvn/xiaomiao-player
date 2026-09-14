import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/fast_thumbnails.dart';

FastThumbFrame _frame(int fill, [int width = 2, int height = 2]) =>
    FastThumbFrame(
      Uint8List.fromList(List.filled(width * height * 4, fill)),
      width,
      height,
    );

void main() {
  setUp(() {
    DeviceServices.debugClearFrames();
  });

  group('DeviceServices 帧缓存查询（FFmpeg 快速引擎，RGBA 直通）', () {
    const path = '/storage/emulated/0/Movies/demo.mp4';

    test('peekFrame：精确秒桶命中', () {
      DeviceServices.debugPutFrame(path, 10500, _frame(1, 2, 1));
      final frame = DeviceServices.peekFrame(path, 10999); // 同一秒桶（都四舍五入到 11s）
      expect(frame, isNotNull);
      expect(frame!.rgba.length, 2 * 1 * 4);
    });

    test('peekFrame：不同秒桶不命中', () {
      // 注意：分桶是「四舍五入到整秒」（DeviceServices.thumbnailBucketMs）。
      // 10500 → 11s 桶；因此相邻桶要用 12s（12000）而不是 11000（11000 与
      // 10500 同属 11s 桶）。
      DeviceServices.debugPutFrame(path, 10500, _frame(1));
      expect(DeviceServices.peekFrame(path, 12000), isNull);
      expect(DeviceServices.peekFrame(path, 10000), isNull); // 10s 桶，也不同
    });

    test('peekNearestFrame：返回间隔内最近帧', () {
      DeviceServices.debugPutFrame(path, 60000, _frame(1));
      DeviceServices.debugPutFrame(path, 120000, _frame(2));
      // 80s 距 60s（20s）比距 120s（40s）更近
      final nearest = DeviceServices.peekNearestFrame(
        path,
        80000,
        maxGapMs: 30000,
      );
      expect(nearest, isNotNull);
      expect(nearest!.bucketMs, 60000);
    });

    test('peekNearestFrame：超出间隔返回 null', () {
      DeviceServices.debugPutFrame(path, 0, _frame(1));
      expect(
        DeviceServices.peekNearestFrame(path, 60000, maxGapMs: 10000),
        isNull,
      );
    });

    test('peekNearestFrame：其他视频的帧不串扰', () {
      DeviceServices.debugPutFrame(path, 60000, _frame(1));
      expect(
        DeviceServices.peekNearestFrame(
          '/storage/emulated/0/Movies/other.mp4',
          60000,
          maxGapMs: 10000,
        ),
        isNull,
      );
    });

    test('LRU：超限（32MB）淘汰最久未用帧', () {
      // 每帧 1MB（512×512×4 字节），上限 32MB → 第 33 帧起触发淘汰
      final big = FastThumbFrame(
        Uint8List.fromList(List.filled(512 * 512 * 4, 7)),
        512,
        512,
      );
      // 先插入最早帧，再填满到超限（33MB），最早帧应被淘汰
      DeviceServices.debugPutFrame(path, 0, big);
      for (var b = 2000; b <= 64000; b += 2000) {
        DeviceServices.debugPutFrame(path, b, big);
      }
      expect(DeviceServices.peekFrame(path, 0), isNull);
      expect(DeviceServices.peekFrame(path, 60000), isNotNull);
    });

    test('LRU：peek 命中即刷新（B4/P2-3：拖动热路径的帧不再被先淘汰）', () {
      final big = FastThumbFrame(
        Uint8List.fromList(List.filled(512 * 512 * 4, 7)),
        512,
        512,
      );
      // 填到超限：0 被淘汰，缓存里剩 2s ~ 64s（尾部最新）
      DeviceServices.debugPutFrame(path, 0, big);
      for (var b = 2000; b <= 64000; b += 2000) {
        DeviceServices.debugPutFrame(path, b, big);
      }
      expect(DeviceServices.peekFrame(path, 2000), isNotNull);
      // 此时 2s 是「最久未用」，若 peek 不刷 LRU，下一个新帧就会把它挤掉
      DeviceServices.debugPutFrame(path, 66000, big);
      expect(
        DeviceServices.peekFrame(path, 2000),
        isNotNull,
        reason: 'peek 命中的帧必须被移到最近使用端（修复前这里是 null）',
      );
      expect(DeviceServices.peekFrame(path, 4000), isNull);
    });

    test('LRU：peekNearestFrame 命中同样刷新', () {
      final big = FastThumbFrame(
        Uint8List.fromList(List.filled(512 * 512 * 4, 7)),
        512,
        512,
      );
      DeviceServices.debugPutFrame(path, 0, big);
      for (var b = 2000; b <= 64000; b += 2000) {
        DeviceServices.debugPutFrame(path, b, big);
      }
      // 80s 最近帧是 60s（间隔内）→ 命中即应移到最近使用端
      expect(
        DeviceServices.peekNearestFrame(path, 80000, maxGapMs: 30000),
        isNotNull,
      );
      DeviceServices.debugPutFrame(path, 66000, big);
      expect(DeviceServices.peekFrame(path, 60000), isNotNull);
      expect(DeviceServices.peekFrame(path, 2000), isNull);
    });

    test('失败记录：超限（256 条）淘汰最旧条目（P2-4）', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 填入 256 条失败条目
      for (var i = 0; i < 256; i++) {
        DeviceServices.debugPutFrameFailure('key_$i', now);
      }
      expect(DeviceServices.debugFrameFailCount, 256);
      expect(DeviceServices.debugHasFrameFailure('key_0'), isTrue);

      // 再填一条，应淘汰最早插入的 key_0
      DeviceServices.debugPutFrameFailure('key_256', now);
      expect(DeviceServices.debugFrameFailCount, 256);
      expect(DeviceServices.debugHasFrameFailure('key_0'), isFalse);
      expect(DeviceServices.debugHasFrameFailure('key_256'), isTrue);
    });

    test('失败记录：过期条目（>10s）自动清理（P2-4）', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 插入一条 15 秒前（已过期）的失败记录
      DeviceServices.debugPutFrameFailure('old_key', now - 15000);
      expect(DeviceServices.debugHasFrameFailure('old_key'), isTrue);

      // 插入一条新记录时，应顺带清理掉过期记录
      DeviceServices.debugPutFrameFailure('new_key', now);
      expect(DeviceServices.debugHasFrameFailure('old_key'), isFalse);
      expect(DeviceServices.debugHasFrameFailure('new_key'), isTrue);
    });
  });
}
