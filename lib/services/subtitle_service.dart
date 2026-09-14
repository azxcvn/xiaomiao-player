import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' hide SubtitleTrack;
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/subtitle_settings.dart';
import 'package:moumou/utils/async_coalesced_reload.dart';
import 'package:moumou/utils/subtitle_auto_match.dart';
import 'package:moumou/utils/subtitle_memory.dart';
import 'package:moumou/utils/subtitle_style_properties.dart';
import 'package:path/path.dart' as p;

/// 字幕控制器：绑定单个播放器（横竖屏共享同一实例），
/// 维护「轨道列表 / 当前字幕轨道 / 外挂字幕路径」状态并直接驱动 mpv。
///
/// - **单选模型**（只允许同时启用一条字幕轨道，参考 mpv `sid`）；
/// - 外挂字幕按视频路径（`mediaPath`）独立隔离存储，避免 A 视频字幕串到 B 视频；
/// - 记录并持久化每个视频最后选中的字幕轨道，重开视频自动恢复选中；
/// - mpv 属性与命令（参考 mpvRx 的 SubtitleStyle / PlaybackSession）：
///   - 轨道列表：`track-list/count` + `track-list/$i/{type,id,title,lang,codec,external,selected}`；
///   - 当前字幕：`sid`（id 或 'no'；打开文件后 mpv 会自动选一条轨道，
///     [reload] 会把 [primary] 同步成 mpv 实际生效的 sid，保证 UI 选中态）；
///   - 外挂字幕：`sub-add <path> <flags>`（'select' = 立即选中；'auto' = 无字幕时才选，
///     重开文件恢复用），`sub-remove <id>` 移除；
///   - 设置：[SubtitleSettings] 各值映射 `sub-delay` / `sub-scale` / `sub-pos` /
///     `sub-color` / `sub-border-*` / `sub-back-color` / `sub-font` / `sub-ass-override`。
///
/// 内嵌样式策略：
/// - 未开启「强制覆盖内嵌样式」时（默认），`sub-ass-override` 设为 `scale`
///   （保留 ASS 原生字体、特效、位置和排版，同时响应缩放调节）；
/// - 开启「强制覆盖内嵌样式」时，`sub-ass-override` 设为 `force`（用户样式强制生效）。
/// - 普通文本字幕（SRT/VTT）在 scale 和 force 模式下均能正常响应用户样式。
///
/// **B5 定下的三条链路纪律**（改动此处前先读）：
/// - **按字段写入**：高频样式改动走 [applyStyleField]（字段 → 属性表见
///   `utils/subtitle_style_properties.dart`），只有初始化/切媒体/重置才全量
///   [applyAllSettings]（P1-10）；
/// - **等待式刷新**：轨道刷新一律经 [reload]（`AsyncCoalescedReload` 合并成
///   「当前轮 + 补跑」），调用方恢复时 `tracks` 至少含它请求之后的状态（P1-11）；
/// - **用户意图钉回**：`sub-reload` 会重挂外挂轨、改变轨道 id，切轨流程锁住
///   事件驱动刷新、刷新一次后按「外挂源路径」把选择重新钉回 `sid`（P1-41 后半）。
class SubtitleController extends ChangeNotifier {
  SubtitleController(this._player, {SubtitleSettings? settings})
      : _settings = settings ?? SubtitleSettings.instance {
    // 监听 media_kit 轨道流：mpv 解复用完成或轨道变动时自动刷新。
    // ⚠️ 显式切轨期间（[selectTrack] 的 `sub-reload`）**必须**跳过：那次重建会
    // 连发多次轨道事件，每次都刷新的话会用 mpv 临时 sid 覆盖用户刚点的选择
    // （P1-41 后半的 `_primary` 抖动/闪空）；切轨流程自己会锁结束后刷新一次。
    _tracksSubscription = _player.stream.tracks.listen((_) {
      if (_selectionLocked) return;
      reload();
    });
  }

  final Player _player;
  final SubtitleSettings _settings;
  StreamSubscription? _tracksSubscription;

  /// 同名字幕自动加载成功后的回调（参数为字幕文件名），由播放页注入以弹提示。
  /// 服务层不依赖 UI，提示的展示交给页面层。
  void Function(String fileName)? onAutoLoadedSubtitle;

  /// 当前播放的媒体绝对路径
  String? _currentMediaPath;

  /// 当前媒体的全部字幕轨道（空 = 无字幕）
  List<SubtitleTrack> _tracks = const [];

  /// 当前生效的字幕轨道（null = 关闭；打开文件后与 mpv `sid` 同步）
  SubtitleTrack? _primary;

  /// 当前视频已导入的外挂字幕绝对路径（按视频独立隔离）
  final List<String> _externalPaths = [];

  /// 选中外挂字幕的源路径（按路径恢复勾选，见 [_resolveSelectionBySource]）
  String? _primarySourcePath;

  /// 最近一次 reapply 对应的媒体（防横竖屏页重复应用 / 切集重复添加）
  String? _appliedMedia;

  /// 轨道刷新：等待式串行重跑（P1-11）。
  ///
  /// 旧实现是「丢弃式」`if (_loading) return;` —— 在飞时调用方立即返回，
  /// 却假定 `_tracks` 已最新，于是「恢复上次选中字幕」静默失败、UI 显示
  /// 「当前视频没有字幕」。现在并发刷新合并成「当前轮 + 一轮补跑」，
  /// 每个调用方恢复执行时拿到的轨道表**至少包含它请求之后的状态**。
  late final AsyncCoalescedReload _reloader = AsyncCoalescedReload(_refreshTracks);

  /// 显式切轨流程进行中（`sub-reload` 重建期）的**嵌套计数**：抑制事件驱动的
  /// [reload]，由切轨流程收尾时统一等待式刷新 + 钉回用户意图（P1-41 后半）。
  ///
  /// 用计数而非 bool：快速连点会让两次 [selectTrack] 重叠执行，bool 会被先结束
  /// 的那次提前解锁，重建期的事件又会漏进来。
  int _selectionLocks = 0;
  bool get _selectionLocked => _selectionLocks > 0;

  /// 用户最近一次**显式**选择字幕的意图（P1-41 后半的「钉回」依据）。
  ///
  /// 切轨会 `sub-reload` 把外挂轨删掉重挂、**轨道 id 随之变化**，所以外挂轨
  /// 记源路径（稳定）、内嵌轨记 id；「关闭字幕」记 [_intentClosed]。异步重建
  /// 之后按它把选择重新写回 `sid`，迟到的轨道事件读到的就是正确轨道（幂等）。
  String? _intentSourcePath;
  String? _intentTrackId;
  bool _intentClosed = false;
  bool _hasIntent = false;

  /// 已 dispose（异步刷新迟到时不得再 notify）
  bool _disposed = false;

  /// 最近一次 fetchTracks 检测到被 mpv 选中的轨道 ID
  String? _lastSelectedTrackId;

  List<SubtitleTrack> get tracks => List.unmodifiable(_tracks);
  SubtitleTrack? get primary => _primary;
  String? get primarySourcePath => _primarySourcePath;
  List<String> get externalPaths => List.unmodifiable(_externalPaths);

  NativePlayer? get _native {
    final platform = _player.platform;
    return platform is NativePlayer ? platform : null;
  }

  /// 读取当前媒体的字幕轨道列表（仅 subtitle 类型；'no' 等伪轨排除）。
  Future<List<SubtitleTrack>> fetchTracks() async {
    final native = _native;
    if (native == null) return const [];
    final countStr = await native.getProperty('track-list/count');
    final count = int.tryParse(countStr) ?? 0;
    if (count <= 0) return const [];
    final result = <SubtitleTrack>[];
    String? selectedSubId;
    for (var i = 0; i < count; i++) {
      final type = await native.getProperty('track-list/$i/type');
      if (type != 'sub') continue;
      final id = await native.getProperty('track-list/$i/id');
      if (id.isEmpty || id == 'no') continue;
      final title = await native.getProperty('track-list/$i/title');
      final lang = await native.getProperty('track-list/$i/lang');
      final codec = await native.getProperty('track-list/$i/codec');
      final external = await native.getProperty('track-list/$i/external');
      final selected = await native.getProperty('track-list/$i/selected');
      final sourcePath =
          await native.getProperty('track-list/$i/external-filename');
      if (selected == 'yes') {
        selectedSubId = id;
      }
      result.add(
        SubtitleTrack(
          id: id,
          title: title.isEmpty ? null : title,
          language: lang.isEmpty ? null : lang,
          codec: codec.isEmpty ? null : codec,
          external: external == 'yes',
          sourcePath: sourcePath.isEmpty ? null : sourcePath,
        ),
      );
    }
    _lastSelectedTrackId = selectedSubId;
    return result;
  }

  /// mpv 当前生效的 `sid`（可能为 'no' / 'auto' / 轨道 id）
  Future<String> _readActiveSid() async {
    final native = _native;
    if (native == null) return 'no';
    try {
      final sid = (await native.getProperty('sid')).trim();
      return sid.isEmpty ? 'no' : sid;
    } catch (_) {
      return 'no';
    }
  }

  /// 用 mpv 实际生效的 sid 同步 [primary]（打开/重开后 mpv 自动选的轨道
  /// 也要反映到 UI 选中态 + 内嵌样式策略）。
  Future<void> _syncActiveFromMpv() async {
    final sid = await _readActiveSid();
    SubtitleTrack? resolved;
    if (sid != 'no' && sid.isNotEmpty) {
      // 轨道 id 会因 `sub-reload` 重挂外挂轨而变化：解析不到时按**用户意图**
      // （外挂轨按源路径，路径稳定）找回，别把用户刚点的那条丢掉（P1-41 后半）。
      resolved = _resolveSelection(sid) ?? _resolveIntent();
    }
    // 只有「用户从未显式选过/关过字幕」时才回落到上次探测到的选中项；
    // 有意图时回落会把「关闭字幕」或刚点的选择重新点着（P1-41 后半）。
    if (resolved == null && sid != 'no' && !_hasIntent && _lastSelectedTrackId != null) {
      resolved = _resolveSelection(_lastSelectedTrackId);
    }
    _primary = resolved;
    _primarySourcePath = resolved?.sourcePath;
    _safeNotify();
  }

  /// 重新加载轨道列表并同步当前选中（以 mpv 实际 sid 为准）。
  ///
  /// **等待式**（P1-11）：并发调用不互相丢弃，合并成「当前轮 + 一轮补跑」；
  /// 每个调用方恢复执行时 `tracks` 至少包含它调用之后的状态。
  Future<void> reload() => _reloader.run();

  /// [reload] 的实际任务体（由 [AsyncCoalescedReload] 串行调度，绝不并发）。
  Future<void> _refreshTracks() async {
    List<SubtitleTrack>? tracks;
    try {
      tracks = await fetchTracks();
    } catch (_) {
      // 读轨道被并发命令打断（`sub-add`/`sub-reload` 期间）时**保留上一份快照**，
      // 不要清空：清空会让 UI 闪出「当前视频没有字幕」（P1-11 的可见症状）。
      // 下一轮补跑/事件刷新会把真实轨道读回来。
      tracks = null;
    }
    if (_disposed) return;
    if (tracks != null) _tracks = tracks;
    await _syncActiveFromMpv();
  }

  /// 记录用户显式选择意图（null = 关闭字幕）。
  void _rememberIntent(SubtitleTrack? track) {
    _hasIntent = true;
    _intentClosed = track == null;
    _intentTrackId = track?.id;
    _intentSourcePath = track?.sourcePath;
  }

  /// 记录「按外挂字幕源路径」的选择意图（导入 / 同名自动加载用）。
  void _rememberIntentPath(String sourcePath) {
    _hasIntent = true;
    _intentClosed = false;
    _intentTrackId = null;
    _intentSourcePath = sourcePath;
  }

  void _clearIntent() {
    _hasIntent = false;
    _intentClosed = false;
    _intentTrackId = null;
    _intentSourcePath = null;
  }

  /// 按用户意图在当前轨道表里找回应选中的轨道（找不到 = 意图已失效）。
  SubtitleTrack? _resolveIntent() {
    if (!_hasIntent || _intentClosed) return null;
    final bySource = _resolveSelectionBySource(_intentSourcePath);
    if (bySource != null) return bySource;
    return _resolveSelection(_intentTrackId);
  }

  /// 把用户意图重新钉回 mpv（`sub-reload` 之后外挂轨 id 变化时会丢选中）。
  ///
  /// **以「mpv 当前 sid 是否已指向目标」为准重写 sid**：`sub-reload` 之后 mpv 的
  /// sid 可能停在**已失效的旧 id** 上——此时 `_primary` 已由 [_syncActiveFromMpv]
  /// 按意图路径找回、UI 显示为选中，但 mpv 侧实际没有生效的字幕；这时必须真写一次
  /// `sid` 才能保证「UI 高亮的那条 = 真正渲染的那条」。反过来，sid 已等于目标 id
  /// （内嵌轨、没被重挂的外挂轨都是这种）就不重复写，避免多余的重选动作
  /// ——历史坑：内嵌 ASS 轨的样式依赖「`sub-ass-override` 先写、再 `sub-reload`」，
  /// 无谓的重选会多一次副标题解码器重建，改这块时必验（§7）。
  Future<void> _reassertSelection() async {
    final native = _native;
    if (native == null || !_hasIntent) return;
    if (_intentClosed) {
      // 显式「关闭字幕」也要钉住：重建期间 mpv 可能自己选了一条。
      if (await _readActiveSid() != 'no') {
        try {
          await native.setProperty('sid', 'no');
        } catch (_) {}
      }
      _primary = null;
      _primarySourcePath = null;
      return;
    }
    final target = _resolveIntent();
    if (target == null) return;
    if (await _readActiveSid() != target.id) {
      try {
        await native.setProperty('sid', target.id);
      } catch (_) {
        return;
      }
    }
    _primary = target;
    _primarySourcePath = target.sourcePath;
  }

  /// 在「显式切轨锁」内执行 [body]：期间事件驱动的 [reload] 一律跳过。
  Future<void> _withSelectionLock(Future<void> Function() body) async {
    _selectionLocks++;
    try {
      await body();
    } finally {
      _selectionLocks--;
    }
  }

  /// 通知监听者；已 dispose（异步刷新迟到）时静默返回，
  /// 避免「ChangeNotifier used after dispose」断言。
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// 外挂字幕记忆路径是否仍可用（存在性校验，P1-9）。
  bool _subtitlePathExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 按 id 在现轨道中找回选中项（找不到返回 null = 已失效）
  SubtitleTrack? _resolveSelection(String? id) {
    if (id == null || id == 'no' || id == 'auto') return null;
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 按源路径在现轨道中找回外挂字幕（切集重新 sub-add 后 id 变化，路径稳定）
  SubtitleTrack? _resolveSelectionBySource(String? sourcePath) {
    if (sourcePath == null) return null;
    for (final t in _tracks) {
      if (t.external && t.sourcePath == sourcePath) return t;
    }
    return null;
  }

  /// 勾选字幕轨道：传 null 关闭。单选模型——同一时刻只允许一条轨道生效。
  Future<void> selectTrack(SubtitleTrack? track) async {
    final native = _native;
    if (native == null) return;
    _rememberIntent(track);
    try {
      await native.setProperty('sid', track?.id ?? 'no');
    } catch (_) {
      return;
    }
    _primary = track;
    _primarySourcePath = track?.sourcePath;
    if (_currentMediaPath != null) {
      await _settings.setSelectedSubtitleFor(
        _currentMediaPath!,
        track?.sourcePath ?? track?.id ?? 'no',
      );
    }
    // 切轨道后重建一次，让 sub-ass-override 对新轨道生效（低频操作，可接受）。
    //
    // ⚠️ `sub-reload` 会把外挂轨**删掉重挂**（轨道 id 变化），期间 mpv 连发
    // 轨道事件；若每条事件都各自刷新一次，就会用 mpv 的临时 sid 覆盖用户刚点的
    // 选择 → `_primary` 短暂为 null →「关闭字幕」条件行闪现、面板跳动
    // （P1-41 后半 + P2-42 的真机现象，仅外挂轨触发）。因此这里：
    // ①重建期间**锁住**事件驱动刷新；②重建完自己等待式刷新一次；
    // ③按用户意图（外挂轨用源路径）把选择重新钉回 sid —— 之后迟到的轨道事件
    // 读到的 sid 已是正确轨道，刷新幂等。
    await _withSelectionLock(() async {
      await applyStyleOverride();
      await reload();
      await _reassertSelection();
    });
    _safeNotify();
  }

  /// 面板点击轨道的两态循环：选中 → 关闭；未选中 → 选中。
  Future<void> cycleSelection(SubtitleTrack track) async {
    if (_primary?.id == track.id) {
      await selectTrack(null);
    } else {
      await selectTrack(track);
    }
  }

  /// 导入外挂字幕：原生侧先把 content:// 拷贝为真实路径（若需要），
  /// 再 `sub-add <path> select` 并刷新轨道列表；成功后记忆路径（绑定当前视频）。
  Future<bool> addExternalSubtitle(String subtitlePath) async {
    final native = _native;
    if (native == null || subtitlePath.isEmpty) return false;
    try {
      await native.command(['sub-add', subtitlePath, 'select']);
    } catch (_) {
      return false;
    }
    if (!_externalPaths.contains(subtitlePath)) {
      _externalPaths.add(subtitlePath);
    }
    _rememberIntentPath(subtitlePath);
    if (_currentMediaPath != null) {
      await _settings.addImportedSubtitleFor(_currentMediaPath!, subtitlePath);
      await _settings.setSelectedSubtitleFor(_currentMediaPath!, subtitlePath);
    }
    await reload();
    await _reassertSelection();
    _safeNotify();
    return true;
  }

  /// 移除已导入的外挂字幕：`sub-remove` + 从当前视频记忆列表删除。
  Future<void> removeExternalSubtitle(SubtitleTrack track) async {
    final native = _native;
    if (native == null || track.id.isEmpty) return;
    try {
      await native.command(['sub-remove', track.id]);
    } catch (_) {}
    final source = track.sourcePath;
    if (source != null) {
      _externalPaths.remove(source);
      if (_currentMediaPath != null) {
        await _settings.removeImportedSubtitleFor(_currentMediaPath!, source);
      }
    }
    // 被移除的正是用户最后选中的那条 → 意图作废，交回 mpv 的 sid 决定后续。
    if (source != null && _intentSourcePath == source) _clearIntent();
    _primarySourcePath = null;
    await reload();
    _safeNotify();
  }

  /// 打开媒体 / 切集后调用（由播放页在 open 完成后触发）：
  /// - 按媒体路径独立加载该视频专属的外挂字幕；
  /// - 若无任何已导入字幕，则自动加载同目录下的同名字幕（对齐小喵 player，
  ///   简体系统优先 sc、繁体系统优先 tc）；
  /// - 恢复该视频最后一次选中的字幕轨道；
  /// - 应用全部字幕设置。
  Future<void> reapplyForMedia(String mediaPath) async {
    if (_appliedMedia == mediaPath) return;
    _appliedMedia = mediaPath;
    _currentMediaPath = mediaPath;
    final native = _native;
    if (native == null) return;

    // 获取当前视频专属导入的外挂字幕，并**逐个校验存在性**（P1-9）：
    // 用户删/改名了字幕文件后，记忆里的死路径会让 `sub-add` 静默失败，而
    // 「记忆非空即跳过同名扫描」又让该视频**永久**没有字幕（文档 §4.11 记过的
    // 「记忆死路径」教训，弹幕侧早已清理、字幕侧此前没有）。失效项从设置里删除，
    // 全部失效时下面的同名扫描照常执行（把文件放回去即可重新自动加载）。
    final remembered = _settings.getImportedSubtitlesFor(mediaPath);
    final memo = partitionSubtitleMemoryPaths(
      remembered,
      exists: _subtitlePathExists,
    );
    for (final stale in memo.stale) {
      await _settings.removeImportedSubtitleFor(mediaPath, stale);
    }
    _externalPaths.clear();
    _externalPaths.addAll(memo.valid);

    // 同名字幕自动加载：仅当该视频还没有任何**仍然有效**的已导入字幕时扫描，
    // 避免覆盖用户手动导入的选择；找到后 sub-add select 并记忆路径。
    String? autoLoadedPath;
    if (memo.valid.isEmpty) {
      autoLoadedPath = await _autoLoadSameNameSubtitle(mediaPath);
      if (autoLoadedPath != null && !_externalPaths.contains(autoLoadedPath)) {
        _externalPaths.add(autoLoadedPath);
      }
    }

    // 挂载属于当前视频的外挂字幕（自动加载的那条已 select 挂载，跳过防重复）
    for (final path in _externalPaths) {
      if (path == autoLoadedPath) continue;
      try {
        await native.command(['sub-add', path, 'auto']);
      } catch (_) {}
    }
    await reload();

    // 恢复该视频最后一次选中的字幕（本次自动加载时已 select，无需再恢复）
    if (autoLoadedPath == null) {
      final savedSub = _settings.getSelectedSubtitleFor(mediaPath);
      if (savedSub == 'no') {
        _rememberIntent(null);
        try {
          await native.setProperty('sid', 'no');
        } catch (_) {}
        _primary = null;
        _primarySourcePath = null;
      } else if (savedSub != null && savedSub.isNotEmpty) {
        final t =
            _resolveSelectionBySource(savedSub) ?? _resolveSelection(savedSub);
        if (t != null) {
          _rememberIntent(t);
          try {
            await native.setProperty('sid', t.id);
          } catch (_) {}
          _primary = t;
          _primarySourcePath = t.sourcePath;
        } else {
          // 记忆里的选中项已失效（文件被删/改名）→ 不留意图，
          // 由上面 `sub-add … auto` 与 mpv 的实际 sid 决定选中态。
          _clearIntent();
        }
      } else {
        // 该视频从未手动选过字幕：不留意图，尊重 mpv 自动选择的结果。
        _clearIntent();
      }
    }

    await _syncActiveFromMpv();
    await applyAllSettings();
  }

  /// 扫描视频同目录下的同名字幕并自动加载最佳匹配（对齐小喵
  /// `autoLoadSubtitleIfExists` 的本地文件路径）。
  ///
  /// 返回自动加载的字幕绝对路径；无匹配 / 失败返回 null。
  Future<String?> _autoLoadSameNameSubtitle(String mediaPath) async {
    final native = _native;
    if (native == null) return null;
    final videoFile = File(mediaPath);
    try {
      if (!videoFile.existsSync()) return null;
    } catch (_) {
      return null;
    }
    final videoDir = videoFile.parent;
    final videoNameWithoutExt = p.basenameWithoutExtension(mediaPath);
    if (videoNameWithoutExt.isEmpty) return null;

    final names = <String>[];
    final pathsByName = <String, String>{};
    try {
      await for (final e in videoDir.list()) {
        if (e is! File) continue;
        final path = e.path;
        final name = p.basename(path);
        names.add(name);
        pathsByName[name] = path;
      }
    } catch (_) {
      return null;
    }
    if (names.isEmpty) return null;

    final bestName = findBestSubtitleFileName(
      videoNameWithoutExt,
      names,
      systemLanguage: _systemLocaleString(),
    );
    if (bestName == null) return null;
    final bestPath = pathsByName[bestName];
    if (bestPath == null) return null;

    try {
      await native.command(['sub-add', bestPath, 'select']);
    } catch (_) {
      return null;
    }
    // 记忆路径 + 选中：下次打开跳过自动扫描、直接恢复（对齐小喵 setExternalSubtitle）
    _rememberIntentPath(bestPath);
    await _settings.addImportedSubtitleFor(mediaPath, bestPath);
    await _settings.setSelectedSubtitleFor(mediaPath, bestPath);
    onAutoLoadedSubtitle?.call(bestName);
    return bestPath;
  }

  /// 当前系统首选 locale（转成小写 Android 风格串，如 `zh_cn`/`zh_tw`/`zh_hk`）。
  String _systemLocaleString() {
    final locales = PlatformDispatcher.instance.locales;
    if (locales.isEmpty) return 'en_us';
    final l = locales.first;
    final country = l.countryCode;
    if (country == null || country.isEmpty) return l.languageCode.toLowerCase();
    return '${l.languageCode}_$country'.toLowerCase();
  }

  /// 切集前清空状态（与 ChapterTracker.clear 同思路，防旧媒体数据闪现）
  void clear() {
    _tracks = const [];
    _primary = null;
    _primarySourcePath = null;
    _externalPaths.clear();
    // 用户意图属于「上一个媒体」，一起清掉；新媒体的意图由 [reapplyForMedia] 重建。
    _clearIntent();
    // 「已应用媒体」标记必须一起复位（B3/P1-8 根因）：[reapplyForMedia] 首行
    // `if (_appliedMedia == mediaPath) return;` 是「同一媒体不重复挂载」的早退，
    // 而 clear() 之后媒体已被重新 open（mpv 丢弃全部 sub-add 的外挂轨道）——
    // 不复位就会早退不补挂：单视频列表循环重播即「外挂字幕消失」。
    _appliedMedia = null;
    _safeNotify();
  }

  /// 只写**单个字段**对应的 mpv 属性（P1-10：滑杆「松手提交」路径）。
  ///
  /// 字段 → 属性的映射收敛在 [subtitleStyleWrites]（纯函数，单测锁定
  /// 「一个字段只写它自己那一条/那一组」）；旧实现每次拖动都全量
  /// [applyAllSettings]，一次事件串行写 16 个 mpv 属性 + 一次设置写盘。
  Future<void> applyStyleField(SubtitleStyleField field) async {
    final values = SubtitleStyleValues.fromSettings(_settings);
    await _writeProperties(subtitleStyleWrites(field, values));
  }

  /// 应用全部字幕设置（延迟/大小/颜色/描边/阴影/背景/粗细/斜体/间距/模糊/
  /// 位置/字体/内嵌样式策略）。
  ///
  /// **低频路径**：初始化（[applyOnInit]）、切媒体（[reapplyForMedia]）、
  /// 面板里的「重置…」。滑杆等高频改动一律走 [applyStyleField]（P1-10）。
  Future<void> applyAllSettings() async {
    await _writeProperties(
      allSubtitleStyleWrites(SubtitleStyleValues.fromSettings(_settings)),
    );
    // 只写 override 值，不 sub-reload：颜色/缩放/位置等 sub-* 属性即时生效，
    // 每次拖动都 sub-reload 会重新读盘解析外部字幕，导致卡顿。
    await _setOverrideProperty();
  }

  /// 逐条写入 mpv 属性（串行，避免通道调用互相插队）。
  ///
  /// 字体**目录**已在 Player 构造时通过 `libassAndroidFontsDir` 注入
  /// （`mpv_initialize` 之前），这里**绝不**再写 `sub-fonts-dir`。
  ///
  /// 历史 bug（P1-10）：默认字体分支曾在运行期写
  /// `sub-fonts-dir='/system/fonts'`，会重载 libass 的 fontconfig 缓存；
  /// 缓存被打坏后 libass 连**位图字幕**（PGS/DVD/DVB，靠 DRAWING 指令渲染）
  /// 一起不渲染 —— 表现为「内嵌字幕无论选哪条都不显示」。因此运行期只允许
  /// 写 `sub-font`（族名）与字体无关的样式属性，目录一律构造期注入。
  Future<void> _writeProperties(List<SubtitlePropertyWrite> writes) async {
    final native = _native;
    if (native == null) return;
    for (final w in writes) {
      try {
        await native.setProperty(w.name, w.value);
      } catch (_) {
        // 播放器已销毁 / 属性不可用时跳过这一条，继续写其余属性
        // （旧实现是一个 try 包住全部：任一条抛错后面的全被跳过）。
      }
    }
  }

  /// 只写内嵌样式策略值（`force`/`scale`），不重建轨道。
  /// 颜色/缩放/位置等 sub-* 属性通过 setProperty 即时生效，无需 sub-reload。
  Future<void> _setOverrideProperty() async {
    final native = _native;
    if (native == null) return;
    final value = _settings.overrideEmbeddedStyle ? 'force' : 'scale';
    try {
      await native.setProperty('sub-ass-override', value);
    } catch (_) {}
  }

  /// 应用内嵌样式策略并重建字幕轨道（`sub-reload`）。
  ///
  /// 内嵌样式策略：
  /// - 开启「强制覆盖内嵌样式」→ `force`（用户样式生效，强制覆盖 ASS 样式与字体）；
  /// - 未开启「强制覆盖内嵌样式」→ `scale`（默认：mpv 完美保留 ASS 原生字体、特效、位置和排版，同时响应缩放调节）。
  /// - 普通文本字幕（SRT/VTT）在 scale 和 force 模式下均能正常响应用户样式。
  ///
  /// 仅应在「强制覆盖内嵌样式」开关切换、或切换字幕轨道后调用一次：
  /// `sub-reload` 会移除并重新添加轨道（对外部字幕 = 重新读盘 + 解析 + 字体匹配），
  /// 放进高频的样式拖动路径会导致明显卡顿。
  Future<void> applyStyleOverride({bool? force}) async {
    final native = _native;
    if (native == null) return;
    // force 显式传入时用目标值（开关切换场景，绕过 setOverrideEmbeddedStyle
    // 尚未 await 完成的竞态）；否则读当前设置（切轨道场景，值已稳定）。
    final value = (force ?? _settings.overrideEmbeddedStyle) ? 'force' : 'scale';
    try {
      await native.setProperty('sub-ass-override', value);
      await native.setProperty('sub-font-provider', 'auto');
      await native.command(['sub-reload']);
    } catch (_) {}
  }

  /// 播放器初始就绪时应用一次设置（初始化越早越好，避免首帧无字幕样式）
  Future<void> applyOnInit() async {
    // ⚠️ 这一条必须在**任何 await 之前**发出去：`sub-auto` 只在文件加载时生效，
    // 首次 open 之后才写就无效（本方法后面的 ensureLoaded / 字体拷贝可能很慢）。
    //
    // 禁用 mpv 自带的「同名外挂字幕自动加载」：mpv 默认会为与视频同名的外挂字幕
    // 自动挂一条，而本控制器的 [_autoLoadSameNameSubtitle] 又会 `sub-add` 同一条
    // → 同一个外挂文件出现**两条完全相同的轨道**（都带「外挂」与删除按钮）；
    // 切轨时 [applyStyleOverride] 的 `sub-reload` 会重挂轨道、改变轨道 id，
    // 引发「点轨道不亮、高亮乱跳、界面闪烁」（真机 2026-09 复现；字幕名与视频名
    // 完全相同时必现，加 `-SC`/`-TC` 后缀后 mpv 的同名匹配失效故不复现）。
    // 同名字幕统一由 App 负责（匹配更准：简繁 -sc/-tc 优先 + 记忆 + 只认字幕扩展名）。
    // 注：`sub-reload` 后 sid 覆盖用户选择那一半已在 B5 收口——切轨期间锁住
    // 事件驱动刷新，并按用户意图（外挂轨用源路径）把选择重新钉回 sid（见 [selectTrack]）。
    final native = _native;
    if (native != null) {
      unawaited(native.setProperty('sub-auto', 'no').catchError((_) {}));
    }
    await _settings.ensureLoaded();
    await DeviceServices.ensureDefaultFontCopied();
    await applyAllSettings();
  }

  @override
  void dispose() {
    // 先置废标志：在途的等待式刷新回来时不得再 notify（P1-11 的迟到路径）。
    _disposed = true;
    _tracksSubscription?.cancel();
    _tracks = const [];
    _primary = null;
    super.dispose();
  }
}