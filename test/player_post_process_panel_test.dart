import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/post_process_preset.dart';
import 'package:moumou/pages/player/views/player_post_process_panel.dart';
import 'package:moumou/services/post_process_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 后处理面板：总开关 / 基础调节 / 五个效果 / 参数随开关展开。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PostProcessService.instance.resetForTest();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: const Scaffold(body: PlayerPostProcessPanel()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('总开关、基础调节与五个效果都在', (tester) async {
    await pumpPanel(tester);

    expect(find.text('启用后处理'), findsOneWidget);
    expect(find.text('基础调节'), findsOneWidget);
    expect(find.text('画面效果'), findsOneWidget);
    for (final label in ['亮度', '对比度', '伽马', '饱和度', '色相']) {
      expect(find.text(label), findsOneWidget, reason: '缺少基础调节：$label');
    }
    for (final label in [
      '锐化',
      '降噪',
      '去色带',
      '暗角',
      '扫描线',
      '自然色彩',
      '泛光',
      '卡通',
      '白平衡',
      '色阶',
      '胶片曲线',
      '胶片颗粒',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '缺少效果：$label');
    }
  });

  testWidgets('总开关关闭时效果开关不可用', (tester) async {
    await pumpPanel(tester);

    // 第一个 Switch 是总开关，其余是效果开关（12 个效果）；
    // 总开关关闭时它们都是禁用态
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, 13);
    expect(switches.first.value, isFalse);
    for (final s in switches.skip(1)) {
      expect(s.onChanged, isNull, reason: '总开关关闭时效果开关应置灰');
    }
  });

  testWidgets('开启总开关 + 暗角后出现参数滑杆', (tester) async {
    await pumpPanel(tester);
    final service = PostProcessService.instance;

    service.setEnabled(true);
    service.setVignetteEnabled(true);
    await tester.pumpAndSettle();

    expect(find.text('宽高比'), findsOneWidget);
    expect(find.text('强度'), findsWidgets);
  });

  testWidgets('预设入口：点选后停留在预设视图，可自行返回参数视图', (tester) async {
    await pumpPanel(tester);
    final service = PostProcessService.instance;

    // 顶部入口显示“自定义”
    expect(find.text('预设效果'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);

    await tester.tap(find.text('预设效果'));
    await tester.pumpAndSettle();

    // 五个分组
    for (final group in ['净化', '胶片电影', '老电视', '低码率', '流媒体', '风格化']) {
      expect(find.text(group), findsOneWidget, reason: '缺少预设分组：$group');
    }
    // 每组三个胶囊（前五组是轻/中/重，风格组是电影感/柔和/复古）
    expect(find.text('中度'), findsNWidgets(5));
    expect(find.text('电影感'), findsOneWidget);

    // 点第一个“中度”（净化）
    await tester.tap(find.text('中度').first);
    await tester.pumpAndSettle();

    expect(service.appliedPreset, PostProcessPreset.cleanStandard);
    expect(service.enabled, isTrue);
    // 应用后停留在预设视图，方便连续试档位
    expect(find.text('启用后处理'), findsNothing);
    expect(find.text('电影感'), findsOneWidget);

    // 用户自己点顶部返回行，回到参数视图
    await tester.tap(find.text('预设效果'));
    await tester.pumpAndSettle();
    expect(find.text('启用后处理'), findsOneWidget);
    expect(find.text('预设效果'), findsOneWidget);

    // 等持久化防抖定时器落地，避免测试结束时残留 timer
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('板块重置：基础调节的重置不影响画面效果', (tester) async {
    await pumpPanel(tester);
    final service = PostProcessService.instance;

    service.setEnabled(true);
    service.setBrightness(20);
    service.setVignetteEnabled(true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('重置').first);
    await tester.pumpAndSettle();

    expect(service.brightness, 0);
    expect(service.vignetteEnabled, isTrue, reason: '基础调节的重置不该动画面效果');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('全部重置：基础调节、画面效果、预设标记一起清空', (tester) async {
    await pumpPanel(tester);
    final service = PostProcessService.instance;

    service.applyPreset(PostProcessPreset.filmStandard);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('全部重置'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('全部重置'));
    await tester.pumpAndSettle();

    expect(service.brightness, 0);
    expect(service.levelsEnabled, isFalse);
    expect(service.vignetteEnabled, isFalse);
    expect(service.appliedPreset, isNull);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
