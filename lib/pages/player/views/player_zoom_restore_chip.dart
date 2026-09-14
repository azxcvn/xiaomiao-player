import 'package:flutter/material.dart';

/// 双指缩放后的「还原画面」胶囊（PiliPlus 同款，点击恢复 1:1）。
///
/// 横屏页与竖屏页共用（B4/D6：竖屏补双指缩放后同样需要还原入口），
/// 位置由调用方 Align（横屏 Alignment(0, 0.34)，竖屏同款）。
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
