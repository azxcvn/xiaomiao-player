/// 网络存储（WebDAV / SMB / FTP）视频的「同目录同名字幕」匹配（纯函数，可单测）。
///
/// 与本地同名自动加载同规则，只是候选来源从 `Directory.list()` 换成远端
/// `NetworkClient.listFiles()`（名单排序复用 [findBestSubtitleFileName]）。
/// 对齐 mpvRx `SubtitleOps.autoloadNetworkFileSubtitles` 的做法：远端列目录 →
/// 命中同名字幕 → 交给本地回环代理铺成无凭据 URL → `sub-add`。
library;

import 'dart:convert';

import 'package:moumou/models/network_file.dart';
import 'package:moumou/utils/subtitle_auto_match.dart';

/// 远程路径（连接根下，以 `/` 开头）中的文件名；取不到返回空串。
///
/// 远端路径可能是 percent 编码态（WebDAV 客户端用 `Uri` 编码后再解回），
/// 这里只还原最基本的 `%XX` 形式，供同名字幕比较使用。
String remoteFileNameOf(String remotePath) {
  final trimmed = remotePath.endsWith('/') && remotePath.length > 1
      ? remotePath.substring(0, remotePath.length - 1)
      : remotePath;
  final slash = trimmed.lastIndexOf('/');
  final raw = slash < 0 ? trimmed : trimmed.substring(slash + 1);
  return _percentDecode(raw);
}

/// 远程路径所在目录（`/` 开头的连接根内路径）；连接根下的文件返回空串。
///
/// 连接根下的文件（`/a.mkv`）返回**空串**而不是 `'/'`：三个协议客户端都把
/// 空串当作连接根（SMB 列共享、WebDAV/FTP 列根），与 [NetworkPath.root] 等效
/// 但便于调用方直接透传。
String remoteDirOf(String remotePath) {
  final trimmed = remotePath.endsWith('/') && remotePath.length > 1
      ? remotePath.substring(0, remotePath.length - 1)
      : remotePath;
  final slash = trimmed.lastIndexOf('/');
  if (slash < 0) return '';
  return trimmed.substring(slash + 1).isEmpty ? '' : trimmed.substring(0, slash);
}

/// 从远端目录列表中挑出与视频同名的**最佳**字幕文件（无匹配返回 null）。
///
/// [videoName] 传视频文件名（含扩展名；为空时调用方用 [remoteFileNameOf] 从路径取）。
/// 只有文件（跳过目录）参与匹配；文件名、语言后缀优先级、扩展名优先级
/// 全部复用本地同名自动加载的规则（[findBestSubtitleFileName]）。
NetworkFile? findBestRemoteSubtitle(
  String videoName, {
  required List<NetworkFile> files,
  required String systemLanguage,
}) {
  final videoBase = _nameWithoutExt(videoName);
  if (videoBase.isEmpty) return null;
  final byName = <String, NetworkFile>{};
  for (final f in files) {
    if (f.isDirectory) continue;
    final name = f.name.isNotEmpty ? f.name : remoteFileNameOf(f.path);
    if (name.isEmpty) continue;
    byName.putIfAbsent(name, () => f);
  }
  if (byName.isEmpty) return null;
  final best = findBestSubtitleFileName(
    videoBase,
    byName.keys.toList(),
    systemLanguage: systemLanguage,
  );
  return best == null ? null : byName[best];
}

/// 取文件名主名（去最后一个 `.` 之后的部分）。
String _nameWithoutExt(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// 还原 `%XX`（其余字符原样保留）；解码结果不是合法 UTF-8 时返回原串。
String _percentDecode(String value) {
  if (!value.contains('%')) return value;
  final bytes = <int>[];
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c == '%' && i + 2 < value.length) {
      final byte = int.tryParse(value.substring(i + 1, i + 3), radix: 16);
      if (byte != null) {
        bytes.add(byte);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(c));
  }
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return value;
  }
}
