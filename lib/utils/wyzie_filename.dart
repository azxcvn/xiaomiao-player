/// Wyzie 字幕落盘文件名纯函数：去除路径非法字符 + 拼「媒体名.语言.格式」。
///
/// 现在落盘名走通用的 [subtitleEntryFileName]（来源无关），本文件保留
/// [wyzieSubtitleFileName] 作为 Wyzie 模型的便捷入口（内部转通用条目）。
library;

import 'package:moumou/models/subtitle_entry.dart';
import 'package:moumou/models/wyzie_models.dart';

final RegExp _illegalFileChars = RegExp(r'[\\/:*?"<>|]');

/// 去除文件路径非法字符（媒体名可能含 `/`、`:` 等，防止写盘失败）。
String sanitizeFileName(String name) {
  final trimmed = name.replaceAll(_illegalFileChars, '_').trim();
  if (trimmed.isEmpty) return '未命名';
  return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
}

/// 生成落盘文件名：`媒体名.语言.格式`（来源无关，Wyzie 与自定义源共用）。
///
/// 媒体名取条目 [SubtitleEntry.name]（Wyzie 侧已在转换时取 fileName /
/// release / media），为空时用 [fallbackTitle]（搜索关键词）；
/// 语言与格式缺失时分别回退 `unknown` / `txt`。
String subtitleEntryFileName(
  SubtitleEntry sub, {
  String fallbackTitle = '',
}) {
  final rawBase = sub.name;
  final base = sanitizeFileName(rawBase.isNotEmpty ? rawBase : fallbackTitle);
  final lang = sanitizeFileName(sub.language.isNotEmpty ? sub.language : 'unknown');
  final fmt = sanitizeFileName(sub.format.isNotEmpty ? sub.format : 'txt');
  return '$base.$lang.$fmt';
}

/// Wyzie 条目的落盘文件名（等价于 [subtitleEntryFileName] 的 Wyzie 入口）
String wyzieSubtitleFileName(WyzieSubtitle sub, {String fallbackTitle = ''}) =>
    subtitleEntryFileName(
      SubtitleEntry.fromWyzie(sub),
      fallbackTitle: fallbackTitle,
    );

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
