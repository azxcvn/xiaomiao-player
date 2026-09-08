import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/dolby_vision_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DolbyVisionSettings.instance.reset();
  });

  test('默认不抑制提示', () async {
    final s = DolbyVisionSettings.instance;
    await s.ensureLoaded();
    expect(s.suppressed, isFalse);
  });

  test('勾选「不再提示」后持久化', () async {
    final s = DolbyVisionSettings.instance;
    await s.setSuppressed(true);
    expect(s.suppressed, isTrue);
    await s.load(); // 模拟重启
    expect(s.suppressed, isTrue);
    await s.setSuppressed(false);
    expect(s.suppressed, isFalse);
  });
}