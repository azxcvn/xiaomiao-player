/// 通用「颜色编辑行」：标题 + 颜色预览点 + 预设色胶囊 + 可展开的 RGBA 滑杆。
///
/// 原先内嵌在字幕面板（`pages/player/views/subtitle_panel.dart` 的
/// `_ColorEditorRow`），弹幕「指定颜色」也要同一套交互，故抽到 widgets 层
/// 共用（§4.5「不得另写一套外壳」的同一纪律）。
///
/// 观感依赖播放器暗色面板的两件套（`playerPanelAccent` /
/// `playerPanelSliderTheme`，见 `widgets/settings_ui.dart`），因此本组件
/// 只适合放在播放器面板内使用。
library;

import 'package:flutter/material.dart';

import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// mpv 颜色串（`#RRGGBB` / `#AARRGGBB`，8 位时 alpha 在前）→ Flutter [Color]
/// （同样为 ARGB）。
Color colorFromMpvHex(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length == 8) {
    final val = int.tryParse(h, radix: 16);
    return val != null ? Color(val) : Colors.white;
  }
  if (h.length == 6) {
    final val = int.tryParse(h, radix: 16);
    return val != null ? Color(0xFF000000 | val) : Colors.white;
  }
  return Colors.white;
}

Color _accentOf(BuildContext context) => playerPanelAccent(context);

SliderThemeData _panelSliderTheme(BuildContext context) =>
    playerPanelSliderTheme(context);

/// 单个颜色的编辑行：标题 + 预览点 + 预设色胶囊 +「自定义调色」展开的 RGBA 滑杆。
///
/// [onSelect] 用于**精确提交**（点预设色 / 滑杆松手）；[onSlide] 用于**拖动中**
/// 实时下发（不需要实时预览的场景可不传，此时只在松手时提交一次）。
class ColorEditorRow extends StatefulWidget {
  /// 行标题（如「弹幕颜色」「文字颜色」）
  final String label;

  /// 当前颜色（mpv 串，如 `#FFFFFFFF`）；null 表示「无 / 不指定」
  final String? value;

  /// 是否允许「无」这一项（null 值）
  final bool allowNone;

  /// 未设置颜色时滑杆的起点色
  final SubtitleRgba defaultColor;

  /// 预设色列表（默认取字幕文字预设色，含白色）
  final List<SubtitlePresetColor> presetColors;

  /// 精确提交（点预设色 / 滑杆松手）
  final ValueChanged<String?> onSelect;

  /// 拖动中实时提交（可选）
  final ValueChanged<String?>? onSlide;

  const ColorEditorRow({
    super.key,
    required this.label,
    required this.value,
    this.allowNone = false,
    this.defaultColor = const (r: 255, g: 255, b: 255, a: 255),
    this.presetColors = SubtitlePresetColor.textPresets,
    required this.onSelect,
    this.onSlide,
  });

  @override
  State<ColorEditorRow> createState() => _ColorEditorRowState();
}

class _ColorEditorRowState extends State<ColorEditorRow> {
  bool _custom = false;

  /// **拖动中的本地预览色**（mpv 串）。null = 未拖动，显示 [widget.value]。
  ///
  /// 有它才能"边拖边看"：拖动中实时更新标题左侧的预览点与各通道读数，
  /// 但**不写设置**（写设置会 `notifyListeners` 触发播放器面板整棵重建 →
  /// 拖动卡顿）。松手走 [widget.onSelect] 一次性提交。
  String? _previewColor;

  /// 当前生效色（拖动中优先用预览色）
  String? get _effectiveValue => _previewColor ?? widget.value;

  /// 当前 RGBA 基准（无颜色时用默认色，滑杆才有可拖的起点）
  SubtitleRgba get _base {
    final v = _effectiveValue;
    return v != null ? mpvColorToRgba(v) : widget.defaultColor;
  }

  /// 把「某一通道新值 + 其余通道当前值」合成为预览色。
  ///
  /// 拖动中：[onSlide] 有实现时交给调用方（字幕面板直连 mpv 用），
  /// 否则至少更新本地预览，避免"盲拖"。
  void _previewChannel(SubtitleRgba Function(SubtitleRgba base) update) {
    final next = rgbaToMpvColor(update(_base));
    if (_previewColor != next) setState(() => _previewColor = next);
    widget.onSlide?.call(next);
  }

  /// 松手：清预览态 + 一次性提交（此后以 [widget.value] 为准）
  void _commitChannel(SubtitleRgba Function(SubtitleRgba base) update) {
    final next = rgbaToMpvColor(update(_base));
    setState(() => _previewColor = null);
    widget.onSelect(next);
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    final effective = _effectiveValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标题 + 颜色预览点（拖动中跟随预览色实时变化，不盲拖）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: effective == null
                      ? Colors.black26
                      : colorFromMpvHex(effective),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: effective == null ? Colors.white24 : Colors.white38,
                  ),
                ),
                child: effective == null
                    ? const Icon(Icons.block, size: 12, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 预设色胶囊（一行或两行排布）
        _buildPresets(),
        const SizedBox(height: 8),
        // 下方独立一行全宽「自定义」胶囊（与预设胶囊总宽度一致）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => setState(() => _custom = !_custom),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _custom
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _custom ? _accentOf(context) : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _custom ? '收起自定义调色' : '自定义调色',
                    style: TextStyle(
                      color: _custom ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _custom ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 展开的 RGBA 四通道滑杆
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _custom ? _buildChannels(base) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 预设色胶囊（多行自适应等宽）
  Widget _buildPresets() {
    final allItems = <({String? hex, String label})>[
      if (widget.allowNone) (hex: null, label: '无'),
      for (final c in widget.presetColors) (hex: c.hex, label: c.label),
    ];

    // 一行最多 4 项，超过则 3 + 剩余 换行。
    // 不再额外加「当前」胶囊——当前色已由左上角预览点体现。
    final List<List<({String? hex, String label})>> rows = allItems.length <= 4
        ? [allItems]
        : [allItems.sublist(0, 3), allItems.sublist(3)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var j = 0; j < rows[i].length; j++) ...[
                  if (j > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ColorDot(
                      hex: rows[i][j].hex,
                      label: rows[i][j].label,
                      selected: rows[i][j].hex == null
                          ? widget.value == null
                          : _matchesPreset(rows[i][j].hex!),
                      onTap: () => widget.onSelect(rows[i][j].hex),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _matchesPreset(String hex) {
    if (widget.value == null) return false;
    final a = mpvColorToRgba(widget.value!);
    final b = mpvColorToRgba(hex);
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
  }

  /// RGBA 四通道滑杆。
  ///
  /// 拖动中走 [_previewChannel]（本地预览跟随，必要时再由调用方实时下发），
  /// 松手走 [_commitChannel]（一次性提交设置）。四通道都基于 [_base] 合成，
  /// 因此调整某个通道不会丢掉其它通道刚拖出的值。
  Widget _buildChannels(SubtitleRgba base) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          _ChannelSlider(
            label: 'R',
            trackColor: const Color(0xFFE53935),
            value: base.r,
            onChanged: (v) =>
                _previewChannel((b) => (r: v, g: b.g, b: b.b, a: b.a)),
            onChangeEnd: (v) =>
                _commitChannel((b) => (r: v, g: b.g, b: b.b, a: b.a)),
          ),
          _ChannelSlider(
            label: 'G',
            trackColor: const Color(0xFF43A047),
            value: base.g,
            onChanged: (v) =>
                _previewChannel((b) => (r: b.r, g: v, b: b.b, a: b.a)),
            onChangeEnd: (v) =>
                _commitChannel((b) => (r: b.r, g: v, b: b.b, a: b.a)),
          ),
          _ChannelSlider(
            label: 'B',
            trackColor: const Color(0xFF1E88E5),
            value: base.b,
            onChanged: (v) =>
                _previewChannel((b) => (r: b.r, g: b.g, b: v, a: b.a)),
            onChangeEnd: (v) =>
                _commitChannel((b) => (r: b.r, g: b.g, b: v, a: b.a)),
          ),
          _ChannelSlider(
            label: 'A',
            trackColor: const Color(0xFF9E9E9E),
            value: base.a,
            onChanged: (v) =>
                _previewChannel((b) => (r: b.r, g: b.g, b: b.b, a: v)),
            onChangeEnd: (v) =>
                _commitChannel((b) => (r: b.r, g: b.g, b: b.b, a: v)),
          ),
        ],
      ),
    );
  }
}

/// 预设色胶囊（圆形色块 + 名称，选中带勾）
class _ColorDot extends StatelessWidget {
  final String? hex;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ColorDot({
    this.hex,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _accentOf(context) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: hex == null ? Colors.black26 : colorFromMpvHex(hex!),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hex == null ? Colors.white24 : Colors.white38,
                  width: 0.5,
                ),
              ),
              child: hex == null
                  ? const Icon(Icons.block, size: 9, color: Colors.white70)
                  : (selected
                        ? const Icon(
                            Icons.check,
                            size: 9,
                            color: Colors.black54,
                          )
                        : null),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// RGBA 单个通道滑杆（设置页同款外观），左侧通道色块 + 读数。
///
/// [onChanged] 拖动中实时下发，[onChangeEnd] 松手精确提交。
class _ChannelSlider extends StatefulWidget {
  final String label;
  final Color trackColor;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  const _ChannelSlider({
    required this.label,
    required this.trackColor,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_ChannelSlider> createState() => _ChannelSliderState();
}

class _ChannelSliderState extends State<_ChannelSlider> {
  /// 拖动中的本地预览值（非 null 时优先于 [widget.value]）
  int? _dragValue;

  @override
  void didUpdateWidget(covariant _ChannelSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部提交（点预设色 / 恢复默认 / 别处改色）后跟随新值；
    // 拖动期间不跟随，避免被父级重建打回起点
    if (_dragValue == null && oldWidget.value != widget.value) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.value;
    return Row(
      children: [
        Container(
          width: 26,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.trackColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            // RGBA 通道滑杆按通道着色（R/G/B/A 各自颜色），不跟随主题：
            // 轨道色就是该通道语义本身，换主题色会让「R 是红的」失去意义
            data: _panelSliderTheme(context).copyWith(
              activeTrackColor: widget.trackColor,
              thumbColor: widget.trackColor,
            ),
            child: Slider(
              min: 0,
              max: 255,
              value: value.toDouble(),
              onChanged: (v) {
                // 本地预览：不碰设置、不触发上层重建（卡顿根因就在这）
                setState(() => _dragValue = v.round());
                widget.onChanged(v.round());
              },
              onChangeEnd: (v) {
                setState(() => _dragValue = null);
                widget.onChangeEnd(v.round());
              },
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
