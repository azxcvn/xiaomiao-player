import 'package:flutter/foundation.dart';

/// 页面级多选状态：进入 / 退出、逐项切换、全选、刷新后剔除失效项。
///
/// **不是单例**——每个页面在自己的 `State` 里 new 一个、`dispose` 时释放。
/// 多选只作用于「当前页面的当前列表」：不跨页、不跨会话、不持久化
/// （与 `PinnedFoldersSettings` 那类全局设置刻意区分开）。
class FileSelectionController extends ChangeNotifier {
  bool _selecting = false;
  final List<String> _paths = <String>[];

  /// 是否处于多选态（AppBar 是否换成选择工具栏）
  bool get selecting => _selecting;

  bool get isEmpty => _paths.isEmpty;

  /// 选中数量
  int get count => _paths.length;

  /// 选中路径，**按用户点选先后**排列（批量操作按此顺序执行）
  List<String> get paths => List.unmodifiable(_paths);

  bool isSelected(String path) => _paths.contains(path);

  /// [visiblePaths] 是否已全部选中（空列表不算全选）
  bool containsAll(Iterable<String> visiblePaths) {
    var any = false;
    for (final p in visiblePaths) {
      any = true;
      if (!_paths.contains(p)) return false;
    }
    return any;
  }

  /// 进入多选并选中 [path]。
  ///
  /// 长按菜单点「多选」时调用并**立刻选中长按的那一项**，
  /// 否则会进入一个「明明是空选择、却已经是多选态」的怪状态。
  void begin(String path) {
    _selecting = true;
    _paths
      ..clear()
      ..add(path);
    notifyListeners();
  }

  /// 退出多选并清空选择
  void exit() {
    if (!_selecting && _paths.isEmpty) return;
    _selecting = false;
    _paths.clear();
    notifyListeners();
  }

  /// 单项选中 / 取消（多选态下点卡片）
  void toggle(String path) {
    if (!_selecting) return;
    if (!_paths.remove(path)) _paths.add(path);
    notifyListeners();
  }

  /// 全选 / 取消全选（范围 = 当前可见列表，过滤后）
  void setAll(Iterable<String> visiblePaths, {required bool selected}) {
    _paths.clear();
    if (selected) _paths.addAll(visiblePaths);
    notifyListeners();
  }

  /// 剔除已不存在的选中项（重扫刷新后调用，避免批量操作打到死路径）
  void retainExisting(Iterable<String> alive) {
    final keep = alive.toSet();
    final before = _paths.length;
    _paths.removeWhere((p) => !keep.contains(p));
    if (_paths.length != before) notifyListeners();
  }
}
