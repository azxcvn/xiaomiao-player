import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/wallpaper_editor_page.dart';
import 'package:moumou/services/wallpaper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 壁纸调整页测试：读数、重置、切换适应/填充清零、保存写入、返回不写入。
///
/// ⚠️ 当前**整体跳过**：这些 widget 用例在本机测试环境下会挂住（跑不出结果，
/// 既不是断言失败也没有异常，疑似出在图片解码 / `pumpAndSettle` 等待上）。
/// 按用户要求先 skip、不再排查，避免拖住测试套件。功能覆盖现状：
/// - 参数钳制 / 持久化 / 拷贝与删除 / 清除 / 文件丢失兜底 由
///   `wallpaper_settings_test.dart` 覆盖（全部通过）；
/// - 编辑器交互（读数、重置、适应/填充、保存）待真机 / 修好环境后由人工确认，
///   恢复方式：删掉每个 `testWidgets` 上的 `skip: _skipReason` 即可。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // testWidgets 的 skip 只接受 bool（原因写在文件头注释里）；
  // 想恢复这些用例：把这个常量改成 false。
  const bool skipEditorWidgetTests = true;

  late Directory tempDir;
  late File sourceImage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperSettings.instance.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('wallpaper_editor_test');
    WallpaperSettings.debugDirOverride = tempDir.path;
    // 只要求「存在且非空」：壁纸层对解不出来的文件静默跳过（errorBuilder），
    // 所以测试不需要真图（真图要在 setUp 里调引擎编码，测试环境下会挂住）
    sourceImage = File(p.join(tempDir.path, 'src.png'))
      ..writeAsBytesSync(List<int>.filled(64, 3));
  });

  tearDown(() {
    WallpaperSettings.instance.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final settings = WallpaperSettings.instance;

  /// 从一个占位首页 push 调整页——保存成功会 pop 回来，
  /// 直接把它当 home 的话 pop 会落到空路由上
  Future<void> pumpEditor(WidgetTester tester, {String? sourcePath}) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WallpaperEditorPage(sourcePath: sourcePath),
                  ),
                ),
                child: const Text('打开调整页'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开调整页'));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染：适应/填充 + 5 条滑杆 + 重置 + 保存壁纸', (tester) async {
    await pumpEditor(tester, sourcePath: sourceImage.path);

    expect(find.text('调整壁纸'), findsOneWidget);
    expect(find.text('适应'), findsOneWidget);
    expect(find.text('填充'), findsOneWidget);
    expect(find.text('缩放'), findsOneWidget);
    expect(find.text('水平位置'), findsOneWidget);
    expect(find.text('垂直位置'), findsOneWidget);
    expect(find.text('模糊'), findsOneWidget);
    expect(find.text('透明度'), findsOneWidget);
    expect(find.text('重置'), findsOneWidget);
    expect(find.text('保存壁纸'), findsOneWidget);
    // 新选图 → 全部走默认值
    expect(find.text('1.00x'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  }, skip: skipEditorWidgetTests);

  testWidgets('保存：图片生效 + 参数写入 + 返回上一页', (tester) async {
    await pumpEditor(tester, sourcePath: sourceImage.path);

    await tester.tap(find.text('保存壁纸'));
    await tester.pumpAndSettle();

    expect(settings.active, isTrue);
    expect(File(settings.path!).existsSync(), isTrue);
    expect(settings.scaleMode, WallpaperScaleMode.fit);
    expect(settings.scale, WallpaperSettings.defaultScale);
    // 已 pop 回占位首页
    expect(find.text('打开调整页'), findsOneWidget);
    expect(find.text('调整壁纸'), findsNothing);
  }, skip: skipEditorWidgetTests);

  testWidgets('调整现有壁纸：载入已存参数；重置后读数回默认', (tester) async {
    await settings.apply(
      sourcePath: sourceImage.path,
      scale: 2.5,
      offsetX: 0.5,
      offsetY: 0,
      scaleMode: WallpaperScaleMode.fill,
      blur: 20,
      opacity: 0.6,
    );

    await pumpEditor(tester);
    expect(find.text('2.50x'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    // 位移读数按「屏幕百分比」显示：0.5 × 35% = 17.5 → 18
    expect(find.text('+18%'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(find.text('1.00x'), findsOneWidget);
    expect(find.text('居中'), findsNWidgets(2)); // 水平 + 垂直
    expect(find.text('100%'), findsOneWidget);
  }, skip: skipEditorWidgetTests);

  testWidgets('切换适应/填充：缩放与位移被清零（保存后生效）', (tester) async {
    await settings.apply(
      sourcePath: sourceImage.path,
      scale: 2.5,
      offsetX: 0.5,
      offsetY: 0.5,
      scaleMode: WallpaperScaleMode.fit,
      blur: 0,
      opacity: 1,
    );

    await pumpEditor(tester);
    expect(find.text('2.50x'), findsOneWidget);

    await tester.tap(find.text('填充'));
    await tester.pumpAndSettle();
    expect(find.text('1.00x'), findsOneWidget);
    expect(find.text('居中'), findsNWidgets(2));

    await tester.tap(find.text('保存壁纸'));
    await tester.pumpAndSettle();

    expect(settings.scaleMode, WallpaperScaleMode.fill);
    expect(settings.scale, WallpaperSettings.defaultScale);
    expect(settings.offsetX, WallpaperSettings.defaultOffset);
    expect(settings.offsetY, WallpaperSettings.defaultOffset);
  }, skip: skipEditorWidgetTests);

  testWidgets('直接返回不保存：设置保持不变', (tester) async {
    await settings.apply(
      sourcePath: sourceImage.path,
      scale: 2,
      offsetX: 0,
      offsetY: 0,
      scaleMode: WallpaperScaleMode.fit,
      blur: 0,
      opacity: 1,
    );
    final savedPath = settings.path;
    final savedScale = settings.scale;

    await pumpEditor(tester);
    // 改了参数但不保存
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(find.text('1.00x'), findsOneWidget);

    await tester.tap(find.byTooltip('Back')); // AppBar 返回
    await tester.pumpAndSettle();

    expect(settings.path, savedPath);
    expect(settings.scale, savedScale, reason: '没点保存就不该写设置');
  }, skip: skipEditorWidgetTests);

  testWidgets('图片已不可用（源图被删）：保存按钮禁用并给出提示文案', (tester) async {
    final gone = File(p.join(tempDir.path, 'gone.png'));
    await pumpEditor(tester, sourcePath: gone.path);

    expect(find.text('图片已不可用，请重新选择'), findsOneWidget);
    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '保存壁纸'),
    );
    expect(saveButton.onPressed, isNull, reason: '拿不到图时不允许保存');
  }, skip: skipEditorWidgetTests);
}
