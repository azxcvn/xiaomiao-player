import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_store.dart';

/// 网络弹幕搜索会话测试（用户实测反馈的"返回后结果全丢、还得重搜一次"）：
/// - 逐台实时产出、去重升级就地覆盖、停止后保留已到结果；
/// - **跨面板重建存活**：结果/关键词/滚动位置都在会话对象里；
/// - 生命周期：用户主动关面板 → 下次打开清空；选完一集自动关闭 → 保留一次。
void main() {
  DanmakuSearchStore makeStore(_FakeNetworkService network) =>
      DanmakuSearchStore(network: network);

  test('搜索：逐台产出追加，结束后 searching 归位、错误文案为空', () async {
    final network = _FakeNetworkService();
    final store = makeStore(network);

    await store.search('紫罗兰');
    expect(store.keyword, '紫罗兰');
    expect(store.searching, isTrue, reason: '订阅刚建立，第一台还没返回');

    await network.closeCurrent();
    expect(store.searching, isFalse);
    expect(store.error, isNull, reason: '有结果就不报错');
    expect(store.results.map((r) => r.anime.animeTitle), ['番剧A', '番剧B']);
    expect(store.stopped, isFalse);
  });

  test('搜索：同一 animeId 的更全结果就地覆盖（不新增重复项）', () async {
    final network = _FakeNetworkService(upgrade: true);
    final store = makeStore(network);

    await store.search('紫罗兰');
    await network.closeCurrent();

    expect(store.results.length, 1, reason: '去重后只有一条');
    expect(store.results.single.anime.episodes.length, 3);
    expect(store.results.single.serverName, '我的服务器');
  });

  test('无结果：error 给出"未找到相关番剧"', () async {
    final network = _FakeNetworkService(empty: true);
    final store = makeStore(network);

    await store.search('空');
    await network.closeCurrent();

    expect(store.results, isEmpty);
    expect(store.error, contains('未找到相关番剧'));
  });

  test('停止：中断后续服务器、已到结果保留、stopped 置位', () async {
    final network = _FakeNetworkService();
    final store = makeStore(network);

    await store.search('紫罗兰');
    expect(store.results, isNotEmpty, reason: '第一台已到');

    store.stop();
    expect(store.searching, isFalse);
    expect(store.stopped, isTrue);
    expect(store.results, isNotEmpty, reason: '已经搜到的结果必须留着');

    // 停止后旧流再推结果也不进来（订阅已断）
    network.emitLate('不该出现');
    await Future<void>.delayed(Duration.zero);
    expect(store.results.map((r) => r.anime.animeTitle), isNot(contains('不该出现')));
  });

  test('跨面板重建：结果/关键词/滚动位置都在（不重新请求）', () async {
    final network = _FakeNetworkService();
    final store = makeStore(network);

    await store.search('紫罗兰');
    await network.closeCurrent();
    store.listOffset = 240;

    // 面板 State 重建后读同一个会话
    expect(store.keyword, '紫罗兰');
    expect(store.results.length, 2);
    expect(store.listOffset, 240);
    expect(network.searchCount, 1, reason: '没有第二次请求');
  });

  test('用户主动关面板：下次打开清空（关面板 = 关掉搜索结果）', () async {
    final store = makeStore(_FakeNetworkService());
    await store.search('紫罗兰');

    store.beginPanelSession();

    expect(store.keyword, isEmpty);
    expect(store.results, isEmpty);
    expect(store.error, isNull);
    expect(store.listOffset, 0);
  });

  test('选完一集自动关闭：保留一次；再下一次主动关面板仍会清空', () async {
    final store = makeStore(_FakeNetworkService());
    await store.search('紫罗兰');

    store.markKeepOnClose();
    store.beginPanelSession();
    expect(store.results, isNotEmpty, reason: '自动关闭不是用户主动关，结果要留');
    expect(store.keepOnClose, isFalse, reason: '标记只生效一次');

    store.beginPanelSession();
    expect(store.results, isEmpty);
  });

  test('从没搜过时 beginPanelSession 不打扰（不触发空通知）', () async {
    final store = makeStore(_FakeNetworkService());
    var notified = 0;
    store.addListener(() => notified++);

    store.beginPanelSession();
    expect(notified, 0);
  });

  test('新搜索清空上一轮结果与滚动位置', () async {
    final network = _FakeNetworkService();
    final store = makeStore(network);

    await store.search('紫罗兰');
    await network.closeCurrent();
    store.listOffset = 500;

    // 记录每次通知时的结果条数：发起新搜索的第一次通知必须是 0（先清空再挂新的）
    final lengths = <int>[];
    store.addListener(() => lengths.add(store.results.length));
    await store.search('海贼王');

    expect(lengths.first, 0, reason: '新一轮从空开始，不与上一轮叠加');
    expect(store.keyword, '海贼王');
    expect(store.listOffset, 0, reason: '换关键词后从顶部开始');
    expect(network.keywords, ['紫罗兰', '海贼王']);
  });
}

/// 假网络服务：第一台立刻产出（可升级），第二台挂在 [closeCurrent] 之前
class _FakeNetworkService extends DanmakuNetworkService {
  _FakeNetworkService({this.upgrade = false, this.empty = false});

  final bool upgrade;
  final bool empty;
  final List<String> keywords = [];
  int searchCount = 0;
  StreamController<DanmakuServerSearchOutcome>? _controller;

  @override
  Stream<DanmakuServerSearchOutcome> searchStream(String keyword) {
    keywords.add(keyword);
    searchCount++;
    final controller = StreamController<DanmakuServerSearchOutcome>();
    _controller = controller;
    if (empty) {
      scheduleMicrotask(controller.close);
      return controller.stream;
    }
    final episodes = [
      for (var i = 0; i < (upgrade ? 1 : 2); i++)
        DandanEpisode(episodeId: 10 + i, episodeTitle: '第0${i + 1}话'),
    ];
    controller.add(
      DanmakuServerSearchOutcome(
        serverName: '弹弹Play（默认）',
        serverUrl: null,
        items: [
          DanmakuSearchItem(
            anime: DandanAnime(
              animeId: 1,
              animeTitle: '番剧A',
              type: 'tv',
              typeDescription: 'TV',
              episodes: episodes,
            ),
            serverUrl: null,
            serverName: '弹弹Play（默认）',
          ),
        ],
      ),
    );
    if (upgrade) {
      controller.add(
        DanmakuServerSearchOutcome(
          serverName: '我的服务器',
          serverUrl: 'https://self.example.com',
          upgrades: [
            DanmakuSearchItem(
              anime: DandanAnime(
                animeId: 1,
                animeTitle: '番剧A',
                type: 'tv',
                typeDescription: 'TV',
                episodes: const [
                  DandanEpisode(episodeId: 11, episodeTitle: '第01话'),
                  DandanEpisode(episodeId: 12, episodeTitle: '第02话'),
                  DandanEpisode(episodeId: 13, episodeTitle: '第03话'),
                ],
              ),
              serverUrl: 'https://self.example.com',
              serverName: '我的服务器',
            ),
          ],
        ),
      );
    } else {
      controller.add(
        DanmakuServerSearchOutcome(
          serverName: '我的服务器',
          serverUrl: 'https://self.example.com',
          items: [
            DanmakuSearchItem(
              anime: const DandanAnime(
                animeId: 2,
                animeTitle: '番剧B',
                type: 'ova',
                typeDescription: 'OVA',
                episodes: [DandanEpisode(episodeId: 21, episodeTitle: '正片')],
              ),
              serverUrl: 'https://self.example.com',
              serverName: '我的服务器',
            ),
          ],
        ),
      );
    }
    return controller.stream;
  }

  /// 结束当前这一轮搜索
  Future<void> closeCurrent() async {
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) await controller.close();
    // 让 onDone 的微任务跑完
    await Future<void>.delayed(Duration.zero);
  }

  /// 停止之后再推一条（应被丢弃）
  void emitLate(String title) {
    final controller = _controller;
    if (controller == null || controller.isClosed) return;
    controller.add(
      DanmakuServerSearchOutcome(
        serverName: '迟到',
        serverUrl: null,
        items: [
          DanmakuSearchItem(
            anime: DandanAnime(
              animeId: 99,
              animeTitle: title,
              type: 'tv',
              typeDescription: 'TV',
              episodes: const [
                DandanEpisode(episodeId: 99, episodeTitle: '第01话'),
              ],
            ),
            serverUrl: null,
            serverName: '迟到',
          ),
        ],
      ),
    );
  }
}
