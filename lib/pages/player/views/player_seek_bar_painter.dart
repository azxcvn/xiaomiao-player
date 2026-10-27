import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/seek_bar_style.dart';

/// 播放器进度条的绘制层（三种样式）。
///
/// 手势与「点击位置 → 时间」的换算留在 `PlayerSeekBar` 里，本类只认几何：
/// [trackLeft] / [trackWidth] 由调用方算好（轨道两端要与按钮对齐，见
/// `player_metrics.dart`），这里只按 [style] 决定轨道高度、拇指形状与色标画法。
///
/// 三种样式各自的色标画法（**绑死，不做独立组合**）：
/// - [SeekBarStyle.classic]：2.5dp 细轨、12dp 实心圆拇指、章节 6dp 圆点、
///   跳段色带画在轨道内（原有样式，尺寸与位置与改造前一致）；
/// - [SeekBarStyle.segmented]：9dp 块状轨，按章节切块、块间留 3dp 缝，
///   播放进度与跳段色在同一块内按比例填；没有章节就是**一整块**（不凭空等分，
///   章节在这儿是真能点的，假分段会骗人）；
/// - [SeekBarStyle.capsule]：11dp 圆角粗轨，已播用主题色渐变、跳段整轨染色、
///   章节改竖刻度、拇指白心带主题色描边。
///
/// 退化规则：时长未知（直播 / 未探测）时**一律按经典细轨画**且不填色——
/// 没有「进度」语义时，粗轨和分段只会显得莫名其妙。
class PlayerSeekBarPainter extends CustomPainter {
  PlayerSeekBarPainter({
    required this.style,
    required this.valueMs,
    required this.durationMs,
    required this.chapters,
    required this.skipSegments,
    required this.trackLeft,
    required this.trackWidth,
    required this.scheme,
    required this.interacting,
  });

  final SeekBarStyle style;

  /// 当前位置（毫秒）
  final double valueMs;

  /// 总时长（毫秒）；< = 0 表示未知
  final double durationMs;

  final List<ChapterInfo> chapters;
  final List<SkipSegment> skipSegments;

  /// 轨道左端 x（相对组件左缘）
  final double trackLeft;

  /// 轨道宽度（已扣掉左右 inset）
  final double trackWidth;

  final ColorScheme scheme;

  /// 是否正处于触摸 / 拖动（拇指外圈放大淡入）
  final bool interacting;

  // ── 各样式几何 ──────────────────────────────────────────
  static const double _classicHeight = 2.5;
  static const double _segmentedHeight = 9;
  static const double _segmentedGap = 3;
  static const double _segmentedRadius = 3;
  static const double _capsuleHeight = 11;

  /// 分段块的最小可画宽度（dp）：再窄就不留缝，否则一屏几十章会碎成马赛克
  static const double _minBlockWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (trackWidth <= 0 || size.height <= 0) return;
    final cy = size.height / 2;
    final left = trackLeft;
    final right = trackLeft + trackWidth;
    final fraction = _fraction;

    if (durationMs <= 0) {
      _paintTrackOnly(canvas, cy, left, right);
      return;
    }
    switch (style) {
      case SeekBarStyle.classic:
        _paintClassic(canvas, cy, left, right, fraction);
      case SeekBarStyle.segmented:
        _paintSegmented(canvas, cy, left, right, fraction);
      case SeekBarStyle.capsule:
        _paintCapsule(canvas, cy, left, right, fraction);
    }
  }

  double get _fraction =>
      durationMs > 0 ? (valueMs / durationMs).clamp(0.0, 1.0) : 0.0;

  /// 时间（毫秒）→ 轨道 x
  double _xFor(double ms) =>
      trackLeft + trackWidth * (ms / durationMs).clamp(0.0, 1.0);

  /// 落在时长范围内、且起点 > 0 的章节（0 点不画标记）
  List<ChapterInfo> get _chaptersInRange {
    final result = <ChapterInfo>[];
    for (final c in chapters) {
      final ms = c.startSeconds * 1000;
      if (!ms.isFinite || ms <= 0 || ms >= durationMs) continue;
      result.add(c);
    }
    return result;
  }

  /// 落在时长范围内、且长度 > 0 的跳段
  List<SkipSegment> get _segmentsInRange {
    final result = <SkipSegment>[];
    for (final s in skipSegments) {
      final from = s.startSeconds * 1000;
      final to = s.endSeconds * 1000;
      if (!from.isFinite || !to.isFinite) continue;
      if (to <= 0 || from >= durationMs || to - from <= 0) continue;
      result.add(s);
    }
    return result;
  }

  // ── 时长未知：只画一根细轨 ──────────────────────────────
  void _paintTrackOnly(Canvas canvas, double cy, double left, double right) {
    final h = _classicHeight;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        cy - h / 2,
        right,
        cy + h / 2,
        const Radius.circular(_classicHeight / 2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
  }

  // ── 经典（原有样式，尺寸与本文件改造前逐项一致）────────
  void _paintClassic(
    Canvas canvas,
    double cy,
    double left,
    double right,
    double fraction,
  ) {
    final h = _classicHeight;
    final radius = Radius.circular(h / 2);
    final track = RRect.fromLTRBR(left, cy - h / 2, right, cy + h / 2, radius);
    canvas.drawRRect(track, Paint()..color = Colors.white.withValues(alpha: 0.30));

    // 跳段色带：与轨道同高，裁在轨道圆角内（未播放区域露出类型色）
    canvas.save();
    canvas.clipRRect(track);
    for (final seg in _segmentsInRange) {
      final x0 = _xFor(seg.startSeconds * 1000);
      final x1 = _xFor(seg.endSeconds * 1000);
      if (x1 - x0 <= 0) continue;
      canvas.drawRect(
        Rect.fromLTRB(x0, cy - h / 2, x1, cy + h / 2),
        Paint()..color = seg.type.color.withValues(alpha: 0.65),
      );
    }
    canvas.restore();

    // 已播放：主题色（画在色带之上，与改造前一致）
    final px = left + trackWidth * fraction;
    if (px > left) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, cy - h / 2, px, cy + h / 2, radius),
        Paint()..color = scheme.primary,
      );
    }

    _paintChapterDots(canvas, cy, fraction);
    _paintClassicThumb(canvas, cy, px);
  }

  void _paintChapterDots(Canvas canvas, double cy, double fraction) {
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.32);
    for (final chapter in _chaptersInRange) {
      final x = _xFor(chapter.startSeconds * 1000);
      final played = fraction >= chapter.startSeconds * 1000 / durationMs;
      fill.color = played
          ? scheme.primary.withValues(alpha: 0.75)
          : Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(x, cy), 3, fill);
      canvas.drawCircle(Offset(x, cy), 3, stroke);
    }
  }

  void _paintClassicThumb(Canvas canvas, double cy, double px) {
    if (interacting) {
      canvas.drawCircle(
        Offset(px, cy),
        16,
        Paint()..color = scheme.primary.withValues(alpha: 0.28),
      );
    }
    canvas.drawCircle(
      Offset(px, cy + 1),
      6,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(Offset(px, cy), 6, Paint()..color = scheme.primary);
  }

  // ── 分段块 ──────────────────────────────────────────────
  void _paintSegmented(
    Canvas canvas,
    double cy,
    double left,
    double right,
    double fraction,
  ) {
    final h = _segmentedHeight;
    final blocks = _buildBlocks();
    // 有章节才留缝；块太窄时也不留（否则碎成一排点）
    final widestGap = blocks.length > 1 &&
            blocks.every((b) => trackWidth * (b.widthMs / durationMs) >=
                _minBlockWidth)
        ? _segmentedGap
        : 0.0;
    final base = Paint()..color = Colors.white.withValues(alpha: 0.16);
    final playedPaint = Paint()..color = scheme.primary;
    final px = left + trackWidth * fraction;

    for (final block in blocks) {
      final x0 = _xFor(block.startMs);
      final x1 = _xFor(block.endMs);
      final drawRight = math.max(x0 + 1, x1 - widestGap);
      final rect = RRect.fromLTRBR(
        x0,
        cy - h / 2,
        drawRight,
        cy + h / 2,
        const Radius.circular(_segmentedRadius),
      );
      canvas.drawRRect(rect, base);

      canvas.save();
      canvas.clipRRect(rect);
      // 跳段：只填「块 ∩ 跳段」那一段（跳段不一定正好卡在章节边界上）
      for (final seg in _segmentsInRange) {
        final from = math.max(seg.startSeconds * 1000, block.startMs);
        final to = math.min(seg.endSeconds * 1000, block.endMs);
        if (to <= from) continue;
        canvas.drawRect(
          Rect.fromLTRB(_xFor(from), cy - h / 2, _xFor(to), cy + h / 2),
          Paint()..color = seg.type.color.withValues(alpha: 0.60),
        );
      }
      // 已播放：块内按比例填，压在色带之上
      if (px > x0) {
        canvas.drawRect(
          Rect.fromLTRB(x0, cy - h / 2, math.min(px, drawRight), cy + h / 2),
          playedPaint,
        );
      }
      canvas.restore();
    }

    // 拇指：圆角方块（与块状轨道同一套语言）
    if (interacting) {
      canvas.drawCircle(
        Offset(px, cy),
        14,
        Paint()..color = scheme.primary.withValues(alpha: 0.24),
      );
    }
    final thumb = RRect.fromLTRBR(
      px - 5,
      cy - 7,
      px + 5,
      cy + 7,
      const Radius.circular(4),
    );
    canvas.drawRRect(
      thumb.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(thumb, Paint()..color = Colors.white);
    canvas.drawRRect(
      thumb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = scheme.primary,
    );
  }

  /// 按章节边界切块；没有章节（或只有 0 点那一章）时整条就是一整块
  List<_SegmentBlock> _buildBlocks() {
    final starts = <double>{0};
    for (final chapter in _chaptersInRange) {
      starts.add(chapter.startSeconds * 1000);
    }
    final sorted = starts.toList()..sort();
    final blocks = <_SegmentBlock>[];
    for (var i = 0; i < sorted.length; i++) {
      final start = sorted[i];
      final end = i + 1 < sorted.length ? sorted[i + 1] : durationMs;
      if (end <= start) continue;
      blocks.add(_SegmentBlock(start, end));
    }
    return blocks;
  }

  // ── 胶囊 ────────────────────────────────────────────────
  void _paintCapsule(
    Canvas canvas,
    double cy,
    double left,
    double right,
    double fraction,
  ) {
    final h = _capsuleHeight;
    final radius = Radius.circular(h / 2);
    final track = RRect.fromLTRBR(left, cy - h / 2, right, cy + h / 2, radius);
    canvas.drawRRect(track, Paint()..color = Colors.white.withValues(alpha: 0.20));

    canvas.save();
    canvas.clipRRect(track);

    // 跳段：整轨染色（不透明度压低，避免盖住主进度色）
    for (final seg in _segmentsInRange) {
      final x0 = _xFor(seg.startSeconds * 1000);
      final x1 = _xFor(seg.endSeconds * 1000);
      if (x1 - x0 <= 0) continue;
      canvas.drawRect(
        Rect.fromLTRB(x0, cy - h / 2, x1, cy + h / 2),
        Paint()..color = seg.type.color.withValues(alpha: 0.72),
      );
    }

    // 已播：主题色 → 亮一点的同色（渐变），有「充能」感
    final px = left + trackWidth * fraction;
    if (px > left) {
      final shader = LinearGradient(
        colors: [
          scheme.primary,
          Color.lerp(scheme.primary, Colors.white, 0.35) ?? scheme.primary,
        ],
      ).createShader(
        Rect.fromLTRB(left, cy - h / 2, math.max(px, left + 1), cy + h / 2),
      );
      canvas.drawRect(
        Rect.fromLTRB(left, cy - h / 2, px, cy + h / 2),
        Paint()..shader = shader,
      );
    }

    // 章节：竖刻度（跨满轨道高度），已播放的调暗一档
    final tick = Paint();
    for (final chapter in _chaptersInRange) {
      final x = _xFor(chapter.startSeconds * 1000);
      final played = fraction >= chapter.startSeconds * 1000 / durationMs;
      tick.color = Colors.white.withValues(alpha: played ? 0.60 : 0.85);
      canvas.drawRect(Rect.fromLTRB(x - 1, cy - h / 2, x + 1, cy + h / 2), tick);
    }
    canvas.restore();

    // 拇指：白心 + 主题色描边
    if (interacting) {
      canvas.drawCircle(
        Offset(px, cy),
        17,
        Paint()..color = scheme.primary.withValues(alpha: 0.26),
      );
    }
    canvas.drawCircle(
      Offset(px, cy + 1),
      8,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(Offset(px, cy), 8, Paint()..color = scheme.primary);
    canvas.drawCircle(Offset(px, cy), 4.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant PlayerSeekBarPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.valueMs != valueMs ||
      oldDelegate.durationMs != durationMs ||
      oldDelegate.trackLeft != trackLeft ||
      oldDelegate.trackWidth != trackWidth ||
      oldDelegate.interacting != interacting ||
      oldDelegate.scheme != scheme ||
      !listEquals(oldDelegate.chapters, chapters) ||
      !listEquals(oldDelegate.skipSegments, skipSegments);
}

/// 分段块：一个章节区间（毫秒）
class _SegmentBlock {
  const _SegmentBlock(this.startMs, this.endMs);

  final double startMs;
  final double endMs;

  double get widthMs => endMs - startMs;
}
