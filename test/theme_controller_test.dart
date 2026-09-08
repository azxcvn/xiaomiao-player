import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('默认值：主题模式/主题色/调色板/自定义色', () async {
    final c = ThemeController();
    await c.load();
    expect(c.mode, AppThemeMode.system);
    expect(c.seedColor, const Color(0xFF00A1D6));
    expect(c.variant, FlexSchemeVariant.tonalSpot);
    expect(c.customColor, isNull);
  });

  test('预设主题色数量 23、首色天蓝', () {
    expect(ThemeController.presetColors.length, 23);
    expect(ThemeController.presetColors.first.label, '天蓝色');
    expect(ThemeController.presetColors.first.color, const Color(0xFF00A1D6));
  });

  test('调色板风格标签 21 种、含标准型', () {
    expect(ThemeController.variantLabels.length, 21);
    expect(ThemeController.variantLabels[FlexSchemeVariant.tonalSpot], '标准型');
  });

  test('setCustomColor：持久化并作为 seed 立即生效', () async {
    final c = ThemeController();
    await c.load();
    const color = Color(0xFF123456);
    await c.setCustomColor(color);
    expect(c.customColor, color);
    expect(c.seedColor, color);
    // 模拟重启
    final c2 = ThemeController();
    await c2.load();
    expect(c2.customColor, color);
    expect(c2.seedColor, color);
  });

  test('setSeedColor 不影响 customColor（预设色切换不改自定义色）', () async {
    final c = ThemeController();
    await c.load();
    await c.setCustomColor(const Color(0xFF123456));
    await c.setSeedColor(const Color(0xFF00A1D6));
    expect(c.seedColor, const Color(0xFF00A1D6));
    expect(c.customColor, const Color(0xFF123456)); // 自定义色保留
  });

  test('动态色：setDynamicColor 置标记并持久化，切换预设/自定义清除标记', () async {
    final c = ThemeController();
    await c.load();
    expect(c.usingDynamicColor, isFalse);

    await c.setDynamicColor(const Color(0xFFABCDEF));
    expect(c.usingDynamicColor, isTrue);
    expect(c.seedColor, const Color(0xFFABCDEF));

    // 模拟重启：动态色标记持久化
    final c2 = ThemeController();
    await c2.load();
    expect(c2.usingDynamicColor, isTrue);

    // 切预设色 → 清除动态标记
    await c2.setSeedColor(const Color(0xFF00A1D6));
    expect(c2.usingDynamicColor, isFalse);
    expect(c2.seedColor, const Color(0xFF00A1D6));

    // 选自定义色 → 清除动态标记
    await c2.setDynamicColor(const Color(0xFFABCDEF));
    expect(c2.usingDynamicColor, isTrue);
    await c2.setCustomColor(const Color(0xFF223344));
    expect(c2.usingDynamicColor, isFalse);
    expect(c2.seedColor, const Color(0xFF223344));
  });
}