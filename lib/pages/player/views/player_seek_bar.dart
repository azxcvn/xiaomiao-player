import 'package:flutter/material.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/seek_bar_style.dart';
import 'package:moumou/pages/player/player_metrics.dart';
import 'package:moumou/pages/player/views/player_seek_bar_painter.dart';
import 'package:moumou/services/player_controls_settings.dart';

/// 全宽进度条（自定义绘制，替代 Material Slider）：
/// 拖动实时预览目标时间，松手/点击跳转。
///
/// 为什么不用 Slider（历史坑，勿改回）：
/// - Material Slider 的轨道默认内缩（thumb/overlay 半径，约 14px），
///   轨道起点无法与返回箭头/时间/下一集精确对齐到 [kPlayerLeftInset]；
/// - 拖动/点击判定受 Slider 内部 padding 与手势竞技场影响，体验不稳定。
///
/// 本实现直接绘制轨道与拇指，手势自管（点击轨道即跳转、拖动跟手），
/// 轨道起点精确落在 [kPlayerLeftInset]、右缘留 20 与底栏对齐。
///
/// 绘制具体长什么样由 [SeekBarStyle] 决定（经典 / 分段块 / 胶囊，见
/// `player_seek_bar_painter.dart`）：**手势与命中换算与样式无关**，
/// 换样式只换画的层，不换手感。
///
/// 触摸反馈（工作.md 第 1 点）：拇指被**触摸或拖动**时，在外面套一个
/// 比拇指大一圈的同心圆（低透明度），让用户感知已命中进度条
/// （轻微放大 + 外圈扩散效果）。
class PlayerSeekBar extends StatefulWidget {
  final double valueMs;
  final double maxMs;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// 章节列表（秒）：按样式画成圆点 / 块缝 / 竖刻度
  /// （工作.md 章节功能：未播放到=白色，播放过=主题色带透明度）
  final List<ChapterInfo> chapters;

  /// 可跳过片段（OP/ED/预告等）：非空时在轨道上绘制类型色时间段
  final List<SkipSegment> skipSegments;

  /// 组件整体高度（含可点击热区），轨道垂直居中。
  ///
  /// 默认 [barHeight]=40（竖屏用）；横屏底栏传更小的值让轨道贴近
  /// 下方控制行（高度差即轨道下移量，进度条上方元素随之外移跟随）。
  final double height;

  /// 轨道起点（相对组件左缘）。默认 [kPlayerLeftInset]（竖屏用）；
  /// 横屏底栏传入更小的值：轨道左端与「下一集」按钮图标左缘对齐。
  final double trackLeftInset;

  /// 样式覆盖：null = 跟随设置（播放器内用）；
  /// 设置页的预览会显式传一个样式。
  final SeekBarStyle? style;

  const PlayerSeekBar({
    super.key,
    required this.valueMs,
    required this.maxMs,
    required this.onChanged,
    required this.onChangeEnd,
    this.chapters = const [],
    this.skipSegments = const [],
    this.height = barHeight,
    this.trackLeftInset = kPlayerLeftInset,
    this.style,
  });

  /// 进度条默认高度（含可点击热区）
  static const double barHeight = 40;

  /// 右缘间距（与底栏按钮行右缘对齐）
  static const double rightInset = 20;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  /// 是否正处于「触摸 / 拖动」状态：为 true 时拇指外圈放大显示
  bool _interacting = false;

  void _setInteracting(bool v) {
    if (_interacting == v) return;
    setState(() => _interacting = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = widget.style ?? PlayerControlsSettings.instance.seekBarStyle;
    final valueMs = widget.valueMs;
    final maxMs = widget.maxMs;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackLeft = widget.trackLeftInset;
          final trackWidth = (constraints.maxWidth -
                  trackLeft -
                  PlayerSeekBar.rightInset)
              .clamp(0.0, double.infinity);

          void handleAt(double dx) {
            if (trackWidth <= 0 || maxMs <= 0) return;
            final f = ((dx - trackLeft) / trackWidth).clamp(0.0, 1.0);
            widget.onChanged(f * maxMs);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 点击轨道：预览（onChanged）→ 松手即跳转（onChangeEnd，用点击位置计算）
            onTapDown: (d) {
              _setInteracting(true);
              handleAt(d.localPosition.dx);
            },
            onTapUp: (d) {
              _setInteracting(false);
              if (trackWidth <= 0 || maxMs <= 0) return;
              final f = ((d.localPosition.dx - trackLeft) / trackWidth)
                  .clamp(0.0, 1.0);
              widget.onChangeEnd(f * maxMs);
            },
            onTapCancel: () => _setInteracting(false),
            // 拖动：实时预览，松手跳转（与原有 onChanged/onChangeEnd 契约一致）
            onHorizontalDragStart: (d) {
              _setInteracting(true);
              handleAt(d.localPosition.dx);
            },
            onHorizontalDragUpdate: (d) {
              _setInteracting(true);
              handleAt(d.localPosition.dx);
            },
            onHorizontalDragEnd: (_) {
              _setInteracting(false);
              widget.onChangeEnd(valueMs);
            },
            onHorizontalDragCancel: () {
              _setInteracting(false);
              widget.onChangeEnd(valueMs);
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, widget.height),
              painter: PlayerSeekBarPainter(
                style: style,
                valueMs: valueMs,
                durationMs: maxMs,
                chapters: widget.chapters,
                skipSegments: widget.skipSegments,
                trackLeft: trackLeft,
                trackWidth: trackWidth,
                scheme: scheme,
                interacting: _interacting,
              ),
            ),
          );
        },
      ),
    );
  }
}
