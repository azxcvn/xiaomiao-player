import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moumou/utils/async_serial_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放进度服务：记录每个视频上次播放到的位置（可监听，进度变化自动通知）
class PlaybackProgressService extends ChangeNotifier {
  static const _key = 'playback_progress';
  static final PlaybackProgressService instance = PlaybackProgressService._();

  PlaybackProgressService._();

  Map<String, int> _cache = {};
  bool _loaded = false;
  Future<void>? _loadFuture;

  /// 写入串行队列（[AsyncSerialQueue]，§4.29）：保证多次 save 的 prefs 写入
  /// 按调用顺序落盘，避免异步写入乱序导致「最后一次保存」被旧快照覆盖
  /// （工作.md 第 9 点：快速退出/进入循环 + 重启后恢复百分比失效的根因之一）。
  final AsyncSerialQueue _writeQueue = AsyncSerialQueue();

  /// 节流（risk_audit #3）：同一视频 [persistInterval] 内只落盘一次，
  /// 内存缓存照常每次更新——避免每次退出/切集都整表 jsonEncode + 全量写盘。
  /// 视频库几千条后单次序列化可达数 MB，节流后写盘频率降到可接受范围。
  static const Duration _persistInterval = Duration(seconds: 30);

  /// 每个 path 最近一次落盘时间（节流判定用）
  final Map<String, DateTime> _lastPersistedAt = {};

  /// 确保已从磁盘加载（首次 get/save 前调用；main.dart 的 load 为异步，
  /// 播放页可能在加载完成前就读进度——必须等待，否则读到空缓存不恢复）。
  Future<void> ensureLoaded() => _loadFuture ??= load();

  /// 同步读取进度（调用前需先 await [ensureLoaded]；未加载时返回 null）
  Duration? getProgress(String path) {
    if (!_loaded) return null;
    final ms = _cache[path];
    return ms != null ? Duration(milliseconds: ms) : null;
  }

  /// 启动时加载全部进度。
  ///
  /// ⚠️ 竞态修复（用户反馈「重启后恢复不了」的根因）：必须在**读盘完成之后**
  /// 才置 [_loaded] = true。旧实现先置位再 await 读盘——main.dart 调 [load] 后
  /// 播放页调 [ensureLoaded]（`_loadFuture ??= load()`）会再走一次 [load]，
  /// 此时 [_loaded] 已是 true 直接返回空缓存，恢复逻辑读到 null 不恢复。
  ///
  /// ⚠️ 防御（P1-33）：读盘/解码失败**必须**回落空表并照常置 [_loaded]。
  /// 若放任 [load] 抛错，[ensureLoaded] 缓存的就是一个 **rejected Future** ——
  /// 此后每次 `ensureLoaded` 立即失败、[_loaded] 恒 false，本次进程内的
  /// **进度恢复与保存全部失效**（对照 `PlaybackHistoryService._decode` 的防御）。
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = _decode(prefs.getString(_key));
    } catch (_) {
      _cache = {};
    } finally {
      _loaded = true; // 读盘完成（或失败回落）后再置位
      notifyListeners();
    }
  }

  /// 防御性解码：坏 JSON / 非数值条目一律丢弃，可继续写入新数据
  Map<String, int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      decoded.forEach((key, value) {
        final int? ms = switch (value) {
          final int v => v,
          final num v => v.toInt(),
          _ => int.tryParse('$value'),
        };
        if (ms != null) out['$key'] = ms;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  /// 保存进度并通知监听者。
  ///
  /// 可靠性（工作.md 第 9 点）：
  /// - 先 await [ensureLoaded]，防止 load() 的 `_cache = ...` 覆盖掉
  ///   刚写入内存的新进度（重启后快速进出的竞态）；
  /// - 写入走 [_writeChain] 串行化，快照在调用时同步生成，
  ///   保证磁盘上的最终内容 = 最后一次调用时的完整缓存。
  ///
  /// 节流（risk_audit #3）：同一 path 在 [_persistInterval] 内重复保存
  /// 只更新内存，不重复整表写盘（用户连续退出/切集同一视频时收益最大；
  /// 退出/切集时内存进度仍是最新的，进程正常存活不受影响）。
  /// [forcePersist] = true 时跳过节流强制落盘（退出播放/切集时调用，
  /// 保证重启后磁盘上一定是最新进度，用户反馈「重启后恢复不了」的修复）。
  Future<void> save(String path, Duration position,
      {bool forcePersist = false}) async {
    await ensureLoaded();
    _cache[path] = position.inMilliseconds;
    notifyListeners();
    final last = _lastPersistedAt[path];
    final now = DateTime.now();
    if (!forcePersist &&
        last != null &&
        now.difference(last) < _persistInterval) {
      return; // 节流命中：内存已更新，跳过本轮全量写盘
    }
    _lastPersistedAt[path] = now;
    final snapshot = jsonEncode(_cache);
    // 写入走公共串行队列（§4.29）：按提交顺序依次落盘，异常不打断后续写入。
    //
    // ⚠️ 任务的错误**必须在这里接收**（P1-34）：`AsyncSerialQueue.add` 把异常交给
    // 返回的 Future，丢弃它就等于未处理异步错误 + 写盘失败静默（用户以为已保存、
    // 重启丢进度）。[AsyncSerialQueue.idle] 只负责等排空、从不抛错，靠它发现不了失败。
    unawaited(
      _writeQueue
          .add(() async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_key, snapshot);
          })
          .catchError((Object error, StackTrace stack) {
        debugPrint('PlaybackProgressService: 进度写盘失败：$error');
      }),
    );
    await _writeQueue.idle;
  }
}
