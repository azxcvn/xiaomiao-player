import 'dart:ui';

/// 跳过片段类型（OP/ED/前情提要/制作人员/正片前段/下集预告）。
///
/// 颜色方案对齐参考项目（小喵 player / mpvRx 的 SkipSegmentType）：
/// 每个类型一个专属色，用于进度条色段标记与跳过胶囊底色，
/// 颜色透明度在绘制/UI 层再调整（见 PlayerSeekBar / ChapterSkipChip）。
///
/// 胶囊文案在 `lib/l10n/label_maps.dart` 的 [chapterSkipTypeLabel]。
enum ChapterSkipType {
  intro(Color(0xFFFF7A00)),
  recap(Color(0xFF2F80FF)),
  outro(Color(0xFFE05666)),
  credits(Color(0xFFA64DFF)),
  coldOpen(Color(0xFFFFB300)),
  preview(Color(0xFF00D4C7));

  /// 类型专属色（进度条色段 / 胶囊底色）
  final Color color;

  const ChapterSkipType(this.color);
}

/// 单个章节（来自 mpv 的 chapter-list 子属性）。
class ChapterInfo {
  /// 章节标题（可能为空串）
  final String title;

  /// 章节起始时间（秒）
  final double startSeconds;

  const ChapterInfo({required this.title, required this.startSeconds});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterInfo &&
          other.title == title &&
          other.startSeconds == startSeconds;

  @override
  int get hashCode => Object.hash(title, startSeconds);
}

/// 可跳过片段（章节关键词检测派生的 OP/ED/预告等时间段）。
class SkipSegment {
  final ChapterSkipType type;

  /// 片段起始时间（秒）
  final double startSeconds;

  /// 片段结束时间（秒，= 下一章节起点或视频时长）
  final double endSeconds;

  const SkipSegment({
    required this.type,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// 有效片段：时长必须 > 1 秒（过短没有跳过意义）
  bool get isValid => endSeconds > startSeconds + 1.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkipSegment &&
          other.type == type &&
          other.startSeconds == startSeconds &&
          other.endSeconds == endSeconds;

  @override
  int get hashCode => Object.hash(type, startSeconds, endSeconds);
}
