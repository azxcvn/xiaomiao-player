/// 弹幕生效集流水线（屏蔽词 → 合并 → 去重）——纯函数 + 后台 isolate 入口。
///
/// **为什么单独成件（P1-15 / P1-16）**：这条链原先写在
/// `DanmakuController._effectiveEntries` 里，只能同步跑在主 isolate——
/// 合并/去重各含一次全量 `sort` + 逐条文本归一化，10 万条量级会卡住 UI；
/// 而且 B 站分段流式加载时它只对**单个批次**求值，跨批次的同内容聚合不成簇，
/// 计数分裂成 `×3`＋`×2`（切换开关时又按全量重算，同一份数据两种呈现）。
/// 抽成纯函数后：① 装载/追加/开关变化一律对**全量原始条目**求值；
/// ② 可经 `compute` 整体丢进后台 isolate（返回值是纯 `List<DanmakuEntry>`，
/// `DanmakuEntry` 无原生资源，天然可跨 isolate）。
///
/// **顺序固定为「屏蔽词 → 合并 → 去重」**：合并与去重在 `DanmakuSettings`
/// 层互斥（语义冲突：去重丢弃重复条目、合并要统计重复条目），所以实际最多
/// 命中一条分支；仍按此顺序写死，保证任何情况下合并都先于去重执行——先跑
/// 去重会把合并需要的计数信息吃掉。
///
/// 纯函数、无 Flutter 依赖（`compute` 的调用在服务层），可单测。
library;

import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/utils/danmaku_blocklist.dart';
import 'package:moumou/utils/danmaku_dedup.dart';
import 'package:moumou/utils/danmaku_merge.dart';

/// 流水线入参（`compute` 只能传一个参数，故打成一条 record）。
///
/// 只含可跨 isolate 发送的纯值：条目列表 + 屏蔽词 + 两个开关。设置单例
/// （`DanmakuSettings`）是 ChangeNotifier，**不能**跨 isolate 读取，调用方
/// 必须先把值快照出来。
typedef DanmakuPipelineRequest = ({
  List<DanmakuEntry> entries,
  List<String> blockedKeywords,
  bool merge,
  bool dedupe,
});

/// 对**全量原始条目**求生效集：先剔除命中屏蔽词的弹幕（屏蔽词为空则原样），
/// 再按合并开关做「跨时间窗同内容聚合计次」，最后按去重开关合并短窗重复。
///
/// 原始条目不会被修改（两个子算法各自复制一份再排序）；返回新列表。
List<DanmakuEntry> effectiveDanmakuEntries({
  required List<DanmakuEntry> entries,
  required List<String> blockedKeywords,
  required bool merge,
  required bool dedupe,
}) {
  final filtered = filterBlockedDanmaku(entries, blockedKeywords);
  final merged = merge ? mergeDanmakuByCount(filtered) : filtered;
  if (!dedupe) return merged;
  return dedupeDanmakuEntries(merged);
}

/// `compute` 入口（**必须是顶层函数**才能跨 isolate 调用）。
List<DanmakuEntry> runDanmakuPipeline(DanmakuPipelineRequest request) =>
    effectiveDanmakuEntries(
      entries: request.entries,
      blockedKeywords: request.blockedKeywords,
      merge: request.merge,
      dedupe: request.dedupe,
    );
