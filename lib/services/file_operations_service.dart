import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moumou/utils/file_ops.dart';

/// 文件操作失败（复制/移动/重命名/删除）：[message] 为可直接展示的中文原因。
class FileOpException implements Exception {
  final String message;

  const FileOpException(this.message);

  @override
  String toString() => message;
}

/// 传输进度快照（复制 / 移动共用）
class FileOpProgress {
  /// 当前正在处理的条目名（文件或文件夹名）
  final String currentName;

  /// 已累计完成的字节数
  final int bytesDone;

  /// 本轮需要传输的总字节数（移动时若源已与目标同卷，则为 0）
  final int bytesTotal;

  /// 已处理条目数 / 总条目数
  final int itemsDone;
  final int itemsTotal;

  const FileOpProgress({
    required this.currentName,
    required this.bytesDone,
    required this.bytesTotal,
    required this.itemsDone,
    required this.itemsTotal,
  });

  /// 0 – 1；总字节未知时退化为按条目数估算
  double get fraction {
    if (bytesTotal > 0) {
      return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    }
    if (itemsTotal > 0) return (itemsDone / itemsTotal).clamp(0.0, 1.0);
    return 0;
  }

  static const FileOpProgress idle = FileOpProgress(
    currentName: '',
    bytesDone: 0,
    bytesTotal: 0,
    itemsDone: 0,
    itemsTotal: 0,
  );
}

/// 取消令牌：UI 每帧写入，传输循环每次缓冲后轮询一次。
///
/// 之所以不用 CancelToken 流式方案：`dart:io` 的 `File.openRead()` 无法中途
/// 打断，只能在块与块之间退出，因此用一个可变对象做「协作式取消」最直接。
class FileOpCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// 文件管理服务：复制 / 移动 / 重命名 / 删除（单条目，走真实路径 `dart:io`）。
///
/// 前置条件：App 已持有 `MANAGE_EXTERNAL_STORAGE`（首页权限门禁保证），
/// 因此无需 SAF 中转，目录选择器直接给真实路径（见 `directory_picker_dialog`）。
/// 所有方法失败抛 [FileOpException]，文案可直接进 SnackBar。
class FileOperationsService {
  FileOperationsService._();

  /// 复制 1 MB 检查一次取消/汇报一次进度
  static const int _chunkBytes = 1024 * 1024;

  /// 文件系统条目是否存在（文件或目录）
  static bool exists(String path) {
    final p = FileOps.stripTrailingSlash(path);
    if (p.isEmpty) return false;
    return File(p).existsSync() || Directory(p).existsSync();
  }

  /// 是否为目录
  static bool isDirectory(String path) =>
      Directory(FileOps.stripTrailingSlash(path)).existsSync();

  // ───────────────────────── 复制 / 移动 ─────────────────────────

  /// 复制 [sourcePath] 到 [destinationDir]。
  ///
  /// 重名自动避让（`名字 (1)`）；返回实际落地的目标绝对路径。
  static Future<String> copy(
    String sourcePath,
    String destinationDir, {
    FileOpCancelToken? cancelToken,
    ValueChanged<FileOpProgress>? onProgress,
  }) {
    return _transfer(
      sourcePath,
      destinationDir,
      move: false,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }

  /// 移动 [sourcePath] 到 [destinationDir]，返回实际落地的目标绝对路径。
  ///
  /// 同卷优先用 `Directory.rename` / `File.rename`（原子、秒级）；
  /// 跨卷失败自动退化为「复制 + 删除源」并汇报进度。
  static Future<String> move(
    String sourcePath,
    String destinationDir, {
    FileOpCancelToken? cancelToken,
    ValueChanged<FileOpProgress>? onProgress,
  }) {
    return _transfer(
      sourcePath,
      destinationDir,
      move: true,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
  }

  static Future<String> _transfer(
    String sourcePath,
    String destinationDir, {
    required bool move,
    FileOpCancelToken? cancelToken,
    ValueChanged<FileOpProgress>? onProgress,
  }) async {
    final src = FileOps.stripTrailingSlash(sourcePath);
    final dest = FileOps.stripTrailingSlash(destinationDir);

    final isDir = Directory(src).existsSync();
    final isFile = File(src).existsSync();
    if (!isDir && !isFile) {
      throw const FileOpException('源文件不存在或已被移动');
    }

    final error = FileOps.validateMoveTarget(
      sourcePath: src,
      sourceIsDirectory: isDir,
      destinationDir: dest,
    );
    if (error != null) throw FileOpException(error);

    final name = FileOps.uniqueName(
      FileOps.baseName(src),
      (candidate) => exists('$dest/$candidate'),
    );
    final target = '$dest/$name';

    if (move && !isDir) {
      // 同卷文件移动：先试原子 rename，失败再走复制+删除
      try {
        await File(src).rename(target);
        onProgress?.call(FileOpProgress(
          currentName: name,
          bytesDone: 0,
          bytesTotal: 0,
          itemsDone: 1,
          itemsTotal: 1,
        ));
        return target;
      } catch (_) {
        // 跨卷 / 权限差异 → 走通用路径
      }
    }

    final entries = _collect(src, isDir: isDir);
    final totalBytes = entries.fold<int>(0, (sum, e) => sum + e.size);
    onProgress?.call(FileOpProgress(
      currentName: name,
      bytesDone: 0,
      bytesTotal: totalBytes,
      itemsDone: 0,
      itemsTotal: entries.isEmpty ? 1 : entries.length,
    ));

    var bytesDone = 0;
    var itemsDone = 0;

    // 目录源必须在循环**之前**建出目标根目录：空目录（或只含符号链接的目录）
    // 的 entries 为空，循环体一次都不执行 → 「移动」会删掉源却不创建目标，
    // 文件夹凭空消失还提示成功（见体检报告 P0-2）。
    if (isDir) {
      try {
        await Directory(target).create(recursive: true);
      } catch (e) {
        throw FileOpException('写入失败：$name（$e）');
      }
    }

    for (final entry in entries) {
      if (cancelToken?.isCancelled ?? false) {
        throw const FileOpException('已取消');
      }
      final rel = entry.relPath;
      final outPath = rel.isEmpty ? target : '$target/$rel';
      try {
        if (entry.isDirectory) {
          await Directory(outPath).create(recursive: true);
        } else {
          await Directory(FileOps.parentOf(outPath)).create(recursive: true);
          bytesDone = await _copyFile(
            entry.path,
            outPath,
            bytesDone: bytesDone,
            name: name,
            totalBytes: totalBytes,
            itemsDone: itemsDone,
            itemsTotal: entries.length,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
        }
      } on FileOpException {
        rethrow;
      } catch (e) {
        throw FileOpException('写入失败：${FileOps.baseName(outPath)}（$e）');
      }
      itemsDone++;
      onProgress?.call(FileOpProgress(
        currentName: name,
        bytesDone: bytesDone,
        bytesTotal: totalBytes,
        itemsDone: itemsDone,
        itemsTotal: entries.length,
      ));
    }

    if (move) {
      try {
        if (isDir) {
          await Directory(src).delete(recursive: true);
        } else {
          await File(src).delete();
        }
      } catch (_) {
        throw const FileOpException('已复制到目标位置，但删除原文件失败，请手动清理');
      }
    }
    return target;
  }

  /// 把 [source] 拷成 [target]，返回累计已写字节数。
  ///
  /// 用 `listen` 而非 `await for` + `Stream.cancel()`：`File.openRead()` 返回的
  /// 是单订阅流，`Stream` 上没有 `cancel()`，中途退出只能靠订阅句柄取消。
  static Future<int> _copyFile(
    String source,
    String target, {
    required int bytesDone,
    required String name,
    required int totalBytes,
    required int itemsDone,
    required int itemsTotal,
    FileOpCancelToken? cancelToken,
    ValueChanged<FileOpProgress>? onProgress,
  }) async {
    final input = File(source).openRead();
    final output = File(target).openWrite();
    var done = bytesDone;
    final completer = Completer<void>();
    late final StreamSubscription<List<int>> subscription;
    subscription = input.listen(
      (chunk) {
        if (cancelToken?.isCancelled ?? false) {
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.completeError(const FileOpException('已取消'));
          }
          return;
        }
        output.add(chunk);
        done += chunk.length;
        if (done - bytesDone >= _chunkBytes || done == totalBytes) {
          onProgress?.call(FileOpProgress(
            currentName: name,
            bytesDone: done,
            bytesTotal: totalBytes,
            itemsDone: itemsDone,
            itemsTotal: itemsTotal,
          ));
        }
      },
      onError: (Object e, StackTrace s) {
        if (!completer.isCompleted) completer.completeError(e, s);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    try {
      await completer.future;
      await output.flush();
    } finally {
      await subscription.cancel();
      await output.close();
    }
    return done;
  }

  /// 展开 [source] 下需要处理的条目（目录自身不出现在列表里，避免把根目录当成文件写）
  static List<_Entry> _collect(String source, {required bool isDir}) {
    if (!isDir) {
      final f = File(source);
      return [
        _Entry(
          path: source,
          relPath: '',
          isDirectory: false,
          size: f.existsSync() ? f.lengthSync() : 0,
        ),
      ];
    }
    final out = <_Entry>[];
    final root = Directory(source);
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      final rel = entity.path.substring(source.length + 1);
      if (entity is Directory) {
        out.add(_Entry(
          path: entity.path,
          relPath: rel,
          isDirectory: true,
          size: 0,
        ));
      } else if (entity is File) {
        out.add(_Entry(
          path: entity.path,
          relPath: rel,
          isDirectory: false,
          size: entity.lengthSync(),
        ));
      }
    }
    return out;
  }

  // ───────────────────────── 重命名 ─────────────────────────

  /// 重命名文件或文件夹，返回新绝对路径。
  ///
  /// [newName] 只含新名字（不含路径）；文件保留原扩展名由调用方决定是否带。
  /// App 内重命名**不允许改名冲突**（同目录已有同名 → 报错，不做自动避让），
  /// 因为重命名是显式意图，静默改名叫 `xxx (1)` 会让用户困惑。
  static Future<String> rename(String path, String newName) async {
    final src = FileOps.stripTrailingSlash(path);
    if (!exists(src)) throw const FileOpException('源文件不存在或已被移动');

    final check = FileOps.validateRenameName(newName);
    if (!check.ok) throw FileOpException(check.error);

    final name = newName.trim();
    if (name == FileOps.baseName(src)) return src; // 没改，直接成功

    final target = '${FileOps.parentOf(src)}/$name';
    if (exists(target)) throw const FileOpException('同目录下已存在同名文件或文件夹');

    try {
      if (Directory(src).existsSync()) {
        await Directory(src).rename(target);
      } else {
        await File(src).rename(target);
      }
    } catch (e) {
      throw FileOpException('重命名失败：$e');
    }
    return target;
  }

  // ───────────────────────── 删除 ─────────────────────────

  /// 删除文件；[deleteWholeFolder] 的语义见 [deleteFolder]
  static Future<void> deleteFile(String path) async {
    final src = FileOps.stripTrailingSlash(path);
    final file = File(src);
    if (!file.existsSync()) throw const FileOpException('文件不存在或已被删除');
    try {
      await file.delete();
    } catch (e) {
      throw FileOpException('删除失败：$e');
    }
  }

  /// 删除文件夹。两种语义由删除确认弹窗当场选择（对齐 mpvRx 的
  /// `deleteFolderAllContents` 偏好，但改为每次询问）：
  /// - [deleteWholeFolder] = true：整个目录递归删除（含字幕/弹幕等非视频文件）
  /// - [deleteWholeFolder] = false：只删目录里的**视频文件**，保留目录与其它文件
  ///
  /// 返回实际删除的条目数（文件夹语义下为删除的视频文件数）。
  static Future<int> deleteFolder(
    String path, {
    required bool deleteWholeFolder,
  }) async {
    final src = FileOps.stripTrailingSlash(path);
    final dir = Directory(src);
    if (!dir.existsSync()) throw const FileOpException('文件夹不存在或已被删除');

    if (deleteWholeFolder) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        throw FileOpException('删除失败：$e');
      }
      return 1;
    }

    var deleted = 0;
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        if (!_isVideoFile(entity.path)) continue;
        await entity.delete();
        deleted++;
      }
    } catch (e) {
      throw FileOpException('删除失败：$e');
    }
    if (deleted == 0) {
      throw const FileOpException('该文件夹内没有可删除的视频文件');
    }
    return deleted;
  }

  /// 「只删视频」语义下的判定：与扫描器共用 [FileOps.videoExtensions] 这一份
  /// 唯一真值（此前的删除集合额外含 7 个音频扩展名，导致弹窗承诺的「其它文件
  /// 不会被删除」被违背、音频被永久删除，见体检报告 P0-1）。
  static bool _isVideoFile(String path) =>
      FileOps.isVideoFileName(FileOps.baseName(path));
}

/// 待传输条目（相对源根目录的路径；文件条目 relPath 为空表示源本身是文件）
class _Entry {
  final String path;
  final String relPath;
  final bool isDirectory;
  final int size;

  const _Entry({
    required this.path,
    required this.relPath,
    required this.isDirectory,
    required this.size,
  });
}
