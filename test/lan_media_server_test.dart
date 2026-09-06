import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/cast/lan_media_server.dart';

void main() {
  test('isSiteLocalIpv4：判定站点本地地址', () {
    expect(isSiteLocalIpv4('192.168.1.5'), isTrue);
    expect(isSiteLocalIpv4('10.0.0.1'), isTrue);
    expect(isSiteLocalIpv4('172.16.0.1'), isTrue);
    expect(isSiteLocalIpv4('172.31.255.255'), isTrue);
    expect(isSiteLocalIpv4('172.32.0.1'), isFalse);
    expect(isSiteLocalIpv4('8.8.8.8'), isFalse);
    expect(isSiteLocalIpv4('127.0.0.1'), isFalse);
    expect(isSiteLocalIpv4('not-an-ip'), isFalse);
  });

  test('expose 返回 LAN URL，全量/Range 拉流正确', () async {
    final dir = await Directory.systemTemp.createTemp('lan_media_server_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/video.mp4');
    final bytes = List<int>.generate(1024, (i) => i % 256);
    await file.writeAsBytes(bytes);

    final server = LanMediaServer(
      bindAddress: InternetAddress.loopbackIPv4,
      lanIpResolver: () async => '127.0.0.1',
    );
    addTearDown(server.stop);

    final url = await server.expose(file.path);
    expect(
      url,
      matches(RegExp(r'^http://127\.0\.0\.1:\d+/[A-Za-z0-9_-]+$')),
    );

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    // 全量请求
    final full = await (await client.getUrl(Uri.parse(url))).close();
    expect(full.statusCode, HttpStatus.ok);
    expect(full.headers.value('accept-ranges'), 'bytes');
    expect(full.headers.value('access-control-allow-origin'), '*');
    final fullBytes = await full.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(fullBytes, bytes);

    // Range 请求
    final rangeReq = await client.getUrl(Uri.parse(url));
    rangeReq.headers.set('Range', 'bytes=100-199');
    final rangeResp = await rangeReq.close();
    expect(rangeResp.statusCode, HttpStatus.partialContent);
    expect(rangeResp.headers.value('content-range'), 'bytes 100-199/1024');
    final rangeBytes =
        await rangeResp.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(rangeBytes, bytes.sublist(100, 200));
  });

  test('错误 token 返回 404 / stop 释放端口 / 文件不存在抛错', () async {
    final dir = await Directory.systemTemp.createTemp('lan_media_server_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v.mp4');
    await file.writeAsBytes([1, 2, 3]);

    final server = LanMediaServer(
      bindAddress: InternetAddress.loopbackIPv4,
      lanIpResolver: () async => '127.0.0.1',
    );

    final url = await server.expose(file.path);
    expect(server.isRunning, isTrue);

    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final bad = await (await client
            .getUrl(Uri.parse(url.replaceFirst(RegExp(r'/[^/]+$'), '/nope'))))
        .close();
    expect(bad.statusCode, HttpStatus.notFound);
    await bad.drain<void>();

    await server.stop();
    expect(server.isRunning, isFalse);

    // 文件不存在时 expose 抛错（不残留半开服务）
    await expectLater(
      server.expose('${dir.path}/missing.mp4'),
      throwsA(isA<FileSystemException>()),
    );
    expect(server.isRunning, isFalse);
  });
}
