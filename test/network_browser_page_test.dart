import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/pages/network/network_browser_page.dart';

/// 网络浏览页加载会话号（P2-22）：快速「进目录 → 返回」时，先发出的请求后回来
/// 不能再把新列表覆盖掉，否则会出现「父目录标题 + 子目录内容」的错位。
void main() {
  const connection = NetworkConnection(
    name: '测试 NAS',
    protocol: NetworkProtocol.webdav,
    host: '127.0.0.1',
    port: 80,
  );

  NetworkFile dir(String path) =>
      NetworkFile(name: path.split('/').last, path: path, isDirectory: true);

  testWidgets('旧目录响应后到 → 不覆盖新列表', (tester) async {
    final pending = <({String path, Completer<List<NetworkFile>> completer})>[];
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) {
      final entry = (path: path, completer: Completer<List<NetworkFile>>());
      pending.add(entry);
      return entry.completer.future;
    }

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(connection: connection, browse: browse),
    ));
    await tester.pump();
    expect(pending.length, 1);
    expect(pending[0].path, '/');

    // 根目录列出「A」→ 进 A（A 的请求在飞）
    pending[0].completer.complete([dir('/A')]);
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(pending.length, 2);
    expect(pending[1].path, '/A');

    // 立刻返回上一级（根的第二次请求在飞，A 的请求仍挂着）
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(pending.length, 3);
    expect(pending[2].path, '/');

    // 新的根列表先回来 → 正常展示
    pending[2].completer.complete([dir('/NEW')]);
    await tester.pump();
    expect(find.text('NEW'), findsOneWidget);

    // 迟到的 A 列表回来 → 必须被丢弃（旧实现会把它画在根标题下）
    pending[1].completer.complete([dir('/STALE')]);
    await tester.pump();
    expect(find.text('STALE'), findsNothing);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('测试 NAS'), findsOneWidget, reason: '标题仍应是根目录');
  });
}
