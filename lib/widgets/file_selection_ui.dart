import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';

/// 多选相关的公共 UI：**顶部上下文工具栏** + 卡片左侧的勾选圆点。

/// 多选态的顶部工具栏：`[×] 已选 N 项 [全选] [⋮]`。
///
/// **为什么是顶部而不是底部操作条**：主 tab 页底部有悬浮胶囊导航
/// （`MainScaffold` 用 `Stack` 叠加在内容之上，胶囊顶缘距内容底 72），
/// 底部再放一条操作栏会直接压住导航；顶部工具栏不与任何悬浮元素冲突。
///
/// [onOpenMenu] 弹出的是**和长按完全同一个**文件管理菜单
/// （`showFileActionMenu`，多选态下撤掉重命名），保持「菜单只有一个真源」。
PreferredSizeWidget buildFileSelectionAppBar({
  required int count,
  required bool allSelected,
  required VoidCallback onExit,
  required VoidCallback onToggleAll,
  required VoidCallback onOpenMenu,
  required AppLocalizations l10n,
}) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: l10n.fileSelectionExit,
      onPressed: onExit,
    ),
    title: Text(l10n.fileSelectionSelected(count)),
    actions: [
      IconButton(
        icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
        tooltip: allSelected ? l10n.commonDeselectAll : l10n.commonSelectAll,
        onPressed: onToggleAll,
      ),
      IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: l10n.fileSelectionOps,
        // 一个都没选时没有可执行的操作，置灰
        onPressed: count == 0 ? null : onOpenMenu,
      ),
    ],
  );
}

/// 卡片左侧的勾选圆点（多选态下由 `FolderCard` / `VideoCard` 插入）
class SelectionMark extends StatelessWidget {
  final bool selected;

  const SelectionMark({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 22,
        color: selected ? scheme.primary : scheme.outline,
      ),
    );
  }
}

/// 选中卡片的底色（在卡片原底色上叠一层主题色）。
///
/// 视频卡片「已看完置灰」与「已选中」可能同时成立，选中态优先级更高，
/// 否则用户看不出自己选中了没有。
///
/// 壁纸模式下卡片底色只剩 [kWallpaperCardOpacity] 不透明，再往上混 14% 的
/// primary 就几乎看不见了，所以那边换成一层**半透明主题色膜**
/// （见 [wallpaperAwareSelectedCardColor]）。
Color selectedCardColor(ColorScheme scheme) =>
    Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), scheme.surfaceContainerLow);

/// 选中卡片的描边；未选中时返回 `BorderSide.none`
BorderSide selectedCardSide(ColorScheme scheme, bool selected) => selected
    ? BorderSide(color: scheme.primary, width: 1.5)
    : BorderSide.none;
