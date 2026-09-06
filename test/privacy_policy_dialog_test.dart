import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/widgets/privacy_policy_dialog.dart';

/// 隐私弹窗测试（工作.md：隐私政策功能）：
/// 5 秒倒计时门禁 + 勾选同意才可确认 + 取消/同意返回值。
void main() {
  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
        find.byKey(PrivacyPolicyDialog.confirmButtonKey),
      );

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyPolicyDialog())),
    );
    await tester.pump();
  }

  testWidgets('初始：确认按钮禁用，显示 5 秒倒计时', (tester) async {
    await pumpDialog(tester);

    expect(confirmButton(tester).onPressed, isNull);
    expect(find.text('同意并继续 (5 秒)'), findsOneWidget);
    expect(find.text('我已阅读并同意以上隐私政策'), findsOneWidget);
  });

  testWidgets('倒计时结束前确认按钮始终禁用（即使已勾选）', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(PrivacyPolicyDialog.agreeCheckboxKey));
    await tester.pump();
    expect(
      tester.widget<CheckboxListTile>(
        find.byKey(PrivacyPolicyDialog.agreeCheckboxKey),
      ).value,
      isTrue,
    );

    // 推进 2 秒（剩余 3 秒）→ 仍禁用
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('同意并继续 (3 秒)'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('倒计时结束但未勾选 → 确认仍禁用', (tester) async {
    await pumpDialog(tester);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('同意并继续'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('倒计时结束 + 勾选同意 → 确认可用', (tester) async {
    await pumpDialog(tester);

    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byKey(PrivacyPolicyDialog.agreeCheckboxKey));
    await tester.pump();

    expect(find.text('同意并继续'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('取消按钮返回 false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPrivacyPolicyDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 弹窗转场完成

    await tester.tap(find.byKey(PrivacyPolicyDialog.cancelButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(result, isFalse);
  });

  testWidgets('倒计时 + 勾选后点同意返回 true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPrivacyPolicyDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.pump(const Duration(seconds: 5)); // 倒计时结束
    await tester.tap(find.byKey(PrivacyPolicyDialog.agreeCheckboxKey));
    await tester.pump();
    await tester.tap(find.byKey(PrivacyPolicyDialog.confirmButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(result, isTrue);
  });
}
