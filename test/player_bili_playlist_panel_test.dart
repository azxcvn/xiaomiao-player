import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/pages/player/views/player_bili_playlist_panel.dart';
import 'package:moumou/widgets/player_option_chip.dart';

import 'l10n_test_helper.dart';

/// B 站番剧播放列表面板测试：
/// - 头部显示「第 X 集 / 共 N 集」与番剧名（当前集用集号，不是排序后的位置）；
/// - 条目渲染集号 + 集名 + 角标；当前集高亮「播放中」；
/// - 顶部三枚排序胶囊：名称升序 / 名称降序 / 番剧顺序（默认选中）；
///   换排序回调播放页，并就地重排列表；
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
    int? currentEpId,
    BiliPlaylistSort sort = BiliPlaylistSort.season,
    ValueChanged<BiliPlaylistSort>? onSortChanged,
    ValueChanged<BiliPlaylistItem>? onSelect,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: PlayerBiliPlaylistPanel(
          playlist: pl,
          currentEpId: currentEpId,
          sort: sort,
          onSortChanged: onSortChanged ?? (_) {},
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
      currentEpId: 2,
    );
    expect(find.text('测试番剧'), findsOneWidget);
    expect(find.text('第 2 集 / 共 3 集'), findsOneWidget);
  });

  testWidgets('未定位当前集时头部显示「共 N 集」', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2)]),
      currentEpId: null,
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
      currentEpId: 2,
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
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
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
                      currentEpId: 1,
                      sort: BiliPlaylistSort.season,
                      onSortChanged: (_) {},
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
      currentEpId: null,
    );
    expect(find.text('没有获取到剧集列表'), findsOneWidget);
  });

  testWidgets('默认选中「番剧顺序」，三枚排序胶囊都在', (tester) async {
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2), ep(3)]),
      currentEpId: 2,
    );
    expect(find.text('名称升序'), findsOneWidget);
    expect(find.text('名称降序'), findsOneWidget);
    expect(find.text('番剧顺序'), findsOneWidget);
    expect(_chip(tester, '番剧顺序').selected, isTrue);
    expect(_chip(tester, '名称升序').selected, isFalse);
    expect(_chip(tester, '名称降序').selected, isFalse);
  });

  testWidgets('切名称降序：列表倒序、回报排序、当前集号不变', (tester) async {
    final changed = <BiliPlaylistSort>[];
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2), ep(3)]),
      currentEpId: 2,
      onSortChanged: changed.add,
    );

    await tester.tap(find.text('名称降序'));
    await tester.pumpAndSettle();

    expect(changed, [BiliPlaylistSort.nameDesc]);
    expect(_chip(tester, '名称降序').selected, isTrue);
    expect(_orderedTexts(tester, ['第1话', '第2话', '第3话']),
        ['第3话', '第2话', '第1话']);
    // 头部仍是当前集的集号（第 2 集），不是排序后的位置
    expect(find.text('第 2 集 / 共 3 集'), findsOneWidget);
    // 当前集高亮跟着 epId 走
    expect(find.text('播放中'), findsOneWidget);
  });

  testWidgets('切回番剧顺序：列表恢复、再次回报', (tester) async {
    final changed = <BiliPlaylistSort>[];
    await pumpPanel(
      tester,
      pl: playlist([ep(1), ep(2), ep(3)]),
      currentEpId: 2,
      onSortChanged: changed.add,
    );

    await tester.tap(find.text('名称降序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('番剧顺序'));
    await tester.pumpAndSettle();

    expect(changed, [BiliPlaylistSort.nameDesc, BiliPlaylistSort.season]);
    expect(_chip(tester, '番剧顺序').selected, isTrue);
    expect(_orderedTexts(tester, ['第1话', '第2话', '第3话']),
        ['第1话', '第2话', '第3话']);
  });
}

PlayerOptionChip _chip(WidgetTester tester, String label) =>
    tester.widget<PlayerOptionChip>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(PlayerOptionChip),
      ),
    );

/// 按屏幕纵向位置排出列表项先后（从 [labels] 里返回实际顺序）
List<String> _orderedTexts(WidgetTester tester, List<String> labels) {
  final copy = [...labels];
  copy.sort((a, b) {
    final ya = tester.getTopLeft(find.text(a)).dy;
    final yb = tester.getTopLeft(find.text(b)).dy;
    return ya.compareTo(yb);
  });
  return copy;
}
