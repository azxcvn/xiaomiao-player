import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/about_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'l10n_test_helper.dart';

/// 关于页顶部信息卡片测试（设计稿见 docs/archive/design-about-info-card.html）：
/// - 上排 = 图标 + 名称 + GitHub/邮箱两个图标按钮（横排）；
/// - 下排 = 版本 / 构建类型 / 提交哈希三枚等宽胶囊；
/// - 布局不得溢出（溢出会抛 RenderFlex 异常，360dp 是设计约束宽度）；
/// - 名称是「13dp 左内边距」的余量瓶颈，不该被挤成省略号（见 [_testCjkFont]）。
///
/// 注：`--dart-define` 注入的哈希在测试环境读不到真实值，这里只断言占位表现
/// （dev build），不伪造构建产物里的值。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 真实 CJK 字体的候选路径。
  ///
  /// 为什么要它：flutter_test 默认用 Ahem —— 每个字符都按一个 em 方框排版，
  /// 汉字宽度被放大成满格，会把「名称会不会被挤省略」测成假阳性。用真实字体
  /// 度量才有意义。仓库里没有随包正文字体（用的是系统字体），所以借参考项目
  /// 的 MiSans；**文件不存在时相关用例跳过**，不伪装成通过。
  const fontCandidates = [
    r'杂项文件\参考项目\Kazumi-main\Kazumi-main\assets\fonts\MiSans-Regular.ttf',
    r'杂项文件\参考项目\mpvRx-2.6.0\mpvRx-2.6.0\app\src\main\res\font\roboto_flex.ttf',
  ];

  String? cjkFontPath() {
    for (final p in fontCandidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// 读字体文件并注册成 `TestCJK`。
  ///
  /// **必须包在 [WidgetTester.runAsync] 里**：`testWidgets` 的函数体跑在
  /// flutter_test 的 fake-async 区，真实异步 I/O（`File.readAsBytes`）与引擎字体
  /// 注册在那里**永远不会完成** —— 直接 `await` 会一挂不返（实测整轮
  /// `flutter test` 被这一条拖到 10 分钟默认超时）。
  Future<bool> loadTestFont(WidgetTester tester) async {
    final path = cjkFontPath();
    if (path == null) return false;
    final loaded = await tester.runAsync(() async {
      final bytes = await File(path).readAsBytes();
      final loader = FontLoader('TestCJK')
        ..addFont(Future.value(bytes.buffer.asByteData()));
      await loader.load();
      return true;
    });
    return loaded ?? false;
  }

  ThemeData themeWithFont() => ThemeData(useMaterial3: true, fontFamily: 'TestCJK');

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'moumou',
      packageName: 'com.azxcvn.moumou',
      version: '1.3.6',
      buildNumber: '4',
      buildSignature: '',
      installerStore: null,
    );
  });

  Future<void> pumpAbout(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    TextScaler scaler = TextScaler.noScaling,
    bool withFont = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: MaterialApp(
          theme: withFont ? themeWithFont() : null,
          locale: kTestLocaleZh,
          localizationsDelegates: kTestLocalizationDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const AboutPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('顶部卡片：名称 + 三枚胶囊 + 两个联系按钮都渲染', (tester) async {
    await pumpAbout(tester);

    expect(find.text('小喵Player'), findsOneWidget);
    // 版本只显示版本名（不带构建号）；构建类型在测试环境是 debug 编译，故为 debug
    expect(find.text('v1.3.6'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);
    // 未注入哈希 → 占位而不是假值
    expect(find.text('dev build'), findsOneWidget);

    expect(find.byTooltip('GitHub'), findsOneWidget);
    expect(find.byTooltip('发送使用反馈'), findsOneWidget);

    // 无布局溢出（RenderFlex overflow 会以异常形式抛出）
    expect(tester.takeException(), isNull);
  });

  testWidgets('360dp 宽度下不溢出', (tester) async {
    await pumpAbout(tester, size: const Size(360, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实字体 + 360dp：名称不被挤成省略号（13dp 内边距的余量验证）', (tester) async {
    final loaded = await loadTestFont(tester);
    if (!loaded) {
      markTestSkipped('未找到真实 CJK 字体（参考项目不在本机），跳过字体度量验证');
      return;
    }
    await pumpAbout(tester, size: const Size(360, 800), withFont: true);

    final paragraph = tester.renderObject<RenderParagraph>(find.text('小喵Player'));
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('系统字号放大到 1.3 倍：布局不报溢出异常（名称可省略，但不许炸）', (tester) async {
    await pumpAbout(
      tester,
      size: const Size(360, 900),
      scaler: const TextScaler.linear(1.3),
    );
    // 大字号下名称允许出现省略号（Flutter 的 ellipsis 是正常降级），
    // 但绝不允许 RenderFlex overflow —— 那才是真问题。
    expect(tester.takeException(), isNull);
  });

  testWidgets('未注入哈希时：点击哈希胶囊给「未注入」提示，且不写剪贴板', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpAbout(tester);
    await tester.tap(find.text('dev build'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.textContaining('未注入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('版本 / 构建类型胶囊不可点击（点了没有反馈）', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.text('v1.3.6'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('debug'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsNothing);
  });
}
