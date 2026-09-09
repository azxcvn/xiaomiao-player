/// 弹幕条目纯数据模型（时间/模式/颜色/文本 + 合并计数 + 会员彩色标记），
/// 来源为 B站 XML / 分段 protobuf 等。
library;

/// 单条弹幕（对齐 B站 XML `<d p="time,mode,fontsize,color,...">` 的数据面）。
///
/// 纯数据类（无逻辑、无依赖，可跨 isolate 发送——解析在后台 isolate 完成，
/// 结果通过 `compute` 回传）。
class DanmakuEntry {
  /// 出现时间（秒，浮点）
  final double time;

  /// B站弹幕模式：1 = 右到左滚动、4 = 底部、5 = 顶部、6 = 逆向、
  /// 7 = 高级、8 = 代码、9 = BAS；渲染映射见服务层（非 4/5 一律按滚动，
  /// 对齐 Kazumi `player_item.dart` 的 `_danmakuItemType`）
  final int mode;

  /// 颜色（十进制 24 位 RGB，如 16777215 = 白色）
  final int color;

  /// 弹幕文本（已反转义、去除首尾空白）
  final String text;

  /// 同内容合并计数（「弹幕合并」开启时由 `utils/danmaku_merge.dart` 写入；
  /// 1 = 未合并。渲染层按 `文本 ×N` 呈现，文本本身保持原样以便去重/屏蔽词判同）
  final int count;

  /// 是否为会员渐变彩色弹幕（B站 protobuf `DanmakuElem.colorful`
  /// == `VipGradualColor`；本地 XML 无此信息，恒 false）
  final bool isColorful;

  const DanmakuEntry({
    required this.time,
    required this.mode,
    required this.color,
    required this.text,
    this.count = 1,
    this.isColorful = false,
  });

  /// 所属秒桶（调度按秒分桶发射）
  int get timeSeconds => time.floor();

  /// 是否为合并条目（计数 > 1）
  bool get isMerged => count > 1;

  /// 渲染用显示文本：合并条目追加 ` ×N`（计数为 1 时与原文一致）
  String get displayText => isMerged ? '$text ×$count' : text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DanmakuEntry &&
          other.time == time &&
          other.mode == mode &&
          other.color == color &&
          other.text == text &&
          other.count == count &&
          other.isColorful == isColorful;

  @override
  int get hashCode => Object.hash(time, mode, color, text, count, isColorful);
}
