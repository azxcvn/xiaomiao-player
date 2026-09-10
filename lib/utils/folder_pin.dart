import 'package:moumou/models/tree_node.dart';

/// 固定（置顶）文件夹的**稳定前置**排序纯函数。
///
/// 语义对齐 mpvRx `FolderListScreen`：
/// ```kotlin
/// val sorted = SortUtils.sortFolders(...)
/// val (pinned, unpinned) = sorted.partition { it.path in pinnedFolderPaths }
/// pinned + unpinned
/// ```
/// 即**先按用户当前排序规则整体排一遍，再按「是否固定」分组前置**——
/// 固定项之间仍然参与排序（不是按固定顺序），未固定项之间也照常排；
/// 排序规则本身不排除固定项，只在最后做一次稳定的分组前置。
///
/// [folders] 必须是**已经排好序**的列表（调用方先跑 `ViewSettings.sortFolders`
/// / `sortTree`），本函数只做分组，不做比较，因此不会引入第二种排序真值。
List<TreeNode> pinnedFoldersFirst(
  List<TreeNode> folders,
  Set<String> pinnedPaths,
) {
  if (pinnedPaths.isEmpty || folders.length < 2) return folders;
  final pinned = <TreeNode>[];
  final rest = <TreeNode>[];
  for (final f in folders) {
    if (f.isFolder && pinnedPaths.contains(f.path)) {
      pinned.add(f);
    } else {
      rest.add(f);
    }
  }
  // 没有固定项，或全部都是固定项（分组前后顺序不变）→ 原样返回
  if (pinned.isEmpty || rest.isEmpty) return folders;
  return [...pinned, ...rest];
}

/// 树状模式版本：对**每一层**的文件夹子级递归应用稳定前置，
/// 使其与首页/目录页的展示顺序完全一致（同一份排序真值，只是逐层下钻）。
///
/// [nodes] 必须是已排序的节点列表；仅文件夹层级受影响，视频相对顺序不变
/// （`sortTree` 已保证文件夹在前、视频在后，保持分组不变）。
List<TreeNode> mapTreeWithPinnedFirst(
  List<TreeNode> nodes,
  Set<String> pinnedPaths,
) {
  if (pinnedPaths.isEmpty) return nodes;
  final ordered = pinnedFoldersFirst(nodes, pinnedPaths);
  var changed = false;
  final result = <TreeNode>[];
  for (final n in ordered) {
    if (!n.isFolder || n.children.isEmpty) {
      result.add(n);
      continue;
    }
    final children = mapTreeWithPinnedFirst(n.children, pinnedPaths);
    if (identical(children, n.children)) {
      result.add(n);
      continue;
    }
    changed = true;
    result.add(
      TreeNode(
        name: n.name,
        path: n.path,
        type: n.type,
        children: children,
        videoCount: n.videoCount,
        totalSize: n.totalSize,
        dateModified: n.dateModified,
      ),
    );
  }
  return changed ? result : ordered;
}
