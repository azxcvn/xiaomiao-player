import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/error_texts.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/subtitle_entry.dart';
import 'package:moumou/pages/subtitle/subtitle_settings_page.dart';
import 'package:moumou/services/download/download_settings.dart';
import 'package:moumou/services/subtitle/custom_subtitle_api.dart';
import 'package:moumou/services/subtitle/subtitle_source_settings.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:moumou/utils/async_session.dart';
import 'package:moumou/utils/wyzie_filename.dart';
import 'package:moumou/utils/wyzie_query.dart';
import 'package:moumou/widgets/directory_picker_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 影视字幕下载页。
///
/// 顶部关键词输入 + 「确定」搜索；初始态展示「字幕设置」入口与下载目录，
/// 搜索后呈现字幕结果列表（勾选 + 全选），底部「下载字幕」批量落盘到目录。
///
/// **来源可切**（[SubtitleSourceSettings] 单选，二选一）：
/// - `Wyzie`：经 sub.wyzie.io 搜索（需 API 密钥，原有链路）；
/// - `自定义地址`：请求用户自填的地址模板，响应自动嗅探解析
///   （见 `utils/custom_subtitle_parser.dart`）。
/// 两条链路都**独立直下**（不进 B 站 DownloadManager），结果统一为
/// [SubtitleEntry]。
///
/// 两条并发纪律（B12）：
/// - **搜索以会话号裁决**：连按两次回车（Enter 曾绕过 `_busy`）也照常发起，结果与
///   转圈状态永远属于**最后一次**输入（P2-35，与 §4.11 网络弹幕搜索同一套）；
/// - **下载对选中项做快照**：下载期间用户可改关键词重新搜索（结果列表被替换），
///   按索引取会在循环里越界（RangeError）并把「下载中」永久卡死（P2-36）。
class SubtitleDownloadPage extends StatefulWidget {
  const SubtitleDownloadPage({
    super.key,
    this.api,
    this.customApi,
    this.writeBytes,
  });

  /// 测试注入的 Wyzie API（不传则自建，并在 [State.dispose] 关闭）。
  final WyzieApi? api;

  /// 测试注入的自定义源 API（不传则自建，并在 [State.dispose] 关闭）。
  final CustomSubtitleApi? customApi;

  /// 测试注入的写盘实现（默认 `File.writeAsBytes`）。
  ///
  /// `testWidgets` 的假时钟不会推进真实 `dart:io` 写盘，注入内存实现后才能
  /// 覆盖「下载中改关键词重新搜索」这条时序（P2-36）。
  final Future<void> Function(String path, List<int> bytes)? writeBytes;

  @override
  State<SubtitleDownloadPage> createState() => _SubtitleDownloadPageState();
}

class _SubtitleDownloadPageState extends State<SubtitleDownloadPage> {
  final TextEditingController _keywordCtrl = TextEditingController();

  /// 自建的 API 才由本页关闭（注入的归调用方，§4.21 / §4.36 同一约定）。
  late final bool _ownsApi = widget.api == null;
  late final WyzieApi _api = widget.api ?? WyzieApi();
  late final bool _ownsCustomApi = widget.customApi == null;
  late final CustomSubtitleApi _customApi =
      widget.customApi ?? CustomSubtitleApi();
  late final Future<void> Function(String path, List<int> bytes) _writeBytes =
      widget.writeBytes ?? _writeFileBytes;

  /// 搜索会话号：只有最新一次搜索能写结果 / 复位转圈。
  final AsyncSession _searchSession = AsyncSession();

  bool _busy = false;
  bool _downloading = false;
  bool _searched = false;
  String? _error;
  List<SubtitleEntry> _results = const [];
  final Set<int> _selected = {};
  String _query = '';

  /// 当前结果是用哪个来源搜出来的（下载按它选客户端：搜索期间用户可能切了来源）
  SubtitleSourceKind _resultKind = SubtitleSourceKind.wyzie;

  SubtitleSourceSettings get _source => SubtitleSourceSettings.instance;

  @override
  void initState() {
    super.initState();
    _source.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
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
    if (_ownsApi) _api.close();
    if (_ownsCustomApi) _customApi.close();
    super.dispose();
  }

  Future<void> _pickDir() async {
    final picked = await showDirectoryPickerDialog(context);
    if (picked != null) {
      await DownloadSettings.instance.setDirectory(picked);
      if (mounted) setState(() {});
    }
  }

  /// 按当前来源校验前置配置：缺什么提示什么（不再一律提示 Wyzie 密钥）。
  /// 返回 false = 前置条件未满足，调用方直接返回。
  Future<bool> _ensureSourceReady(AppLocalizations l10n) async {
    await _source.ensureLoaded();
    if (_source.kind == SubtitleSourceKind.wyzie) {
      if (WyzieSettings.instance.apiKey.isEmpty) {
        _toast(l10n.subtitleSetWyzieKeyFirst);
        return false;
      }
      return true;
    }
    if (!_source.customConfigured) {
      _toast(l10n.subtitleSetCustomUrlFirst);
      return false;
    }
    return true;
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context);
    final keyword = _keywordCtrl.text.trim();
    if (keyword.isEmpty) return;
    if (!await _ensureSourceReady(l10n)) return;
    if (!DownloadSettings.instance.hasDirectory) {
      _toast(l10n.downloadSetDirFirst);
      await _pickDir();
      if (!DownloadSettings.instance.hasDirectory) return;
    }
    // 每次搜索开一个新会话：旧响应回来时既不能写结果、也不能提前复位转圈
    final session = _searchSession.start();
    final kind = _source.kind;
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
      _selected.clear();
      _searched = false;
      _query = keyword;
      _resultKind = kind;
    });
    try {
      final entries = await _searchBySource(kind, keyword);
      if (!mounted || !_searchSession.isCurrent(session)) return;
      setState(() {
        _results = entries;
        _searched = true;
      });
    } catch (e) {
      if (!mounted || !_searchSession.isCurrent(session)) return;
      setState(() => _error = _errText(l10n, e));
    } finally {
      // 旧会话回来时不能把转圈提前关掉（新搜索还在跑）
      if (mounted && _searchSession.isCurrent(session)) {
        setState(() => _busy = false);
      }
    }
  }

  /// 按来源发起搜索并统一成 [SubtitleEntry] 列表
  Future<List<SubtitleEntry>> _searchBySource(
    SubtitleSourceKind kind,
    String keyword,
  ) async {
    if (kind == SubtitleSourceKind.custom) {
      return _customApi.search(
        urlTemplate: _source.customUrlTemplate,
        query: keyword,
      );
    }
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
    return filtered.map(SubtitleEntry.fromWyzie).toList();
  }

  Future<void> _download() async {
    if (_selected.isEmpty || _downloading) return;
    final l10n = AppLocalizations.of(context);
    if (!DownloadSettings.instance.directoryExists) {
      _toast(l10n.downloadDirGone);
      await _pickDir();
      if (!DownloadSettings.instance.directoryExists) return;
    }
    final dir = DownloadSettings.instance.directory;
    // **先快照选中项**：下载期间用户可能改关键词重新搜索（`_results` 被整表替换），
    // 边下边按下标取会越界抛 RangeError，并把 `_downloading` 永久卡在 true（P2-36）
    final indices = _selected.toList()..sort();
    final picked = <SubtitleEntry>[
      for (final i in indices)
        if (i >= 0 && i < _results.length) _results[i],
    ];
    if (picked.isEmpty) return;
    setState(() => _downloading = true);
    final used = <String>{};
    var ok = 0;
    var fail = 0;
    try {
      for (final sub in picked) {
        try {
          final bytes = await _fetchBytes(sub.url);
          final base = subtitleEntryFileName(sub, fallbackTitle: _query);
          final name = uniqueFileName(base, used);
          used.add(name);
          await _writeBytes('$dir/$name', bytes);
          ok++;
        } catch (_) {
          fail++;
        }
      }
    } finally {
      // 无论中途发生什么（含被替换的结果列表/写盘异常）都要复位，
      // 否则「下载字幕」按钮永久不可点
      if (mounted) setState(() => _downloading = false);
    }
    if (!mounted) return;
    _toast(fail == 0
        ? l10n.subtitleDownloadedCount(ok)
        : l10n.subtitleDownloadResult(ok, fail));
  }

  /// 下载字节：按**搜出这批结果的来源**选客户端（不按当前选择——
  /// 用户可能搜完就切了来源，那批 url 仍属于原来源）
  Future<List<int>> _fetchBytes(String url) {
    if (_resultKind == SubtitleSourceKind.custom) {
      return _customApi.fetchBytes(url);
    }
    return _api.fetchBytes(url);
  }

  void _resetSearch() {
    // 作废在途搜索：用户已回到「重新搜索」态，旧响应不该再把结果写回来
    _searchSession.invalidate();
    setState(() {
      _busy = false;
      _results = const [];
      _selected.clear();
      _error = null;
      _searched = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasResults = _results.isNotEmpty;
    // 监听来源设置：设置页里换了来源，返回本页时摘要/校验口径立刻跟着变
    return ListenableBuilder(
      listenable: _source,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.biliSubtitleDownloadTitle)),
        body: Column(
          children: [
            _buildInput(),
            Expanded(child: _buildBody()),
            if (hasResults) _downloadBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: l10n.subtitleSearchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            // 搜索中**按钮仍在位可点**：连按两次回车/点两次都要照常发起新搜索，
            // 由会话号决定谁的结果算数（静默吞掉才是「功能坏了」，P2-35/§4.11）
            onPressed: _search,
            child: _busy
                // ⚠️ 转圈必须显式给色：默认取的是主题 primary，而本按钮**仍在位可点**
                // （底色就是 primary）→ 圈与底色同色，看上去像「圈消失了」（真机反馈）。
                // 用 onPrimary（按钮自己的前景色）：当前主题下即白色，深色主题下
                // 会自动换成对应的高对比色（写死白色在深浅两套主题里总有一套看不见）。
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
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
            TextButton(onPressed: _resetSearch, child: Text(l10n.subtitleBackToSettings)),
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
                  l10n.subtitleNoResultHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(onPressed: _resetSearch, child: Text(l10n.subtitleBackToSettings)),
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
              title: l10n.subtitleDownloadSettings,
              subtitle: Text(
                '${l10n.commonLabelWithColon(l10n.subtitleCurrentSource)}'
                '${subtitleSourceKindLabel(l10n, _source.kind)}',
              ),
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
              l10n.subtitleSearchHintShort,
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dir = DownloadSettings.instance.directory;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(
        dir.isEmpty ? l10n.downloadNoDir : DownloadSettings.instance.directoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      trailing: TextButton(onPressed: _pickDir, child: Text(l10n.downloadSetDir)),
    );
  }

  Widget _headerBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.subtitleResultHeader(_query, _results.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: _resetSearch, child: Text(l10n.subtitleSearchAgain)),
        ],
      ),
    );
  }

  Widget _selectAllBar() {
    final l10n = AppLocalizations.of(context);
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
          Text(l10n.commonSelectAll),
          const Spacer(),
          Text(l10n.subtitleSelectedOfTotal(_selected.length, _results.length)),
        ],
      ),
    );
  }

  Widget _resultsList() {
    final l10n = AppLocalizations.of(context);
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
            subtitleEntryDisplayName(l10n, sub),
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
                _metaChip(subtitleEntryDisplayLanguage(l10n, sub)),
                _metaChip(sub.source.isNotEmpty
                    ? subtitleEntrySourceLabel(l10n, sub)
                    : l10n.subtitleUnknownSource),
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
    final l10n = AppLocalizations.of(context);
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
            label: Text(_downloading
                ? l10n.subtitleDownloadingNow
                : l10n.subtitleDownloadButton(_selected.length)),
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

  /// 默认写盘实现（字幕文件很小，一次性写）。
  static Future<void> _writeFileBytes(String path, List<int> bytes) =>
      File(path).writeAsBytes(bytes, flush: true);

  /// 异常 → 展示文案（两条来源链路共用，按错误码取文，不再剥类名前缀）
  String _errText(AppLocalizations l10n, Object e) => switch (e) {
        WyzieApiException error => wyzieErrorText(l10n, error),
        CustomSubtitleApiException error => customSubtitleErrorText(l10n, error),
        _ => '$e',
      };
}
