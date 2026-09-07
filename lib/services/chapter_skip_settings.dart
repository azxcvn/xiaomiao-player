import 'package:flutter/foundation.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 章节跳段设置（ChangeNotifier 单例）：针对**有章节信息**的视频。
///
/// 区别于 [IntroOutroSettings]（针对无章节视频、按固定秒数跳过片头片尾），
/// 本设置控制「章节标题 → 跳过片段」的自动跳过行为：
/// - [autoSkipTypes]：哪些片段类型（片头/片尾/前情提要/制作人员/正片前段/
///   下集预告）在播放进入时**自动跳过**；
/// - [customIntroKeywords] / [customOutroKeywords]：用户自定义关键词，
///   与内置关键词表共同参与章节标题分类。
class ChapterSkipSettings extends ChangeNotifier {
  ChapterSkipSettings._();
  static final ChapterSkipSettings instance = ChapterSkipSettings._();

  static const String _keyAutoTypes = 'chapter_skip_auto_types';
  static const String _keyCustomIntro = 'chapter_skip_custom_intro';
  static const String _keyCustomOutro = 'chapter_skip_custom_outro';

  Future<void>? _loadFuture;

  Set<ChapterSkipType> _autoSkipTypes = {};
  String _customIntroKeywords = '';
  String _customOutroKeywords = '';

  /// 自动跳过的片段类型集合（默认空 = 全部手动，只弹跳过胶囊）。
  Set<ChapterSkipType> get autoSkipTypes => Set.unmodifiable(_autoSkipTypes);

  String get customIntroKeywords => _customIntroKeywords;
  String get customOutroKeywords => _customOutroKeywords;

  /// 指定类型是否自动跳过。
  bool autoSkip(ChapterSkipType type) => _autoSkipTypes.contains(type);

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyAutoTypes);
    _autoSkipTypes = {
      if (raw != null)
        for (final name in raw) ..._typeFromName(name),
    };
    _customIntroKeywords = prefs.getString(_keyCustomIntro) ?? '';
    _customOutroKeywords = prefs.getString(_keyCustomOutro) ?? '';
    notifyListeners();
  }

  Iterable<ChapterSkipType> _typeFromName(String name) sync* {
    for (final t in ChapterSkipType.values) {
      if (t.name == name) yield t;
    }
  }

  /// 设置某类型的自动跳过开关（true = 进入该类型片段时自动 seek）。
  Future<void> setAutoSkip(ChapterSkipType type, bool enabled) async {
    await ensureLoaded();
    final changed = enabled ? _autoSkipTypes.add(type) : _autoSkipTypes.remove(type);
    if (!changed) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyAutoTypes,
      _autoSkipTypes.map((t) => t.name).toList(),
    );
  }

  Future<void> setCustomIntroKeywords(String value) async {
    await ensureLoaded();
    final v = value.trim();
    if (_customIntroKeywords == v) return;
    _customIntroKeywords = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomIntro, v);
  }

  Future<void> setCustomOutroKeywords(String value) async {
    await ensureLoaded();
    final v = value.trim();
    if (_customOutroKeywords == v) return;
    _customOutroKeywords = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomOutro, v);
  }

  /// 测试用：恢复默认（单例在测试间共享，避免状态泄漏）。
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null;
    _autoSkipTypes = {};
    _customIntroKeywords = '';
    _customOutroKeywords = '';
    notifyListeners();
  }
}
