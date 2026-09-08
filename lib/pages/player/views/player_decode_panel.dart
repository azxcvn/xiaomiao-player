import 'package:flutter/material.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/player_option_chip.dart';

/// 解码方式面板内容（横屏经 [showPlayerPanel] 右侧滑入，竖屏经
/// [showPlayerBottomPanel] 底部弹出，标题「解码」）。
///
/// 分两组：
/// - **解码方式**：自动 / 硬解 / 硬解+ / 软解 四档 2×2 等宽胶囊；
/// - **解码预设**：快速 / 标准（默认快速，vd-lavc-* 性能开关）。
/// 两者均**重启播放器（重开视频）后生效**，面板底部有提示。
///
/// 切换解码方式/预设后，弹出「需重启」弹窗（工作.md 迁移功能）：
/// 「立即重启」整应用重启、「稍后重启」仅关闭弹窗（改动已持久化，
/// 下次启动生效）。
class PlayerDecodePanel extends StatefulWidget {
  const PlayerDecodePanel({super.key});

  @override
  State<PlayerDecodePanel> createState() => _PlayerDecodePanelState();
}

class _PlayerDecodePanelState extends State<PlayerDecodePanel> {
  final DecodeSettings _settings = DecodeSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_handleChanged);
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_handleChanged);
    super.dispose();
  }

  /// 切换解码方式：写入设置后弹「需重启」确认（立即整应用重启 / 稍后）。
  Future<void> _setMode(DecodeMode mode) async {
    await _settings.setMode(mode);
    if (!mounted) return;
    await _promptRestart();
  }

  /// 切换解码预设：写入设置后弹「需重启」确认（立即整应用重启 / 稍后）。
  Future<void> _setPreset(DecodePreset preset) async {
    await _settings.setPreset(preset);
    if (!mounted) return;
    await _promptRestart();
  }

  /// 弹「需重启」确认框。立即重启 → 调用原生整应用重启；
  /// 稍后重启 → 仅关闭（改动已持久化，退出重开视频/应用后生效）。
  Future<void> _promptRestart() async {
    if (!mounted) return;
    final restartNow = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需重启应用'),
        content: const Text(
          '解码配置已修改，重启应用后生效。\n\n是否立即重启？',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍后重启'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('立即重启'),
          ),
        ],
      ),
    );
    if (restartNow == true) {
      await DeviceServices.restartApp();
    }
  }

  Widget _buildModeRow(List<DecodeMode> modes) {
    return Row(
      children: [
        for (var i = 0; i < modes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PlayerOptionChip(
              label: modes[i].label,
              selected: _settings.mode == modes[i],
              onTap: () => _setMode(modes[i]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPresetGrid() {
    final presets = DecodePreset.values;
    return Column(
      children: [
        for (var i = 0; i < presets.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var j = 0; j < 2 && i + j < presets.length; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(
                  child: PlayerOptionChip(
                    label: presets[i + j].label,
                    selected: _settings.preset == presets[i + j],
                    onTap: () => _setPreset(presets[i + j]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 解码方式：2×2 等宽胶囊
          _buildModeRow(const [DecodeMode.autoSafe, DecodeMode.hwCopy]),
          const SizedBox(height: 8),
          _buildModeRow(const [DecodeMode.hwPlus, DecodeMode.sw]),
          const SizedBox(height: 16),
          // 解码预设
          _sectionLabel('解码预设'),
          const SizedBox(height: 8),
          _buildPresetGrid(),
          const SizedBox(height: 12),
          Text(
            '切换后需重启应用生效，可选立即重启',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '「硬解+」在直通不可用时自动回退',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
