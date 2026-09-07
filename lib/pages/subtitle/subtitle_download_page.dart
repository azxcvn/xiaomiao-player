import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/pages/subtitle/subtitle_settings_page.dart';
import 'package:moumou/services/download/download_settings.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:moumou/utils/wyzie_filename.dart';
import 'package:moumou/utils/wyzie_query.dart';
import 'package:moumou/widgets/directory_picker_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 影视字幕下载页。
///
/// 顶部关键词输入 + 「确定」搜索；初始态展示「字幕设置」五入口与下载目录，
/// 搜索后呈现字幕结果列表（勾选 + 全选），底部「下载字幕」批量落盘到目录。
/// 字幕经 Wyzie 接口（sub.wyzie.io）搜索，独立直下（不进 B 站 DownloadManager）。
class SubtitleDownloadPage extends StatefulWidget {
  const SubtitleDownloadPage({super.key});

  @override
  State<SubtitleDownloadPage> createState() => _SubtitleDownloadPageState();
}

class _SubtitleDownloadPageState extends State<SubtitleDownloadPage> {
  final TextEditingController _keywordCtrl = TextEditingController();
  final WyzieApi _api = WyzieApi();

  bool _busy = false;
  bool _downloading = false;
  bool _searched = false;
  String? _error;
  List<WyzieSubtitle> _results = const [];
  final Set<int> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    WyzieSettings.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    DownloadSettings.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDir() async {
    final picked = await showDirectoryPickerDialog(context);
    if (picked != null) {
      await DownloadSettings.instance.setDirectory(picked);
      if (mounted) setState(() {});
    }
  }

  Future<void> _search() async {
    final keyword = _keywordCtrl.text.trim();
    if (keyword.isEmpty) return;
    // 未设置 WYZIE API 密钥时先提示（工作.md：密钥为用户自行粘贴）。
    if (WyzieSettings.instance.apiKey.isEmpty) {
      _toast('请先设置 WYZIE API 密钥');
      return;
    }
    if (!DownloadSettings.instance.hasDirectory) {
      _toast('请先设置下载目录');
      await _pickDir();
      if (!DownloadSettings.instance.hasDirectory) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
      _selected.clear();
      _searched = false;
      _query = keyword;
    });
    try {
      final settings = WyzieSettings.instance;
      final raw = await _api.search(
        query: keyword,
        apiKey: settings.apiKey,
        language: wyzieCommaParam(settings.languages),
        format: wyzieCommaParam(settings.formats),
        encoding: wyzieCommaParam(settings.encodings),
        source: wyzieSourceParam(settings.sources),
      );
      // Wyzie 常无视 language 参数返回全语言，本地按所选语言过滤兜底。
      final filtered = filterWyzieByLanguages(raw, settings.languages);
      if (!mounted) return;
      setState(() {
        _results = filtered;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (_selected.isEmpty || _downloading) return;
    if (!DownloadSettings.instance.directoryExists) {
      _toast('下载目录不存在，请重新选择');
      await _pickDir();
      if (!DownloadSettings.instance.directoryExists) return;
    }
    final dir = DownloadSettings.instance.directory;
    setState(() => _downloading = true);
    final used = <String>{};
    var ok = 0;
    var fail = 0;
    final indices = _selected.toList()..sort();
    for (var i = 0; i < indices.length; i++) {
      final sub = _results[indices[i]];
      try {
        final bytes = await _api.fetchBytes(sub.url);
        final base = wyzieSubtitleFileName(sub, fallbackTitle: _query);
        final name = uniqueFileName(base, used);
        used.add(name);
        await File('$dir/$name').writeAsBytes(bytes, flush: true);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    _toast(fail == 0 ? '已下载 $ok 个字幕' : '下载完成：成功 $ok，失败 $fail');
  }

  void _resetSearch() {
    setState(() {
      _results = const [];
      _selected.clear();
      _error = null;
      _searched = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _results.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('字幕下载')),
      body: Column(
        children: [
          _buildInput(),
          Expanded(child: _buildBody()),
          if (hasResults) _downloadBar(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '输入影视名称或 IMDB / TMDB ID',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : _search,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            TextButton(onPressed: _resetSearch, child: const Text('返回设置')),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      if (_searched) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '未找到字幕，请换个关键词或调整字幕设置',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(onPressed: _resetSearch, child: const Text('返回设置')),
            ],
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        children: [
          _dirTile(),
          SettingsCard(
            child: SettingsTile(
              icon: Icons.tune,
              title: '字幕下载设置',
              subtitle: const Text('API 密钥 / 字幕来源 / 语言 / 格式 / 编码'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubtitleSettingsPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '输入关键词后点「确定」搜索字幕',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _dirTile(),
        _headerBar(),
        _selectAllBar(),
        Expanded(child: _resultsList()),
      ],
    );
  }

  Widget _dirTile() {
    final scheme = Theme.of(context).colorScheme;
    final dir = DownloadSettings.instance.directory;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(
        dir.isEmpty ? '未设置下载目录' : DownloadSettings.instance.directoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      trailing: TextButton(onPressed: _pickDir, child: const Text('设置目录')),
    );
  }

  Widget _headerBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$_query · ${_results.length} 条',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: _resetSearch, child: const Text('重新搜索')),
        ],
      ),
    );
  }

  Widget _selectAllBar() {
    final all = _selected.length == _results.length && _results.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Checkbox(
            value: all,
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.addAll(List.generate(_results.length, (i) => i));
              } else {
                _selected.clear();
              }
            }),
          ),
          const Text('全选'),
          const Spacer(),
          Text('已选 ${_selected.length} / ${_results.length} 条'),
        ],
      ),
    );
  }

  Widget _resultsList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final sub = _results[i];
        return CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: _selected.contains(i),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(i);
            } else {
              _selected.remove(i);
            }
          }),
          title: Text(
            sub.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _metaChip(sub.displayLanguage),
                _metaChip(sub.source.isNotEmpty ? sub.source : '未知来源'),
                if (sub.format.isNotEmpty) _metaChip(sub.format.toUpperCase()),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 结果条目元数据胶囊标签（语言 / 来源 / 格式）。
  Widget _metaChip(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _downloadBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_downloading ? '下载中…' : '下载字幕（${_selected.length}）'),
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
      ));
  }

  String _errText(Object e) => e.toString().replaceFirst('WyzieApiException: ', '');
}
