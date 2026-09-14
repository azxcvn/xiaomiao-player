import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/formatters.dart';

/// 截图文件名纯函数测试（工作.md 播放器截图命名：app名称-截图日期-时间）。
void main() {
  test('formatScreenshotName：app名称 + 日期 + 到秒的时间', () {
    final dt = DateTime(2026, 1, 5, 14, 30, 25);
    expect(formatScreenshotName(dt), '小喵Player-2026-01-05-143025.png');
  });

  test('formatScreenshotName：个位数月/日/时/分/秒补零', () {
    final dt = DateTime(2026, 3, 4, 5, 6, 7);
    expect(formatScreenshotName(dt), '小喵Player-2026-03-04-050607.png');
  });

  test('formatScreenshotName：同年不同秒文件名不同（避免同日覆盖）', () {
    final a = DateTime(2026, 1, 5, 14, 30, 25);
    final b = DateTime(2026, 1, 5, 14, 30, 26);
    expect(formatScreenshotName(a), isNot(formatScreenshotName(b)));
  });

  group('formatPlaybackTimeText（底栏时间文本，B4/P1-5）', () {
    test('默认显示「已播 / 总时长」', () {
      expect(
        formatPlaybackTimeText(
          position: const Duration(minutes: 1, seconds: 30),
          duration: const Duration(minutes: 2),
          showRemaining: false,
        ),
        '01:30 / 02:00',
      );
    });

    test('剩余时长模式：「已播 / -剩余」', () {
      expect(
        formatPlaybackTimeText(
          position: const Duration(seconds: 30),
          duration: const Duration(minutes: 1),
          showRemaining: true,
        ),
        '00:30 / -00:30',
      );
    });

    test('拖动越过结尾：剩余为负**清零**，不出现 -59:55', () {
      // 竖屏页原先未钳制：formatDuration(-5000) 经 ~/ 与 % 得到 "59:55"
      expect(formatDuration(-5000), '59:55', reason: '记录未钳制时的错误形态');
      expect(
        formatPlaybackTimeText(
          position: const Duration(seconds: 65),
          duration: const Duration(minutes: 1),
          showRemaining: true,
        ),
        '01:05 / -00:00',
      );
    });

    test('时长未知（0）时退化为「已播 / 00:00」，不做剩余计算', () {
      expect(
        formatPlaybackTimeText(
          position: const Duration(seconds: 5),
          duration: Duration.zero,
          showRemaining: true,
        ),
        '00:05 / 00:00',
      );
    });

    test('超过 1 小时显示 h:mm:ss', () {
      expect(
        formatPlaybackTimeText(
          position: const Duration(hours: 1, minutes: 2, seconds: 3),
          duration: const Duration(hours: 2),
          showRemaining: false,
        ),
        '1:02:03 / 2:00:00',
      );
    });
  });
}
