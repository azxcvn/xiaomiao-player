import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/wyzie_models.dart';

/// Wyzie 字幕 API 数据模型 fromJson 测试（字段映射 / 容错 / 常量表完整性）。
void main() {
  test('WyzieSubtitle fromJson 完整解析 + 派生展示名/语言名', () {
    final sub = WyzieSubtitle.fromJson({
      'id': 'abc',
      'url': 'https://x/sub.srt',
      'format': 'srt',
      'encoding': 'utf-8',
      'language': 'en',
      'display': 'English',
      'source': 'opensubtitles',
      'fileName': 'Movie.Name.en.srt',
      'downloadCount': 42,
      'isHearingImpaired': true,
      'ai': true,
    });
    expect(sub, isNotNull);
    expect(sub!.id, 'abc');
    expect(sub.url, 'https://x/sub.srt');
    expect(sub.displayName, 'Movie.Name.en.srt');
    expect(sub.displayLanguage, 'English');
    expect(sub.downloadCount, 42);
    expect(sub.hearingImpaired, isTrue);
    expect(sub.ai, isTrue);
  });

  test('WyzieSubtitle url 缺失/空 → null（无效条目跳过）', () {
    expect(WyzieSubtitle.fromJson({'format': 'srt'}), isNull);
    expect(WyzieSubtitle.fromJson({'url': ''}), isNull);
  });

  test('WyzieSubtitle 数字 id 兜底转字符串 + releases 列表解析', () {
    final sub = WyzieSubtitle.fromJson({
      'url': 'https://x/a.srt',
      'id': 123,
      'releases': ['r1', 'r2'],
    });
    expect(sub!.id, '123');
    expect(sub.releases, ['r1', 'r2']);
  });

  test('WyzieSourcesResponse 解析 tiered/free/paid/key/available', () {
    final resp = WyzieSourcesResponse.fromJson({
      'sources': ['a'],
      'free': ['a'],
      'paid': ['b'],
      'tiered': [
        {'key': 'a', 'name': 'A', 'tier': 'free'},
        {'key': 'b', 'name': 'B', 'tier': 'paid', 'available': false},
      ],
      'allFree': false,
      'key': {'valid': true, 'type': 'pro'},
      'available': ['a'],
      'restricted': ['b'],
    });
    expect(resp.tiered.length, 2);
    expect(resp.tiered.first.isFree, isTrue);
    expect(resp.tiered.first.name, 'A');
    expect(resp.tiered.last.available, isFalse);
    expect(resp.free, ['a']);
    expect(resp.paid, ['b']);
    expect(resp.key?.valid, isTrue);
    expect(resp.key?.type, 'pro');
  });

  test('WyzieSourcesResponse 空响应容错', () {
    final resp = WyzieSourcesResponse.fromJson({});
    expect(resp.tiered, isEmpty);
    expect(resp.key, isNull);
  });

  test('WyzieSourceItem 缺 name 用 key 兜底', () {
    final item = WyzieSourceItem.fromJson({'key': 'bravo', 'tier': 'free'});
    expect(item!.name, 'bravo');
    expect(item.isFree, isTrue);
  });

  test('WyzieTmdbResult 解析', () {
    final r = WyzieTmdbResult.fromJson({
      'id': 123,
      'title': 'Inception',
      'releaseYear': '2010',
    });
    expect(r!.id, 123);
    expect(r.title, 'Inception');
    expect(r.releaseYear, '2010');
  });

  test('常量表：语言/格式/编码含默认值，来源兜底含 all', () {
    expect(wyzieLanguages['en'], 'English');
    expect(wyzieLanguages['zh'], 'Chinese');
    expect(wyzieFormats['srt'], 'SRT');
    expect(wyzieFormats['ass'], 'ASS');
    expect(wyzieEncodings['utf-8'], 'Unicode (UTF-8)');
    expect(wyzieFallbackSources['all'], '全部');
    expect(wyzieFallbackIsFree('charlie'), isTrue);
    expect(wyzieFallbackIsFree('bravo'), isFalse);
  });
}
