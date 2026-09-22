import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:moumou/services/wallpaper_settings.dart';

/// 壁纸渲染层：铺在**内容之下**。
///
/// 由两处使用，且必须是同一套渲染代码（否则调整页预览与实机不一致）：
/// - [AppFrame]：实机渲染，参数取自 [WallpaperSettings]；
/// - `WallpaperEditorPage`：调整页预览框，参数取自页面内的临时状态。
///
/// 结构自下而上（对齐参考实现 mpvRx 的 `AppWallpaperHost`）：
/// 1. 壁纸图（「适应」模式先垫一层同图虚化副本填留边）；
/// 2. 固定遮罩：深色主题黑 18% / 浅色主题白 30%——不随透明度滑杆变化，
///    作用是在任何图上都保住文字可读性。
///
/// 底色不在这里铺（调用方负责）：实机由 [AppFrame] 铺，预览框由自己的
/// `surfaceContainerLowest` 容器铺。
class WallpaperLayer extends StatelessWidget {
  /// 图片绝对路径
  final String path;
  final WallpaperScaleMode scaleMode;
  final double scale;
  final double offsetX;
  final double offsetY;

  /// 模糊强度（滑杆量纲 0–40，内部按 [WallpaperSettings.blurSigmaFactor] 换算）
  final double blur;

  /// 图片自身不透明度（0–1）
  final double opacity;

  const WallpaperLayer({
    super.key,
    required this.path,
    this.scaleMode = WallpaperScaleMode.fit,
    this.scale = WallpaperSettings.defaultScale,
    this.offsetX = WallpaperSettings.defaultOffset,
    this.offsetY = WallpaperSettings.defaultOffset,
    this.blur = WallpaperSettings.defaultBlur,
    this.opacity = WallpaperSettings.defaultOpacity,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final file = File(path);
    final safeOpacity = opacity.clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 「适应」模式的留边用同图虚化副本填（照抄 mpvRx：Crop + 1.12 倍 +
          // 72% 透明 + 固定 28 模糊，且不参与缩放/位移）；「填充」已铺满，不需要
          if (scaleMode == WallpaperScaleMode.fit)
            _image(
              file: file,
              fit: BoxFit.cover,
              scale: WallpaperSettings.fitBackdropScale,
              offsetX: 0,
              offsetY: 0,
              opacity: WallpaperSettings.fitBackdropOpacity * safeOpacity,
              blur: WallpaperSettings.fitBackdropBlur,
            ),
          _image(
            file: file,
            fit: scaleMode == WallpaperScaleMode.fit
                ? BoxFit.contain
                : BoxFit.cover,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY,
            opacity: safeOpacity,
            blur: blur,
          ),
          // 固定遮罩（深色主题压黑 / 浅色主题提白）
          ColoredBox(
            color: isDark
                ? Colors.black.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.30),
          ),
        ],
      ),
    );
  }

  /// 单层壁纸图：解码降采样 → 模糊 → 透明度 → 缩放/位移。
  ///
  /// 位移公式 `offset × 容器尺寸 × offsetTravel` 与调整页的手势/滑杆严格互逆
  /// （见 `wallpaper_editor_page.dart`），两边共用 [WallpaperSettings.offsetTravel]。
  Widget _image({
    required File file,
    required BoxFit fit,
    required double scale,
    required double offsetX,
    required double offsetY,
    required double opacity,
    required double blur,
  }) {
    Widget image = Image(
      // ResizeImage：按最长边降采样解码（4000×3000 全尺寸解码约 48MB RGBA，
      // 铺满手机屏根本用不到）。allowUpscaling=false：小图不放大。
      image: ResizeImage(
        FileImage(file),
        width: WallpaperSettings.decodeMaxDimension,
        allowUpscaling: false,
      ),
      fit: fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      // 文件损坏 / 不是图片时静默不画（此时露出调用方铺的底色），
      // 不弹红框、不把异常抛给 FlutterError
      errorBuilder: (context, _, _) => const SizedBox.shrink(),
    );

    if (blur > 0) {
      final sigma = blur * WallpaperSettings.blurSigmaFactor;
      image = ImageFiltered(
        // TileMode.clamp：否则模糊会把边缘往外扩成半透明，屏幕四周出现暗边
        imageFilter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
        child: image,
      );
    }

    if (opacity < 1) {
      // Opacity 在 1.0 时会跳过合成层，所以只在 <1 时套
      image = Opacity(opacity: opacity, child: image);
    }

    if (scale != 1 || offsetX != 0 || offsetY != 0) {
      Widget transformed = image;
      if (scale != 1) {
        transformed = Transform.scale(scale: scale, child: transformed);
      }
      if (offsetX != 0 || offsetY != 0) {
        // FractionalTranslation：按**自身尺寸的比例**平移，等价于 mpvRx 的
        // `translation = offset × 容器尺寸 × 0.35`（图铺满容器，自身尺寸即容器尺寸），
        // 且**不需要 LayoutBuilder**。
        //
        // 这里原先用 LayoutBuilder 取容器尺寸，结果在路由的 Zoom 转场下每帧抛
        // 「RenderBox was not laid out: _RenderLayoutBuilder」——布局被打断后子树
        // 再也没被 layout，异常经 widget inspector 的结构化上报序列化整棵诊断树，
        // 主线程直接 100% 打转、界面卡死（真机日志实测）。绝不要再引入 LayoutBuilder。
        transformed = FractionalTranslation(
          translation: Offset(
            offsetX * WallpaperSettings.offsetTravel,
            offsetY * WallpaperSettings.offsetTravel,
          ),
          child: transformed,
        );
      }
      image = transformed;
    }

    return image;
  }
}
