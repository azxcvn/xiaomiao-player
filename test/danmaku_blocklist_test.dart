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
  });
}
