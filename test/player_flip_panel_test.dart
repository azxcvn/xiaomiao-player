import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/player_session_state.dart';
import 'package:moumou/pages/player/views/player_flip_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 画面翻转面板：两个开关直接驱动共享会话状态（翻转本身由播放页的
/// Transform.flip 完成，面板不碰 mpv）。
void main() {
  late PlayerSessionState session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = PlayerSessionState();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(body: PlayerFlipPanel(session: session)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('两个开关默认关闭', (tester) async {
    await pumpPanel(tester);

    expect(find.text('水平翻转'), findsOneWidget);
    expect(find.text('垂直翻转'), findsOneWidget);
    expect(session.flipHorizontal, isFalse);
    expect(session.flipVertical, isFalse);
  });

  testWidgets('水平翻转开关切换状态', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(session.flipHorizontal, isTrue);
    expect(session.flipVertical, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(session.flipHorizontal, isFalse);
  });

  testWidgets('垂直翻转开关切换状态', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(session.flipVertical, isTrue);
    expect(session.flipHorizontal, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(session.flipVertical, isFalse);
  });
}
