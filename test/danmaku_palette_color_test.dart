import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/danmaku_palette_color.dart';

/// 弹幕调色板取色器测试：空回退、单色、随机取自已选、相邻不重色、换色重置。
void main() {
  test('空调色板取不到色（调用方回落原色）', () {
    final p = DanmakuPalettePicker(colors: const []);
    expect(p.next(), isNull);
    expect(p.length, 0);
  });

  test('只选 1 种：恒返回它（相邻去重无从谈起）', () {
    final p = DanmakuPalettePicker(colors: const [0xFF00FF00]);
    expect(p.next(), 0xFF00FF00);
    expect(p.next(), 0xFF00FF00);
  });

  test('多色：随机取自已选集合', () {
    final colors = [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00];
    final p = DanmakuPalettePicker(colors: colors, random: Random(7));    for (var i = 0; i < 200; i++) {
      expect(colors, contains(p.next()));
    }
  });

  test('多色：相邻两条不重色（连续抽 500 次）', () {
    final p = DanmakuPalettePicker(
      colors: const [0xFF0000, 0x00FF00, 0x0000FF],
      random: Random(1),
    );
    int? last;
    for (var i = 0; i < 500; i++) {
      final c = p.next();
      expect(c, isNotNull);
      expect(c, isNot(last), reason: '第 $i 条与上一条同色');
      last = c;
    }
  });

  test('多色：抽到重复色之间的间隔不会退化成只剩两色轮换', () {
    // 统计分布：三种色在 300 次里都应出现（不是永远只抽 candidates 的第一项）
    final p = DanmakuPalettePicker(
      colors: const [0xFF0000, 0x00FF00, 0x0000FF],
      random: Random(42),
    );
    final counts = <int, int>{};
    for (var i = 0; i < 300; i++) {
      final c = p.next()!;
      counts[c] = (counts[c] ?? 0) + 1;
    }
    expect(counts.keys.length, 3);
    for (final v in counts.values) {
      expect(v, greaterThan(50));
    }
  });

  test('换调色板（updateColors）重置上一条颜色记忆', () {
    final p = DanmakuPalettePicker(
      colors: const [0xFF0000, 0x00FF00],
      random: Random(3),
    );
    final first = p.next();
    // 换成新集合后，第一次抽色不受旧集合的上一条影响：单色必然抽到它
    p.updateColors(const [0x123456]);
    expect(first, isNot(0x123456));
    expect(p.next(), 0x123456);
  });
}
