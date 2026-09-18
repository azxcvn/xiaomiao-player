/// 网络存储目录列表的短时缓存（会话级，不落盘）。
///
/// 为什么需要：远端列目录是**慢操作**（一次往返，SMB 更慢），而浏览页现在有三
/// 处会重复列同一个目录——进目录、返回上级、以及后台的递归视频计数。有缓存后
/// 「返回上级」和「点进子目录」都是瞬时的，递归计数也顺带把结果留给用户点进去。
///
/// 只在内存：远端内容随时可能被别人改动，落盘会让用户看到过期列表。TTL 短
/// （默认 60s），下拉刷新 / 进目录前都可显式作废。
library;

import 'package:moumou/models/network_file.dart';

/// 默认存活时间：超过即视为过期（宁可多列一次，也不展示过期目录）。
const Duration kNetworkDirCacheTtl = Duration(seconds: 60);

/// 最多缓存多少个目录（超出按最久未用淘汰）。
const int kNetworkDirCacheMaxEntries = 60;

class NetworkDirectoryCache {
  NetworkDirectoryCache({
    this.ttl = kNetworkDirCacheTtl,
    this.maxEntries = kNetworkDirCacheMaxEntries,
  });

  final Duration ttl;
  final int maxEntries;

  final Map<String, _CacheEntry> _entries = {};

  /// 取缓存（过期 / 不存在返回 null）。命中即刷新 LRU 位置。
  List<NetworkFile>? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (ttl <= Duration.zero) return null; // 零/负 TTL = 不缓存
    if (DateTime.now().difference(entry.storedAt) > ttl) return null;
    _entries[key] = entry; // 重新插入 = 最近使用
    return entry.files;
  }

  /// 写入缓存（[files] 会被复制一份不可变视图）。
  void put(String key, List<NetworkFile> files) {
    _entries.remove(key);
    _entries[key] = _CacheEntry(
      storedAt: DateTime.now(),
      files: List.unmodifiable(files),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// 作废单个目录（刷新当前目录用）。
  void invalidate(String key) => _entries.remove(key);

  /// 作废某条连接的全部缓存（账户被编辑 / 删除时）。
  void invalidateConnection(String connectionKeyPrefix) {
    _entries.removeWhere((k, _) => k.startsWith(connectionKeyPrefix));
  }

  void clear() => _entries.clear();

  /// 当前缓存条目数（测试用）。
  int get length => _entries.length;
}

class _CacheEntry {
  final DateTime storedAt;
  final List<NetworkFile> files;

  _CacheEntry({required this.storedAt, required this.files});
}
