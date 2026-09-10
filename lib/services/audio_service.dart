import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide AudioTrack;
import 'package:moumou/models/audio_track.dart';
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

/// 音频控制器：绑定单个播放器（横竖屏共享同一实例），
/// 维护「音频轨道列表 / 当前音轨 / 外部音轨 / 声道 / 音频处理」状态并直接驱动 mpv。
///
/// - **单选模型**（只允许同时启用一条音轨，参考 mpv `aid`）；
/// - 外部音轨**临时**（工作.md 音频功能：退出播放后不保留）——只存内存，
///   切集 mpv 自动卸载外部音轨，[clear] 清空内存状态，不做任何持久化；
/// - **声道 / 音频处理为会话级状态**（工作.md 音频功能：每次进播放器重置）——
///   控制器随播放器生命周期创建，字段初始化为默认值（安全自动 / 音量标准化关 /
///   动态范围压缩关），不跨播放会话持久化；
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
  }

  final Player _player;
  StreamSubscription? _tracksSubscription;
  StreamSubscription? _logSubscription;

  /// 音轨自动回退结果回调（页面层据此提示用户；服务层不依赖 UI，与
  /// [SubtitleController.onAutoLoadedSubtitle] 同一约定）。
  ///
  /// - [fallback] 非空 = 已自动切到该音轨；
  /// - [fallback] 为空 = 确认当前音轨放不出来但**无路可退**（调用方提示失败原因）；
  /// - [failed] 为判定失败的那条音轨（可能为 null）；[reason] 为给用户看的说明。
  void Function(AudioTrack? fallback, AudioTrack? failed, String reason)?
      onAudioFallback;

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

  // ── 会话级设置（每次进播放器重置，不持久化）────────────

  /// 音频声道（默认安全自动）
  AudioChannels _channels = AudioChannels.autoSafe;

  /// 音量标准化开关（默认关闭）
  bool _volumeNormalization = false;

  /// 动态范围压缩开关（默认关闭）
  bool _drc = false;

  AudioChannels get channels => _channels;
  bool get volumeNormalization => _volumeNormalization;
  bool get drc => _drc;

  /// 当前媒体的全部音轨（空 = 无音轨）
  List<AudioTrack> _tracks = const [];

  /// 当前生效的音轨（null = 关闭；打开文件后与 mpv `aid` 同步）
  AudioTrack? _primary;

  /// 当前视频已导入的外部音轨绝对路径（临时，仅内存，不持久化）
  final List<String> _externalPaths = [];

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

  /// 设置音频声道并立即应用（会话级，不持久化）。
  Future<void> setChannels(AudioChannels v) async {
    if (_channels == v) return;
    _channels = v;
    notifyListeners();
    await applyAudioOptions();
  }

  /// 设置音量标准化开关并立即应用（会话级，不持久化）。
  Future<void> setVolumeNormalization(bool v) async {
    if (_volumeNormalization == v) return;
    _volumeNormalization = v;
    notifyListeners();
    await applyAudioOptions();
  }

  /// 设置动态范围压缩开关并立即应用（会话级，不持久化）。
  Future<void> setDrc(bool v) async {
    if (_drc == v) return;
    _drc = v;
    notifyListeners();
    await applyAudioOptions();
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

  /// mpv 日志入口：命中「音轨放不出来」特征时启动一次复核 + 回退。
  void _handleLog(String prefix, String text) {
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
            '当前音轨无法播放，且没有其它可切换的音轨',
          );
          return;
        }
        await selectTrack(fallback);
        onAudioFallback?.call(
          fallback,
          failed,
          '当前音轨无法播放，已自动切换到「${fallback.displayTitle}」',
        );
      } finally {
        _fallbackInFlight = false;
      }
    }));
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
  Future<void> removeExternalAudio(AudioTrack track) async {
    final native = _native;
    if (native == null || track.id.isEmpty) return;
    try {
      await native.command(['audio-remove', track.id]);
    } catch (_) {}
    final source = track.sourcePath;
    if (source != null) {
      _externalPaths.remove(source);
    }
    if (_primary?.id == track.id) {
      _primary = null;
    }
    await reload();
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
    // 切集后新媒体的音轨由 mpv 重新自动选，回退防重入需复位
    _fallbackInFlight = false;
    _selectionProbeTimer?.cancel();
    _awaitingAudioStart = false;
    notifyListeners();
  }

  /// 应用音频声道 + 音频处理 + 均衡器（`audio-channels` + `af` 滤镜链）。
  ///
  /// 声道/音频处理值来自本控制器的会话级字段（每次进播放器重置为默认）；
  /// 均衡器/低音/虚拟环绕值来自全局持久化的 [EqualizerSettings.instance]
  /// （与小喵 player 的「均衡器跨会话恢复」一致）。
  Future<void> applyAudioOptions() async {
    final native = _native;
    if (native == null) return;
    try {
      await native.setProperty(
        'audio-channels',
        audioChannelsPropertyValue(_channels),
      );
      final eq = EqualizerSettings.instance;
      await native.setProperty(
        'af',
        buildAudioFilterChain(
          channels: _channels,
          volumeNormalization: _volumeNormalization,
          drc: _drc,
          eqBands: eq.bands,
          eqEnabled: eq.enabled,
          // 与小喵 player 一致：「启用均衡器」开关同时门控低音增强与
          // 虚拟环绕（关时不生效，但保留存储值，重开即恢复）。
          bassBoost: eq.enabled ? eq.bassBoost : 0,
          virtualizer: eq.enabled ? eq.virtualizer : 0,
        ),
      );
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
    _tracks = const [];
    _primary = null;
    _externalPaths.clear();
    super.dispose();
  }
}
