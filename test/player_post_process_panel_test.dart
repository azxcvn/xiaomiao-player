import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('效果'), findsOneWidget);
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
}
