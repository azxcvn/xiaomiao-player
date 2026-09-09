/// 异步数据的三态模型（对齐 PiliPlus `LoadingState`，只取「三态 + 保留旧数据」
/// 语义，不抄 GetX 版控制器）。
///
/// - [Loading]：首次加载中（尚无数据）；
/// - [Loaded]：已有数据（**刷新失败时仍是 Loaded**——旧列表不清空）；
/// - [LoadError]：首次加载失败（无数据可展示）。
///
/// 刷新失败保留旧数据是这套模型的核心收益：用户不会因为一次网络抖动而看到
/// 「列表被清空 + 报错」。
library;

/// 三态：加载中 / 有数据 / 加载失败
sealed class LoadingState<T> {
  const LoadingState();

  /// 首次加载中
  const factory LoadingState.loading() = Loading<T>;

  /// 已有数据
  const factory LoadingState.loaded(T data) = Loaded<T>;

  /// 首次加载失败（无数据）
  const factory LoadingState.error(String message) = LoadError<T>;

  /// 是否有数据可展示
  bool get hasData => this is Loaded<T>;

  /// 数据（无数据时返回 null）
  T? get dataOrNull => switch (this) {
        Loaded<T>(:final data) => data,
        _ => null,
      };

  /// 错误文案（非失败态返回 null）
  String? get errorOrNull => switch (this) {
        LoadError<T>(:final message) => message,
        _ => null,
      };
}

/// 首次加载中
final class Loading<T> extends LoadingState<T> {
  const Loading();
}

/// 已有数据
final class Loaded<T> extends LoadingState<T> {
  final T data;
  const Loaded(this.data);
}

/// 首次加载失败
final class LoadError<T> extends LoadingState<T> {
  final String message;
  const LoadError(this.message);
}

/// 一页数据 + 是否还有下一页（分页控制器的输入）。
class PageResult<T> {
  final List<T> items;

  /// 是否还有下一页（由调用方按总数/返回条数判定）
  final bool hasMore;

  const PageResult(this.items, {this.hasMore = false});

  static const PageResult<Never> empty = PageResult<Never>([], hasMore: false);
}
