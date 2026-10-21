import 'package:flutter/material.dart';
import 'package:moumou/services/wallpaper_settings.dart';

/// 卡片底色：**壁纸生效时半透明**（露出壁纸），否则原样返回 [base]。
///
/// 半透明度由用户在外观页「卡片背景透明度」控制
/// （[WallpaperSettings.cardOpacity]，默认 0.35）：0 = 全透明，1 = 完全不透明。
/// 旧版这里是写死的 0.35（检测到壁纸就强制降低），现在交给用户。
///
/// 只用于「列表 item 的卡片」——文件夹卡（`FolderCard`）、视频卡（`VideoCard`）、
/// 设置卡（`SettingsCard`）。这些组件是全仓列表项底色的唯一来源，改它们就覆盖了
/// 首页列表 / 树状、文件夹详情、网络存储浏览、历史记录、我的页与全部设置子页。
///
/// **不适用**于对话框、底部弹层、弹出菜单、胶囊导航栏、缩略图底板等：压在照片上
/// 会读不清，这些地方必须保持不透明（这是刻意的边界，不是漏改）。
Color wallpaperAwareCardColor(BuildContext context, Color base) {
  if (!WallpaperSettings.instance.active) return base;
  return base.withValues(alpha: WallpaperSettings.instance.cardOpacity);
}

/// 选中卡片的底色：壁纸模式下换成**同透明度的主题色膜**，否则用原来的混合色。
///
/// 不能沿用「primary 14% 混在原底色上」的做法：原底色本身已经半透明，再乘 14%
/// 的 primary 几乎看不见。这里用与普通卡片相同的不透明度（用户可调），靠颜色
/// 区分选中；选中态还有 primary 描边与勾选标记兜底。
Color wallpaperAwareSelectedCardColor(BuildContext context, ColorScheme scheme) {
  final settings = WallpaperSettings.instance;
  if (!settings.active) {
    return Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.14),
      scheme.surfaceContainerLow,
    );
  }
  return scheme.primary.withValues(alpha: settings.cardOpacity);
}
