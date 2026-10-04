import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App 界面语言偏好（工作.md：多语言支持）。
///
/// 全局单例（同 [PrivacyPolicySettings] 模式），ChangeNotifier +
/// shared_preferences 持久化：
/// - 键 `app_locale`，值**只允许** `'zh'` / `'en'`（ASCII，**没有 `'system'`**）；
/// - 缺省、空值、非法值一律回落 `'zh'`（简体中文）；
/// - [setLocale] 写入后 `notifyListeners()`，`MaterialApp.locale` 立即生效
///   （无需重启；由 main.dart 的 ListenableBuilder 监听重建）。
class AppLocaleSettings extends ChangeNotifier {
  static final AppLocaleSettings instance = AppLocaleSettings._();

  AppLocaleSettings._();

  /// 加载去重（同其他设置服务）：setLocale 在写入前 await [ensureLoaded]，
  /// 防止启动时异步 load 尚未完成、用户已选的语言被 load 覆盖。
  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyAppLocale = 'app_locale';

  /// 支持的语言取值（语言选项用自称且不翻译：简体中文 / English）
  static const String zhCode = 'zh';
  static const String enCode = 'en';

  /// 当前语言取值（`'zh'` / `'en'`）
  String _value = zhCode;

  /// 当前语言取值原文（写持久化/比对用）
  String get rawValue => _value;

  /// 当前语言对应的 Locale（**永远非空**，默认简体中文，无「跟随系统」）
  Locale get locale => Locale(_value);

  /// 启动时加载（main.dart 在 runApp 前 await，确保首帧即可读到正确语言）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _value = _normalize(prefs.getString(_keyAppLocale));
    notifyListeners();
  }

  /// 切换语言（只接受 `'zh'` / `'en'`，其余按简体中文处理）
  Future<void> setLocale(String value) async {
    await ensureLoaded();
    final next = _normalize(value);
    if (_value == next) return;
    _value = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLocale, next);
  }

  /// 缺省 / 空值 / 非法值一律回落简体中文
  static String _normalize(String? value) => value == enCode ? enCode : zhCode;

  /// 测试用：恢复默认值（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null; // 下次 setLocale 重新触发 load（读当前 mock prefs）
    _value = zhCode;
    notifyListeners();
  }
}
