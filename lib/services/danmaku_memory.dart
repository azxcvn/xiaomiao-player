/// 弹幕手动导入记忆存储：按视频路径记忆最近一次手动选择的弹幕文件，
/// 重启播放器/重启软件后自动恢复加载，无需重新选择（工作.md 弹幕阶段1
/// 用户反馈：手动导入的弹幕不被记忆）。
///
/// - 存储：SharedPreferences 单键 JSON（`{视频路径: 弹幕文件路径}`），
///   进程内缓存避免每次读取反序列化；
/// - 优先级：记忆的手动导入 **优先于** 同名自动查找（用户显式选择不被
///   覆盖，对齐字幕外挂记忆语义）；同名自动加载（9 种命名规则）的结果
///   不写入记忆（确定性查找，无需记忆）；
/// - 失效处理：记忆的弹幕文件被删除/不可读时由调用方清除该条记忆并
///   回落同名查找；
/// - 自动加载 toast 去重：另存「已提示过」的视频路径集合（独立键），
///   使「已自动加载弹幕」提示只在每个视频**第一次**自动加载时出现，
///   重启播放器/软件后不再重复。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

class DanmakuManualMemory {
  DanmakuManualMemory();

  static const _key = 'danmaku_manual_memory';
  static const _toastedKey = 'danmaku_auto_toasted';

  /// 记忆条数上限：超出后**淘汰最久未用**（见 [get] / [set]）。
  ///
  /// 无上限时「每看一个新视频就多一条」，配合每次全量 `jsonEncode` 写盘会
  /// 越用越慢（体检报告 §3-14；用户拍板 2026-09：弹幕 200 条）。
  static const maxEntries = 200;

  Map<String, String>? _cache;
  Set<String>? _toastedCache;

  /// 读取全量映射（进程内缓存；首次读 SharedPreferences）
  Future<Map<String, String>> _map() async {
    final cached = _cache;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _cache = _decode(prefs.getString(_key));
    return _cache!;
  }

  /// 防御性解码：损坏数据 / 非字符串值一律丢弃，不抛异常
  Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
        };
      }
    } catch (_) {
      // 损坏的 JSON 视为无记忆
    }
    return {};
  }

  /// 该视频记忆的手动弹幕文件路径（无记忆返回 null）。
  ///
  /// 命中即把该键移到 Map 末尾（Dart Map 保序）→ 后续 [set] 淘汰时它不会
  /// 被当作「最久未用」；纯内存操作，不额外写盘。
  Future<String?> get(String videoPath) async {
    final map = await _map();
    final value = map.remove(videoPath);
    if (value == null) return null;
    map[videoPath] = value;
    return value;
  }

  /// 记录/覆盖该视频的手动弹幕文件（超上限时淘汰最久未用的若干条）。
  Future<void> set(String videoPath, String danmakuPath) async {
    final map = await _map();
    map.remove(videoPath);
    map[videoPath] = danmakuPath;
    trimToLimit(map, maxEntries);
    await _persist(map);
  }

  /// 把映射裁剪到 [limit] 条（淘汰 Map 头部 = 最久未用/最早写入的那些）。
  @visibleForTesting
  static void trimToLimit(Map<String, String> map, int limit) {
    if (limit <= 0) {
      map.clear();
      return;
    }
    while (map.length > limit) {
      map.remove(map.keys.first);
    }
  }

  /// 清除该视频的记忆（记忆的弹幕文件失效场景）
  Future<void> remove(String videoPath) async {
    final map = await _map();
    if (!map.containsKey(videoPath)) return;
    map.remove(videoPath);
    await _persist(map);
  }

  Future<void> _persist(Map<String, String> map) async {
    _cache = map;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
  }

  // ── 自动加载 toast 去重（视频路径集合，独立键持久化）──

  Future<Set<String>> _toastedSet() async {
    final cached = _toastedCache;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _toastedCache = _decodeList(prefs.getString(_toastedKey));
    return _toastedCache!;
  }

  Set<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return {for (final e in decoded) if (e is String) e};
      }
    } catch (_) {
      // 损坏的 JSON 视为无记录
    }
    return {};
  }

  /// 该视频是否已提示过「已自动加载弹幕」（true = 不再提示）
  Future<bool> hasShownAutoLoadToast(String videoPath) async =>
      (await _toastedSet()).contains(videoPath);

  /// 记录该视频已提示过（幂等；无记录才写盘）
  Future<void> markAutoLoadToastShown(String videoPath) async {
    final set = await _toastedSet();
    if (set.contains(videoPath)) return;
    set.add(videoPath);
    _toastedCache = set;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_toastedKey, jsonEncode(set.toList()));
  }
}
