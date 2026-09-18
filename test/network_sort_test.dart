import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/utils/network_sort.dart';

/// 网络目录排序：**只有名称与日期**（远端列目录可靠给出的字段）。
///
/// 回归场景：此前网络页直接用了本地那套排序（名称/日期/大小/数量），
/// 大小与数量在远端排不动；且「修改时间缺失」的条目在降序时会被顶到最前。
void main() {
  NetworkFile f(String name, {int mtime = 0}) => NetworkFile(
        name: name,
        path: '/$name',
        lastModified: mtime,
      );

  int ms(int day) => DateTime(2026, 1, day).millisecondsSinceEpoch;

  List<String> names(List<NetworkFile> list) => list.map((e) => e.name).toList();

  group('按名称', () {
    test('自然序：EP2 在 EP10 前（不是字典序）', () {
      final list = [f('EP10.mkv'), f('EP2.mkv'), f('EP1.mkv')];
      expect(
        names(sortNetworkEntries(list, const NetworkSort())),
        ['EP1.mkv', 'EP2.mkv', 'EP10.mkv'],
      );
    });

    test('升降序互为反向', () {
      final list = [f('b.mkv'), f('a.mkv'), f('c.mkv')];
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(order: NetworkSortOrder.desc),
        )),
        ['c.mkv', 'b.mkv', 'a.mkv'],
      );
    });
  });

  group('按日期', () {
    test('升序 / 降序', () {
      final list = [f('a', mtime: ms(3)), f('b', mtime: ms(1)), f('c', mtime: ms(2))];
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(field: NetworkSortField.date),
        )),
        ['b', 'c', 'a'],
      );
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(
            field: NetworkSortField.date,
            order: NetworkSortOrder.desc,
          ),
        )),
        ['a', 'c', 'b'],
      );
    });

    test('修改时间缺失（0）的条目**恒排末尾**，降序也不跑到最前', () {
      final list = [f('无时间', mtime: 0), f('旧', mtime: ms(1)), f('新', mtime: ms(5))];
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(
            field: NetworkSortField.date,
            order: NetworkSortOrder.desc,
          ),
        )),
        ['新', '旧', '无时间'],
      );
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(field: NetworkSortField.date),
        )),
        ['旧', '新', '无时间'],
      );
    });

    test('时间相同时按名称兜底，顺序稳定', () {
      final list = [f('b', mtime: ms(1)), f('a', mtime: ms(1))];
      expect(
        names(sortNetworkEntries(
          list,
          const NetworkSort(field: NetworkSortField.date),
        )),
        ['a', 'b'],
      );
    });
  });

  test('不修改传入列表（返回新列表）', () {
    final list = [f('b'), f('a')];
    sortNetworkEntries(list, const NetworkSort());
    expect(names(list), ['b', 'a']);
  });

  test('NetworkSort.copyWith', () {
    const s = NetworkSort();
    expect(s.field, NetworkSortField.name);
    expect(s.isAscending, isTrue);
    final s2 = s.copyWith(
      field: NetworkSortField.date,
      order: NetworkSortOrder.desc,
    );
    expect(s2.field, NetworkSortField.date);
    expect(s2.isAscending, isFalse);
  });
}
