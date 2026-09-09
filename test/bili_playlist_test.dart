import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/models/bili_playlist.dart';

/// B 站番剧播放列表模型测试：
/// - 由季详情/剧集数组构造（集号 1 起、顺序保持）；
/// - 按 epId 定位当前集（未找到 -1）；
/// - hasNextAt / itemAt 边界；
/// - 展示名回落（long_title → title → 「第 N 集」）与角标透传。
void main() {
  BiliEpisode ep(
    int epId, {
    String title = '',
    String longTitle = '',
    String badge = '',
    int cid = 0,
  }) =>
      BiliEpisode(
        epId: epId,
        aid: epId * 10,
        cid: cid == 0 ? epId * 100 : cid,
        bvid: 'BV$epId',
        title: title.isEmpty ? '第$epId话' : title,
        longTitle: longTitle,
        cover: '',
        badge: badge,
      );

  BiliSeasonDetail detail(List<BiliEpisode> episodes, {String title = '测试番剧'}) =>
      BiliSeasonDetail(
        seasonId: 12345,
        mediaId: 1,
        title: title,
        cover: '',
        evaluate: '',
        areas: const [],
        ratingScore: 0,
        publishTime: '',
        views: 0,
        danmaku: 0,
        favorite: 0,
        likes: 0,
        coins: 0,
        newEpTitle: '',
        newEpDesc: '',
        episodes: episodes,
        seasons: const [],
      );

  group('构造', () {
    test('fromSeasonDetail：季名 + 集号从 1 起 + 顺序保持', () {
      final playlist = BiliPlaylist.fromSeasonDetail(detail([
        ep(1),
        ep(2),
        ep(3),
      ]));
      expect(playlist.seasonId, 12345);
      expect(playlist.seasonTitle, '测试番剧');
      expect(playlist.length, 3);
      expect(playlist.items.map((e) => e.index).toList(), [1, 2, 3]);
      expect(playlist.items.map((e) => e.epId).toList(), [1, 2, 3]);
      expect(playlist.isNotEmpty, isTrue);
      expect(playlist.isEmpty, isFalse);
    });

    test('fromEpisodes：无季信息时季名/id 为空', () {
      final playlist = BiliPlaylist.fromEpisodes([ep(7), ep(8)]);
      expect(playlist.seasonId, 0);
      expect(playlist.seasonTitle, '');
      expect(playlist.length, 2);
      expect(playlist.items.first.epId, 7);
    });

    test('空剧集列表', () {
      final playlist = BiliPlaylist.fromSeasonDetail(detail(const []));
      expect(playlist.isEmpty, isTrue);
      expect(playlist.length, 0);
      expect(playlist.indexOfEpId(1), -1);
      expect(playlist.hasNextAt(0), isFalse);
    });
  });

  group('indexOfEpId / hasNextAt / itemAt', () {
    late BiliPlaylist playlist;

    setUp(() {
      playlist = BiliPlaylist.fromSeasonDetail(
        detail([ep(11), ep(22), ep(33)]),
      );
    });

    test('按 epId 定位', () {
      expect(playlist.indexOfEpId(11), 0);
      expect(playlist.indexOfEpId(22), 1);
      expect(playlist.indexOfEpId(33), 2);
    });

    test('未找到/空值/非法值返回 -1', () {
      expect(playlist.indexOfEpId(99), -1);
      expect(playlist.indexOfEpId(null), -1);
      expect(playlist.indexOfEpId(0), -1);
      expect(playlist.indexOfEpId(-5), -1);
    });

    test('hasNextAt 边界：最后一集/越界为 false', () {
      expect(playlist.hasNextAt(0), isTrue);
      expect(playlist.hasNextAt(1), isTrue);
      expect(playlist.hasNextAt(2), isFalse); // 最后一集
      expect(playlist.hasNextAt(-1), isFalse); // 未定位
      expect(playlist.hasNextAt(3), isFalse); // 越界
    });

    test('itemAt 越界返回 null', () {
      expect(playlist.itemAt(0)?.epId, 11);
      expect(playlist.itemAt(2)?.epId, 33);
      expect(playlist.itemAt(3), isNull);
      expect(playlist.itemAt(-1), isNull);
    });
  });

  group('条目展示', () {
    test('标题优先 long_title，其次 title，最后「第 N 集」', () {
      final playlist = BiliPlaylist.fromEpisodes([
        ep(1, title: '第1话', longTitle: '第1话 你即将死去'),
        ep(2, title: '第2话', longTitle: ''),
        // 标题全空：回落「第 N 集」
        const BiliEpisode(
          epId: 3,
          aid: 30,
          cid: 300,
          bvid: '',
          title: '',
          longTitle: '',
          cover: '',
        ),
      ]);
      expect(playlist.items[0].title, '第1话 你即将死去');
      expect(playlist.items[1].title, '第2话');
      expect(playlist.items[2].title, '第 3 集');
    });

    test('角标与 cid/aid 透传', () {
      final playlist = BiliPlaylist.fromEpisodes([
        ep(5, badge: '会员', cid: 555),
      ]);
      final item = playlist.items.single;
      expect(item.badge, '会员');
      expect(item.cid, 555);
      expect(item.aid, 50);
      expect(item.episode.epId, 5);
    });
  });
}
