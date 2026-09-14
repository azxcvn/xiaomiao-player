/// 弹幕关键词屏蔽纯函数（架构 §4.11「屏蔽词」）：弹幕文本包含任一屏蔽词
/// 即被过滤（子串匹配，忽略大小写与首尾空白）。屏蔽词列表为空 = 不过滤。
///
/// **归一化前置（P1-16）**：屏蔽词表在**每次过滤前归一化一次**，而不是在
/// 「逐条弹幕 × 逐个关键词」的内层重复 `trim().toLowerCase()`——10 万条 ×
/// N 个词的内层分配是这条流水线在切换屏蔽词时的主要浪费。
///
/// 纯函数、无 Flutter 依赖，可单测。
library;

import 'package:moumou/models/danmaku_entry.dart';

/// 归一化屏蔽词表：去首尾空白 + 转小写 + 丢弃空词 + 去重（保序）。
///
/// 归一化结果可直接喂给 [matchesNormalizedKeyword] 复用，
/// 避免对同一条弹幕的每个关键词重复做同样的字符串处理。
List<String> normalizeBlockedKeywords(List<String> keywords) {
  final normalized = <String>[];
  for (final raw in keywords) {
    final k = raw.trim().toLowerCase();
    if (k.isEmpty || normalized.contains(k)) continue;
    normalized.add(k);
  }
  return normalized;
}

/// 文本是否命中**已归一化**的关键词表（忽略大小写与首尾空白，子串包含即命中）。
bool matchesNormalizedKeyword(String text, List<String> normalizedKeywords) {
  if (normalizedKeywords.isEmpty) return false;
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return false;
  for (final k in normalizedKeywords) {
    if (t.contains(k)) return true;
  }
  return false;
}

/// 判断 [text] 是否命中任一屏蔽词（忽略大小写与首尾空白，子串包含即命中）。
///
/// 单条判定入口（内部每次归一化一份关键词表）；批量过滤请用
/// [filterBlockedDanmaku]（关键词表只归一化一次）。
bool matchesBlockedKeyword(String text, List<String> keywords) =>
    matchesNormalizedKeyword(text, normalizeBlockedKeywords(keywords));

/// 从条目列表中剔除命中屏蔽词的条目（屏蔽词为空时原样返回原列表）。
List<DanmakuEntry> filterBlockedDanmaku(
  List<DanmakuEntry> entries,
  List<String> keywords,
) {
  if (keywords.isEmpty) return entries;
  final normalized = normalizeBlockedKeywords(keywords);
  if (normalized.isEmpty) return entries;
  return entries
      .where((e) => !matchesNormalizedKeyword(e.text, normalized))
      .toList();
}
