import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/privacy_policy_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 隐私政策同意状态服务测试：默认未同意、同意持久化、load 恢复。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrivacyPolicySettings.instance.resetForTest();
  });

  final s = PrivacyPolicySettings.instance;

  test('默认未同意', () {
    expect(s.accepted, isFalse);
  });

  test('同意后 accepted 为 true 并持久化（模拟重启 load）', () async {
    await s.accept();
    expect(s.accepted, isTrue);
    await s.load();
    expect(s.accepted, isTrue);
  });

  test('重复同意不重复写（幂等）', () async {
    await s.accept();
    await s.accept();
    expect(s.accepted, isTrue);
  });

  test('load 读回持久化状态', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_policy_accepted', true);
    await s.load();
    expect(s.accepted, isTrue);
  });
}
