/// 网络存储浏览页的显示设置（单例 ChangeNotifier + SharedPreferences）。
///
/// 三件事：
/// - **排序**：远端列目录只有「名称 / 修改时间」两个可靠字段，所以这里自带一套
///   排序偏好——**不复用**本地那套（名称/日期/大小/数量），大小与数量在远端
///   根本排不动，放出来就是骗人；
/// - **是否显示隐藏项**（`.` 开头、`@eaDir` 等 NAS 元数据）：默认不显示；
/// - **已播放过的远端视频时长**：列表页要显示「时长」，但远端探测（读文件头解析
///   容器）本轮不做，所以改成「播过一次就记住」——播放页拿到真实时长后回写，
///   下次进列表即可显示。键必须是**连接 id + 远端路径**（loopback URL 里的
///   token 每次会话都变，存 URL 等于没存）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moumou/utils/network_sort.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkViewSettings extends ChangeNotifier {
  NetworkViewSettings._();

  static final NetworkViewSettings instance = NetworkViewSettings._();

  static const _keyShowHidden = 'network_show_hidden';
  static const _keyDurations = 'network_video_durations';
  static const _keySortField = 'network_sort_field';
  static const _keySortOrder = 'network_sort_order';

  /// 时长记忆条数上限（超出淘汰最久未用）。
  static const maxRememberedDurations = 500;

  Future<void>? _loadFuture;
  bool _showHidden = false;
  NetworkSortField _sortField = NetworkSortField.name;
  NetworkSortOrder _sortOrder = NetworkSortOrder.asc;
  Map<String, int> _durations = {};

  bool get showHidden => _showHidden;

  NetworkSort get sort => NetworkSort(field: _sortField, order: _sortOrder);

  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _showHidden = prefs.getBool(_keyShowHidden) ?? false;
    _sortField = _enumByName(
      NetworkSortField.values,
      prefs.getString(_keySortField),
      NetworkSortField.name,
    );
    _sortOrder = _enumByName(
      NetworkSortOrder.values,
      prefs.getString(_keySortOrder),
      NetworkSortOrder.asc,
    );
    try {
      final raw = prefs.getString(_keyDurations);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _durations = decoded.map(
          (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
        );
      } else {
        _durations = {};
      }
    } catch (_) {
      _durations = {};
    }
    notifyListeners();
  }

  Future<void> setShowHidden(bool value) async {
    await ensureLoaded();
    if (_showHidden == value) return;
    _showHidden = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowHidden, value);
  }

  Future<void> setSort(NetworkSort sort) async {
    await ensureLoaded();
    if (_sortField == sort.field && _sortOrder == sort.order) return;
    _sortField = sort.field;
    _sortOrder = sort.order;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySortField, sort.field.name);
    await prefs.setString(_keySortOrder, sort.order.name);
  }

  /// 某个远端视频记忆的时长（毫秒；无记录返回 0）。
  int durationFor(String key) => _durations[key] ?? 0;

  /// 记住一个远端视频的时长（播放页拿到真实时长后回写）。
  ///
  /// 一次播放只调一次（播放页退出前），不是高频路径。
  Future<void> rememberDuration(String key, int durationMs) async {
    if (key.isEmpty || durationMs <= 0) return;
    await ensureLoaded();
    _durations.remove(key);
    _durations[key] = durationMs; // 重新插入 = 刷新 LRU 位置
    while (_durations.length > maxRememberedDurations) {
      _durations.remove(_durations.keys.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDurations, jsonEncode(_durations));
  }

  /// 测试用：恢复默认值（单例在测试间共享，避免状态泄漏）。
  @visibleForTesting
  void reset() {
    _loadFuture = null;
    _showHidden = false;
    _sortField = NetworkSortField.name;
    _sortOrder = NetworkSortOrder.asc;
    _durations = {};
    notifyListeners();
  }
}

/// 按名字取枚举值（未知/缺失回退 [fallback]）。
T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null || name.isEmpty) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
