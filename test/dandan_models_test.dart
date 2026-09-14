import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/dandan_models.dart';

/// 弹弹Play API 数据模型 fromJson 测试（容错 + 字段映射）。
void main() {
  group('DandanEpisode.fromJson', () {
    test('正常解析', () {
      final ep = DandanEpisode.fromJson({
        'episodeId': 42,
        'episodeTitle': '第42话',
      });
      expect(ep, isNotNull);
      expect(ep!.episodeId, 42);
      expect(ep.episodeTitle, '第42话');
    });

    test('字段缺失/类型不符 → null', () {
      expect(DandanEpisode.fromJson({'episodeTitle': 'x'}), isNull);
      expect(DandanEpisode.fromJson({'episodeId': '42', 'episodeTitle': 'x'}),
          isNull);
    });
  });

  group('DandanAnime.fromJson', () {
    test('解析番剧 + 集列表（坏集跳过）', () {
      final anime = DandanAnime.fromJson({
        'animeId': 1,
        'animeTitle': '某番剧',
        'type': 'tv',
        'typeDescription': 'TV',
        'episodes': [
          {'episodeId': 1, 'episodeTitle': '第01话'},
          {'episodeTitle': '缺 id'},
          {'episodeId': 2, 'episodeTitle': '第02话'},
        ],
      });
      expect(anime, isNotNull);
      expect(anime!.animeId, 1);
      expect(anime.animeTitle, '某番剧');
      expect(anime.episodes.length, 2);
      expect(anime.episodes.map((e) => e.episodeId).toList(), [1, 2]);
    });

    test('缺 animeId/animeTitle → null', () {
      expect(DandanAnime.fromJson({'animeTitle': 'x'}), isNull);
      expect(DandanAnime.fromJson({'animeId': 1}), isNull);
    });

    // P2-12：自建服务器常把字段类型写错，裸 `as String?` 会抛 TypeError
    // → 整条响应解析失败（搜索结果全空）。这里必须「回退默认值」而不是抛。
    test('类型随意的 type/typeDescription → 回退空串，不抛异常', () {
      final anime = DandanAnime.fromJson({
        'animeId': 1,
        'animeTitle': '某番剧',
        'type': 1,
        'typeDescription': {'x': 1},
        'episodes': [
          {'episodeId': 1, 'episodeTitle': '第01话'},
        ],
      });
      expect(anime, isNotNull);
      expect(anime!.animeTitle, '某番剧');
      expect(anime.type, '');
      expect(anime.typeDescription, '');
      expect(anime.episodes.length, 1);
    });
  });

  group('DandanMatchInfo.fromJson', () {
    test('正常解析（含 shift 默认 0）', () {
      final m = DandanMatchInfo.fromJson({
        'episodeId': 7,
        'animeId': 8,
        'animeTitle': '番剧',
        'episodeTitle': '第07话',
        'type': 'tv',
        'typeDescription': 'TV',
      });
      expect(m, isNotNull);
      expect(m!.episodeId, 7);
      expect(m.shift, 0);
    });

    test('shift 数值解析', () {
      final m = DandanMatchInfo.fromJson({
        'episodeId': 7,
        'animeId': 8,
        'animeTitle': 'a',
        'episodeTitle': 'b',
        'shift': 1.5,
      });
      expect(m!.shift, 1.5);
    });

    test('缺关键字段 → null', () {
      expect(DandanMatchInfo.fromJson({'episodeId': 7}), isNull);
    });

    // P2-12：shift 为字符串/布尔等类型不符时不抛异常（回退 0）
    test('类型随意的 type/shift → 回退默认值，不抛异常', () {
      final m = DandanMatchInfo.fromJson({
        'episodeId': 7,
        'animeId': 8,
        'animeTitle': '番剧',
        'episodeTitle': '第07话',
        'type': 1,
        'typeDescription': 2,
        'shift': '1.5',
      });
      expect(m, isNotNull);
      expect(m!.type, '');
      expect(m.typeDescription, '');
      expect(m.shift, 1.5);
      expect(
        DandanMatchInfo.fromJson({
          'episodeId': 7,
          'animeId': 8,
          'animeTitle': 'a',
          'episodeTitle': 'b',
          'shift': true,
        })!
            .shift,
        0,
      );
    });
  });
}
