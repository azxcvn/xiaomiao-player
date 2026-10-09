import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 播放器设置子页：双击手势、快进/快退时长（固定档位 + 点数值原地自定义）、
/// 音量/亮度手势灵敏度、长按倍速（倍率滑杆，归「手势」组）、
/// 自动连播 / 播放完毕自动退出（归「播放行为」组）、
/// 常驻进度线、倍速记忆、按钮背景、双指缩放、已观看进度阈值。
///
/// 分组结构（各组别内的设置项以分割线分隔）：
/// - **手势**：双击手势、快进/快退时长、音量/亮度灵敏度、长按倍速滑杆
///   （工作.md 第 3 点：全部归为**一张卡片**内，项间用分割线分隔）；
/// - **视频方向**：自动 / 锁定竖屏 / 锁定横屏（工作.md 第 5 点）+
///   界面跟随重力旋转开关（默认关闭，只作用于「自动」）；
/// - **播放行为**：常驻进度线、进度条缩略图、记住上次倍速、保存音量到系统、
///   双指缩小视频、按钮背景、自动连播、播放完毕自动退出、倍速播放指示器、
///   启用播放界面动画、锁定状态豁免双击、音量增强（开关 + 可折叠的上限
///   百分比滑杆，组内最后一项）；
/// - **已观看进度阈值**：滑杆设置（5% – 100%，步进 5%）。
///
/// 循环播放模式（关闭/列表循环/单集循环）已移至播放界面内调整
/// （顶栏/更多面板的「循环播放」槽位动作），本页不再提供。
/// 超分辨率（模式/质量/记忆）在播放界面右下角入口直接调整，本页不提供；
/// 控制栏（启用动作）的编辑只在播放器内进行（「更多 → 自定义」），本页不提供。
class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({super.key});

  IconData _modeIcon(DoubleTapMode mode) {
    return switch (mode) {
      DoubleTapMode.pause => Icons.pause_circle_outline,
      DoubleTapMode.seek => Icons.fast_forward_outlined,
      DoubleTapMode.mixed => Icons.touch_app_outlined,
    };
  }

  IconData _orientationIcon(VideoOrientationMode mode) {
    return switch (mode) {
      VideoOrientationMode.auto => Icons.smartphone,
      VideoOrientationMode.portrait => Icons.screen_lock_portrait,
      VideoOrientationMode.landscape => Icons.screen_lock_landscape,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = PlayerControlsSettings.instance;
    final decodeSettings = DecodeSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPlayerSettings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, decodeSettings]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              // ── 手势（工作.md 第 3 点：所有手势设置归为一张卡片）──
              SettingsGroupTitle(title: l10n.settingsPlayerGroupGesture),
              SettingsCard(
                child: Column(
                  children: [
                    for (final m in DoubleTapMode.values)
                      SettingsRadioTile(
                        icon: _modeIcon(m),
                        title: playerDoubleTapModeLabel(l10n, m),
                        selected: settings.doubleTapMode == m,
                        onTap: () => settings.setDoubleTapMode(m),
                      ),
                    // 快进/快退时长（双击手势与中央按钮共用）
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SeekSettingTile(
                      value: settings.seekSeconds,
                      onChanged: settings.setSeekSeconds,
                    ),
                    // 音量/亮度灵敏度
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SensitivityTile(
                      icon: Icons.volume_up_outlined,
                      title: l10n.settingsPlayerVolumeSensitivity,
                      value: settings.volumeSensitivity,
                      onChanged: settings.setVolumeSensitivity,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _SensitivityTile(
                      icon: Icons.brightness_6_outlined,
                      title: l10n.settingsPlayerBrightnessSensitivity,
                      value: settings.brightnessSensitivity,
                      onChanged: settings.setBrightnessSensitivity,
                    ),
                    // 长按倍速滑杆（归入手势组别）
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _LongPressSpeedTile(
                      value: settings.longPressSpeed,
                      onChanged: settings.setLongPressSpeed,
                    ),
                  ],
                ),
              ),
              // ── 视频方向（工作.md 第 5 点）────────────────
              const SizedBox(height: 16),
              SettingsGroupTitle(title: l10n.settingsPlayerGroupOrientation),
              SettingsCard(
                child: Column(
                  children: [
                    for (final m in VideoOrientationMode.values)
                      SettingsRadioTile(
                        icon: _orientationIcon(m),
                        title: playerOrientationModeLabel(l10n, m),
                        subtitle: switch (m) {
                          VideoOrientationMode.auto =>
                            Text(l10n.settingsPlayerOrientationFollowVideo),
                          VideoOrientationMode.portrait =>
                            Text(l10n.settingsPlayerOrientationAlwaysPortrait),
                          VideoOrientationMode.landscape =>
                            Text(l10n.settingsPlayerOrientationAlwaysLandscape),
                        },
                        selected: settings.videoOrientation == m,
                        onTap: () => settings.setVideoOrientation(m),
                      ),
                    // 界面跟随重力旋转（默认关闭；只作用于「自动」：锁定竖屏/
                    // 锁定横屏是用户的明确指定，优先级更高）
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.screen_rotation,
                      title: l10n.settingsPlayerUiFollowGravity,
                      trailing: Switch(
                        value: settings.followPhoneRotation,
                        onChanged: (v) =>
                            _onFollowPhoneRotationChanged(context, v),
                      ),
                    ),
                  ],
                ),
              ),
              // ── 顶部信息（工作.md 阶段1 第 1 点：时间/电量/网速/数据类型多选）──
              const SizedBox(height: 16),
              SettingsGroupTitle(title: l10n.settingsPlayerGroupTopInfo),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsCheckboxTile(
                      icon: Icons.access_time,
                      title: l10n.commonTime,
                      subtitle: Text(l10n.settingsPlayerShowTimeDesc),
                      checked: settings.showTopTime,
                      onChanged: settings.setShowTopTime,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsCheckboxTile(
                      icon: Icons.battery_full,
                      title: l10n.settingsPlayerBattery,
                      subtitle: Text(l10n.settingsPlayerShowBatteryDesc),
                      checked: settings.showTopBattery,
                      onChanged: settings.setShowTopBattery,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsCheckboxTile(
                      icon: Icons.speed_outlined,
                      title: l10n.settingsPlayerNetSpeed,
                      subtitle: Text(l10n.settingsPlayerShowNetSpeedDesc),
                      checked: settings.showTopNetSpeed,
                      onChanged: settings.setShowTopNetSpeed,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsCheckboxTile(
                      icon: Icons.wifi_outlined,
                      title: l10n.settingsPlayerDataType,
                      subtitle: Text(l10n.settingsPlayerShowDataTypeDesc),
                      checked: settings.showTopNetType,
                      onChanged: settings.setShowTopNetType,
                    ),
                  ],
                ),
              ),
              // ── 播放行为（原「播放」组别改名）────────────
              const SizedBox(height: 16),
              SettingsGroupTitle(title: l10n.settingsPlayerGroupBehavior),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.horizontal_rule,
                      title: l10n.settingsPlayerPersistentProgressBar,
                      subtitle: Text(l10n.settingsPlayerPersistentProgressBarDesc),
                      trailing: Switch(
                        value: settings.showProgressLine,
                        onChanged: (v) => settings.setShowProgressLine(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.bookmarks_outlined,
                      title: l10n.settingsPlayerChapterProgressBar,
                      subtitle: Text(l10n.settingsPlayerChapterProgressBarDesc),
                      trailing: Switch(
                        value: settings.showChapterProgress,
                        onChanged: (v) => settings.setShowChapterProgress(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.image_outlined,
                      title: l10n.settingsPlayerThumbnailPreview,
                      subtitle: Text(l10n.settingsPlayerThumbnailPreviewDesc),
                      trailing: Switch(
                        value: settings.showThumbnailPreview,
                        onChanged: (v) => settings.setShowThumbnailPreview(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.speed,
                      title: l10n.settingsPlayerRememberSpeed,
                      subtitle: Text(l10n.settingsPlayerRememberSpeedDesc),
                      trailing: Switch(
                        value: settings.rememberSpeed,
                        onChanged: (v) => settings.setRememberSpeed(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.volume_off_outlined,
                      title: l10n.settingsPlayerSaveVolumeToSystem,
                      subtitle: Text(l10n.settingsPlayerSaveVolumeToSystemDesc),
                      trailing: Switch(
                        value: settings.saveVolumeToSystem,
                        onChanged: (v) => settings.setSaveVolumeToSystem(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.pinch_outlined,
                      title: l10n.settingsPlayerPinchToZoom,
                      subtitle: Text(l10n.settingsPlayerPinchToZoomDesc),
                      trailing: Switch(
                        value: settings.enableShrinkVideo,
                        onChanged: (v) => settings.setEnableShrinkVideo(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.radio_button_checked,
                      title: l10n.settingsPlayerButtonBackground,
                      subtitle: Text(l10n.settingsPlayerButtonBackgroundDesc),
                      trailing: Switch(
                        value: settings.showButtonBackground,
                        onChanged: (v) => settings.setShowButtonBackground(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.skip_next_rounded,
                      title: l10n.settingsPlayerAutoNext,
                      subtitle: Text(l10n.settingsPlayerAutoNextDesc),
                      trailing: Switch(
                        value: settings.autoNext,
                        onChanged: (v) => settings.setAutoNext(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.exit_to_app,
                      title: l10n.settingsPlayerAutoExit,
                      subtitle: Text(l10n.settingsPlayerAutoExitDesc),
                      trailing: Switch(
                        value: settings.autoExit,
                        onChanged: (v) => settings.setAutoExit(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.speed_rounded,
                      title: l10n.settingsPlayerSpeedIndicator,
                      subtitle: Text(l10n.settingsPlayerSpeedIndicatorDesc),
                      trailing: Switch(
                        value: settings.showSpeedIndicator,
                        onChanged: (v) => settings.setShowSpeedIndicator(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.animation_outlined,
                      title: l10n.settingsPlayerUiAnimations,
                      subtitle: Text(l10n.settingsPlayerUiAnimationsDesc),
                      trailing: Switch(
                        value: settings.playerAnimations,
                        onChanged: (v) => settings.setPlayerAnimations(v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsTile(
                      icon: Icons.lock_open_outlined,
                      title: l10n.settingsPlayerLockExemptDoubleTap,
                      subtitle: Text(l10n.settingsPlayerLockExemptDoubleTapDesc),
                      trailing: Switch(
                        value: settings.lockGestureExempt,
                        onChanged: (v) =>
                            _onLockGestureExemptChanged(context, v),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    // 音量增强（组内最后一项）：开关 + 可折叠的上限滑杆。
                    SettingsTile(
                      icon: Icons.volume_up_outlined,
                      title: l10n.settingsPlayerVolumeBoost,
                      subtitle: Text(l10n.settingsPlayerVolumeBoostDesc),
                      trailing: Switch(
                        value: settings.volumeBoostEnabled,
                        onChanged: (v) => settings.setVolumeBoostEnabled(v),
                      ),
                    ),
                    // 上限滑杆：开启时展开，关闭时折叠（动画收起）
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: settings.volumeBoostEnabled
                          ? Column(
                              children: [
                                const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                _VolumeBoostCapTile(
                                  value: settings.volumeBoostCap,
                                  onChanged: settings.setVolumeBoostCap,
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              // 已观看进度阈值（视频列表「进度」字段的完成判定）
              SettingsGroupTitle(title: l10n.settingsPlayerWatchThreshold),
              SettingsCard(
                child: _WatchThresholdTile(
                  value: settings.watchThreshold,
                  onChanged: settings.setWatchThreshold,
                ),
              ),
              // ── 解码（GPU-next / Vulkan 可选渲染后端，重启播放器生效）──
              const SizedBox(height: 16),
              SettingsGroupTitle(title: l10n.playerActionDecode),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsSwitchTile(
                      icon: Icons.auto_awesome_outlined,
                      title: l10n.settingsPlayerEnableGpuNext,
                      subtitle: Text(l10n.settingsPlayerGpuNextDesc),
                      value: decodeSettings.gpuNext,
                      onChanged: (v) => _onGpuNextChanged(context, v),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsSwitchTile(
                      icon: Icons.memory_outlined,
                      title: l10n.settingsPlayerEnableVulkan,
                      subtitle: Text(l10n.settingsPlayerVulkanDesc),
                      value: decodeSettings.useVulkan,
                      onChanged: decodeSettings.gpuNext
                          ? (v) => _onVulkanChanged(context, v)
                          : null,
                    ),
                    // 禁用原因说明：`gpu-api` 只对 GPU-next 渲染器有效，
                    // vo=gpu 不认它——只把开关置灰会让用户以为坏了（可发现性）。
                    if (!decodeSettings.gpuNext)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(
                          l10n.settingsPlayerVulkanNeedsGpuNext,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        '${l10n.settingsPlayerRestartHint}'
                        '${l10n.settingsPlayerNoBlackScreenHint}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 启用「锁定状态豁免双击」前的二次确认。
  ///
  /// 锁定本就是给口袋/背包等误触场景用的保护，豁免双击等于在锁定态重新
  /// 打开一个会改变播放状态的手势，必须让用户在开启前知道代价；仅开启时
  /// 弹窗（关闭直接生效），取消则不写设置。
  Future<void> _onLockGestureExemptChanged(BuildContext context, bool v) async {
    if (!v) {
      PlayerControlsSettings.instance.setLockGestureExempt(false);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).settingsPlayerLockExemptDialogTitle),
        content: Text(
          AppLocalizations.of(ctx).settingsPlayerLockExemptDialogBody,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).commonEnable),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PlayerControlsSettings.instance.setLockGestureExempt(true);
    }
  }

  /// 启用「界面跟随重力旋转」前的二次确认。
  ///
  /// 这个开关有两个前提（系统「自动旋转」开着、「视频方向」= 自动），不满足时
  /// 开了也不生效——必须先讲清前提，否则用户会当成开关坏了。仅开启时弹窗
  ///（关闭直接生效），取消则不写设置。
  Future<void> _onFollowPhoneRotationChanged(
    BuildContext context,
    bool v,
  ) async {
    if (!v) {
      PlayerControlsSettings.instance.setFollowPhoneRotation(false);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).settingsPlayerGravityDialogTitle),
        content: Text(
          AppLocalizations.of(ctx).settingsPlayerGravityDialogBody,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).commonTurnOn),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PlayerControlsSettings.instance.setFollowPhoneRotation(true);
    }
  }

  /// 启用 GPU-next 前的二次确认：超分不可用 + 杜比视界提示。
  /// 仅开启时弹窗（关闭直接生效）；取消则不写设置。
  Future<void> _onGpuNextChanged(BuildContext context, bool v) async {
    if (!v) {
      DecodeSettings.instance.setGpuNext(false);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).settingsPlayerEnableGpuNext),
        content: Text(
          AppLocalizations.of(ctx).settingsPlayerGpuNextWarning,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).commonEnable),
          ),
        ],
      ),
    );
    if (ok == true) DecodeSettings.instance.setGpuNext(true);
  }

  /// 启用 Vulkan 前的二次确认（说明机制与回落行为）。
  /// 仅开启时弹窗（关闭直接生效）；取消则不写设置。
  Future<void> _onVulkanChanged(BuildContext context, bool v) async {
    if (!v) {
      DecodeSettings.instance.setVulkan(false);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).settingsPlayerEnableVulkan),
        content: Text(
          AppLocalizations.of(ctx).settingsPlayerVulkanWarning,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).commonEnable),
          ),
        ],
      ),
    );
    if (ok == true) DecodeSettings.instance.setVulkan(true);
  }
}

/// 音量/亮度手势灵敏度设置项：图标 + 标题 + 右侧倍率数值 + 滑杆（0.5x – 2.0x）。
/// 灵敏度含义：满屏滑动对应的量程倍率（1.0 = 满屏滑完整个量程）。
class _SensitivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const _SensitivityTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: kazumiSliderTheme(scheme),
            child: Slider(
              min: PlayerControlsSettings.minGestureSensitivity,
              max: PlayerControlsSettings.maxGestureSensitivity,
              divisions: 15,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 长按倍速设置项（滑杆式，参考快进/快退时长调节样式）：
/// 图标 + 固定标题 + 右侧倍率数值 + 滑杆（1 – 4 倍，步进 0.5，离散）。
class _LongPressSpeedTile extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _LongPressSpeedTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app_outlined,
                  size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).settingsPlayerLongPressSpeed,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toStringAsFixed(1)}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 1 – 4 倍、步进 0.5 共 7 档（(4-1)/0.5 = 6 个跨度）
          SliderTheme(
            data: kazumiSliderTheme(scheme).copyWith(
              tickMarkShape: const DenseSliderTickMarkShape(),
            ),
            child: Slider(
              min: PlayerControlsSettings.minLongPressSpeed,
              max: PlayerControlsSettings.maxLongPressSpeed,
              divisions: ((PlayerControlsSettings.maxLongPressSpeed -
                          PlayerControlsSettings.minLongPressSpeed) /
                      PlayerControlsSettings.longPressSpeedStep)
                  .round(),
              value: value,
              onChanged: onChanged,
            ),
          ),
          Text(
            AppLocalizations.of(context).settingsPlayerLongPressSpeedDesc,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 快进/快退时长设置项（Kazumi 风格）：
/// 左侧图标 + 固定标题，右侧数值胶囊（点击原地变输入框，1 – 600 秒），
/// 下方固定档位滑杆（5/10/15/20/25/30 秒）。
class _SeekSettingTile extends StatefulWidget {
  static const _gears = [5, 10, 15, 20, 25, 30];

  final int value;
  final ValueChanged<int> onChanged;

  const _SeekSettingTile({required this.value, required this.onChanged});

  @override
  State<_SeekSettingTile> createState() => _SeekSettingTileState();
}

class _SeekSettingTileState extends State<_SeekSettingTile> {
  bool _editing = false;
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller.text = '${widget.value}';
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  void _commit() {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < 1 || v > PlayerControlsSettings.maxSeekSeconds) {
      setState(
        () => _error = AppLocalizations.of(context).settingsPlayerSeekRange(
          PlayerControlsSettings.maxSeekSeconds,
        ),
      );
      return;
    }
    widget.onChanged(v);
    setState(() => _editing = false);
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 档位滑杆只覆盖 5–30，超出档位的手动值按边界显示，数值以右侧为准
    final sliderValue =
        widget.value.clamp(_SeekSettingTile._gears.first, _SeekSettingTile._gears.last).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fast_forward_rounded,
                  size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              // 固定标题：用户只可自定义秒数，不可改文本
              Expanded(
                child: Text(
                  AppLocalizations.of(context).settingsPlayerSeekSeconds,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 数值：点击原地变输入框（1 – 600 秒）
              if (_editing)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      suffixText: AppLocalizations.of(context).commonSeconds,
                      isDense: true,
                      errorText: _error,
                      errorStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _commit(),
                    onTapOutside: (_) => _cancel(),
                  ),
                )
              else
                GestureDetector(
                  onTap: _startEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context).commonSecondsValue(
                        widget.value,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSecondaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // 固定档位滑杆（Kazumi 风格：2024 新式、离散档位、无气泡）
          SliderTheme(
            data: kazumiSliderTheme(scheme),
            child: Slider(
              min: _SeekSettingTile._gears.first.toDouble(),
              max: _SeekSettingTile._gears.last.toDouble(),
              divisions: _SeekSettingTile._gears.length - 1,
              value: sliderValue,
              onChanged: (v) => widget.onChanged(v.round()),
            ),
          ),
          Text(
            AppLocalizations.of(context).settingsPlayerTapValueHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 「已观看」进度阈值设置项（滑杆式，5% – 100%，步进 5%，默认 95%）：
/// 视频列表「进度」字段据此判定 未观看 / 观看中 / 已看完（看完的卡片置灰）。
class _WatchThresholdTile extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _WatchThresholdTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).settingsPlayerWatchThresholdTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: kazumiSliderTheme(scheme).copyWith(
              tickMarkShape: const DenseSliderTickMarkShape(),
            ),
            child: Slider(
              min: PlayerControlsSettings.minWatchThreshold,
              max: PlayerControlsSettings.maxWatchThreshold,
              divisions: 19,
              value: value,
              onChanged: onChanged,
            ),
          ),
          Text(
            AppLocalizations.of(context).settingsPlayerWatchThresholdDesc,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 音量增强上限设置项（百分比滑杆，10% – 100%，步进 10%，默认 60%）：
/// 系统音量满 100% 后继续上滑，接管 mpv 音量放大至 `100 + cap`（最高 200%）。
class _VolumeBoostCapTile extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _VolumeBoostCapTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).settingsPlayerBoostCap,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '100% → ${100 + value}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: kazumiSliderTheme(scheme).copyWith(
              tickMarkShape: const DenseSliderTickMarkShape(),
            ),
            child: Slider(
              min: PlayerControlsSettings.minVolumeBoostCap.toDouble(),
              max: PlayerControlsSettings.maxVolumeBoostCap.toDouble(),
              divisions: PlayerControlsSettings.volumeBoostCapDivisions,
              value: value.toDouble(),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Text(
            AppLocalizations.of(context).settingsPlayerBoostCapDesc(100 + value),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
