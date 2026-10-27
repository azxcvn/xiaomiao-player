import 'package:flutter/material.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/seek_bar_style.dart';
import 'package:moumou/pages/player/views/player_seek_bar_painter.dart';

/// 设置页里的进度条样式预览条（黑底，模拟播放器底栏）。
///
/// 复用播放器真正的 [PlayerSeekBarPainter]（不是另画一套示意图）：设置页看到的
/// 就是进播放页看到的样子，改绘制层不会出现「预览和实际不一致」。数据是固定
/// 的假数据（24:00、已播 4:00、8 章、OP/ED 各一段），只为把两种色标都露出来。
class SeekBarStylePreview extends StatelessWidget {
  const SeekBarStylePreview({super.key, required this.style, this.height = 52});

  final SeekBarStyle style;
  final double height;

  static const double _durationMs = 1440 * 1000;
  static const double _valueMs = 240 * 1000;
  static const double _sideInset = 16;

  static const List<ChapterInfo> _chapters = [
    ChapterInfo(title: '', startSeconds: 0),
    ChapterInfo(title: '', startSeconds: 60),
    ChapterInfo(title: '', startSeconds: 120),
    ChapterInfo(title: '', startSeconds: 420),
    ChapterInfo(title: '', startSeconds: 510),
    ChapterInfo(title: '', startSeconds: 900),
    ChapterInfo(title: '', startSeconds: 1080),
    ChapterInfo(title: '', startSeconds: 1290),
  ];

  static const List<SkipSegment> _skips = [
    SkipSegment(
      type: ChapterSkipType.intro,
      startSeconds: 420,
      endSeconds: 510,
    ),
    SkipSegment(
      type: ChapterSkipType.outro,
      startSeconds: 1290,
      endSeconds: 1440,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        // 预览条固定深色：播放器底栏就是黑底，跟应用主题无关
        color: const Color(0xFF10131A),
        borderRadius: BorderRadius.circular(12),
        // 当「一块屏幕」而不是「一块色块」：极细的亮边勾边 + 一点投影，
        // 放在浅色设置卡片里就有画面感，也不至于像贴了块黑洞
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = (constraints.maxWidth - _sideInset * 2)
              .clamp(0.0, double.infinity);
          return CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: PlayerSeekBarPainter(
              style: style,
              valueMs: _valueMs,
              durationMs: _durationMs,
              chapters: _chapters,
              skipSegments: _skips,
              trackLeft: _sideInset,
              trackWidth: trackWidth,
              scheme: scheme,
              interacting: false,
            ),
          );
        },
      ),
    );
  }
}
