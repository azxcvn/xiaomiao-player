import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/widgets/marquee_text.dart';

/// 跑马灯速度测试（用户反馈：想看文件名关键点时字很快就划走了）：
/// 一轮循环时长按**固定速度**换算（不再固定 4s），且开头先停留一会儿。
void main() {
  group('marqueeLoopDuration（一轮时长 = 起步停留 + 距离 / 速度）', () {
    test('无溢出只有起步停留', () {
      expect(marqueeLoopDuration(0), kMarqueeStartHold);
      expect(marqueeLoopDuration(-10), kMarqueeStartHold);
    });

    test('时长与滚动距离成正比（速度恒定）', () {
      // 显式给速度：秒数 = 距离 / 速度
      expect(
        marqueeLoopDuration(400, pixelsPerSecond: 40),
        kMarqueeStartHold + const Duration(seconds: 10),
      );
      expect(
        marqueeLoopDuration(800, pixelsPerSecond: 40),
        kMarqueeStartHold + const Duration(seconds: 20),
      );
      // 默认速度即常量本身（长标题只是滚得久，不会变快）
      expect(
        marqueeLoopDuration(400) - kMarqueeStartHold,
        Duration(
          milliseconds: (400 / kMarqueePixelsPerSecond * 1000).round(),
        ),
      );
    });

    test('比旧实现（一轮恒 4s）慢：最窄的跑马灯也不会更快', () {
      // 旧实现溢出即固定 4s：可视宽 100px 时等效速度 = (100 + 间隔 48) / 4
      const oldFastestEquivalent = (100 + 48) / 4;
      expect(kMarqueePixelsPerSecond, lessThan(oldFastestEquivalent));
    });
  });

  testWidgets('先停留起步时长，随后按恒定像素速度滚动', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              child: MarqueeText(
                text: '很长很长的视频文件名' * 5,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
    // 跑马灯是无限循环动画，只能定帧 pump（pumpAndSettle 会一直等下去）
    final controller = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;

    // 1s < 起步停留 1.2s：这一帧必须还在起点
    await tester.pump(const Duration(milliseconds: 1000));
    expect(controller.offset, 0, reason: '起步停留期间不应滚动');

    // 进入滚动段后再取两次采样，差值 = 1s × 速度
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 1000));
    final first = controller.offset;
    expect(first, greaterThan(0), reason: '起步停留结束后应开始滚动');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      controller.offset - first,
      closeTo(kMarqueePixelsPerSecond, 1),
      reason: '滚动速度应恒定在 kMarqueePixelsPerSecond',
    );
  });
}
