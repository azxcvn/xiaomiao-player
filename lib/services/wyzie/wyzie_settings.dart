import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wyzie 字幕下载设置（ChangeNotifier 单例）。
///
/// 持久化 WYZIE API 密钥与搜索偏好：字幕来源（默认 all）、字幕语言
/// （默认 en + zh）、首选格式（默认 srt + ass）、首选编码（默认 utf-8）。
/// 供 `pages/subtitle/subtitle_download_page.dart` 读取并拼查询参数。
class WyzieSettings extends ChangeNotifier {
  WyzieSettings._();
  static final WyzieSettings instance = WyzieSettings._();

  static const String _keyApiKey = 'wyzie_api_key';
  static const String _keySources = 'wyzie_sources';
  static const String _keyLanguages = 'wyzie_languages';
  static const String _keyFormats = 'wyzie_formats';
  static const String _keyEncodings = 'wyzie_encodings';

  Future<void>? _loadFuture;

  String _apiKey = '';
  Set<String> _sources = {'all'};
  Set<String> _languages = {'en', 'zh'};
  Set<String> _formats = {'srt', 'ass'};
  Set<String> _encodings = {'utf-8'};

  String get apiKey => _apiKey;
  Set<String> get sources => Set.unmodifiable(_sources);
  Set<String> get languages => Set.unmodifiable(_languages);
  Set<String> get formats => Set.unmodifiable(_formats);
  Set<String> get encodings => Set.unmodifiable(_encodings);

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyApiKey) ?? '';
    _sources = _loadSet(prefs, _keySources, {'all'});
    _languages = _loadSet(prefs, _keyLanguages, {'en', 'zh'});
    _formats = _loadSet(prefs, _keyFormats, {'srt', 'ass'});
    _encodings = _loadSet(prefs, _keyEncodings, {'utf-8'});
    notifyListeners();
  }

  Set<String> _loadSet(SharedPreferences prefs, String key, Set<String> fallback) {
    final raw = prefs.getStringList(key);
    if (raw == null || raw.isEmpty) return fallback;
    return raw.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toSet();
  }

  Future<void> _saveSet(String key, Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value.toList());
  }

  /// 写入 API 密钥（去掉首尾空白）。
  Future<void> setApiKey(String value) async {
    _apiKey = value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, _apiKey);
  }

  Future<void> setSources(Set<String> value) async {
    _sources = _normalize(value, 'all');
    notifyListeners();
    await _saveSet(_keySources, _sources);
  }

  Future<void> setLanguages(Set<String> value) async {
    _languages = _normalize(value, 'all');
    notifyListeners();
    await _saveSet(_keyLanguages, _languages);
  }

  Future<void> setFormats(Set<String> value) async {
    _formats = _normalize(value, 'all');
    notifyListeners();
    await _saveSet(_keyFormats, _formats);
  }

  Future<void> setEncodings(Set<String> value) async {
    _encodings = _normalize(value, 'all');
    notifyListeners();
    await _saveSet(_keyEncodings, _encodings);
  }

  /// 空集回退为 [fallback]（空集语义上等同于「不限」）。
  Set<String> _normalize(Set<String> value, String fallback) {
    final cleaned = value.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    return cleaned.isEmpty ? {fallback} : cleaned;
  }

  /// 测试用：重置内存状态与加载标记（单例在测试间共享，避免状态泄漏）。
  @visibleForTesting
  void resetForTest() {
    _apiKey = '';
    _sources = {'all'};
    _languages = {'en', 'zh'};
    _formats = {'srt', 'ass'};
    _encodings = {'utf-8'};
    _loadFuture = null;
  }
}
