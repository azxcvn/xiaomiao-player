import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/player_session_state.dart';
import 'package:moumou/pages/player/views/player_ab_loop_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// AB 循环面板：端点读写都落在共享会话状态里，并同步写 mpv `ab-loop-a/b`。
void main() {
  late PlayerSessionState session;
  late ValueNotifier<Duration> position;
  late List<String> writes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    writes = [];
    session = PlayerSessionState(
      setMpvProperty: (name, value) async => writes.add('$name=$value'),
    );
    // 当前播放位置固定为 01:15，方便断言时间文本
    position = ValueNotifier(const Duration(seconds: 75));
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: PlayerAbLoopPanel(
            session: session,
            positionListenable: position,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('初始两端未设置，底部清除不可点', (tester) async {
    await pumpPanel(tester);

    expect(find.text('未设置'), findsNWidgets(2));
    expect(find.text('当前位置 01:15'), findsOneWidget);

    // 不可点时点击不发任何 mpv 写命令
    await tester.tap(find.text('清除 AB 循环'));
    await tester.pump();
    expect(writes, isEmpty);
  });

  testWidgets('点「设为 A」写入 A 点并显示时间', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('设为 A'));
    await tester.pumpAndSettle();

    expect(session.abLoopA, const Duration(seconds: 75));
    expect(writes, ['ab-loop-a=75.000']);
    expect(find.text('01:15'), findsOneWidget);
    expect(find.text('未设置'), findsOneWidget);
  });

  testWidgets('点「设为 B」写入 B 点', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('设为 B'));
    await tester.pumpAndSettle();

    expect(session.abLoopB, const Duration(seconds: 75));
    expect(writes, ['ab-loop-b=75.000']);
  });

  testWidgets('端点右侧 ✕ 只清该端点', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.text('设为 A'));
    await tester.tap(find.text('设为 B'));
    await tester.pumpAndSettle();
    writes.clear();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(session.abLoopA, isNull);
    expect(session.abLoopB, isNotNull);
    expect(writes, ['ab-loop-a=no']);
  });

  testWidgets('底部「清除 AB 循环」两端一起清', (tester) async {
    await pumpPanel(tester);
    await tester.tap(find.text('设为 A'));
    await tester.tap(find.text('设为 B'));
    await tester.pumpAndSettle();
    writes.clear();

    await tester.tap(find.text('清除 AB 循环'));
    await tester.pumpAndSettle();

    expect(session.hasAbLoop, isFalse);
    expect(writes, ['ab-loop-a=no', 'ab-loop-b=no']);
  });

  testWidgets('横屏面板宽度（340dp）+ 英文长文案不溢出', (tester) async {
    // 横屏右侧面板外壳只有 340dp：两端点都设上（多两个 ✕）时是最挤的状态
    session.setAbLoopA(const Duration(minutes: 12));
    session.setAbLoopB(const Duration(minutes: 34));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 600,
              child: PlayerAbLoopPanel(
                session: session,
                positionListenable: position,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('34:00'), findsOneWidget);
  });
}
