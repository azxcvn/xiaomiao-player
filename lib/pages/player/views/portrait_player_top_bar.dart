import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/pages/player/player_metrics.dart';
import 'package:moumou/pages/player/views/player_pressable.dart';
import 'package:moumou/services/player_controls_settings.dart';

/// 竖屏播放页顶栏：两行布局。
///
/// - 第一行：返回 + 标题（弹性）；
/// - 第二行：自定义槽位（**最多 5 个**）+ 固定「更多」按钮，共 6 个按钮
///   **横向均匀分布**（与横屏一致支持 5 槽位，避免横竖切换丢槽位；
///   控制栏从标题行拆出、另起一行）。
///
/// 返回按钮左缘与底栏进度条开端/时间/下一集对齐（[kPlayerLeftInset]，
/// 工作.md 第 19 点人体工学）。
///
/// 控制按钮背景：与横屏顶栏一致，受「播放器设置 → 按钮背景」控制
/// （默认关闭 = 纯图标）。
///
/// ⚠️ SafeArea 不消费顶部 inset（v3 用户反馈：顶部 inset 把返回/控制行
/// 大幅往下顶）：播放页沉浸式全屏，控制行紧贴屏幕顶部。
/// ⚠️ 顶部渐变压暗由页面层统一提供（「信息行 + 本顶栏」整体一个连续
/// 渐变）：本组件不再自带渐变，避免两段渐变拼接的「阴影在时间电量下方」
/// 断层（用户反馈 v2）。
class PortraitPlayerTopBar extends StatelessWidget {
  /// 竖屏顶栏最多渲染的槽位数（与横屏一致，5 个）
  static const int maxPortraitSlots = 5;

  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  /// 点击槽位动作（与横屏 [PlayerTopBar.onActionTap] 同语义，
  /// 由播放页传入动作处理入口）
  final void Function(PlayerTopAction) onActionTap;

  const PortraitPlayerTopBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onMore,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showBg = PlayerControlsSettings.instance.showButtonBackground;
    return SafeArea(
      left: false,
      right: false,
      bottom: false,
      // 不消费顶部 inset：见文件头注释（v3 用户反馈：顶部大间隔）
      top: false,
      child: Padding(
        // top 留出空间，远离状态栏/刘海；顶部信息行已单独占一行
        padding: const EdgeInsets.fromLTRB(kPlayerLeftInset, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：返回 + 标题
            Row(
              children: [
                _PortraitTopIconButton(
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // 第二行：槽位 + 更多（有槽位时横向均匀分布；无槽位时更多固定右侧）
            ListenableBuilder(
              listenable: PlayerControlsSettings.instance,
              builder: (context, _) {
                final l10n = AppLocalizations.of(context);
                final actions = PlayerControlsSettings.instance.topActions;
                if (actions.isEmpty) {
                  // 无槽位：更多按钮固定右侧（不参与均分）
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _PortraitTopIconButton(
                        icon: Icons.more_vert,
                        tooltip: l10n.commonMore,
                        showBackground: showBg,
                        onPressed: onMore,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (final a in actions.take(maxPortraitSlots))
                      Expanded(
                        child: Center(
                          child: _PortraitTopIconButton(
                            icon: a.icon,
                            tooltip: playerTopActionLabel(l10n, a),
                            showBackground: showBg,
                            onPressed: () => onActionTap(a),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: _PortraitTopIconButton(
                          icon: Icons.more_vert,
                          tooltip: l10n.commonMore,
                          showBackground: showBg,
                          onPressed: onMore,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶栏图标按钮：[showBackground] 只决定**底衬画不画**（半透明圆），
/// 不改图标尺寸、不改触摸盒、不改按钮间距（与横屏 [_TopIconButton] 同一约定）。
///
/// 尺寸恒定（竖屏不跟「控制栏按钮大小」走：竖屏顶栏按槽位均分宽度、底栏
/// 本来就紧，工作.md v3 溢出修复 —— 缩放只对横屏生效）。
class _PortraitTopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool showBackground;
  final VoidCallback onPressed;

  const _PortraitTopIconButton({
    required this.icon,
    required this.tooltip,
    required this.showBackground,
    required this.onPressed,
  });

  /// 图标边长（无底衬 / 有底衬都一样）
  static const double _iconSize = 22;

  /// 图标外内边距（22 + 13×2 = 48dp 触摸目标，与原 IconButton 一致）
  static const double _padding = 13;

  /// 底衬直径比图标直径大的量
  static const double _bgPadding = 6;

  @override
  Widget build(BuildContext context) {
    return PlayerPressable(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: _iconSize + _padding * 2,
          height: _iconSize + _padding * 2,
          child: Center(
            child: showBackground
                ? Container(
                    width: _iconSize + _bgPadding * 2,
                    height: _iconSize + _bgPadding * 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    // Center：不让圆底的 tight 约束把 Icon 渲染盒撑到圆底大小
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: _iconSize,
                      ),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: _iconSize),
          ),
        ),
      ),
    );
  }
}
