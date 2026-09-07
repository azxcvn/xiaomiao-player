import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/settings_page.dart';
import 'package:moumou/services/bilibili/bili_account.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「我的」页 B 站下载入口登录门禁测试：未登录哔哩哔哩账号时点击
/// 弹幕下载 / 视频下载 → toast「需要登录哔哩哔哩账号」，不进入页面
/// （与首页速拨「哔哩番剧」同一处理）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: ThemeController())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未登录点击弹幕下载 → toast 提示登录', (tester) async {
    await pumpSettings(tester);
    expect(BiliAccount.instance.isLogin, isFalse);

    await tester.scrollUntilVisible(find.text('弹幕下载'), 400);
    await tester.tap(find.text('弹幕下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('需要登录哔哩哔哩账号'), findsOneWidget);
  });

  testWidgets('未登录点击视频下载 → toast 提示登录', (tester) async {
    await pumpSettings(tester);
    expect(BiliAccount.instance.isLogin, isFalse);

    await tester.scrollUntilVisible(find.text('视频下载'), 400);
    await tester.tap(find.text('视频下载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('需要登录哔哩哔哩账号'), findsOneWidget);
  });
}
