import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户隐私政策同意状态（工作.md：隐私政策功能）。
///
/// 全局单例（同 [IntroOutroSettings] 模式），ChangeNotifier +
/// shared_preferences 持久化。首次启动未同意时由启动门禁弹出隐私弹窗，
/// 勾选同意后写入持久化，此后启动不再弹窗。
class PrivacyPolicySettings extends ChangeNotifier {
  static final PrivacyPolicySettings instance = PrivacyPolicySettings._();

  PrivacyPolicySettings._();

  /// 加载去重（同其他设置服务）：accept 在写入前 await [ensureLoaded]，
  /// 防止启动时异步 load 尚未完成、用户已同意被 load 覆盖。
  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyAccepted = 'privacy_policy_accepted';

  /// 是否已同意隐私政策（默认 false = 未同意）
  bool _accepted = false;

  bool get accepted => _accepted;

  /// 启动时加载（main.dart 在 runApp 前 await，确保首帧即可读正确状态）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _accepted = prefs.getBool(_keyAccepted) ?? false;
    notifyListeners();
  }

  /// 用户勾选同意后调用（写入持久化，此后不再弹窗）
  Future<void> accept() async {
    await ensureLoaded();
    if (_accepted) return;
    _accepted = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccepted, true);
  }

  /// 测试用：恢复默认值（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null; // 下次 accept 重新触发 load（读当前 mock prefs）
    _accepted = false;
    notifyListeners();
  }
}
