/// 后处理面板（横屏播放页「更多 → 后处理」进入）。
///
/// 结构（自上而下）：
/// - **预设效果**：顶部一行入口，进去选「胶片电影 / 老电视 / 低码率 / 流媒体 /
///   风格化」，点选后把参数写进下面这些开关和滑杆，然后回到本面板；
/// - **总开关**：关掉 = 所有效果不应用（mpv 属性复位、着色器链清空）；
/// - **基础调节**：亮度 / 对比 / 伽马 / 饱和度 / 色相（mpv 内置属性，拖动即时生效）；
/// - **效果**：锐化/柔化、降噪、去色带（前两个是属性/着色器）+ 白平衡、色阶、
///   胶片曲线、暗角、扫描线、自然色彩、泛光、卡通、胶片颗粒（运行时生成的
///   mpv 用户着色器，改参数后 220ms 防抖重建）；
/// - **恢复默认**：参数回到默认值（总开关保留，预设标记清空）。
///
/// 面板直接驱动 [PostProcessService] 单例，播放器由播放页在打开媒体时绑定。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/post_process_preset.dart';
import 'package:moumou/services/post_process_service.dart';

class PlayerPostProcessPanel extends StatefulWidget {
  const PlayerPostProcessPanel({super.key});

  @override
  State<PlayerPostProcessPanel> createState() => _PlayerPostProcessPanelState();
}

class _PlayerPostProcessPanelState extends State<PlayerPostProcessPanel> {
  final PostProcessService _service = PostProcessService.instance;

  /// 面板内切换：预设选择视图 ↔ 参数视图（不新开面板页，横竖屏都适用）
  bool _showPresets = false;

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
    // 参数视图 ↔ 预设视图之间做淡入 + 轻微右滑，避免“闪切”
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _showPresets
          ? KeyedSubtree(
              key: const ValueKey('presets'),
              child: _buildPresetView(l10n),
            )
          : KeyedSubtree(
              key: const ValueKey('params'),
              child: _buildParamsView(l10n),
            ),
    );
  }

  Widget _buildParamsView(AppLocalizations l10n) {
    final on = _service.enabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // ── 预设效果入口 ──
        _presetEntry(l10n),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),

        // ── 基础调节 ──
        _sectionHeader(l10n.playerPostProcessBasic),
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
        _sectionReset(l10n, _service.resetBasicAdjustments),

        // ── 画面效果 ──
        _sectionHeader(l10n.playerPostProcessEffects),

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
          label: l10n.playerPostProcessDenoise,
          value: _service.denoiseEnabled,
          enabled: on,
          onChanged: _service.setDenoiseEnabled,
        ),
        if (_service.denoiseEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.denoiseStrength,
            min: PostProcessService.denoiseStrengthMin,
            max: PostProcessService.denoiseStrengthMax,
            enabled: on,
            onChanged: _service.setDenoiseStrength,
          ),
          _sliderRow(
            label: l10n.playerPostProcessRange,
            value: _service.denoiseRadius,
            min: PostProcessService.denoiseRadiusMin,
            max: PostProcessService.denoiseRadiusMax,
            divisions: 7,
            enabled: on,
            onChanged: _service.setDenoiseRadius,
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

        // ── 白平衡 ──
        _effectHeader(
          label: l10n.playerPostProcessWhiteBalance,
          value: _service.whiteBalanceEnabled,
          enabled: on,
          onChanged: _service.setWhiteBalanceEnabled,
        ),
        if (_service.whiteBalanceEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessTemperature,
            value: _service.temperature,
            min: PostProcessService.temperatureMin,
            max: PostProcessService.temperatureMax,
            divisions: 200,
            enabled: on,
            onChanged: _service.setTemperature,
          ),
          _sliderRow(
            label: l10n.playerPostProcessTint,
            value: _service.tint,
            min: PostProcessService.tintMin,
            max: PostProcessService.tintMax,
            divisions: 200,
            enabled: on,
            onChanged: _service.setTint,
          ),
        ],

        // ── 色阶 ──
        _effectHeader(
          label: l10n.playerPostProcessLevels,
          value: _service.levelsEnabled,
          enabled: on,
          onChanged: _service.setLevelsEnabled,
        ),
        if (_service.levelsEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessInBlack,
            value: _service.inBlack,
            min: PostProcessService.inBlackMin,
            max: PostProcessService.inBlackMax,
            enabled: on,
            onChanged: _service.setInBlack,
          ),
          _sliderRow(
            label: l10n.playerPostProcessInWhite,
            value: _service.inWhite,
            min: PostProcessService.inWhiteMin,
            max: PostProcessService.inWhiteMax,
            enabled: on,
            onChanged: _service.setInWhite,
          ),
          _sliderRow(
            label: l10n.playerPostProcessGamma,
            value: _service.levelsGamma,
            min: PostProcessService.levelsGammaMin,
            max: PostProcessService.levelsGammaMax,
            enabled: on,
            onChanged: _service.setLevelsGamma,
          ),
        ],

        // ── 胶片曲线 ──
        _effectHeader(
          label: l10n.playerPostProcessFilmic,
          value: _service.filmicEnabled,
          enabled: on,
          onChanged: _service.setFilmicEnabled,
        ),
        if (_service.filmicEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessExposure,
            value: _service.exposure,
            min: PostProcessService.exposureMin,
            max: PostProcessService.exposureMax,
            enabled: on,
            onChanged: _service.setExposure,
          ),
          _sliderRow(
            label: l10n.playerPostProcessToe,
            value: _service.filmicToe,
            min: PostProcessService.toeMin,
            max: PostProcessService.toeMax,
            enabled: on,
            onChanged: _service.setFilmicToe,
          ),
          _sliderRow(
            label: l10n.playerPostProcessShoulder,
            value: _service.filmicShoulder,
            min: PostProcessService.shoulderMin,
            max: PostProcessService.shoulderMax,
            enabled: on,
            onChanged: _service.setFilmicShoulder,
          ),
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.filmicAmount,
            min: PostProcessService.filmicAmountMin,
            max: PostProcessService.filmicAmountMax,
            enabled: on,
            onChanged: _service.setFilmicAmount,
          ),
        ],

        // ── 胶片颗粒 ──
        _effectHeader(
          label: l10n.playerPostProcessFilmGrain,
          value: _service.filmGrainEnabled,
          enabled: on,
          onChanged: _service.setFilmGrainEnabled,
        ),
        if (_service.filmGrainEnabled) ...[
          _sliderRow(
            label: l10n.playerPostProcessAmount,
            value: _service.filmGrainIntensity,
            min: PostProcessService.filmGrainIntensityMin,
            max: PostProcessService.filmGrainIntensityMax,
            enabled: on,
            onChanged: _service.setFilmGrainIntensity,
          ),
          _sliderRow(
            label: l10n.playerPostProcessSize,
            value: _service.filmGrainSize,
            min: PostProcessService.filmGrainSizeMin,
            max: PostProcessService.filmGrainSizeMax,
            divisions: 3,
            enabled: on,
            onChanged: _service.setFilmGrainSize,
          ),
        ],
        _sectionReset(l10n, _service.resetEffects),

        const SizedBox(height: 8),
        const Divider(height: 1, color: Colors.white12),
        // 全局重置：红字，和板块级“重置”区分开
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _service.resetSettings,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: Text(l10n.playerPostProcessResetAll),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  // ── 预设 ─────────────────────────────────────────────────

  /// 分组 → 预设列表（前四组各三档，风格组是三个独立风格）
  static const Map<PostProcessPresetGroup, List<PostProcessPreset>>
      _presetGroups = {
    PostProcessPresetGroup.clean: [
      PostProcessPreset.cleanLight,
      PostProcessPreset.cleanStandard,
      PostProcessPreset.cleanStrong,
    ],
    PostProcessPresetGroup.film: [
      PostProcessPreset.filmLight,
      PostProcessPreset.filmStandard,
      PostProcessPreset.filmStrong,
    ],
    PostProcessPresetGroup.tv: [
      PostProcessPreset.tvLight,
      PostProcessPreset.tvStandard,
      PostProcessPreset.tvStrong,
    ],
    PostProcessPresetGroup.lowBitrate: [
      PostProcessPreset.lowBitrateLight,
      PostProcessPreset.lowBitrateStandard,
      PostProcessPreset.lowBitrateStrong,
    ],
    PostProcessPresetGroup.streaming: [
      PostProcessPreset.streamingLight,
      PostProcessPreset.streamingStandard,
      PostProcessPreset.streamingStrong,
    ],
    PostProcessPresetGroup.style: [
      PostProcessPreset.cinematic,
      PostProcessPreset.soft,
      PostProcessPreset.retro,
    ],
  };

  /// 顶部入口：当前预设状态 + 进入预设视图
  Widget _presetEntry(AppLocalizations l10n) {
    final applied = _service.appliedPreset;
    final String state;
    if (applied == null) {
      state = l10n.playerPresetCustom;
    } else {
      final label = applied.isStyle
          ? _presetLabel(l10n, applied)
          : '${_groupLabel(l10n, applied.group)} · ${_presetLabel(l10n, applied)}';
      state = _service.presetModified
          ? '$label · ${l10n.playerPresetModified}'
          : label;
    }
    return InkWell(
      onTap: () => setState(() => _showPresets = true),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.movie_filter_outlined,
              size: 18,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.playerPresetEffects,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            Text(
              state,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  /// 预设选择视图（面板内切换，不新开页面）
  Widget _buildPresetView(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        InkWell(
          onTap: () => setState(() => _showPresets = false),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.playerPresetEffects,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in _presetGroups.entries) ...[
          _groupHeader(_groupLabel(l10n, entry.key)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in entry.value)
                _presetChip(
                  _presetLabel(l10n, preset),
                  selected: _service.appliedPreset == preset,
                  // 应用后留在预设视图：方便连续切换档位对比效果，
                  // 用户自己点顶部返回行回到参数界面
                  onTap: () => _service.applyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _presetChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? scheme.onPrimary : Colors.white70,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _groupLabel(AppLocalizations l10n, PostProcessPresetGroup group) {
    switch (group) {
      case PostProcessPresetGroup.clean:
        return l10n.playerPresetGroupClean;
      case PostProcessPresetGroup.film:
        return l10n.playerPresetGroupFilm;
      case PostProcessPresetGroup.tv:
        return l10n.playerPresetGroupTv;
      case PostProcessPresetGroup.lowBitrate:
        return l10n.playerPresetGroupLowBitrate;
      case PostProcessPresetGroup.streaming:
        return l10n.playerPresetGroupStreaming;
      case PostProcessPresetGroup.style:
        return l10n.playerPresetGroupStyle;
    }
  }

  String _presetLabel(AppLocalizations l10n, PostProcessPreset preset) {
    switch (preset) {
      case PostProcessPreset.cinematic:
        return l10n.playerPresetCinematic;
      case PostProcessPreset.soft:
        return l10n.playerPresetSoft;
      case PostProcessPreset.retro:
        return l10n.playerPresetRetro;
      default:
        return switch (preset.strength) {
          PostProcessPresetStrength.light => l10n.playerPresetLight,
          PostProcessPresetStrength.strong => l10n.playerPresetStrong,
          _ => l10n.playerPresetStandard,
        };
    }
  }

  /// 主板块标题（比下方调节项大一号）
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 板块底部的重置按钮（右下角，比标题行里的小按钮大一圈）
  Widget _sectionReset(AppLocalizations l10n, VoidCallback onReset) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt, size: 20),
        label: Text(
          l10n.commonReset,
          style: const TextStyle(fontSize: 14),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(88, 40),
        ),
      ),
    );
  }

  /// 预设分组标题（比胶囊文字大一号）
  Widget _groupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          fontWeight: FontWeight.w600,
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
