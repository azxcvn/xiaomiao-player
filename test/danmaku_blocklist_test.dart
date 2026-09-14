import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/utils/danmaku_blocklist.dart';

/// 弹幕关键词屏蔽纯函数测试（架构 §4.11「屏蔽词」）。
void main() {
  group('matchesBlockedKeyword', () {
    test('空屏蔽词列表不命中', () {
      expect(matchesBlockedKeyword('你好', const []), isFalse);
    });

    test('子串包含命中', () {
      expect(matchesBlockedKeyword('前方高能预警', ['高能']), isTrue);
    });

    test('大小写不敏感', () {
      expect(matchesBlockedKeyword('ABC', ['abc']), isTrue);
      expect(matchesBlockedKeyword('abc', ['ABC']), isTrue);
    });

    test('忽略首尾空白', () {
      expect(matchesBlockedKeyword('  你好  ', ['你好']), isTrue);
    });

    test('空白关键词忽略', () {
      expect(matchesBlockedKeyword('你好', ['  ', '']), isFalse);
    });

    test('不包含不命中', () {
      expect(matchesBlockedKeyword('你好', ['再见']), isFalse);
    });
  });

  group('filterBlockedDanmaku', () {
    final entries = [
      const DanmakuEntry(time: 1, mode: 1, color: 0xFFFFFF, text: '666'),
      const DanmakuEntry(time: 2, mode: 1, color: 0xFFFFFF, text: '前方高能'),
      const DanmakuEntry(time: 3, mode: 1, color: 0xFFFFFF, text: '哈哈哈哈'),
    ];

    test('屏蔽词为空原样返回', () {
      final out = filterBlockedDanmaku(entries, const []);
      expect(out.length, 3);
    });

    test('命中词被过滤', () {
      final out = filterBlockedDanmaku(entries, ['高能']);
      expect(out.map((e) => e.text).toList(), ['666', '哈哈哈哈']);
    });

    test('多个屏蔽词都生效', () {
      final out = filterBlockedDanmaku(entries, ['666', '哈']);
      expect(out.map((e) => e.text).toList(), ['前方高能']);
    });

    test('全部为空白词 → 视为不过滤（与 matchesBlockedKeyword 一致）', () {
      final out = filterBlockedDanmaku(entries, ['  ', '']);
      expect(out.length, 3);
    });
  });

  // P1-16：批量过滤前把关键词表归一化一次，避免「逐条弹幕 × 逐个关键词」
  // 重复 trim/toLowerCase。归一化语义必须与逐条判定完全一致。
  group('normalizeBlockedKeywords / matchesNormalizedKeyword', () {
    test('去首尾空白 + 转小写 + 丢弃空词 + 去重（保序）', () {
      expect(
        normalizeBlockedKeywords([' 高能 ', 'ABC', 'abc', '', '   ', '哈']),
        ['高能', 'abc', '哈'],
      );
    });

    test('归一化表可直接复用判定（等价于逐条 matchesBlockedKeyword）', () {
      final normalized = normalizeBlockedKeywords([' 高能 ', 'ABC']);
      const texts = ['前方高能', 'abc 弹幕', '普通弹幕', '   '];
      for (final text in texts) {
        expect(
          matchesNormalizedKeyword(text, normalized),
          matchesBlockedKeyword(text, [' 高能 ', 'ABC']),
          reason: text,
        );
      }
    });

    test('空白文本不命中', () {
      expect(matchesNormalizedKeyword('   ', normalizeBlockedKeywords(['x'])),
          isFalse);
      expect(matchesNormalizedKeyword('x', const []), isFalse);
    });
  });
}
