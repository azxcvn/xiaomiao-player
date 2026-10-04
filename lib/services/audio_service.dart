import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;
import 'package:moumou/models/audio_track.dart';
import 'package:moumou/services/audio_settings.dart';
import 'package:moumou/services/equalizer_settings.dart';

/// 判断一条 mpv 日志是否代表「当前选中的音轨放不出来」。
///
/// 背景（真机 bug）：MKV 内含 Dolby TrueHD（MLP FBA / A_TRUEHD / 8 channels）
/// 与 AC-3（6 channels）两条音轨，mpv 在 Android 上固定走 `ao=opensles`
/// （只支持双声道），切到 TrueHD 那条后**完全没有声音**：解码链/音频输出在
/// 初始化阶段就失败，而 FFmpeg 的 TrueHD 解码器不接受强制双声道下混。
/// mpv 只在日志里报错，应用侧此前**完全没有消费** `Player.stream.log`
/// （`logLevel` 默认 `error`），于是用户表现为「点了没反应、静默无声」。
///
/// 本函数把「要不要回退音轨」的判定抽成纯函数（可单测）：
/// - 只认音频相关日志前缀（`ad` 解码器 / `ao` 音频输出 / `cplayer` 播放核心 /
///   `ffmpeg`），避免视频/网络错误误触发；
/// - 消息里必须出现音频或音频输出的失败特征词。
bool isAudioPlaybackFailureLog(String prefix, String text) {
  final p = prefix.trim().toLowerCase();
  final t = text.toLowerCase();
  if (t.isEmpty) return false;
  // af 滤镜链失败**不是**「这条音轨放不出来」：那是内核缺滤镜，换轨救不了。
  // 不加这条的话，「Audio filter initialized failed.」会被判成音轨失败 →
  // 白白把用户选的音轨切走（音频链挂掉时 audio-params 也是 no，复核同样通过）。
  if (isAudioFilterFailureLog(prefix, text)) return false;
  if (!const {'ad', 'ao', 'cplayer', 'ffmpeg'}.contains(p)) return false;
  final mentionsAudio = t.contains('audio') ||
      t.contains('decoder') ||
      t.contains('truehd') ||
      t.contains('mlp') ||
      t.contains('channel layout') ||
      t.contains('channel map') ||
      t.contains('downmix');
  if (!mentionsAudio) return false;
  const failureMarkers = [
    'could not open',
    'failed to',
    'cannot open',
    'can not open',
    "can't open",
    'unable to',
    'not supported',
    'unsupported',
    'no audio',
    'error',
    'failed',
    'invalid',
    'rejected',
  ];
  return failureMarkers.any(t.contains);
}

/// 是否是「af 音频滤镜链建不起来」的 mpv 日志（纯函数，可单测）。
///
/// 背景（用户实测 `T3-PLR-035` / `T3-PLR-036` + issue #8）：本工程打包的 libmpv
/// 内核里 ffmpeg **只编进了 `equalizer` 一个音频滤镜**（对 `libmpv.so` 做符号扫描：
/// 只有 `ff_af_equalizer`，`dynaudnorm` / `acompressor` / `lowshelf` /
/// `extrastereo` / `pan` 这些名字根本不存在）。于是：
///
/// 1. **滤镜名不被支持**（直接写名字的 `dynaudnorm` / `pan`）：
///    `Option af: item 'dynaudnorm' isn't supported.` —— 属性整条没写进去；
/// 2. **滤镜图建不起来**（写在 `lavfi=[…]` 里的那些）：`Audio filter initialized failed.`
///    —— 属性写进去了，但 mpv 音频链初始化失败。
///
/// 第 2 种会让**整段音频没声音**，而且这些开关是持久化的 → 之后每个视频都没声音
/// （issue #8 的复现过程）。所以必须在 [AudioController] 里接住：
/// 见 `_handleAudioFilterFailureLog`。
bool isAudioFilterFailureLog(String prefix, String text) {
  final t = text.toLowerCase();
  if (t.isEmpty) return false;
  if (t.contains('audio filter initialized failed')) return true;
  // media_kit 把「属性写入失败」也塞进日志：`error: … _setProperty(af, 4)`
  if (prefix.trim().toLowerCase() == 'media_kit' &&
      t.contains('_setproperty(af')) {
    return true;
  }
  return _unsupportedAfItemPattern.hasMatch(t);
}

/// mpv 的 `Option af: item 'xxx' isn't supported.`（`m_option.c`）
final RegExp _unsupportedAfItemPattern =
    RegExp(r"option\s+\S*af\S*\s*:\s*item\s+'", caseSensitive: false);

/// 从「滤镜名不被支持」的日志里取出那个滤镜名（取不到返回 null）。
///
/// 日志里的 item 可能是 `dynaudnorm`、`pan=[stereo|c0=c1|c1=c0]`、
/// `@bass:lavfi=[lowshelf=…]` —— 统一归一成滤镜名（`dynaudnorm` / `pan` / `lowshelf`）。
String? unsupportedAudioFilterFromLog(String text) {
  final m = RegExp(r"item\s+'([^']*)'", caseSensitive: false).firstMatch(text);
  if (m == null) return null;
  var name = m.group(1)!.trim();
  if (name.isEmpty) return null;
  // 命名滤镜的标签（`@bass:`）只可能在最前面
  if (name.startsWith('@')) {
    final colon = name.indexOf(':');
    if (colon >= 0) name = name.substring(colon + 1);
  }
  // 去掉 `lavfi=[…]` 外壳，再取第一个 `=` 之前的滤镜名
  name = name.replaceFirst(RegExp(r'^lavfi=\['), '');
  final eq = name.indexOf('=');
  if (eq >= 0) name = name.substring(0, eq);
  name = name.replaceAll(RegExp(r'[\[\]]'), '').trim();
  return name.isEmpty ? null : name;
}

/// 为一个「确认放不出来」的音轨挑回退目标。
///
/// 优先级：**不同编码格式**的其它轨道（TrueHD 放不出来时 AC-3 通常没问题）
/// → 其它任意轨道（外部音轨排在最后，它本就是临时导入的）。
/// 候选列表为空或只有当前这条时返回 null（表示无处可退，由调用方提示用户）。
AudioTrack? pickFallbackAudioTrack({
  required List<AudioTrack> tracks,
  required AudioTrack? failed,
  AudioTrack? current,
}) {
  final skipIds = <String>{
    if (failed != null) failed.id,
    if (current != null) current.id,
  };
  final candidates = tracks.where((t) => !skipIds.contains(t.id)).toList();
  if (candidates.isEmpty) return null;
  final failedCodec = failed?.codec?.trim().toLowerCase();
  final differentCodec = candidates.where((t) {
    final c = t.codec?.trim().toLowerCase();
    // 编码未知（null/空）时不参与「不同格式」优先，避免误判
    return c != null && c.isNotEmpty && c != failedCodec;
  }).toList();
  final pool = differentCodec.isNotEmpty ? differentCodec : candidates;
  final embedded = pool.where((t) => !t.external).toList();
  return (embedded.isNotEmpty ? embedded : pool).first;
}

/// 移除外部音轨后要落回的轨道（纯函数，可单测）。
///
/// 背景（用户实测 `T3-PLR-032`）：`audio-remove` 掉**当前正在播**的外部音轨后，
/// mpv 会把 `aid` 置成 `no`（什么都不选）→ 界面上一条音轨都没选中、声音没了；
/// 而用户语义是「移除外部音轨 = 回到原来的内嵌音轨」。
///
/// 选择顺序：
/// 1. 导入外部音轨**之前**选中的那条内嵌轨（若它还在列表里）；
/// 2. 否则第一条内嵌轨（`aidBeforeImport` 为 `auto`/未知时同此）；
/// 3. 没有可用的内嵌轨、或导入前本来就是「关闭」→ null（保持关闭）。
AudioTrack? pickTrackAfterExternalRemoval({
  required List<AudioTrack> tracks,
  required String removedId,
  String? aidBeforeImport,
}) {
  // 导入前就是「关闭」：尊重用户当时的选择，移除后仍保持关闭
  if (aidBeforeImport == 'no') return null;
  final embedded = tracks
      .where((t) => t.id != removedId && !t.external)
      .toList(growable: false);
  if (embedded.isEmpty) return null;
  if (aidBeforeImport != null && aidBeforeImport != 'auto') {
    for (final t in embedded) {
      if (t.id == aidBeforeImport) return t;
    }
  }
  return embedded.first;
}

/// 音轨自动回退的原因码（**纯数据，不含文案**）。
///
/// 文案在 UI 层：`l10n/label_maps.dart` 的 [audioFallbackReasonText]。
enum AudioFallbackReason {
  /// 当前音轨放不出来，且没有其它可切换的音轨
  noAlternative,

  /// 当前音轨放不出来，已自动切到另一条音轨
  switched,
}

/// 音频控制器：绑定单个播放器（横竖屏共享同一实例），
/// 维护「音频轨道列表 / 当前音轨 / 外部音轨 / 声道 / 音频处理」状态并直接驱动 mpv。
///
/// - **单选模型**（只允许同时启用一条音轨，参考 mpv `aid`）；
/// - 外部音轨**临时**（工作.md 音频功能：退出播放后不保留）——只存内存，
///   切集 mpv 自动卸载外部音轨，[clear] 清空内存状态，不做任何持久化；
/// - **声道 / 音频处理跨会话持久化**（用户反馈「选好再进就回到默认」）——
///   唯一真值在全局单例 [AudioSettings]（shared_preferences，同
///   [EqualizerSettings] 模式），控制器只负责订阅 + 下发 mpv，不再自己存字段；
/// - **不可播放音轨自动回退**：用户**显式换轨后的 4 秒窗口内**订阅 `Player.stream.log`，
///   命中 [isAudioPlaybackFailureLog] 时先读 `audio-params` 复核（真失败 = 无有效
///   输出格式），再切到 [pickFallbackAudioTrack] 选出的另一条音轨并回调
///   [onAudioFallback]，避免「选了这条就永久无声」；窗口限制是为了避免播放中途的
///   瞬时音频日志（underrun / 重连）误触发换轨；
/// - mpv 属性与命令（参考 mpvRx 的 PlaybackSession / TrackSelector）：
///   - 轨道列表：`track-list/count` + `track-list/$i/{type,id,title,lang,codec,demux-channels,external,external-filename,selected}`；
///   - 当前音轨：`aid`（id 或 'no'；打开文件后 mpv 自动选一条轨道，
///     [reload] 把 [primary] 同步成 mpv 实际生效的 aid）；
///   - 外部音轨：`audio-add <path> select`（立即选中）、`audio-remove <id>` 移除；
///   - 音频声道：`audio-channels`（反向立体声用 `af` 滤镜交换左右声道）；
///   - 音频处理：`af` 滤镜链（音量标准化 `dynaudnorm` / 动态范围压缩
///     `lavfi=[acompressor=...]`，见 [buildAudioFilterChain]）。
///     **只写内核建得起来的滤镜**：内核缺滤镜时跳过该滤镜、整条建不起来时停用
///     af 并提示用户——绝不留下「音效开着、整段没声音」的状态
///     （判定见 [isAudioFilterFailureLog]）。
class AudioController extends ChangeNotifier {
  AudioController(this._player, {this.onAudioFallback}) {
    // 监听 media_kit 轨道流：mpv 解复用完成或轨道变动时自动刷新
    _tracksSubscription = _player.stream.tracks.listen((_) {
      reload();
    });
    // 监听 mpv 日志：音轨/音频输出初始化失败时自动回退（见类注释）
    _logSubscription = _player.stream.log.listen((event) {
      _handleLog(event.prefix, event.text);
    });
    // 监听均衡器设置：用户调均衡器时自动重应用 af 滤镜链（均衡器为
    // 全局持久化状态，控制器随播放器生命周期，故在构造订阅、dispose 反订阅）
    EqualizerSettings.instance.addListener(_onEqualizerChanged);
    // 监听声道 / 音频处理设置：同一套「全局持久化 + 控制器订阅」模式。
    // 首次 [AudioSettings.ensureLoaded] 读盘完成时会通知一次，本次进播放器
    // 即使早于读盘就 open，也能在读到持久化值后立刻重应用
    AudioSettings.instance.addListener(_onAudioSettingsChanged);
    unawaited(AudioSettings.instance.ensureLoaded());
  }

  final Player _player;
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _logSubscription;

  /// 音轨自动回退结果回调（页面层据此提示用户；服务层不依赖 UI，与
  /// [SubtitleController.onAutoLoadedSubtitle] 同一约定）。
  ///
  /// - [fallback] 非空 = 已自动切到该音轨；
  /// - [fallback] 为空 = 确认当前音轨放不出来但**无路可退**（调用方提示失败原因）；
  /// - [failed] 为判定失败的那条音轨（可能为 null）；[reason] 为回退原因码
  ///   （文案在 UI 层，见 `l10n/label_maps.dart` 的 [audioFallbackReasonText]）。
  void Function(
    AudioTrack? fallback,
    AudioTrack? failed,
    AudioFallbackReason reason,
  )? onAudioFallback;

  /// 回退流程防重入（一次失败只回退一次；用户手动换轨后复位）
  bool _fallbackInFlight = false;

  /// 「刚换过轨、等新音轨起声」窗口。
  ///
  /// 只在这个窗口内响应 mpv 音频错误日志：播放中途的瞬时音频日志
  /// （underrun / 缓冲重连 / seek 重新初始化）不该触发换轨，而「切过去这条轨
  /// 根本建不起来」的失败一定发生在换轨后的头几秒。
  bool _awaitingAudioStart = false;
  Timer? _selectionProbeTimer;

  /// 均衡器设置变更 → 重应用 af 滤镜链（含均衡器/低音/虚拟环绕）。
  void _onEqualizerChanged() {
    applyAudioOptions();
  }

  /// 声道 / 音频处理设置变更（用户点选或首次读盘完成）→ 通知面板重绘 +
  /// 重应用 `audio-channels` / `af`。
  void _onAudioSettingsChanged() {
    notifyListeners();
    applyAudioOptions();
  }

  // ── 声道 / 音频处理（跨会话持久化，真值在 [AudioSettings]）────────

  AudioChannels get channels => AudioSettings.instance.channels;
  bool get volumeNormalization => AudioSettings.instance.volumeNormalization;
  bool get drc => AudioSettings.instance.drc;

  /// 当前媒体的全部音轨（空 = 无音轨）
  List<AudioTrack> _tracks = const [];

  /// 当前生效的音轨（null = 关闭；打开文件后与 mpv `aid` 同步）
  AudioTrack? _primary;

  /// 当前视频已导入的外部音轨绝对路径（临时，仅内存，不持久化）
  final List<String> _externalPaths = [];

  /// 导入外部音轨**之前** mpv 的 `aid`（`'no'` = 当时是「关闭」）。
  ///
  /// 只记第一次导入时的值：移除最后一条外部音轨后据此还原选中状态
  /// （见 [pickTrackAfterExternalRemoval]），避免变成「什么也不选」。
  String? _aidBeforeExternalImport;
  bool _hasAidBeforeExternalImport = false;

  /// 内核里不存在、**不能再写进 af 链**的滤镜名（本会话记住）。
  ///
  /// 只用于直接写名字的滤镜（`dynaudnorm` / `pan`）：mpv 会明确报出是哪一个。
  /// `lavfi=[…]` 里的滤镜内核报不出名字，走 [_audioFiltersDisabled] 整条停用。
  /// 内核属性，不随切集清空（见 [clear]）。
  final Set<String> _unsupportedAudioFilters = {};

  /// 整条 af 链都建不起来（例如 lavfi 图初始化失败）时置位：本会话不再写 af。
  /// 宁可不做音效，也不能「一开音效就整段没声音」。
  bool _audioFiltersDisabled = false;

  /// 最近一次**实际写进 mpv** 的 af 链（空串 = 没有滤镜）。
  /// 用它判断「这条 af 失败日志是不是我们这条链引起的」——比时间窗口可靠：
  /// 失败的日志可能和属性写入的回复并发到达。
  String _lastAppliedChain = '';

  /// 本会话已重写 af 链的次数（防止内核报错时无限重试）
  int _afRetryCount = 0;

  /// 音频滤镜不可用（被跳过/整条停用）时回调，页面层据此提示用户。
  /// 服务层不依赖 UI，与 [onAudioFallback] 同一约定。
  void Function()? onAudioFiltersUnavailable;

  /// 已经提示过一次就不再重复（一次会话里同一件事提示一次足够）
  bool _audioFiltersNotified = false;

  /// 轨道读取是否进行中（防并发刷新互相覆盖）
  bool _loading = false;

  /// 最近一次 fetchTracks 检测到被 mpv 选中的轨道 ID
  String? _lastSelectedTrackId;

  List<AudioTrack> get tracks => List.unmodifiable(_tracks);
  AudioTrack? get primary => _primary;
  List<String> get externalPaths => List.unmodifiable(_externalPaths);

  NativePlayer? get _native {
    final platform = _player.platform;
    return platform is NativePlayer ? platform : null;
  }

  /// 设置音频声道并立即应用（写入 [AudioSettings]，跨会话生效）。
  ///
  /// 不做「值相同就跳过」的前置判断：设置单例内部先 await 读盘再比较，
  /// 才是与持久化值一致的口径（本控制器字段只是转发）。
  Future<void> setChannels(AudioChannels v) async {
    // 落盘 + notifyListeners 由设置单例完成，本控制器经
    // [_onAudioSettingsChanged] 重应用 mpv 属性
    await AudioSettings.instance.setChannels(v);
  }

  /// 设置音量标准化开关并立即应用（写入 [AudioSettings]，跨会话生效）。
  Future<void> setVolumeNormalization(bool v) async {
    await AudioSettings.instance.setVolumeNormalization(v);
  }

  /// 设置动态范围压缩开关并立即应用（写入 [AudioSettings]，跨会话生效）。
  Future<void> setDrc(bool v) async {
    await AudioSettings.instance.setDrc(v);
  }

  /// 读取当前媒体的音轨列表（仅 audio 类型；'no' 等伪轨排除）。
  Future<List<AudioTrack>> fetchTracks() async {
    final native = _native;
    if (native == null) return const [];
    final countStr = await native.getProperty('track-list/count');
    final count = int.tryParse(countStr) ?? 0;
    if (count <= 0) return const [];
    final result = <AudioTrack>[];
    String? selectedAudioId;
    for (var i = 0; i < count; i++) {
      final type = await native.getProperty('track-list/$i/type');
      if (type != 'audio') continue;
      final id = await native.getProperty('track-list/$i/id');
      if (id.isEmpty || id == 'no') continue;
      final title = await native.getProperty('track-list/$i/title');
      final lang = await native.getProperty('track-list/$i/lang');
      final codec = await native.getProperty('track-list/$i/codec');
      final channels = await native.getProperty('track-list/$i/demux-channels');
      final external = await native.getProperty('track-list/$i/external');
      final selected = await native.getProperty('track-list/$i/selected');
      final sourcePath =
          await native.getProperty('track-list/$i/external-filename');
      if (selected == 'yes') {
        selectedAudioId = id;
      }
      result.add(
        AudioTrack(
          id: id,
          title: title.isEmpty ? null : title,
          language: lang.isEmpty ? null : lang,
          codec: codec.isEmpty ? null : codec,
          channels: channels.isEmpty ? null : channels,
          external: external == 'yes',
          sourcePath: sourcePath.isEmpty ? null : sourcePath,
        ),
      );
    }
    _lastSelectedTrackId = selectedAudioId;
    return result;
  }

  /// mpv 当前生效的 `aid`（可能为 'no' / 'auto' / 轨道 id）
  Future<String> _readActiveAid() async {
    final native = _native;
    if (native == null) return 'no';
    try {
      final aid = (await native.getProperty('aid')).trim();
      return aid.isEmpty ? 'no' : aid;
    } catch (_) {
      return 'no';
    }
  }

  /// 用 mpv 实际生效的 aid 同步 [primary]（打开/重开后 mpv 自动选的轨道
  /// 也要反映到 UI 选中态）。
  Future<void> _syncActiveFromMpv() async {
    final aid = await _readActiveAid();
    AudioTrack? resolved;
    if (aid != 'no' && aid.isNotEmpty) {
      resolved = _resolveSelection(aid);
    }
    if (resolved == null && aid != 'no' && _lastSelectedTrackId != null) {
      resolved = _resolveSelection(_lastSelectedTrackId);
    }
    _primary = resolved;
    notifyListeners();
  }

  /// 重新加载轨道列表并同步当前选中（以 mpv 实际 aid 为准）。
  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    try {
      List<AudioTrack> tracks;
      try {
        tracks = await fetchTracks();
      } catch (_) {
        tracks = const [];
      }
      _tracks = tracks;
      await _syncActiveFromMpv();
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  /// 按 id 在现轨道中找回选中项（找不到返回 null = 已失效）
  AudioTrack? _resolveSelection(String? id) {
    if (id == null || id == 'no' || id == 'auto') return null;
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 勾选音轨：传 null 关闭。单选模型——同一时刻只允许一条音轨生效。
  Future<void> selectTrack(AudioTrack? track) async {
    final native = _native;
    if (native == null) return;
    // 用户显式换轨：复位回退防重入，并开一个短暂的「等音轨起声」窗口
    // （选「关闭」时不开窗口——那条路径本来就不该有声音）
    _fallbackInFlight = false;
    _openProbeWindow(track != null);
    try {
      await native.setProperty('aid', track?.id ?? 'no');
    } catch (_) {
      return;
    }
    _primary = track;
    notifyListeners();
  }

  /// 开关「等音轨起声」探测窗口（[enabled] 时定时 4 秒后自动关闭）。
  void _openProbeWindow(bool enabled) {
    _selectionProbeTimer?.cancel();
    _selectionProbeTimer = null;
    _awaitingAudioStart = enabled;
    if (enabled) {
      _selectionProbeTimer = Timer(const Duration(seconds: 4), () {
        _awaitingAudioStart = false;
      });
    }
  }

  // ── 不可播放音轨自动回退 ────────────────────────────────

  /// mpv 日志入口：先处理 af 滤镜失败（与音轨无关），再走音轨自动回退。
  void _handleLog(String prefix, String text) {
    // af 滤镜链失败：摘掉出问题的滤镜，或整条停用（否则 mpv 音频链初始化失败 =
    // 整段无声，且设置是持久化的 → 之后每个视频都没声音，issue #8）
    if (_handleAudioFilterFailureLog(prefix, text)) return;
    // 只在「刚换过轨」的窗口内响应：播放中途的瞬时音频日志不触发换轨
    if (!_awaitingAudioStart) return;
    if (!isAudioPlaybackFailureLog(prefix, text)) return;
    if (_fallbackInFlight) return;
    final selectedId = _primary?.id;
    if (selectedId == null || selectedId == 'no') return;
    _fallbackInFlight = true;
    // 给音频链一点初始化/重试时间，再复核是否为「真失败」
    unawaited(Future<void>.delayed(const Duration(milliseconds: 600), () async {
      try {
        if (!await _isSelectedTrackReallyUnplayable(selectedId)) {
          _fallbackInFlight = false; // 误报：只发生在瞬时错误上
          return;
        }
        final failed = _trackById(selectedId);
        final fallback = pickFallbackAudioTrack(
          tracks: _tracks,
          failed: failed,
          current: _primary,
        );
        if (fallback == null) {
          // 无路可退：让用户能看到失败原因，而不是静默无声
          onAudioFallback?.call(
            null,
            failed ?? _primary,
            AudioFallbackReason.noAlternative,
          );
          return;
        }
        await selectTrack(fallback);
        onAudioFallback?.call(
          fallback,
          failed,
          AudioFallbackReason.switched,
        );
      } finally {
        _fallbackInFlight = false;
      }
    }));
  }

  /// af 滤镜链失败的兜底处理（返回 true = 这条日志已被消费）。
  ///
  /// - 能认出是哪个滤镜（`dynaudnorm` / `pan` 这类直接写名字的）→ 记下来，
  ///   立刻用「去掉它的链」重写一次 af，其余音效继续可用；
  /// - 认不出（`lavfi=[…]` 的图建不起来）→ 整个会话停用 af，先把声音救回来，
  ///   并回调页面提示用户（内核不支持这些音效）。
  bool _handleAudioFilterFailureLog(String prefix, String text) {
    if (!isAudioFilterFailureLog(prefix, text)) return false;
    // 当前根本没有 af 链（已停用 / 用户没开任何音效）→ 与本控制器无关
    if (_audioFiltersDisabled || _lastAppliedChain.isEmpty) return true;
    final name = unsupportedAudioFilterFromLog(text);
    if (name != null &&
        _afRetryCount < 6 &&
        !_unsupportedAudioFilters.contains(name)) {
      _unsupportedAudioFilters.add(name);
      _afRetryCount++;
      _notifyAudioFiltersUnavailable();
      unawaited(applyAudioOptions());
      return true;
    }
    if (!_audioFiltersDisabled) {
      _audioFiltersDisabled = true;
      _notifyAudioFiltersUnavailable();
      unawaited(applyAudioOptions());
    }
    return true;
  }

  void _notifyAudioFiltersUnavailable() {
    if (_audioFiltersNotified) return;
    _audioFiltersNotified = true;
    onAudioFiltersUnavailable?.call();
  }

  /// 复核「选中的音轨确实放不出来」：读 mpv `audio-params`。
  ///
  /// mpv 每次音频链（重新）初始化后都会写入该属性（如
  /// `48000Hz stereo float`）；解码器或音频输出初始化失败时它为 `no`/空。
  /// 读不到（异常/属性不存在）时返回 false —— 宁可漏一次回退，也不要
  /// 因为读属性失败把还能正常出声的音轨切走。
  Future<bool> _isSelectedTrackReallyUnplayable(String selectedId) async {
    final native = _native;
    if (native == null) return false;
    // 复核期间用户已换轨 → 本次诊断作废
    if (_primary?.id != selectedId) return false;
    try {
      final params = (await native.getProperty('audio-params')).trim();
      if (params.isEmpty) return true;
      final lower = params.toLowerCase();
      return lower == 'no' || lower == 'none';
    } catch (_) {
      return false;
    }
  }

  AudioTrack? _trackById(String id) {
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 面板点击轨道的两态循环：选中 → 关闭；未选中 → 选中。
  Future<void> cycleSelection(AudioTrack track) async {
    if (_primary?.id == track.id) {
      await selectTrack(null);
    } else {
      await selectTrack(track);
    }
  }

  /// 导入外部音轨：`audio-add <path> select` 立即选中并刷新轨道列表。
  /// 仅记内存路径（临时），不持久化（工作.md 音频功能）。
  Future<bool> addExternalAudio(String audioPath) async {
    final native = _native;
    if (native == null || audioPath.isEmpty) return false;
    // 记下导入前选中的内嵌音轨：移除外部音轨时要落回它
    if (!_hasAidBeforeExternalImport) {
      _aidBeforeExternalImport = await _readActiveAid();
      _hasAidBeforeExternalImport = true;
    }
    try {
      await native.command(['audio-add', audioPath, 'select']);
    } catch (_) {
      return false;
    }
    if (!_externalPaths.contains(audioPath)) {
      _externalPaths.add(audioPath);
    }
    await reload();
    notifyListeners();
    return true;
  }

  /// 移除已导入的外部音轨：`audio-remove` + 从内存列表删除。
  ///
  /// 若移除的是**当前正在播**的那条，mpv 会把 `aid` 置成 `no`（什么都不选、
  /// 直接没声音）——所以移除后要显式落回内嵌音轨（用户实测 `T3-PLR-032`）。
  Future<void> removeExternalAudio(AudioTrack track) async {
    final native = _native;
    if (native == null || track.id.isEmpty) return;
    final wasSelected = _primary?.id == track.id;
    try {
      await native.command(['audio-remove', track.id]);
    } catch (_) {}
    final source = track.sourcePath;
    if (source != null) {
      _externalPaths.remove(source);
    }
    if (wasSelected) {
      _primary = null;
    }
    await reload();
    if (wasSelected) {
      await selectTrack(
        pickTrackAfterExternalRemoval(
          tracks: _tracks,
          removedId: track.id,
          aidBeforeImport:
              _hasAidBeforeExternalImport ? _aidBeforeExternalImport : null,
        ),
      );
    }
    if (_externalPaths.isEmpty) {
      _aidBeforeExternalImport = null;
      _hasAidBeforeExternalImport = false;
    }
    notifyListeners();
  }

  /// 打开媒体 / 切集后调用（由播放页在 open 完成后触发）：
  /// 刷新轨道列表 + 同步 mpv 实际音轨 + 重新应用声道与音频处理。
  /// 外部音轨不跨媒体保留（mpv 切集自动卸载，[clear] 已清空内存状态）。
  ///
  /// 同时开一次「等音轨起声」探测窗口：mpv 自动选中的那条轨也可能是放不出来的
  /// （例如 TrueHD 8 声道），需要在它初始化失败的当口接住（§4.32）。
  Future<void> reapplyForMedia(String mediaPath) async {
    _openProbeWindow(true);
    await reload();
    await applyAudioOptions();
  }

  /// 切集前清空状态（与 SubtitleController.clear 同思路，防旧媒体数据闪现）。
  void clear() {
    _tracks = const [];
    _primary = null;
    _externalPaths.clear();
    _lastSelectedTrackId = null;
    // 外部音轨不跨媒体保留：还原基线也要一起清（切集后由 mpv 重新自动选）
    _aidBeforeExternalImport = null;
    _hasAidBeforeExternalImport = false;
    // 切集后新媒体的音轨由 mpv 重新自动选，回退防重入需复位
    _fallbackInFlight = false;
    // 注意：_unsupportedAudioFilters / _audioFiltersDisabled（内核缺哪些滤镜）
    // **不清**——那是内核属性，不随切集变化，清了会让每个视频重新踩一遍无声。
    _selectionProbeTimer?.cancel();
    _awaitingAudioStart = false;
    notifyListeners();
  }

  /// 应用音频声道 + 音频处理 + 均衡器（`audio-channels` + `af` 滤镜链）。
  ///
  /// 声道/音频处理值来自全局持久化的 [AudioSettings.instance]，均衡器/低音/
  /// 虚拟环绕值来自 [EqualizerSettings.instance]（两者都跨会话恢复）。
  ///
  /// **只写内核建得起来的滤镜**：内核缺哪个滤镜，mpv 就会让整条 af（乃至整条
  /// 音频链）初始化失败 → 整段无声。所以这里会跳过已确认不支持的滤镜
  /// （[_unsupportedAudioFilters]），整个链都建不起来时直接置空
  /// （[_audioFiltersDisabled]），并回调页面提示（详见 [_handleAudioFilterFailureLog]）。
  Future<void> applyAudioOptions() async {
    final native = _native;
    if (native == null) return;
    try {
      final audio = AudioSettings.instance;
      await native.setProperty(
        'audio-channels',
        audioChannelsPropertyValue(audio.channels),
      );
      final eq = EqualizerSettings.instance;
      final chain = _audioFiltersDisabled
          ? ''
          : buildAudioFilterChain(
              channels: audio.channels,
              volumeNormalization: audio.volumeNormalization,
              drc: audio.drc,
              eqBands: eq.bands,
              eqEnabled: eq.enabled,
              // 与小喵 player 一致：「启用均衡器」开关同时门控低音增强与
              // 虚拟环绕（关时不生效，但保留存储值，重开即恢复）。
              bassBoost: eq.enabled ? eq.bassBoost : 0,
              virtualizer: eq.enabled ? eq.virtualizer : 0,
              unavailableFilters: _unsupportedAudioFilters,
            );
      // 先记下来再写：失败日志可能与写入回复并发到达（见 [_lastAppliedChain]）
      _lastAppliedChain = chain;
      await native.setProperty('af', chain);
    } catch (_) {
      // 播放器不可用（已销毁）时静默
    }
  }

  /// 播放器初始就绪时应用一次设置（初始化越早越好，避免首帧用错声道）。
  Future<void> applyOnInit() async {
    await applyAudioOptions();
  }

  @override
  void dispose() {
    _tracksSubscription?.cancel();
    _logSubscription?.cancel();
    _selectionProbeTimer?.cancel();
    EqualizerSettings.instance.removeListener(_onEqualizerChanged);
    AudioSettings.instance.removeListener(_onAudioSettingsChanged);
    _tracks = const [];
    _primary = null;
    _externalPaths.clear();
    super.dispose();
  }
}
