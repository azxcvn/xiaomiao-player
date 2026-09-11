import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式
enum AppThemeMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色'),
  amoled('AMOLED 纯黑');

  final String label;
  const AppThemeMode(this.label);
}

/// 主题控制器：管理主题模式与主题色，并持久化到本地
class ThemeController extends ChangeNotifier {
  static const _keyMode = 'theme_mode';
  static const _keySeed = 'theme_seed_color';
  static const _keyVariant = 'theme_variant';

  /// 调色板风格的新持久化键（v2）。
  ///
  /// 旧键 `theme_variant` 的 0~7 是**旧** `DynamicSchemeVariant` 序号，与
  /// `FlexSchemeVariant.index` 语义冲突，无法区分「旧值」与「用户新选的
  /// index<8」；换新键后旧键只在**从未写过新键**时被读取并迁移一次（体检 P0-3）。
  static const _keyVariantV2 = 'theme_variant_scheme_v2';
  static const _keyCustomColor = 'theme_custom_color';
  static const _keyUsingDynamic = 'theme_using_dynamic_color';

  AppThemeMode _mode = AppThemeMode.system;
  Color _seedColor = const Color(0xFF00A1D6);
  FlexSchemeVariant _variant = FlexSchemeVariant.tonalSpot;

  /// 用户自定义的主题色（外观页「自定义」入口选色后持久化）；null = 未设置
  Color? _customColor;

  /// 当前主题色是否来自「动态色」（壁纸取色）；用于网格选中态
  bool _usingDynamicColor = false;

  AppThemeMode get mode => _mode;
  Color get seedColor => _seedColor;
  FlexSchemeVariant get variant => _variant;

  /// 用户自定义色（未设置返回 null）
  Color? get customColor => _customColor;

  /// 当前是否正在使用动态色（壁纸取色）
  bool get usingDynamicColor => _usingDynamicColor;

  /// 预设主题色（23 种：默认天蓝置首，其余按色相排列，名称统一 3 字）
  static const List<({Color color, String label})> presetColors = [
    (color: Color(0xFF00A1D6), label: '天蓝色'),
    (color: Color(0xFF2196F3), label: '蓝色'),
    (color: Color(0xFF03A9F4), label: '浅蓝色'),
    (color: Color(0xFF3F51B5), label: '靛蓝色'),
    (color: Color(0xFF00BCD4), label: '蓝绿色'),
    (color: Color(0xFF009688), label: '青色'),
    (color: Color(0xFF4CAF50), label: '绿色'),
    (color: Color(0xFF5CB67B), label: '薄荷绿'),
    (color: Color(0xFF8BC34A), label: '浅绿色'),
    (color: Color(0xFFCDDC39), label: '酸橙色'),
    (color: Color(0xFFFFEB3B), label: '黄色'),
    (color: Color(0xFFFFC107), label: '琥珀色'),
    (color: Color(0xFFFF9800), label: '橙色'),
    (color: Color(0xFFF57C00), label: '橙红色'),
    (color: Color(0xFFF44336), label: '红色'),
    (color: Color(0xFFFF7299), label: '粉红色'),
    (color: Color(0xFFFF6699), label: '亮粉色'),
    (color: Color(0xFF6750A4), label: '紫罗兰'),
    (color: Color(0xFF9C27B0), label: '紫色'),
    (color: Color(0xFF673AB7), label: '深紫色'),
    (color: Color(0xFF607D8B), label: '蓝灰色'),
    (color: Color(0xFF795548), label: '棕色'),
    (color: Color(0xFF9E9E9E), label: '灰色'),
  ];

  /// 调色板风格（flex_seed_scheme 的 21 种 FlexSchemeVariant，名称统一 3 字）
  static const Map<FlexSchemeVariant, String> variantLabels = {
    FlexSchemeVariant.tonalSpot: '标准型',
    FlexSchemeVariant.fidelity: '保真型',
    FlexSchemeVariant.monochrome: '单色型',
    FlexSchemeVariant.neutral: '中性型',
    FlexSchemeVariant.vibrant: '鲜艳型',
    FlexSchemeVariant.expressive: '鲜明型',
    FlexSchemeVariant.content: '柔和型',
    FlexSchemeVariant.rainbow: '彩虹型',
    FlexSchemeVariant.fruitSalad: '果味型',
    FlexSchemeVariant.candyPop: '糖果型',
    FlexSchemeVariant.chroma: '饱和型',
    FlexSchemeVariant.highContrast: '对比型',
    FlexSchemeVariant.jolly: '欢快型',
    FlexSchemeVariant.material: '经典型',
    FlexSchemeVariant.material3Legacy: '旧版型',
    FlexSchemeVariant.oneHue: '单色相',
    FlexSchemeVariant.soft: '淡雅型',
    FlexSchemeVariant.ultraContrast: '超对比',
    FlexSchemeVariant.vivid: '生动型',
    FlexSchemeVariant.vividBackground: '亮背景',
    FlexSchemeVariant.vividSurfaces: '亮表面',
  };

  /// 旧版持久化迁移：Flutter DynamicSchemeVariant 的 index（0-7）→
  /// FlexSchemeVariant 对应值（枚举顺序不同，必须显式映射）
  static const List<FlexSchemeVariant> _legacyVariantMapping = [
    FlexSchemeVariant.tonalSpot, // 0 tonalSpot
    FlexSchemeVariant.neutral, // 1 neutral
    FlexSchemeVariant.vibrant, // 2 vibrant
    FlexSchemeVariant.expressive, // 3 expressive
    FlexSchemeVariant.content, // 4 content
    FlexSchemeVariant.monochrome, // 5 monochrome
    FlexSchemeVariant.rainbow, // 6 rainbow
    FlexSchemeVariant.fruitSalad, // 7 fruitSalad
  ];

  /// 恢复调色板风格：**新键优先**，只有新键缺失时才读旧键并迁移一次。
  ///
  /// 没有这层门控时，`setVariant` 写的是新枚举 index、`load` 却对 index<8
  /// 无条件走旧映射，两者只在 0 与 ≥8 上一致 → 用户选「保真型(1)」重启后
  /// 变成「中性型(3)」，选择被静默改写（体检 P0-3）。迁移结果立即写回新键，
  /// 旧键此后再不参与读取，因此只会迁移一次、不会二次改写。
  Future<void> _restoreVariant(SharedPreferences prefs) async {
    final current = prefs.getInt(_keyVariantV2);
    if (current != null &&
        current >= 0 &&
        current < FlexSchemeVariant.values.length) {
      _variant = FlexSchemeVariant.values[current];
      return;
    }

    final legacy = prefs.getInt(_keyVariant);
    if (legacy == null || legacy < 0) return;
    if (legacy < _legacyVariantMapping.length) {
      // 旧数据：按 DynamicSchemeVariant 顺序映射
      _variant = _legacyVariantMapping[legacy];
    } else if (legacy < FlexSchemeVariant.values.length) {
      _variant = FlexSchemeVariant.values[legacy];
    } else {
      return; // 越界脏数据：保留默认风格，不写回
    }
    await prefs.setInt(_keyVariantV2, _variant.index);
  }

  /// 启动时从本地恢复
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyMode);
    final seedValue = prefs.getInt(_keySeed);
    final customValue = prefs.getInt(_keyCustomColor);
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < AppThemeMode.values.length) {
      _mode = AppThemeMode.values[modeIndex];
    }
    if (seedValue != null) {
      _seedColor = Color(seedValue);
    }
    if (customValue != null) {
      _customColor = Color(customValue);
    }
    _usingDynamicColor = prefs.getBool(_keyUsingDynamic) ?? false;
    await _restoreVariant(prefs);
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMode, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    if (_seedColor == color && !_usingDynamicColor) return;
    _seedColor = color;
    _usingDynamicColor = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
    await prefs.setBool(_keyUsingDynamic, false);
  }

  Future<void> setVariant(FlexSchemeVariant variant) async {
    if (_variant == variant) return;
    _variant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVariantV2, variant.index);
  }

  /// 设置用户自定义主题色（外观页「自定义」入口）：持久化该色并作为当前
  /// seed 立即生效（复用 [setSeedColor] 的 seed 持久化，主题其余机制不变）。
  Future<void> setCustomColor(Color color) async {
    if (_customColor == color && _seedColor == color && !_usingDynamicColor) {
      return;
    }
    _customColor = color;
    _seedColor = color;
    _usingDynamicColor = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomColor, color.toARGB32());
    await prefs.setInt(_keySeed, color.toARGB32());
    await prefs.setBool(_keyUsingDynamic, false);
  }

  /// 设置动态色（壁纸取色）：seed = 取到的颜色，并标记当前使用动态色。
  Future<void> setDynamicColor(Color color) async {
    if (_seedColor == color && _usingDynamicColor) return;
    _seedColor = color;
    _usingDynamicColor = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
    await prefs.setBool(_keyUsingDynamic, true);
  }
}
