import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';

void main() {
  test('NetworkProtocol.tryParse 已知值解析', () {
    expect(NetworkProtocol.tryParse('webdav'), NetworkProtocol.webdav);
    expect(NetworkProtocol.tryParse('smb'), NetworkProtocol.smb);
    expect(NetworkProtocol.tryParse('ftp'), NetworkProtocol.ftp);
    expect(NetworkProtocol.tryParse('nfs'), isNull);
    expect(NetworkProtocol.tryParse(''), isNull);
  });

  test('NetworkProtocol 默认端口', () {
    expect(NetworkProtocol.smb.defaultPort, 445);
    expect(NetworkProtocol.ftp.defaultPort, 21);
    expect(NetworkProtocol.webdav.defaultPort, 80);
  });

  group('默认端口按 scheme 区分（WebDAV 的 HTTPS 是 443，不是 80）', () {
    test('webdav：http → 80，https → 443', () {
      expect(NetworkProtocol.webdav.defaultPortFor(), 80);
      expect(NetworkProtocol.webdav.defaultPortFor(useHttps: true), 443);
      expect(NetworkProtocol.webdav.secureDefaultPort, 443);
    });

    test('smb / ftp 无加密变体：两者相同', () {
      expect(NetworkProtocol.smb.defaultPortFor(useHttps: true), 445);
      expect(NetworkProtocol.ftp.defaultPortFor(useHttps: true), 21);
    });

    test('切换 HTTPS：默认 80 跟随成 443', () {
      expect(
        resolvePortOnChange(
          currentText: '80',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
        ),
        '443',
      );
      // 反向同样跟随
      expect(
        resolvePortOnChange(
          currentText: '443',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: true,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: false,
        ),
        '80',
      );
    });

    test('切换协议：默认端口跟随（SMB 445 → FTP 21）', () {
      expect(
        resolvePortOnChange(
          currentText: '445',
          previousProtocol: NetworkProtocol.smb,
          previousHttps: false,
          nextProtocol: NetworkProtocol.ftp,
          nextHttps: false,
        ),
        '21',
      );
      expect(
        resolvePortOnChange(
          currentText: '80',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
        ),
        '443',
      );
    });

    test('用户手改过的端口一律保留（群晖 5005/5006、自定义 8080）', () {
      expect(
        resolvePortOnChange(
          currentText: '5005',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
        ),
        '5005',
      );
      expect(
        resolvePortOnChange(
          currentText: '5005',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
          touched: true,
        ),
        '5005',
      );
    });

    test('端口为空 / 非法 → 直接给新默认值', () {
      expect(
        resolvePortOnChange(
          currentText: '',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
        ),
        '443',
      );
      expect(
        resolvePortOnChange(
          currentText: 'abc',
          previousProtocol: NetworkProtocol.webdav,
          previousHttps: false,
          nextProtocol: NetworkProtocol.webdav,
          nextHttps: true,
        ),
        '443',
      );
    });
  });

  test('NetworkConnection JSON 往返', () {
    const c = NetworkConnection(
      id: 3,
      name: '家庭 NAS',
      protocol: NetworkProtocol.webdav,
      host: 'nas.local',
      port: 5005,
      username: 'bob',
      password: 'secret',
      path: '/movies',
      isAnonymous: false,
      useHttps: true,
    );
    final restored = NetworkConnection.fromJson(c.toJson());
    expect(restored.id, 3);
    expect(restored.name, '家庭 NAS');
    expect(restored.protocol, NetworkProtocol.webdav);
    expect(restored.host, 'nas.local');
    expect(restored.port, 5005);
    expect(restored.username, 'bob');
    expect(restored.password, 'secret');
    expect(restored.path, '/movies');
    expect(restored.isAnonymous, isFalse);
    expect(restored.useHttps, isTrue);
  });

  test('NetworkConnection.fromJson 字段缺失容错', () {
    final c = NetworkConnection.fromJson(const {});
    expect(c.id, 0);
    expect(c.name, '未命名');
    expect(c.protocol, NetworkProtocol.webdav);
    expect(c.host, '');
    expect(c.port, NetworkProtocol.webdav.defaultPort);
    expect(c.path, '/');
  });

  test('copyWith 局部覆盖', () {
    const c = NetworkConnection(name: 'a', protocol: NetworkProtocol.ftp, host: 'h', port: 21);
    final c2 = c.copyWith(name: 'b', id: 9);
    expect(c2.name, 'b');
    expect(c2.id, 9);
    expect(c2.host, 'h');
    expect(c2.protocol, NetworkProtocol.ftp);
  });

  test('toString 不泄露凭据', () {
    const c = NetworkConnection(
      name: 'a',
      protocol: NetworkProtocol.ftp,
      host: 'h',
      port: 21,
      password: 'topsecret',
    );
    expect(c.toString(), isNot(contains('topsecret')));
    expect(c.toString(), contains('credentials=<redacted>'));
  });

  test('toJson(includePassword: false) 不写密码字段', () {
    const c = NetworkConnection(
      name: 'a',
      protocol: NetworkProtocol.smb,
      host: 'h',
      port: 445,
      password: 'topsecret',
    );
    expect(c.toJson(includePassword: false).containsKey('password'), isFalse);
    expect(c.toJson().containsKey('password'), isTrue);
    // 其余字段一个不少（否则恢复出来的连接会缺字段）
    expect(
      c.toJson(includePassword: false).keys.toSet(),
      c.toJson().keys.toSet().difference({'password'}),
    );
  });
}