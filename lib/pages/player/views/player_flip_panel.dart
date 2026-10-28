/// 画面翻转面板内容（横屏右侧面板 / 竖屏底部面板共用）。
///
/// 两个开关：水平翻转（左右镜像）/ 垂直翻转（上下镜像），状态存在
/// [PlayerSessionState]（横竖屏共用一份，转屏、切集都保持）。
///
/// 翻转由播放页把 `Video` 包一层 `Transform.flip` 完成（不走 mpv 的 vf
/// 滤镜：本项目的 libmpv 精简构建没有 hflip / vflip）。因此画面与 mpv 渲染
/// 的字幕会一起镜像，Flutter 层的弹幕保持正向。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/player/player_session_state.dart';

class PlayerFlipPanel extends StatelessWidget {
  /// 横竖屏共享的播放会话（翻转开关就存在这里）
  final PlayerSessionState session;

  const PlayerFlipPanel({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FlipSwitchRow(
                label: l10n.playerFlipHorizontal,
                value: session.flipHorizontal,
                onChanged: session.setFlipHorizontal,
              ),
              const Divider(height: 20, color: Colors.white12),
              _FlipSwitchRow(
                label: l10n.playerFlipVertical,
                value: session.flipVertical,
                onChanged: session.setFlipVertical,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.playerFlipDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 一行开关：名称 + Switch（与片头片尾面板的总开关同款）
class _FlipSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlipSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
