import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 杜比视界偏色提示设置：记录用户是否勾选「不再提示」。
///
/// 播放到杜比视界视频且未开 gpu-next / 软解时弹偏色引导弹窗（对齐老项目
/// `DolbyVisionHintDialog`）；用户勾选「不再提示」后持久化，后续相同编码
/// 不再打扰（除非重开应用后仍保留，见 [suppressed]）。
///
/// 全局单例，ChangeNotifier + shared_preferences 持久化。
class DolbyVisionSettings extends ChangeNotifier {
  static final DolbyVisionSettings instance = DolbyVisionSettings._();

  DolbyVisionSettings._();

  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keySuppress = 'dolby_vision_hint_suppressed';

  bool _suppressed = false;

  /// 是否已勾选「不再提示」杜比视界偏色引导
  bool get suppressed => _suppressed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _suppressed = prefs.getBool(_keySuppress) ?? false;
    notifyListeners();
  }

  /// 勾选/取消「不再提示」
  Future<void> setSuppressed(bool v) async {
    await ensureLoaded();
    if (_suppressed == v) return;
    _suppressed = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySuppress, v);
  }

  /// 测试用：恢复默认（单例在测试间共享）
  @visibleForTesting
  void reset() {
    _loadFuture = null;
    _suppressed = false;
    notifyListeners();
  }
}