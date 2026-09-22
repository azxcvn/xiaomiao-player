import 'package:flutter/material.dart';
import 'package:moumou/services/wallpaper_settings.dart';

/// 壁纸生效时卡片底色的**不透明度**（0.35 = 35% 不透明，65% 透出壁纸）。
///
/// 这是唯一的调节旋钮：嫌太透/太实改这一个数（三个卡片组件共用）。
/// 选半透明而非全透明：亮壁纸 + 全透明底会让路径、大小这类次要文字糊掉。
const double kWallpaperCardOpacity = 0.35;

/// 壁纸生效时选中卡片的**主题色膜**不透明度。
///
/// 不能沿用「primary 14% 混在原底色上」的做法：原底色本身已经只剩 35% 不透明，
/// 再乘 14% 的 primary 几乎看不见，用户看不出自己选中了没有。
const double kWallpaperSelectedOpacity = 0.32;

/// 卡片底色：**壁纸生效时半透明**（露出壁纸），否则原样返回 [base]。
///
/// 只用于「列表 item 的卡片」——文件夹卡（`FolderCard`）、视频卡（`VideoCard`）、
/// 设置卡（`SettingsCard`）。这些组件是全仓列表项底色的唯一来源，改它们就覆盖了
/// 首页列表 / 树状、文件夹详情、网络存储浏览、历史记录、我的页与全部设置子页。
///
/// **不适用**于对话框、底部弹层、弹出菜单、胶囊导航栏、缩略图底板等：压在照片上
/// 会读不清，这些地方必须保持不透明（这是刻意的边界，不是漏改）。
Color wallpaperAwareCardColor(BuildContext context, Color base) {
  if (!WallpaperSettings.instance.active) return base;
  return base.withValues(alpha: kWallpaperCardOpacity);
}

/// 选中卡片的底色：壁纸模式下换成**半透明主题色膜**，否则用原来的混合色。
Color wallpaperAwareSelectedCardColor(BuildContext context, ColorScheme scheme) {
  if (!WallpaperSettings.instance.active) {
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.14),
      scheme.surfaceContainerLow,
    );
  }
  return scheme.primary.withValues(alpha: kWallpaperSelectedOpacity);
}
