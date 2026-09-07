/// 弹幕关键词屏蔽纯函数（架构 §4.11「屏蔽词」）：弹幕文本包含任一屏蔽词
/// 即被过滤（子串匹配，忽略大小写与首尾空白）。屏蔽词列表为空 = 不过滤。
///
/// 纯函数、无 Flutter 依赖，可单测。
library;

import 'package:moumou/models/danmaku_entry.dart';

/// 判断 [text] 是否命中任一屏蔽词（忽略大小写与首尾空白，子串包含即命中）。
bool matchesBlockedKeyword(String text, List<String> keywords) {
  if (keywords.isEmpty) return false;
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return false;
  for (final raw in keywords) {
    final k = raw.trim().toLowerCase();
    if (k.isNotEmpty && t.contains(k)) return true;
  }
  return false;
}

/// 从条目列表中剔除命中屏蔽词的条目（屏蔽词为空时原样返回原列表）。
List<DanmakuEntry> filterBlockedDanmaku(
  List<DanmakuEntry> entries,
  List<String> keywords,
) {
  if (keywords.isEmpty) return entries;
  return entries.where((e) => !matchesBlockedKeyword(e.text, keywords)).toList();
}
