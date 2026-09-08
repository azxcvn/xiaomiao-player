import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_color_picker_plus/flutter_color_picker_plus.dart';
import 'package:moumou/pages/settings/font_page.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 外观设置子页：外观模式 / 主题色 / 调色板风格
///
/// 主题色：纯代表色块 + 名称，固定行列网格；调色板风格：固定网格按钮。
/// 两者均无预览、无布局跳动（选中态用边框 + 角标，格子尺寸恒定）。
class AppearancePage extends StatelessWidget {
  final ThemeController controller;

  const AppearancePage({super.key, required this.controller});

  IconData _modeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.amoled:
        return Icons.nights_stay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // 底部安全区已由全局 SafeArea 处理
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              // 外观模式
              const SettingsGroupTitle(title: '外观模式'),
              SettingsCard(
                child: Column(
                  children: [
                    for (final mode in AppThemeMode.values)
                      SettingsRadioTile(
                        icon: _modeIcon(mode),
                        title: mode.label,
                        selected: controller.mode == mode,
                        onTap: () => controller.setMode(mode),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 主题色：纯代表色块 + 名称（固定 4 列网格，卡片包裹）
              const SettingsGroupTitle(title: '主题色'),
              SettingsCard(
                padding: const EdgeInsets.all(12),
                child: _buildThemeColorSection(context, controller),
              ),
              const SizedBox(height: 20),
              // 调色板风格：标准型独占首行 + 其余 20 个 4×5（卡片包裹）
              const SettingsGroupTitle(title: '调色板风格'),
              SettingsCard(
                padding: const EdgeInsets.all(12),
                child: _buildVariantSection(context, controller),
              ),
              const SizedBox(height: 20),
              // ── App 字体设置（工作.md 第 3 点：调色板风格下方）────
              const SettingsGroupTitle(title: '字体'),
              SettingsCard(
                child: SettingsTile(
                  icon: Icons.font_download_outlined,
                  title: 'App字体设置',
                  subtitle: const Text('自定义全局字体'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FontSettingsPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 主题色区：23 预设 + 动态色 = 24 格（4×6 初版方格子）+ 下方通栏「自定义」。
  Widget _buildThemeColorSection(
    BuildContext context,
    ThemeController controller,
  ) {
    final presets = ThemeController.presetColors; // 23 个
    const totalCells = 24; // 23 预设 + 1 动态色

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < presets.length) {
              final preset = presets[index];
              return _colorTile(preset.color, preset.label, controller);
            }
            // 第 24 格：动态色
            return _buildDynamicTile(context, controller);
          },
        ),
        const SizedBox(height: 12),
        // 自定义（通栏胶囊，唯一保持现状的一行）
        _buildCustomTile(context, controller),
      ],
    );
  }

  /// 单个预设色块（初版：方形格子、色块填满、圆角矩形、标签下方）
  Widget _colorTile(
    Color color,
    String label,
    ThemeController controller,
  ) {
    final selected = controller.seedColor == color;
    return _SelectionTile(
      label: label,
      selected: selected,
      onTap: () => controller.setSeedColor(color),
      pill: false,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 「动态色」格子（第 24 格）：点击取壁纸主色；Android 12 以下 toast。
  Widget _buildDynamicTile(
    BuildContext context,
    ThemeController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _SelectionTile(
      label: '动态色',
      selected: controller.usingDynamicColor,
      onTap: () => _applyDynamicColor(context, controller),
      pill: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary,
              scheme.tertiary,
              scheme.secondary,
              scheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
      ),
    );
  }

  /// 「自定义」通栏块：显示已选自定义色（未设置显示➕），点击弹选色弹窗。
  /// 高度与下方调色板「标准型」通栏一致（aspect 7.2），胶囊样式。
  Widget _buildCustomTile(
    BuildContext context,
    ThemeController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final custom = controller.customColor;
    final selected =
        custom != null && controller.seedColor == custom && !controller.usingDynamicColor;
    return AspectRatio(
      aspectRatio: 7.2, // 通栏：与调色板标准型行等高
      child: GestureDetector(
        onTap: () => _pickCustomColor(context, controller),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '自定义',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 弹自定义选色弹窗（色相环 + SV 区 + hex 手输 + RGB/HSV/HSL 切换）。
  Future<void> _pickCustomColor(
    BuildContext context,
    ThemeController controller,
  ) async {
    final picked = await showAppDialog<Color>(
      context: context,
      builder: (ctx) => _CustomColorDialog(
        initialColor: controller.customColor ?? const Color(0xFF00A1D6),
      ),
    );
    if (picked != null) {
      await controller.setCustomColor(picked);
    }
  }

  /// 动态色：取系统壁纸主色作为 seed 立即生效。
  Future<void> _applyDynamicColor(
    BuildContext context,
    ThemeController controller,
  ) async {
    final sdk = await DeviceServices.getSdkInt();
    if (sdk > 0 && sdk < 31) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('安卓版本过低，不支持该功能')),
          );
      }
      return;
    }
    final color = await DeviceServices.getWallpaperPrimaryColor();
    if (color == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('无法读取壁纸颜色')));
      }
      return;
    }
    await controller.setDynamicColor(Color(color));
  }

  /// 调色板风格区：标准型独占首行，其余 20 个 4×5（胶囊化）。
  Widget _buildVariantSection(
    BuildContext context,
    ThemeController controller,
  ) {
    final entries = ThemeController.variantLabels.entries.toList();
    // 标准型 = tonalSpot 固定在首行；其余按地图顺序排
    final standard =
        entries.firstWhere((e) => e.key == FlexSchemeVariant.tonalSpot);
    final rest = entries.where((e) => e.key != FlexSchemeVariant.tonalSpot).toList();
    const perRow = 4;

    Widget variantTile(
      MapEntry<FlexSchemeVariant, String> entry, {
      double aspectRatio = 1.8,
    }) {
      final selected = controller.variant == entry.key;
      final scheme = Theme.of(context).colorScheme;
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: _SelectionTile(
          selected: selected,
          onTap: () => controller.setVariant(entry.key),
          pill: true,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontFamily:
                    Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // 首行：标准型独占（通栏，高度与其余行一致 = 4 格宽 ×1.8 反推 7.2）
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: variantTile(standard, aspectRatio: 7.2),
        ),
        // 其余 20 个：4×5
        for (var r = 0; r < 5; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (var c = 0; c < perRow; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: variantTile(rest[r * perRow + c]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 网格中的单个可选项：内容区 + 可选名称 + 选中高亮。
///
/// 选中效果符合当前主题（primaryContainer 背景 + primary 描边 + 角标），
/// 切换选中态时背景/描边/文字颜色平滑过渡，角标弹性弹出，格子尺寸恒定。
class _SelectionTile extends StatelessWidget {
  final Widget child;
  final String? label;
  final bool selected;
  final VoidCallback onTap;

  /// true = 胶囊（pill）圆角；false = 默认 12 圆角矩形
  final bool pill;

  const _SelectionTile({
    required this.child,
    required this.selected,
    required this.onTap,
    this.label,
    this.pill = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(pill ? 999 : 12),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.all(selected ? 3 : 4),
                    child: child,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (context, value, _) {
                        return Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surfaceContainerLow,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 10,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 12,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 自定义主题色弹窗：方块 SV 调色板 + 侧面色相条 + 当前预览 + hex 手输框 +
/// RGB/HSV/HSL 值切换胶囊（自绘数值，不用 ColorPickerLabel 避免 Dropdown 坑）。
/// 确定返回所选 [Color]，取消返回 null。
class _CustomColorDialog extends StatefulWidget {
  final Color initialColor;

  const _CustomColorDialog({required this.initialColor});

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late Color _color = widget.initialColor;
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);
  _ValueKind _valueKind = _ValueKind.rgb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('自定义主题色'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 方块 SV 调色板（纯饱和度/亮度，无色相）+ 下方横向色相滑条
              SizedBox(
                width: 280,
                height: 180,
                child: ColorPickerArea(
                  _hsv,
                  (c) => setState(() {
                    _hsv = c;
                    _color = c.toColor();
                  }),
                  PaletteType.hsv,
                ),
              ),
              const SizedBox(height: 8),
              // 横向色相滑条（需固定高度，ColorPickerSlider 内部是 CustomMultiChildLayout）
              SizedBox(
                height: 48,
                child: ColorPickerSlider(
                  TrackType.hue,
                  _hsv,
                  (c) => setState(() {
                    _hsv = c;
                    _color = c.toColor();
                  }),
                ),
              ),
              const SizedBox(height: 16),
              // 当前颜色预览 + hex 手输
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ColorPickerInput(
                      _color,
                      (c) => setState(() {
                        _color = c;
                        _hsv = HSVColor.fromColor(c);
                      }),
                      enableAlpha: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // RGB / HSV / HSL 值切换胶囊（三个等宽均分）
              Row(
                children: [
                  for (final k in _ValueKind.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                k.name.toUpperCase(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: _valueKind == k,
                            onSelected: (_) =>
                                setState(() => _valueKind = k),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: _valueKind == k
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            selectedColor: scheme.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // 数值文本：胶囊背景包裹 + 居中，宽度撑满整行（与上方三按钮总长一致）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _valueText(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('确定'),
        ),
      ],
    );
  }

  /// 按当前选中类型生成可读数值文本（RGB 整数 / HSV 度·百分比 / HSL）
  String _valueText() {
    final c = _color;
    switch (_valueKind) {
      case _ValueKind.rgb:
        final r = (c.r * 255).round();
        final g = (c.g * 255).round();
        final b = (c.b * 255).round();
        return 'R $r  G $g  B $b';
      case _ValueKind.hsv:
        final h = _hsv.hue.round();
        final s = (_hsv.saturation * 100).round();
        final v = (_hsv.value * 100).round();
        return 'H $h°  S $s%  V $v%';
      case _ValueKind.hsl:
        final hsl = HSLColor.fromColor(c);
        final h = hsl.hue.round();
        final s = (hsl.saturation * 100).round();
        final l = (hsl.lightness * 100).round();
        return 'H $h°  S $s%  L $l%';
    }
  }
}

enum _ValueKind { rgb, hsv, hsl }
