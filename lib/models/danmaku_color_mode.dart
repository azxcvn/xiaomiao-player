/// 弹幕颜色三态（issue #1 需求 5 的改良方案）。
///
/// 用户原始诉求是「加一个开关，关掉就全部用白色」——但那等于**否定弹幕文件
/// 自身的颜色信息**（B 站普通彩色弹幕、大会员渐变彩色弹幕全部失效）。本 App
/// 改为「保留原色为默认、提供覆盖能力」：关掉覆盖就回到弹幕原色，不销毁数据。
///
/// 三态互斥（单选），而非「随机色 + 指定色两个开关」——后者要额外定义
/// 「两个都开听谁的」，语义不清且用户难预期。
///
/// 生效优先级与渐变彩色弹幕的关系见 `services/danmaku_service.dart` 的
/// `_addEntry`：只有 [source] 模式保留 `isColorful`（会员粉蓝渐变）。
library;

import 'package:moumou/models/subtitle_track.dart';

enum DanmakuColorMode {
  /// 跟随弹幕自身颜色（默认）：XML `p` 第 4 位 / protobuf 字段 5，
  /// 并保留大会员渐变彩色弹幕。
  source('跟随弹幕颜色'),

  /// 随机渐变色：忽略文件颜色，按 HSV 色轮黄金角逐条着色
  /// （算法见 `utils/danmaku_random_color.dart`）。
  random('随机渐变色'),

  /// 指定单一颜色：所有弹幕统一用 [DanmakuSettings.colorValue]，
  /// 渐变彩色弹幕一并让位。
  fixed('指定颜色');

  final String label;
  const DanmakuColorMode(this.label);

  /// 从持久化 index 还原（越界/损坏回落 [source]，即历史默认行为）。
  static DanmakuColorMode fromIndex(int? index) {
    if (index != null && index >= 0 && index < DanmakuColorMode.values.length) {
      return DanmakuColorMode.values[index];
    }
    return DanmakuColorMode.source;
  }
}

/// mpv 颜色串 → 渲染层要的 `0xRRGGBB` 整数（丢掉 alpha）。
///
/// 弹幕渲染（canvas_danmaku）只接受不含 alpha 的 RGB，透明度由弹幕设置里的
/// 「不透明度」统一控制，所以这里刻意不带上 alpha 通道。
int mpvColorToRgbInt(String hex) {
  final c = mpvColorToRgba(hex);
  return (c.r << 16) | (c.g << 8) | c.b;
}
