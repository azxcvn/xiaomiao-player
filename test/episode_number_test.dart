import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/episode_number.dart';

/// 文件名集数解析（`utils/episode_number.dart`）的表驱动测试。
///
/// 正样本覆盖：显式标记（第 N 话 / SxxExx / EPxx）、`- 03` 与 `[03]` 两种最常见
/// 的字幕组写法、多括号组连排、小数集、v2 修订；
/// 负样本明确断言 **null**：年份、分辨率、区间合集、特别篇、只有季数、超上限 ——
/// 这些是"猜错比不猜更糟"的场景（胶囊显示错的集数会让人选错文件）。
void main() {
  group('显式集数标记', () {
    const cases = <String, double>{
      '第01话.mp4': 1,
      '第12集.mkv': 12,
      '第 3 话.mkv': 3,
      '第01話.mkv': 1,
      '第一话.mp4': 1,
      '第十二集.mp4': 12,
      '第二十三话.mp4': 23,
      'S01E01.mkv': 1,
      's02e05.mp4': 5,
      'EP01.mkv': 1,
      'ep12.mp4': 12,
      'Ep.07.mkv': 7,
      'Episode 3.mkv': 3,
      '[E03].srt': 3,
      // 4 位集数（千集长篇）照常支持
      '第1123集.mp4': 1123,
      '[Group] 番名 第1123集 [1080p].xml': 1123,
    };
    cases.forEach((name, expected) {
      test(name, () => expect(extractEpisodeNumber(name), expected));
    });
  });

  group('数字 token（- 03 / [03] / 裸数字）', () {
    const cases = <String, double>{
      '01.mkv': 1,
      '12.mkv': 12,
      '01 - Title.mkv': 1,
      '[Group] Anime - 01 [1080p].mkv': 1,
      'Anime - 07.mkv': 7,
      'Anime_12.5.mkv': 12.5,
      'Anime 01v2.mkv': 1,
      'Anime【02】.mkv': 2,
      '03 .mkv': 3,
      ' 1.mkv': 1,
      // 多个方括号标签连排（旧实现只允许「集数后最多跟一个括号组」→ 识别不出）
      '[Group][Anime][03v2][1080p].mkv': 3,
      '[sweetSub][番名][第03话][1080p][简繁].xml': 3,
      // 集数夹在中间、后面还跟着副标题（旧实现识别不出）
      '[Group] 番名 - 03 - 副标题 [1080p].ass': 3,
      // 标题里也带数字：`- 03` 优先于裸数字
      '[Group] Anime 2 - 03.mkv': 3,
      '86 - 03.mkv': 3,
      // 无显式标记、但真正的数字被技术标签包围
      '[LoliHouse] 番名 - 12.5 [WebRip 1080p HEVC-10bit AAC ASSx2].ass': 12.5,
      // anitomy 官方示例（年份、v2、校验码、技术标签全齐）
      '[TaigaSubs]_Toradora!_(2008)_-_01v2_-_Tiger_and_Dragon_[1080p_H.264_FLAC][BAD7A16A].mkv':
          1,
    };
    cases.forEach((name, expected) {
      test(name, () => expect(extractEpisodeNumber(name), expected));
    });
  });

  group('完整路径 / 空白容错', () {
    const cases = <String, double>{
      '/storage/emulated/0/Download/1.mp4': 1,
      '/storage/emulated/0/Movies/2.mkv': 2,
      'smb://nas/anime/03.mkv': 3,
      r'C:\Videos\4.mp4': 4,
      '/storage/emulated/0/Download/第05话.mp4': 5,
      '/storage/emulated/0/Anime/[Group] Show - 06 [1080p].mkv': 6,
      '/storage/emulated/0/Download/ 2.mp4': 2,
    };
    cases.forEach((name, expected) {
      test(name, () => expect(extractEpisodeNumber(name), expected));
    });

    test('路径分隔符是标题一部分时按显式标记兜底', () {
      expect(extractEpisodeNumber('Show 第1话/ep.mkv'), 1);
    });
  });

  group('解析不出来就是 null（宁缺勿错）', () {
    const cases = <String>[
      '',
      'Movie.mkv',
      '剧场版.mkv',
      'Anime 合集.mkv',
      '[Group] 番名 [01-12][1080p][合集].mkv',
      // 日期：2024 是年份，10/01 是区间
      '2024-10-01 番名.mkv',
      '/storage/emulated/0/2024/Show.mkv',
      '/Movies/1080p/Movie.mkv',
      'Anime 1080p.mkv',
      '[Group] Anime [1080p][x264][10bit].mkv',
      // 只有季数，没有集数
      '[Group] Anime [S2].mkv',
      '[Group] 番名 第二季 [1080p].mkv',
      // 特别篇 / 片头片尾
      '[Group] Anime [OVA].mkv',
      '[Group] Anime [NCED].mkv',
      '[Group] Anime - PV [1080p].mkv',
      // 集数不合法
      '第0集.mkv',
      '第10000集.mkv',
      // 分辨率数字不当集数
      '[Group] Anime - [1080].mkv',
      'Anime [720].mkv',
    ];
    for (final name in cases) {
      test(name.isEmpty ? '(空串)' : name, () {
        expect(extractEpisodeNumber(name), isNull);
      });
    }
  });

  group('上限', () {
    test('9999 以内可用', () {
      expect(extractEpisodeNumber('第9999集.mkv'), 9999);
    });

    test('超过上限当编号处理', () {
      expect(extractEpisodeNumber('第10000集.mkv'), isNull);
      expect(extractEpisodeNumber('12345.mkv'), isNull);
    });
  });
}
