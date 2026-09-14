import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_decode_panel.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/widgets/player_option_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 解码面板测试（P3）：点「当前已选档位 / 预设」不该弹「需重启应用」
/// —— 没有改动就没有需要重启的东西。
///
/// ⚠️ `setUp` 里**不要**预热 `DecodeSettings.ensureLoaded()`：预热出来的 Future
/// 属于真实事件循环的 zone，widget 测试体内的 `await` 续体会被排到 `pump` 驱动
/// 不到的微任务队列里（fake-async 家族的坑），于是「写设置」永远不生效。
/// 这里保持惰性：第一次 `setMode` 在 fake zone 内创建加载链，`pump` 就能推进。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlayerDecodePanel())),
    );
    await tester.pumpAndSettle();
  }

  // 胶囊顺序：0-3 = 解码方式（自动/硬解/硬解+/软解），4-9 = 解码预设
  Finder modeChip(DecodeMode mode) =>
      find.byType(PlayerOptionChip).at(DecodeMode.values.indexOf(mode));

  Finder presetChip(DecodePreset preset) => find
      .byType(PlayerOptionChip)
      .at(DecodeMode.values.length + DecodePreset.values.indexOf(preset));

  testWidgets('初始档位与预设为默认值（自动 / 快速）', (tester) async {
    await pumpPanel(tester);
    expect(DecodeSettings.instance.mode, DecodeMode.autoSafe);
    expect(DecodeSettings.instance.preset, DecodePreset.fast);
  });

  testWidgets('点当前已选解码档位：不弹「需重启应用」', (tester) async {
    await pumpPanel(tester);

    await tester.tap(modeChip(DecodeMode.autoSafe));
    await tester.pumpAndSettle();

    expect(DecodeSettings.instance.mode, DecodeMode.autoSafe);
    expect(find.text('需重启应用'), findsNothing);
  });

  testWidgets('点其它解码档位：写入设置并弹「需重启应用」', (tester) async {
    await pumpPanel(tester);

    await tester.tap(modeChip(DecodeMode.sw));
    await tester.pumpAndSettle();

    expect(DecodeSettings.instance.mode, DecodeMode.sw);
    expect(find.text('需重启应用'), findsOneWidget);

    // 关掉弹窗，避免影响后续用例
    await tester.tap(find.text('稍后重启'));
    await tester.pumpAndSettle();
  });

  testWidgets('点当前已选解码预设：不弹「需重启应用」', (tester) async {
    await pumpPanel(tester);

    await tester.tap(presetChip(DecodePreset.fast));
    await tester.pumpAndSettle();

    expect(DecodeSettings.instance.preset, DecodePreset.fast);
    expect(find.text('需重启应用'), findsNothing);
  });
}
