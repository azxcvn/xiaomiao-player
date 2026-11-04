import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/player_loop.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/utils/app_dialog.dart';

/// 听视频界面底部面板（工作.md 阶段1 第 2 点重设计）：
///
/// 倍速面板与播放列表面板统一为**深色胶囊风格**，与听视频界面沉浸式暗色一体；
/// 两个面板都带右上角「关闭」按钮（旧版倍速有关闭、列表没有的不一致已修复）。
///
/// - [showAudioSpeedSheet]：倍速档位胶囊 + 「定时关闭」预设胶囊；
/// - [showAudioPlaylistSheet]：播放列表（当前项高亮 + 等化器动画）+ 随机/循环胶囊。
///
/// 面板内数据全部由听视频页传入并通过回调写回，面板自身无状态。

/// 面板深色背景
const Color kAudioPanelBg = Color(0xFF1C1C24);

/// 听视频循环模式：关闭 → 单曲循环 → 列表循环（点击循环按钮三态切换）
///
/// 值本身复用播放页的全局设置 [LoopMode]（`PlayerControlsSettings.loopMode`，
/// shared_preferences 持久化），这里只提供听视频的**点击顺序**与展示映射。
/// 注意点击顺序与 [LoopMode] 的枚举顺序不同：枚举顺序 off / loopAll /
/// repeatOne 是持久化约定（按 index 存），不能为了 UI 顺序去改它。
LoopMode _nextLoopMode(LoopMode mode) => switch (mode) {
      LoopMode.off => LoopMode.repeatOne,
      LoopMode.repeatOne => LoopMode.loopAll,
      LoopMode.loopAll => LoopMode.off,
    };

/// 循环按钮图标：关闭与列表循环都是重复箭头，单曲循环多一个「1」
IconData _loopModeIcon(LoopMode mode) => switch (mode) {
      LoopMode.off => Icons.repeat_rounded,
      LoopMode.repeatOne => Icons.repeat_one_rounded,
      LoopMode.loopAll => Icons.repeat_rounded,
    };

/// 定时关闭预设：关闭 / 15 分钟 / 30 分钟 / 60 分钟 / 自定义 / 播完当前曲目
enum AudioSleepPreset {
  off(Duration.zero),
  min15(Duration(minutes: 15)),
  min30(Duration(minutes: 30)),
  min60(Duration(minutes: 60)),
  custom(Duration.zero),
  trackEnd(Duration.zero);

  final Duration duration;
  const AudioSleepPreset(this.duration);
}

/// 循环模式文案（听视频这边仍用「单曲循环」的说法：循环单位是曲目；
/// 关闭复用 audioRepeatOff「循环关闭」，列表循环复用 loopModeLoopAll）
String _repeatModeLabel(AppLocalizations l10n, LoopMode mode) =>
    switch (mode) {
      LoopMode.off => l10n.audioRepeatOff,
      LoopMode.repeatOne => l10n.audioRepeatSingle,
      LoopMode.loopAll => l10n.loopModeLoopAll,
    };

/// 定时关闭预设文案
String _sleepPresetLabel(AppLocalizations l10n, AudioSleepPreset preset) =>
    switch (preset) {
      AudioSleepPreset.off => l10n.commonOff,
      AudioSleepPreset.min15 => l10n.audioSleepMinutes(15),
      AudioSleepPreset.min30 => l10n.audioSleepMinutes(30),
      AudioSleepPreset.min60 => l10n.audioSleepMinutes(60),
      AudioSleepPreset.custom => l10n.commonCustom,
      AudioSleepPreset.trackEnd => l10n.audioSleepEndOfTrack,
    };

// ────────────────────────────────────────────────────────────
// 倍速面板
// ────────────────────────────────────────────────────────────

/// 倍速面板：倍速档位胶囊 + 定时关闭预设胶囊（含自定义时长），右上角关闭按钮。
///
/// [sleepRemaining] 传 **ValueListenable** 而不是一次性快照：面板打开期间页面
/// 仍在每秒递减倒计时，只传快照的话「剩余 xx:xx」会定在打开那一刻（P3）。
Future<void> showAudioSpeedSheet(
  BuildContext context, {
  required double speed,
  required List<double> options,
  required ValueChanged<double> onSpeed,
  required AudioSleepPreset sleepPreset,
  required void Function(AudioSleepPreset preset, {Duration? custom}) onSleepPreset,
  ValueListenable<Duration?>? sleepRemaining,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kAudioPanelBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AudioPanelHeader(
              title: l10n.audioPlaybackSpeed,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in options)
                  _AudioChip(
                    label: '${s.toStringAsFixed(1)}x',
                    selected: (s - speed).abs() < 0.001,
                    onTap: () {
                      onSpeed(s);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _AudioSectionLabel(l10n.audioSleepTimer),
            const SizedBox(height: 8),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 10),
              Row(
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _AudioChip(
                        label: _sleepPresetLabel(
                          l10n,
                          AudioSleepPreset.values[row * 3 + col],
                        ),
                        selected:
                            sleepPreset == AudioSleepPreset.values[row * 3 + col],
                        expand: true,
                        onTap: () async {
                          final p = AudioSleepPreset.values[row * 3 + col];
                          if (p == AudioSleepPreset.custom) {
                            final minutes = await _showCustomSleepDialog(
                              sheetContext,
                            );
                            if (minutes == null) return;
                            onSleepPreset(
                              AudioSleepPreset.custom,
                              custom: Duration(minutes: minutes),
                            );
                          } else {
                            onSleepPreset(p);
                          }
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
            // 定时关闭激活时显示剩余时间（订阅 notifier：面板开着也会跳秒）
            if (sleepPreset != AudioSleepPreset.off) ...[
              const SizedBox(height: 12),
              _SleepRemainingLine(
                trackEnd: sleepPreset == AudioSleepPreset.trackEnd,
                remaining: sleepRemaining,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// 播放列表面板
// ────────────────────────────────────────────────────────────

/// 曲目行的**估算**行高（dense ListTile 在 1.0x 字号下约 48dp）。
///
/// 只用于「打开面板后把正在播放的曲目滚进视野」的初始偏移：真实行高随全局
/// 字号缩放（0.85x – 1.6x）变化，估算偏差只影响落点差几行，随后由
/// [_revealCurrentTile] 按真实布局精确居中。
const double _kAudioTileEstimateHeight = 56;

/// [_revealCurrentTile] 的最大重试轮数（长列表里估算偏差太大时修正一次就够）
const int _kRevealAttempts = 2;

/// 把当前播放项滚到列表中间（面板第一行建出来后调用）。
///
/// `ListView.builder` 只为视口附近的行建 widget，所以分两步：
/// 1. 打开时由 [ScrollController.initialScrollOffset] 按估算行高先滚过去，
///    让当前行进入构建范围（没建出来的行谈不上定位）；
/// 2. 当前行建出来之后，用 `Scrollable.ensureVisible` 按**真实布局**居中——
///    行高随全局字号缩放而变，估算只负责命中、不负责对齐。
///
/// 估算误差在长列表里会累计（1000 行能差几十行），这时第 2 步拿不到子节点：
/// 改用「均匀行高」比例配真实 [ScrollMetrics.maxScrollExtent] 修正一次再重试，
/// 最多重试 [_kRevealAttempts] 轮；仍拿不到就静默放弃，面板本身照常可用。
void _revealCurrentTile(
  GlobalKey tileKey,
  ScrollController controller,
  int index,
  int count, {
  int attempt = 0,
}) {
  final ctx = tileKey.currentContext;
  if (ctx != null) {
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 150),
      ),
    );
    return;
  }
  if (attempt >= _kRevealAttempts || !controller.hasClients || count < 2) {
    return;
  }
  final pos = controller.position;
  if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) return;
  // 均匀行高下「第 index 行」占整条列表的相对位置 × 真实可滚范围：结果恒在
  // 范围内（不会滚出界），偏差被压到一个视口内，下一轮就能建出当前行
  final target = (index / (count - 1)) * pos.maxScrollExtent;
  controller.jumpTo(
    target.clamp(pos.minScrollExtent, pos.maxScrollExtent),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _revealCurrentTile(
      tileKey,
      controller,
      index,
      count,
      attempt: attempt + 1,
    );
  });
}

/// 播放列表面板：曲目列表（当前项高亮）+ 随机/循环胶囊，右上角关闭按钮。
///
/// [repeatMode] 是**全局循环设置**当前值（[LoopMode]），点击循环按钮按
/// 「关闭 → 单曲循环 → 列表循环」顺序切换并通过 [onRepeatModeChanged]
/// 写回（由页面写入 `PlayerControlsSettings`）。
Future<void> showAudioPlaylistSheet(
  BuildContext context, {
  required List<VideoFile> videos,
  required int currentIndex,
  required bool shuffle,
  required LoopMode repeatMode,
  required ValueChanged<int> onSelect,
  required VoidCallback onToggleShuffle,
  required ValueChanged<LoopMode> onRepeatModeChanged,
}) {
  final l10n = AppLocalizations.of(context);
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  final sheetHeight =
      (MediaQuery.sizeOf(context).height * 0.42 - bottomInset)
          .clamp(280.0, double.infinity);
  // 面板内本地状态：随机/循环的展示值随点击即时更新，同时回调写回页面逻辑状态。
  var localShuffle = shuffle;
  var localRepeat = repeatMode;
  // 打开就落到正在播放的曲目（见 [_revealCurrentTile]）：靠后的索引（第 19 集）
  // 此刻还没建 widget，只能先按估算行高把滚动位置放过去，让它进入构建范围。
  final scrollController = ScrollController(
    initialScrollOffset: currentIndex * _kAudioTileEstimateHeight,
  );
  final currentTileKey = GlobalKey();
  var revealScheduled = false;
  final sheetFuture = showModalBottomSheet<void>(
    context: context,
    backgroundColor: kAudioPanelBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _AudioPanelHeader(
                  title: l10n.playerPlaylistWithCount(videos.length),
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: videos.length,
                  itemBuilder: (context, i) {
                    final cur = i == currentIndex;
                    final v = videos[i];
                    // 第一行建出来就安排一次「滚到当前曲目」：不依赖当前行本身
                    // 是否已建出来（长列表里估算偏差可能刚好错过当前行）
                    if (!revealScheduled) {
                      revealScheduled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _revealCurrentTile(
                          currentTileKey,
                          scrollController,
                          currentIndex,
                          videos.length,
                        );
                      });
                    }
                    return ListTile(
                      key: cur ? currentTileKey : null,
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: cur
                          ? _EqualizerBars(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const SizedBox(width: 14, height: 14),
                      title: Text(
                        v.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cur
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight:
                              cur ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onSelect(i);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // 底部：随机播放 / 循环模式（胶囊）
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AudioChip(
                      label: l10n.audioShuffle,
                      icon: Icons.shuffle_rounded,
                      selected: localShuffle,
                      onTap: () {
                        localShuffle = !localShuffle;
                        onToggleShuffle();
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 12),
                    _AudioChip(
                      label: _repeatModeLabel(l10n, localRepeat),
                      icon: _loopModeIcon(localRepeat),
                      selected: localRepeat != LoopMode.off,
                      onTap: () {
                        localRepeat = _nextLoopMode(localRepeat);
                        onRepeatModeChanged(localRepeat);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // 弹层没有 State 可挂 dispose，面板关掉后再释放滚动控制器
  unawaited(sheetFuture.whenComplete(scrollController.dispose));
  return sheetFuture;
}

// ────────────────────────────────────────────────────────────
// 公共小组件
// ────────────────────────────────────────────────────────────

/// 面板标题行：左侧标题 + 右侧关闭按钮（两个面板统一，工作.md 阶段1 第 2 点）
class _AudioPanelHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _AudioPanelHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
          tooltip: l10n.commonOff,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// 定时关闭的剩余时间行。
///
/// 面板打开期间倒计时仍在走，所以订阅 [remaining] 实时刷新，而不是收一个
/// 打开瞬间的时长快照（P3：旧实现「剩余时间定住不动」）。
class _SleepRemainingLine extends StatelessWidget {
  const _SleepRemainingLine({required this.trackEnd, required this.remaining});

  /// 「播完当前曲目」模式：显示固定文案，不显示倒计时。
  final bool trackEnd;

  /// 剩余时长（null = 倒计时已结束/未启动，按 0 显示）。
  final ValueListenable<Duration?>? remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 12,
    );
    if (trackEnd) {
      return Text(
        l10n.audioSleepEndOfTrackHint,
        textAlign: TextAlign.center,
        style: style,
      );
    }
    final listenable = remaining;
    if (listenable == null) {
      return Text(
        l10n.audioSleepRemaining(_fmtDuration(Duration.zero)),
        textAlign: TextAlign.center,
        style: style,
      );
    }
    return ValueListenableBuilder<Duration?>(
      valueListenable: listenable,
      builder: (_, value, _) => Text(
        l10n.audioSleepRemaining(_fmtDuration(value ?? Duration.zero)),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// 面板小节标题（如「定时关闭」）
class _AudioSectionLabel extends StatelessWidget {
  final String text;

  const _AudioSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 深色胶囊选项：选中主题主色填充，未选中半透明白底；可选前置图标。
/// [expand] 为 true 时占满父级宽度（等宽网格用），内容居中。
class _AudioChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  const _AudioChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? primary : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment:
              expand ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? onPrimary : Colors.white70),
              const SizedBox(width: 6),
            ],
            // 文案长度随语言变化（英文明显更长，如「播完当前」→ After track）：
            // 胶囊在等宽网格里宽度固定，Flexible + 省略号保证任何语言都不溢出
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? onPrimary : Colors.white,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 当前播放项的等化器跳动动画（三根竖条错相起伏）
class _EqualizerBars extends StatefulWidget {
  final Color color;

  const _EqualizerBars({required this.color});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 3,
                  height: 4 + 10 * _barFactor(t, i),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _barFactor(double t, int index) {
    final phase = (t + index / 3) % 1.0;
    return 0.35 + 0.65 * (1 - _cos2pi(phase * 2)) / 2;
  }

  static double _cos2pi(double x) {
    final xx = x - x.roundToDouble();
    return 1 - 2 * xx * xx * (3 - 2 * xx.abs());
  }
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 自定义定时关闭弹窗：滑杆选分钟（5 – 180，步进 5），确定返回分钟数。
Future<int?> _showCustomSleepDialog(BuildContext context) {
  int minutes = 30;
  return showAppDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF23232C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          AppLocalizations.of(dialogContext).audioSleepCustomTitle,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(dialogContext).audioSleepMinutes(minutes),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Theme.of(dialogContext).colorScheme.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
                thumbColor: Theme.of(dialogContext).colorScheme.primary,
                trackHeight: 3,
              ),
              child: Slider(
                value: minutes.toDouble().clamp(5, 180),
                min: 5,
                max: 180,
                divisions: 35,
                onChanged: (v) => setDialogState(() => minutes = v.round()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              AppLocalizations.of(dialogContext).commonCancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(minutes),
            child: Text(
              AppLocalizations.of(dialogContext).commonConfirm,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
