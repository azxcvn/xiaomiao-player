import 'package:flutter/material.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 影视字幕下载页的「字幕设置」区：WYZIE API 密钥、字幕来源、字幕语言、
/// 首选格式、首选编码五个入口（各弹选择/粘贴对话框）。
///
/// 设置读写在单例 [WyzieSettings]（持久化），区块用 `ListenableBuilder`
/// 监听以刷新摘要。字幕来源经 [WyzieApi.getSources] 动态拉取并缓存，
/// 拉取失败回退静态来源表（对齐 mpvRx）。
class SubtitleSettingsSection extends StatefulWidget {
  const SubtitleSettingsSection({super.key});

  @override
  State<SubtitleSettingsSection> createState() => _SubtitleSettingsSectionState();
}

class _SubtitleSettingsSectionState extends State<SubtitleSettingsSection> {
  /// 密钥获取链接（工作.md：用户提供的飞书文档教程）。
  static const String _getKeyUrl =
      'https://acnmwaofo249.feishu.cn/wiki/UlcDwvf4TiPvQBkprQbcZgDJnse?from=from_copylink';

  final WyzieApi _api = WyzieApi();
  WyzieSourcesResponse? _sourcesResponse;

  WyzieSettings get _settings => WyzieSettings.instance;

  Future<void> _openGetKey() async {
    final uri = Uri.parse(_getKeyUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 无浏览器/无处理者时静默（对齐 about_page 的容错）
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        return SettingsCard(
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.key_outlined,
                title: 'WYZIE API 密钥',
                subtitle: Text(_settings.apiKey.isEmpty ? '未设置' : '已保存'),
                onTap: _editApiKey,
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.dns_outlined,
                title: '字幕来源',
                subtitle: Text(_sourcesSummary()),
                onTap: _editSources,
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.translate,
                title: '字幕语言',
                subtitle: Text(_languagesSummary()),
                onTap: _editLanguages,
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.description_outlined,
                title: '首选格式',
                subtitle: Text(_formatsSummary()),
                onTap: _editFormats,
              ),
              const Divider(height: 1),
              SettingsTile(
                icon: Icons.text_fields,
                title: '首选编码',
                subtitle: Text(_encodingsSummary()),
                onTap: _editEncodings,
              ),
            ],
          ),
        );
      },
    );
  }

  String _sourcesSummary() {
    final s = _settings.sources;
    if (s.isEmpty || s.contains('all')) return '全部来源';
    return s.map(_sourceName).join('、');
  }

  String _languagesSummary() {
    final s = _settings.languages;
    if (s.isEmpty || s.contains('all')) return '全部语言';
    return s.map((k) => wyzieLanguages[k] ?? k).join('、');
  }

  String _formatsSummary() {
    final s = _settings.formats;
    if (s.isEmpty || s.contains('all')) return '全部格式';
    return s.map((k) => wyzieFormats[k] ?? k).join('、');
  }

  String _encodingsSummary() {
    final s = _settings.encodings;
    if (s.isEmpty || s.contains('all')) return '全部编码';
    return s.map((k) => wyzieEncodings[k] ?? k).join('、');
  }

  String _sourceName(String key) {
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
        title: '字幕语言',
        options: wyzieLanguagesSorted,
        selected: _settings.languages,
        hasAll: true,
        onConfirm: _settings.setLanguages,
      );

  Future<void> _editFormats() => _showMultiSelect(
        title: '首选格式',
        options: wyzieFormats,
        selected: _settings.formats,
        hasAll: true,
        onConfirm: _settings.setFormats,
      );

  Future<void> _editEncodings() => _showMultiSelect(
        title: '首选编码',
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
                        title: const Text('全部', style: TextStyle(fontSize: 14)),
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
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onConfirm(temp);
                  },
                  child: const Text('确定'),
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
    return AlertDialog(
      title: const Text('WYZIE API 密钥'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '粘贴密钥（wyzie-…）',
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onGetKey,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('如何获取密钥'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm(_ctrl.text);
          },
          child: const Text('确定'),
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
    final freeItems = _items.where((i) => i.isFree).toList();
    final paidItems = _items.where((i) => !i.isFree).toList();
    final keyInfo = _response?.key;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('字幕来源')),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
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
                      ? '密钥类型：${keyInfo.type.isNotEmpty ? keyInfo.type : '未知'}'
                      : '密钥无效',
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
              title: const Text('全部', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (freeItems.isNotEmpty) ...[
              _groupLabel('免费来源'),
              for (final item in freeItems) _sourceTile(item),
            ],
            if (paidItems.isNotEmpty) ...[
              _groupLabel('付费来源'),
              for (final item in paidItems) _sourceTile(item),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_temp),
          child: const Text('确定'),
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
