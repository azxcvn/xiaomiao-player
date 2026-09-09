/// 弹幕合并（同内容跨时间窗聚合 + 计数）纯函数。
///
/// 与「弹幕去重」的分工（用户拍板语义）：
/// - **去重**（`danmaku_dedup.dart`，窗 5s）：**同一时间窗内**的相同内容只留
///   一条、不显示数量——解决「同一句话在几秒内被刷屏」；
/// - **合并**（本文件，窗 10s）：**跨时间**把一段内容里的相同弹幕聚成一条并
///   计数（渲染为 `文本 ×12`）——解决「同一句话被很多人发，屏幕上重复几十条」。
///
/// 两者判同都走 [normalizeDanmakuText]（小写/去空白/去标点/连续字符收敛），
/// 因此 `666`、`6 6 6`、`66666` 会被视为同一条。
///
/// **算法（一次线性扫描，O(n) 时间 / O(窗口内不同文本数) 空间）**：
/// 1. 按时间升序排序（输入无需有序）；
/// 2. 用「归一化文本 → 当前簇」哈希表，簇记录：代表条目 + 簇起始时间 + 计数；
/// 3. 同键新条目若距**簇起始时间**不超过 [windowSeconds] → 计数 +1（不再输出）；
///    否则先把上一簇落盘、再以本条开新簇；
/// 4. 结束时把所有簇落盘，按时间升序返回：计数 > 1 的簇带 [DanmakuEntry.count]，
///    计数 = 1 的原样返回。
///
/// **为什么不需要「找最多/第二多」**：每个归一化键各自累加自己的计数，一次扫描
/// 就得到全部频次，不存在排序/排名步骤——用户担心的算力开销在此消解（几十万条
/// 弹幕也只是一遍哈希查找）。
///
/// 簇锚定「首条时间」而非「上一条时间」：避免连续的重复把窗口无限向后拖长。
/// 纯函数、无 Flutter 依赖，可单测。
library;

import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/utils/danmaku_dedup.dart';

/// 默认合并时间窗（秒）：同内容弹幕在 10 秒内聚成一条并计数。
///
/// 取值依据：B站弹幕的「同一句话集体刷屏」通常持续几秒（远小于一集），
/// 10 秒足以覆盖一次爆发，又不至于把相隔较远的两拨弹幕误并成一条。
/// 后续若发现某些场景（如 OP 处长期重复的歌词弹幕）合并过度，可调小或做成档位。
const double kDanmakuMergeWindowSeconds = 10;

/// 合并结果的最小计数（1 = 保留全部条目但只有 ≥2 的显示计数）
const int kDanmakuMergeMinCount = 2;

/// 单条弹幕所属的合并簇（内部使用）
class _Cluster {
  _Cluster(this.entry, this.startTime) : count = 1;

  /// 簇的代表条目（首条）
  final DanmakuEntry entry;

  /// 簇起始时间（秒）
  final double startTime;

  /// 簇内条数
  int count;

  DanmakuEntry toEntry(int minCount) => count < minCount
      ? entry
      : DanmakuEntry(
          time: entry.time,
          mode: entry.mode,
          color: entry.color,
          text: entry.text,
          count: count,
          isColorful: entry.isColorful,
        );
}

/// 同内容跨时间窗聚合 + 计数（详见文件头算法说明）。
///
/// [windowSeconds] 为聚合窗口；[minCount] 为「多大计数才写回 count」，
/// 低于它的簇原样返回（默认 2）。
List<DanmakuEntry> mergeDanmakuByCount(
  List<DanmakuEntry> entries, {
  double windowSeconds = kDanmakuMergeWindowSeconds,
  int minCount = kDanmakuMergeMinCount,
}) {
  if (entries.length < 2) return List.of(entries);
  final sorted = List.of(entries)..sort((a, b) => a.time.compareTo(b.time));
  final clusters = <String, _Cluster>{};
  // 输出顺序 = 簇起始时间顺序（用列表按首次出现顺序落盘，最后再按时间排序）
  final flushed = <DanmakuEntry>[];

  for (final entry in sorted) {
    final key = normalizeDanmakuText(entry.text);
    if (key.isEmpty) {
      // 归一化后为空（纯标点/空白弹幕）：不参与合并，原样保留
      flushed.add(entry);
      continue;
    }
    final cluster = clusters[key];
    if (cluster == null) {
      clusters[key] = _Cluster(entry, entry.time);
      continue;
    }
    if (entry.time - cluster.startTime <= windowSeconds) {
      cluster.count++; // 窗口内同内容 → 计入当前簇
      continue;
    }
    // 超出窗口：上一簇落盘，本条开新簇
    flushed.add(cluster.toEntry(minCount));
    clusters[key] = _Cluster(entry, entry.time);
  }
  for (final cluster in clusters.values) {
    flushed.add(cluster.toEntry(minCount));
  }
  flushed.sort((a, b) => a.time.compareTo(b.time));
  return flushed;
}
