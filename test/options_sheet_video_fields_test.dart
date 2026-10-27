import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/options_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 「排序与字段」面板 - 视频显示字段布局测试：
/// 新增的「完整名称」胶囊与「字幕指示器」**同一行**（原来是字幕指示器独占
/// 一整行），该行由 1 个胶囊变成 2 个，且「完整名称」默认选中。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ViewSettings> pumpSheet(
    WidgetTester tester, {
    bool hasFolders = false,
    bool hasVideos = true,
  }) async {
    // 面板较长：放大视口让整块一次布局完成
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = ViewSettings();
    await settings.ensureLoaded();
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSortOptionsSheet(
                  context,
                  settings,
                  hasFolders: hasFolders,
                  hasVideos: hasVideos,
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

  testWidgets('分辨率与帧率合并成一个开关：点一次同时开关两个字段', (tester) async {
    final settings = await pumpSheet(tester);

    // 面板里只有一个合并开关，不再有单独的「帧率」「分辨率」
    expect(find.text('分辨率/帧率'), findsOneWidget);
    expect(find.text('帧率'), findsNothing);
    expect(find.text('分辨率'), findsNothing);
    // 默认两个字段都没开
    expect(settings.videoFields, isNot(contains(VideoField.resolution)));
    expect(settings.videoFields, isNot(contains(VideoField.frameRate)));

    await tester.tap(find.text('分辨率/帧率'));
    await tester.pumpAndSettle();
    expect(
      settings.videoFields,
      containsAll([VideoField.resolution, VideoField.frameRate]),
    );

    await tester.tap(find.text('分辨率/帧率'));
    await tester.pumpAndSettle();
    expect(settings.videoFields, isNot(contains(VideoField.resolution)));
    expect(settings.videoFields, isNot(contains(VideoField.frameRate)));
  });

  testWidgets('老数据只开了其中一个字段：点一下合并开关补齐另一个', (tester) async {
    // 分辨率 = index 3（「分辨率」「帧率」分开存的旧配置）
    SharedPreferences.setMockInitialValues({
      'view_video_fields_v2': ['3'],
    });
    final settings = await pumpSheet(tester);
    expect(settings.videoFields, {VideoField.resolution});

    await tester.tap(find.text('分辨率/帧率'));
    await tester.pumpAndSettle();
    expect(
      settings.videoFields,
      containsAll([VideoField.resolution, VideoField.frameRate]),
    );
  });

  testWidgets('文件夹字段顺序：数量、大小在前，路径、日期在后', (tester) async {
    // 纯文件夹面板：避免视频区里的同名字段干扰定位
    await pumpSheet(tester, hasFolders: true, hasVideos: false);

    // 排序区里也有「数量/大小/日期」同名胶囊，字段区排在它们后面 → 取最后一个
    Offset chip(String label) => tester.getTopLeft(find.text(label).last);
    bool before(Offset a, Offset b) =>
        a.dy < b.dy - 1 || ((a.dy - b.dy).abs() <= 1 && a.dx < b.dx);

    const labels = ['数量', '大小', '路径', '日期'];
    final positions = labels.map(chip).toList();
    for (var i = 0; i < positions.length - 1; i++) {
      expect(
        before(positions[i], positions[i + 1]),
        isTrue,
        reason: '「${labels[i]}」应排在「${labels[i + 1]}」前面',
      );
    }
  });
}
