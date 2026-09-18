/// 网络存储浏览页的条目过滤与搜索（纯逻辑，可单测）。
///
/// 本地媒体库有「扫描隐藏文件夹 / .nomedia / 黑白名单」一套规则，网络存储这边
/// 全都没有——远端目录里 `@eaDir`（群晖缩略图）、`#recycle`、`.Trash-1000`、
/// `Thumbs.db` 之类会直接把列表灌满。这里给出一份**最小**的默认过滤。
library;

import 'package:moumou/models/network_file.dart';

/// 常见 NAS / 系统的元数据目录名（小写比较），默认不展示。
const Set<String> kNetworkMetaNames = {
  '@eadir', // 群晖缩略图
  '@tmp', // 群晖临时
  '#recycle', // 群晖回收站
  '#snapshot', // 群晖快照
  '.recycle', // QNAP / 通用回收站
  'lost+found',
  'system volume information',
  'thumbs.db',
  'desktop.ini',
};

/// 该远端条目是否属于「隐藏项」（点开头、常见元数据名/后缀）。
///
/// [showHidden] 为 true 时一律返回 false（开关打开 = 全部展示）。
bool isHiddenNetworkEntry(NetworkFile file, {bool showHidden = false}) {
  if (showHidden) return false;
  final name = file.name.isNotEmpty ? file.name : '';
  if (name.isEmpty) return false;
  if (name.startsWith('.')) return true;
  final lower = name.toLowerCase();
  if (kNetworkMetaNames.contains(lower)) return true;
  // 系统的临时/部分下载文件
  if (lower.endsWith('.tmp') ||
      lower.endsWith('.part') ||
      lower.endsWith('.partial') ||
      lower.endsWith('.crdownload')) {
    return true;
  }
  // `foo~`（编辑器备份）、`#foo#`（Emacs 自动保存）
  if (name.endsWith('~') || (name.startsWith('#') && name.endsWith('#'))) {
    return true;
  }
  return false;
}

/// 过滤掉隐藏项（保持原顺序）。
List<NetworkFile> visibleNetworkEntries(
  List<NetworkFile> entries, {
  bool showHidden = false,
}) {
  if (showHidden) return List.unmodifiable(entries);
  return List.unmodifiable(
    entries.where((e) => !isHiddenNetworkEntry(e, showHidden: false)),
  );
}

/// 按文件名过滤（大小写不敏感的子串匹配；[query] 为空返回原表）。
List<NetworkFile> searchNetworkEntries(
  List<NetworkFile> entries,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.unmodifiable(entries);
  return List.unmodifiable(
    entries.where((e) => e.name.toLowerCase().contains(q)),
  );
}
