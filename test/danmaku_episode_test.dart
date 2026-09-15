import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/utils/danmaku_episode.dart';

/// 弹幕集数提取 / 匹配纯函数测试（切集自动匹配弹幕，工作.md 第 7 点）。
void main() {
  group('extractEpisodeNumber', () {
    test('纯数字 / 扩展名', () {
      expect(extractEpisodeNumber('01.mkv'), 1);
      expect(extractEpisodeNumber('12.mkv'), 12);
    });

    test('第 N 话 / 集 / 回', () {
      expect(extractEpisodeNumber('第01话.mp4'), 1);
      expect(extractEpisodeNumber('第12集.mkv'), 12);
      expect(extractEpisodeNumber('第 3 话'), 3);
    });

    test('S01E01（季 + 集，取集）', () {
      expect(extractEpisodeNumber('S01E01.mkv'), 1);
      expect(extractEpisodeNumber('s02e05.mp4'), 5);
    });

    test('EP 前缀', () {
      expect(extractEpisodeNumber('EP01.mkv'), 1);
      expect(extractEpisodeNumber('ep12.mp4'), 12);
    });

    test('末尾集数带分隔符与 [1080p] 后缀', () {
      expect(extractEpisodeNumber('[Group] Anime - 01 [1080p].mkv'), 1);
      expect(extractEpisodeNumber('Anime_12.5.mkv'), 12.5);
      expect(extractEpisodeNumber('Anime - 07.mkv'), 7);
    });

    test('v2 修正与全角括号', () {
      expect(extractEpisodeNumber('Anime 01v2.mkv'), 1);
      expect(extractEpisodeNumber('Anime【02】.mkv'), 2);
    });

    test('开头集数（01 - Title 格式）', () {
      expect(extractEpisodeNumber('01 - Title.mkv'), 1);
    });

    test('无法识别 → null', () {
      expect(extractEpisodeNumber('剧场版.mkv'), isNull);
      expect(extractEpisodeNumber('Movie.mkv'), isNull);
      expect(extractEpisodeNumber(''), isNull);
    });
  });

  group('extractEpisodeNumberFromTitle', () {
    test('标题带集数直接用文件名规则', () {
      expect(extractEpisodeNumberFromTitle('第01话'), 1);
    });

    test('标题无规则结构退回第一个数字', () {
      expect(extractEpisodeNumberFromTitle('Episode 3'), 3);
      expect(extractEpisodeNumberFromTitle('番剧 第 7 话'), 7);
    });

    test('无数字 → null', () {
      expect(extractEpisodeNumberFromTitle('特别篇'), isNull);
    });
  });

  group('findMatchingEpisode', () {
    const episodes = [
      DandanEpisode(episodeId: 101, episodeTitle: '第01话'),
      DandanEpisode(episodeId: 102, episodeTitle: '第02话'),
      DandanEpisode(episodeId: 103, episodeTitle: '第03话'),
    ];

    test('按标题集数精确匹配', () {
      expect(findMatchingEpisode(episodes, 2)!.episodeId, 102);
    });

    test('标题无集数时按数组下标回退', () {
      const plain = [
        DandanEpisode(episodeId: 201, episodeTitle: '正片'),
        DandanEpisode(episodeId: 202, episodeTitle: '正片'),
      ];
      expect(findMatchingEpisode(plain, 2)!.episodeId, 202);
    });

    test('越界 → null', () {
      expect(findMatchingEpisode(episodes, 99), isNull);
      expect(findMatchingEpisode(const [], 1), isNull);
    });
  });

  // ── 按当前视频文件名定位（网络弹幕面板「展开自动定位到当前集」）──────
  group('locateCurrentEpisode', () {
    const episodes = [
      DandanEpisode(episodeId: 101, episodeTitle: '第01话 起点'),
      DandanEpisode(episodeId: 102, episodeTitle: '第02话 前进'),
      DandanEpisode(episodeId: 103, episodeTitle: '第03话 终点'),
    ];

    test('从文件名解析集数并命中下标', () {
      final loc = locateCurrentEpisode('[Group] Anime - 02 [1080p].mkv', episodes);
      expect(loc.index, 1);
      expect(loc.number, 2);
      expect(loc.message, isNull);
    });

    test('第 1 集命中下标 0（不能把 0 当"未命中"）', () {
      final loc = locateCurrentEpisode('第01话.mp4', episodes);
      expect(loc.index, 0);
      expect(loc.message, isNull);
    });

    test('文件名无集数 → 未命中 + 提示可用输入框', () {
      final loc = locateCurrentEpisode('Anime 合集.mkv', episodes);
      expect(loc.index, -1);
      expect(loc.number, isNull);
      expect(loc.message, contains('未能从文件名识别集数'));
    });

    test('集数超出范围 → 未命中 + 提示未找到', () {
      final loc = locateCurrentEpisode('第99话.mkv', episodes);
      expect(loc.index, -1);
      expect(loc.number, 99);
      expect(loc.message, contains('未找到第 99 集'));
    });

    test('文件名为空/未提供 → 静默不提示（用户只是没在放视频）', () {
      for (final name in [null, '']) {
        final loc = locateCurrentEpisode(name, episodes);
        expect(loc.index, -1);
        expect(loc.message, isNull, reason: '不该给用户一条无意义的提示');
      }
    });

    test('标题无集数时按数组下标回退（与切集自动匹配同语义）', () {
      const plain = [
        DandanEpisode(episodeId: 201, episodeTitle: '正片'),
        DandanEpisode(episodeId: 202, episodeTitle: '正片'),
      ];
      final loc = locateCurrentEpisode('02.mkv', plain);
      expect(loc.index, 1);
    });
  });
}
