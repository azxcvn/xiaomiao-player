/// 网络存储目录的排序（纯逻辑，可单测）。
///
/// 远端列目录能拿到的稳定字段只有**名称与修改时间**（大小部分服务器会给 0/-1，
/// 时间也可能缺），所以网络目录**不复用**本地那套排序（名称/日期/大小/数量 +
/// 字段开关）——那会给出实际排不动的选项。这里只留名称与日期两种。
library;

import 'package:moumou/models/network_file.dart';
import 'package:moumou/utils/natural_compare.dart';

enum NetworkSortField {
  name('名称'),
  date('日期');

  final String label;
  const NetworkSortField(this.label);
}

enum NetworkSortOrder {
  asc('升序'),
  desc('降序');

  final String label;
  const NetworkSortOrder(this.label);
}

class NetworkSort {
  final NetworkSortField field;
  final NetworkSortOrder order;

  const NetworkSort({this.field = NetworkSortField.name, this.order = NetworkSortOrder.asc});

  NetworkSort copyWith({NetworkSortField? field, NetworkSortOrder? order}) =>
      NetworkSort(field: field ?? this.field, order: order ?? this.order);

  bool get isAscending => order == NetworkSortOrder.asc;
}

/// 稳定排序：
/// - 名称按自然序（`EP2` 在 `EP10` 前），大小写不敏感；
/// - 日期按时间戳倒/正序，**修改时间缺失（0）的条目恒排在末尾**——远端常有一
///   部分条目没有时间，若把 0 当最小值参与升降序翻转，它们会在降序时跑到最上面。
List<NetworkFile> sortNetworkEntries(
  List<NetworkFile> entries,
  NetworkSort sort,
) {
  final list = [...entries];
  list.sort((a, b) {
    final cmp = switch (sort.field) {
      NetworkSortField.name => _withOrder(
          naturalCompare(a.name, b.name),
          sort,
        ),
      NetworkSortField.date => _compareDate(a, b, sort),
    };
    if (cmp != 0) return cmp;
    // 同值用名称兜底，保证顺序稳定可预期
    return naturalCompare(a.name, b.name);
  });
  return list;
}

int _withOrder(int cmp, NetworkSort sort) => sort.isAscending ? cmp : -cmp;

int _compareDate(NetworkFile a, NetworkFile b, NetworkSort sort) {
  final aTime = a.lastModified;
  final bTime = b.lastModified;
  final aKnown = aTime > 0;
  final bKnown = bTime > 0;
  if (aKnown != bKnown) return aKnown ? -1 : 1; // 未知时间恒在末尾
  if (!aKnown) return 0;
  final cmp = aTime.compareTo(bTime);
  return sort.isAscending ? cmp : -cmp;
}
