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

  /// 已判定「已看完」的路径（[markCompleted] 同步登记；见 [save] 的粘性保护）
  ///
  /// **会话内粘性**：EOF 之后退出/切集/dispose 会**连续**来好几次保存（实测
  /// `_exitPlayer` + `dispose` 两次），每次位置都比时长小一点 —— 只拦一次挡不住
  /// 后面那次（B3 真机现象：自动暂停停在末尾后退出，卡片显示 100% 却不是
  /// 「已看完」）。用户从头重看该视频时由 [releaseCompleted] 解除。
  final Set<String> _completed = {};

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
    // 「已看完」粘性保护（B3）：[markCompleted] 已把进度写成时长，此后**任何**
    // 更小的位置都不得覆盖它 —— EOF 之后退出/切集/dispose 会连续来好几次保存
    //（实测 `_exitPlayer` + `dispose` 两次），每次位置都比时长小一点：只拦一次
    // 挡不住后面那次，卡片就会「显示 100% 却不是已看完」，且够格触发恢复
    //（重进直接 EOF 退出）。
    //
    // 解除点：用户从头重看该视频（未恢复进度）时由 [releaseCompleted] 解除，
    // 这次重看留下的中途进度照常写入 —— 不会「看过一次就再也存不住进度」。
    if (_completed.contains(path) &&
        (_cache[path] ?? -1) > position.inMilliseconds) {
      debugPrint(
        'PlaybackProgressService: 保留已看完标记，丢弃本次进度写入 '
        'path=$path pos=${position.inMilliseconds}ms mark=${_cache[path]}ms',
      );
      return;
    }
    _cache[path] = position.inMilliseconds;
    notifyListeners();
    await _persist(path, forcePersist: forcePersist);
  }

  /// 解除「已看完」粘性（用户从头重看该视频时调用）。
  ///
  /// 不解除的话，本次会话内该视频的进度会一直被粘在 100%（重看中途退出也
  /// 存不下来）。调用点：播放页打开/切到某媒体且**未恢复进度**（从头播）时。
  void releaseCompleted(String path) => _completed.remove(path);

  /// 同步标记「已看完」（= 时长），并强制落盘。
  ///
  /// ⚠️ **同步写内存**（不经过 [save] 的异步首行 await）：EOF 处理链上紧接着
  /// 就发生退出/切集的保存，标记与一次性保护必须**立刻**可见，否则会被那一次
  /// 保存覆盖（B3 真机验证：阈值 100% 时卡片显示 100% 却不是「已看完」）。
  /// 强制落盘的理由：已看完是低频关键事件，不能被 30 秒节流吞掉。
  void markCompleted(String path, Duration duration) {
    if (duration <= Duration.zero) return;
    if (!_loaded) {
      // 理论不可达（EOF 必然远晚于启动读盘）：仍补一道，避免 load() 的
      // `_cache = decode(...)` 把刚写的标记抹掉。
      unawaited(ensureLoaded().then((_) => _markCompletedNow(path, duration)));
      return;
    }
    _markCompletedNow(path, duration);
  }

  void _markCompletedNow(String path, Duration duration) {
    final ms = duration.inMilliseconds;
    final existing = _cache[path] ?? 0;
    _cache[path] = ms > existing ? ms : existing;
    _completed.add(path);
    notifyListeners();
    debugPrint(
      'PlaybackProgressService: 已看完 path=$path mark=${_cache[path]}ms',
    );
    unawaited(_persist(path, forcePersist: true));
  }

  /// 落盘（调用方已完成内存更新）：节流 + [AsyncSerialQueue] 串行写。
  Future<void> _persist(String path, {required bool forcePersist}) async {
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

  /// 测试用：把单例恢复成「未加载」状态（对齐 `ChapterSkipSettings.resetForTest`）
  @visibleForTesting
  void resetForTest() {
    _cache = {};
    _loaded = false;
    _loadFuture = null;
    _lastPersistedAt.clear();
    _completed.clear();
  }
}
