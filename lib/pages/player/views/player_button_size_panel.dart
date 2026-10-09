/// 控制栏按钮大小面板（横屏播放页「更多 → 按钮大小」进入）。
///
/// - 滑杆 0.8 – 1.4、步进 0.1，改完立即写设置 → 播放页顶栏/底栏随
///   [PlayerControlsSettings] 重建（面板半透明，滑的时候能直接看到）；
/// - **拖动滑杆时本页其余内容淡出**（标题、说明、重置都压到很淡），只留
///   滑杆与百分比：视线不被面板干扰，一眼看清播放页控制栏的变化；
/// - **只作用于横屏**：竖屏顶栏/底栏本来紧凑（工作.md v3 溢出修复），
///   参数固定不缩放，故本页只在横屏「更多」出现。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/player/views/portrait_edit_panel.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/widgets/player_panel.dart'
    show PlayerPanelDim, PlayerPanelDimFade;

class PlayerButtonSizePanel extends StatefulWidget {
  const PlayerButtonSizePanel({super.key});

  @override
  State<PlayerButtonSizePanel> createState() => _PlayerButtonSizePanelState();
}

class _PlayerButtonSizePanelState extends State<PlayerButtonSizePanel> {
  /// 是否正在拖动滑杆（拖动时整个面板让位淡出）
  bool _dragging = false;

  void _setDragging(bool value) {
    if (!mounted || _dragging == value) return;
    setState(() => _dragging = value);
    // 面板外壳同步淡出（连面板自身背景一起淡，只剩滑杆清晰）
    PlayerPanelDim.set(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = PlayerControlsSettings.instance;
    // 面板底色已变淡；本页其余内容再淡到几乎看不见，只留滑杆
    final dimmed = _dragging && PlayerPanelDim.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scale = settings.buttonScale;
        final spacing = settings.buttonSpacingScale;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _fade(
              dimmed,
              _sliderHeader(l10n.playerButtonSize, scale),
            ),
            // 滑杆：拖动期间**不淡出**（唯一保留的操作，百分比由滑杆气泡显示）
            // 面板底色已变淡提供对比，滑杆保持满不透明度
            _slider(
              value: scale,
              min: PlayerControlsSettings.minButtonScale,
              max: PlayerControlsSettings.maxButtonScale,
              onChanged: settings.setButtonScale,
            ),
            const SizedBox(height: 4),
            _fade(
              dimmed,
              _sliderHeader(l10n.playerButtonSpacing, spacing),
            ),
            _slider(
              value: spacing,
              min: PlayerControlsSettings.minButtonSpacingScale,
              max: PlayerControlsSettings.maxButtonSpacingScale,
              onChanged: settings.setButtonSpacingScale,
            ),
            _fade(
              dimmed,
              Text(
                l10n.playerButtonSizeHint,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            _fade(
              dimmed,
              Column(
                children: [
                  const Divider(height: 1, color: Colors.white12),
                  PortraitPanelActionTile(
                    icon: Icons.restart_alt,
                    label: l10n.commonReset,
                    onTap: () => settings
                        .setButtonScale(PlayerControlsSettings.defaultButtonScale)
                        .then(
                          (_) => settings.setButtonSpacingScale(
                            PlayerControlsSettings.defaultButtonSpacingScale,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 滑杆上方：名称 + 当前百分比
  Widget _sliderHeader(String label, double value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
        Text(
          '${(value * 100).round()}%',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 滑杆（拖动时触发面板让位；百分比由滑杆气泡显示）
  Widget _slider({
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: ((max - min) / PlayerControlsSettings.buttonScaleStep).round(),
      label: '${(value * 100).round()}%',
      onChangeStart: (_) => _setDragging(true),
      onChanged: onChanged,
      onChangeEnd: (_) => _setDragging(false),
    );
  }

  /// 拖动滑杆时淡出（面板底色由外壳变淡，这里再淡掉本页其余内容）
  Widget _fade(bool dimmed, Widget child) {
    return PlayerPanelDimFade(dimmed: dimmed, child: child);
  }
}
