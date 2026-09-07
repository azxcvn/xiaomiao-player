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
}
