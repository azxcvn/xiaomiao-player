import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/services/app_font_settings.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:path/path.dart' as p;

/// App 字体设置页（工作.md 第 3 点）：
/// - 顶部「启用自定义字体」开关（关闭 = 跟随系统字体）；
/// - 启用后展开：字体预览（数字+符号一行 / 大写 / 小写 / 中文，统一字号）
///   + 导入字体（系统文件选择器）+ 字号/字重滑杆 + 一键重置。
///
/// 导入走系统文件选择器（ACTION_OPEN_DOCUMENT，MIME font/*）选单个字体，
/// 拷贝到 filesDir/fonts/ 后解析族名并 `loadFontFromList` 注册（§4.12）。
class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({super.key});

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  bool _importing = false;

  Future<void> _pickFont() async {
    final l10n = AppLocalizations.of(context);
    final uri = await DeviceServices.openFontPicker();
    if (uri == null || !mounted) return;
    setState(() => _importing = true);
    final path = await DeviceServices.copyFontFromUri(uri, 'custom_font.ttf');
    if (path == null || !mounted) {
      if (mounted) setState(() => _importing = false);
      return;
    }
    final family = await DeviceServices.getFontFamilyName(path);
    if (!mounted) return;
    setState(() => _importing = false);
    if (family.isEmpty) {
      _toast(l10n.settingsFontParseFailed);
      return;
    }
    await AppFontSettings.instance.setFont(family, p.basename(path));
    if (!mounted) return;
    _toast(l10n.settingsFontApplied(family));
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsFontTitle)),
      body: ListenableBuilder(
        listenable: AppFontSettings.instance,
        builder: (context, _) {
          final s = AppFontSettings.instance;
          final enabled = s.enabled;
          final hasFont = s.family != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              // ── 开关（最上方）────────────────────────
              SettingsCard(
                child: SettingsSwitchTile(
                  icon: Icons.font_download_outlined,
                  title: l10n.settingsFontEnable,
                  subtitle: Text(
                    enabled
                        ? l10n.settingsFontEnabledDesc
                        : l10n.settingsFontDisabledDesc,
                  ),
                  value: enabled,
                  onChanged: (v) => AppFontSettings.instance.setEnabled(v),
                ),
              ),
              if (enabled) ...[
                const SizedBox(height: 20),
                // ── 预览（数字+符号一行 / 大写 / 小写 / 中文，统一字号）──
                SettingsCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 数字与符号合并为一行，缩小字距
                      _PreviewText(
                        l10n.settingsFontPreviewSample,
                        fontSize: 12,
                        letterSpacing: -0.5,
                      ),
                      const SizedBox(height: 4),
                      _PreviewText(
                        'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                        fontSize: 12,
                        weight: FontWeight.w600,
                      ),
                      const SizedBox(height: 4),
                      _PreviewText(
                        'abcdefghijklmnopqrstuvwxyz',
                        fontSize: 12,
                      ),
                      const SizedBox(height: 4),
                      _PreviewText(
                        l10n.settingsFontPreviewText,
                        fontSize: 12,
                        height: 1.6,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.settingsFontPreviewHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SettingsGroupTitle(title: l10n.settingsFontGroupFont),
                SettingsCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      if (hasFont) ...[
                        SettingsSliderRow(
                          label: l10n.settingsFontSizeLabel,
                          display: '${s.textScale.toStringAsFixed(2)}x',
                          value: s.textScale,
                          min: AppFontSettings.minTextScale,
                          max: AppFontSettings.maxTextScale,
                          onChanged: (v) => s.setTextScale(v),
                        ),
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        SettingsSliderRow(
                          label: l10n.settingsFontWeightLabel,
                          display: appFontWeightLabel(
                            l10n,
                            s.fontWeightIndex,
                          ),
                          value: s.fontWeightIndex.toDouble(),
                          min: -1,
                          max: 8,
                          divisions: 9,
                          onChanged: (v) => s.setFontWeightIndex(v.round()),
                        ),
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ],
                      // 导入字体放在字重下方：拖动滑杆时无需上下滑动即可换字体
                      SettingsTile(
                        icon: Icons.upload_file_outlined,
                        title: _importing
                            ? l10n.settingsFontImporting
                            : l10n.settingsFontImport,
                        subtitle: Text(
                          hasFont
                              ? l10n.settingsFontCurrent(s.family!)
                              : l10n.settingsFontPickHint,
                        ),
                        trailing: hasFont
                            ? IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.grey,
                                ),
                                tooltip: l10n.settingsFontReselect,
                                onPressed: _importing ? null : _pickFont,
                              )
                            : null,
                        onTap: _importing ? null : _pickFont,
                      ),
                      if (hasFont) ...[
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: TextButton.icon(
                              onPressed: () async {
                                await s.setTextScale(1.0);
                                await s.setFontWeightIndex(-1);
                              },
                              icon: const Icon(Icons.restart_alt, size: 16),
                              label: Text(l10n.settingsFontReset),
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 预览文本行（继承全局 fontFamily，即当前生效字体）
class _PreviewText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight weight;
  final double? height;
  final double? letterSpacing;

  const _PreviewText(
    this.text, {
    required this.fontSize,
    this.weight = FontWeight.w400,
    this.height,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
