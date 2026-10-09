/// 「自定义」控制栏页（横屏右侧面板与竖屏底部面板共用同一份实现）。
///
/// 内容：
/// - 上方 **5 格预览条**：用户选中的动作，顺序 = 播放页右上角从左到右；
///   长按拖动排序、点方块（或右下角 －）移除、未放满画空槽框；
/// - 下方 **可添加网格**（3–4 列，按宽度自适应）：点方块即添加，
///   槽位满 5 个时点方块弹提示；
/// - 底部「重置控制栏」。
///
/// 增删都带**飞行动画**（[PlayerActionFlyAnimation]）：图标从下方方块沿弧线
/// 飞到上方槽位（移除时反向飞回），让「去哪了 / 从哪来」看得见。
///
/// ⚠️ 顺序很重要：先调 `flyTo/flyBack` 取旧布局的飞行起终点，再改设置 ——
/// 否则两端布局同时在变，落点会飞偏。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/pages/player/views/player_action_grid.dart';
import 'package:moumou/pages/player/views/portrait_edit_panel.dart';
import 'package:moumou/pages/player/views/portrait_player_top_bar.dart';
import 'package:moumou/services/player_controls_settings.dart';

class PlayerCustomizePanel extends StatefulWidget {
  const PlayerCustomizePanel({super.key});

  @override
  State<PlayerCustomizePanel> createState() => _PlayerCustomizePanelState();
}

class _PlayerCustomizePanelState extends State<PlayerCustomizePanel> {
  final PlayerActionFlyAnimationController _fly =
      PlayerActionFlyAnimationController();

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: PlayerControlsSettings.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final settings = PlayerControlsSettings.instance;
        final enabled = settings.topActions;
        final disabled = PlayerTopAction.values
            .where((a) => !enabled.contains(a))
            .toList();
        final full = enabled.length >= PortraitPlayerTopBar.maxPortraitSlots;
        return PlayerActionFlyAnimation(
          controller: _fly,
          // 飞行进度变化（开始/结束）时重建，让目标槽位图标隐身/显形
          onFlyingChanged: () => setState(() {}),
          // 整页一个滚动视图（预览条 + 可添加网格 + 重置一起滚）
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlayerPanelSectionLabel(l10n.playerActionsEnabledHint),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PlayerActionPreviewRow(
                    slots: enabled,
                    onReorder: (o, n) => settings.reorderTopAction(o, n),
                    onRemove: (a) {
                      // 先取源槽位位置（此刻列表还没变），再改数据
                      _fly.flyBack(a, atIndex: enabled.indexOf(a));
                      settings.removeTopAction(a);
                    },
                    keyOf: _fly.slotKey,
                    isSlotHidden: _fly.isSlotHidden,
                  ),
                ),
                const Divider(height: 14, color: Colors.white12),
                if (disabled.isNotEmpty) ...[
                  PlayerPanelSectionLabel(l10n.playerAddable),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                    child: Text(
                      l10n.playerAddableHint,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  PlayerActionGrid(
                    tiles: (tileWidth, tileHeight) => [
                      for (final a in disabled)
                        PlayerActionGridTile(
                          key: _fly.tileKey(a),
                          icon: a.icon,
                          label: playerTopActionLabel(l10n, a),
                          badge: Icon(
                            Icons.add_circle,
                            size: 18,
                            color: scheme.primary,
                          ),
                          width: tileWidth,
                          height: tileHeight,
                          onTap: () {
                            if (full) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.playerMaxActions(
                                        PlayerControlsSettings.maxTopActions,
                                      ),
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1500,
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            } else {
                              // 先取落点（此刻那个空槽还在），再改数据
                              _fly.flyTo(a, atIndex: enabled.length);
                              settings.addTopAction(a);
                            }
                          },
                        ),
                    ],
                  ),
                ],
                const Divider(height: 1, color: Colors.white12),
                PortraitPanelActionTile(
                  icon: Icons.restart_alt,
                  label: l10n.playerResetControlBar,
                  onTap: settings.resetTopActions,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
