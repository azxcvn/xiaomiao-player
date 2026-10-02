import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/custom_subtitle_parser.dart';

/// 自定义字幕源解析测试（方案 A）：
/// - 地址模板展开（`{name}` 占位 / 无占位符拼末尾 / URL 编码）；
/// - 响应自动嗅探（顶层数组 / data / data 里再套一层 / results）；
/// - 字段名变体、语言数组、格式缺省从地址推断；
/// - 坏数据：非 JSON、找不到列表、缺地址的条目一律丢弃；不猜、不静默当空。
void main() {
  group('expandSubtitleUrlTemplate（地址模板）', () {
    test('{name} 占位替换为 URL 编码后的片名', () {
      expect(
        expandSubtitleUrlTemplate('https://x.test/s?name={name}', '你的名字'),
        'https://x.test/s?name=%E4%BD%A0%E7%9A%84%E5%90%8D%E5%AD%97',
      );
    });

    test('没有占位符 → 片名拼到末尾（适配 ...?name= 这类地址）', () {
      expect(
        expandSubtitleUrlTemplate('https://x.test/s?name=', 'abc def'),
        'https://x.test/s?name=abc+def',
      );
    });

    test('空模板返回空串（调用方据此报「地址无效」）', () {
      expect(expandSubtitleUrlTemplate('   ', 'x'), isEmpty);
      expect(isUsableSubtitleUrlTemplate('   '), isFalse);
      expect(isUsableSubtitleUrlTemplate('https://x.test'), isTrue);
    });
  });

  group('parseCustomSubtitleResponse（自动嗅探）', () {
    test('顶层数组', () {
      final list = parseCustomSubtitleResponse('''
        [
          {"name": "Movie.zh.srt", "url": "https://cdn.test/a.srt", "language": "zh", "ext": ".srt"},
          {"title": "Movie.en.ass", "link": "https://cdn.test/b.ass", "languages": ["en", "zh"], "format": "ass"}
        ]
      ''');
      expect(list.length, 2);
      expect(list[0].name, 'Movie.zh.srt');
      expect(list[0].language, 'zh');
      expect(list[0].format, 'srt');
      // 来源在服务层存 ASCII 稳定值 `custom`，显示名由 UI 侧取 l10n
      expect(list[0].source, 'custom');
      // 语言数组用 ASCII 逗号拼接（纯函数层拿不到 l10n，见阶段 8 全角标点收口）
      expect(list[1].language, 'en, zh');
      expect(list[1].format, 'ass');
    });

    test('包一层 data（含 code 字段的常见形状）', () {
      final list = parseCustomSubtitleResponse(
        '{"code":0,"data":[{"name":"A","url":"https://cdn.test/a.srt","ext":"srt"}]}',
      );
      expect(list.single.url, 'https://cdn.test/a.srt');
    });

    test('data 里再套一层列表键', () {
      final list = parseCustomSubtitleResponse(
        '{"data":{"subtitles":[{"title":"A","download_url":"https://cdn.test/a.srt"}]}}',
      );
      expect(list.single.name, 'A');
    });

    test('results / items 等列表键', () {
      expect(
        parseCustomSubtitleResponse(
          '{"results":[{"name":"A","url":"https://cdn.test/a.srt"}]}',
        ).length,
        1,
      );
      expect(
        parseCustomSubtitleResponse(
          '{"items":[{"name":"A","url":"https://cdn.test/a.srt"}]}',
        ).length,
        1,
      );
    });

    test('格式缺省时从地址后缀推断，仍不认识则 txt', () {
      final list = parseCustomSubtitleResponse(
        '[{"name":"A","url":"https://cdn.test/a.ASS?x=1"},'
        '{"name":"B","url":"https://cdn.test/b.bin"}]',
      );
      expect(list[0].format, 'ass');
      expect(list[1].format, 'txt');
    });

    test('smi / sbv / ttml 等冷门但真实存在的格式原样保留（真机源会回 .smi）', () {
      final list = parseCustomSubtitleResponse(
        '[{"name":"A","url":"https://cdn.test/a.smi","ext":"smi"},'
        '{"name":"B","url":"https://cdn.test/b.sbv"},'
        '{"name":"C","url":"https://cdn.test/c.xml","ext":"ttml"}]',
      );
      expect(list.map((e) => e.format), ['smi', 'sbv', 'ttml']);
    });

    test('缺地址 / 相对地址 / 非 http 的条目丢弃，其余保留', () {
      final list = parseCustomSubtitleResponse('''
        [
          {"name": "no-url"},
          {"name": "relative", "url": "/files/a.srt"},
          {"name": "ftp", "url": "ftp://cdn.test/a.srt"},
          {"name": "ok", "url": "https://cdn.test/a.srt"}
        ]
      ''');
      expect(list.length, 1);
      expect(list.single.name, 'ok');
    });

    test('同一直链去重（保留第一条）', () {
      final list = parseCustomSubtitleResponse(
        '[{"name":"A","url":"https://cdn.test/a.srt"},'
        '{"name":"A-copy","url":"https://cdn.test/a.srt"}]',
      );
      expect(list.length, 1);
      expect(list.single.name, 'A');
    });

    test('hashMatch 兼容两种字段名', () {
      final list = parseCustomSubtitleResponse(
        '[{"name":"A","url":"https://cdn.test/a.srt","isHashMatch":true},'
        '{"name":"B","url":"https://cdn.test/b.srt","hashMatch":true}]',
      );
      expect(list.map((e) => e.hashMatch), [true, true]);
    });

    test('非 JSON / 找不到列表 → 抛解析异常（不当成「没有字幕」）', () {
      expect(
        () => parseCustomSubtitleResponse('<html>not json</html>'),
        throwsA(isA<CustomSubtitleParseException>()),
      );
      expect(
        () => parseCustomSubtitleResponse('{"code":1,"msg":"bad key"}'),
        throwsA(isA<CustomSubtitleParseException>()),
      );
      expect(
        () => parseCustomSubtitleResponse('"just a string"'),
        throwsA(isA<CustomSubtitleParseException>()),
      );
    });

    test('列表为空 → 返回空表（这是合法的「没有字幕」）', () {
      expect(parseCustomSubtitleResponse('[]'), isEmpty);
      expect(parseCustomSubtitleResponse('{"data":[]}'), isEmpty);
    });
  });
}
