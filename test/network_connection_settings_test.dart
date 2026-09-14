import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/services/network/network_connection_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 内存版密码存储；[failWrites] = true 时模拟 Keystore 不可用。
class _MemoryPasswordStore implements NetworkPasswordStore {
  final Map<int, String> values = {};
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<String?> read(int connectionId) async {
    if (failReads) throw StateError('keystore unavailable');
    return values[connectionId];
  }

  @override
  Future<void> write(int connectionId, String password) async {
    if (failWrites) throw StateError('keystore unavailable');
    values[connectionId] = password;
  }

  @override
  Future<void> delete(int connectionId) async {
    values.remove(connectionId);
  }
}

Future<String> _rawPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList('network_connections') ?? []).join('\n');
}

void main() {
  late _MemoryPasswordStore passwords;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    passwords = _MemoryPasswordStore();
    NetworkConnectionSettings.instance.reset();
    NetworkConnectionSettings.instance.usePasswordStoreForTest(passwords);
  });

  test('初始为空', () {
    expect(NetworkConnectionSettings.instance.connections, isEmpty);
  });

  test('add 分配自增 id 并持久化', () async {
    final s = NetworkConnectionSettings.instance;
    final a = await s.add(const NetworkConnection(
      name: 'NAS',
      protocol: NetworkProtocol.webdav,
      host: '192.168.1.2',
      port: 5005,
    ));
    final b = await s.add(const NetworkConnection(
      name: 'FTP',
      protocol: NetworkProtocol.ftp,
      host: 'ftp.example.com',
      port: 21,
    ));
    expect(a.id, 1);
    expect(b.id, 2);
    expect(s.connections.length, 2);

    // 模拟重启：reset 清内存，load 从 prefs 恢复
    s.reset();
    s.usePasswordStoreForTest(passwords);
    await s.load();
    expect(s.connections.length, 2);
    expect(s.connections.map((c) => c.name), containsAll(['NAS', 'FTP']));
  });

  test('update 按 id 替换', () async {
    final s = NetworkConnectionSettings.instance;
    final a = await s.add(const NetworkConnection(
      name: 'NAS',
      protocol: NetworkProtocol.smb,
      host: 'h',
      port: 445,
    ));
    await s.update(a.copyWith(name: 'NAS2', port: 9000));
    expect(s.connections.single.name, 'NAS2');
    expect(s.connections.single.port, 9000);
  });

  test('remove 按 id 删除', () async {
    final s = NetworkConnectionSettings.instance;
    final a = await s.add(const NetworkConnection(
      name: 'NAS',
      protocol: NetworkProtocol.webdav,
      host: 'h',
      port: 80,
    ));
    final b = await s.add(const NetworkConnection(
      name: 'FTP',
      protocol: NetworkProtocol.ftp,
      host: 'h',
      port: 21,
    ));
    await s.remove(a.id);
    expect(s.connections.single.id, b.id);

    s.reset();
    s.usePasswordStoreForTest(passwords);
    await s.load();
    expect(s.connections.single.id, b.id);
  });

  test('byId 查找', () async {
    final s = NetworkConnectionSettings.instance;
    final a = await s.add(const NetworkConnection(
      name: 'NAS',
      protocol: NetworkProtocol.webdav,
      host: 'h',
      port: 80,
    ));
    expect(s.byId(a.id)?.name, 'NAS');
    expect(s.byId(999), isNull);
  });

  test('损坏单条 JSON 不拖垮整个列表', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('network_connections', [
      'not-json',
      '{"name":"ok","protocol":"ftp","host":"h","port":21}',
    ]);
    await NetworkConnectionSettings.instance.load();
    final s = NetworkConnectionSettings.instance;
    expect(s.connections.length, 1);
    expect(s.connections.single.name, 'ok');
  });

  group('密码加密存储（P2-17 / D4）', () {
    test('密码进加密存储，SharedPreferences 里没有明文', () async {
      final s = NetworkConnectionSettings.instance;
      final c = await s.add(const NetworkConnection(
        name: 'NAS',
        protocol: NetworkProtocol.smb,
        host: 'h',
        port: 445,
        username: 'bob',
        password: 'topsecret',
      ));

      expect(passwords.values[c.id], 'topsecret');
      final raw = await _rawPrefs();
      expect(raw, isNot(contains('topsecret')));
      expect(raw, isNot(contains('"password"')));
    });

    test('重启后密码从加密存储恢复', () async {
      final s = NetworkConnectionSettings.instance;
      await s.add(const NetworkConnection(
        name: 'NAS',
        protocol: NetworkProtocol.smb,
        host: 'h',
        port: 445,
        password: 'topsecret',
      ));
      s.reset();
      s.usePasswordStoreForTest(passwords);
      await s.load();
      expect(s.connections.single.password, 'topsecret');
    });

    test('老明文密码迁移：加密写回 + 清单去掉明文', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('network_connections', [
        jsonEncode(const NetworkConnection(
          id: 7,
          name: '老 NAS',
          protocol: NetworkProtocol.smb,
          host: 'h',
          port: 445,
          password: 'legacy-secret',
        ).toJson()),
      ]);

      final s = NetworkConnectionSettings.instance;
      await s.load();
      expect(s.connections.single.password, 'legacy-secret');
      expect(passwords.values[7], 'legacy-secret', reason: '已加密写回');
      final raw = await _rawPrefs();
      expect(raw, isNot(contains('legacy-secret')), reason: '明文已清除');
    });

    test('加密不可用时迁移失败回退：密码不丢，明文保留', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('network_connections', [
        jsonEncode(const NetworkConnection(
          id: 7,
          name: '老 NAS',
          protocol: NetworkProtocol.smb,
          host: 'h',
          port: 445,
          password: 'legacy-secret',
        ).toJson()),
      ]);
      passwords.failWrites = true;

      final s = NetworkConnectionSettings.instance;
      await s.load();
      expect(s.connections.single.password, 'legacy-secret', reason: '不能丢密码');
      expect(passwords.values, isEmpty);
      final raw = await _rawPrefs();
      expect(raw, contains('legacy-secret'), reason: '迁移失败 → 明文原样保留');
    });

    test('update 覆盖密码；remove 清掉加密项', () async {
      final s = NetworkConnectionSettings.instance;
      final c = await s.add(const NetworkConnection(
        name: 'NAS',
        protocol: NetworkProtocol.ftp,
        host: 'h',
        port: 21,
        password: 'p1',
      ));
      await s.update(c.copyWith(password: 'p2'));
      expect(passwords.values[c.id], 'p2');
      expect((await _rawPrefs()), isNot(contains('"password"')));

      await s.remove(c.id);
      expect(passwords.values, isEmpty);
    });
  });
}
