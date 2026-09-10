import 'package:flutter/material.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/folder_card.dart';

/// 列表视图：只列出文件夹（点进去只显示该文件夹内的视频）。
/// 首页列表模式的专属视图。
///
/// 长按文件夹由调用方弹出文件管理菜单（固定/复制/移动/重命名/删除）；
/// 固定的文件夹按 [pinnedPaths] 显示图钉并稳定前置。
class FolderListView extends StatelessWidget {
  final List<TreeNode> folders;
  final Set<FolderField> fields;
  final Set<String> pinnedPaths;
  final void Function(TreeNode) onFolderTap;
  final void Function(TreeNode)? onFolderLongPress;

  const FolderListView({
    super.key,
    required this.folders,
    required this.fields,
    required this.onFolderTap,
    this.pinnedPaths = const {},
    this.onFolderLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 底部预留悬浮胶囊空间（系统安全区已由全局 AppFrame 处理）
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final node = folders[index];
        return FolderCard(
          node: node,
          fields: fields,
          onTap: () => onFolderTap(node),
          onLongPress: onFolderLongPress == null
              ? null
              : () => onFolderLongPress!(node),
          isPinned: pinnedPaths.contains(node.path),
        );
      },
    );
  }
}
