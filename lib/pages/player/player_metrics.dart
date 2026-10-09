/// 播放页左侧人体工学对齐常量（工作.md 第 19 点）。
/// 顶栏返回箭头、底栏进度条开端、「下一集」按钮左缘、时间文本左缘
/// 统一对齐到同一 x（横屏/竖屏播放页共用，portrait 底栏同步引用）。
library;

import 'dart:math' as math;

const double kPlayerLeftInset = 20;

/// 底栏**轨道级**对齐 x（B4/P1-6：横竖屏两页共用同一基准）。
///
/// [kPlayerLeftInset] 是「行」的左内边距（20），而进度条轨道、章节名、
/// 「下一集」**图标**三者要对齐的是 28：竖屏行内「下一集」是 38 宽盒居中
/// 放 26 号图标，故行内边距取 [kPlayerNextRowLeftPadding]（22）后图标左缘
/// 正好落在 28；横屏行内「下一集」图标外再包 8dp padding，行内边距仍是
/// [kPlayerLeftInset]（20 + 8 = 28）。两页的 PlayerSeekBar 都传
/// `trackLeftInset: kPlayerTrackLeftInset`，章节名行左内边距同值——
/// 三处若各写各的数字就会再次漂移（体检报告 P1-6 的原始症状）。
const double kPlayerTrackLeftInset = 28;

/// 竖屏底栏操作行左内边距：38 宽「下一集」盒内 26 号图标居中，
/// 22 + (38 - 26) / 2 = [kPlayerTrackLeftInset]（见上）。
const double kPlayerNextRowLeftPadding = 22;

/// 播放页自动隐藏时长（横竖屏共用）：控制层无操作后收起、锁定后呼出的
/// 解锁按钮同样在该时长后收回。
///
/// 两处共用一个常量：它们都是「呼出后没人理就自己收回去」的同类行为，
/// 各写各的数字会出现「控制层已收起、解锁按钮还挂在屏幕上」的错位
/// （与 kPlayerTrackLeftInset 同一类漂移问题）。
const Duration kPlayerAutoHideDelay = Duration(seconds: 3);

/// 横屏控制栏图标按钮的触摸盒边长（「按钮大小 / 按钮间距」两个倍率共同决定）。
///
/// 公式：`max(图标 + 内边距×大小倍率×2, 44) + 内边距×大小倍率×(间距倍率-1)`
///
/// - 内边距**按左右两侧**算（原实现是 `Padding(all: p)`，22 + 13×2 = 48dp）；
/// - 下限 44 只兜「图标 + 两侧内边距」这部分，**不能把间距倍率也吃进去**：
///   早先写成 `max(图标 + 内边距×大小×间距, 44)`，默认倍率下间距那部分被
///   44 的兜底吞掉，调大「按钮间距」毫无效果；
/// - 间距倍率小于 1 时允许盒子收到 44 以下（图标本体仍按「按钮大小」缩放）。
double playerButtonHitSize({
  required double iconSize,
  required double basePadding,
  required double scale,
  required double spacingScale,
  double minHitSize = 44,
}) {
  final pad = basePadding * scale;
  return math.max(iconSize + pad * 2, minHitSize) + pad * (spacingScale - 1);
}
