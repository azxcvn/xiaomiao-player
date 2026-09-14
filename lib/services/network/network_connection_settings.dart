/// 网络存储连接（账号）配置清单：单例 ChangeNotifier + SharedPreferences 持久化，
/// 与现有 MediaScanSettings 等配置服务保持同构。
///
/// **密码只进加密存储**（`flutter_secure_storage`，Android 走
/// EncryptedSharedPreferences / Keystore），SharedPreferences 里只留
/// 「连接元数据」JSON、**不含 password 字段**——与 B 站凭据同一套方案
/// （§4.11；`docs/ARCHITECTURE.md` §4.11 的「密码加密」承诺）。
///
/// **老版本明文迁移**：`load()` 若在某条连接的 JSON 里读到 `password`（旧格式），
/// 把它加密写回 secure storage、随后重写清单去掉明文；**加密失败则不迁移**，
/// 明文原样留着（宁可暂时明文，也不能让用户的密码凭空消失）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 密码存储抽象：解耦 flutter_secure_storage，便于测试注入内存实现。
abstract class NetworkPasswordStore {
  Future<String?> read(int connectionId);
  Future<void> write(int connectionId, String password);
  Future<void> delete(int connectionId);
}

/// 生产实现：flutter_secure_storage（Android 走 EncryptedSharedPreferences/Keystore）。
class FlutterNetworkPasswordStore implements NetworkPasswordStore {
  const FlutterNetworkPasswordStore();

  static const _storage = FlutterSecureStorage();

  static String _key(int connectionId) => 'network_password_$connectionId';

  @override
  Future<String?> read(int connectionId) =>
      _storage.read(key: _key(connectionId));

  @override
  Future<void> write(int connectionId, String password) =>
      _storage.write(key: _key(connectionId), value: password);

  @override
  Future<void> delete(int connectionId) =>
      _storage.delete(key: _key(connectionId));
}

class NetworkConnectionSettings extends ChangeNotifier {
  NetworkConnectionSettings._();

  static final NetworkConnectionSettings instance = NetworkConnectionSettings._();

  static const _key = 'network_connections';

  NetworkPasswordStore _passwords = const FlutterNetworkPasswordStore();

  /// 加密存储写失败的连接 id：这些连接退回明文存储，绝不丢密码。
  final Set<int> _plaintextFallback = <int>{};

  Future<void>? _loadFuture;
  List<NetworkConnection> _connections = [];
  int _nextId = 1;

  /// 只读连接列表（不含可变视图）。
  List<NetworkConnection> get connections => List.unmodifiable(_connections);

  /// 测试用：注入内存密码存储（生产恒为 Keystore 实现）。
  @visibleForTesting
  void usePasswordStoreForTest(NetworkPasswordStore store) => _passwords = store;

  NetworkConnection? byId(int id) {
    for (final c in _connections) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final list = <NetworkConnection>[];
    var maxId = 0;
    var migrated = false;
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is! Map) continue;
        final json = Map<String, dynamic>.from(decoded);
        final connection = NetworkConnection.fromJson(json);
        if (connection.id > maxId) maxId = connection.id;

        // 旧格式的明文密码（迁移来源）；新格式这里恒为空。
        final legacy = json['password'];
        final legacyPlaintext = legacy is String ? legacy : '';
        final (password, keepPlaintext) =
            await _resolvePassword(connection.id, legacyPlaintext);
        if (keepPlaintext) {
          _plaintextFallback.add(connection.id);
        } else if (legacyPlaintext.isNotEmpty) {
          migrated = true; // 已加密写回 → 可以清掉清单里的明文
        }
        list.add(connection.copyWith(password: password));
      } catch (_) {
        // 单条损坏不拖垮整个列表。
      }
    }
    _connections = list;
    _nextId = maxId + 1;
    if (migrated) await _save();
    notifyListeners();
  }

  /// 取一条连接的密码，顺带完成老明文迁移。
  ///
  /// 返回 `(密码, 是否必须继续明文存储)`——第二个值为 true 表示加密存储不可用，
  /// 调用方要把该 id 记进 [_plaintextFallback]，绝不能顺手清掉明文。
  Future<(String, bool)> _resolvePassword(int id, String legacyPlaintext) async {
    final String stored;
    try {
      stored = await _passwords.read(id) ?? '';
    } catch (error) {
      // 读不出来不能假定「没有密码」：有明文就继续用明文（下次启动再试迁移）。
      debugPrint('[网络存储] 密码读取失败（保持原状）：$error');
      return (legacyPlaintext, legacyPlaintext.isNotEmpty);
    }
    if (stored.isNotEmpty) return (stored, false);
    if (legacyPlaintext.isEmpty) return ('', false);
    final failed = await _storePassword(id, legacyPlaintext);
    return (legacyPlaintext, failed);
  }

  /// 新增一条连接，返回分配好 id 的完整对象。
  Future<NetworkConnection> add(NetworkConnection connection) async {
    await ensureLoaded();
    final withId = connection.copyWith(id: _nextId++);
    await _storePassword(withId.id, withId.password);
    _connections = [..._connections, withId];
    notifyListeners();
    await _save();
    return withId;
  }

  Future<void> update(NetworkConnection connection) async {
    await ensureLoaded();
    await _storePassword(connection.id, connection.password);
    _connections = [
      for (final e in _connections)
        if (e.id == connection.id) connection else e,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> remove(int id) async {
    await ensureLoaded();
    _connections = _connections.where((e) => e.id != id).toList();
    _plaintextFallback.remove(id);
    try {
      await _passwords.delete(id);
    } catch (error) {
      // 删不掉加密项不影响功能（清单里已经没有这条连接了）。
      debugPrint('[网络存储] 密码清除失败：$error');
    }
    notifyListeners();
    await _save();
  }

  /// 把密码写入加密存储；返回是否**失败退回明文**。
  Future<bool> _storePassword(int id, String password) async {
    try {
      if (password.isEmpty) {
        await _passwords.delete(id);
      } else {
        await _passwords.write(id, password);
      }
      _plaintextFallback.remove(id);
      return false;
    } catch (error) {
      debugPrint('[网络存储] 密码加密写入失败，退回明文存储：$error');
      _plaintextFallback.add(id);
      return true;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      // 密码只有在加密写入失败时才落明文（否则连字段都不写）
      _connections
          .map((c) => jsonEncode(
                c.toJson(includePassword: _plaintextFallback.contains(c.id)),
              ))
          .toList(),
    );
  }

  /// 测试用：重置状态。
  @visibleForTesting
  void reset() {
    _loadFuture = null;
    _connections = [];
    _nextId = 1;
    _plaintextFallback.clear();
    notifyListeners();
  }
}
