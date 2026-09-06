import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App 更新设置（工作.md：更新功能）。
///
/// 全局单例（同 [IntroOutroSettings] 模式），ChangeNotifier +
/// shared_preferences 持久化：
/// - [autoUpdateEnabled]：自动检查更新开关（开启后每次启动 2 秒后自动检查）；
/// - [ignoredVersion]：用户「忽略本版本」的版本号（自动检查不弹该版本）。
class UpdateSettings extends ChangeNotifier {
  static final UpdateSettings instance = UpdateSettings._();

  UpdateSettings._();

  /// 加载去重（同其他设置服务）：setter 在写入前 await [ensureLoaded]。
  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyAutoUpdate = 'update_auto_enabled';
  static const _keyIgnoredVersion = 'update_ignored_version';

  /// 自动检查更新开关（默认开启）
  bool _autoUpdateEnabled = true;

  /// 用户忽略的版本号（空字符串 = 未忽略）
  String _ignoredVersion = '';

  bool get autoUpdateEnabled => _autoUpdateEnabled;
  String get ignoredVersion => _ignoredVersion;

  /// 该版本是否已被用户「忽略本版本」
  bool isVersionIgnored(String version) =>
      _ignoredVersion.isNotEmpty && _ignoredVersion == version;

  /// 启动时加载（main.dart 在 runApp 前 await，确保自动检查读正确状态）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoUpdateEnabled = prefs.getBool(_keyAutoUpdate) ?? true;
    _ignoredVersion = prefs.getString(_keyIgnoredVersion) ?? '';
    notifyListeners();
  }

  Future<void> setAutoUpdateEnabled(bool value) async {
    await ensureLoaded();
    if (_autoUpdateEnabled == value) return;
    _autoUpdateEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoUpdate, value);
  }

  /// 用户点「忽略本版本」：记录该版本，自动检查不再弹。
  Future<void> ignoreVersion(String version) async {
    await ensureLoaded();
    if (_ignoredVersion == version) return;
    _ignoredVersion = version;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIgnoredVersion, version);
  }

  /// 测试用：恢复默认值（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null; // 下次 setter 重新触发 load（读当前 mock prefs）
    _autoUpdateEnabled = true;
    _ignoredVersion = '';
    notifyListeners();
  }
}
