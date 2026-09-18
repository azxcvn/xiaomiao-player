import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/player_settings_page.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「播放设置 → 播放行为 → 锁定状态豁免双击」测试（issue #2 需求）：
/// 位置（启用播放界面动画之后、音量增强之前）、默认关闭、开启前的二次确认
/// （取消不写设置）、关闭直接生效。
void main() {
  final settings = PlayerControlsSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings.reset();
  });

  /// 页面很长，「播放行为」组在下半屏：放大测试视口让整页一次性布局完成，
  /// 这样三项开关的先后顺序可以直接按 y 坐标断言（滚动后早先的行会被回收）。
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PlayerSettingsPage()));
    await tester.pumpAndSettle();
  }

  /// 「锁定状态豁免双击」那一行的 Switch（页面有十几个 Switch，必须按标题定位）
  Finder exemptTile() =>
      find.ancestor(of: find.text('锁定状态豁免双击'), matching: find.byType(ListTile));

  Switch exemptSwitch(WidgetTester tester) => tester.widget<Switch>(
        find.descendant(of: exemptTile(), matching: find.byType(Switch)),
      );

  double titleY(WidgetTester tester, String title) =>
      tester.getTopLeft(find.text(title)).dy;

  testWidgets('位置：夹在「启用播放界面动画」与「音量增强」之间；默认关闭', (tester) async {
    await pumpPage(tester);

    expect(find.text('锁定状态豁免双击'), findsOneWidget);
    // 副标题按需求文案：说明这是"锁定状态下双击屏幕播放/暂停"的功能
    expect(find.text('启用锁定状态下双击屏幕播放/暂停的功能'), findsOneWidget);
    expect(exemptSwitch(tester).value, isFalse, reason: '默认关闭');
    // 顺序：动画 → 豁免双击 → 音量增强
    expect(
      titleY(tester, '启用播放界面动画'),
      lessThan(titleY(tester, '锁定状态豁免双击')),
    );
    expect(
      titleY(tester, '锁定状态豁免双击'),
      lessThan(titleY(tester, '音量增强')),
    );
  });

  testWidgets('开启前弹二次确认：取消则不写设置', (tester) async {
    await pumpPage(tester);

    await tester.tap(
      find.descendant(of: exemptTile(), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('启用锁定状态豁免双击'), findsOneWidget);
    // 必须讲清"只豁免双击"和"误暂停"代价
    expect(find.textContaining('只豁免这一个手势'), findsOneWidget);
    expect(find.textContaining('误暂停'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(settings.lockGestureExempt, isFalse);
    expect(exemptSwitch(tester).value, isFalse);
  });

  testWidgets('确认后生效并落盘；随后关闭不再弹窗', (tester) async {
    await pumpPage(tester);

    await tester.tap(
      find.descendant(of: exemptTile(), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定启用'));
    await tester.pumpAndSettle();

    expect(settings.lockGestureExempt, isTrue);
    expect(exemptSwitch(tester).value, isTrue);
    await settings.load(); // 模拟重启：读盘仍是开
    expect(settings.lockGestureExempt, isTrue);

    // 关闭：直接生效，不弹二次确认
    await tester.tap(
      find.descendant(of: exemptTile(), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(find.text('启用锁定状态豁免双击'), findsNothing);
    expect(settings.lockGestureExempt, isFalse);
    expect(exemptSwitch(tester).value, isFalse);
  });

  testWidgets('界面跟随重力旋转：在「视频方向」组内、默认关闭、无副标题', (tester) async {
    await pumpPage(tester);

    expect(find.text('界面跟随重力旋转'), findsOneWidget);
    final tile = find.ancestor(
      of: find.text('界面跟随重力旋转'),
      matching: find.byType(ListTile),
    );
    // 按需求：取消副标题文本
    expect(tester.widget<ListTile>(tile).subtitle, isNull);
    expect(
      tester
          .widget<Switch>(find.descendant(of: tile, matching: find.byType(Switch)))
          .value,
      isFalse,
      reason: '默认关闭',
    );
    // 位置：三个方向单选（自动/锁定竖屏/锁定横屏）之后
    expect(titleY(tester, '锁定横屏'), lessThan(titleY(tester, '界面跟随重力旋转')));
  });

  testWidgets('开启前弹二次确认：讲明两个前提，取消则不写设置', (tester) async {
    await pumpPage(tester);

    final tile = find.ancestor(
      of: find.text('界面跟随重力旋转'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(find.text('开启界面跟随重力旋转'), findsOneWidget);
    // 必须讲清两个前提：系统「自动旋转」+ 视频方向「自动」
    expect(find.textContaining('「自动旋转」'), findsOneWidget);
    expect(find.textContaining('「视频方向」设为「自动」'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(settings.followPhoneRotation, isFalse);
    expect(
      tester
          .widget<Switch>(find.descendant(of: tile, matching: find.byType(Switch)))
          .value,
      isFalse,
    );
  });

  testWidgets('确认后生效并落盘；关闭直接生效不弹窗', (tester) async {
    await pumpPage(tester);

    final tile = find.ancestor(
      of: find.text('界面跟随重力旋转'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定开启'));
    await tester.pumpAndSettle();

    expect(settings.followPhoneRotation, isTrue);
    await settings.load(); // 模拟重启：读盘仍是开
    expect(settings.followPhoneRotation, isTrue);

    // 关闭：直接生效，不弹二次确认
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(find.text('开启界面跟随重力旋转'), findsNothing);
    expect(settings.followPhoneRotation, isFalse);
  });
}
