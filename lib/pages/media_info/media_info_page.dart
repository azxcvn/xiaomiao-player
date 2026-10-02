import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/video_info_service.dart';

/// 媒体信息页：点击视频卡片最右侧的「i」图标进入，
/// 用 MediaInfoLib 解析并展示 通用信息 / 视频流 / 音频流 / 字幕流。
class MediaInfoPage extends StatefulWidget {
  final String path;
  final String title;

  const MediaInfoPage({
    super.key,
    required this.path,
    required this.title,
  });

  @override
  State<MediaInfoPage> createState() => _MediaInfoPageState();
}

class _MediaInfoPageState extends State<MediaInfoPage> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await VideoInfoService.getMediaInfo(widget.path);
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    final info = _info;
    if (info == null) return;
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _formatText(l10n, info)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.mediaInfoCopied),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatText(AppLocalizations l10n, Map<String, dynamic> info) {
    final buf = StringBuffer()
      ..writeln(l10n.mediaInfoTitleWithName(widget.title))
      ..writeln('=' * 40);
    final general = info['general'] as Map?;
    if (general != null && general.isNotEmpty) {
      buf.writeln(l10n.mediaInfoGeneralHeader);
      general.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) buf.writeln('$k: $v');
      });
      buf.writeln();
    }
    _formatStreams(buf, l10n.mediaInfoVideoStreams, info['videoStreams']);
    _formatStreams(buf, l10n.mediaInfoAudioStreams, info['audioStreams']);
    _formatStreams(buf, l10n.mediaInfoSubtitleStreams, info['textStreams']);
    return buf.toString();
  }

  void _formatStreams(StringBuffer buf, String title, dynamic list) {
    if (list is! List || list.isEmpty) return;
    buf.writeln('【$title】');
    for (final item in list) {
      final m = Map<String, dynamic>.from(item as Map);
      buf.writeln('- ${m.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) => '${e.key}: ${e.value}').join(' | ')}');
    }
    buf.writeln();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_info != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.commonCopy,
              onPressed: _copy,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _info == null
              ? Center(child: Text(l10n.mediaInfoFetchFailed))
              : _buildInfo(l10n, scheme),
    );
  }

  Widget _buildInfo(AppLocalizations l10n, ColorScheme scheme) {
    final info = _info!;
    final general = info['general'] as Map? ?? const {};
    final videoStreams = info['videoStreams'] as List? ?? const [];
    final audioStreams = info['audioStreams'] as List? ?? const [];
    final textStreams = info['textStreams'] as List? ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        if (general.isNotEmpty) ...[
          _sectionTitle(scheme, l10n.mediaInfoGeneral),
          _infoCard(
            scheme,
            [
              if (_nonEmpty(general['format'])) (l10n.mediaInfoFormat, general['format']! as String),
              if (_nonEmpty(general['formatVersion'])) (l10n.mediaInfoFormatVersion, general['formatVersion']! as String),
              if (_nonEmpty(general['fileSize'])) (l10n.mediaInfoFileSize, general['fileSize']! as String),
              if (_nonEmpty(general['duration'])) (l10n.commonDuration, general['duration']! as String),
              if (_nonEmpty(general['overallBitRate'])) (l10n.mediaInfoOverallBitrate, general['overallBitRate']! as String),
              if (_nonEmpty(general['frameRate'])) (l10n.commonFrameRate, general['frameRate']! as String),
              if (_nonEmpty(general['title'])) (l10n.commonTitle, general['title']! as String),
              if (_nonEmpty(general['encodedDate'])) (l10n.mediaInfoEncodedDate, general['encodedDate']! as String),
              if (_nonEmpty(general['writingApplication'])) (l10n.mediaInfoWritingApp, general['writingApplication']! as String),
              if (_nonEmpty(general['writingLibrary'])) (l10n.mediaInfoWritingLibrary, general['writingLibrary']! as String),
            ],
          ),
        ],
        if (videoStreams.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle(scheme, l10n.mediaInfoVideoStreams),
          for (var i = 0; i < videoStreams.length; i++)
            _infoCard(scheme, _streamRows(l10n, videoStreams[i] as Map, l10n.mediaInfoVideoStreamNo(i + 1))),
        ],
        if (audioStreams.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle(scheme, l10n.mediaInfoAudioStreams),
          for (var i = 0; i < audioStreams.length; i++)
            _infoCard(scheme, _streamRows(l10n, audioStreams[i] as Map, l10n.mediaInfoAudioStreamNo(i + 1))),
        ],
        if (textStreams.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle(scheme, l10n.mediaInfoSubtitleStreams),
          for (var i = 0; i < textStreams.length; i++)
            _infoCard(scheme, _streamRows(l10n, textStreams[i] as Map, l10n.mediaInfoSubtitleStreamNo(i + 1))),
        ],
        if (general.isEmpty &&
            videoStreams.isEmpty &&
            audioStreams.isEmpty &&
            textStreams.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(child: Text(l10n.mediaInfoNoInfo)),
          ),
      ],
    );
  }

  List<(String, String)> _streamRows(AppLocalizations l10n, Map stream, String title) {
    final labelMap = {
      'id': 'ID',
      'format': l10n.mediaInfoCodec,
      'formatProfile': l10n.mediaInfoProfile,
      'codecId': l10n.mediaInfoCodecId,
      'width': l10n.mediaInfoWidth,
      'height': l10n.mediaInfoHeight,
      'displayAspectRatio': l10n.mediaInfoAspectRatio,
      'frameRate': l10n.commonFrameRate,
      'frameRateMode': l10n.mediaInfoFrameRateMode,
      'bitRate': l10n.mediaInfoBitrate,
      'bitDepth': l10n.mediaInfoBitDepth,
      'colorSpace': l10n.mediaInfoColorSpace,
      'chromaSubsampling': l10n.mediaInfoChromaSubsampling,
      'hdrFormat': l10n.mediaInfoHdrFormat,
      'channels': l10n.mediaInfoChannels,
      'samplingRate': l10n.settingsDecoderSampleRates,
      'language': l10n.settingsGroupLanguage,
      'title': l10n.commonTitle,
      'duration': l10n.commonDuration,
      'streamSize': l10n.mediaInfoStreamSize,
    };
    final rows = <(String, String)>[
      for (final e in stream.entries)
        if (_nonEmpty(e.value))
          (labelMap[e.key] ?? e.key, e.value.toString()),
    ];
    // 标题行信息不足时至少保留流序号
    if (rows.isEmpty) rows.add((l10n.mediaInfoStream, title));
    return rows;
  }

  bool _nonEmpty(dynamic v) => v != null && v.toString().isNotEmpty;

  Widget _sectionTitle(ColorScheme scheme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _infoCard(ColorScheme scheme, List<(String, String)> rows) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        row.$1,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
