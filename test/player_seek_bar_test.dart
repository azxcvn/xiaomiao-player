import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/seek_bar_style.dart';
import 'package:moumou/pages/player/views/player_seek_bar.dart';
import 'package:moumou/pages/player/views/player_seek_bar_painter.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 进度条三样式：绘制层能跑、手势换算与样式无关、退化规则不炸。
void main() {
  const width = 200.0;
  const maxMs = 200000.0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerControlsSettings.instance.reset();
  });

  const chapters = [
    ChapterInfo(title: 'A', startSeconds: 30),
    ChapterInfo(title: 'B', startSeconds: 90),
  ];
  const skips = [
    SkipSegment(
      type: ChapterSkipType.intro,
      startSeconds: 30,
      endSeconds: 60,
    ),
  ];

  Future<void> pumpBar(
    WidgetTester tester, {
    SeekBarStyle? style,
    List<ChapterInfo> chapterList = chapters,
    List<SkipSegment> skipList = skips,
    double duration = maxMs,
    double value = 50000,
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeEnd,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PlayerSeekBar(
                valueMs: value,
                maxMs: duration,
                onChanged: onChanged ?? (_) {},
                onChangeEnd: onChangeEnd ?? (_) {},
                chapters: chapterList,
                skipSegments: skipList,
                trackLeftInset: 0,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  PlayerSeekBarPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PlayerSeekBarPainter,
      ),
    );
    return paint.painter! as PlayerSeekBarPainter;
  }

  group('三种样式都能画', () {
    for (final style in SeekBarStyle.values) {
      testWidgets('$style：渲染无异常，painter 收到对应样式', (tester) async {
        await pumpBar(tester, style: style);
        expect(tester.takeException(), isNull);
        expect(painterOf(tester).style, style);
      });
    }

    testWidgets('无章节 + 分段块：整条一整块，不崩', (tester) async {
      await pumpBar(
        tester,
        style: SeekBarStyle.segmented,
        chapterList: const [],
        skipList: const [],
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('时长未知（0）：任何样式都退成细轨，不崩', (tester) async {
      for (final style in SeekBarStyle.values) {
        await pumpBar(tester, style: style, duration: 0, value: 0);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('章节挤在一起（块太窄）：不留缝也不崩', (tester) async {
      final dense = [
        for (var i = 1; i < 40; i++)
          ChapterInfo(title: '$i', startSeconds: i * 0.5),
      ];
      await pumpBar(
        tester,
        style: SeekBarStyle.segmented,
        chapterList: dense,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('手势换算与样式无关', () {
    testWidgets('点击中点：onChanged 落在一半时长', (tester) async {
      double? changed;
      await pumpBar(
        tester,
        style: SeekBarStyle.capsule,
        onChanged: (v) => changed = v,
      );
      // 轨道宽 = 200 - 右缘 20 = 180；点 x=90 → 50%
      final origin = tester.getTopLeft(find.byType(PlayerSeekBar));
      await tester.tapAt(origin + const Offset(90, 20));
      await tester.pump();
      expect(changed, closeTo(100000, 1));
    });

    testWidgets('拖动结束回调收到当前值（由调用方传入的预览值）', (tester) async {
      var ended = false;
      await pumpBar(
        tester,
        style: SeekBarStyle.segmented,
        onChangeEnd: (_) => ended = true,
      );
      await tester.drag(find.byType(PlayerSeekBar), const Offset(30, 0));
      await tester.pump();
      expect(ended, isTrue);
    });

    testWidgets('未播放（value=0）：不崩，painter 收到 0', (tester) async {
      await pumpBar(tester, style: SeekBarStyle.classic, value: 0);
      expect(painterOf(tester).valueMs, 0);
    });
  });

  testWidgets('不传 style 时跟随设置', (tester) async {
    await PlayerControlsSettings.instance
        .setSeekBarStyle(SeekBarStyle.capsule);
    await pumpBar(tester);
    expect(painterOf(tester).style, SeekBarStyle.capsule);
  });
}
