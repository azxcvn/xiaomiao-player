import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/utils/danmaku_merge.dart';

/// 弹幕合并纯函数测试（跨时间窗同内容聚合 + 计数）：
/// - 窗口内相同内容聚成一条并计数，窗口外各自成簇；
/// - 簇锚定首条时间（不会被连续重复无限拖长）；
/// - 归一化判同（666 / 6 6 6 / 66666 视为同一条）；
/// - 输出按时间升序、不同文本各自计数、空归一化文本原样保留；
/// - 展示文本 `文本 ×N`、isColorful 透传、minCount / windowSeconds 可调。
void main() {
  DanmakuEntry e(
    double time,
    String text, {
    int mode = 1,
    int color = 0xFFFFFF,
    bool isColorful = false,
  }) =>
      DanmakuEntry(
        time: time,
        mode: mode,
        color: color,
        text: text,
        isColorful: isColorful,
      );

  group('基本聚合', () {
    test('空列表 / 单条原样返回', () {
      expect(mergeDanmakuByCount(const []), isEmpty);
      final one = [e(1, 'a')];
      expect(mergeDanmakuByCount(one), one);
      expect(mergeDanmakuByCount(one).single.count, 1);
    });

    test('窗口内相同内容合并为一条并计数', () {
      final merged = mergeDanmakuByCount([
        e(10.0, '前方高能'),
        e(11.5, '前方高能'),
        e(14.0, '前方高能'),
      ]);
      expect(merged.length, 1);
      expect(merged.single.text, '前方高能');
      expect(merged.single.count, 3);
      expect(merged.single.time, 10.0); // 保留首条时间
      expect(merged.single.displayText, '前方高能 ×3');
      expect(merged.single.isMerged, isTrue);
    });

    test('超出窗口：各自成簇且不计数', () {
      final merged = mergeDanmakuByCount([
        e(0, '哈哈'),
        e(11, '哈哈'), // 距首条 11s > 10s
      ]);
      expect(merged.length, 2);
      expect(merged.every((x) => x.count == 1), isTrue);
      expect(merged.first.displayText, '哈哈'); // 未合并 → 不追加计数
    });

    test('簇锚定首条：连续重复不会把窗口无限拖长', () {
      final merged = mergeDanmakuByCount([
        e(0, 'x'),
        e(9, 'x'), // 距首条 9s ≤ 10s → 并入
        e(15, 'x'), // 距首条 15s > 10s → 新簇（距上一条只有 6s 也不并入）
      ]);
      expect(merged.length, 2);
      expect(merged[0].count, 2);
      expect(merged[0].time, 0);
      expect(merged[1].count, 1);
      expect(merged[1].time, 15);
    });

    test('不同文本各自计数，互不影响', () {
      final merged = mergeDanmakuByCount([
        e(0, 'A'),
        e(1, 'B'),
        e(2, 'A'),
        e(3, 'B'),
        e(4, 'B'),
      ]);
      expect(merged.length, 2);
      final a = merged.firstWhere((x) => x.text == 'A');
      final b = merged.firstWhere((x) => x.text == 'B');
      expect(a.count, 2);
      expect(b.count, 3);
    });

    test('输出按时间升序（输入无序）', () {
      final merged = mergeDanmakuByCount([
        e(20, 'B'),
        e(5, 'A'),
        e(21, 'B'),
        e(6, 'A'),
      ]);
      expect(merged.map((x) => x.time).toList(), [5, 20]);
      expect(merged.map((x) => x.count).toList(), [2, 2]);
    });
  });

  group('归一化判同', () {
    test('666 / 6 6 6 / 66666 视为同一条', () {
      final merged = mergeDanmakuByCount([
        e(0, '666'),
        e(1, '6 6 6'),
        e(2, '66666'),
      ]);
      expect(merged.length, 1);
      expect(merged.single.count, 3);
      // 文本保持首条原文
      expect(merged.single.text, '666');
    });

    test('纯标点/空白弹幕（归一化后为空）原样保留且不参与合并', () {
      final merged = mergeDanmakuByCount([
        e(0, '!!!'),
        e(1, '???'),
        e(2, '!!!'),
      ]);
      expect(merged.length, 3);
      expect(merged.every((x) => x.count == 1), isTrue);
    });

    test('大小写/全角差异视为同一条', () {
      final merged = mergeDanmakuByCount([
        e(0, 'ABC'),
        e(1, 'abc'),
        e(2, 'ＡＢＣ'), // 全角
      ]);
      expect(merged.length, 1);
      expect(merged.single.count, 3);
    });
  });

  group('参数与透传', () {
    test('windowSeconds 可调（窗口缩小后不再合并）', () {
      final entries = [e(0, 'x'), e(6, 'x')];
      expect(mergeDanmakuByCount(entries).single.count, 2); // 默认 10s
      final tight = mergeDanmakuByCount(entries, windowSeconds: 5);
      expect(tight.length, 2);
    });

    test('minCount 高于簇内计数时返回原条目', () {
      final merged = mergeDanmakuByCount([
        e(0, 'x'),
        e(1, 'x'),
      ], minCount: 3);
      expect(merged.length, 1); // 仍被聚合（重复条目被吞掉）
      expect(merged.single.count, 1); // 但计数低于阈值 → 不写回 count
      expect(merged.single.displayText, 'x');
    });

    test('isColorful 透传到合并后的条目', () {
      final merged = mergeDanmakuByCount([
        e(0, 'x', isColorful: true),
        e(1, 'x', isColorful: false),
      ]);
      expect(merged.single.count, 2);
      expect(merged.single.isColorful, isTrue); // 取首条
    });

    test('mode / color 取首条', () {
      final merged = mergeDanmakuByCount([
        e(0, 'x', mode: 4, color: 0xFF0000),
        e(1, 'x', mode: 5, color: 0x00FF00),
      ]);
      expect(merged.single.mode, 4);
      expect(merged.single.color, 0xFF0000);
    });

    test('合并结果可再次合并（幂等：计数不翻倍）', () {
      final once = mergeDanmakuByCount([e(0, 'x'), e(1, 'x')]);
      expect(once.single.count, 2);
      final twice = mergeDanmakuByCount(once);
      expect(twice.length, 1);
      // 已合并条目再次进入合并：同键只剩它自己 → 保持原计数
      expect(twice.single.count, 2);
    });
  });

  group('DanmakuEntry 展示字段', () {
    test('count=1 时 displayText 等于原文、isMerged 为 false', () {
      expect(e(0, 'hi').displayText, 'hi');
      expect(e(0, 'hi').isMerged, isFalse);
    });

    test('count>1 时 displayText 追加 ×N', () {
      const entry = DanmakuEntry(time: 0, mode: 1, color: 0, text: 'hi', count: 7);
      expect(entry.displayText, 'hi ×7');
      expect(entry.isMerged, isTrue);
    });

    test('相等性包含 count / isColorful', () {
      expect(e(0, 'x'), e(0, 'x'));
      expect(e(0, 'x'), isNot(const DanmakuEntry(
        time: 0, mode: 1, color: 0xFFFFFF, text: 'x', count: 2)));
      expect(e(0, 'x', isColorful: true), isNot(e(0, 'x')));
    });
  });
}
