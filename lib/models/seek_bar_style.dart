/// 播放器进度条样式（播放器设置 → 章节进度条）。
///
/// **色标画法跟样式绑定**，不提供「轨道样式 + 色标样式」的自由组合：轨道粗细、
/// 拇指形状、跳段色带与章节节点的落法互相耦合，拆开就会得到一堆画不出来的
/// 组合（粗轨上贴 6dp 小圆点、细轨上塞满竖刻度）。每个样式一套固定画法，
/// 见 `player_seek_bar_painter.dart`。
///
/// 持久化用 [storageKey]（名字字符串，不按 index）：以后插入/调整枚举顺序
/// 不会把用户的存档打偏，未知值一律回落默认。
enum SeekBarStyle {
  /// 经典：2.5dp 细轨 + 实心圆拇指 + 章节小圆点 + 轨道内跳段色带（原有样式）
  classic('classic'),

  /// 分段块：轨道按章节切成块，播放进度与跳段颜色在块内填充，块缝即章节
  segmented('segmented'),

  /// 胶囊：11dp 粗轨 + 渐变已播 + 章节竖刻度 + 白心描边拇指
  capsule('capsule');

  const SeekBarStyle(this.storageKey);

  /// 存档用的字符串键（不要改，改了等于丢用户设置）
  final String storageKey;

  /// 存档字符串 → 样式；未知 / 空 / 类型不对 → [classic]（老版本没有这个键）
  static SeekBarStyle fromStorage(Object? raw) {
    for (final style in values) {
      if (style.storageKey == raw) return style;
    }
    return classic;
  }
}
