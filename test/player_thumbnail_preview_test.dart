import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_thumbnail_preview.dart';

/// 缩略图预览气泡的章节胶囊回归测试。
///
/// 对齐 mpvRx：拖动进度条时，预览图**上方**显示当前时间点所属的章节名胶囊，
/// 下方是时间胶囊。章节名由页面用 `ChapterTracker.chapterTitleAt(拖动位置)`
/// 注入（纯函数算法见 `utils/chapter_utils.dart` 与 `chapter_utils_test.dart`）。
///
/// 这里只验证「气泡在有/无章节名时的渲染行为」，不涉及抓帧（frame 传 null
/// 走加载占位）。
void main() {
  Widget wrap({
    String? chapterTitle,
    bool visible = true,
    Duration time = const Duration(seconds: 100),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: PlayerThumbnailPreview(
            frame: null,
            time: time,
            fraction: 0.5,
            visible: visible,
            chapterTitle: chapterTitle,
          ),
        ),
      ),
    );
  }

  testWidgets('有章节名：显示章节胶囊 + 时间胶囊共两个胶囊', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: '正片'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('正片'), findsOneWidget);
    expect(find.text('01:40'), findsOneWidget); // 100s
  });

  testWidgets('章节名为 null：只显示时间胶囊', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: null));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('01:40'), findsOneWidget);
    // 除时间外不应再有别的文本
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('章节名为空白：不显示空胶囊', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: '   '));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(Text), findsOneWidget); // 只有时间
    expect(find.text('   '), findsNothing);
  });

  testWidgets('章节名两端空白被去掉后显示', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: '  片尾  '));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('片尾'), findsOneWidget);
  });

  testWidgets('超长章节名单行省略，不撑破气泡宽度', (tester) async {
    const long = '这是一个非常非常非常非常非常非常长的章节标题';
    final repeated = long * 3;
    await tester.pumpWidget(wrap(chapterTitle: repeated));
    await tester.pump(const Duration(milliseconds: 200));

    // 气泡里的文本是 trim 后的原串（同一字符串）
    final finder = find.text(repeated);
    expect(finder, findsOneWidget);
    final text = tester.widget<Text>(finder);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    // 胶囊宽度受预览图宽度（160）约束
    expect(tester.getSize(finder).width, lessThanOrEqualTo(160.0));
  });

  testWidgets('章节胶囊在预览图上方、时间胶囊在下方（顺序）', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: '正片'));
    await tester.pump(const Duration(milliseconds: 200));

    final chapterY = tester.getCenter(find.text('正片')).dy;
    final timeY = tester.getCenter(find.text('01:40')).dy;
    expect(chapterY, lessThan(timeY));
  });

  testWidgets('不可见时（松手淡出后）整体透明', (tester) async {
    await tester.pumpWidget(wrap(chapterTitle: '正片', visible: false));
    await tester.pump(const Duration(milliseconds: 200));

    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0.0);
  });
}
