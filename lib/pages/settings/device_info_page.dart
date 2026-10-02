import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/device_decoder.dart';
import 'package:moumou/pages/settings/decoder_detail_page.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 设备硬件与编解码能力检测页（工作.md 迁移功能）。
///
/// 展示三层信息（对齐参考项目 mpvRx 的 `CodecCapabilitiesScreen`、
/// 老项目 `DeviceInfoScreen`）：
/// 1. **屏幕 HDR 能力**：HDR10 / HDR10+ / HLG / 杜比视界；
/// 2. **关键视频编码器**：H.264/H.265/AV1/VP9/杜比视界的硬解/软解支持；
/// 3. **系统解码器清单**：全部硬解/软解解码器（筛选胶囊两行布局——
///   第一行 音频/硬解/软解/视频 等宽均分，第二行「全部」独占整行对齐）。
///
/// 数据一次从原生读取（[DeviceServices.getDeviceCapabilities]），
/// 页面内做筛选/搜索，无二次跨进程调用。
class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  bool _loading = true;

  /// 原生通道读失败（**只存状态，不存文案**）：错误文案在 build 里用 l10n 取。
  ///
  /// 不能在 [_load] 里取 `AppLocalizations.of(context)`——[_load] 是从
  /// `initState` 调的，而 initState 期间查 InheritedWidget 是非法的（会断言失败、
  /// 页面永远停在 loading，测试里表现为 `pumpAndSettle` 超时）。
  bool _failed = false;

  String _manufacturer = '';
  String _model = '';
  String _release = '';
  int _sdkInt = 0;
  List<String> _hdrTypes = const [];

  final List<_KeyCodec> _keyCodecs = [];
  final List<DeviceDecoderEntry> _decoders = [];

  _DecoderFilter _filter = _DecoderFilter.all;
  String _query = '';

  // ── 筛选结果缓存（P2-38）──────────────────────────────────────────
  // 原来 `_filtered` 每次调用都 `where().toList()` 全量过一遍，而它一帧内会被调用
  // 两次（清单 + 空态判断），搜索框每击键又整页 rebuild → O(n) × 每击键。
  // 这里按「查询词 + 筛选档」缓存：输入没变直接复用（解码器清单几百条）。
  List<DeviceDecoderEntry>? _filteredCache;
  String? _filteredCacheQuery;
  _DecoderFilter? _filteredCacheFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final caps = await DeviceServices.getDeviceCapabilities();
    if (!mounted) return;
    if (caps == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = false;
      final device = caps['device'];
      if (device is Map) {
        _manufacturer = (device['manufacturer'] as String?) ?? '';
        _model = (device['model'] as String?) ?? '';
        _release = (device['release'] as String?) ?? '';
        _sdkInt = int.tryParse((device['sdkInt'] as String?) ?? '') ?? 0;
      }
      final hdr = caps['hdrCapabilities'];
      _hdrTypes = (hdr is List)
          ? [
              for (final h in hdr)
                if (h is String) h,
            ]
          : const [];

      _keyCodecs.clear();
      final key = caps['keyCodecs'];
      if (key is List) {
        for (final k in key) {
          if (k is Map) _keyCodecs.add(_KeyCodec.fromMap(k));
        }
      }

      _decoders.clear();
      final decoders = caps['decoders'];
      if (decoders is List) {
        for (final d in decoders) {
          if (d is Map) _decoders.add(DeviceDecoderEntry.fromMap(d));
        }
      }
      // 数据源变了：作废筛选缓存（键只覆盖 query/filter，覆盖不到 _decoders 内容）
      _filteredCache = null;
    });
  }

  List<DeviceDecoderEntry> get _filtered {
    // P2-38：缓存命中直接复用（同一查询词一帧内会被问两次；击键重建也不重复全量过滤）
    final cached = _filteredCache;
    if (cached != null &&
        _filteredCacheQuery == _query &&
        _filteredCacheFilter == _filter) {
      return cached;
    }
    final q = _query.trim().toLowerCase();
    final result = _decoders.where((d) {
      final matchFilter = switch (_filter) {
        _DecoderFilter.all => true,
        _DecoderFilter.hardware => d.isHardware,
        _DecoderFilter.software => !d.isHardware,
        _DecoderFilter.video => d.mediaType == 'video',
        _DecoderFilter.audio => d.mediaType == 'audio',
      };
      if (!matchFilter) return false;
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.mimeType.toLowerCase().contains(q) ||
          d.formatName.toLowerCase().contains(q) ||
          d.profiles.any((p) => p.toLowerCase().contains(q));
    }).toList();
    _filteredCache = result;
    _filteredCacheQuery = _query;
    _filteredCacheFilter = _filter;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsDeviceInfo)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? _errorView(scheme)
          // CustomScrollView：卡片区 + 解码器清单表头是固定几块，清单本体走
          // SliverList 懒构建（P2-38）
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverList.list(
                    children: [
                      _deviceCard(scheme),
                      const SizedBox(height: 16),
                      _hdrCard(scheme),
                      const SizedBox(height: 16),
                      _keyCodecCard(scheme),
                      const SizedBox(height: 16),
                      _decoderListBody(scheme),
                    ],
                  ),
                ),
                // 清单本体：懒构建（只 build 可见项），左右内边距沿用页面 12
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  sliver: _decoderListSliver(scheme),
                ),
              ],
            ),
    );
  }

  Widget _errorView(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).settingsDeviceCapabilityError,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _load,
            child: Text(AppLocalizations.of(context).commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(ColorScheme scheme) {
    final deviceName =
        '${_manufacturer.isNotEmpty ? '$_manufacturer ' : ''}$_model';
    return SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deviceName.trim().isEmpty
                  ? AppLocalizations.of(context).settingsDeviceUnknown
                  : deviceName.trim(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Android $_release · API $_sdkInt',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hdrCard(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: AppLocalizations.of(context).settingsDeviceHdrCapability,
        ),
        SettingsCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _hdrTypes.isEmpty
                ? Text(
                    AppLocalizations.of(context).settingsDeviceHdrUnsupported,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final h in _hdrTypes) _tagChip(scheme, h, hl: true),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _keyCodecCard(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(
          title: AppLocalizations.of(context).settingsDeviceKeyVideoEncoders,
        ),
        SettingsCard(
          child: Column(
            children: [
              for (var i = 0; i < _keyCodecs.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                _keyCodecTile(scheme, _keyCodecs[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _keyCodecTile(ColorScheme scheme, _KeyCodec k) {
    final l10n = AppLocalizations.of(context);
    final String label;
    final Color color;
    if (k.hasHardware) {
      label = l10n.decodeModeHwCopy;
      color = scheme.primary;
    } else if (k.hasSoftware) {
      label = l10n.decodeModeSw;
      color = scheme.tertiary;
    } else {
      label = l10n.settingsDeviceUnsupported;
      color = scheme.error;
    }
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.videocam_outlined, size: 22, color: color),
      ),
      title: Text(
        k.formatName,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        k.decoderName?.isNotEmpty == true
            ? '${k.decoderName} · ${k.maxResolution ?? '—'}'
            : (k.maxResolution ?? '—'),
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (k.isHdrSupported)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'HDR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: k.hasHardware
                    ? scheme.onPrimary
                    : k.hasSoftware
                    ? scheme.onTertiary
                    : scheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 解码器清单**表头**（标题徽标 + 搜索框 + 筛选胶囊）：固定几行，随页面
  /// `SliverList.list` 的常规 children 一起构建（P2-38）。
  Widget _decoderListBody(ColorScheme scheme) {
    final hwCount = _decoders.where((d) => d.isHardware).length;
    final swCount = _decoders.length - hwCount;
    final videoCount = _decoders.where((d) => d.mediaType == 'video').length;
    final audioCount = _decoders.where((d) => d.mediaType == 'audio').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SettingsGroupTitle(
              title: AppLocalizations.of(context).settingsDeviceDecoderList,
            ),
            Text(
              AppLocalizations.of(context).settingsDeviceDecoderSummary(
                hwCount,
                swCount,
                videoCount,
                audioCount,
              ),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        SettingsCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 搜索
                TextField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    ).settingsDeviceSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                // 筛选胶囊（两行布局：第一行 音频/硬解/软解/视频 等宽均分，
                // 第二行「全部」独占整行，宽度与第一行四个胶囊总长对齐）
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _filterChip(
                            scheme,
                            _DecoderFilter.audio,
                            AppLocalizations.of(context).playerActionAudio,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterChip(
                            scheme,
                            _DecoderFilter.hardware,
                            AppLocalizations.of(context).decodeModeHwCopy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterChip(
                            scheme,
                            _DecoderFilter.software,
                            AppLocalizations.of(context).decodeModeSw,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _filterChip(
                            scheme,
                            _DecoderFilter.video,
                            AppLocalizations.of(context).commonVideo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _filterChip(
                        scheme,
                        _DecoderFilter.all,
                        AppLocalizations.of(context).commonAll,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 解码器清单**本体**（懒构建 sliver，P2-38）：空态用 `SliverToBoxAdapter`，
  /// 有数据走 [SliverList.builder]——只构建可见项，不再一次性 `for` 全量构建
  /// （解码器清单几百条，原来是整页每击键都重建全部 tile）。
  Widget _decoderListSliver(ColorScheme scheme) {
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              AppLocalizations.of(context).settingsDeviceNoMatchingDecoder,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) => _decoderTile(scheme, filtered[i]),
    );
  }

  Widget _decoderTile(ColorScheme scheme, DeviceDecoderEntry d) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDecoderDetail(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: (d.isHardware ? scheme.primary : scheme.tertiary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                d.mediaType == 'video'
                    ? Icons.videocam_outlined
                    : Icons.audiotrack_outlined,
                size: 16,
                color: d.isHardware ? scheme.primary : scheme.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.formatName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (d.isHardware
                              ? scheme.primaryContainer
                              : scheme.tertiaryContainer),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.isHardware ? 'HW' : 'SW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: d.isHardware
                                ? scheme.onPrimaryContainer
                                : scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    d.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (d.maxResolution.isNotEmpty ||
                      d.maxChannels > 0 ||
                      d.profiles.isNotEmpty)
                    Text(
                      [
                        if (d.maxResolution.isNotEmpty) d.maxResolution,
                        if (d.maxChannels > 0)
                          AppLocalizations.of(
                            context,
                          ).settingsDeviceChannels(d.maxChannels),
                        if (d.profiles.isNotEmpty) d.profiles.join(' / '),
                        if (d.isHdrSupported) 'HDR',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _openDecoderDetail(DeviceDecoderEntry d) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DecoderDetailPage(decoder: d)));
  }

  Widget _filterChip(ColorScheme scheme, _DecoderFilter f, String label) {
    final selected = _filter == f;
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center, softWrap: false),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = f),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? scheme.primaryContainer
            : scheme.outlineVariant.withValues(alpha: 0.4),
      ),
      shape: const StadiumBorder(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _tagChip(ColorScheme scheme, String text, {bool hl = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hl ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: hl ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _DecoderFilter { all, hardware, software, video, audio }

class _KeyCodec {
  final String formatName;
  final String mimeType;
  final bool hasHardware;
  final bool hasSoftware;
  final String? decoderName;
  final String? maxResolution;
  final bool isHdrSupported;

  _KeyCodec({
    required this.formatName,
    required this.mimeType,
    required this.hasHardware,
    required this.hasSoftware,
    this.decoderName,
    this.maxResolution,
    this.isHdrSupported = false,
  });

  factory _KeyCodec.fromMap(Map<dynamic, dynamic> m) => _KeyCodec(
    formatName: (m['formatName'] as String?) ?? '',
    mimeType: (m['mimeType'] as String?) ?? '',
    hasHardware: (m['hasHardware'] as bool?) ?? false,
    hasSoftware: (m['hasSoftware'] as bool?) ?? false,
    decoderName: m['decoderName'] as String?,
    maxResolution: m['maxResolution'] as String?,
    isHdrSupported: (m['isHdrSupported'] as bool?) ?? false,
  );
}
