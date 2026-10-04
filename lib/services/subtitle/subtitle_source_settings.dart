import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 下载字幕时用哪个来源：Wyzie 字幕服务 / 自定义字幕地址。
///
/// 两者**互斥**（UI 上是单选，不是两个开关）：单选天然不会出现
/// 「都开」「都关」这种无意义状态。默认 Wyzie（保持原有行为）。
///
/// 名称在 `lib/l10n/label_maps.dart` 的 [subtitleSourceKindLabel]。
enum SubtitleSourceKind {
  wyzie,
  custom;

  static SubtitleSourceKind byName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return SubtitleSourceKind.wyzie;
  }
}

/// 字幕来源设置（ChangeNotifier 单例 + shared_preferences）。
///
/// 与 [WyzieSettings] 分工：本类只管「用哪个来源 + 自定义地址模板」，
/// Wyzie 自己的密钥/来源/语言/格式/编码仍归 [WyzieSettings]。
///
/// 自定义地址模板支持 `{name}` 占位（没有占位符时片名拼到末尾，见
/// `utils/custom_subtitle_parser.dart`）。**仓库里不内置任何第三方地址。**
class SubtitleSourceSettings extends ChangeNotifier {
  SubtitleSourceSettings._();
  static final SubtitleSourceSettings instance = SubtitleSourceSettings._();

  static const String _keyKind = 'subtitle_source_kind';
  static const String _keyCustomUrl = 'subtitle_custom_url';

  Future<void>? _loadFuture;

  SubtitleSourceKind _kind = SubtitleSourceKind.wyzie;
  String _customUrlTemplate = '';

  SubtitleSourceKind get kind => _kind;
  String get customUrlTemplate => _customUrlTemplate;

  /// 自定义来源是否已配置（地址非空）
  bool get customConfigured => _customUrlTemplate.trim().isNotEmpty;

  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _kind = SubtitleSourceKind.byName(prefs.getString(_keyKind));
    _customUrlTemplate = prefs.getString(_keyCustomUrl) ?? '';
    notifyListeners();
  }

  Future<void> setKind(SubtitleSourceKind value) async {
    await ensureLoaded();
    if (_kind == value) return;
    _kind = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKind, value.name);
  }

  /// 写入自定义地址模板（去首尾空白；允许为空 = 未配置）
  Future<void> setCustomUrlTemplate(String value) async {
    await ensureLoaded();
    final trimmed = value.trim();
    if (_customUrlTemplate == trimmed) return;
    _customUrlTemplate = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomUrl, trimmed);
  }

  /// 测试用：重置内存状态与加载标记（单例在测试间共享）
  @visibleForTesting
  void resetForTest() {
    _kind = SubtitleSourceKind.wyzie;
    _customUrlTemplate = '';
    _loadFuture = null;
  }
}
