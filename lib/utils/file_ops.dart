import 'dart:io';

/// 应用内文件管理（复制 / 移动 / 重命名 / 删除）的**纯函数**部分：
/// 路径细分、目标校验、重命名校验、重名避让、失效固定路径推导、
/// 视频扩展名判定（扫描与删除共用同一份唯一真值）。
///
/// 真正的磁盘读写（含进度与取消）在 `services/file_operations_service.dart`；
/// 本文件不碰磁盘（[directoryContains] 除外，用于防「移动到自己内部」）。
/// 目录分隔符统一按 `/` 处理（Android 绝对路径）。
class FileOps {
  FileOps._();

  /// 取路径最后一段作为显示名（去掉尾部斜杠；根路径返回 `/`）
  static String baseName(String path) {
    final norm = stripTrailingSlash(path);
    if (norm.isEmpty || norm == '/') return norm.isEmpty ? path : '/';
    final i = norm.lastIndexOf('/');
    return i < 0 ? norm : norm.substring(i + 1);
  }

  /// 取父目录路径；已在根下则返回原路径
  static String parentOf(String path) {
    final norm = stripTrailingSlash(path);
    final i = norm.lastIndexOf('/');
    if (i <= 0) return '/';
    return norm.substring(0, i);
  }

  /// 去掉尾部斜杠（根路径 `/` 保留）
  static String stripTrailingSlash(String path) {
    var p = path;
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// 目标目录是否为 [source] 自身或其子孙目录。
  ///
  /// 用于拦截「把文件夹复制/移动进自己的子目录」这类会无限递归、
  /// 或把源目录当目标导致自毁的操作（mpvRx 未拦截，属额外防护）。
  static bool directoryContains(String source, String target) {
    final s = stripTrailingSlash(source);
    final t = stripTrailingSlash(target);
    if (s.isEmpty || t.isEmpty) return false;
    return t == s || t.startsWith('$s/');
  }

  /// 复制/移动的目标目录校验；返回 null 表示合法，否则返回给用户看的原因。
  ///
  /// - 目标目录不存在 / 不是目录 → 提示不可用
  /// - 目标与源同目录 → 提示无需操作（重名会走自动避让加序号，语义混乱）
  /// - 目标是源自身或其子孙 → 提示不允许
  static String? validateMoveTarget({
    required String sourcePath,
    required bool sourceIsDirectory,
    required String destinationDir,
  }) {
    final dest = stripTrailingSlash(destinationDir);
    if (dest.isEmpty) return '请选择目标文件夹';
    if (!Directory(dest).existsSync()) return '目标文件夹不存在或不可读';
    if (parentOf(sourcePath) == dest) {
      return sourceIsDirectory ? '该文件夹已经在这个目录里了' : '该视频已经在这个目录里了';
    }
    if (sourceIsDirectory && directoryContains(sourcePath, dest)) {
      return '不能把文件夹复制或移动到它自己的子目录里';
    }
    return null;
  }

  /// 重命名校验（只校验新名字本身，不碰磁盘）。
  /// 通过返回 `(ok: true)`；不通过返回 `(ok: false, error: 原因)`。
  static ({bool ok, String error}) validateRenameName(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return (ok: false, error: '名称不能为空');
    if (name == '.' || name == '..') return (ok: false, error: '名称不合法');
    if (name.contains('/') || name.contains(r'\')) {
      return (ok: false, error: '名称不能包含路径分隔符');
    }
    if (name.contains(_illegalNameChars)) {
      return (ok: false, error: '名称不能包含 \\ / : * ? " < > | 等字符');
    }
    return (ok: true, error: '');
  }

  static final RegExp _illegalNameChars = RegExp(r'[<>:"|?*\x00-\x1F]');

  /// 扩展名（含点，小写）；没有扩展名返回空串。
  ///
  /// 点开头的隐藏文件（`.nomedia`）视为**没有扩展名**，与 `uniqueName` 的判定一致。
  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot).toLowerCase();
  }

  /// 文件名去掉扩展名后的主体；无扩展名时原样返回。
  static String stemOf(String name) {
    final ext = extensionOf(name);
    return ext.isEmpty ? name : name.substring(0, name.length - ext.length);
  }

  /// 视频扩展名**唯一真值**（含点、小写）。
  ///
  /// 扫描器（`VideoScanner.videoExt`）与「只删文件夹内的视频文件」的删除集合
  /// 必须共用这一份：两处各存一份时曾出现「扫描器不认为音频是视频、删除器却
  /// 按音频扩展名删除」，用户在弹窗读到「其它文件不会被删除」后音频仍被永久
  /// 删除（体检报告 P0-1）。
  static const List<String> videoExtensions = [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.ts', '.m4v',
    '.webm', '.3gp', '.mpg', '.mpeg',
  ];

  /// 是否为视频文件名（只看扩展名、大小写不敏感；传路径请先取 [baseName]）。
  static bool isVideoFileName(String fileName) =>
      videoExtensions.contains(extensionOf(fileName));

  /// 重命名输入框的初始文本：文件给「主体」（扩展名锁死在输入框右侧），
  /// 文件夹给完整名字（文件夹允许改名带点，不锁扩展名）。
  static String renameInitialInput({
    required String currentName,
    required bool isDirectory,
  }) {
    return isDirectory ? currentName : stemOf(currentName);
  }

  /// 由输入框文本计算**最终文件名**：文件的扩展名恒为 [originalName] 的扩展名。
  ///
  /// - 视频/文件：`456` → `456.mp4`；用户把扩展名也打进来（`456.mp4`）时
  ///   静默去掉重复后缀，不会变成 `456.mp4.mp4`（也能修复 mpvRx 式的
  ///   「用户全选删掉扩展名 → 改完文件打不开」的事故）。
  /// - 文件夹：不锁扩展名，输入即最终名字。
  static String renameTargetName({
    required String input,
    required String originalName,
    required bool isDirectory,
  }) {
    final trimmed = input.trim();
    if (isDirectory) return trimmed;
    final ext = extensionOf(originalName);
    if (ext.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.endsWith(ext)) {
      final stem = trimmed.substring(0, trimmed.length - ext.length);
      // `456.mp4` → `456.mp4`；`.mp4`（主体为空）保持原样交给校验报错
      return stem.isEmpty ? trimmed : '$stem$ext';
    }
    return '$trimmed$ext';
  }

  /// 重命名输入校验。
  ///
  /// [originalExtension] 非空时表示「扩展名被锁定」（视频/其它文件）：
  /// 输入 `456.mp4` 视为 `456` 并接受；只输入 `.mp4`（主体为空）则报错，
  /// 避免生成一个只有扩展名的文件。
  static ({bool ok, String error}) validateRenameInput(
    String input, {
    String originalExtension = '',
  }) {
    final check = validateRenameName(input);
    if (!check.ok) return check;
    if (originalExtension.isEmpty) return check;
    // 剥掉锁定的扩展名后必须还有主体（只输 `.mp4` 视为非法）
    final trimmed = input.trim();
    final stem = trimmed.toLowerCase().endsWith(originalExtension)
        ? trimmed.substring(0, trimmed.length - originalExtension.length)
        : trimmed;
    if (stem.trim().isEmpty) {
      return (ok: false, error: '请输入扩展名之前的名称');
    }
    return (ok: true, error: '');
  }

  /// 重名避让：在目标目录里为 [desiredName] 找一个不冲突的名字。
  ///
  /// 带扩展名时序号插在扩展名前（`a.mp4` → `a (1).mp4`），
  /// 无扩展名时直接追加（`S01` → `S01 (1)`）；逐个递增直到不冲突。
  /// [taken] 返回该名字是否已被占用（由调用方查磁盘，便于单测注入）。
  static String uniqueName(String desiredName, bool Function(String) taken) {
    if (!taken(desiredName)) return desiredName;

    final dot = desiredName.lastIndexOf('.');
    final hasExt = dot > 0 && dot < desiredName.length - 1;
    final stem = hasExt ? desiredName.substring(0, dot) : desiredName;
    final ext = hasExt ? desiredName.substring(dot) : '';

    for (var i = 1; i < 10000; i++) {
      final candidate = '$stem ($i)$ext';
      if (!taken(candidate)) return candidate;
    }
    return desiredName;
  }

  /// 重命名/移动后，旧固定路径的清理集合。
  ///
  /// 固定集合按**绝对路径**存储，路径变了旧记录就失效；这里给出应当移除的
  /// 旧路径（重命名 = 旧路径本身；移动 = 旧路径 + 其所有子孙目录）。
  static Set<String> stalePinnedPaths({
    required String oldPath,
    required Iterable<String> pinnedPaths,
    required bool includeDescendants,
  }) {
    final old = stripTrailingSlash(oldPath);
    final stale = <String>{};
    for (final p in pinnedPaths) {
      final norm = stripTrailingSlash(p);
      if (norm == old) {
        stale.add(p);
        continue;
      }
      if (includeDescendants && norm.startsWith('$old/')) stale.add(p);
    }
    return stale;
  }
}
