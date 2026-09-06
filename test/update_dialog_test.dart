import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/update_info.dart';
import 'package:moumou/services/update/update_service.dart';
import 'package:moumou/services/update/update_settings.dart';
import 'package:moumou/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 更新弹窗测试（工作.md：更新功能）：
/// 三按钮齐全、Markdown 无原生符号、忽略本版本落盘、立即更新弹子菜单与 Toast。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateSettings.instance.resetForTest();
  });

  /// 空下载链接的 UpdateInfo（测试「待接入」Toast 回退分支）
  const emptyUpdate = UpdateInfo(version: '1.1.0', body: 'test');

  /// 打开更新弹窗（模拟从某个入口调用；info 默认用开发写死的新版本）
  Future<void> pumpDialog(WidgetTester tester, {UpdateInfo? info}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUpdateDialog(
                context,
                info: info ?? UpdateService.devUpdate,
                settings: UpdateSettings.instance,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 弹窗转场完成
  }

  testWidgets('弹窗：标题 + 三按钮 + Markdown 无原生符号', (tester) async {
    await pumpDialog(tester);

    expect(find.text('发现新版本 1.1.0'), findsOneWidget);
    expect(find.byKey(UpdateDialog.ignoreButtonKey), findsOneWidget);
    expect(find.byKey(UpdateDialog.remindButtonKey), findsOneWidget);
    expect(find.byKey(UpdateDialog.updateButtonKey), findsOneWidget);
    expect(find.text('忽略'), findsOneWidget);
    expect(find.text('稍后提醒'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);

    // Markdown 已渲染：不应残留 ## / ** 等原生符号
    expect(find.textContaining('##', findRichText: true), findsNothing);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });

  testWidgets('忽略本版本：写入 ignoredVersion', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(UpdateDialog.ignoreButtonKey));
    await tester.pumpAndSettle();

    expect(UpdateSettings.instance.ignoredVersion, '1.1.0');
  });

  testWidgets('稍后提醒：不写入忽略版本', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(UpdateDialog.remindButtonKey));
    await tester.pumpAndSettle();

    expect(UpdateSettings.instance.ignoredVersion, '');
  });

  testWidgets('立即更新：弹下载方式子菜单，点主下载站 Toast 待接入', (tester) async {
    await pumpDialog(tester, info: emptyUpdate);

    await tester.tap(find.byKey(UpdateDialog.updateButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 子菜单出现，含主 / 备用下载站
    expect(find.text('选择下载方式'), findsOneWidget);
    expect(find.text('主下载站'), findsOneWidget);
    expect(find.text('备用下载站'), findsOneWidget);

    // 点主下载站（链接为空）→ Toast 待接入
    await tester.tap(find.text('主下载站'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('主下载站链接待接入'), findsOneWidget);
  });

  testWidgets('立即更新：点备用下载站 Toast 待接入', (tester) async {
    await pumpDialog(tester, info: emptyUpdate);

    await tester.tap(find.byKey(UpdateDialog.updateButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('备用下载站'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('备用下载站链接待接入'), findsOneWidget);
  });
}
