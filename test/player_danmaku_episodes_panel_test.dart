import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/pages/player/views/player_danmaku_episodes_panel.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_store.dart';

/// 网络弹幕**集数二级界面**测试（问题 3）：
/// 集名完整换行（不截断/不长按弹窗）、跳转输入框、进页自动定位到当前集并
/// **把命中集滚到首行** + 较长时间的闪烁高亮、定位失败的内联提示、
/// 点某集回调并关闭面板。
void main() {
  /// 默认 130 集（足够长，能验证"滚到首行"而不是"本来就在首屏"）
  DanmakuSearchItem item({
    List<DandanEpisode>? episodes,
    String serverName = '弹弹Play（默认）',
    String? serverUrl,
  }) {
    final list =
        episodes ??
        List.generate(
          130,
          (i) => DandanEpisode(episodeId: 1000 + i, episodeTitle: '第${i + 1}话'),
        );
    return DanmakuSearchItem(
      anime: DandanAnime(
        animeId: 1,
        animeTitle: '紫罗兰永恒花园',
        type: 'tv',
        typeDescription: 'TV',
        episodes: list,
      ),
      serverUrl: serverUrl,
      serverName: serverName,
    );
  }

  /// 跑到"自动定位滚动完成、闪烁仍在"的那一帧。
  ///
  /// 需要多帧：首帧 → post-frame 里启动 `animateTo` → ticker 的第一帧只记录
  /// 起点（elapsed = 0）→ 最后一帧推进 500ms 让 420ms 的滚动走完。
  Future<void> settleLocate(WidgetTester tester) async {
    await tester.pump(); // post-frame：启动滚动动画
    await tester.pump(); // ticker 第一帧（记录起点）
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 500)); // 走完
  }

  /// 固定 320×400 的容器：集列表必须滚动，才能验证定位落点
  Future<void> pumpPanel(
    WidgetTester tester, {
    DanmakuSearchItem? searchItem,
    String? currentFileName,
    void Function(DandanAnime, DandanEpisode, String?)? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: PlayerDanmakuEpisodesPanel(
                item: searchItem ?? item(),
                currentFileName: currentFileName,
                onEpisodeSelected: onSelected ?? (a, e, s) {},
              ),
            ),
          ),
        ),
      ),
    );
    await settleLocate(tester);
  }

  /// 闪烁高亮层 = 自动定位/跳转命中的那一整行
  final highlight = find.byKey(kEpisodeHighlightKey);

  /// 集列表视口顶部（比较落点用）
  double viewportTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(SingleChildScrollView)).dy;

  testWidgets('集名完整换行：不设 maxLines/ellipsis', (tester) async {
    const long = '第01话 紫罗兰永恒花园 [BDRip][1080p][简繁外挂字幕] 收藏版';
    await pumpPanel(
      tester,
      searchItem: item(
        episodes: const [
          DandanEpisode(episodeId: 1, episodeTitle: long),
          DandanEpisode(episodeId: 2, episodeTitle: '第02话'),
        ],
      ),
    );

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, isNull, reason: '一行装不下就换行，不截断也不弹窗');
    expect(text.overflow, isNull);
  });

  testWidgets('头部只占一行：跳转输入 + 右侧「共 N 集 · 来自 X」，不再有标题块', (tester) async {
    await pumpPanel(tester, searchItem: item(serverName: '我的服务器'));

    // 番剧名只在面板顶部标题行（跑马灯），页面内不再重复一块
    expect(find.text('紫罗兰永恒花园'), findsNothing);
    expect(find.text('共 130 集 · 来自 我的服务器'), findsOneWidget);
    // 头部必须很矮：高度全留给集列表（原来标题块 + 跳转条叠起来吃掉竖屏 2/5）
    final headerHeight =
        tester.getTopLeft(find.byType(SingleChildScrollView)).dy -
        tester.getTopLeft(find.byType(PlayerDanmakuEpisodesPanel)).dy;
    expect(headerHeight, lessThan(60));
  });

  testWidgets('自动定位：按文件名命中第 120 集并滚到**首行**', (tester) async {
    await pumpPanel(tester, currentFileName: 'Violet Evergarden 第120话.mkv');

    // 命中的正是第 120 集
    expect(
      find.descendant(of: highlight, matching: find.text('第120话')),
      findsOneWidget,
    );
    // 且它被顶到可视区首行（"120 集放在最前面"）
    expect(
      (tester.getTopLeft(highlight).dy - viewportTop(tester)).abs(),
      lessThan(1.0),
    );
  });

  testWidgets('命中集闪烁高亮，且持续时间够长（约 3.4s 后才消失）', (tester) async {
    await pumpPanel(tester, currentFileName: 'Violet Evergarden 第120话.mkv');
    expect(highlight, findsOneWidget, reason: '滚动到位后仍在闪');

    // 再等 3s（合计 > 闪烁总时长）→ 高亮结束
    await tester.pump(const Duration(milliseconds: 3000));
    expect(highlight, findsNothing, reason: '闪完恢复常态');
  });

  testWidgets('文件名解析不出集数：内联提示，不定位不高亮', (tester) async {
    await pumpPanel(tester, currentFileName: 'Violet Evergarden.mkv');
    expect(find.textContaining('未能从文件名识别集数'), findsOneWidget);
    expect(highlight, findsNothing);
  });

  testWidgets('currentFileName 为 null：静默不定位、不提示', (tester) async {
    await pumpPanel(tester);
    expect(find.textContaining('未能从文件名识别集数'), findsNothing);
    expect(find.textContaining('未找到第'), findsNothing);
    expect(highlight, findsNothing);
  });

  testWidgets('跳至第 N 集：命中集滚到首行 + 高亮', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await settleLocate(tester);

    expect(
      find.descendant(of: highlight, matching: find.text('第7话')),
      findsOneWidget,
    );
    expect(
      (tester.getTopLeft(highlight).dy - viewportTop(tester)).abs(),
      lessThan(1.0),
    );
  });

  testWidgets('跳转输入非数字 / 超出范围 → 内联提示', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    expect(find.text('请输入集数（数字）'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '999');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    expect(find.text('没有第 999 集'), findsOneWidget);
  });

  testWidgets('只有 1 集时不显示「跳至第 N 集」输入框，但仍标出集数与来源', (tester) async {
    await pumpPanel(
      tester,
      searchItem: item(
        episodes: const [DandanEpisode(episodeId: 1, episodeTitle: '正片')],
      ),
    );
    expect(find.text('跳至第'), findsNothing);
    expect(find.text('共 1 集 · 来自 弹弹Play（默认）'), findsOneWidget);
    expect(find.text('正片'), findsOneWidget);
  });

  testWidgets('点某一集 → 回调携带番剧/该集/来源服务器，并关闭面板', (tester) async {
    DandanAnime? gotAnime;
    DandanEpisode? gotEpisode;
    String? gotServer;
    // 集数界面选完一集后，面板是被"自动关闭"的：要标记保留搜索结果
    DanmakuSearchStore.instance.resetForTest();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: PlayerDanmakuEpisodesPanel(
                        item: item(
                          episodes: const [
                            DandanEpisode(episodeId: 11, episodeTitle: '第01话'),
                            DandanEpisode(episodeId: 12, episodeTitle: '第02话'),
                          ],
                          serverName: '我的服务器',
                          serverUrl: 'https://self.example.com',
                        ),
                        onEpisodeSelected: (a, e, s) {
                          gotAnime = a;
                          gotEpisode = e;
                          gotServer = s;
                        },
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('第02话'));
    await tester.pumpAndSettle();

    expect(gotAnime?.animeId, 1);
    expect(gotEpisode?.episodeId, 12);
    expect(gotServer, 'https://self.example.com');
    expect(
      DanmakuSearchStore.instance.keepOnClose,
      isTrue,
      reason: '选完一集是"自动关闭面板"，搜索结果要保留（下次打开还能接着挑）',
    );
    // 面板已关闭，回到 home
    expect(find.text('第02话'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    DanmakuSearchStore.instance.resetForTest();
  });
}
