import 'package:flutter/material.dart';

/// 双指缩放后「还原画面」胶囊在调用方 Stack 里的**竖向位置**（`Align` 的 y 分量）。
///
/// 这个值只跟「中央控制簇（快退/播放/快进）的下沿」有关系，横竖屏共用同一份：
/// - 中央簇高 72（大播放键直径），屏幕几何中心即控件中心 → 其下沿约在
///   `+0.22`（16:9 横屏 ≈ +0.056 × 2）；
/// - 胶囊自身高约 44（20 图标 + 上下各 12 内边距）。实测（见
///   `test/player_zoom_restore_chip_test.dart`）0.60 时两者只差约 37dp，
///   在播放键圆形阴影的观感范围内仍显拥挤；0.64 时间距约 61dp，
///   **彻底离开播放按钮的阴影**，同时距底栏仍有余量、不越出屏幕下沿；
/// - 原值 0.34 时两者只差约 0.01 倍屏高，几乎贴住（用户反馈的重叠）。
///
/// 竖屏沿用同一数值：竖屏画面区更矮，但因为同样是「相对高度的比例」，
/// 胶囊与中央簇的相对间距保持一致。
const double kZoomRestoreChipAlignmentY = 0.64;

/// 双指缩放后的「还原画面」胶囊（PiliPlus 同款，点击恢复 1:1）。
///
/// 横屏页与竖屏页共用（B4/D6：竖屏补双指缩放后同样需要还原入口）。
/// **位置**用 [kZoomRestoreChipAlignmentY]；**显隐**由调用方跟随控制层
/// （FadeTransition + IgnorePointer），不再常驻屏幕。
class PlayerZoomRestoreChip extends StatelessWidget {
  final VoidCallback onTap;

  const PlayerZoomRestoreChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              '还原画面',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
