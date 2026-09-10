import 'package:flutter/material.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/folder_card.dart';
import 'package:moumou/widgets/video_card.dart';

/// 树状视图一级界面：与列表模式一致的文件夹卡片列表（不展开整棵树）。
/// 文件夹点击进入目录浏览页逐级下钻，视频点击直接播放。
/// 首页树状模式的专属视图；空态由调用方处理。
///
/// 文件夹与视频长按由调用方弹出文件管理菜单（文件夹多一项「固定」）；
/// 固定的文件夹按 [pinnedPaths] 显示图钉并稳定前置在列表最前。
class TreeListView extends StatelessWidget {
  final List<TreeNode> roots;
  final Set<FolderField> folderFields;
  final Set<VideoField> videoFields;
  final Set<String> pinnedPaths;
  final void Function(TreeNode) onFolderTap;
  final void Function(VideoFile) onVideoTap;
  final void Function(VideoFile)? onVideoInfoTap;
  final void Function(TreeNode)? onFolderLongPress;
  final void Function(VideoFile)? onVideoLongPress;

  const TreeListView({
    super.key,
    required this.roots,
    required this.folderFields,
    required this.videoFields,
    required this.onFolderTap,
    required this.onVideoTap,
    this.pinnedPaths = const {},
    this.onVideoInfoTap,
    this.onFolderLongPress,
    this.onVideoLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 底部预留悬浮胶囊空间（系统安全区已由全局 AppFrame 处理）
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      itemCount: roots.length,
      itemBuilder: (context, index) {
        final node = roots[index];
        if (node.isFolder) {
          return FolderCard(
            node: node,
            fields: folderFields,
            onTap: () => onFolderTap(node),
            onLongPress: onFolderLongPress == null
                ? null
                : () => onFolderLongPress!(node),
            isPinned: pinnedPaths.contains(node.path),
          );
        }
        return VideoCard(
          video: node.video!,
          fields: videoFields,
          onTap: () => onVideoTap(node.video!),
          onInfoTap: onVideoInfoTap == null
              ? null
              : () => onVideoInfoTap!(node.video!),
          onLongPress: onVideoLongPress == null
              ? null
              : () => onVideoLongPress!(node.video!),
        );
      },
    );
  }
}
