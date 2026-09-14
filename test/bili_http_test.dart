import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moumou/services/bilibili/bili_http.dart';

/// 记录 [close] 是否被调用的假 client。
class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"code":0,"data":{}}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closed = true;
  }
}

/// `BiliHttp` 的 client 生命周期（§4.14/§7：每次进页面 new 一个不关就是泄漏）。
void main() {
  test('自建的 client 由 close() 关闭（幂等）', () {
    final tracking = _TrackingClient();
    final api = BiliHttp(clientFactory: () => tracking);
    expect(tracking.closed, isFalse);
    api.close();
    expect(tracking.closed, isTrue);
    api.close(); // 幂等：重复关闭不抛
    expect(tracking.closed, isTrue);
  });

  test('注入的 client 不代关（归调用方）', () {
    final tracking = _TrackingClient();
    final api = BiliHttp(client: tracking);
    api.close();
    expect(tracking.closed, isFalse, reason: '注入的 client 生命周期由调用方管');
  });

  test('close 之后注入的 client 仍可用（只标记关闭，不破坏注入对象）', () async {
    final tracking = _TrackingClient();
    final api = BiliHttp(client: tracking);
    api.close();
    final json = await api.getJson('https://api.bilibili.com/x/test');
    expect(json['code'], 0);
  });
}
