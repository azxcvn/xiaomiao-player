import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/error_texts.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/services/subtitle/custom_subtitle_api.dart';
import 'package:moumou/services/subtitle/subtitle_source_settings.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 影视字幕下载页的「字幕设置」区。
///
/// 顶部是**字幕来源（单选，二选一）**：`Wyzie 字幕服务` / `自定义字幕地址`；
/// 下面是**当前来源的参数**：
/// - Wyzie：API 密钥 / 字幕来源 / 字幕语言 / 首选格式 / 首选编码（各弹对话框）；
/// - 自定义：地址模板（`{name}` 占位）+ 测试连接。
///
/// 来源选择读写在 [SubtitleSourceSettings]（单选，天然互斥——旧的需求是
/// 「两个开关互斥」，单选不会出现「都开/都关」的无意义状态）；
/// Wyzie 的五项偏好仍归 [WyzieSettings]。区块用 `ListenableBuilder`
/// 同时监听两者以刷新摘要。字幕来源列表经 [WyzieApi.getSources] 动态拉取并
/// 缓存，拉取失败回退静态来源表（对齐 mpvRx）。
class SubtitleSettingsSection extends StatefulWidget {
  const SubtitleSettingsSection({super.key, this.customApi});

  /// 测试注入的自定义源客户端（不传则自建，由本区块关闭）
  final CustomSubtitleApi? customApi;

  @override
  State<SubtitleSettingsSection> createState() => _SubtitleSettingsSectionState();
}

class _SubtitleSettingsSectionState extends State<SubtitleSettingsSection> {
  /// 密钥获取链接（工作.md：用户提供的飞书文档教程）。
  static const String _getKeyUrl =
      'https://acnmwaofo249.feishu.cn/wiki/UlcDwvf4TiPvQBkprQbcZgDJnse?from=from_copylink';

  /// 自定义接口地址的教程链接（用户提供的飞书文档）
  static const String _customUrlHelpUrl =
      'https://acnmwaofo249.feishu.cn/wiki/UnPnwpwwiiQFjNkcFu0cON9kn6e?from=from_copylink';

  final WyzieApi _api = WyzieApi();
  late final bool _ownsCustomApi = widget.customApi == null;
  late final CustomSubtitleApi _customApi =
      widget.customApi ?? CustomSubtitleApi();
  WyzieSourcesResponse? _sourcesResponse;

  WyzieSettings get _settings => WyzieSettings.instance;
  SubtitleSourceSettings get _source => SubtitleSourceSettings.instance;

  @override
  void dispose() {
    _api.close();
    if (_ownsCustomApi) _customApi.close();
    super.dispose();
  }

  /// 用外部浏览器打开链接（无浏览器/无处理者时静默，对齐 about_page 的容错）
  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // 静默：打不开教程不该影响设置本身
    }
  }

  Future<void> _openGetKey() => _openUrl(_getKeyUrl);

  Future<void> _openCustomUrlHelp() => _openUrl(_customUrlHelpUrl);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_settings, _source]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final custom = _source.kind == SubtitleSourceKind.custom;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroupTitle(title: l10n.subtitleSourceSection),
            SettingsCard(
              child: Column(
                children: [
                  SettingsRadioTile(
                    icon: Icons.cloud_outlined,
                    title: l10n.subtitleSourceWyzie,
                    subtitle: Text(l10n.subtitleWyzieDesc),
                    selected: !custom,
                    onTap: () => _source.setKind(SubtitleSourceKind.wyzie),
                  ),
                  const Divider(height: 1),
                  SettingsRadioTile(
                    icon: Icons.link,
                    title: l10n.subtitleSourceCustom,
                    subtitle: Text(l10n.subtitleCustomDesc),
                    selected: custom,
                    onTap: () => _source.setKind(SubtitleSourceKind.custom),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsGroupTitle(
              title: custom ? l10n.subtitleCustomParams : l10n.subtitleWyzieParams,
            ),
            SettingsCard(
              child: Column(
                children: custom ? _customTiles() : _wyzieTiles(),
              ),
            ),
            if (custom) ...[
              const SizedBox(height: 8),
              const _CustomSourceHint(),
            ],
          ],
        );
      },
    );
  }

  /// Wyzie 参数（原有五项，行为不变）
  List<Widget> _wyzieTiles() {
    final l10n = AppLocalizations.of(context);
    return [
        SettingsTile(
          icon: Icons.key_outlined,
          title: l10n.subtitleWyzieApiKey,
          subtitle: Text(_settings.apiKey.isEmpty ? l10n.commonNotSet : l10n.commonSaved),
          onTap: _editApiKey,
        ),
        const Divider(height: 1),
        SettingsTile(
          icon: Icons.dns_outlined,
          title: l10n.subtitleWyzieSources,
          subtitle: Text(_sourcesSummary()),
          onTap: _editSources,
        ),
        const Divider(height: 1),
        SettingsTile(
          icon: Icons.translate,
          title: l10n.subtitleLanguage,
          subtitle: Text(_languagesSummary()),
          onTap: _editLanguages,
        ),
        const Divider(height: 1),
        SettingsTile(
          icon: Icons.description_outlined,
          title: l10n.subtitlePreferredFormat,
          subtitle: Text(_formatsSummary()),
          onTap: _editFormats,
        ),
        const Divider(height: 1),
        SettingsTile(
          icon: Icons.text_fields,
          title: l10n.subtitlePreferredEncoding,
          subtitle: Text(_encodingsSummary()),
          onTap: _editEncodings,
        ),
      ];
  }

  /// 自定义来源参数：地址模板 + 测试连接
  List<Widget> _customTiles() {
    final l10n = AppLocalizations.of(context);
    return [
        SettingsTile(
          icon: Icons.link,
          title: l10n.subtitleApiEndpoint,
          subtitle: Text(
            _source.customConfigured
                ? _source.customUrlTemplate
                : l10n.commonNotSet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: _editCustomUrl,
        ),
        const Divider(height: 1),
        SettingsTile(
          icon: Icons.network_check,
          title: l10n.commonTestConnection,
          subtitle: Text(l10n.subtitleCustomTestHint),
          onTap: _source.customConfigured ? _testCustomSource : null,
        ),
      ];
  }

  // ── 自定义来源 ────────────────────────────────────────────

  Future<void> _editCustomUrl() {
    return showAppDialog<String>(
      context: context,
      builder: (_) => _CustomUrlDialog(
        initialUrl: _source.customUrlTemplate,
        onGetHelp: _openCustomUrlHelp,
      ),
    ).then((value) async {
      if (value != null) await _source.setCustomUrlTemplate(value);
    });
  }

  /// 测试连接：让用户填一个片名，请求一次并报告「解析出几条 / 失败原因」。
  ///
  /// 不预置片名：不同接口对「测试」这类假片名的返回差别很大，报错会误导用户。
  Future<void> _testCustomSource() async {
    final query = await showAppDialog<String>(
      context: context,
      builder: (_) => const _CustomTestDialog(),
    );
    if (query == null || query.trim().isEmpty) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _snack(l10n.subtitleTesting);
    try {
      final entries = await _customApi.search(
        urlTemplate: _source.customUrlTemplate,
        query: query.trim(),
      );
      if (!mounted) return;
      _snack(
        entries.isEmpty
            ? l10n.subtitleTestNoResult
            : l10n.subtitleTestOk(entries.length),
      );
    } on CustomSubtitleApiException catch (e) {
      if (!mounted) return;
      _snack(customSubtitleErrorText(l10n, e));
    } catch (e) {
      if (!mounted) return;
      _snack(l10n.subtitleTestFailed('$e'));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
      ));
  }

  String _sourcesSummary() {
    final s = _settings.sources;
    if (s.isEmpty || s.contains('all')) {
      return AppLocalizations.of(context).subtitleAllSources;
    }
    return s.map(_sourceName).join(AppLocalizations.of(context).commonListSeparator);
  }

  String _languagesSummary() {
    final s = _settings.languages;
    if (s.isEmpty || s.contains('all')) {
      return AppLocalizations.of(context).subtitleAllLanguages;
    }
    return s
        .map((k) => wyzieLanguages[k] ?? k)
        .join(AppLocalizations.of(context).commonListSeparator);
  }

  String _formatsSummary() {
    final s = _settings.formats;
    if (s.isEmpty || s.contains('all')) {
      return AppLocalizations.of(context).subtitleAllFormats;
    }
    return s
        .map((k) => wyzieFormats[k] ?? k)
        .join(AppLocalizations.of(context).commonListSeparator);
  }

  String _encodingsSummary() {
    final s = _settings.encodings;
    if (s.isEmpty || s.contains('all')) {
      return AppLocalizations.of(context).subtitleAllEncodings;
    }
    return s
        .map((k) => wyzieEncodings[k] ?? k)
        .join(AppLocalizations.of(context).commonListSeparator);
  }

  String _sourceName(String key) {
    if (key == 'all') return AppLocalizations.of(context).commonAll;
    final tiered = _sourcesResponse?.tiered;
    if (tiered != null) {
      for (final item in tiered) {
        if (item.key == key) return item.name;
      }
    }
    return wyzieFallbackSources[key] ?? key;
  }

  // ── API 密钥 ──────────────────────────────────────────────

  Future<void> _editApiKey() {
    return showAppDialog<void>(
      context: context,
      builder: (_) => _ApiKeyDialog(
        initialKey: _settings.apiKey,
        onGetKey: _openGetKey,
        onConfirm: (value) => _settings.setApiKey(value),
      ),
    );
  }

  // ── 字幕来源 ──────────────────────────────────────────────

  Future<void> _editSources() async {
    final result = await showAppDialog<Set<String>>(
      context: context,
      builder: (_) => _WyzieSourcesDialog(
        api: _api,
        apiKey: _settings.apiKey,
        selected: _settings.sources,
        cachedResponse: _sourcesResponse,
        onResponse: (resp) => _sourcesResponse = resp,
      ),
    );
    if (result != null) {
      await _settings.setSources(result);
    }
  }

  // ── 字幕语言 / 首选格式 / 首选编码 ────────────────────────

  Future<void> _editLanguages() => _showMultiSelect(
        title: AppLocalizations.of(context).subtitleLanguage,
        options: wyzieLanguagesSorted,
        selected: _settings.languages,
        hasAll: true,
        onConfirm: _settings.setLanguages,
      );

  Future<void> _editFormats() => _showMultiSelect(
        title: AppLocalizations.of(context).subtitlePreferredFormat,
        options: wyzieFormats,
        selected: _settings.formats,
        hasAll: true,
        onConfirm: _settings.setFormats,
      );

  Future<void> _editEncodings() => _showMultiSelect(
        title: AppLocalizations.of(context).subtitlePreferredEncoding,
        options: wyzieEncodings,
        selected: _settings.encodings,
        hasAll: true,
        onConfirm: _settings.setEncodings,
      );

  Future<void> _showMultiSelect({
    required String title,
    required Map<String, String> options,
    required Set<String> selected,
    required bool hasAll,
    required Future<void> Function(Set<String>) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context);
    var temp = Set<String>.from(selected);
    await showAppDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void toggle(String key, bool on) {
              setState(() {
                if (on) {
                  temp.remove('all');
                  temp.add(key);
                } else {
                  temp.remove(key);
                }
              });
            }

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: [
                    if (hasAll)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: temp.contains('all'),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            temp = {'all'};
                          } else {
                            temp.remove('all');
                          }
                        }),
                        title: Text(l10n.commonAll,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    for (final e in options.entries)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: temp.contains(e.key),
                        onChanged: (v) => toggle(e.key, v == true),
                        title: Text(e.value, style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirm(temp);
                  },
                  child: Text(l10n.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// WYZIE API 密钥编辑弹窗。
///
/// 输入框控制器由弹窗自身持有（initState 建 / dispose 释放），随路由完全卸载
/// 时才 dispose——避免在 `showAppDialog` 返回后立即手动 dispose 控制器，被
/// 退出动画期间的 TextField 继续引用导致「TextEditingController used after
/// being disposed」红屏。
class _ApiKeyDialog extends StatefulWidget {
  final String initialKey;
  final VoidCallback onGetKey;
  final ValueChanged<String> onConfirm;

  const _ApiKeyDialog({
    required this.initialKey,
    required this.onGetKey,
    required this.onConfirm,
  });

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.subtitleWyzieApiKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.subtitlePasteKeyHint,
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onGetKey,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.subtitleHowToGetKey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm(_ctrl.text);
          },
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}

/// 字幕来源选择弹窗：动态拉取 `/sources`（含免费/付费分层与密钥状态），
/// 拉取失败回退静态来源表；支持刷新。
class _WyzieSourcesDialog extends StatefulWidget {
  final WyzieApi api;
  final String apiKey;
  final Set<String> selected;
  final WyzieSourcesResponse? cachedResponse;
  final ValueChanged<WyzieSourcesResponse> onResponse;

  const _WyzieSourcesDialog({
    required this.api,
    required this.apiKey,
    required this.selected,
    required this.cachedResponse,
    required this.onResponse,
  });

  @override
  State<_WyzieSourcesDialog> createState() => _WyzieSourcesDialogState();
}

class _WyzieSourcesDialogState extends State<_WyzieSourcesDialog> {
  bool _loading = false;
  WyzieSourcesResponse? _response;
  late Set<String> _temp;

  @override
  void initState() {
    super.initState();
    _response = widget.cachedResponse;
    _temp = Set<String>.from(widget.selected);
    if (_response == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.api.getSources(apiKey: widget.apiKey);
      if (!mounted) return;
      setState(() => _response = resp);
      widget.onResponse(resp);
    } catch (_) {
      // 拉取失败回退静态来源表
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<WyzieSourceItem> get _items {
    final tiered = _response?.tiered;
    if (tiered != null && tiered.isNotEmpty) return tiered;
    return wyzieFallbackSources.entries
        .where((e) => e.key != 'all')
        .map(
          (e) => WyzieSourceItem(
            key: e.key,
            name: e.value,
            tier: wyzieFallbackIsFree(e.key) ? 'free' : 'paid',
          ),
        )
        .toList();
  }

  void _toggle(String key, bool on) {
    setState(() {
      if (on) {
        _temp.remove('all');
        _temp.add(key);
      } else {
        _temp.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final freeItems = _items.where((i) => i.isFree).toList();
    final paidItems = _items.where((i) => !i.isFree).toList();
    final keyInfo = _response?.key;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.subtitleSourceSection)),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView(
          children: [
            if (keyInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  keyInfo.valid
                      ? l10n.subtitleKeyType(
                          keyInfo.type.isNotEmpty
                              ? keyInfo.type
                              : l10n.commonUnknown,
                        )
                      : l10n.subtitleKeyInvalid,
                  style: TextStyle(
                    fontSize: 12,
                    color: keyInfo.valid ? scheme.primary : scheme.error,
                  ),
                ),
              ),
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _temp.contains('all'),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _temp = {'all'};
                } else {
                  _temp.remove('all');
                }
              }),
              title: Text(l10n.commonAll,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (freeItems.isNotEmpty) ...[
              _groupLabel(l10n.subtitleFreeSource),
              for (final item in freeItems) _sourceTile(item),
            ],
            if (paidItems.isNotEmpty) ...[
              _groupLabel(l10n.subtitlePaidSource),
              for (final item in paidItems) _sourceTile(item),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_temp),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }

  Widget _groupLabel(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: scheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sourceTile(WyzieSourceItem item) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: !_temp.contains('all') && _temp.contains(item.key),
      onChanged: item.available ? (v) => _toggle(item.key, v == true) : null,
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (!item.available) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock, size: 15, color: Theme.of(context).colorScheme.error),
          ],
        ],
      ),
    );
  }
}

/// 自定义来源的说明卡片：模板写法 + 隐私边界（片名会发往用户填的地址）。
class _CustomSourceHint extends StatelessWidget {
  const _CustomSourceHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Text(
        AppLocalizations.of(context).subtitleCustomSourceHelp('{name}'),
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 自定义地址编辑弹窗（控制器随路由卸载释放，同 [_ApiKeyDialog] 的约定）。
///
/// 底部带「如何自定义接口地址」教程入口（对齐密钥弹窗的「如何获取密钥」），
/// 点了用外部浏览器打开用户提供的飞书文档。
class _CustomUrlDialog extends StatefulWidget {
  final String initialUrl;
  final VoidCallback onGetHelp;

  const _CustomUrlDialog({
    required this.initialUrl,
    required this.onGetHelp,
  });

  @override
  State<_CustomUrlDialog> createState() => _CustomUrlDialogState();
}

class _CustomUrlDialogState extends State<_CustomUrlDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.subtitleSourceCustom),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'https://example.com/subtitle?name={name}',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.subtitlePlaceholderHelp('{name}'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onGetHelp,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.subtitleHowToCustomEndpoint),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// 测试连接弹窗：让用户填一个用于试搜的片名。
class _CustomTestDialog extends StatefulWidget {
  const _CustomTestDialog();

  @override
  State<_CustomTestDialog> createState() => _CustomTestDialogState();
}

class _CustomTestDialogState extends State<_CustomTestDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.commonTestConnection),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.subtitleTestNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.subtitleTestNameDesc,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l10n.commonTest),
        ),
      ],
    );
  }
}
