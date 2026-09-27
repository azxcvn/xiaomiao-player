import 'package:flutter/material.dart';

/// 跑马灯滚动速度（逻辑像素 / 秒）。
///
/// 旧实现把一轮循环写死成 4 秒，**滚动速度随文本长度变化**：文本越长越快
/// （400px 的长标题 ≈ 112 像素/秒），关键点根本来不及看（用户反馈）。
/// 现在按恒定速度换算时长：30 像素/秒 ≈ 中文 2 字/秒，比旧实现任何一档都慢，
/// 长标题也只是滚得久一点、不会变快。
const double kMarqueePixelsPerSecond = 30;

/// 每轮循环开头在起点停留的时长：先让人看清标题开头，再开始滚动。
const Duration kMarqueeStartHold = Duration(milliseconds: 1200);

/// 跑马灯一轮循环的时长（纯函数，可单测）= 起步停留 + 滚动距离 / 速度。
///
/// [scrollRange] = 一份文本宽 + 间隔（一次完整循环要滚过的距离）；
/// 无溢出（≤ 0）或速度非法时退化为只有起步停留。
Duration marqueeLoopDuration(
  double scrollRange, {
  double pixelsPerSecond = kMarqueePixelsPerSecond,
  Duration startHold = kMarqueeStartHold,
}) {
  if (scrollRange <= 0 || pixelsPerSecond <= 0) return startHold;
  return startHold +
      Duration(
        milliseconds: (scrollRange / pixelsPerSecond * 1000).round(),
      );
}

/// 跑马灯文本：文本超出一行时，自动从左到右无缝循环滚动显示完整内容。
///
/// 实现方式：溢出时渲染两份文本（中间留固定间隔），滚动总距离 = 一份文本宽
/// + 间隔。动画循环到终点跳回起点时，第二份文本正好接在第一份末尾，
/// 视觉上形成头尾相接的无缝循环。
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  /// 两份文本之间的间隔（无缝衔接的最小间隙）
  final double gap;

  /// 滚动速度（逻辑像素 / 秒）；默认 [kMarqueePixelsPerSecond]。
  ///
  /// 需要更慢的场景（例如文件选择器的**路径行**：名字长、又是标识性文本）
  /// 可单独调慢，不影响其它跑马灯。
  final double pixelsPerSecond;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 48,
    this.pixelsPerSecond = kMarqueePixelsPerSecond,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animation;
  double _scrollRange = 0; // 一份文本宽 + 间隔（一次完整循环的滚动距离）
  bool _overflow = false;

  /// 起步停留在整轮循环里占的比例（由 [marqueeLoopDuration] 推出）
  double _holdFraction = 0;

  /// 当前 [AnimationController.repeat] 实际生效的一轮时长（null = 未在循环）。
  ///
  /// 单独记一份是因为 `repeat()` 的周期在**调用那一刻**就固定了，之后再改
  /// `_animation.duration` 对已在跑的循环无效——文本宽度变化必须据此重启。
  Duration? _appliedLoop;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animation = AnimationController(vsync: this, duration: kMarqueeStartHold)
      ..addListener(() {
        if (_scrollController.hasClients && _overflow) {
          _scrollController.jumpTo(_scrollRange * _eased(_animation.value));
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animation.dispose();
    super.dispose();
  }

  /// 把线性进度映射成「先停在起点、再匀速滚完」：
  /// 前 [_holdFraction] 段不动，剩下的段线性走完整个滚动距离。
  double _eased(double t) {
    final hold = _holdFraction;
    if (hold <= 0) return t;
    if (t <= hold) return 0;
    return (t - hold) / (1 - hold);
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      // 文本变化：回到起点，由 build 中的溢出判断决定是否重新循环
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final textWidth = painter.width;
        _overflow = textWidth > constraints.maxWidth;
        _scrollRange = _overflow ? textWidth + widget.gap : 0;
        // 按恒定速度换算本轮时长（跟文本长度无关），让长标题也看得清
        final loop = marqueeLoopDuration(
          _scrollRange,
          pixelsPerSecond: widget.pixelsPerSecond,
        );
        _holdFraction = loop.inMicroseconds <= 0
            ? 0
            : (kMarqueeStartHold.inMicroseconds / loop.inMicroseconds).clamp(
                0.0,
                1.0,
              );

        if (_overflow) {
          // 一轮时长随文本宽度变化，而 [AnimationController.repeat] 的周期取自
          // **调用时**的 duration：时长变了必须重新 repeat 一次才会生效
          //（[_appliedLoop] 记的就是当前 repeat 生效的那个时长；repeat 会从当前
          // 进度接着走，不会跳帧）
          if (_appliedLoop != loop) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _overflow && _appliedLoop != loop) {
                _appliedLoop = loop;
                _animation.duration = loop;
                _animation.repeat();
              }
            });
          }
        } else if (_animation.isAnimating) {
          _appliedLoop = null;
          _animation.stop();
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.text, style: widget.style, maxLines: 1),
              // 溢出时追加间隔与第二份文本，实现无缝衔接
              if (_overflow) ...[
                SizedBox(width: widget.gap),
                Text(widget.text, style: widget.style, maxLines: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}
