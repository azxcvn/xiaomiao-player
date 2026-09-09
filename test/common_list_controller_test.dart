import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/common_list_controller.dart';
import 'package:moumou/utils/loading_state.dart';

/// C2 通用分页控制器测试（§4.29）：
/// - 三态（首次加载 / 有数据 / 首次失败）；
/// - 刷新失败**保留旧数据**（state 仍为 Loaded，仅记录 error）；
/// - 加载更多追加 + hasMore 收敛；
/// - 并发防重入、出错后阻止加载更多、reset 清空；
/// - describeError 语义化映射。
/// 可控的假分页源（页大小 20，按 total 计算 hasMore）
class FakeSource {
  FakeSource({this.total = 45, this.pageSize = 20});
  final int total;
  final int pageSize;
  int calls = 0;
  Object? failWith;
  Duration delay = Duration.zero;

  Future<PageResult<int>> fetch(int page) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failWith != null) throw failWith!;
    final start = (page - 1) * pageSize;
    final items = [
      for (var i = start; i < start + pageSize && i < total; i++) i,
    ];
    return PageResult(items, hasMore: page * pageSize < total);
  }
}

void main() {
  group('三态', () {
    test('未加载时 state 为 Loading', () {
      final c = CommonListController<int>(
        fetchPage: FakeSource().fetch,
      );
      expect(c.state, isA<Loading<List<int>>>());
      expect(c.started, isFalse);
      expect(c.items, isEmpty);
      expect(c.state.hasData, isFalse);
      expect(c.state.dataOrNull, isNull);
      expect(c.state.errorOrNull, isNull);
      c.dispose();
    });

    test('首次加载成功 → Loaded + 页码/hasMore', () async {
      final src = FakeSource(total: 45);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      expect(c.started, isTrue);
      expect(c.state, isA<Loaded<List<int>>>());
      expect(c.items, List.generate(20, (i) => i));
      expect(c.page, 1);
      expect(c.hasMore, isTrue);
      expect(c.error, isNull);
      c.dispose();
    });

    test('首次加载失败（无数据）→ LoadError', () async {
      final src = FakeSource()..failWith = StateError('网络炸了');
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      expect(c.state, isA<LoadError<List<int>>>());
      expect(c.state.errorOrNull, contains('网络炸了'));
      expect(c.items, isEmpty);
      c.dispose();
    });

    test('成功但结果为空 → Loaded([])（不能永远显示加载中）', () async {
      final src = FakeSource(total: 0);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      expect(c.state, isA<Loaded<List<int>>>());
      expect(c.items, isEmpty);
      expect(c.hasMore, isFalse);
      // reset 后回到 Loading
      c.reset();
      expect(c.state, isA<Loading<List<int>>>());
      c.dispose();
    });
  });

  group('刷新失败保留旧数据', () {
    test('已有数据时刷新失败：列表不清空，仅记录 error', () async {
      final src = FakeSource(total: 10);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      final before = c.items;

      src.failWith = StateError('抖了一下');
      await c.refresh();

      expect(c.items, before); // 旧数据仍在
      expect(c.state, isA<Loaded<List<int>>>()); // 仍是 Loaded
      expect(c.error, contains('抖了一下')); // 错误另存
      c.dispose();
    });

    test('成功后 error 被清空', () async {
      final src = FakeSource(total: 5);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      src.failWith = StateError('x');
      await c.refresh();
      expect(c.error, isNotNull);
      src.failWith = null;
      await c.refresh();
      expect(c.error, isNull);
      c.dispose();
    });
  });

  group('加载更多', () {
    test('追加下一页并更新页码，到末尾后 hasMore=false', () async {
      final src = FakeSource(total: 45);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      await c.loadMore();
      expect(c.items.length, 40);
      expect(c.page, 2);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.items.length, 45);
      expect(c.page, 3);
      expect(c.hasMore, isFalse);
      c.dispose();
    });

    test('hasMore=false 时不再请求', () async {
      final src = FakeSource(total: 3);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      expect(c.hasMore, isFalse);
      final callsBefore = src.calls;
      await c.loadMore();
      expect(src.calls, callsBefore);
      c.dispose();
    });

    test('最近一次出错时阻止加载更多', () async {
      final src = FakeSource(total: 100);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      src.failWith = StateError('err');
      await c.loadMore(); // 失败
      expect(c.error, isNotNull);
      final callsBefore = src.calls;
      await c.loadMore(); // 被阻止
      expect(src.calls, callsBefore);
      c.dispose();
    });

    test('未开始时 loadMore 等价首次加载', () async {
      final src = FakeSource(total: 10);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.loadMore();
      expect(c.started, isTrue);
      expect(c.items.length, 10);
      expect(c.page, 1);
      c.dispose();
    });
  });

  group('并发防重入 / reset / 映射', () {
    test('加载中重复调用 refresh/loadMore 不重复请求', () async {
      final src = FakeSource(total: 100)
        ..delay = const Duration(milliseconds: 20);
      final c = CommonListController<int>(fetchPage: src.fetch);
      final first = c.refresh();
      final second = c.refresh(); // 应被忽略
      final more = c.loadMore(); // 应被忽略
      await Future.wait([first, second, more]);
      expect(src.calls, 1);
      c.dispose();
    });

    test('reset 清空数据与分页状态', () async {
      final src = FakeSource(total: 45);
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      await c.loadMore();
      c.reset();
      expect(c.items, isEmpty);
      expect(c.page, 0);
      expect(c.started, isFalse);
      expect(c.hasMore, isTrue);
      expect(c.error, isNull);
      expect(c.state, isA<Loading<List<int>>>());
      c.dispose();
    });

    test('clearError 只清错误', () async {
      final src = FakeSource(total: 5)..failWith = StateError('e');
      final c = CommonListController<int>(fetchPage: src.fetch);
      await c.refresh();
      expect(c.error, isNotNull);
      c.clearError();
      expect(c.error, isNull);
      c.dispose();
    });

    test('describeError 自定义文案', () async {
      final src = FakeSource()..failWith = StateError('原始错误');
      final c = CommonListController<int>(
        fetchPage: src.fetch,
        describeError: (e) => '友好提示',
      );
      await c.refresh();
      expect(c.error, '友好提示');
      expect(c.state.errorOrNull, '友好提示');
      c.dispose();
    });

    test('notifyListeners 在状态变化时触发', () async {
      final src = FakeSource(total: 5);
      final c = CommonListController<int>(fetchPage: src.fetch);
      var notified = 0;
      c.addListener(() => notified++);
      await c.refresh();
      expect(notified, greaterThanOrEqualTo(2)); // 开始 + 结束
      c.dispose();
    });

    test('dispose 后不再通知、不再请求', () async {
      final src = FakeSource(total: 5)..delay = const Duration(milliseconds: 10);
      final c = CommonListController<int>(fetchPage: src.fetch);
      final future = c.refresh();
      c.dispose();
      await future; // 不应抛「已 dispose 还 notify」异常
      expect(c.items, isEmpty);
    });
  });
}
