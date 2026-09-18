import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/pages/player/views/player_danmaku_network_panel.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 网络弹幕搜索面板 UI 测试（本轮：逐台实时呈现）：
/// 每台服务器返回就立刻上屏（不等其余服务器）、搜索中「转圈 + 停止」、
/// 结果计数条、停止后结果保留且后续服务器不再产出、番剧名完整换行不截断、
/// 点结果卡回调（集数二级界面由播放页 push）；以及上一轮的紧凑搜索框、
/// 关键词历史胶囊、命中后自动折叠（搜索中不折叠）、P2-10 会话号语义。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPanel(
    WidgetTester tester, {
    DanmakuSearchStore? store,
    void Function(DanmakuSearchItem)? onResultTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerDanmakuNetworkPanel(
            store: store ?? DanmakuSearchStore(network: _FakeNetworkService()),
            onResultTap: onResultTap ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 输入关键词并用键盘搜索动作提交，等到流结束（假服务立即返回）
  Future<void> search(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  /// 只发一次搜索、**不**等结果：可控服务挂起时搜索框里的转圈会一直转，
  /// `pumpAndSettle` 会超时（转圈是无限动画）
  Future<void> submit(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  testWidgets('无历史无结果：显示空态提示', (tester) async {
    await pumpPanel(tester);
    expect(find.text('输入关键词搜索网络弹幕'), findsOneWidget);
  });

  testWidgets('搜索结果：标题 + 胶囊小标签（类型/集数/来源服务器）', (tester) async {
    await pumpPanel(tester);
    await search(tester, '紫罗兰');
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('2 集'), findsOneWidget);
    expect(find.text('OVA'), findsOneWidget);
    // **每个**结果都标来源：默认弹弹Play 与自建服务器都标
    expect(find.text('我的服务器'), findsOneWidget);
    expect(find.text('弹弹Play（默认）'), findsOneWidget);
  });

  testWidgets('番剧名完整换行：不设 maxLines/ellipsis，也没有「查看完整名称」', (tester) async {
    await pumpPanel(tester);
    await search(tester, '紫罗兰');

    final title = tester.widget<Text>(find.text('紫罗兰永恒花园'));
    expect(title.maxLines, isNull, reason: '完整展示，一行装不下就换行');
    expect(title.overflow, isNull);
    expect(find.text('查看完整名称'), findsNothing, reason: '不再截断 + 二次弹窗');
  });

  testWidgets('点结果卡 → 回调携带该条结果（不再就地展开集列表）', (tester) async {
    DanmakuSearchItem? tapped;
    await pumpPanel(tester, onResultTap: (item) => tapped = item);

    await search(tester, '紫罗兰');
    await tester.tap(find.text('紫罗兰永恒花园'));
    await tester.pumpAndSettle();

    expect(tapped?.anime.animeTitle, '紫罗兰永恒花园');
    expect(tapped?.anime.animeId, 1);
    expect(tapped?.serverName, '弹弹Play（默认）');
    expect(tapped?.serverUrl, isNull);
  });

  testWidgets('搜索框紧凑：胶囊容器定高 40dp', (tester) async {
    await pumpPanel(tester);
    final box = tester.getSize(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(box.height, 40);
  });

  testWidgets('关键词历史：搜索框下方胶囊展示 + 末尾「清除」胶囊', (tester) async {
    SharedPreferences.setMockInitialValues({
      'danmaku_search_history': jsonEncode(['紫罗兰', '海贼王']),
    });
    await pumpPanel(tester);
    expect(find.text('紫罗兰'), findsOneWidget);
    expect(find.text('海贼王'), findsOneWidget);
    // 历史胶囊紧贴搜索框下方（无独立分组卡片/分组标签）
    expect(find.text('搜索历史'), findsNothing);
    expect(
      tester.getTopLeft(find.text('紫罗兰')).dy,
      greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
    );

    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    expect(find.text('紫罗兰'), findsNothing);
    expect(find.text('海贼王'), findsNothing);
    expect(find.text('输入关键词搜索网络弹幕'), findsOneWidget);
  });

  testWidgets('命中结果后自动折叠搜索框，点折叠条重新展开', (tester) async {
    SharedPreferences.setMockInitialValues({
      'danmaku_search_history': jsonEncode(['海贼王']),
    });
    await pumpPanel(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('海贼王'), findsOneWidget);

    await search(tester, '紫罗兰');
    // 搜索框与历史胶囊让位给结果区，只剩「关键词 · N 部」折叠条
    expect(find.byType(TextField), findsNothing);
    expect(find.text('海贼王'), findsNothing);
    expect(find.text('清除'), findsNothing);
    expect(find.text('2 部'), findsOneWidget);

    await tester.tap(find.text('2 部'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('紫罗兰永恒花园'), findsOneWidget); // 结果仍在
  });

  testWidgets('搜索无结果时搜索框保持展开（便于立刻改词）', (tester) async {
    await pumpPanel(tester);
    await search(tester, '空');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('未找到相关番剧'), findsOneWidget);
  });

  testWidgets('点历史胶囊 → 填入关键词并搜索', (tester) async {
    SharedPreferences.setMockInitialValues({
      'danmaku_search_history': jsonEncode(['紫罗兰']),
    });
    await pumpPanel(tester);
    await tester.tap(find.text('紫罗兰'));
    await tester.pumpAndSettle();
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
  });

  testWidgets('搜索失败显示错误横幅', (tester) async {
    await pumpPanel(tester);
    await search(tester, '错');
    expect(find.textContaining('搜索失败'), findsOneWidget);
  });

  // ── 本轮核心：逐台实时呈现 + 停止 ───────────────────────────────

  testWidgets('逐台实时呈现：先返回的服务器立刻上屏，不等其余服务器', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, '紫罗兰');
    expect(service.keywords, ['紫罗兰']);
    // 一台都没返回：整屏转圈
    expect(find.text('搜索中…'), findsOneWidget);

    // 第一台返回 → 结果立刻可见，此时其余服务器还在搜
    service.emit(0, '紫罗兰永恒花园');
    await tester.pump();
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
    expect(find.text('搜索中…'), findsNothing);
    expect(find.text('正在搜索 · 已获得 1 部'), findsOneWidget);

    // 第二台返回 → 追加，计数增长
    service.emit(
      0,
      '紫罗兰 剧场版',
      animeId: 2,
      serverName: '我的服务器',
      serverUrl: 'https://self.example.com',
    );
    await tester.pump();
    expect(find.text('正在搜索 · 已获得 2 部'), findsOneWidget);
    expect(find.text('我的服务器'), findsOneWidget);

    // 全部返回 → 转圈/停止让位，搜索框折叠成「关键词 · N 部」条
    await service.close(0);
    await tester.pumpAndSettle();
    expect(find.byTooltip('停止搜索'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('正在搜索 · 已获得 2 部'), findsNothing);
    expect(find.text('2 部'), findsOneWidget);
  });

  testWidgets('后来的服务器集数更多 → 就地替换那张卡（不新增重复卡）', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));
    await submit(tester, '紫罗兰');

    // A 服务器先返回：同样一部番剧，只有 1 集
    service.emit(0, '紫罗兰永恒花园', animeId: 1);
    await tester.pump();
    expect(find.text('1 集'), findsOneWidget);
    expect(find.text('弹弹Play（默认）'), findsOneWidget);

    // B 服务器后返回：同一 animeId 但有 12 集 → 替换（比"谁快谁赢"更全）
    service.emit(
      0,
      '紫罗兰永恒花园',
      animeId: 1,
      episodeCount: 12,
      serverName: '我的服务器',
      serverUrl: 'https://self.example.com',
      upgrade: true,
    );
    await tester.pump();

    expect(find.text('紫罗兰永恒花园'), findsOneWidget, reason: '不新增重复卡');
    expect(find.text('12 集'), findsOneWidget);
    expect(find.text('我的服务器'), findsOneWidget, reason: '来源胶囊跟着换成更全的那台');
    expect(find.text('弹弹Play（默认）'), findsNothing);
    expect(find.text('正在搜索 · 已获得 1 部'), findsOneWidget);

    await service.close(0);
    await tester.pumpAndSettle();
    expect(find.text('1 部'), findsOneWidget);
  });

  testWidgets('搜索中：搜索框右侧是转圈 + 停止，搜索箭头隐藏且不折叠', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, '紫罗兰');
    expect(find.byTooltip('搜索'), findsNothing);
    expect(find.byTooltip('停止搜索'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    service.emit(0, '紫罗兰永恒花园');
    await tester.pump();
    // 有结果也不折叠（停止按钮必须可见）
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('停止搜索'), findsOneWidget);

    await service.close(0);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing, reason: '全部返回后才折叠');
  });

  testWidgets('点停止：转圈停下、已到达结果保留、后续服务器不再产出', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, '紫罗兰');
    service.emit(0, '紫罗兰永恒花园');
    await tester.pump();
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);

    await tester.tap(find.byTooltip('停止搜索'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('停止搜索'), findsNothing);
    expect(find.text('已停止搜索 · 共 1 部'), findsOneWidget);
    expect(find.text('紫罗兰永恒花园'), findsOneWidget, reason: '已搜到的结果必须留着');

    // 订阅已取消：旧流再推结果也不会进来
    service.emit(0, '停止后不该出现', animeId: 9);
    await tester.pump();
    expect(find.text('停止后不该出现'), findsNothing);
  });

  testWidgets('停止时还没有任何结果：搜索框保持展开（能改关键词）', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, '紫罗兰');
    await tester.tap(find.byTooltip('停止搜索'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('已停止搜索 · 共 0 部'), findsOneWidget);
  });

  testWidgets('部分服务器失败：有结果时以状态条提示，不吞掉已到结果', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, '紫罗兰');
    service.emit(0, '紫罗兰永恒花园');
    service.emitError(0, '我的服务器: 连接超时');
    await tester.pump();
    await service.close(0);
    await tester.pumpAndSettle();

    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
    expect(find.textContaining('部分服务器搜索失败'), findsOneWidget);
    expect(find.textContaining('连接超时'), findsOneWidget);
  });

  // ── P2-10：搜索并发语义（会话号 + 不再静默吞掉搜索中的新搜索）──

  testWidgets('搜索中再搜不被吞：旧流结果丢弃，最终取最后一次输入', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, 'A');
    expect(service.keywords, ['A']);

    // 搜索期间照常发起新搜索（键盘搜索键）
    await submit(tester, 'B');
    expect(service.keywords, ['A', 'B']);

    // 新的（B）先返回 → 显示 B
    service.emit(1, 'B 番剧', animeId: 2);
    await tester.pump();
    expect(find.text('B 番剧'), findsOneWidget);

    // 旧流（A）后到 → 丢弃，不覆盖新结果
    service.emit(0, 'A 番剧', animeId: 1);
    await tester.pump();
    expect(find.text('A 番剧'), findsNothing);

    await service.close(1);
    await tester.pumpAndSettle();
    expect(find.text('B 番剧'), findsOneWidget);
  });

  testWidgets('点搜索箭头也能重新发起（非搜索中）', (tester) async {
    final service = _ControlledNetworkService();
    await pumpPanel(tester, store: DanmakuSearchStore(network: service));

    await submit(tester, 'A');
    await service.close(0);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'C');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    expect(service.keywords, ['A', 'C']);

    service.emit(1, 'C 番剧', animeId: 3);
    await service.close(1);
    await tester.pumpAndSettle();
    expect(find.text('C 番剧'), findsOneWidget);
  });

  // ── 搜索结果跨面板重建存活（用户实测：进二级界面再返回结果全没了）──

  testWidgets('进二级界面再返回（面板 State 重建）：结果、关键词、计数都还在', (tester) async {
    final store = DanmakuSearchStore(network: _FakeNetworkService());
    await pumpPanel(tester, store: store);
    await search(tester, '紫罗兰');
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);

    // 模拟"点结果进集数二级界面"：面板被卸载
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    store.listOffset = 120; // 顺手验证滚动位置也带回来

    // 返回：外壳重建同一个面板（同一会话对象）
    await pumpPanel(tester, store: store);
    expect(find.text('紫罗兰永恒花园'), findsOneWidget, reason: '结果不得丢失');
    expect(find.text('另一部番'), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget, reason: '折叠条还原上次关键词与条数');
    // 关键词也回填到输入框（展开后可见）
    await tester.tap(find.text('2 部'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '紫罗兰',
    );
    expect(store.listOffset, 120, reason: '滚动位置由会话对象带着走');
  });

  testWidgets('用户主动关面板后再打开：搜索结果已清空（关面板 = 关掉搜索）', (tester) async {
    final store = DanmakuSearchStore(network: _FakeNetworkService());
    await pumpPanel(tester, store: store);
    await search(tester, '紫罗兰');
    expect(store.results, isNotEmpty);

    // 用户点 X / 遮罩关面板 → 外层再打开弹幕面板时会调 beginPanelSession
    store.beginPanelSession();

    expect(store.results, isEmpty);
    expect(store.keyword, isEmpty);
    await pumpPanel(tester, store: store);
    expect(find.text('输入关键词搜索网络弹幕'), findsOneWidget);
    expect(find.text('紫罗兰永恒花园'), findsNothing);
  });

  testWidgets('选完一集自动关闭面板后再打开：结果仍在（省一次请求）', (tester) async {
    final store = DanmakuSearchStore(network: _FakeNetworkService());
    await pumpPanel(tester, store: store);
    await search(tester, '紫罗兰');

    // 集数二级界面选中某集 → markKeepOnClose → 面板自动关闭
    store.markKeepOnClose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    store.beginPanelSession(); // 下次打开弹幕面板

    expect(store.results, isNotEmpty, reason: '不是用户主动关的，结果要留下');
    await pumpPanel(tester, store: store);
    expect(find.text('紫罗兰永恒花园'), findsOneWidget);
    expect(find.text('2 部'), findsOneWidget);
  });

  testWidgets('保留只发生一次：自动关闭那次留着，之后用户主动关面板仍会清空', (tester) async {
    final store = DanmakuSearchStore(network: _FakeNetworkService());
    await pumpPanel(tester, store: store);
    await search(tester, '紫罗兰');

    store.markKeepOnClose();
    store.beginPanelSession(); // 保留一次
    expect(store.results, isNotEmpty);

    store.beginPanelSession(); // 这次没有 keep 标记 → 用户主动关的面板
    expect(store.results, isEmpty);
  });
}

/// 可控流式服务：`searchStream` 每次被调用登记一个 [StreamController]，
/// 由测试决定何时推入哪台服务器的结果、何时结束——用来验证
/// 「不合并、不等齐、边到边显示」与「停止后不再产出」。
class _ControlledNetworkService extends DanmakuNetworkService {
  final List<String> keywords = [];
  final List<StreamController<DanmakuServerSearchOutcome>> streams = [];

  @override
  Stream<DanmakuServerSearchOutcome> searchStream(String keyword) {
    keywords.add(keyword);
    final controller = StreamController<DanmakuServerSearchOutcome>();
    streams.add(controller);
    return controller.stream;
  }

  /// 第 [index] 次搜索推入一台服务器的结果。
  ///
  /// [upgrade] 为 true 时放进 `upgrades`（同一 animeId 的替换事件），模拟
  /// "后到的服务器集数更多、就地覆盖旧卡"。
  void emit(
    int index,
    String title, {
    int animeId = 1,
    String serverName = '弹弹Play（默认）',
    String? serverUrl,
    int episodeCount = 1,
    bool upgrade = false,
  }) {
    final item = DanmakuSearchItem(
      anime: DandanAnime(
        animeId: animeId,
        animeTitle: title,
        type: 'tv',
        typeDescription: 'TV',
        episodes: [
          for (var i = 0; i < episodeCount; i++)
            DandanEpisode(
              episodeId: animeId * 100 + i,
              episodeTitle: '第${i + 1}话',
            ),
        ],
      ),
      serverUrl: serverUrl,
      serverName: serverName,
    );
    streams[index].add(
      DanmakuServerSearchOutcome(
        serverName: serverName,
        serverUrl: serverUrl,
        items: upgrade ? const [] : [item],
        upgrades: upgrade ? [item] : const [],
      ),
    );
  }

  /// 第 [index] 次搜索推入一台服务器的失败事件
  void emitError(int index, String error) {
    streams[index].add(
      DanmakuServerSearchOutcome(
        serverName: '',
        serverUrl: null,
        error: error,
      ),
    );
  }

  Future<void> close(int index) => streams[index].close();
}

/// 测试假网络服务（真实 [DanmakuNetworkService] 会发起 HTTP 请求，
/// 单元测试环境用固定结果替代）。
class _FakeNetworkService extends DanmakuNetworkService {
  _FakeNetworkService();

  @override
  Stream<DanmakuServerSearchOutcome> searchStream(String keyword) async* {
    if (keyword == '错') {
      yield const DanmakuServerSearchOutcome(
        serverName: '弹弹Play（默认）',
        serverUrl: null,
        error: '弹弹Play（默认）: 超时',
      );
      return;
    }
    if (keyword == '空') return;
    // 两台服务器各返回一条，覆盖「来源胶囊」与逐台追加
    yield const DanmakuServerSearchOutcome(
      serverName: '弹弹Play（默认）',
      serverUrl: null,
      items: [
        DanmakuSearchItem(
          anime: DandanAnime(
            animeId: 1,
            animeTitle: '紫罗兰永恒花园',
            type: 'tv',
            typeDescription: 'TV',
            episodes: [
              DandanEpisode(episodeId: 11, episodeTitle: '第01话'),
              DandanEpisode(episodeId: 12, episodeTitle: '第02话'),
            ],
          ),
          serverUrl: null,
          serverName: '弹弹Play（默认）',
        ),
      ],
    );
    yield const DanmakuServerSearchOutcome(
      serverName: '我的服务器',
      serverUrl: 'https://self.example.com',
      items: [
        DanmakuSearchItem(
          anime: DandanAnime(
            animeId: 2,
            animeTitle: '另一部番',
            type: 'ova',
            typeDescription: 'OVA',
            episodes: [DandanEpisode(episodeId: 21, episodeTitle: '正片')],
          ),
          serverUrl: 'https://self.example.com',
          serverName: '我的服务器',
        ),
      ],
    );
  }
}
