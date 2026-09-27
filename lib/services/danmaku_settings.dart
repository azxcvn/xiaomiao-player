/// 弹幕设置（阶段2，工作.md 弹幕第 4 点）：样式（字号/字重/速度/描边/
/// 不透明度/随机渐变色）+ 配置（显示区域/行高/三类弹幕显隐/海量弹幕/去重/屏蔽词）。
///
/// 全局单例（同 [IntroOutroSettings] 模式）：ChangeNotifier +
/// shared_preferences 持久化——所有个性化设置跨重启视频/重启播放保留
/// （工作.md 弹幕第 6 点）。弹幕设置面板与 [DanmakuController] 共同监听：
/// 面板改值实时写盘 + 通知，控制器把设置映射到 canvas_danmaku 的
/// DanmakuOption（updateOption 热更新，见 danmaku_service.dart）。
library;

import 'package:flutter/foundation.dart';
import 'package:moumou/models/danmaku_color_mode.dart';
import 'package:moumou/models/danmaku_font_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕「指定颜色」模式的默认色（白）与回退色。
///
/// 与字幕默认色（`SubtitleSettings.color` 的 `#FFFFFF`）同值，但**各自独立**：
/// 字幕颜色可被用户改，弹幕默认色不该跟着变。
const String kDanmakuDefaultColor = '#FFFFFFFF';

class DanmakuSettings extends ChangeNotifier {
  static final DanmakuSettings instance = DanmakuSettings._();

  DanmakuSettings._();

  /// 加载去重（risk_audit #9）：setter 在改设置前 await [ensureLoaded]，
  /// 防止启动时异步 load 尚未完成、用户已改设置被 load 覆盖
  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  /// 把任意值吸附到最近的 [areaStep] 档位（10% 一档，范围 0.1–1.0）。
  /// 用整数档位除以 10 返回，保证结果与 `0.3` 等字面量精确相等
  /// （避免 `步数 * 0.1` 的浮点累积误差）。
  static double snapArea(double v) {
    final clamped = v.clamp(minArea, maxArea);
    final steps = (clamped / areaStep).round();
    return steps / 10;
  }

  // ── 滑杆范围常量（面板滑杆与 load 钳制共用）──

  static const double minFontSize = 10;
  static const double maxFontSize = 30;
  static const double minFontWeight = 0; // FontWeight.values 下标
  static const double maxFontWeight = 8;
  static const double minScrollSeconds = 2; // 滚动耗时下限（最快）
  static const double maxScrollSeconds = 16;
  static const double minOpacity = 0.1;
  static const double maxOpacity = 1.0;
  static const double minStrokeWidth = 0;
  static const double maxStrokeWidth = 4;
  static const double minArea = 0.1;
  static const double maxArea = 1.0;

  /// 显示区域档位步进（工作.md 弹幕第 3 点：无极调节改为 10% 固定档位，
  /// 10/20/…/100% 共 10 档）
  static const double areaStep = 0.1;
  static const double minLineHeight = 0.5;
  static const double maxLineHeight = 3.0;
  static const double minTimeOffsetSeconds = -180;
  static const double maxTimeOffsetSeconds = 180;

  /// 「指定颜色」调色板最多可选几种颜色（超过则无法再添加）。
  ///
  /// 8 是够用与「别把面板撑爆」的折中：预设色胶囊一行 4 个，最多两行。
  static const int maxPaletteColors = 8;

  // ── 弹幕样式 ──

  /// 弹幕字号（px，canvas DanmakuOption.fontSize，默认 16）
  double _fontSize = 16;

  /// 字体字重（FontWeight.values 下标 0–8，4 = w500 中等，canvas 同下标语义）
  int _fontWeight = 4;

  /// 滚动弹幕横穿屏幕的耗时（秒，默认 10；值越大越慢——面板以
  /// 「弹幕速度」呈现，速度滑杆即调此值）
  double _scrollSeconds = 10;

  /// 不透明度（0.1–1.0，默认 1.0）
  double _opacity = 1.0;

  /// 描边粗细（0–4，默认 1.5；0 = 无描边）
  double _strokeWidth = 1.5;

  /// 弹幕**调色板**（mpv 串 `#AARRGGBB` 列表）：仅 [DanmakuColorMode.fixed]
  /// 生效，每条弹幕从**已选色中随机取一个**（见 `utils/danmaku_palette_color.dart`）。
  ///
  /// 只选 1 种 = 原先「所有弹幕统一一个颜色」的行为；**空列表 = 该模式失效**，
  /// [effectiveColorMode] 会回落「跟随弹幕颜色」（面板上三个单选也不会有
  /// 「指定颜色」被选中，不会出现「选了指色但弹幕不变」的死状态）。
  ///
  /// 历史键 `danmaku_color_value`（单色）由 [_migrateColorPalette] 迁移成
  /// 长度为 1 的列表，老用户升级无感。
  List<String> _colorValues = const [kDanmakuDefaultColor];

  /// 弹幕颜色模式（默认**跟随弹幕自身颜色**——保留 B 站彩色/渐变彩色弹幕）
  DanmakuColorMode _colorMode = DanmakuColorMode.source;

  // ── 弹幕配置 ──

  /// 显示区域（0.1–1.0，屏幕高度比例，默认 1.0）
  double _area = 1.0;

  /// 行高（弹幕轨道行高倍数 0.5–3.0，默认 1.6）
  double _lineHeight = 1.6;

  /// 顶部弹幕显示（canvas hideTop 取反，默认显示）
  bool _showTop = true;

  /// 底部弹幕显示（canvas hideBottom 取反，默认显示）
  bool _showBottom = true;

  /// 滚动弹幕显示（canvas hideScroll 取反，默认显示）
  bool _showScroll = true;

  /// 海量弹幕（轨道占满时叠加绘制，默认关闭）
  bool _massiveMode = false;

  /// 弹幕去重（时间窗口内相同内容合并为一条，默认关闭；**与 [merge] 互斥**；
  /// 算法见 utils/danmaku_dedup.dart）
  bool _deduplication = false;

  /// 弹幕合并（跨时间窗把同内容弹幕聚成一条并计数，默认关闭；**与
  /// [deduplication] 互斥**；算法见 utils/danmaku_merge.dart）
  bool _merge = false;

  /// 时间轴偏移（秒，-180~180，默认 0；正 = 延后、负 = 提前）。
  /// 校准弹幕相对视频画面的显示时间（对齐 Kazumi danmakuTimeOffset）。
  double _timeOffset = 0;

  /// 关键词屏蔽列表（弹幕文本包含任一关键词即被过滤，匹配见
  /// utils/danmaku_blocklist.dart；空列表 = 不屏蔽）
  List<String> _blockedKeywords = [];

  /// 弹幕字体模式（工作.md 第 4 点）：跟随系统 / 跟随 App / 自定义，默认跟随系统。
  DanmakuFontMode _fontMode = DanmakuFontMode.followSystem;

  /// 弹幕自定义字体族名（仅 [_fontMode] == custom 时生效；null = 未选）。
  String? _customFontFamily;

  /// 弹幕自定义字体文件名（filesDir/fonts/ 内，冷启动重读字节用）。
  String? _customFontFile;

  DanmakuColorMode get colorMode => _colorMode;

  /// **实际生效**的颜色模式：`fixed` 且调色板为空时回落
  /// [DanmakuColorMode.source]（跟随弹幕颜色）。
  ///
  /// 渲染取色与面板单选都必须看这个值，而不是裸的 [colorMode]——否则会出现
  /// 「面板显示指定色、弹幕却没有颜色可用」的不一致状态。
  DanmakuColorMode get effectiveColorMode =>
      (_colorMode == DanmakuColorMode.fixed && _colorValues.isEmpty)
      ? DanmakuColorMode.source
      : _colorMode;

  /// 「指定颜色」模式的调色板（mpv 串列表，只读；改值走 [setColorValues]）
  List<String> get colorValues => List.unmodifiable(_colorValues);

  /// 调色板是否为空（弹幕取不到色 → 模式回落跟随原色）
  bool get hasColorValues => _colorValues.isNotEmpty;

  /// 「指定颜色」模式的**首个**颜色（mpv 串 `#AARRGGBB`）。
  ///
  /// 兼容用途：调色板为空时返回默认白（供调色滑杆起点、旧调用方读取）。
  String get colorValue => _colorValues.isEmpty
      ? kDanmakuDefaultColor
      : _colorValues.first;

  /// 指定颜色调色板的默认可选色（空列表时的回退色，也是「恢复默认」值）
  static const String kDefaultColorValue = kDanmakuDefaultColor;

  /// 两个调色板是否等价（顺序敏感；面板/测试共用）
  static bool sameColorValues(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  double get fontSize => _fontSize;
  int get fontWeight => _fontWeight;
  double get scrollSeconds => _scrollSeconds;
  double get opacity => _opacity;
  double get strokeWidth => _strokeWidth;
  double get area => _area;
  double get lineHeight => _lineHeight;
  bool get showTop => _showTop;
  bool get showBottom => _showBottom;
  bool get showScroll => _showScroll;
  bool get massiveMode => _massiveMode;
  bool get deduplication => _deduplication;
  bool get merge => _merge;
  double get timeOffsetSeconds => _timeOffset;
  List<String> get blockedKeywords => List.unmodifiable(_blockedKeywords);
  DanmakuFontMode get fontMode => _fontMode;
  String? get customFontFamily => _customFontFamily;
  String? get customFontFile => _customFontFile;

  /// 启动时加载（main.dart 调用）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = (prefs.getDouble(_keyFontSize) ?? 16).clamp(
      minFontSize,
      maxFontSize,
    );
    _fontWeight = (prefs.getInt(_keyFontWeight) ?? 4).clamp(0, 8);
    _scrollSeconds = (prefs.getDouble(_keyScrollSeconds) ?? 10).clamp(
      minScrollSeconds,
      maxScrollSeconds,
    );
    _opacity = (prefs.getDouble(_keyOpacity) ?? 1.0).clamp(
      minOpacity,
      maxOpacity,
    );
    _strokeWidth = (prefs.getDouble(_keyStrokeWidth) ?? 1.5).clamp(
      minStrokeWidth,
      maxStrokeWidth,
    );
    _loadColorMode(prefs);
    _area = snapArea(prefs.getDouble(_keyArea) ?? 1.0);
    _lineHeight = (prefs.getDouble(_keyLineHeight) ?? 1.6).clamp(
      minLineHeight,
      maxLineHeight,
    );
    _showTop = prefs.getBool(_keyShowTop) ?? true;
    _showBottom = prefs.getBool(_keyShowBottom) ?? true;
    _showScroll = prefs.getBool(_keyShowScroll) ?? true;
    _massiveMode = prefs.getBool(_keyMassiveMode) ?? false;
    _deduplication = prefs.getBool(_keyDedup) ?? false;
    _merge = prefs.getBool(_keyMerge) ?? false;
    _timeOffset = (prefs.getDouble(_keyTimeOffset) ?? 0).clamp(
      minTimeOffsetSeconds,
      maxTimeOffsetSeconds,
    );
    _blockedKeywords = _normalizeBlocklist(
      prefs.getStringList(_keyBlockedKeywords) ?? const [],
    );
    _fontMode = _fontModeFromIndex(prefs.getInt(_keyFontMode));
    _customFontFamily = prefs.getString(_keyCustomFontFamily);
    _customFontFile = prefs.getString(_keyCustomFontFile);
    notifyListeners();
  }

  /// 从持久化 index 恢复字体模式（越界/损坏回落 followSystem）
  static DanmakuFontMode _fontModeFromIndex(int? index) {
    if (index != null && index >= 0 && index < DanmakuFontMode.values.length) {
      return DanmakuFontMode.values[index];
    }
    return DanmakuFontMode.followSystem;
  }

  /// 加载弹幕颜色模式（含**旧键迁移**）。
  ///
  /// 历史版本只有布尔 `danmaku_random_color`（「随机渐变色」开关）。升级到三态
  /// 后若用户曾开着随机色，必须落到 [DanmakuColorMode.random]，否则会被静默
  /// 重置回「跟随弹幕颜色」——用户会认为设置丢了。
  void _loadColorMode(SharedPreferences prefs) {
    final rawIndex = prefs.getInt(_keyColorMode);
    if (rawIndex != null) {
      _colorMode = DanmakuColorMode.fromIndex(rawIndex);
    } else if (prefs.getBool(_keyRandomColor) ?? false) {
      // 旧数据迁移：随机色开关开 → 随机色模式
      _colorMode = DanmakuColorMode.random;
    } else {
      _colorMode = DanmakuColorMode.source;
    }
    _colorValues = _migrateColorPalette(prefs);
  }

  /// 读调色板，并把**历史单色键**迁移过来。
  ///
  /// 老版本只存 `danmaku_color_value` 一个串。若新键不存在（老用户），就用旧
  /// 键的值作为长度为 1 的调色板——升级后行为与升级前完全一致，设置不丢。
  /// 旧键**保留不删**：万一用户回退到旧版本，旧版本的「指定颜色」还在。
  static List<String> _migrateColorPalette(SharedPreferences prefs) {
    final raw = prefs.getStringList(_keyColorValues);
    if (raw != null) return _normalizePalette(raw);
    final legacy = prefs.getString(_keyColorValue);
    if (legacy != null && legacy.trim().isNotEmpty) {
      return _normalizePalette([legacy]);
    }
    return const [kDanmakuDefaultColor];
  }

  /// 调色板归一化：去首尾空白、去空串、去重（保持顺序）、最多
  /// [maxPaletteColors] 种（超出部分丢弃）。
  static List<String> _normalizePalette(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final t = item.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
      if (out.length >= maxPaletteColors) break;
    }
    return out;
  }

  /// 屏蔽词归一化：去首尾空白、去空串、去重（保持原顺序）。
  static List<String> _normalizeBlocklist(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final t = item.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      out.add(t);
    }
    return out;
  }

  // ── 样式 setter（改值 → notifyListeners → 异步写盘）──

  Future<void> setFontSize(double v) async {
    await ensureLoaded();
    final c = v.clamp(minFontSize, maxFontSize);
    if (_fontSize == c) return;
    _fontSize = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, c);
  }

  Future<void> setFontWeight(int v) async {
    await ensureLoaded();
    final c = v.clamp(minFontWeight.toInt(), maxFontWeight.toInt());
    if (_fontWeight == c) return;
    _fontWeight = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFontWeight, c);
  }

  Future<void> setScrollSeconds(double v) async {
    await ensureLoaded();
    final c = v.clamp(minScrollSeconds, maxScrollSeconds);
    if (_scrollSeconds == c) return;
    _scrollSeconds = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScrollSeconds, c);
  }

  Future<void> setOpacity(double v) async {
    await ensureLoaded();
    final c = v.clamp(minOpacity, maxOpacity);
    if (_opacity == c) return;
    _opacity = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOpacity, c);
  }

  Future<void> setStrokeWidth(double v) async {
    await ensureLoaded();
    final c = v.clamp(minStrokeWidth, maxStrokeWidth);
    if (_strokeWidth == c) return;
    _strokeWidth = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyStrokeWidth, c);
  }

  /// 切换弹幕颜色模式（跟随弹幕颜色 / 随机渐变色 / 指定颜色）。
  ///
  /// **从空调色板切到「指定颜色」时自动补一个默认色（白）**：否则会落进
  /// 「模式是 fixed、调色板为空」的状态——[effectiveColorMode] 会把它盖回
  /// source，用户看到的是「点了指定颜色没反应」（真机反馈的 bug）。
  Future<void> setColorMode(DanmakuColorMode v) async {
    await ensureLoaded();
    final seedPalette = v == DanmakuColorMode.fixed && _colorValues.isEmpty;
    if (_colorMode == v && !seedPalette) return;
    _colorMode = v;
    if (seedPalette) _colorValues = const [kDanmakuDefaultColor];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColorMode, v.index);
    if (seedPalette) {
      await prefs.setStringList(_keyColorValues, _colorValues);
    }
  }

  /// 设置「指定颜色」模式的调色板（多色，弹幕随机取用）。
  ///
  /// 传空列表 = 用户取消了全部颜色 → 该模式随即**回落「跟随弹幕颜色」**
  /// （[effectiveColorMode]），面板的单选也跟着回到「跟随弹幕颜色」，
  /// 不会留下「选了指色却没有颜色」的死状态。
  ///
  /// 归一化：去空白/去重/截断到 [maxPaletteColors]。
  Future<void> setColorValues(List<String> colors) async {
    await ensureLoaded();
    final next = _normalizePalette(colors);
    if (sameColorValues(_colorValues, next)) return;
    _colorValues = List.unmodifiable(next);
    if (_colorValues.isEmpty) {
      // 空调色板 → 模式回落跟随原色（与面板显示保持一致）
      _colorMode = DanmakuColorMode.source;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyColorValues, _colorValues);
    await prefs.setInt(_keyColorMode, _colorMode.index);
  }

  /// 设置「指定颜色」模式的颜色（mpv 串 `#AARRGGBB`）——**单色快捷入口**，
  /// 等价于把调色板整体替换成这一个颜色（旧调用方/旧测试沿用）。
  ///
  /// 颜色为空串/非法时回退默认白，避免把空值写进渲染层。
  Future<void> setColorValue(String hex) async {
    final v = hex.trim().isEmpty ? kDanmakuDefaultColor : hex.trim();
    await setColorValues([v]);
  }

  /// 在调色板里**追加**一种颜色（自定义调色「添加到调色板」用）。
  ///
  /// 已存在则不重复添加；已达 [maxPaletteColors] 上限则原样返回。
  Future<void> addColorValue(String hex) async {
    await ensureLoaded();
    final v = hex.trim();
    if (v.isEmpty || _colorValues.contains(v)) return;
    if (_colorValues.length >= maxPaletteColors) return;
    await setColorValues([..._colorValues, v]);
  }

  /// 从调色板**移除**一种颜色（面板上色点的 × 用）。
  Future<void> removeColorValue(String hex) async {
    await ensureLoaded();
    if (!_colorValues.contains(hex)) return;
    await setColorValues(
      _colorValues.where((c) => c != hex).toList(growable: false),
    );
  }

  // ── 配置 setter ──

  Future<void> setArea(double v) async {
    await ensureLoaded();
    final c = snapArea(v);
    if ((_area - c).abs() < 0.001) return;
    _area = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyArea, c);
  }

  Future<void> setLineHeight(double v) async {
    await ensureLoaded();
    final c = v.clamp(minLineHeight, maxLineHeight);
    if (_lineHeight == c) return;
    _lineHeight = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, c);
  }

  Future<void> setShowTop(bool v) async {
    await ensureLoaded();
    if (_showTop == v) return;
    _showTop = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTop, v);
  }

  Future<void> setShowBottom(bool v) async {
    await ensureLoaded();
    if (_showBottom == v) return;
    _showBottom = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowBottom, v);
  }

  Future<void> setShowScroll(bool v) async {
    await ensureLoaded();
    if (_showScroll == v) return;
    _showScroll = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowScroll, v);
  }

  Future<void> setMassiveMode(bool v) async {
    await ensureLoaded();
    if (_massiveMode == v) return;
    _massiveMode = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMassiveMode, v);
  }

  /// 开关弹幕去重。**与弹幕合并互斥**（两者语义冲突：去重丢弃重复条目，
  /// 合并要统计重复条目，同时开启逻辑上讲不通）——开启去重会自动关闭合并，
  /// 互斥裁决只在本服务一处，UI 与运行时共用同一份生效值。
  Future<void> setDeduplication(bool v) async {
    await ensureLoaded();
    if (_deduplication == v) return;
    _deduplication = v;
    if (v) _merge = false; // 互斥：开去重 → 关合并
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDedup, v);
    if (v) await prefs.setBool(_keyMerge, false);
  }

  /// 开关弹幕合并。**与弹幕去重互斥**——开启合并会自动关闭去重（见
  /// [setDeduplication] 的说明）。
  Future<void> setMerge(bool v) async {
    await ensureLoaded();
    if (_merge == v) return;
    _merge = v;
    if (v) _deduplication = false; // 互斥：开合并 → 关去重
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMerge, v);
    if (v) await prefs.setBool(_keyDedup, false);
  }

  Future<void> setTimeOffset(double v) async {
    await ensureLoaded();
    final c = v.roundToDouble().clamp(
      minTimeOffsetSeconds,
      maxTimeOffsetSeconds,
    );
    if (_timeOffset == c) return;
    _timeOffset = c;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTimeOffset, c);
  }

  // ── 关键词屏蔽（架构 §4.11「屏蔽词」）──

  /// 添加屏蔽词（去空白、去重、忽略空串；重复添加幂等）。
  Future<void> addBlockedKeyword(String keyword) async {
    await ensureLoaded();
    final k = keyword.trim();
    if (k.isEmpty || _blockedKeywords.contains(k)) return;
    _blockedKeywords = [..._blockedKeywords, k];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlockedKeywords, _blockedKeywords);
  }

  /// 移除屏蔽词（不存在则幂等）。
  Future<void> removeBlockedKeyword(String keyword) async {
    await ensureLoaded();
    final k = keyword.trim();
    if (k.isEmpty || !_blockedKeywords.contains(k)) return;
    _blockedKeywords = _blockedKeywords.where((e) => e != k).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBlockedKeywords, _blockedKeywords);
  }

  /// 清空全部屏蔽词。
  Future<void> clearBlockedKeywords() async {
    await ensureLoaded();
    if (_blockedKeywords.isEmpty) return;
    _blockedKeywords = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBlockedKeywords);
  }

  // ── 弹幕字体（工作.md 第 4 点）──

  Future<void> setFontMode(DanmakuFontMode v) async {
    await ensureLoaded();
    if (_fontMode == v) return;
    _fontMode = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFontMode, v.index);
  }

  /// 设置弹幕自定义字体（族名 + 文件名）。注册进引擎由调用方负责
  /// （见 AppFontSettings.registerFontFile；main.dart 冷启动时统一再注册）。
  Future<void> setCustomFont(String family, String file) async {
    await ensureLoaded();
    if (_customFontFamily == family && _customFontFile == file) return;
    _customFontFamily = family;
    _customFontFile = file;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomFontFamily, family);
    await prefs.setString(_keyCustomFontFile, file);
  }

  // ── 一键恢复默认（保留在面板底部，设置值全部回默认）──

  /// 恢复默认设置：样式与配置全部回默认值
  Future<void> reset() async {
    await ensureLoaded();
    if (_isDefault) return;
    _fontSize = 16;
    _fontWeight = 4;
    _scrollSeconds = 10;
    _opacity = 1.0;
    _strokeWidth = 1.5;
    _colorMode = DanmakuColorMode.source;
    _colorValues = const [kDanmakuDefaultColor];
    _area = 1.0;
    _lineHeight = 1.6;
    _showTop = true;
    _showBottom = true;
    _showScroll = true;
    _massiveMode = false;
    _deduplication = false;
    _merge = false;
    _timeOffset = 0;
    _blockedKeywords = [];
    _fontMode = DanmakuFontMode.followSystem;
    _customFontFamily = null;
    _customFontFile = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, 16);
    await prefs.setInt(_keyFontWeight, 4);
    await prefs.setDouble(_keyScrollSeconds, 10);
    await prefs.setDouble(_keyOpacity, 1.0);
    await prefs.setDouble(_keyStrokeWidth, 1.5);
    await prefs.setInt(_keyColorMode, DanmakuColorMode.source.index);
    await prefs.setStringList(
      _keyColorValues,
      const [kDanmakuDefaultColor],
    );
    await prefs.setDouble(_keyArea, 1.0);
    await prefs.setDouble(_keyLineHeight, 1.6);
    await prefs.setBool(_keyShowTop, true);
    await prefs.setBool(_keyShowBottom, true);
    await prefs.setBool(_keyShowScroll, true);
    await prefs.setBool(_keyMassiveMode, false);
    await prefs.setBool(_keyDedup, false);
    await prefs.setBool(_keyMerge, false);
    await prefs.setDouble(_keyTimeOffset, 0);
    await prefs.remove(_keyBlockedKeywords);
    await prefs.setInt(_keyFontMode, DanmakuFontMode.followSystem.index);
    await prefs.remove(_keyCustomFontFamily);
    await prefs.remove(_keyCustomFontFile);
  }

  bool get _isDefault =>
      _fontSize == 16 &&
      _fontWeight == 4 &&
      _scrollSeconds == 10 &&
      _opacity == 1.0 &&
      _strokeWidth == 1.5 &&
      _colorMode == DanmakuColorMode.source &&
      sameColorValues(_colorValues, const [kDanmakuDefaultColor]) &&
      _area == 1.0 &&
      _lineHeight == 1.6 &&
      _showTop &&
      _showBottom &&
      _showScroll &&
      !_massiveMode &&
      !_deduplication &&
      !_merge &&
      _timeOffset == 0 &&
      _blockedKeywords.isEmpty &&
      _fontMode == DanmakuFontMode.followSystem &&
      _customFontFamily == null &&
      _customFontFile == null;

  // ── SharedPreferences 键 ──

  static const _keyFontSize = 'danmaku_font_size';
  static const _keyFontWeight = 'danmaku_font_weight';
  static const _keyScrollSeconds = 'danmaku_speed';
  static const _keyOpacity = 'danmaku_opacity';
  static const _keyStrokeWidth = 'danmaku_stroke_width';

  /// 弹幕颜色模式（int，[DanmakuColorMode] 的 index）
  static const _keyColorMode = 'danmaku_color_mode';

  /// 「指定颜色」模式的**单色**（历史键，mpv 串）。仅用于迁移到
  /// [_keyColorValues]（调色板），新代码不再写入。
  static const _keyColorValue = 'danmaku_color_value';

  /// 「指定颜色」模式的调色板（`StringList`，mpv 串；弹幕随机取用）
  static const _keyColorValues = 'danmaku_color_values';

  /// **历史键（只读，用于迁移）**：旧版「随机渐变色」布尔开关。
  /// 新代码不再写入；[_loadColorMode] 见其为 true 时迁移到
  /// [DanmakuColorMode.random]，避免老用户设置被静默重置。
  static const _keyRandomColor = 'danmaku_random_color';
  static const _keyArea = 'danmaku_area';
  static const _keyLineHeight = 'danmaku_line_height';
  static const _keyShowTop = 'danmaku_show_top';
  static const _keyShowBottom = 'danmaku_show_bottom';
  static const _keyShowScroll = 'danmaku_show_scroll';
  static const _keyMassiveMode = 'danmaku_massive_mode';
  static const _keyDedup = 'danmaku_dedup';
  static const _keyMerge = 'danmaku_merge';
  static const _keyTimeOffset = 'danmaku_time_offset';
  static const _keyBlockedKeywords = 'danmaku_blocked_keywords';
  static const _keyFontMode = 'danmaku_font_mode';
  static const _keyCustomFontFamily = 'danmaku_font_family';
  static const _keyCustomFontFile = 'danmaku_font_file';

  /// 测试用：恢复默认值并清加载标记（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null; // 下次 setter 重新触发 load（读当前 mock prefs）
    _fontSize = 16;
    _fontWeight = 4;
    _scrollSeconds = 10;
    _opacity = 1.0;
    _strokeWidth = 1.5;
    _colorMode = DanmakuColorMode.source;
    _colorValues = const [kDanmakuDefaultColor];
    _area = 1.0;
    _lineHeight = 1.6;
    _showTop = true;
    _showBottom = true;
    _showScroll = true;
    _massiveMode = false;
    _deduplication = false;
    _merge = false;
    _timeOffset = 0;
    _blockedKeywords = [];
    _fontMode = DanmakuFontMode.followSystem;
    _customFontFamily = null;
    _customFontFile = null;
    notifyListeners();
  }
}
