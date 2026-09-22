/// 存储卷根（自建文件选择器的「卷跳转」入口用，issue #3）。
///
/// 一个 [StorageRoot] = 一个已挂载的存储卷：内部存储（`/storage/emulated/0`）
/// 或外置卷（SD 卡 / U 盘，挂载在 `/storage/XXXX-XXXX`）。
///
/// 为什么需要它：`/storage` 目录本身在 Android 11+ 上**列不出来**——「所有文件
/// 访问」只授权到各卷根，不含 `/storage` 这个挂载点容器，所以自建选择器停在
/// `/storage/emulated/0` 时既上不去、也永远发现不了外置卡。卷只能由原生侧走
/// `StorageManager` 枚举后交给 Dart（见 [DeviceServices.getStorageRoots]）。
class StorageRoot {
  /// 展示名（原生取 `StorageVolume.getDescription`，如「内部存储」「SD 卡」）
  final String name;

  /// 卷根绝对路径（如 `/storage/ABCD-1234`）
  final String path;

  /// 是否内部存储（主共享卷）
  final bool isPrimary;

  /// 是否可移除（SD 卡 / U 盘；内部存储为 false）
  final bool isRemovable;

  const StorageRoot({
    required this.name,
    required this.path,
    this.isPrimary = false,
    this.isRemovable = false,
  });
}

/// 判断 [path] 落在哪个卷根下（含相等），用于选择器高亮当前卷。
///
/// 找不到归属返回 null（例如路径已在卷外，或卷列表不可用）。
/// 取**最长匹配**：个别设备存在卷根互相嵌套的罕见情况，最长前缀才是
/// 真正包含该路径的那个卷。
StorageRoot? storageRootOf(String path, List<StorageRoot> roots) {
  if (path.isEmpty) return null;
  StorageRoot? best;
  for (final root in roots) {
    if (root.path.isEmpty) continue;
    if (path == root.path || path.startsWith('${root.path}/')) {
      if (best == null || root.path.length > best.path.length) {
        best = root;
      }
    }
  }
  return best;
}
