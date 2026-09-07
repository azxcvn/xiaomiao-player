/// Wyzie 字幕落盘文件名纯函数：去除路径非法字符 + 拼「媒体名.语言.格式」。
library;

import 'package:moumou/models/wyzie_models.dart';

final RegExp _illegalFileChars = RegExp(r'[\\/:*?"<>|]');

/// 去除文件路径非法字符（媒体名可能含 `/`、`:` 等，防止写盘失败）。
String sanitizeFileName(String name) {
  final trimmed = name.replaceAll(_illegalFileChars, '_').trim();
  if (trimmed.isEmpty) return '未命名';
  return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
}

/// 生成落盘文件名：`媒体名.语言.格式`。
///
/// 媒体名优先取 fileName / release / media，均为空时用 [fallbackTitle]
/// （搜索关键词）；语言与格式缺失时分别回退 `unknown` / `txt`。
String wyzieSubtitleFileName(WyzieSubtitle sub, {String fallbackTitle = ''}) {
  final rawBase = sub.fileName.isNotEmpty
      ? sub.fileName
      : (sub.release.isNotEmpty ? sub.release : sub.media);
  final base = sanitizeFileName(rawBase.isNotEmpty ? rawBase : fallbackTitle);
  final lang = sanitizeFileName(sub.language.isNotEmpty ? sub.language : 'unknown');
  final fmt = sanitizeFileName(sub.format.isNotEmpty ? sub.format : 'txt');
  return '$base.$lang.$fmt';
}

/// 在同批次落盘中消重：若 [base] 已被 [used] 占用，则在扩展名前插入
/// ` (n)` 递增序号（如 `Movie.en.srt` → `Movie.en (1).srt`）。
String uniqueFileName(String base, Set<String> used) {
  if (!used.contains(base)) return base;
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  final ext = dot > 0 ? base.substring(dot) : '';
  var n = 1;
  var candidate = '$stem ($n)$ext';
  while (used.contains(candidate)) {
    n++;
    candidate = '$stem ($n)$ext';
  }
  return candidate;
}
