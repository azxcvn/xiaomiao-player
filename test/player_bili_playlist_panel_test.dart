import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/pages/player/views/player_bili_playlist_panel.dart';

/// B 站番剧播放列表面板测试：
/// - 头部显示「第 X 集 / 共 N 集」与番剧名；
/// - 条目渲染集号 + 集名 + 角标；当前集高亮「播放中」；
/// - 点击条目回调并关闭面板；空列表显示空态。
void main() {
  BiliEpisode ep(int epId, {String longTitle = '', String badge = ''}) =>
      BiliEpisode(
        epId: epId,
        aid: epId,
        cid: epId * 100,
        bvid: '',
        title: '第$epId话',
        longTitle: longTitle,
        cover: '',
        badge: badge,
      );

  BiliPlaylist playlist(List<BiliEpisode> episodes, {String title = '测试番剧'}) =>
      BiliPlaylist.fromEpisodes(episodes, seasonTitle: title);

  Future<void> pumpPanel(
    WidgetTester tester, {
    required BiliPlaylist pl,
    required int currentIndex,
    ValueChanged<BiliPlaylistItem>? onSelect,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: PlayerBiliPlaylistPanel(
          playlist: pl,
          currentIndex: currentIndex,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('头部显示番剧名与集数进度', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2), ep(3)]),
      currentIndex: 1,
    );
    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('第 2 集 / 共 3 集'), findsOneWidget);
  });

  testWidgets('未定位当前集时头部显示「共 N 集」', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2)]),
      currentIndex: -1,
    );
    expect(find.text('共 2 集'), findsOneWidget);
    expect(find.text('播放中'), findsNothing);
  });

  testWidgets('条目渲染集号/集名/角标，当前集高亮播放中', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist([
        ep(1, longTitle: '第1话 你即将死去'),
        ep(2, badge: '会员'),
        ep(3, badge: '预告'),
      ]),
      currentIndex: 1,
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('第1话 你即将死去'), findsOneWidget);
    expect(find.text('第2话'), findsOneWidget);
    // 角标映射：会员 → VIP、预告 → 预告
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('预告'), findsOneWidget);
    // 只有当前集显示「播放中」
    expect(find.text('播放中'), findsOneWidget);
  });

  testWidgets('点击条目回调并关闭面板', (tester) async {
    BiliPlaylistItem? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    body: PlayerBiliPlaylistPanel(
                      playlist: playlist([ep(1), ep(2)]),
                      currentIndex: 0,
                      onSelect: (item) => tapped = item,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第2话'));
    await tester.pumpAndSettle();
    expect(tapped?.epId, 2);
    // 面板已关闭
    expect(find.text('第2话'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('空剧集列表显示空态', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist(const []),
      currentIndex: -1,
    );
    expect(find.text('没有获取到剧集列表'), findsOneWidget);
  });
}
