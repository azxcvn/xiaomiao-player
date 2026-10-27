import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/media_labels.dart';

/// 视频卡片字段标签的文本规则：
/// 分辨率按短边命名、帧率合并成 `1080p@23.98`、字幕编码串拆成多个标签。
void main() {
  group('分辨率', () {
    test('横屏取短边（高度）', () {
      expect(videoResolutionLabel(1920, 1080), '1080p');
      expect(videoResolutionLabel(3840, 2160), '2160p');
      expect(videoResolutionLabel(1280, 720), '720p');
    });

    test('竖屏同样取短边（宽度）', () {
      expect(videoResolutionLabel(1080, 1920), '1080p');
    });

    test('宽高缺失返回 null（不显示标签）', () {
      expect(videoResolutionLabel(0, 1080), isNull);
      expect(videoResolutionLabel(1920, 0), isNull);
      expect(videoResolutionLabel(0, 0), isNull);
    });
  });

  group('帧率', () {
    test('整数帧率不带小数', () {
      expect(videoFrameRateLabel(24), '24');
      expect(videoFrameRateLabel(60), '60');
    });

    test('非整数帧率保留两位', () {
      expect(videoFrameRateLabel(23.976), '23.98');
      expect(videoFrameRateLabel(29.97), '29.97');
    });

    test('未知 / 非法值返回空串', () {
      expect(videoFrameRateLabel(0), '');
      expect(videoFrameRateLabel(-1), '');
      expect(videoFrameRateLabel(double.nan), '');
      expect(videoFrameRateLabel(double.infinity), '');
    });
  });

  group('画质标签（分辨率 + 帧率合并）', () {
    test('两个字段都勾且都有数据：合并成一个标签', () {
      expect(
        videoQualityLabel(
          showResolution: true,
          showFrameRate: true,
          width: 1920,
          height: 1080,
          frameRate: 23.976,
        ),
        '1080p@23.98',
      );
    });

    test('只勾分辨率：只显示 p 值', () {
      expect(
        videoQualityLabel(
          showResolution: true,
          showFrameRate: false,
          width: 1920,
          height: 1080,
          frameRate: 23.976,
        ),
        '1080p',
      );
    });

    test('只勾帧率：单独显示帧率并补 fps 后缀', () {
      expect(
        videoQualityLabel(
          showResolution: false,
          showFrameRate: true,
          width: 1920,
          height: 1080,
          frameRate: 23.976,
        ),
        '23.98 fps',
      );
    });

    test('勾了分辨率但视频没有分辨率数据：退回只显示帧率', () {
      expect(
        videoQualityLabel(
          showResolution: true,
          showFrameRate: true,
          width: 0,
          height: 0,
          frameRate: 24,
        ),
        '24 fps',
      );
    });

    test('两个字段都没有数据返回 null（不显示标签）', () {
      expect(
        videoQualityLabel(
          showResolution: true,
          showFrameRate: true,
          width: 0,
          height: 0,
          frameRate: 0,
        ),
        isNull,
      );
    });
  });

  group('字幕类型标签', () {
    test('按空白拆成每种字幕一个标签', () {
      expect(subtitleTypeLabels('PGS SRT'), ['PGS', 'SRT']);
      expect(subtitleTypeLabels('ASS'), ['ASS']);
    });

    test('无字幕 / 全是空白返回空列表（不显示任何标签）', () {
      expect(subtitleTypeLabels(''), isEmpty);
      expect(subtitleTypeLabels('   '), isEmpty);
    });
  });
}
