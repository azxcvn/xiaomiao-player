import 'package:flutter/material.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/widgets/file_selection_ui.dart';
import 'package:moumou/widgets/marquee_text.dart';

/// 文件夹卡片：列表模式与树状模式共用（字段驱动渲染）
///
/// 尾部为静态 chevron_right，点击进入下一层（列表=文件夹详情页；树状=目录浏览页）。
/// **固定的文件夹**在名称左侧显示一枚图钉（纯指示，固定/取消固定走长按菜单，
/// 见 `folder_actions`）；长按卡片由调用方弹出文件管理菜单。
///
/// 多选态（[selectionMode]）下：左侧插入勾选圆点、尾部 chevron 隐藏
/// （此态点击是「选中」而不是「进入」），选中项换底色 + 主题色描边。
class FolderCard extends StatelessWidget {
  final TreeNode node;
  final Set<FolderField> fields;
  final VoidCallback onTap;

  /// 长按卡片（弹出文件管理菜单：固定/复制/移动/重命名/删除/多选）；null 时无长按行为
  final VoidCallback? onLongPress;

  /// 是否已固定（置顶显示）；固定项始终排在列表最前
  final bool isPinned;

  /// 是否处于多选态
  final bool selectionMode;

  /// 是否已被选中（仅多选态有意义）
  final bool selected;

  const FolderCard({
    super.key,
    required this.node,
    required this.fields,
    required this.onTap,
    this.onLongPress,
    this.isPinned = false,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: selected ? selectedCardColor(scheme) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selectedCardSide(scheme, selected),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (selectionMode) SelectionMark(selected: selected),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.folder, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 15,
                              color: scheme.primary,
                            ),
                          ),
                        Expanded(
                          child: MarqueeText(
                            text: node.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._buildFields(scheme),
                  ],
                ),
              ),
              // 多选态点击是「选中」而不是「进入下一层」，箭头会造成误导 → 隐藏
              if (!selectionMode)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFields(ColorScheme scheme) {
    final widgets = <Widget>[];

    // 路径：单独一行（完整显示，不省略；长路径自动换行）
    if (fields.contains(FolderField.path)) {
      widgets.add(_fieldRow(scheme, Icons.folder_open, node.path));
    }

    // 数量/大小/日期：横向紧凑排列
    final tags = <Widget>[];
    if (fields.contains(FolderField.count)) {
      tags.add(
        _fieldTag(
          scheme,
          Icons.video_library_outlined,
          '${node.videoCount} 个视频',
        ),
      );
    }
    if (fields.contains(FolderField.size)) {
      tags.add(
        _fieldTag(scheme, Icons.data_usage, formatFileSize(node.totalSize)),
      );
    }
    if (fields.contains(FolderField.date)) {
      tags.add(
        _fieldTag(
          scheme,
          Icons.calendar_today_outlined,
          formatDate(node.dateModified),
        ),
      );
    }
    if (tags.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 14, runSpacing: 4, children: tags),
        ),
      );
    }

    return widgets;
  }

  Widget _fieldRow(ColorScheme scheme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          // 完整显示路径（不省略不截断；多行换行）
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldTag(ColorScheme scheme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
