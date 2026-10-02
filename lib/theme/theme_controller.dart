import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式
///
/// 只留稳定值：名称（跟随系统/浅色/深色/AMOLED 纯黑）在
/// `lib/l10n/label_maps.dart` 的 [appThemeModeLabel] 里按 l10n 取。
/// **顺序即持久化语义**（`theme_mode` 存 index），一个都不许动。
enum AppThemeMode {
  system,
  light,
  dark,
  amoled,
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

  /// 读盘 Future（[ensureLoaded] 缓存；null = 尚未开始加载）
  Future<void>? _loadFuture;

  AppThemeMode get mode => _mode;
  Color get seedColor => _seedColor;
  FlexSchemeVariant get variant => _variant;

  /// 用户自定义色（未设置返回 null）
  Color? get customColor => _customColor;

  /// 当前是否正在使用动态色（壁纸取色）
  bool get usingDynamicColor => _usingDynamicColor;

  /// 预设主题色（23 种：默认天蓝置首，其余按色相排列）。
  ///
  /// 名称不在代码里：`lib/l10n/label_maps.dart` 的 `themeColorLabel(l10n, index)`
  /// 按**下标**取中文/英文。**顺序即语义**（下标与名称一一对应），不许调整。
  static const List<Color> presetColors = [
    Color(0xFF00A1D6), // 天蓝色
    Color(0xFF2196F3), // 蓝色
    Color(0xFF03A9F4), // 浅蓝色
    Color(0xFF3F51B5), // 靛蓝色
    Color(0xFF00BCD4), // 蓝绿色
    Color(0xFF009688), // 青色
    Color(0xFF4CAF50), // 绿色
    Color(0xFF5CB67B), // 薄荷绿
    Color(0xFF8BC34A), // 浅绿色
    Color(0xFFCDDC39), // 酸橙色
    Color(0xFFFFEB3B), // 黄色
    Color(0xFFFFC107), // 琥珀色
    Color(0xFFFF9800), // 橙色
    Color(0xFFF57C00), // 橙红色
    Color(0xFFF44336), // 红色
    Color(0xFFFF7299), // 粉红色
    Color(0xFFFF6699), // 亮粉色
    Color(0xFF6750A4), // 紫罗兰
    Color(0xFF9C27B0), // 紫色
    Color(0xFF673AB7), // 深紫色
    Color(0xFF607D8B), // 蓝灰色
    Color(0xFF795548), // 棕色
    Color(0xFF9E9E9E), // 灰色
  ];

  /// 调色板风格的**展示顺序**（flex_seed_scheme 的 21 种 FlexSchemeVariant）。
  ///
  /// 名称在 `lib/l10n/label_maps.dart` 的 `paletteVariantLabel(l10n, variant)`。
  /// 注意：这个顺序与 `FlexSchemeVariant.values` **不同**（历史顺序），
  /// 改它会让外观页网格排列变化。
  static const List<FlexSchemeVariant> variantOrder = [
    FlexSchemeVariant.tonalSpot,
    FlexSchemeVariant.fidelity,
    FlexSchemeVariant.monochrome,
    FlexSchemeVariant.neutral,
    FlexSchemeVariant.vibrant,
    FlexSchemeVariant.expressive,
    FlexSchemeVariant.content,
    FlexSchemeVariant.rainbow,
    FlexSchemeVariant.fruitSalad,
    FlexSchemeVariant.candyPop,
    FlexSchemeVariant.chroma,
    FlexSchemeVariant.highContrast,
    FlexSchemeVariant.jolly,
    FlexSchemeVariant.material,
    FlexSchemeVariant.material3Legacy,
    FlexSchemeVariant.oneHue,
    FlexSchemeVariant.soft,
    FlexSchemeVariant.ultraContrast,
    FlexSchemeVariant.vivid,
    FlexSchemeVariant.vividBackground,
    FlexSchemeVariant.vividSurfaces,
  ];

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
  ///
  /// 全程 try/catch：任何一步读盘失败只回落默认外观，**绝不**让本 Future 变成
  /// rejected —— [ensureLoaded] 会把它缓存下来，一旦失败每次 setter 首行的
  /// await 都会立刻抛，本次进程内改主题/风格/自定义色全部失效（同类修法见
  /// `PlaybackProgressService.load`，§7）。
  Future<void> load() async {
    try {
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
    } catch (e) {
      debugPrint('ThemeController: 外观读盘失败，沿用默认值：$e');
    } finally {
      notifyListeners();
    }
  }

  /// 确保已从磁盘加载。
  ///
  /// setter 首行与 `main.dart` 共享同一 load Future：防止「启动读盘尚未完成、
  /// 用户刚在外观页选的主题/风格/自定义色被 [load] 的成员写回覆盖」
  /// （§4.1/§7「设置单例 load 竞态 → `ensureLoaded()` + 全部 setter 首行 await」
  /// 约定）。本服务此前是全仓最后一个遗漏点；按 C2 必须先于调色板迁移门控
  /// 落地，否则迁移读到的启动期持久化值不可信（体检 D10 / P1-30·P1-31 同类）。
  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<void> setMode(AppThemeMode mode) async {
    await ensureLoaded();
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMode, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    await ensureLoaded();
    if (_seedColor == color && !_usingDynamicColor) return;
    _seedColor = color;
    _usingDynamicColor = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
    await prefs.setBool(_keyUsingDynamic, false);
  }

  Future<void> setVariant(FlexSchemeVariant variant) async {
    await ensureLoaded();
    if (_variant == variant) return;
    _variant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVariantV2, variant.index);
  }

  /// 设置用户自定义主题色（外观页「自定义」入口）：持久化该色并作为当前
  /// seed 立即生效（复用 [setSeedColor] 的 seed 持久化，主题其余机制不变）。
  Future<void> setCustomColor(Color color) async {
    await ensureLoaded();
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
    await ensureLoaded();
    if (_seedColor == color && _usingDynamicColor) return;
    _seedColor = color;
    _usingDynamicColor = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeed, color.toARGB32());
    await prefs.setBool(_keyUsingDynamic, true);
  }
}
