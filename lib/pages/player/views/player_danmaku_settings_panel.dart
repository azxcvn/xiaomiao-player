/// 弹幕设置面板（阶段2，工作.md 弹幕第 4 点）：两个部分组成——
///
/// **弹幕样式**：字号 / 字重 / 描边粗细 / 速度（数值越小越快）/ 不透明度
/// 全部为「松手才提交」项（见 [_CommitSliderTile]：拖动不写盘、不热更新）+
/// 随机渐变色开关（开启后忽略弹幕文件内颜色，所有弹幕按 HSV 色轮黄金角
/// 渐变随机着色，算法见 utils/danmaku_random_color.dart）；
///
/// **弹幕配置**：显示区域（10% 固定档位）/ 行高滑杆（同样松手才提交）+ 顶部/底部/滚动弹幕
/// 显隐开关 + 海量弹幕开关（轨道占满时叠加绘制）+ 弹幕去重开关（时间窗内
/// 相同内容合并为一条）+ 弹幕合并开关（不同时间内相同弹幕合并且计数）
/// + 屏蔽词（输入添加 / 词条删除 / 一键清空）。
///
/// **弹幕偏移**：时间轴偏移滑杆（-180~+180 秒，正 = 延后、负 = 提前），
/// 校准弹幕相对视频画面的显示时间（对齐 Kazumi danmakuTimeOffset）。
///
/// 所有设置持久化于 [DanmakuSettings]（全局单例），重启视频/重启播放/
/// 重启软件均保留（工作.md 弹幕第 6 点）；面板与 [DanmakuController]
/// 共同监听设置单例，改值即时生效无需重开面板。
///
/// 横屏在 [showPlayerPanel] 右侧滑入外壳、竖屏在 [showPlayerBottomPanel]
/// 底部弹出外壳共用本内容（§4.5 约定）；入口：横屏左下角时间右侧的
/// 弹幕设置按钮 / 竖屏右下角进度条上方的弹幕设置按钮 / 更多→弹幕→弹幕设置
/// （三处入口进入同一面板，工作.md 弹幕第 2 点）。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/danmaku_color_mode.dart';
import 'package:moumou/models/danmaku_font_mode.dart';
import 'package:moumou/models/subtitle_track.dart' show mpvColorToRgba;
import 'package:moumou/services/app_font_settings.dart';
import 'package:moumou/services/danmaku_settings.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/widgets/color_editor_row.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 与「设置」页面 / 字幕面板一致的滑杆主题（Kazumi 风格：缺口轨道 + 小柄
/// 拇指，无拖拽气泡——用户要的「字幕杂项」那种，而非默认大圆钮 + 气泡）。
///
/// **跟随主题**：强调色由 [playerPanelSliderTheme] 从当前 `ColorScheme.primary`
/// 派生暗色方案得到（原实现用写死的 `Color(0xFF4FC3F7)`，换主题色滑杆不变）。
SliderThemeData _panelSliderTheme(BuildContext context) =>
    playerPanelSliderTheme(context);

class PlayerDanmakuSettingsPanel extends StatelessWidget {
  const PlayerDanmakuSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DanmakuSettings.instance,
      builder: (context, _) {
        final s = DanmakuSettings.instance;
        final l10n = AppLocalizations.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(l10n.playerDanmakuStyle),
              _SettingsGroup(
                children: [
                  _CommitSliderTile(
                    label: l10n.playerDanmakuFontSize,
                    value: s.fontSize,
                    min: DanmakuSettings.minFontSize,
                    max: DanmakuSettings.maxFontSize,
                    display: (v) => v.round().toString(),
                    onCommit: s.setFontSize,
                  ),
                  _groupDivider(),
                  _CommitSliderTile(
                    label: l10n.settingsFontWeightLabel,
                    value: s.fontWeight.toDouble(),
                    min: DanmakuSettings.minFontWeight,
                    max: DanmakuSettings.maxFontWeight,
                    display: (v) => appFontWeightLabel(l10n, v.round()),
                    // 字重取整档（w100–w900 九档，滑杆无极拖动松手即最近档）
                    divisions: 8,
                    onCommit: (v) => s.setFontWeight(v.round()),
                  ),
                  _groupDivider(),
                  _CommitSliderTile(
                    label: l10n.playerDanmakuSpeed,
                    value: s.scrollSeconds,
                    min: DanmakuSettings.minScrollSeconds,
                    max: DanmakuSettings.maxScrollSeconds,
                    display: (v) => l10n.commonSecondsValue(v.round()),
                    hint: l10n.playerDanmakuSpeedDesc,
                    onCommit: s.setScrollSeconds,
                  ),
                  _groupDivider(),
                  _CommitSliderTile(
                    label: l10n.playerStrokeWidth,
                    value: s.strokeWidth,
                    min: DanmakuSettings.minStrokeWidth,
                    max: DanmakuSettings.maxStrokeWidth,
                    display: (v) => v == 0 ? l10n.commonNone : v.toStringAsFixed(1),
                    onCommit: s.setStrokeWidth,
                  ),
                  _groupDivider(),
                  _CommitSliderTile(
                    label: l10n.playerOpacity,
                    value: s.opacity,
                    min: DanmakuSettings.minOpacity,
                    max: DanmakuSettings.maxOpacity,
                    display: (v) => '${(v * 100).round()}%',
                    onCommit: s.setOpacity,
                  ),
                  _groupDivider(),
                  // ── 弹幕颜色三态（互斥单选）──
                  //
                  // 用户原始诉求是「开关一关就全白」，但那会否定弹幕自身颜色
                  // （B 站彩色弹幕与大会员渐变彩色全失效）。改为「保留原色为
                  // 默认 + 提供覆盖」，选「指定颜色」后才展开调色区。
                  for (final mode in DanmakuColorMode.values) ...[
                    _ColorModeTile(
                      mode: mode,
                      // 单选状态看**裸模式**：面板要如实显示「用户选了哪个」。
                      // （不能用 effectiveColorMode——调色板被清空时它会把
                      // 「指定颜色」显示成未选中，用户再点也进不去，正是真机
                      // 反馈的「点指定颜色没反应」；空调色板切进来时设置层会
                      // 自动补一个默认色，见 DanmakuSettings.setColorMode）
                      selected: s.colorMode == mode,
                      onTap: () => s.setColorMode(mode),
                    ),
                    if (mode != DanmakuColorMode.values.last) _groupDivider(),
                  ],
                  if (s.colorMode == DanmakuColorMode.fixed) ...[
                    _groupDivider(),
                    // 不加 `const`：面板外部改设置（如测试里直接调 API、恢复默认）
                    // 触发本面板重建时，const 实例会让这棵子树跳过重建，调色板停在
                    // 旧快照上（实测：settings 已是 2 色，UI 仍显示「已选 1/8 种」）
                    _ColorPaletteSection(),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(l10n.playerDanmakuConfig),
              _SettingsGroup(
                children: [
                  _CommitSliderTile(
                    label: l10n.playerDanmakuDisplayArea,
                    value: s.area,
                    min: DanmakuSettings.minArea,
                    max: DanmakuSettings.maxArea,
                    display: (v) => '${(v * 100).round()}%',
                    // 10% 一档（0.1–1.0 共 10 档，工作.md 弹幕第 3 点）
                    divisions: 9,
                    onCommit: s.setArea,
                  ),
                  _groupDivider(),
                  _CommitSliderTile(
                    label: l10n.playerDanmakuLineHeight,
                    value: s.lineHeight,
                    min: DanmakuSettings.minLineHeight,
                    max: DanmakuSettings.maxLineHeight,
                    display: (v) => v.toStringAsFixed(1),
                    onCommit: s.setLineHeight,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuTop,
                    value: s.showTop,
                    onChanged: s.setShowTop,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuBottom,
                    value: s.showBottom,
                    onChanged: s.setShowBottom,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuScroll,
                    value: s.showScroll,
                    onChanged: s.setShowScroll,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuMassive,
                    hint: l10n.playerDanmakuMassiveDesc,
                    value: s.massiveMode,
                    onChanged: s.setMassiveMode,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuDedupe,
                    hint: l10n.playerDanmakuDedupeDesc,
                    value: s.deduplication,
                    onChanged: s.setDeduplication,
                  ),
                  _groupDivider(),
                  _SwitchTile(
                    label: l10n.playerDanmakuMerge,
                    hint: l10n.playerDanmakuMergeDesc,
                    value: s.merge,
                    onChanged: s.setMerge,
                  ),
                  _groupDivider(),
                  // 不能加 const：父级 ListenableBuilder 重建时需刷新词条列表
                  _BlocklistTile(),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(l10n.playerDanmakuOffset),
              _SettingsGroup(
                children: [
                  _CommitSliderTile(
                    label: l10n.playerDanmakuTimelineOffset,
                    value: s.timeOffsetSeconds,
                    min: DanmakuSettings.minTimeOffsetSeconds,
                    max: DanmakuSettings.maxTimeOffsetSeconds,
                    display: (value) => danmakuOffsetText(l10n, value),
                    // 1 秒一档（-180~+180 共 360 档），松手提交重锚定弹幕
                    divisions: 360,
                    onCommit: s.setTimeOffset,
                  ),
                  _groupDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _OffsetActionButton(
                            icon: Icons.remove,
                            label: l10n.playerDanmakuAdvanceOneSecond,
                            enabled:
                                s.timeOffsetSeconds >
                                DanmakuSettings.minTimeOffsetSeconds,
                            onTap: () =>
                                s.setTimeOffset(s.timeOffsetSeconds - 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OffsetActionButton(
                            icon: Icons.add,
                            label: l10n.playerDanmakuDelayOneSecond,
                            enabled:
                                s.timeOffsetSeconds <
                                DanmakuSettings.maxTimeOffsetSeconds,
                            onTap: () =>
                                s.setTimeOffset(s.timeOffsetSeconds + 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: _OffsetActionButton(
                        icon: Icons.restart_alt,
                        label: l10n.playerDanmakuResetOffset,
                        enabled: s.timeOffsetSeconds != 0,
                        onTap: () => s.setTimeOffset(0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(l10n.playerDanmakuFont),
              // 不能加 const：否则父级 ListenableBuilder 重建时该子组件因
              // 同实例被跳过 build，切换字体模式后单选选中态/自定义段不刷新
              _DanmakuFontSection(),
              const SizedBox(height: 16),
              _ResetButton(onTap: () => DanmakuSettings.instance.reset()),
            ],
          ),
        );
      },
    );
  }

  /// 组内分隔线（与播放器设置分组卡一致：1px 缩进线）
  static Widget _groupDivider() => const Divider(
    height: 1,
    thickness: 0.5,
    indent: 16,
    endIndent: 16,
    color: Colors.white10,
  );
}

/// 分组标题（如「弹幕样式」「弹幕配置」）
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 暗底圆角分组容器（面板内卡片，内容为滑杆/开关行 + 缩进分隔线）
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// 重栅格化项滑杆（字号/字重/描边粗细/速度/不透明度/显示区域/行高）：拖动时只改
/// 本地预览值（不写设置、不触发 canvas 重绘），松手时才提交到 [DanmakuSettings]
/// （一次写盘 + 一次全量重绘）。避免 `onChanged` 逐像素写盘 + 全层热更新导致掉帧
/// （对齐弹幕移植方案「松手才 updateOption」纪律；P2-16 把最后四条实时写盘的滑杆
/// 也并入了这一纪律）。
class _CommitSliderTile extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double value) display;
  final String? hint;
  final int? divisions;
  final ValueChanged<double> onCommit;

  const _CommitSliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onCommit,
    this.hint,
    this.divisions,
  });

  @override
  State<_CommitSliderTile> createState() => _CommitSliderTileState();
}

class _CommitSliderTileState extends State<_CommitSliderTile> {
  late double _preview = widget.value;

  @override
  void didUpdateWidget(_CommitSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部提交（如恢复默认）后同步预览值，避免滑杆停留在旧值
    if (oldWidget.value != widget.value && widget.value != _preview) {
      _preview = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Text(
                widget.display(_preview),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (widget.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.hint!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          SliderTheme(
            data: _panelSliderTheme(context),
            child: Slider(
              value: _preview.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) => setState(() => _preview = v),
              onChangeEnd: widget.onCommit,
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹幕偏移的快捷操作按钮（提前/延后 1 秒 + 单独重置），紧凑胶囊样式，
/// 禁用态降透明度并阻断点击。
class _OffsetActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _OffsetActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹幕颜色模式单选行（跟随弹幕颜色 / 随机渐变色 / 指定颜色，互斥）。
///
/// 与「弹幕字体」段的三选一同款观感（右侧圆形勾选 + 说明文字），
/// 让「颜色」与「字体」两类互斥选项在面板里保持一致。
class _ColorModeTile extends StatelessWidget {
  final DanmakuColorMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ColorModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  /// 每种模式的说明（讲清「原色会不会被覆盖」）
  String _hintOf(AppLocalizations l10n) => switch (mode) {
    DanmakuColorMode.source => l10n.danmakuColorModeSourceDesc,
    DanmakuColorMode.random => l10n.danmakuColorModeRandomDesc,
    DanmakuColorMode.fixed => l10n.danmakuColorModeFixedDesc,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = playerPanelAccent(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          danmakuColorModeLabel(l10n, mode),
          style: TextStyle(
            color: selected ? accent : Colors.white,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          _hintOf(l10n),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, size: 18, color: accent)
            : const Icon(
                Icons.circle_outlined,
                size: 18,
                color: Colors.white24,
              ),
        onTap: onTap,
      ),
    );
  }
}

/// 弹幕「指定颜色」的**调色板**区（多选，选中几种就随机用这几种）。
///
/// 与原先「统一一个颜色」的区别只在**已选数量**：
/// - 选 1 种 = 旧行为（所有弹幕同一色）；
/// - 选 ≥2 种 = 每条弹幕从已选中随机抽一个（相邻两条不重色，
///   算法见 `utils/danmaku_palette_color.dart`）；
/// - 全部取消 → 设置层落空调色板 + 模式回落「跟随弹幕颜色」（选项区那三行
///   单选会立刻切回「跟随弹幕颜色」，不会留下选中了却没颜色的死状态）。
///
/// 交互仍是「点胶囊多选 + 自定义调色添加」，复用字幕那套 [ColorEditorRow]
/// （§4.5 不另写外壳），仅把它切到多选模式。
class _ColorPaletteSection extends StatefulWidget {
  const _ColorPaletteSection();

  @override
  State<_ColorPaletteSection> createState() => _ColorPaletteSectionState();
}

class _ColorPaletteSectionState extends State<_ColorPaletteSection> {
  /// 自定义调色的**草稿色**（已确认进调色板之前的候选）。
  ///
  /// 调色板本身是已确认的色；滑杆只动这个草稿，用户看预览点满意了点
  /// 「添加到调色板」才真正入列（真机反馈：滑到哪算哪种色是错的）。
  late String _draft = _initialDraft(DanmakuSettings.instance.colorValues);

  /// 草稿起点 = 调色板最后一色（面板刚展开时它就是当前色），空则默认白
  static String _initialDraft(List<String> values) =>
      values.isEmpty ? kDanmakuDefaultColor : values.last;

  /// 点胶囊 = 在调色板里加/减这一个色（不做「整体替换」，否则多选无从谈起）
  Future<void> _toggle(String hex) async {
    final l10n = AppLocalizations.of(context);
    final s = DanmakuSettings.instance;
    if (s.colorValues.any((v) => _sameColor(v, hex))) {
      await s.removeColorValue(hex);
      return;
    }
    if (s.colorValues.length >= DanmakuSettings.maxPaletteColors) {
      _toast(l10n.playerDanmakuPaletteMaxHint(DanmakuSettings.maxPaletteColors));
      return;
    }
    await s.addColorValue(hex);
  }

  /// 确认把草稿色加进调色板；成功后草稿回到调色板最后一色（= 当前色），
  /// 用户可以接着调下一个颜色。
  Future<void> _confirmDraft() async {
    final s = DanmakuSettings.instance;
    final had = s.colorValues.length;
    await s.addColorValue(_draft);
    if (s.colorValues.length == had) return; // 已存在或已满，什么都没发生
    if (!mounted) return;
    setState(() => _draft = s.colorValues.last);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// 同色判断按 RGBA 比（容忍 `#RRGGBB` / `#AARRGGBB` 写法与大小写差异）
  static bool _sameColor(String a, String b) {
    final x = mpvColorToRgba(a);
    final y = mpvColorToRgba(b);
    return x.r == y.r && x.g == y.g && x.b == y.b && x.a == y.a;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = DanmakuSettings.instance;
    final values = s.colorValues;
    final already = values.any((v) => _sameColor(v, _draft));
    final full = values.length >= DanmakuSettings.maxPaletteColors;
    final canAdd = !already && !full;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaletteStrip(
          values: values,
          // 点预览条上的色块即移除该色；移空后设置层会回落「跟随弹幕颜色」
          onRemove: s.removeColorValue,
        ),
        // 复用字幕那套调色件（预设色点 + 可展开 RGBA 滑杆），切多选模式：
        // 点胶囊 = 加/减该色；滑杆 = 只改「草稿色」，靠下面的按钮确认添加。
        //
        // `value` 传草稿色：预览点与滑杆起点都用它（自管状态，拖动不外泄）。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ColorEditorRow(
            label: l10n.playerDanmakuPaletteTitle,
            value: _draft,
            multiSelect: true,
            selectedValues: values,
            // 拖动只更新草稿（实时刷新下面「添加」按钮的可用性）；
            // 真正的入列动作在按钮上
            onPreview: (hex) {
              if (!mounted || hex == _draft) return;
              setState(() => _draft = hex);
            },
            onSelect: (hex) {
              if (hex != null) _toggle(hex);
            },
          ),
        ),
        // 自定义调色的确认按钮：滑杆只改草稿，点这里才入调色板
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canAdd ? _confirmDraft : null,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                already
                    ? l10n.playerDanmakuColorExists
                    : full
                    ? l10n.playerDanmakuPaletteFull(
                        DanmakuSettings.maxPaletteColors,
                      )
                    : l10n.playerDanmakuAddToPalette,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 调色板预览条：已选颜色圆点（点 × 移除）+ 「已选 N/M 种」计数。
class _PaletteStrip extends StatelessWidget {
  final List<String> values;
  final ValueChanged<String> onRemove;

  const _PaletteStrip({required this.values, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = playerPanelAccent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final hex in values) _swatch(hex, accent),
          Text(
            l10n.playerDanmakuPaletteSelected(
              values.length,
              DanmakuSettings.maxPaletteColors,
            ),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 预览条上的一个色块：**整块可点**即移除该色（右侧带 × 提示）。
  ///
  /// 不给 × 单独做触点：那个图标只有 15px，真机手指很难点中，
  /// 面板测试里点它也打不中（命中区域太小）。
  Widget _swatch(String hex, Color accent) {
    return GestureDetector(
      key: ValueKey('palette-tap-$hex'),
      onTap: () => onRemove(hex),
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: ValueKey('palette-x-$hex'),
        height: 28,
        padding: const EdgeInsets.only(left: 10, right: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colorFromMpvHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 0.5),
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 15, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// 开关行：标签（+ 可选说明）→ 右侧 Switch
class _SwitchTile extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 6),
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 屏蔽词管理（架构 §4.11「屏蔽词」）：折叠行，展开后输入添加 / 词条删除 /
/// 一键清空。列表持久化在 [DanmakuSettings]，发射前过滤见 danmaku_service
/// 的 `_effectiveEntries`。
class _BlocklistTile extends StatefulWidget {
  const _BlocklistTile();

  @override
  State<_BlocklistTile> createState() => _BlocklistTileState();
}

class _BlocklistTileState extends State<_BlocklistTile> {
  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await DanmakuSettings.instance.addBlockedKeyword(text);
    if (mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = DanmakuSettings.instance;
    final keywords = s.blockedKeywords;
    return Column(
      children: [
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.block, color: Colors.white, size: 22),
            title: Text(
              l10n.playerDanmakuBlockWords,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            subtitle: Text(
              keywords.isEmpty
                  ? l10n.commonNotSet
                  : keywords.join(l10n.commonListSeparator),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white54,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.playerDanmakuBlockWordsHint,
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _add(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _add,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(l10n.commonAdd),
                          ),
                        ],
                      ),
                      if (keywords.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final kw in keywords)
                              _KeywordChip(
                                label: kw,
                                onDelete: () => DanmakuSettings.instance
                                    .removeBlockedKeyword(kw),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                DanmakuSettings.instance.clearBlockedKeywords(),
                            child: Text(
                              l10n.commonClearAll,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 屏蔽词胶囊（词条 + 删除 ✕）
class _KeywordChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _KeywordChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 14, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// 一键恢复默认（红色胶囊，对齐片头片尾面板的重置按钮样式）
class _ResetButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ResetButton({required this.onTap});

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton> {
  bool _flash = false;

  void _handleTap() {
    setState(() => _flash = true);
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flash = false);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _flash ? scheme.error : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          l10n.commonRestoreDefaults,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _flash ? scheme.onError : scheme.error,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// 弹幕字体段（工作.md 第 4 点）：跟随系统 / 跟随 App / 自定义 三选一（互斥），
/// 选「自定义」时展开字体目录导入 + 字体列表选择。复用 filesDir/fonts/ 共享
/// 字体池（与字幕字体同目录，一次导入三处可用）。
class _DanmakuFontSection extends StatefulWidget {
  const _DanmakuFontSection();

  @override
  State<_DanmakuFontSection> createState() => _DanmakuFontSectionState();
}

class _DanmakuFontSectionState extends State<_DanmakuFontSection> {
  List<SubtitleFontEntry> _entries = const [];
  bool _loading = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _reloadEntries();
  }

  /// 重新扫描私有 fonts/ 目录（进入面板/导入后刷新字体列表）
  Future<void> _reloadEntries() async {
    final entries = await DeviceServices.listFontEntries();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  /// 选择字体目录 → 一次性拷贝全部字体 → 刷新列表
  Future<void> _pickDirectory() async {
    final l10n = AppLocalizations.of(context);
    final uri = await DeviceServices.openFontDirectoryPicker();
    if (uri == null || !mounted) return;
    setState(() => _loading = true);
    final count = await DeviceServices.copyFontsFromDirectory(uri);
    final entries = await DeviceServices.listFontEntries();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _entries = entries;
    });
    _toast(l10n.playerFontsImported(count, entries.length));
  }

  /// 选中弹幕自定义字体：写设置 + 注册进引擎（即时生效，冷启动再注册）
  Future<void> _selectFont(SubtitleFontEntry entry) async {
    await DanmakuSettings.instance.setCustomFont(entry.family, entry.file);
    await AppFontSettings.registerFontFile(entry.family, entry.file);
    if (!mounted) return;
    setState(() => _expanded = false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = DanmakuSettings.instance;
    final mode = s.fontMode;
    final appFamily = AppFontSettings.instance.effectiveFamily;
    final l10n = AppLocalizations.of(context);
    return _SettingsGroup(
      children: [
        _FontRadioTile(
          label: danmakuFontModeLabel(l10n, DanmakuFontMode.followSystem),
          selected: mode == DanmakuFontMode.followSystem,
          onTap: () => s.setFontMode(DanmakuFontMode.followSystem),
        ),
        PlayerDanmakuSettingsPanel._groupDivider(),
        _FontRadioTile(
          label: danmakuFontModeLabel(l10n, DanmakuFontMode.followApp),
          subtitle: appFamily,
          selected: mode == DanmakuFontMode.followApp,
          onTap: () => s.setFontMode(DanmakuFontMode.followApp),
        ),
        PlayerDanmakuSettingsPanel._groupDivider(),
        _FontRadioTile(
          label: danmakuFontModeLabel(l10n, DanmakuFontMode.custom),
          selected: mode == DanmakuFontMode.custom,
          onTap: () => s.setFontMode(DanmakuFontMode.custom),
        ),
        if (mode == DanmakuFontMode.custom) ...[
          PlayerDanmakuSettingsPanel._groupDivider(),
          _FontTile(
            icon: Icons.folder_open,
            title: l10n.playerPickFontDir,
            subtitle: _loading
                ? l10n.commonLoadingDots
                : (_entries.isEmpty
                      ? l10n.playerFontDirImportHint
                      : l10n.playerFontsLoaded(_entries.length)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: _loading ? null : _pickDirectory,
          ),
          if (_entries.isNotEmpty) ...[
            PlayerDanmakuSettingsPanel._groupDivider(),
            _FontTile(
              icon: Icons.text_fields,
              title: s.customFontFamily ?? l10n.playerPickFont,
              trailing: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white54,
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            // 展开/收起动画（字幕字体面板同款 AnimatedSize）
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      children: [
                        for (final e in _entries)
                          _FontOptionTile(
                            label: e.family,
                            subtitle: e.file,
                            selected: s.customFontFamily == e.family,
                            onTap: () => _selectFont(e),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ],
    );
  }
}

/// 弹幕字体三选一单选行（跟随系统 / 跟随 App / 自定义，互斥）
class _FontRadioTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FontRadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final accent = playerPanelAccent(context);
    // ListTile 外包 Material：_SettingsGroup 是带背景色的 Container，
    // 否则 ListTile 会因 DecoratedBox 遮挡 ink 而触发断言（§4.5 面板约定）
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        leading: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? accent : Colors.white24),
          ),
          child: selected
              ? const Icon(Icons.check, size: 13, color: Colors.black87)
              : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
        onTap: onTap,
      ),
    );
  }
}

/// 弹幕自定义字体选项行（单选高亮）
class _FontOptionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _FontOptionTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = playerPanelAccent(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 28, right: 16),
        leading: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? accent : Colors.white24),
          ),
          child: selected
              ? const Icon(Icons.check, size: 12, color: Colors.black87)
              : null,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 弹幕字体段内的通用图标行（选择字体目录 / 选择字体）
class _FontTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _FontTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.white, size: 22),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
