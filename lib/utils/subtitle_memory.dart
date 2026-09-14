/// 外挂字幕「记忆路径」的失效清理（P1-9，纯函数、可单测）。
///
/// 背景：`SubtitleSettings` 按视频路径记住用户导入 / 同名自动加载的外挂字幕
/// 绝对路径，重开同一视频时直接 `sub-add` 这些路径，**且只要记忆非空就跳过
/// 同名字幕扫描**。一旦用户删掉或改名了那个字幕文件，记忆里的死路径会：
/// ①`sub-add` 失败（静默）②同名扫描永不执行 → **该视频永久没有任何字幕**，
/// 直到手动导入或清数据。这正是 `docs/ARCHITECTURE.md` §4.11 记过的
/// 「记忆死路径」教训（弹幕侧早已有失效清理，字幕侧没有）。
///
/// 因此重新挂载前必须逐个校验存在性：失效的从设置里删掉，全部失效时
/// 允许回落同名扫描。此处只做**判断与分流**（`exists` 由调用方注入，
/// 便于单测不碰文件系统）。
library;

/// 记忆路径的分流结果。
///
/// - [valid]：仍然存在的路径（按原顺序、已去重）；
/// - [stale]：已失效的路径（应从设置里移除，并允许回落同名扫描）。
typedef SubtitleMemoryPartition = ({List<String> valid, List<String> stale});

/// 把记忆路径分流为「仍可用」与「已失效」。
///
/// 顺序与去重规则：保留**首次出现**的顺序（用户导入顺序即面板顺序），
/// 重复项算作非失效（避免误判为 stale 后把有效路径删掉）。
SubtitleMemoryPartition partitionSubtitleMemoryPaths(
  List<String> paths, {
  required bool Function(String path) exists,
}) {
  final valid = <String>[];
  final stale = <String>[];
  final seen = <String>{};
  for (final path in paths) {
    if (path.isEmpty) continue;
    if (!seen.add(path)) continue;
    if (exists(path)) {
      valid.add(path);
    } else {
      stale.add(path);
    }
  }
  return (valid: valid, stale: stale);
}
