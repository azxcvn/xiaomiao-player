import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/subtitle/subtitle_download_page.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 影视字幕下载页 UI 测试：初始态（字幕设置入口 + 关键词输入 + 目录栏）、
/// 字幕设置子页五入口、语言多选摘要联动、API 密钥弹窗取消/保存回归。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WyzieSettings.instance.resetForTest();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SubtitleDownloadPage()));
    await tester.pumpAndSettle();
  }

  /// 点主页「字幕下载设置」入口进入设置子页。
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('字幕下载设置'));
    await tester.pumpAndSettle();
  }

  testWidgets('初始态：字幕下载设置入口 + 关键词输入 + 确定按钮 + 目录栏', (tester) async {
    await pumpPage(tester);

    expect(find.text('字幕下载设置'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('未设置下载目录'), findsOneWidget);
    // 五个设置项已收敛到子页，主页不再平铺
    expect(find.text('WYZIE API 密钥'), findsNothing);
  });

  testWidgets('字幕设置子页：五个设置项齐全', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    expect(find.text('WYZIE API 密钥'), findsOneWidget);
    expect(find.text('字幕来源'), findsOneWidget);
    expect(find.text('字幕语言'), findsOneWidget);
    expect(find.text('首选格式'), findsOneWidget);
    expect(find.text('首选编码'), findsOneWidget);
  });

  testWidgets('字幕语言弹窗勾选「全部」后摘要更新为全部语言', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    // 默认摘要 English、Chinese
    expect(find.text('English、Chinese'), findsOneWidget);

    await tester.tap(find.text('字幕语言'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);

    await tester.tap(
      find.descendant(of: dialog, matching: find.text('全部')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('确定')),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部语言'), findsOneWidget);
    expect(WyzieSettings.instance.languages, {'all'});
  });

  testWidgets('API 密钥弹窗：取消关闭不崩溃（回归：控制器不得提前 dispose）', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    await tester.tap(find.text('WYZIE API 密钥'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('如何获取密钥'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('未设置 API 密钥点确定 → toast 请先设置密钥', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Inception');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('请先设置 WYZIE API 密钥'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('API 密钥弹窗：输入密钥确定后保存并显示已保存', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);
    expect(find.text('未设置'), findsOneWidget);

    await tester.tap(find.text('WYZIE API 密钥'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '  wyzie-abc  ',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('确定'),
      ),
    );
    await tester.pumpAndSettle();

    expect(WyzieSettings.instance.apiKey, 'wyzie-abc', reason: '去掉首尾空白');
    expect(find.text('已保存'), findsOneWidget);
  });
}
