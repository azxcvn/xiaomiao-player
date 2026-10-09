import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/pages/player/views/player_action_grid.dart';
import 'package:moumou/pages/player/views/player_bottom_bar.dart';
import 'package:moumou/pages/player/views/player_button_size_panel.dart';
import 'package:moumou/pages/player/views/player_top_bar.dart';
import 'package:moumou/pages/player/views/portrait_edit_panel.dart';
import 'package:moumou/pages/player/views/portrait_player_top_bar.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/widgets/player_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 控制栏按钮外观与自定义面板回归测试：
/// - 「按钮背景」开关**不改按钮尺寸/间距**（历史问题：开启后顶栏图标从 22
///   缩到 16、触摸盒从 48 缩到 28，按钮又小又挤；横竖屏顶栏都要修）；
/// - 「控制栏按钮大小」倍率作用于横屏顶栏/底栏图标；
/// - 网格紧凑（方底只比图标大一圈）、按宽度自动 4/3 列；
/// - 5 格预览条均分整行、长按能拖动排序（Tooltip 不能抢长按）、✕ 可移除；
/// - 可添加网格 ＋ 添加受 5 个上限约束；
/// - 整页可滚动（不只有网格一小块能滑）；
/// - 拖动滑杆时面板外壳整体淡出。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerControlsSettings.instance.reset();
  });

  Widget wrap(Widget child, {Size size = const Size(800, 600)}) {
    return MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }

  Widget topBar() => PlayerTopBar(
        title: '视频标题',
        onBack: () {},
        onMore: () {},
        onActionTap: (_) {},
      );

  Widget bottomBar() => PlayerBottomBar(
        valueMs: 1000,
        maxMs: 10000,
        onSeekChanged: (_) {},
        onSeekEnd: (_) {},
        hasNext: true,
        onNext: () {},
        timeText: '00:01 / 00:10',
        onTimeTap: () {},
        onSpeedTap: () {},
        showSpeedButtonBackground: false,
        superResolutionLabel: '超分辨率',
        onSuperResolutionTap: () {},
        onScreenSwitchTap: () {},
        showScreenSwitchBackground: false,
        onPlaylistTap: () {},
        chapters: const <ChapterInfo>[],
        skipSegments: const <SkipSegment>[],
        danmakuOn: true,
        onDanmakuToggle: () {},
        onDanmakuSettingsTap: () {},
      );

  Widget previewRow({
    List<PlayerTopAction> slots = const [PlayerTopAction.subtitle],
    void Function(int, int)? onReorder,
    void Function(PlayerTopAction)? onRemove,
    double width = 340,
  }) {
    return Center(
      child: SizedBox(
        width: width,
        child: PlayerActionPreviewRow(
          slots: slots,
          onReorder: onReorder ?? (_, _) {},
          onRemove: onRemove ?? (_) {},
        ),
      ),
    );
  }

  double backIconSize(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.arrow_back)).size!;

  /// 顶栏左右两端按钮的横向间距：按钮盒变小时它会明显缩小
  double barSpan(WidgetTester tester) =>
      tester.getRect(find.byIcon(Icons.more_vert)).right -
      tester.getRect(find.byIcon(Icons.arrow_back)).left;

  testWidgets('横屏顶栏：按钮背景开关不改按钮尺寸与间距', (tester) async {
    final s = PlayerControlsSettings.instance;
    await tester.pumpWidget(wrap(topBar()));
    final offIconSize = backIconSize(tester);
    final offSpan = barSpan(tester);

    await s.setShowButtonBackground(true);
    await tester.pumpWidget(wrap(topBar()));

    expect(backIconSize(tester), offIconSize);
    expect(barSpan(tester), closeTo(offSpan, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('竖屏顶栏：按钮背景开关不改按钮尺寸与间距', (tester) async {
    final s = PlayerControlsSettings.instance;
    Widget bar() => PortraitPlayerTopBar(
          title: '标题',
          onBack: () {},
          onMore: () {},
          onActionTap: (_) {},
        );
    await s.addTopAction(PlayerTopAction.subtitle);
    await tester.pumpWidget(wrap(bar()));
    final offSize = backIconSize(tester);
    final offSpan = barSpan(tester);

    await s.setShowButtonBackground(true);
    await tester.pumpWidget(wrap(bar()));

    expect(backIconSize(tester), offSize);
    expect(barSpan(tester), closeTo(offSpan, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('控制栏按钮大小同时缩放横屏顶栏与底栏图标', (tester) async {
    final s = PlayerControlsSettings.instance;
    await tester.pumpWidget(wrap(topBar()));
    final baseTop = backIconSize(tester);
    await tester.pumpWidget(wrap(bottomBar()));
    final baseBottom =
        tester.widget<Icon>(find.byIcon(Icons.speed_rounded)).size!;

    await s.setButtonScale(1.4);
    await tester.pumpWidget(wrap(topBar()));
    expect(backIconSize(tester), closeTo(baseTop * 1.4, 0.01));
    await tester.pumpWidget(wrap(bottomBar()));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.speed_rounded)).size!,
      closeTo(baseBottom * 1.4, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('网格按宽度自动定列数，格子紧凑（不占满整格）', (tester) async {
    // 横屏 340dp 面板 / 竖屏 360dp → 4 列；极窄 300dp → 3 列
    expect(playerActionGridMetrics(340).columns, 4);
    expect(playerActionGridMetrics(360).columns, 4);
    expect(playerActionGridMetrics(300).columns, 3);
    final m = playerActionGridMetrics(340);
    expect(m.tileWidth, lessThan(80));
    expect(m.tileHeight, lessThan(84));
    // 方底（格子高 - 名称行）不超过 52：只比图标大一圈
    expect(m.tileHeight - 28, lessThanOrEqualTo(52));
  });

  testWidgets('5 格预览条：只显示已选动作 + － 移除 + 均分整行', (tester) async {
    final s = PlayerControlsSettings.instance;
    await s.addTopAction(PlayerTopAction.subtitle);
    await s.addTopAction(PlayerTopAction.danmaku);
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(tester.takeException(), isNull);

    // 已选两个动作有图标，预览条每个已放置槽位一个「－」角标
    expect(find.byIcon(PlayerTopAction.subtitle.icon), findsWidgets);
    expect(find.byIcon(PlayerTopAction.danmaku.icon), findsWidgets);
    expect(find.byIcon(Icons.remove), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump();
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(s.topActions.length, 1);
  });

  testWidgets('预览条：长按能拖动排序（不再被 Tooltip 抢长按）', (tester) async {
    final reorders = <String>[];
    await tester.pumpWidget(
      wrap(
        previewRow(
          slots: const [PlayerTopAction.subtitle, PlayerTopAction.danmaku],
          onReorder: (o, n) => reorders.add('$o->$n'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // 槽位里不得有 Tooltip：它的「长按显示名称」会抢掉同一个长按手势
    expect(
      find.descendant(
        of: find.byType(PlayerActionPreviewRow),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );

    final first = find.byIcon(PlayerTopAction.subtitle.icon);
    final gesture = await tester.startGesture(tester.getCenter(first));
    // 长按超过延迟阈值 → 进入拖动；随后小步移动（真实手指轨迹，
    // 一次大跳跃的合成事件落不到相邻槽位上）
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 32));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reorders, isNotEmpty);
  });

  testWidgets('预览条：5 格刚好填满整行（右侧不留空白）', (tester) async {
    await tester.pumpWidget(wrap(previewRow()));
    expect(tester.takeException(), isNull);
    final rowRect = tester.getRect(find.byType(PlayerActionPreviewRow));
    // 预览条左右内边距各 12 → 内容区 316dp
    final slotRects = tester
        .widgetList<SizedBox>(find.descendant(
          of: find.byType(PlayerActionPreviewRow),
          matching: find.byType(SizedBox),
        ))
        .where((b) => (b.width ?? 0) > 30 && (b.width ?? 0) < 80)
        .length;
    // 5 个槽位（含空槽）在同一条横向列表里
    expect(slotRects, greaterThanOrEqualTo(PlayerActionPreviewRow.slotCount));
    expect(rowRect.width, 340);
  });

  testWidgets('可添加网格：点整个方块就能添加（不必点角标）', (tester) async {
    final s = PlayerControlsSettings.instance;
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(tester.takeException(), isNull);
    // 网格项名称文本的中心在方块内 → 点文本即命中整块
    await tester.ensureVisible(find.text('弹幕'));
    await tester.pump();
    await tester.tap(find.text('弹幕'));
    await tester.pump();
    expect(s.topActions, contains(PlayerTopAction.danmaku));
  });

  testWidgets('预览条：点整个方块就能移除（不必点 － 角标）', (tester) async {
    final s = PlayerControlsSettings.instance;
    await s.addTopAction(PlayerTopAction.subtitle);
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(tester.takeException(), isNull);
    expect(s.topActions, contains(PlayerTopAction.subtitle));

    // 「字幕」此刻只出现在预览条里（已放置 → 不在可添加网格），
    // 点它的图标即可移除
    await tester.tap(find.byIcon(PlayerTopAction.subtitle.icon).first);
    await tester.pump();
    expect(s.topActions, isNot(contains(PlayerTopAction.subtitle)));
  });

  testWidgets('增删带飞行动画：飞行期间目标槽位图标隐身、overlay 里出现副本', (tester) async {
    final s = PlayerControlsSettings.instance;
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(tester.takeException(), isNull);

    final host = tester.state<PlayerActionFlyAnimationState>(
      find.byType(PlayerActionFlyAnimation),
    );
    expect(host.flyingAction, isNull);

    await tester.ensureVisible(find.text('弹幕'));
    await tester.pump();
    await tester.tap(find.text('弹幕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // 1) 飞行进行中：动画层记录了正在飞的动作
    expect(host.flyingAction, PlayerTopAction.danmaku);
    // 2) 目标槽位（预览条里那一格）的图标已隐身（AnimatedOpacity → 0），
    //    避免与飞行副本重合
    expect(
      find.descendant(
        of: find.byType(PlayerActionPreviewRow),
        matching: find.byType(AnimatedOpacity),
      ),
      findsWidgets,
    );
    final hiddenIcons = tester
        .widgetList<AnimatedOpacity>(find.descendant(
          of: find.byType(PlayerActionPreviewRow),
          matching: find.byType(AnimatedOpacity),
        ))
        .where((w) => w.opacity == 0)
        .length;
    expect(hiddenIcons, greaterThan(0), reason: '飞行期间槽位图标应隐身为 0');
    // 3) 飞行副本在 overlay 里（被 IgnorePointer 包裹，与槽位图标区分）
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byIcon(PlayerTopAction.danmaku.icon),
      ),
      findsWidgets,
      reason: 'overlay 里应有飞行副本',
    );

    await tester.pumpAndSettle();
    expect(host.flyingAction, isNull);
    expect(s.topActions, contains(PlayerTopAction.danmaku));
    expect(tester.takeException(), isNull);
  });

  testWidgets('可添加网格：点 ＋ 添加动作，到 5 个上限后提示', (tester) async {
    final s = PlayerControlsSettings.instance;
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.add_circle), findsWidgets);

    for (var i = 0; i < PlayerControlsSettings.maxTopActions; i++) {
      await tester.ensureVisible(find.byIcon(Icons.add_circle).first);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_circle).first);
      await tester.pump();
    }
    expect(s.topActions.length, PlayerControlsSettings.maxTopActions);
    await tester.ensureVisible(find.byIcon(Icons.add_circle).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pump();
    expect(s.topActions.length, PlayerControlsSettings.maxTopActions);
    expect(find.text('最多允许放 5 个'), findsOneWidget);
  });

  testWidgets('自定义页整页可滚动（不是只剩网格一小块能滑）', (tester) async {
    await tester.pumpWidget(wrap(const PortraitEditControlPanel()));
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('竖屏底部面板高度下自定义页不溢出', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: PortraitEditControlPanel(),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.add_circle), findsWidgets);
  });

  testWidgets('横屏面板外壳只占右缘 340dp，底色不铺满全屏', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlayerPanel(
                context,
                animate: false,
                pages: const [
                  PlayerPanelPage(title: '更多', body: SizedBox.shrink()),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 面板底色所在的 Material 宽度 = 面板宽 340dp，不能铺满 800dp 全屏
    // （曾把 Material 放在 Align 外面 → 底色按整屏布局刷满全屏）
    final widest = find
        .descendant(
          of: find.byType(PlayerPanel),
          matching: find.byType(Material),
        )
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderBox>()
        .map((box) => box.size.width)
        .fold<double>(0, (a, b) => a > b ? a : b);
    expect(widest, 340);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPanel), findsNothing);
  });

  testWidgets('拖动滑杆时面板外壳整体淡出（连面板背景一起）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlayerPanel(
                context,
                animate: false,
                pages: const [
                  PlayerPanelPage(
                    title: '按钮大小',
                    body: PlayerButtonSizePanel(),
                  ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerButtonSizePanel), findsOneWidget);
    // 图例已删：面板里不再有示意按钮图标
    expect(find.byIcon(Icons.photo_size_select_large), findsNothing);

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // 1) 面板底色变到完全透明（0%）
    final panelColors = tester
        .widgetList<Material>(find.ancestor(
          of: find.byType(Slider),
          matching: find.byType(Material),
        ))
        .map((m) => m.color)
        .whereType<Color>()
        .toList();
    expect(
      panelColors.any((c) => c.a == 0),
      isTrue,
      reason: '拖动时面板底色应降到完全透明：$panelColors',
    );
    // 2) 滑杆本身保持满不透明度（不能被一起淡掉）
    final sliderOpacities = tester
        .widgetList<AnimatedOpacity>(find.ancestor(
          of: find.byType(Slider),
          matching: find.byType(AnimatedOpacity),
        ))
        .map((w) => w.opacity)
        .toList();
    expect(sliderOpacities.every((o) => o >= 0.99), isTrue,
        reason: '滑杆不能被淡：$sliderOpacities');
    // 3) 本页其余内容被淡掉
    final textOpacities = tester
        .widgetList<AnimatedOpacity>(find.ancestor(
          of: find.text('按钮大小'),
          matching: find.byType(AnimatedOpacity),
        ))
        .map((w) => w.opacity)
        .toList();
    expect(textOpacities.any((o) => o < 0.2), isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
