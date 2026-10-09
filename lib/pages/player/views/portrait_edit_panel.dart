/// 「自定义」页在竖屏底部面板里的入口（内容与横屏共用
/// [PlayerCustomizePanel]，见 `player_customize_panel.dart`）。
///
/// ⚠️ 竖屏与横屏一致最多 5 个槽位（[PortraitPlayerTopBar.maxPortraitSlots]）。
library;

import 'package:flutter/material.dart';
import 'package:moumou/pages/player/views/player_customize_panel.dart';

class PortraitEditControlPanel extends StatelessWidget {
  const PortraitEditControlPanel({super.key});

  @override
  Widget build(BuildContext context) => const PlayerCustomizePanel();
}

/// 面板中的动作行：图标 + 名称 +（副标题）+ 箭头
class PortraitPanelActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const PortraitPanelActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      titleAlignment: ListTileTitleAlignment.center,
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }
}
