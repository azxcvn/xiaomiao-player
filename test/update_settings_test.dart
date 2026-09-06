import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/update/update_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 更新设置服务测试（工作.md：更新功能）：默认值、开关持久化、忽略版本。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateSettings.instance.resetForTest();
  });

  final s = UpdateSettings.instance;

  test('默认值：自动更新开启、未忽略任何版本', () {
    expect(s.autoUpdateEnabled, isTrue);
    expect(s.ignoredVersion, '');
    expect(s.isVersionIgnored('1.1.0'), isFalse);
  });

  test('自动更新开关持久化（模拟重启 load）', () async {
    await s.setAutoUpdateEnabled(false);
    expect(s.autoUpdateEnabled, isFalse);
    await s.load();
    expect(s.autoUpdateEnabled, isFalse);
  });

  test('忽略版本持久化并可查询', () async {
    await s.ignoreVersion('1.1.0');
    expect(s.ignoredVersion, '1.1.0');
    expect(s.isVersionIgnored('1.1.0'), isTrue);
    expect(s.isVersionIgnored('1.2.0'), isFalse);
    await s.load();
    expect(s.ignoredVersion, '1.1.0');
  });

  test('重复忽略同版本不重复写（幂等）', () async {
    await s.ignoreVersion('1.1.0');
    await s.ignoreVersion('1.1.0');
    expect(s.ignoredVersion, '1.1.0');
  });
}
