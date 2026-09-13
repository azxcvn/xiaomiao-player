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

  // ---- B2 调色板风格持久化收口（P0-3 / P1-37）----

  test('set 全部 21 个风格 → load 往返一致（含 index<8 的旧映射重灾区）', () async {
    // 标签表覆盖库内全部枚举（外观页 4×5+通栏 = 21 个胶囊）
    expect(
      ThemeController.variantLabels.length,
      FlexSchemeVariant.values.length,
    );
    final c = ThemeController();
    await c.ensureLoaded();
    for (final variant in FlexSchemeVariant.values) {
      await c.setVariant(variant);
      final reopened = ThemeController();
      await reopened.load();
      expect(reopened.variant, variant, reason: '风格 ${variant.name} 重启后必须保持');
    }
  });

  test('新键里的 index<8 按新枚举读回（存保真型不再读成中性型）', () async {
    // 旧 bug：load 对 index<8 无条件走旧 DynamicSchemeVariant 映射
    SharedPreferences.setMockInitialValues({
      'theme_variant_scheme_v2': FlexSchemeVariant.fidelity.index,
    });
    final c = ThemeController();
    await c.load();
    expect(FlexSchemeVariant.fidelity.index, lessThan(8)); // 正是重灾区区间
    expect(c.variant, FlexSchemeVariant.fidelity);
    expect(c.variant, isNot(FlexSchemeVariant.neutral));
  });

  test('旧键只迁移一次：按旧语义映射并写回新键，此后旧键不再参与读取', () async {
    // 旧数据：theme_variant=1（旧 DynamicSchemeVariant[1] = neutral）
    SharedPreferences.setMockInitialValues({'theme_variant': 1});
    final first = ThemeController();
    await first.load();
    expect(first.variant, FlexSchemeVariant.neutral);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('theme_variant_scheme_v2'),
      FlexSchemeVariant.neutral.index,
      reason: '迁移结果必须写回新键（此后旧键不再被读）',
    );

    // 迁移后用户改选「保真型」→ 重启后仍是保真型（若二次迁移就会变回中性格）
    await first.setVariant(FlexSchemeVariant.fidelity);
    final second = ThemeController();
    await second.load();
    expect(second.variant, FlexSchemeVariant.fidelity);
  });

  // ---- B2 加载纪律（D10：与 P1-30/P1-31 同款）----

  test('ensureLoaded 复用同一 load Future（与 main.dart 共享）', () async {
    SharedPreferences.setMockInitialValues({
      'theme_variant_scheme_v2': FlexSchemeVariant.vibrant.index,
    });
    final c = ThemeController();
    final f1 = c.ensureLoaded();
    final f2 = c.ensureLoaded();
    expect(identical(f1, f2), isTrue);
    await f1;
    expect(c.variant, FlexSchemeVariant.vibrant);
  });

  test('setter 首行 await 读盘：同步段不写内存，读盘完成后不回退成磁盘值', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': AppThemeMode.light.index,
      'theme_variant_scheme_v2': FlexSchemeVariant.vibrant.index,
    });
    final c = ThemeController();
    final pending = c.setVariant(FlexSchemeVariant.fidelity); // 故意不 await
    expect(c.variant, FlexSchemeVariant.tonalSpot); // 默认值：同步段不得改内存
    await pending;
    expect(c.variant, FlexSchemeVariant.fidelity); // 用户选择赢过磁盘上的 vibrant

    // 读盘只跑一次：再 ensureLoaded 不得把内存回退成磁盘值
    await c.ensureLoaded();
    expect(c.variant, FlexSchemeVariant.fidelity);
    // 读盘确实跑过（未被改过的 mode 取到磁盘上的 light），但没有二次回读
    expect(c.mode, AppThemeMode.light);
  });

  test('脏数据不让 ensureLoaded 变成 rejected Future：回落默认，setter 仍可用', () async {
    // 类型不符的持久化值：getInt 会抛 TypeError
    SharedPreferences.setMockInitialValues({'theme_seed_color': '不是数字'});
    final c = ThemeController();
    await c.ensureLoaded(); // 不得抛
    expect(c.seedColor, const Color(0xFF00A1D6)); // 回落默认天蓝

    await c.setMode(AppThemeMode.dark); // 本次进程内改主题仍必须可用
    expect(c.mode, AppThemeMode.dark);
  });
}