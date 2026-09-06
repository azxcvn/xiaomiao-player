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
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moumou/models/playback_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackHistoryService extends ChangeNotifier {
  /// App 全局单例（测试构造独立实例共享同一持久化 key，同 DanmakuManualMemory）
  static final PlaybackHistoryService instance = PlaybackHistoryService();

  PlaybackHistoryService();

  /// 加载去重（risk_audit #9 同款防护）：setter 先 await [ensureLoaded]，
  /// 防启动 load 未完成时用户改动被覆盖。
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyEntries = 'playback_history_entries';
  static const _keyEnabled = 'playback_history_enabled';

  /// 历史条目上限（超过淘汰最旧；对齐 mpvRx 最近播放为有界列表的思路）
  static const int maxEntries = 500;

  bool _enabled = true;
  List<PlaybackHistoryEntry> _entries = const [];

  bool get enabled => _enabled;

  /// 历史条目（新 → 旧；unmodifiable 防外部直接改）
  List<PlaybackHistoryEntry> get entries => List.unmodifiable(_entries);

  /// 最近一次播放的条目（无历史返回 null）
  PlaybackHistoryEntry? get mostRecent =>
      _entries.isEmpty ? null : _entries.first;

  /// 启动时加载（main.dart 调用）
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    _entries = _decode(prefs.getString(_keyEntries));
    notifyListeners();
  }

  /// 测试用：重置内存态（下一次 ensureLoaded 重新读盘），不落盘
  @visibleForTesting
  void debugReset() {
    _loadFuture = null;
    _entries = const [];
    _enabled = true;
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
    final keptDuration =
        durationMs > 0 ? durationMs : (old?.durationMs ?? 0);
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
    _entries = [for (final e in _entries) if (e.path != path) e];
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyEntries,
      jsonEncode([for (final e in _entries) e.toJson()]),
    );
  }

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
