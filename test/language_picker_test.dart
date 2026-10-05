import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/settings_page.dart';
import 'package:moumou/services/app_locale_settings.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:moumou/widgets/language_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 语言入口回归测试（阶段 2）：
/// - 弹窗只有「简体中文 / English」两项、**默认选中简体中文**、标题是双语；
/// - 点「确定」写入 `app_locale`（值只允许 zh/en）；点「取消」/关闭 = 不改；
/// - 设置页「语言」组的位置：**在「弹幕」组下方、「下载」组上方**；
/// - 设置页「语言设置」项能打开同一个弹窗。
void main() {
  final settings = AppLocaleSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings.resetForTest();
    // ⚠️ 这里**不要**预热 `ensureLoaded()`：预热出的 Future 属于真实事件循环的
    // zone，widget 测试体内的 `await` 续体会被排到 `pump` 驱动不到的微任务队列，
    // 于是「写 app_locale」永远不生效（与 player_decode_panel_test 同一个坑）。
    // 保持惰性：第一次 setLocale 在 fake zone 内创建加载链，pump 就能推进。
  });

  Future<void> pumpHost(WidgetTester tester, {Widget? child}) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: child ??
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showLanguagePickerDialog(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('弹窗：标题随语言 + 三项自称 + 默认选中简体中文', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择语言'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    // 默认选中简体中文：勾选图标落在「简体中文」那一行
    final zhRow = find.ancestor(
      of: find.text('简体中文'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: zhRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(settings.rawValue, 'zh');
  });

  testWidgets('选繁體中文 + 确定：写入 app_locale=zh_Hant 并持久化', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(settings.rawValue, 'zh_Hant');
    // 这一条守住「不许把 locale getter 写成 Locale('zh_Hant')」：
    // 那种写法与生成物 supportedLocales 里的项不相等，界面会静默回落简体
    expect(settings.locale, kTestLocaleZhHant);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'zh_Hant');
  });

  testWidgets('设置页副标题：设置为繁体后显示「繁體中文」', (tester) async {
    // 先把设置设成繁体再 pump（AppLocaleSettings 是 ChangeNotifier，
    // 测试宿主没有监听它，pump 之后再改不会重建界面）
    await settings.setLocale(AppLocaleSettings.zhHantCode);
    await pumpHost(
      tester,
      child: SettingsPage(controller: ThemeController()),
    );

    expect(find.text('繁體中文'), findsOneWidget);
    expect(settings.rawValue, 'zh_Hant');
  });

  testWidgets('选 English + 确定：写入 app_locale=en 并持久化', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(settings.rawValue, 'en');
    expect(settings.locale, const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');
  });

  testWidgets('点取消：不改语言（保持简体中文）', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(settings.rawValue, 'zh');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), isNull);
  });

  testWidgets('设置页：「语言」组在「弹幕」下方、「下载」上方，项名为「语言设置」', (tester) async {
    await pumpHost(
      tester,
      child: SettingsPage(controller: ThemeController()),
    );

    final yDanmaku = tester.getTopLeft(find.text('弹幕')).dy;
    final yLanguage = tester.getTopLeft(find.text('语言')).dy;
    final yDownload = tester.getTopLeft(find.text('下载')).dy;
    expect(yLanguage, greaterThan(yDanmaku));
    expect(yLanguage, lessThan(yDownload));

    expect(find.text('语言设置'), findsOneWidget);
    // 副标题显示当前语言（自称）
    expect(find.text('简体中文'), findsOneWidget);
  });

  testWidgets('设置页点「语言设置」→ 打开同一个弹窗，改完立即写设置', (tester) async {
    await pumpHost(
      tester,
      child: SettingsPage(controller: ThemeController()),
    );

    await tester.tap(find.text('语言设置'));
    await tester.pumpAndSettle();
    expect(find.text('选择语言'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(settings.rawValue, 'en');
  });
}
