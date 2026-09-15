/// 播放历史服务（工作.md：播放历史记录功能）：
/// 记录最近播放过的视频（本地文件 + 打开链接的在线 URL），
/// 供首页速拨「最近播放」直启最后一次播放的视频、
/// 「我的 → 播放 → 历史记录」查看/删除/清空/关闭记录。
///
/// - 全局单例 ChangeNotifier（同 `IntroOutroSettings` 模式），
///   SharedPreferences 单键 JSON 持久化，条目按 path 去重（重复播放
///   提到最前），上限淘汰最旧；
/// - 「关闭播放历史记录」只停止新记录写入，已存历史保留可查看/清除；
/// - **只记录可重放来源**：本地真实路径与在线直链。loopback 代理 URL
///   （网络存储，`127.0.0.1` 退出即失效）与哔哩哔哩在线播放
///   （需登录态重新解析 playurl）由调用方过滤，不写入历史。
///
/// ## 与播放进度的关系（[clearProgressOnDelete]）
///
/// 播放历史（本服务）与播放进度（`PlaybackProgressService`）**存储上解耦**：
/// 两个独立的 SharedPreferences 键，互不依赖。用户反馈「删除历史后进度还在」
/// 的诉求，用**开关**解决而非改成硬耦合：
///
/// - [clearProgressOnDelete] 开 → 删历史**级联**清进度；
/// - 关 → 删历史不动进度（原行为）。
///
/// ⚠️ [clearProgressOnDelete] **依赖** [enabled]：关掉历史记录后列表里没有
/// 条目，"删除历史"这个动作根本不会发生，开关处于悬空状态（还会让用户误以为
/// 进度被清了）。故用 [effectiveClearProgressOnDelete] 做一次裁决——
/// 只有历史记录开启时级联才真正生效。裁决只放这一处，UI 与删除路径共用。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moumou/models/playback_history_entry.dart';
import 'package:moumou/utils/async_serial_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackHistoryService extends ChangeNotifier {
  /// App 全局单例（测试构造独立实例共享同一持久化 key，同 DanmakuManualMemory）
  static final PlaybackHistoryService instance = PlaybackHistoryService();

  PlaybackHistoryService();

  /// 加载去重（risk_audit #9 同款防护）：setter 先 await [ensureLoaded]，
  /// 防启动 load 未完成时用户改动被覆盖。
  Future<void>? _loadFuture;

  /// 写入串行队列（[AsyncSerialQueue]，§4.29）：保证 record/remove/clearAll 的
  /// prefs 写入按提交顺序执行，磁盘上永远是最后一次调用的完整快照（P2-40）。
  final AsyncSerialQueue _writeQueue = AsyncSerialQueue();

  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyEntries = 'playback_history_entries';
  static const _keyEnabled = 'playback_history_enabled';
  static const _keyClearProgressOnDelete = 'playback_history_clear_progress';

  /// 历史条目上限（超过淘汰最旧；对齐 mpvRx 最近播放为有界列表的思路）
  static const int maxEntries = 500;

  bool _enabled = true;
  List<PlaybackHistoryEntry> _entries = const [];

  /// 删除历史时是否同步清除播放进度（默认**关闭** = 原行为，两套数据解耦）
  bool _clearProgressOnDelete = false;

  bool get enabled => _enabled;

  /// 「删除历史时同步清除进度」的**原始**开关值（不代表当前是否真的生效，
  /// 生效判定见 [effectiveClearProgressOnDelete]）
  bool get clearProgressOnDelete => _clearProgressOnDelete;

  /// 该开关当前**是否可操作**：只有历史记录开启时才有意义
  /// （关掉历史记录后列表为空，没有"删除历史"这个动作）
  bool get canClearProgressOnDelete => _enabled;

  /// 级联删除**实际是否生效** = 开关值 ∧ 历史记录开启。
  ///
  /// ⚠️ 删除路径必须用本值、不要直接用 [clearProgressOnDelete]——否则
  /// 「历史记录关 + 级联开关开」时用户会以为进度被清了，实际没清。
  bool get effectiveClearProgressOnDelete => _enabled && _clearProgressOnDelete;

  /// 历史条目（新 → 旧；unmodifiable 防外部直接改）
  List<PlaybackHistoryEntry> get entries => List.unmodifiable(_entries);

  /// 最近一次播放的条目（无历史返回 null）
  PlaybackHistoryEntry? get mostRecent =>
      _entries.isEmpty ? null : _entries.first;

  /// 启动时加载（main.dart 调用）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    _clearProgressOnDelete = prefs.getBool(_keyClearProgressOnDelete) ?? false;
    _entries = _decode(prefs.getString(_keyEntries));
    notifyListeners();
  }

  /// 测试用：重置内存态（下一次 ensureLoaded 重新读盘），不落盘
  @visibleForTesting
  void debugReset() {
    _loadFuture = null;
    _entries = const [];
    _enabled = true;
    _clearProgressOnDelete = false;
  }

  /// 记录一次播放（同 path 去重并提到最前；关闭记录时不写入）。
  /// [durationMs] 已知时长（如来自播放列表 MediaStore），未知传 0。
  Future<void> record(
    String path,
    String title, {
    required bool isUrl,
    int durationMs = 0,
  }) async {
    await ensureLoaded();
    if (!_enabled || path.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 保留已知时长（旧条目时长 > 新传入的 0 时沿用旧值）
    final old = _entries.where((e) => e.path == path).firstOrNull;
    final keptDuration = durationMs > 0 ? durationMs : (old?.durationMs ?? 0);
    _entries = [
      PlaybackHistoryEntry(
        path: path,
        title: title.isEmpty ? path : title,
        isUrl: isUrl,
        playedAtMs: now,
        durationMs: keptDuration,
      ),
      for (final e in _entries)
        if (e.path != path) e,
    ];
    if (_entries.length > maxEntries) {
      _entries = _entries.sublist(0, maxEntries);
    }
    notifyListeners();
    await _persist();
  }

  /// 回填条目时长（播放页退出时调用：open 时未知、播完退出后已知）。
  /// 条目不存在（被删除/未记录）时静默忽略。
  Future<void> updateDuration(String path, int durationMs) async {
    await ensureLoaded();
    if (durationMs <= 0) return;
    var changed = false;
    _entries = [
      for (final e in _entries)
        e.path == path && e.durationMs != durationMs
            ? () {
                changed = true;
                return e.copyWith(durationMs: durationMs);
              }()
            : e,
    ];
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  /// 删除单条播放历史（不存在时静默）
  Future<void> remove(String path) async {
    await ensureLoaded();
    if (!_entries.any((e) => e.path == path)) return;
    _entries = [
      for (final e in _entries)
        if (e.path != path) e,
    ];
    notifyListeners();
    await _persist();
  }

  /// 一键清空全部播放历史
  Future<void> clearAll() async {
    await ensureLoaded();
    if (_entries.isEmpty) return;
    _entries = const [];
    notifyListeners();
    await _persist();
  }

  /// 关闭/开启播放历史记录（关闭只停新记录，已存历史保留）
  Future<void> setEnabled(bool v) async {
    await ensureLoaded();
    if (_enabled == v) return;
    _enabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, v);
  }

  /// 设置「删除历史时同步清除进度」。
  ///
  /// 只写开关值本身（不连带改 [enabled]）：实际是否生效由
  /// [effectiveClearProgressOnDelete] 裁决，UI 那边会把开关置灰提示。
  Future<void> setClearProgressOnDelete(bool v) async {
    await ensureLoaded();
    if (_clearProgressOnDelete == v) return;
    _clearProgressOnDelete = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClearProgressOnDelete, v);
  }

  Future<void> _persist() async {
    // P2-40：并发落盘顺序不定会让磁盘上留着**较早**的快照（record/remove/clearAll
    // 可能被几乎同时触发）。对齐 `PlaybackProgressService._persist` 的 §4.29 写法：
    // ① 快照在**调用时同步生成**（等到排队执行再编码就晚了）；
    // ② 写入走 [AsyncSerialQueue] 串行，按提交顺序落盘、异常不打断后续写入；
    // ③ 任务的错误必须在这里接收——`AsyncSerialQueue.add` 把异常交给返回的 Future，
    //    丢弃它等于未处理异步错误 + 写盘失败静默（§4.29/P1-34 同一个坑）。
    final snapshot = jsonEncode([for (final e in _entries) e.toJson()]);
    unawaited(
      _writeQueue
          .add(() async {
            final prefs = await SharedPreferences.getInstance();
            // await 掉 bool 返回值：让任务类型是 Future<void>，与 catchError 的
            // 处理器签名一致（同 PlaybackProgressService 的写法）
            await prefs.setString(_keyEntries, snapshot);
          })
          .catchError((Object error, StackTrace stack) {
            debugPrint('PlaybackHistoryService: 播放历史写盘失败：$error');
          }),
    );
    await _writeQueue.idle;
  }

  /// 等待在途的历史写盘完成（P2-40 的串行队列排空）。
  ///
  /// 用途：退出前落盘、以及**测试**里「触发 UI 动作后断言磁盘内容」——widget 测试的
  /// `pumpAndSettle` 只保证帧与定时器排空，不保证这条 microtask 链跑完，直接读
  /// SharedPreferences 会看到上一份快照。
  Future<void> flushPendingWrites() => _writeQueue.idle;

  /// 防御性解码：损坏 JSON / 非法条目一律丢弃，可继续写入新数据
  List<PlaybackHistoryEntry> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = <PlaybackHistoryEntry>[];
      for (final item in decoded) {
        final e = PlaybackHistoryEntry.fromJson(item);
        if (e != null) entries.add(e);
      }
      // 落盘本就按新→旧写；异常顺序读入时按时间戳重排兜底
      entries.sort((a, b) => b.playedAtMs.compareTo(a.playedAtMs));
      if (entries.length > maxEntries) {
        entries.removeRange(maxEntries, entries.length);
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }
}
