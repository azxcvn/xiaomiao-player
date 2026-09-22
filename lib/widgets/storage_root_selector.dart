import 'package:flutter/material.dart';
import 'package:moumou/models/storage_root.dart';
import 'package:moumou/services/device_services.dart';

/// 存储卷跳转行：把已挂载的存储卷（内部存储 / SD 卡 / U 盘）列成一行胶囊，
/// 点击即跳到该卷根（issue #3）。
///
/// 为什么必须单独有这么一行：`/storage` 目录本身在 Android 11+ 上**列不出来**
/// ——「所有文件访问」只授权到各卷根，不含 `/storage` 这个挂载点容器。所以
/// 自建选择器停在 `/storage/emulated/0` 时既上不去、也发现不了外置卡；
/// 卷只能由原生 `StorageManager` 枚举（[DeviceServices.getStorageRoots]）。
///
/// - 卷列表加载失败 / 只有内部存储一个卷 → 整行收起（不占位、不报错）；
/// - [currentPath] 落在某个卷内时该胶囊高亮（高亮由 [storageRootOf] 判定）；
/// - [onDark] = true 时用播放页深色面板配色，否则跟随主题（设置页 / 对话框）。
class StorageRootSelector extends StatelessWidget {
  /// 当前浏览路径（用于高亮所在卷）
  final String currentPath;

  /// 点击某个卷根的回调（传卷根绝对路径）
  final ValueChanged<String> onRootSelected;

  /// 是否深色面板（播放器内的选择器用）
  final bool onDark;

  const StorageRootSelector({
    super.key,
    required this.currentPath,
    required this.onRootSelected,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StorageRoot>>(
      future: DeviceServices.getStorageRoots(),
      builder: (context, snapshot) {
        final roots = snapshot.data ?? const <StorageRoot>[];
        // 只有一个卷时跳转无意义（进不去外置卡），直接收起
        if (roots.length < 2) return const SizedBox.shrink();
        final active = storageRootOf(currentPath, roots);
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < roots.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _RootChip(
                    root: roots[i],
                    selected: identical(roots[i], active),
                    onDark: onDark,
                    scheme: scheme,
                    onTap: () => onRootSelected(roots[i].path),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 单个卷胶囊：图标区分内部存储 / 可移除卷，选中态用主题色填充
class _RootChip extends StatelessWidget {
  final StorageRoot root;
  final bool selected;
  final bool onDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _RootChip({
    required this.root,
    required this.selected,
    required this.onDark,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = root.isRemovable
        ? Icons.sd_card_outlined
        : Icons.smartphone_outlined;

    final Color background;
    final Color foreground;
    final Color border;
    if (onDark) {
      background = selected
          ? const Color(0xFF4FC3F7).withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.08);
      foreground = selected ? const Color(0xFF4FC3F7) : Colors.white70;
      border = selected
          ? const Color(0xFF4FC3F7).withValues(alpha: 0.6)
          : Colors.white24;
    } else {
      background = selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest;
      foreground =
          selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
      border = selected ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              root.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
