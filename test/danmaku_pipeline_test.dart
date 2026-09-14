import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/services/danmaku_scheduler.dart';
import 'package:moumou/utils/danmaku_pipeline.dart';

DanmakuEntry _e(double time, String text, {int color = 0xFFFFFF}) =>
    DanmakuEntry(time: time, mode: 1, color: color, text: text);

/// 弹幕生效集流水线测试（P1-15 / P1-16 抽件）：
/// - 顺序固定「屏蔽词 → 合并 → 去重」；
/// - 对**全量**原始条目求值 → B 站分段流式加载下跨批次同内容聚合成同一个簇
///   （不再分裂成 ×3 + ×2），并可用 [DanmakuScheduler.replaceAll] 整体替换秒桶；
/// - 入参 record 可经 `compute` 跨 isolate（§7 坑表：闭包/参数不可发送会崩）。
void main() {
  group('流水线顺序与开关', () {
    test('开关全关：只有屏蔽词过滤，条目原样（计数仍为 1）', () {
      final out = effectiveDanmakuEntries(
        entries: [_e(1, 'aaa'), _e(2, 'bbb'), _e(3, 'aaa')],
        blockedKeywords: const [],
        merge: false,
        dedupe: false,
      );
      expect(out.length, 3);
      expect(out.every((e) => e.count == 1), isTrue);
    });

    test('屏蔽词生效：命中的整条剔除（忽略大小写/首尾空白）', () {
      final out = effectiveDanmakuEntries(
        entries: [_e(1, '前方高能'), _e(2, '好耶')],
        blockedKeywords: const [' 高能 '],
        merge: false,
        dedupe: false,
      );
      expect(out.map((e) => e.text).toList(), ['好耶']);
    });

    test('合并开启：跨时间窗同内容聚成一条并计数（保留首条时间）', () {
      final out = effectiveDanmakuEntries(
        entries: [_e(10, '666'), _e(11, '666'), _e(12, '666')],
        blockedKeywords: const [],
        merge: true,
        dedupe: false,
      );
      expect(out.length, 1);
      expect(out.single.count, 3);
      expect(out.single.time, 10);
      expect(out.single.displayText, '666 ×3');
    });

    test('去重开启：时间窗内相同内容只留首条、不计数', () {
      final out = effectiveDanmakuEntries(
        entries: [_e(10, '666'), _e(11, '666')],
        blockedKeywords: const [],
        merge: false,
        dedupe: true,
      );
      expect(out.length, 1);
      expect(out.single.count, 1);
    });

    test('合并先于去重：两个开关同时为真时先去重会吃掉计数，这里不会', () {
      final out = effectiveDanmakuEntries(
        entries: [_e(10, '666'), _e(11, '666'), _e(50, '666')],
        blockedKeywords: const [],
        merge: true,
        dedupe: true,
      );
      // 10/11s 聚成 ×2（同一时间窗），50s 超窗另成一条
      expect(out.length, 2);
      expect(out.first.count, 2);
      expect(out.last.count, 1);
    });

    test('空输入 / 全被屏蔽 → 空列表', () {
      expect(
        effectiveDanmakuEntries(
          entries: const [],
          blockedKeywords: const ['x'],
          merge: true,
          dedupe: true,
        ),
        isEmpty,
      );
      expect(
        effectiveDanmakuEntries(
          entries: [_e(1, 'x')],
          blockedKeywords: const ['x'],
          merge: true,
          dedupe: true,
        ),
        isEmpty,
      );
    });
  });

  group('跨批次全量重算（P1-15：B 站分段流式加载）', () {
    // 同一句「前方高能」被批次边界切开：批1 有 3 条、批2 有 2 条，
    // 5 条都落在同一个 10s 合并窗内。
    final batch1 = [_e(10.0, '前方高能'), _e(11.0, '前方高能'), _e(12.0, '前方高能')];
    final batch2 = [_e(13.0, '前方高能'), _e(14.0, '前方高能')];

    test('逐批求值会分裂（旧实现的问题：×3 + ×2）', () {
      List<DanmakuEntry> of(List<DanmakuEntry> b) => effectiveDanmakuEntries(
            entries: b,
            blockedKeywords: const [],
            merge: true,
            dedupe: false,
          );
      expect(of(batch1).single.count, 3);
      expect(of(batch2).single.count, 2);
    });

    test('全量求值聚成同一个簇 ×5（保留首条时间）', () {
      final out = effectiveDanmakuEntries(
        entries: [...batch1, ...batch2],
        blockedKeywords: const [],
        merge: true,
        dedupe: false,
      );
      expect(out.length, 1);
      expect(out.single.count, 5);
      expect(out.single.time, 10.0);
      expect(out.single.displayText, '前方高能 ×5');
    });

    test('追加 = 全量重算 + 秒桶整体替换：最终计数与一次性装载一致', () {
      final appendOnly = DanmakuScheduler();
      final raw = <DanmakuEntry>[];
      for (final batch in [batch1, batch2]) {
        raw.addAll(batch);
        appendOnly.replaceAll(effectiveDanmakuEntries(
          entries: raw,
          blockedKeywords: const [],
          merge: true,
          dedupe: false,
        ));
      }

      final oneShot = DanmakuScheduler();
      oneShot.replaceAll(effectiveDanmakuEntries(
        entries: [...batch1, ...batch2],
        blockedKeywords: const [],
        merge: true,
        dedupe: false,
      ));

      expect(appendOnly.danmakuCount, 1);
      expect(appendOnly.danmakuCount, oneShot.danmakuCount);
    });

    test('切一次开关（重算）结果不变：同一份数据只有一种呈现', () {
      final raw = [...batch1, ...batch2];
      List<DanmakuEntry> run({required bool merge}) =>
          effectiveDanmakuEntries(
            entries: raw,
            blockedKeywords: const [],
            merge: merge,
            dedupe: false,
          );
      // 合并关 → 5 条原样；合并开 → 1 条 ×5；再关 → 又是 5 条（幂等）
      expect(run(merge: false).length, 5);
      expect(run(merge: true).length, 1);
      expect(run(merge: false).length, 5);
      expect(run(merge: true).single.count, 5);
    });
  });

  group('isolate 入口', () {
    test('runDanmakuPipeline 与命名参数版结果一致', () {
      final request = (
        entries: [_e(1, 'a'), _e(2, 'a')],
        blockedKeywords: const ['b'],
        merge: true,
        dedupe: false,
      );
      final direct = effectiveDanmakuEntries(
        entries: request.entries,
        blockedKeywords: request.blockedKeywords,
        merge: request.merge,
        dedupe: request.dedupe,
      );
      final viaEntry = runDanmakuPipeline(request);
      expect(viaEntry.length, direct.length);
      expect(viaEntry.single.count, 2);
    });

    test('compute 可跨 isolate 调用（入参与返回值均可发送）', () async {
      final result = await compute(runDanmakuPipeline, (
        entries: [_e(1, '前方高能'), _e(2, '前方高能'), _e(3, '无关')],
        blockedKeywords: const ['无关'],
        merge: true,
        dedupe: false,
      ));
      expect(result.length, 1);
      expect(result.single.text, '前方高能');
      expect(result.single.count, 2);
    });
  });
}
