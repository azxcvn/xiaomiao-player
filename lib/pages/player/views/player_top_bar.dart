import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/pages/player/player_metrics.dart';
import 'package:moumou/pages/player/views/player_pressable.dart';
import 'package:moumou/services/player_controls_settings.dart';

/// 顶栏：返回 + 标题 + 自定义槽位（最多 5 个，空槽隐藏）+ 固定「更多」按钮。
///
/// 槽位内容由用户在「更多 → 自定义」中自由放置/排序；
/// 「更多」按钮不可删除、不占槽位，是唯一的编辑入口。
///
/// 控制按钮背景：设置「播放器设置 → 按钮背景」开启后，返回/槽位/更多
/// 图标显示半透明圆底（与底栏倍速图标一致）；默认关闭 = 纯图标。
/// **背景开关只画不画底衬，不改按钮尺寸与间距**；尺寸由「播放器设置 →
/// 控制栏按钮大小」控制（横屏生效，竖屏参数固定）。
///
/// ⚠️ 顶部渐变压暗由页面层统一提供（「信息行 + 本顶栏」整体一个连续
/// 渐变，见 PlayerStatusBar 文件头注释）：本组件不再自带渐变，避免与
/// 上方信息行的渐变拼接产生「阴影在时间电量下方」的断层（用户反馈 v2）。
class PlayerTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final void Function(PlayerTopAction) onActionTap;

  const PlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onMore,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 顶栏已随控制设置自动重建（槽位变化/背景开关共用同一监听）
    final showBg = PlayerControlsSettings.instance.showButtonBackground;
    return SafeArea(
      // 横屏时挖孔在物理左/右侧，控制层不应消费左右 inset（见 AppFrame 约定）
      left: false,
      bottom: false,
      right: false,
      // 人体工学（工作.md 第 19 点）：返回按钮整体右移，与底栏进度条
      // 开端/下一集/时间文本对齐到同一 x（kPlayerLeftInset）
      child: Padding(
        padding: const EdgeInsets.only(left: kPlayerLeftInset),
          child: Row(
            children: [
              _TopIconButton(
                icon: Icons.arrow_back,
                tooltip: l10n.commonBack,
                showBackground: showBg,
                onPressed: onBack,
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 槽位区：随设置变化自动重建；空列表时不占任何空间
            ListenableBuilder(
              listenable: PlayerControlsSettings.instance,
              builder: (context, _) {
                final l10n = AppLocalizations.of(context);
                final actions = PlayerControlsSettings.instance.topActions;
                if (actions.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in actions)
                      _TopIconButton(
                        icon: a.icon,
                        tooltip: playerTopActionLabel(l10n, a),
                        showBackground: showBg,
                        onPressed: () => onActionTap(a),
                      ),
                  ],
                );
              },
            ),
            // 固定「更多」按钮（竖三点，更符合直觉），距右缘留间距
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TopIconButton(
                icon: Icons.more_vert,
                tooltip: l10n.commonMore,
                showBackground: showBg,
                onPressed: onMore,
              ),
            ),
            ],
          ),
        ),
      );
  }
}

/// 顶栏图标按钮：[showBackground] 只决定**底衬画不画**（半透明圆形），
/// 不改图标尺寸、不改触摸盒、不改按钮间距（历史问题：开启背景会把
/// 22 号图标 + 48dp 触摸盒换成 16 号图标 + 28dp 圆，按钮看着又小又挤）。
///
/// 尺寸由「播放器设置 → 控制栏按钮大小」（[PlayerControlsSettings.buttonScale]）
/// 统一控制，随设置实时重建。
class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool showBackground;
  final VoidCallback onPressed;

  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.showBackground,
    required this.onPressed,
  });

  /// 图标基准边长（= 「控制栏按钮大小」1.0 时的原尺寸）
  static const double _baseIconSize = 22;

  /// 图标外内边距基准（22 + 13×2 = 48dp 触摸目标，与原 IconButton 一致）
  static const double _basePadding = 13;

  /// 底衬直径比图标直径大的量（半透明圆比图标大一圈）
  static const double _bgPadding = 6;

  /// 触摸目标下限：缩放只影响视觉，不能让命中区小于 44dp
  static const double _minHitSize = 44;

  @override
  Widget build(BuildContext context) {
    final scale = PlayerControlsSettings.instance.buttonScale;
    final iconSize = _baseIconSize * scale;
    final pad = _basePadding * scale;
    final hit = math.max(iconSize + pad, _minHitSize);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: hit,
        height: hit,
        child: PlayerPressable(
          onTap: onPressed,
          child: Center(
            child: showBackground
                ? Container(
                    width: iconSize + _bgPadding * 2,
                    height: iconSize + _bgPadding * 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    // Center：不让圆底的 tight 约束把 Icon 的渲染盒撑到
                    // 圆底大小（否则图标盒尺寸随背景开关变，间距跟着变）
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
