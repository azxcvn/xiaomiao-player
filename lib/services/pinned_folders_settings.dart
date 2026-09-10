import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 固定（置顶）文件夹设置：单例 ChangeNotifier + SharedPreferences 持久化。
///
/// 存**文件夹绝对路径**集合（对齐 mpvRx `FoldersPreferences.pinnedFolders`），
/// 因此重命名/删除文件夹后需要由调用方调用 [retainExisting] 清理失效路径。
/// 展示顺序由 `utils/folder_pin.dart` 的稳定前置纯函数决定，本服务只管数据。
class PinnedFoldersSettings extends ChangeNotifier {
  PinnedFoldersSettings._();

  static final PinnedFoldersSettings instance = PinnedFoldersSettings._();

  static const String _key = 'pinned_folder_paths';

  final Set<String> _paths = <String>{};
  Future<void>? _loading;

  /// 固定文件夹路径集合（只读视图）
  Set<String> get paths => Set.unmodifiable(_paths);

  int get count => _paths.length;

  bool isPinned(String path) => _paths.contains(path);

  /// 加载并缓存（启动时调用；调用方共享同一 Future 防竞态）
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key);
      if (list != null) {
        _paths
          ..clear()
          ..addAll(list.where((e) => e.isNotEmpty));
        notifyListeners();
      }
    } catch (_) {
      // 读盘失败：保持空集合，不影响首页展示
    }
  }

  /// 固定 / 取消固定单个文件夹
  Future<void> toggle(String path) async {
    if (path.isEmpty) return;
    if (!_paths.remove(path)) _paths.add(path);
    notifyListeners();
    await _persist();
  }

  Future<void> setPinned(String path, bool pinned) async {
    if (path.isEmpty) return;
    final changed = pinned ? _paths.add(path) : _paths.remove(path);
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  /// 批量固定 / 取消固定（多选菜单一次勾选多个文件夹时用）。
  ///
  /// 与循环调 [setPinned] 的区别：**只通知、只写盘一次**，
  /// 避免一次多选触发 N 次列表重建与 N 次持久化。
  Future<void> setPinnedAll(
    Iterable<String> paths, {
    required bool pinned,
  }) async {
    var changed = false;
    for (final p in paths) {
      if (p.isEmpty) continue;
      final hit = pinned ? _paths.add(p) : _paths.remove(p);
      changed = hit || changed;
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  /// 批量替换（「固定文件夹」设置页一键清空/批量取消用）
  Future<void> replaceAll(Iterable<String> paths) async {
    final next = paths.where((e) => e.isNotEmpty).toSet();
    if (setEquals(next, _paths)) return;
    _paths
      ..clear()
      ..addAll(next);
    notifyListeners();
    await _persist();
  }

  /// 清理磁盘上已不存在的固定路径（删除/移动/重命名文件夹后调用）。
  ///
  /// [additionalStale] 用于额外声明「本次操作已失效的旧路径」
  /// （如重命名：旧路径已不存在，但新路径尚未被扫描进目录树）。
  Future<void> retainExisting({Iterable<String> additionalStale = const []}) async {
    if (_paths.isEmpty) return;
    final next = <String>{};
    for (final p in _paths) {
      if (additionalStale.contains(p)) continue;
      if (Directory(p).existsSync()) next.add(p);
    }
    if (setEquals(next, _paths)) return;
    _paths
      ..clear()
      ..addAll(next);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _paths.toList());
    } catch (_) {
      // 写盘失败：内存态已更新，不阻断交互
    }
  }

  /// 测试专用：清空内存态与加载缓存（单例在测试进程内共享，需逐用例复位）
  @visibleForTesting
  void debugReset() {
    _paths.clear();
    _loading = null;
  }
}
