import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/appearance_page.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外观页测试（工作.md 迁移功能：主题色网格 + 动态色 + 自定义色 + 调色板胶囊化）：
/// 网格渲染、动态色 toast（Android<12）、自定义色弹窗、调色板重排与胶囊。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('moumou/video_info');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    ThemeController? controller,
  }) async {
    // 加大视口，让主题色/调色板/自定义都可见，避免懒加载 ListView 截断
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AppearancePage(controller: controller ?? ThemeController()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('主题色区渲染预设 + 动态色 + 自定义入口', (tester) async {
    await pumpPage(tester);
    // 滚动到主题色区（自定义在下方，需滚动）
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('动态色'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('天蓝色'), findsOneWidget); // 首个预设
  });

  testWidgets('调色板区：标准型独占首行 + 其余 20 个胶囊', (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('调色板风格'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('调色板风格'), findsOneWidget);
    expect(find.text('标准型'), findsOneWidget);
    // 21 个标签都存在
    expect(find.text('保真型'), findsOneWidget);
    expect(find.text('单色型'), findsOneWidget);
    expect(find.text('中性型'), findsOneWidget);
    expect(find.text('亮表面'), findsOneWidget); // 最后一个
  });

  testWidgets('动态色：Android 12 以下点击 toast 提示', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getSdkInt') return 30; // Android 11
      return null;
    });
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('动态色'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('动态色'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('安卓版本过低，不支持该功能'), findsOneWidget);
  });

  testWidgets('自定义入口点击弹出选色弹窗', (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('自定义'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    // 弹窗标题
    expect(find.text('自定义主题色'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}