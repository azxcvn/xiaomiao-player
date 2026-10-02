import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_color_mode.dart';
import 'package:moumou/pages/player/views/player_danmaku_settings_panel.dart';
import 'package:moumou/services/danmaku_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 弹幕设置面板回归测试（阶段2）：
/// - 三段式布局齐全：弹幕样式（滑杆 + 颜色三态单选）、弹幕配置、
///   弹幕偏移；
/// - 滑杆拖动 / 开关切换 / 颜色模式单选写设置单例（重栅格化项字号/字重/
///   描边松手提交，轻量项实时写）；
/// - 恢复默认按钮一键回默认值。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DanmakuSettings.instance.resetForTest();
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: const Scaffold(body: PlayerDanmakuSettingsPanel()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 面板内容超出视口时先滚动到目标可见再交互
  Future<void> ensureVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
  }

  /// 调色区标题的精确匹配（`find.textContaining('弹幕颜色')` 会连
  /// 「跟随弹幕颜色」那个单选项一起匹配到，不能用它断言调色区是否展开）
  final paletteTitle = find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').startsWith('弹幕颜色（'),
  );

  testWidgets('两段式布局齐全：样式 + 配置 + 恢复默认', (tester) async {
    await pumpPanel(tester);
    expect(tester.takeException(), isNull);
    // 分组标题
    expect(find.text('弹幕样式'), findsOneWidget);
    expect(find.text('弹幕配置'), findsOneWidget);
    // 样式滑杆
    expect(find.text('弹幕字号'), findsOneWidget);
    expect(find.text('字体字重'), findsOneWidget);
    expect(find.text('弹幕速度'), findsOneWidget);
    expect(find.text('描边粗细'), findsOneWidget);
    expect(find.text('不透明度'), findsOneWidget);
    // 随机渐变色
    expect(find.text('随机渐变色'), findsOneWidget);
    // 配置滑杆
    expect(find.text('显示区域'), findsOneWidget);
    expect(find.text('弹幕行高'), findsOneWidget);
    // 配置开关
    expect(find.text('顶部弹幕'), findsOneWidget);
    expect(find.text('底部弹幕'), findsOneWidget);
    expect(find.text('滚动弹幕'), findsOneWidget);
    expect(find.text('海量弹幕'), findsOneWidget);
    expect(find.text('弹幕去重'), findsOneWidget);
    expect(find.text('弹幕合并'), findsOneWidget);
    expect(find.text('屏蔽词'), findsOneWidget);
    // 位置：弹幕合并夹在「弹幕去重」与「屏蔽词」之间（工作.md 指定）
    final dedupY = tester.getTopLeft(find.text('弹幕去重')).dy;
    final mergeY = tester.getTopLeft(find.text('弹幕合并')).dy;
    final blockY = tester.getTopLeft(find.text('屏蔽词')).dy;
    expect(dedupY, lessThan(mergeY));
    expect(mergeY, lessThan(blockY));
    // 副标题说明语义
    expect(find.text('不同时间内相同弹幕合并且计数'), findsOneWidget);
    // 弹幕偏移
    expect(find.text('弹幕偏移'), findsOneWidget);
    expect(find.text('时间轴偏移'), findsOneWidget);
    expect(find.text('提前 1 秒'), findsOneWidget);
    expect(find.text('延后 1 秒'), findsOneWidget);
    expect(find.text('重置偏移'), findsOneWidget);
    // 恢复默认
    expect(find.text('恢复默认设置'), findsOneWidget);
  });

  testWidgets('颜色模式单选 + 开关切换实时写设置', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    // 「随机渐变色」已由开关改为三态单选（跟随弹幕颜色 / 随机渐变色 / 指定颜色）
    expect(s.colorMode, DanmakuColorMode.source);
    await tester.tap(find.text('随机渐变色'));
    await tester.pumpAndSettle();
    expect(s.colorMode, DanmakuColorMode.random);
    // 选「指定颜色」后才展开调色区
    expect(paletteTitle, findsNothing, reason: '未选指定色时不展开调色区');
    // 选中「随机渐变色」后其副标题变长、把下一项推出视口，先滚动到可见再点
    await ensureVisible(tester, find.text('指定颜色'));
    await tester.tap(find.text('指定颜色'));
    await tester.pumpAndSettle();
    expect(s.colorMode, DanmakuColorMode.fixed);
    await ensureVisible(tester, paletteTitle);
    expect(paletteTitle, findsOneWidget, reason: '选指定色后展开调色区');

    // Switch 组件定位：颜色模式已不是 Switch，还剩 3 显隐 + 海量 + 去重 + 合并
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(6));
    // 去重是倒数第二个 Switch、合并是最后一个（都在视口外，先滚动到可见）
    await ensureVisible(tester, switches.at(4));
    await tester.tap(switches.at(4));
    await tester.pumpAndSettle();
    expect(s.deduplication, isTrue);
    await ensureVisible(tester, switches.last);
    await tester.tap(switches.last);
    await tester.pumpAndSettle();
    expect(s.merge, isTrue);
    // 互斥：开合并后去重被自动关闭
    expect(s.deduplication, isFalse);
  });

  testWidgets('滑杆拖动松手后写设置（字号）', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    expect(s.fontSize, 16);
    // 找到字号滑杆：第一个 Slider（样式区第一行）
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(8)); // 5 样式 + 2 配置 + 1 偏移
    // 字号滑杆（index 0）拖到最右端附近：10–30，拖到 90% 处；松手提交
    final bounds = tester.getRect(sliders.first);
    await tester.drag(sliders.first, Offset(bounds.width * 0.9, 0));
    await tester.pumpAndSettle();
    expect(s.fontSize, greaterThan(20));
  });

  testWidgets('偏移快捷按钮：提前/延后 1 秒 + 单独重置', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    expect(s.timeOffsetSeconds, 0);

    // 延后 1 秒（视口外，先滚动到可见）
    await ensureVisible(tester, find.text('延后 1 秒'));
    await tester.tap(find.text('延后 1 秒'));
    await tester.pumpAndSettle();
    expect(s.timeOffsetSeconds, 1);

    // 提前 1 秒（同行，回到 0）
    await tester.tap(find.text('提前 1 秒'));
    await tester.pumpAndSettle();
    expect(s.timeOffsetSeconds, 0);

    // 单独重置：只复位偏移，不影响其它设置（全局重置未触发）
    await s.setFontSize(24);
    await s.setTimeOffset(60);
    expect(s.timeOffsetSeconds, 60);
    await ensureVisible(tester, find.text('重置偏移'));
    await tester.tap(find.text('重置偏移'));
    await tester.pumpAndSettle();
    expect(s.timeOffsetSeconds, 0);
    expect(s.fontSize, 24);
  });

  testWidgets('恢复默认按钮：改值后一键回默认', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    // 先改两个值
    await s.setFontSize(24);
    await s.setShowTop(false);
    expect(s.fontSize, 24);
    expect(s.showTop, isFalse);
    // 点恢复默认（视口外，先滚动到可见）
    await ensureVisible(tester, find.text('恢复默认设置'));
    await tester.tap(find.text('恢复默认设置'));
    await tester.pumpAndSettle();
    expect(s.fontSize, 16);
    expect(s.showTop, isTrue);
  });

  testWidgets('设置变化后面板读数联动刷新（ListenableBuilder）', (tester) async {
    await pumpPanel(tester);
    expect(find.text('16'), findsOneWidget); // 字号读数
    await DanmakuSettings.instance.setFontSize(24);
    await tester.pumpAndSettle();
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('屏蔽词：展开后输入添加写设置', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    expect(s.blockedKeywords, isEmpty);

    await ensureVisible(tester, find.text('屏蔽词'));
    await tester.tap(find.text('屏蔽词'));
    await tester.pumpAndSettle();
    expect(find.text('输入要屏蔽的关键词'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '测试词');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(s.blockedKeywords, ['测试词']);
  });

  testWidgets('屏蔽词：词条删除', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.addBlockedKeyword('删除我');
    await tester.pumpAndSettle();

    await ensureVisible(tester, find.text('屏蔽词'));
    await tester.tap(find.text('屏蔽词'));
    await tester.pumpAndSettle();

    await ensureVisible(tester, find.byIcon(Icons.close));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(s.blockedKeywords, isEmpty);
  });

  // ── 「指定颜色」调色板（多色随机，方案 A）────────────────────────────

  testWidgets('调色板：点胶囊是多选（加/减），不是整体替换', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.setColorMode(DanmakuColorMode.fixed);
    await tester.pumpAndSettle();
    expect(s.colorValues, [kDanmakuDefaultColor]);

    // 加一种（黄）→ 两种
    await ensureVisible(tester, find.text('黄色'));
    await tester.tap(find.text('黄色'));
    await tester.pumpAndSettle();
    expect(s.colorValues.length, 2);
    expect(find.text('已选 2/8 种'), findsOneWidget);

    // 再点同一个（已选中）→ 从调色板**移除**，而不是替换
    await tester.tap(find.text('黄色'));
    await tester.pumpAndSettle();
    expect(s.colorValues, [kDanmakuDefaultColor]);
    expect(find.text('已选 1/8 种'), findsOneWidget);
  });

  testWidgets('调色板：全部取消后模式回落「跟随弹幕颜色」且调色区收起', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues([kDanmakuDefaultColor, '#FFFFEB3B']);
    await tester.pumpAndSettle();
    expect(find.text('已选 2/8 种'), findsOneWidget);

    // 预览条上的色块整块可点（× 在胶囊里）→ 逐个移除
    final first = find.byKey(
      const ValueKey('palette-tap-$kDanmakuDefaultColor'),
    );
    await ensureVisible(tester, first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(s.colorValues, ['#FFFFEB3B']);
    expect(find.text('已选 1/8 种'), findsOneWidget);

    final second = find.byKey(const ValueKey('palette-tap-#FFFFEB3B'));
    await ensureVisible(tester, second);
    await tester.tap(second);
    await tester.pumpAndSettle();

    expect(s.colorValues, isEmpty);
    expect(
      s.colorMode,
      DanmakuColorMode.source,
      reason: '调色板空 → 回落跟随弹幕颜色（不留下选了没颜色的死状态）',
    );
    expect(paletteTitle, findsNothing, reason: '调色区随模式收起');
  });

  testWidgets('调色板：清空后再点「指定颜色」能进得去（自动补默认色）', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;

    // 先清空调色板 → 模式回落「跟随弹幕颜色」
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues([kDanmakuDefaultColor, '#FFFFEB3B']);
    await s.setColorValues(const []);
    await tester.pumpAndSettle();
    expect(s.colorMode, DanmakuColorMode.source);
    expect(paletteTitle, findsNothing);

    // 再点「指定颜色」：必须能进去（真机 bug：这里怎么点都没反应）
    await ensureVisible(tester, find.text('指定颜色'));
    await tester.tap(find.text('指定颜色'));
    await tester.pumpAndSettle();
    expect(
      s.colorMode,
      DanmakuColorMode.fixed,
      reason: '空调色板切回指定颜色时自动补默认色，不能卡在 source',
    );
    expect(s.colorValues, [kDanmakuDefaultColor]);
    await ensureVisible(tester, paletteTitle);
    expect(paletteTitle, findsOneWidget, reason: '调色区重新展开');
  });

  testWidgets('调色板：预览条点色块移除该色，其余保留', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues([kDanmakuDefaultColor, '#FFFFEB3B']);
    await tester.pumpAndSettle();

    final swatch = find.byKey(
      const ValueKey('palette-tap-$kDanmakuDefaultColor'),
    );
    await ensureVisible(tester, swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();
    expect(
      s.colorValues,
      ['#FFFFEB3B'],
      reason: '点预览条上的色块只移除该色，其余保留',
    );
  });

  testWidgets('调色板：自定义调色要「调 → 预览 → 点添加」才入调色板', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.setColorMode(DanmakuColorMode.fixed);
    await tester.pumpAndSettle();
    expect(s.colorValues.length, 1);

    await ensureVisible(tester, find.text('自定义调色'));
    await tester.tap(find.text('自定义调色'));
    await tester.pumpAndSettle();

    // 草稿起点 = 调色板最后一色（白）→ 尚未产生新色，按钮提示「已在调色板中」
    expect(find.text('该颜色已在调色板中'), findsOneWidget);
    expect(s.colorValues.length, 1);

    // 拖 A 通道：只改草稿（**不写入调色板**）
    final slider = find.byType(Slider).at(8);
    await ensureVisible(tester, slider);
    await tester.drag(slider, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(
      s.colorValues.length,
      1,
      reason: '滑杆只改草稿，滑到哪就加一种颜色是错的',
    );

    // 确认添加才入调色板（草稿是半透明白，与纯白不同色）
    await ensureVisible(tester, find.text('添加到调色板'));
    await tester.tap(find.text('添加到调色板'));
    await tester.pumpAndSettle();
    expect(s.colorValues.length, 2);
    expect(find.text('已选 2/8 种'), findsOneWidget);
    // 草稿回到当前色 → 按钮重新变回「已添加」提示
    expect(find.text('该颜色已在调色板中'), findsOneWidget);
  });

  testWidgets('调色板：草稿与已选色重复时不能重复添加', (tester) async {
    await pumpPanel(tester);
    final s = DanmakuSettings.instance;
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues([kDanmakuDefaultColor, '#FFFFEB3B']);
    await tester.pumpAndSettle();

    // 草稿起点 = 最后一色（黄，#FFEB3B）→ 与已选同色（写法不同），按钮禁用
    expect(find.text('该颜色已在调色板中'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: '同色不允许重复添加');
    expect(s.colorValues.length, 2);
  });
}
