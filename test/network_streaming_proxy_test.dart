import 'dart:io';

import 'package:flutter_test/flutter_test.dart';import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/network/network_streaming_proxy.dart';

/// 测试用假客户端：从内存字节数组提供流，模拟 GET / HEAD / Range 读取。
class _FakeClient implements NetworkClient {
  final List<int> data;
  bool _connected = false;

  _FakeClient(this.data);

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  bool isConnected() => _connected;

  @override
  Future<List<NetworkFile>> listFiles(String path) async => [];

  @override
  Future<int> getFileSize(String path) async => data.length;

  @override
  Future<Stream<List<int>>> openStream(String path, {int offset = 0}) async {
    return Stream.value(data.sublist(offset));
  }
}

/// 记录「问远端文件大小」次数，用于验证代理的按路径缓存是否命中。
class _CountingClient implements NetworkClient {
  final List<int> data;
  int sizeQueries = 0;
  bool _connected = false;

  _CountingClient(this.data);

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  bool isConnected() => _connected;

  @override
  Future<List<NetworkFile>> listFiles(String path) async => [];

  @override
  Future<int> getFileSize(String path) async {
    sizeQueries++;
    return data.length;
  }

  @override
  Future<Stream<List<int>>> openStream(String path, {int offset = 0}) async {
    return Stream.value(data.sublist(offset));
  }
}

const _connection = NetworkConnection(
  name: 'test',
  protocol: NetworkProtocol.webdav,
  host: '127.0.0.1',
  port: 80,
);

Future<List<int>> _readBody(HttpClientResponse res) async {
  final bytes = <int>[];
  await for (final chunk in res) {
    bytes.addAll(chunk);
  }
  return bytes;
}

void main() {
  final bytes = List<int>.generate(2048, (i) => i % 256);

  late NetworkStreamingProxy proxy;
  late HttpClient http;

  setUp(() {
    proxy = NetworkStreamingProxy(clientFactory: (_) => _FakeClient(bytes));
    http = HttpClient();
  });

  tearDown(() async {
    await proxy.stop();
    http.close();
  });

  test('registerStream 返回无凭据 loopback URL', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    final uri = Uri.parse(url);
    expect(uri.scheme, 'http');
    expect(uri.host, '127.0.0.1');
    expect(uri.userInfo, isEmpty);
    expect(url, isNot(contains('@')));
  });

  test('GET 返回完整字节', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    final req = await http.getUrl(Uri.parse(url));
    final res = await req.close();
    expect(res.statusCode, HttpStatus.ok);
    expect(res.headers.value('accept-ranges'), 'bytes');
    expect(await _readBody(res), bytes);
  });

  test('HEAD 返回 Content-Length 且无正文', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    final req = await http.openUrl('HEAD', Uri.parse(url));
    final res = await req.close();
    expect(res.statusCode, HttpStatus.ok);
    expect(res.headers.value('accept-ranges'), 'bytes');
    expect(res.contentLength, bytes.length);
    expect(await _readBody(res), isEmpty);
  });

  test('Range 请求返回分段内容', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    final req = await http.getUrl(Uri.parse(url));
    req.headers.set('range', 'bytes=100-199');
    final res = await req.close();
    expect(res.statusCode, HttpStatus.partialContent);
    expect(res.headers.value('content-range'), 'bytes 100-199/2048');
    expect(await _readBody(res), bytes.sublist(100, 200));
  });

  test('unregister 后再次请求 404', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    await proxy.unregisterStream(url);
    final req = await http.getUrl(Uri.parse(url));
    final res = await req.close();
    expect(res.statusCode, HttpStatus.notFound);
    await res.drain<void>();
  });

  test('未知 stream 返回 404', () async {
    final url = await proxy.registerStream(
      _connection,
      '/video.mp4',
      fileSize: bytes.length,
    );
    final uri = Uri.parse(url);
    final bad = uri.replace(path: '/nonexistent-token/x');
    final req = await http.getUrl(bad);
    final res = await req.close();
    expect(res.statusCode, HttpStatus.notFound);
    await res.drain<void>();
  });

  group('按路径缓存（NetworkPath 值相等）', () {
    test('registerStream 传入的 fileSize 生效 → 不再问远端大小', () async {
      final client = _CountingClient(bytes);
      final p = NetworkStreamingProxy(clientFactory: (_) => client);
      addTearDown(p.stop);
      final url = await p.registerStream(
        _connection,
        '/video.mp4',
        fileSize: bytes.length,
      );
      final req = await http.getUrl(Uri.parse(url));
      final res = await req.close();
      expect(res.statusCode, HttpStatus.ok);
      expect(await _readBody(res), bytes);
      expect(client.sizeQueries, 0);
    });

    test('registerStream 传入的 mimeType 生效（主路径）', () async {
      final p = NetworkStreamingProxy(
        clientFactory: (_) => _CountingClient(bytes),
      );
      addTearDown(p.stop);
      final url = await p.registerStream(
        _connection,
        '/video.unknown-ext',
        fileSize: bytes.length,
        mimeType: 'video/x-matroska',
      );
      final req = await http.getUrl(Uri.parse(url));
      final res = await req.close();
      expect(res.headers.contentType?.mimeType, 'video/x-matroska');
      await res.drain<void>();
    });
  });

  test('并发注册共用一次 bind（不会 bind 出两个 HttpServer，P2-23）', () async {
    final p = NetworkStreamingProxy(clientFactory: (_) => _FakeClient(bytes));
    addTearDown(p.stop);
    final urls = await Future.wait([
      p.registerStream(_connection, '/a.mp4', fileSize: bytes.length),
      p.registerStream(_connection, '/b.mp4', fileSize: bytes.length),
      p.registerStream(_connection, '/c.mp4', fileSize: bytes.length),
    ]);
    final ports = urls.map((u) => Uri.parse(u).port).toSet();
    expect(ports.length, 1, reason: '三个并发注册必须共用同一个回环服务端');
  });

  test('复用到的死连接失败后自动重连一次（P2-20）', () async {
    var created = 0;
    // 先注册（不带 fileSize）→ 首次请求会建连；建出的第一个客户端 openStream 必失败
    final p = NetworkStreamingProxy(clientFactory: (_) {
      created++;
      return _FlakyClient(bytes, failOpenStream: created == 1);
    });
    addTearDown(p.stop);
    final url = await p.registerStream(_connection, '/video.mp4');

    final req = await http.getUrl(Uri.parse(url));
    final res = await req.close();
    expect(res.statusCode, HttpStatus.ok);
    expect(await _readBody(res), bytes);
    expect(created, 2, reason: '死连接要丢弃后重连一次，而不是把失败直接甩给 mpv');
  });
}

/// 第一次 `openStream` 抛错（模拟「连接还在，但真要读的时候已经断了」）。
class _FlakyClient implements NetworkClient {
  _FlakyClient(this.data, {this.failOpenStream = false});

  final List<int> data;
  final bool failOpenStream;
  bool _connected = false;

  @override
  Future<void> connect() async => _connected = true;

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  bool isConnected() => _connected;

  @override
  Future<List<NetworkFile>> listFiles(String path) async => [];

  @override
  Future<int> getFileSize(String path) async => data.length;

  @override
  Future<Stream<List<int>>> openStream(String path, {int offset = 0}) async {
    if (failOpenStream) throw const SocketException('connection reset');
    return Stream.value(data.sublist(offset));
  }
}