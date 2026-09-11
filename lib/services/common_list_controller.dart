import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:moumou/utils/async_session.dart';
import 'package:moumou/utils/loading_state.dart';

/// 通用分页列表控制器（ChangeNotifier）：统一「刷新 / 加载更多 / 三态 /
/// 刷新失败保留旧数据」语义（对齐 PiliPlus `CommonListController` 的模型，
/// 但不抄其 GetX 版实现）。
///
/// 用法（页面持有一个实例，dispose 时释放）：
/// ```dart
/// _controller = CommonListController<BiliSearchItem>(
///   fetchPage: (page) async {
///     final r = await service.searchBangumi(_keyword, page: page);
///     return PageResult(r.list, hasMore: page * _pageSize < r.numResults);
///   },
///   describeError: (e) => e is BiliApiException ? e.message : '$e',
/// );
/// ```
///
/// 语义要点：
/// - **刷新失败不清空列表**：已有数据时出错只记录 [error]（页面可弹 toast），
///   [state] 仍是 `Loaded`（旧数据继续展示）；
/// - **并发防重入**：同一时刻只有一次请求在跑（[refresh]/[loadMore] 相互排斥）；
/// - **换条件后旧请求的结果必须作废**：[reset] 走 [AsyncSession.invalidate]，
///   在飞请求回来时令牌已失效 → 丢弃结果，不会用旧关键词的数据覆盖新列表
///   （P1-37；旧实现 reset 里把 `_loading` 清成 false，于是旧请求回来照样写回）；
/// - **加载更多不会因失败清空**：失败只记 [error]，已加载数据保留；
/// - 换关键词/换筛选条件用 [reset]（清空数据与分页状态）。
class CommonListController<T> extends ChangeNotifier {
  CommonListController({
    required this.fetchPage,
    this.describeError,
  });

  /// 拉取第 [page] 页（页码从 1 开始）
  final Future<PageResult<T>> Function(int page) fetchPage;

  /// 异常 → 展示文案（默认 `toString()`；页面可传入自己的语义化映射）
  final String Function(Object error)? describeError;

  final List<T> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _started = false;
  bool _hasLoadedOnce = false;
  String? _error;
  bool _disposed = false;

  /// 会话号（§4.29）：[reset] 作废在飞请求，旧结果不再回写（P1-37）
  final AsyncSession _session = AsyncSession();

  /// 已加载的数据（只读视图）
  List<T> get items => UnmodifiableListView(_items);

  /// 是否已发起过至少一次加载（页面据此决定「未开始」提示）
  bool get started => _started;

  /// 首屏/刷新加载中
  bool get isLoading => _loading;

  /// 加载更多中
  bool get isLoadingMore => _loadingMore;

  /// 是否还有下一页
  bool get hasMore => _hasMore;

  /// 最近一次错误（成功后清空；有数据时不影响展示）
  String? get error => _error;

  /// 已加载到第几页（0 = 未加载）
  int get page => _page;

  /// 三态（有数据恒为 Loaded，即使最近一次刷新失败；
  /// **成功加载过但结果为空**也算 Loaded——否则空列表会永远显示加载中）
  LoadingState<List<T>> get state {
    if (_items.isNotEmpty) return LoadingState.loaded(items);
    if (_error != null) return LoadingState.error(_error!);
    if (_hasLoadedOnce) return LoadingState.loaded(items);
    return const LoadingState.loading();
  }

  /// 重新从第 1 页加载（保留旧数据直到成功；失败只记录错误）
  Future<void> refresh() async {
    if (_disposed || _loading || _loadingMore) return;
    final token = _session.start(); // 新一轮：作废更早的在飞请求
    _loading = true;
    _started = true;
    _error = null;
    _notify();
    try {
      final result = await fetchPage(1);
      if (_disposed || !_session.isCurrent(token)) return;
      _items
        ..clear()
        ..addAll(result.items);
      _page = 1;
      _hasMore = result.hasMore;
      _hasLoadedOnce = true;
    } catch (e) {
      if (_disposed || !_session.isCurrent(token)) return;
      _error = _describe(e);
    } finally {
      // 只有仍是最新会话才收尾：被作废的旧请求不能清新请求的加载标志
      if (_session.isCurrent(token)) {
        _loading = false;
        _notify();
      }
    }
  }

  /// 加载下一页并追加（无下一页/正在加载/最近一次出错时不动作）
  Future<void> loadMore() async {
    if (_disposed || _loading || _loadingMore || !_hasMore || _error != null) {
      return;
    }
    if (!_started) return refresh();
    final token = _session.generation; // 沿用当前会话（不新开一轮）
    _loadingMore = true;
    _notify();
    try {
      final result = await fetchPage(_page + 1);
      if (_disposed || !_session.isCurrent(token)) return;
      _items.addAll(result.items);
      _page += 1;
      _hasMore = result.hasMore;
      _hasLoadedOnce = true;
    } catch (e) {
      if (_disposed || !_session.isCurrent(token)) return;
      _error = _describe(e);
    } finally {
      if (_session.isCurrent(token)) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  /// 清空数据与分页状态（换关键词/筛选条件时调用，随后再 [refresh]）。
  ///
  /// 同时**作废在飞请求**：旧关键词的响应回来时令牌已失效 → 结果被丢弃，
  /// 不会覆盖新关键词的列表（P1-37；旧实现只清标志，旧响应照样写回）。
  void reset() {
    _session.invalidate();
    _items.clear();
    _page = 0;
    _loading = false;
    _loadingMore = false;
    _hasMore = true;
    _started = false;
    _hasLoadedOnce = false;
    _error = null;
    _notify();
  }

  /// 清除错误（重试前调用；重试入口用 [refresh]）
  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  String _describe(Object e) => describeError?.call(e) ?? e.toString();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
