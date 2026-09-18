import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/options_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「排序与字段」面板 - 视频显示字段布局测试：
/// 新增的「完整名称」胶囊与「字幕指示器」**同一行**（原来是字幕指示器独占
/// 一整行），该行由 1 个胶囊变成 2 个，且「完整名称」默认选中。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ViewSettings> pumpSheet(WidgetTester tester) async {
    // 面板较长：放大视口让整块一次布局完成
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = ViewSettings();
    await settings.ensureLoaded();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSortOptionsSheet(
                  context,
                  settings,
                  hasFolders: false,
                  hasVideos: true,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('完整名称与字幕指示器同一行、默认选中、点击可切换', (tester) async {
    final settings = await pumpSheet(tester);

    expect(find.text('视频显示字段'), findsOneWidget);
    expect(find.text('完整名称'), findsOneWidget);
    expect(find.text('字幕指示器'), findsOneWidget);
    // 同一行：两个胶囊的垂直中心一致
    expect(
      tester.getCenter(find.text('完整名称')).dy,
      tester.getCenter(find.text('字幕指示器')).dy,
    );
    // 默认选中
    expect(settings.videoFields, contains(VideoField.fullName));

    await tester.tap(find.text('完整名称'));
    await tester.pumpAndSettle();
    expect(settings.videoFields, isNot(contains(VideoField.fullName)));

    await tester.tap(find.text('完整名称'));
    await tester.pumpAndSettle();
    expect(settings.videoFields, contains(VideoField.fullName));
  });
}
