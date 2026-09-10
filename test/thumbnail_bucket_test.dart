import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/device_services.dart';

/// 进度条缩略图「秒桶」纯函数测试。
///
/// 背景（真机反馈的精度问题）：缩略图缓存键与「松手 seek 目标」必须落在**同一
/// 时刻**，否则缩略图看到的画面与松手后落到的画面会差最多 1 秒（截断分桶时
/// 恒定偏后，表现为松手后画面往前跳、再也看不到刚才预览的那一帧）。
///
/// 该桶改为四舍五入到整秒（对齐 mpvRx 的 `roundToInt()`），落点离手指位置最多
/// 偏 0.5 秒；配合 `hr-seek=absolute` + media_kit 初始化写入的
/// `hr-seek-framedrop=no`，seek 帧级精确且不丢目标帧。
void main() {
  group('thumbnailBucketMs（秒桶：四舍五入到整秒）', () {
    test('半秒以下向下、半秒及以上向上', () {
      expect(DeviceServices.thumbnailBucketMs(10_400), 10_000);
      expect(DeviceServices.thumbnailBucketMs(10_499), 10_000);
      expect(DeviceServices.thumbnailBucketMs(10_500), 11_000);
      expect(DeviceServices.thumbnailBucketMs(10_999), 11_000);
    });

    test('整秒与首帧保持不变（幂等 → 缓存键稳定）', () {
      expect(DeviceServices.thumbnailBucketMs(0), 0);
      for (final ms in [0, 1000, 10_000, 59_000, 3600_000]) {
        expect(DeviceServices.thumbnailBucketMs(ms), ms);
        expect(
          DeviceServices.thumbnailBucketMs(DeviceServices.thumbnailBucketMs(ms)),
          ms,
        );
      }
    });

    test('负值与零归零（拖到起点之前不产生负桶）', () {
      expect(DeviceServices.thumbnailBucketMs(0), 0);
      expect(DeviceServices.thumbnailBucketMs(-1), 0);
      expect(DeviceServices.thumbnailBucketMs(-9_999), 0);
      expect(DeviceServices.thumbnailBucketMs(-10_000), 0);
    });

    test('0.9 秒内不会跨到 1 秒（499 → 0，500 → 1000）', () {
      expect(DeviceServices.thumbnailBucketMs(1), 0);
      expect(DeviceServices.thumbnailBucketMs(499), 0);
      expect(DeviceServices.thumbnailBucketMs(500), 1_000);
    });

    test('回归：取代截断分桶，落点与手指位置偏差 ≤ 0.5 秒', () {
      // 旧实现 = (ms ~/ 1000) * 1000：拖到 10.9s → 桶 10.0s，预览比落点早 0.9s。
      const ms = 10_900;
      const legacyBucket = (ms ~/ 1000) * 1000;
      expect(legacyBucket, 10_000);
      expect(DeviceServices.thumbnailBucketMs(ms), 11_000);
      // 新桶与手指位置的最大偏差不超过 0.5 秒
      expect(
        (DeviceServices.thumbnailBucketMs(ms) - ms).abs(),
        lessThanOrEqualTo(500),
      );
    });
  });
}
