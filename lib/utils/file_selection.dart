import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';

/// 多选（批量文件管理）的**纯函数**部分：把页面上的卡片索引成
/// 「路径 → 选中项」，再按用户点选顺序取出，供批量编排使用。
///
/// 选中项用记录类型表达，与 `TreeNode` / `VideoFile` 解耦：
/// `widgets/folder_actions.dart` 的批量入口只认这个记录。
typedef FileSelectionItem = ({String path, String name, bool isDirectory});

/// 目录树索引：**递归**收录每一层的文件夹与视频。
///
/// 递归是刻意的：选择发生在当前可见列表上，但列表可能被搜索词过滤过；
/// 用全集索引取名字，能保证「选过、但此刻被过滤掉」的项照样能被批量操作命中。
Map<String, FileSelectionItem> indexTreeSelection(List<TreeNode> nodes) {
  final index = <String, FileSelectionItem>{};
  void walk(List<TreeNode> list) {
    for (final n in list) {
      if (n.isFolder) {
        index[n.path] = (path: n.path, name: n.name, isDirectory: true);
        walk(n.children);
      } else {
        final video = n.video;
        if (video != null) {
          index[video.path] =
              (path: video.path, name: video.name, isDirectory: false);
        }
      }
    }
  }

  walk(nodes);
  return index;
}

/// 视频列表索引（列表模式的文件夹详情页用，那里只有视频）
Map<String, FileSelectionItem> indexVideoSelection(List<VideoFile> videos) {
  return {
    for (final v in videos)
      v.path: (path: v.path, name: v.name, isDirectory: false),
  };
}

/// 按 [order]（用户点选先后）从 [index] 取出选中项。
///
/// 索引里查不到的路径（已被外部删除 / 改名）**自动丢弃**，
/// 因此批量操作永远不会对着一个不存在的路径发起。
List<FileSelectionItem> pickSelection(
  List<String> order,
  Map<String, FileSelectionItem> index,
) {
  final out = <FileSelectionItem>[];
  for (final path in order) {
    final item = index[path];
    if (item != null) out.add(item);
  }
  return out;
}
