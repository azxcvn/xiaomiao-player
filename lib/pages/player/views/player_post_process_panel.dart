/// 后处理面板（横屏播放页「更多 → 后处理」进入）。
///
/// 结构（自上而下）：
/// - **总开关**：关掉 = 所有效果不应用（mpv 属性复位、着色器链清空）；
/// - **基础调节**：亮度 / 对比 / 伽马 / 饱和度 / 色相（mpv 内置属性，拖动即时生效）；
/// - **效果**：锐化、去色带（mpv 内置属性）+ 暗角、扫描线、自然色彩（运行时生成
///   的 mpv 用户着色器，改参数后 220ms 防抖重建）；
/// - **恢复默认**：参数回到默认值（总开关保留）。
///
/// 面板直接驱动 [PostProcessService] 单例，播放器由播放页在打开媒体时绑定。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/player/views/portrait_edit_panel.dart';
import 'package:moumou/services/post_process_service.dart';

class PlayerPostProcessPanel extends StatefulWidget {
  const PlayerPostProcessPanel({super.key});

  @override
  State<PlayerPostProcessPanel> createState() => _PlayerPostProcessPanelState();
}

class _PlayerPostProcessPanelState extends State<PlayerPostProcessPanel> {
  final PostProcessService _service = PostProcessService.instance;

  @override
  void initState() {
    super.initState();
    // 面板是独立弹窗路由：监听服务变化刷新选中态/滑杆位置
    _service.addListener(_onChanged);
    _service.ensureLoaded();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final on = _service.enabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // ── 总开关 ──
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.playerPostProcessEnable,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Switch(
              value: on,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: _service.setEnabled,
            ),
          ],
        ),
        Text(
          l10n.playerPostProcessHint,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),

        // ── 基础调节 ──
        _sectionLabel(l10n.playerPostProcessBasic),
        _sliderRow(
          label: l10n.playerPostProcessBrightness,
          value: _service.brightness,
          min: PostProcessService.basicMin,
          max: PostProcessService.basicMax,
          divisions: 200,
          enabled: on,
          onChanged: _service.setBrightness,
        ),
        _sliderRow(
          label: l10n.playerPostProcessContrast,
          value: _service.contrast,
          min: PostProcessService.basicMin,
          max: PostProcessService.basicMax,
          divisions: 200,
          enabled: on,
          onChanged: _service.setContrast,
        ),
        _sliderRow(
          label: l10n.playerPostProcessGamma,
          value: _service.gamma,
          min: PostProcessService.basicMin,
          max: PostProcessService.basicMax,
          divisions: 200,
          enabled: on,
          onChanged: _service.setGamma,
        ),
        _sliderRow(
          label: l10n.playerPostProcessSaturation,
          value: _service.saturation,
          min: PostProcessService.basicMin,
          max: PostProcessService.basicMax,
          divisions: 200,
          enabled: on,
          onChanged: _service.setSaturation,
        ),
        _sliderRow(
          label: l10n.playerPostProcessHue,
          value: _service.hue,
          min: PostProcessService.basicMin,
          max: PostProcessService.basicMax,
          divisions: 200,
          enabled: on,
          onChanged: _service.setHue,
        ),

        // ── 效果 ──
        const SizedBox(height: 4),
        _sectionLabel(l10n.playerPostProcessEffects),

        _effectHeader(
          label: l10n.playerPostProcessSharpen,
          value: _service.sharpenEnabled,
          enabled: on,
          onChanged: _service.setSharpenEnabled,
        ),
        if (_service.sharpenEnabled) ...[
          if (!_service.sharpenAvailable)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                l10n.playerPostProcessGpuNextHint,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.sharpenAmount,
            min: PostProcessService.sharpenMin,
            max: PostProcessService.sharpenMax,
            enabled: on,
            onChanged: _service.setSharpenAmount,
          ),
        ],

        _effectHeader(
          label: l10n.playerPostProcessDeband,
          value: _service.debandEnabled,
          enabled: on,
          onChanged: _service.setDebandEnabled,
        ),
        if (_service.debandEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessThreshold,
            value: _service.debandThreshold,
            min: PostProcessService.debandThresholdMin,
            max: PostProcessService.debandThresholdMax,
            divisions: 80,
            enabled: on,
            onChanged: _service.setDebandThreshold,
          ),
          _sliderRow(
            label: l10n.playerPostProcessRange,
            value: _service.debandRange,
            min: PostProcessService.debandRangeMin,
            max: PostProcessService.debandRangeMax,
            divisions: 28,
            enabled: on,
            onChanged: _service.setDebandRange,
          ),
          _sliderRow(
            label: l10n.playerPostProcessGrain,
            value: _service.debandGrain,
            min: PostProcessService.debandGrainMin,
            max: PostProcessService.debandGrainMax,
            divisions: 64,
            enabled: on,
            onChanged: _service.setDebandGrain,
          ),
          _sliderRow(
            label: l10n.playerPostProcessIterations,
            value: _service.debandIterations,
            min: PostProcessService.debandIterationsMin,
            max: PostProcessService.debandIterationsMax,
            divisions: 16,
            enabled: on,
            onChanged: _service.setDebandIterations,
          ),
        ],

        _effectHeader(
          label: l10n.playerPostProcessVignette,
          value: _service.vignetteEnabled,
          enabled: on,
          onChanged: _service.setVignetteEnabled,
        ),
        if (_service.vignetteEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.vignettePower,
            min: PostProcessService.vignettePowerMin,
            max: PostProcessService.vignettePowerMax,
            enabled: on,
            onChanged: _service.setVignettePower,
          ),
          _sliderRow(
            label: l10n.playerPostProcessAspect,
            value: _service.vignetteAspect,
            min: PostProcessService.vignetteAspectMin,
            max: PostProcessService.vignetteAspectMax,
            enabled: on,
            onChanged: _service.setVignetteAspect,
          ),
          _sliderRow(
            label: l10n.playerPostProcessRange,
            value: _service.vignetteRadius,
            min: PostProcessService.vignetteRadiusMin,
            max: PostProcessService.vignetteRadiusMax,
            enabled: on,
            onChanged: _service.setVignetteRadius,
          ),
          _sliderRow(
            label: l10n.playerPostProcessSoftness,
            value: _service.vignetteSoftness,
            min: PostProcessService.vignetteSoftnessMin,
            max: PostProcessService.vignetteSoftnessMax,
            enabled: on,
            onChanged: _service.setVignetteSoftness,
          ),
        ],

        _effectHeader(
          label: l10n.playerPostProcessScanlines,
          value: _service.scanlinesEnabled,
          enabled: on,
          onChanged: _service.setScanlinesEnabled,
        ),
        if (_service.scanlinesEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessDensity,
            value: _service.scanlinesDensity,
            min: PostProcessService.scanlinesDensityMin,
            max: PostProcessService.scanlinesDensityMax,
            enabled: on,
            onChanged: _service.setScanlinesDensity,
          ),
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.scanlinesIntensity,
            min: PostProcessService.scanlinesIntensityMin,
            max: PostProcessService.scanlinesIntensityMax,
            enabled: on,
            onChanged: _service.setScanlinesIntensity,
          ),
        ],

        _effectHeader(
          label: l10n.playerPostProcessNatural,
          value: _service.naturalColorsEnabled,
          enabled: on,
          onChanged: _service.setNaturalColorsEnabled,
        ),
        if (_service.naturalColorsEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessLuma,
            value: _service.naturalLuma,
            min: PostProcessService.naturalLumaMin,
            max: PostProcessService.naturalLumaMax,
            enabled: on,
            onChanged: _service.setNaturalLuma,
          ),
          _sliderRow(
            label: l10n.playerPostProcessChroma,
            value: _service.naturalChroma,
            min: PostProcessService.naturalChromaMin,
            max: PostProcessService.naturalChromaMax,
            enabled: on,
            onChanged: _service.setNaturalChroma,
          ),
        ],

        // ── 泛光（着色器）──
        _effectHeader(
          label: l10n.playerPostProcessBloom,
          value: _service.bloomEnabled,
          enabled: on,
          onChanged: _service.setBloomEnabled,
        ),
        if (_service.bloomEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.bloomAmount,
            min: PostProcessService.bloomAmountMin,
            max: PostProcessService.bloomAmountMax,
            enabled: on,
            onChanged: _service.setBloomAmount,
          ),
          _sliderRow(
            label: l10n.playerPostProcessSpread,
            value: _service.bloomSpread,
            min: PostProcessService.bloomSpreadMin,
            max: PostProcessService.bloomSpreadMax,
            enabled: on,
            onChanged: _service.setBloomSpread,
          ),
        ],

        // ── 卡通（着色器）──
        _effectHeader(
          label: l10n.playerPostProcessCartoon,
          value: _service.cartoonEnabled,
          enabled: on,
          onChanged: _service.setCartoonEnabled,
        ),
        if (_service.cartoonEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.cartoonStrength,
            min: PostProcessService.cartoonStrengthMin,
            max: PostProcessService.cartoonStrengthMax,
            enabled: on,
            onChanged: _service.setCartoonStrength,
          ),
        ],

        const SizedBox(height: 8),
        const Divider(height: 1, color: Colors.white12),
        PortraitPanelActionTile(
          icon: Icons.restart_alt,
          label: l10n.commonReset,
          onTap: _service.resetSettings,
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 效果行：名称 + 开关（总开关关闭时整行置灰）
  Widget _effectHeader({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white38,
              fontSize: 15,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: Theme.of(context).colorScheme.primary,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white38,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              _formatValue(value),
              style: TextStyle(
                color: enabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 32,
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  /// 整数参数显示整数，其余保留两位（拖动时读数不跳）
  String _formatValue(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(2);
  }
}
