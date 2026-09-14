import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/network/webdav_client.dart';

const _multistatus =
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:multistatus xmlns:d="DAV:"></d:multistatus>';

NetworkConnection _connection(int port) => NetworkConnection(
      name: 'fake',
      protocol: NetworkProtocol.webdav,
      host: '127.0.0.1',
      port: port,
    );

/// 服务器忽略 `Range`、对一个 32MB 的正文持续推送，并记录真正推出去的字节数。
///
/// [status] 用于区分两种丢弃点：200（Range 被忽略）与 404（非 2xx 错误响应）。
Future<HttpServer> _startIgnoreRangeServer(
  void Function(int) onSent, {
  int status = 200,
}) async {
  const chunk = 64 * 1024;
  const totalChunks = 512; // 32MB
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var sent = 0;
  server.listen((request) async {
    final response = request.response;
    if (request.method == 'PROPFIND') {
      response.statusCode = 207;
      response.headers.contentType = ContentType.parse('application/xml');
      response.write(_multistatus);
      await response.close();
      return;
    }
    // GET：**忽略 Range**，直接推到整份内容
    response.statusCode = status;
    response.headers.set('Content-Length', '${chunk * totalChunks}');
    try {
      for (var i = 0; i < totalChunks; i++) {
        response.add(List<int>.filled(chunk, 0));
        await response.flush();
        sent += chunk;
        onSent(sent);
      }
      await response.close();
    } catch (_) {
      // 客户端提前断开：正常路径（带上限丢弃）
    }
  });
  return server;
}

void main() {
  test('connect 成功（PROPFIND 2xx 即视为可达）', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 207;
      request.response.write(_multistatus);
      await request.response.close();
    });

    final client = WebDavClient(_connection(server.port));
    await client.connect();
    expect(client.isConnected(), isTrue);
    await client.disconnect();
    expect(client.isConnected(), isFalse);
  });

  test('服务器忽略 Range → 丢弃时带上限，不整文件下载', () async {
    var maxSent = 0;
    final server = await _startIgnoreRangeServer((sent) {
      if (sent > maxSent) maxSent = sent;
    });
    addTearDown(() => server.close(force: true));

    final client = WebDavClient(_connection(server.port));
    await client.connect();
    await expectLater(
      client.openStream('/movie.mp4', offset: 1024),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('忽略了分段请求'),
        ),
      ),
    );
    await client.disconnect();
    // 上限 2MB：允许服务端多推一点，但绝不能是整份 32MB（旧的无上限 drain 会）
    expect(
      maxSent,
      lessThan(8 * 1024 * 1024),
      reason: '丢弃响应体必须带上限（§4.28 / §7）',
    );
  });

  test('非 2xx 的响应体也带上限丢弃', () async {
    var maxSent = 0;
    final server = await _startIgnoreRangeServer(
      (sent) {
        if (sent > maxSent) maxSent = sent;
      },
      status: 404,
    );
    addTearDown(() => server.close(force: true));

    final client = WebDavClient(_connection(server.port));
    await client.connect();
    await expectLater(
      client.openStream('/movie.mp4'),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('HTTP 404'),
        ),
      ),
    );
    await client.disconnect();
    expect(maxSent, lessThan(8 * 1024 * 1024));
  });

  test('分段起点与请求不一致 → 报错而非返回错位的流', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.method == 'PROPFIND') {
        request.response.statusCode = 207;
        request.response.write(_multistatus);
        await request.response.close();
        return;
      }
      request.response.statusCode = 206;
      // 请求的是 offset=1024，服务器却从 4096 开始
      request.response.headers.set('Content-Range', 'bytes 4096-8191/100000');
      request.response.headers.set('Content-Length', '4096');
      request.response.add(List<int>.filled(4096, 0));
      await request.response.close();
    });

    final client = WebDavClient(_connection(server.port));
    await client.connect();
    await expectLater(
      client.openStream('/movie.mp4', offset: 1024),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('分段起点'),
        ),
      ),
    );
    await client.disconnect();
  });

  test('服务器只接受连接不回话 → 12 秒内报超时', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    // 收到请求后什么都不回
    server.listen((request) {});

    final client = WebDavClient(_connection(server.port));
    final started = DateTime.now();
    await expectLater(
      client.connect(),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('超时'),
        ),
      ),
    );
    expect(DateTime.now().difference(started).inSeconds, lessThan(14));
  });

  test('PROPFIND 响应体超上限 → 报「目录过大」且不把整个目录拉下来（P2-21）', () async {
    var sent = 0;
    const chunk = 64 * 1024;
    const totalChunks = 512; // 32MB，远大于 JSON 上限 16MB
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final response = request.response;
      response.statusCode = 207;
      response.headers.contentType = ContentType.parse('application/xml');
      response.headers.set('Content-Length', '${chunk * totalChunks}');
      try {
        for (var i = 0; i < totalChunks; i++) {
          response.add(List<int>.filled(chunk, 0));
          await response.flush();
          sent += chunk;
        }
        await response.close();
      } catch (_) {
        // 客户端按声明长度直接放弃：正常路径
      }
    });

    final client = WebDavClient(_connection(server.port));
    await expectLater(
      client.connect(),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('目录过大'),
        ),
      ),
    );
    expect(sent, 0, reason: '声明就超限时一个字节都不该读');
  });
}
