import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/player_loop.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/player/views/audio_player_panels.dart';

import 'l10n_test_helper.dart';

VideoFile _v(int i) => VideoFile(path: '/videos/$i.mp4', name: '第$i集');

/// 听视频播放列表面板回归测试。
///
/// 重点：打开面板时要自动落到**正在播放的那一集**（用户反馈：20 集播到第 19 集，
/// 打开列表还停在第一集，得自己往下滑才能看见）。
///
/// ⚠️ 不用 `pumpAndSettle`：当前项挂着 [_EqualizerBars] 这类无限循环动画，
/// settle 永远等不到（ARCHITECTURE 里记过同类坑），一律用固定时长的 `pump`。
void main() {
  const currentIndex = 18; // 第 19 集（共 20 集）
  final videos = [for (var i = 1; i <= 20; i++) _v(i)];

  testWidgets('打开面板自动滚到正在播放的曲目', (tester) async {
    await _pumpHost(tester, videos: videos, currentIndex: currentIndex);

    // 面板首帧 + 滑入动画 + 精确居中动画，全部推进完
    await _openSheet(tester);

    final tile = find.widgetWithText(ListTile, '第19集');
    expect(tile, findsOneWidget, reason: '当前曲目必须被建出来（否则说明没滚到）');

    final listRect = tester.getRect(find.byType(ListView));
    final tileRect = tester.getRect(tile);
    expect(
      tileRect.top,
      greaterThanOrEqualTo(listRect.top - 0.5),
      reason: '当前曲目应完整落在列表可视区内（顶部）',
    );
    expect(
      tileRect.bottom,
      lessThanOrEqualTo(listRect.bottom + 0.5),
      reason: '当前曲目应完整落在列表可视区内（底部）',
    );

    // 第一集此时应该在视口外（说明确实滚下去了，不是碰巧可见）
    expect(find.text('第1集'), findsNothing);
  });

  testWidgets('长列表（300 集）也能落到位', (tester) async {
    // 估算行高的误差会随条目累计：300 集时初始偏移会偏出几十行，当前行
    // 一开始根本建不出来 → 走 [_revealCurrentTile] 的比例修正兜底
    final many = [for (var i = 1; i <= 300; i++) _v(i)];
    await _pumpHost(tester, videos: many, currentIndex: 250);
    await _openSheet(tester);

    final tile = find.widgetWithText(ListTile, '第251集');
    expect(tile, findsOneWidget, reason: '兜底修正后当前曲目必须被建出来');
    final listRect = tester.getRect(find.byType(ListView));
    final tileRect = tester.getRect(tile);
    expect(tileRect.top, greaterThanOrEqualTo(listRect.top - 0.5));
    expect(tileRect.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
  });

  testWidgets('点曲目：回传下标并关闭面板', (tester) async {
    final picked = <int>[];
    await _pumpHost(
      tester,
      videos: videos,
      currentIndex: 0,
      onSelect: picked.add,
    );
    await _openSheet(tester);

    await tester.tap(find.text('第2集'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked, [1]);
    expect(find.byType(ListView), findsNothing, reason: '面板应已关闭');
  });

  testWidgets('循环胶囊按「关闭 → 单曲 → 列表 → 关闭」回传', (tester) async {
    final modes = <LoopMode>[];
    await _pumpHost(
      tester,
      videos: videos,
      currentIndex: 0,
      onRepeatModeChanged: modes.add,
    );
    await _openSheet(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(_repeatLabel(modes.isEmpty
          ? LoopMode.off
          : modes.last)));
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(modes, [LoopMode.repeatOne, LoopMode.loopAll, LoopMode.off]);
  });
}

/// 循环胶囊当前文案（与面板 _repeatModeLabel 口径一致）
String _repeatLabel(LoopMode mode) => switch (mode) {
      LoopMode.off => '循环关闭',
      LoopMode.repeatOne => '单曲循环',
      LoopMode.loopAll => '列表循环',
    };

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('打开列表'));
  await tester.pump(); // 插入弹层
  await tester.pump(const Duration(milliseconds: 300)); // 滑入动画
  await tester.pump(const Duration(milliseconds: 200)); // 居中动画
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required List<VideoFile> videos,
  required int currentIndex,
  ValueChanged<int>? onSelect,
  ValueChanged<LoopMode>? onRepeatModeChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAudioPlaylistSheet(
                ctx,
                videos: videos,
                currentIndex: currentIndex,
                shuffle: false,
                repeatMode: LoopMode.off,
                onSelect: onSelect ?? (_) {},
                onToggleShuffle: () {},
                onRepeatModeChanged: onRepeatModeChanged ?? (_) {},
              ),
              child: const Text('打开列表'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
