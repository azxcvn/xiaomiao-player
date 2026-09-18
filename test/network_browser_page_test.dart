import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/pages/network/network_browser_page.dart';
import 'package:moumou/services/network/network_directory_cache.dart';
import 'package:moumou/services/network/network_view_settings.dart';
import 'package:moumou/widgets/video_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 网络浏览页：
/// 1. 加载会话号（P2-22）：快速「进目录 → 返回」时，先发出的请求后回来不能再把
///    新列表覆盖掉，否则会出现「父目录标题 + 子目录内容」的错位；
/// 2. 目录缓存：已经列过的目录再进不再发请求（返回上级瞬时打开）；
/// 3. 隐藏项过滤：NAS 元数据目录与点开头的文件默认不展示。
void main() {
  const connection = NetworkConnection(
    name: '测试 NAS',
    protocol: NetworkProtocol.webdav,
    host: '127.0.0.1',
    port: 80,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 单例在测试间共享：不重置会让「显示隐藏文件」上一个用例的状态漏进来
    NetworkViewSettings.instance.reset();
  });

  NetworkFile dir(String path) =>
      NetworkFile(name: path.split('/').last, path: path, isDirectory: true);

  testWidgets('A 的旧列表后到 → 不覆盖已经返回的根列表', (tester) async {
    final pending = <({String path, Completer<List<NetworkFile>> completer})>[];
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) {
      final entry = (path: path, completer: Completer<List<NetworkFile>>());
      pending.add(entry);
      return entry.completer.future;
    }

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pump();
    expect(pending.length, 1);

    // 根目录有 A（A 还没列过 → 进 A 会真的发请求）
    pending[0].completer.complete([dir('/A')]);
    await tester.pump();
    await tester.tap(find.text('A'));
    await tester.pump();

    // 进 A 的请求**挂着不回**（模拟慢请求 / 弱网）
    final aRequest = pending.firstWhere(
      (e) => e.path == '/A' && !e.completer.isCompleted,
    );

    // A 还没回来就返回根：根目录命中缓存 → 瞬时恢复
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(find.text('A'), findsOneWidget, reason: '根列表应来自缓存');

    // A 的列表迟到 → 不得覆盖根列表（会话号已更新）
    aRequest.completer.complete([dir('/A/STALE')]);
    await tester.pump();
    expect(find.text('STALE'), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('测试 NAS'), findsOneWidget, reason: '标题仍应是根目录');
  });

  testWidgets('已列过的目录再进命中缓存，不再发请求', (tester) async {
    var calls = 0;
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) async {
      calls++;
      return [dir('/番剧')];
    }

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();
    final afterFirst = calls;

    await tester.tap(find.text('番剧'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('番剧'));
    await tester.pumpAndSettle();
    // 第二次进 /番剧 命中缓存：只多了「首次进目录 + 返回根强制刷新」这些，
    // 不应再为 /番剧 发一次请求
    expect(calls, lessThanOrEqualTo(afterFirst + 2));
  });

  testWidgets('隐藏项默认不展示，可在菜单里打开', (tester) async {
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) async => [
          dir('/@eaDir'),
          dir('/.hidden'),
          dir('/番剧'),
        ];

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('番剧'), findsOneWidget);
    expect(find.text('@eaDir'), findsNothing);
    expect(find.text('.hidden'), findsNothing);

    // 右上角菜单 → 显示隐藏文件
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>));
    await tester.pumpAndSettle();
    expect(find.text('@eaDir'), findsOneWidget);
    expect(find.text('.hidden'), findsOneWidget);
  });

  testWidgets('文件夹与视频只显示日期（不显示大小/时长等远端拿不到的信息）', (tester) async {
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) async => [
          NetworkFile(
            name: '动画',
            path: '/动画',
            isDirectory: true,
            size: 1234567,
            lastModified: DateTime(2026, 3, 1).millisecondsSinceEpoch,
          ),
          NetworkFile(
            name: '01.mkv',
            path: '/01.mkv',
            size: 2048,
            lastModified: DateTime(2026, 2, 2).millisecondsSinceEpoch,
          ),
          NetworkFile(
            name: '01.sc.ass',
            path: '/01.sc.ass',
            size: 1024,
            lastModified: DateTime(2026, 1, 1).millisecondsSinceEpoch,
          ),
        ];

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('动画'), findsOneWidget);
    expect(find.text('01.mkv'), findsOneWidget);
    // 非视频文件条目也在，只是不可点击
    expect(find.text('01.sc.ass'), findsOneWidget);
    // 日期显示（服务器给了时间）
    expect(find.text('2026-03-01'), findsOneWidget);
    expect(find.text('2026-02-02'), findsOneWidget);
    // 没播过的视频没有时长：不显示（远端列目录拿不到时长）
    expect(find.text('0:00'), findsNothing);
    // 大小一律不显示：远端只有部分服务器给，显示了就是假的
    expect(find.textContaining('MB'), findsNothing);
    expect(find.textContaining('KB'), findsNothing);
    // 远端读不到的字段一个都不出现
    expect(find.textContaining('无字幕'), findsNothing);
    expect(find.textContaining('未观看'), findsNothing);
    expect(find.textContaining('fps'), findsNothing);
  });

  testWidgets('时长只在「播过一次」后才显示（播前没有）', (tester) async {
    const connectionId = 0; // 未入库连接：记忆键用 连接 id|远端路径
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) async => [
          NetworkFile(
            name: '01.mkv',
            path: '/01.mkv',
            lastModified: DateTime(2026, 2, 2).millisecondsSinceEpoch,
          ),
        ];

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();
    // 播放前：卡片没有时长标签
    expect(find.text('1:23:45'), findsNothing);

    // 模拟播放页回报时长（真实链路由 PlayerPage.onDurationKnown 触发）
    await NetworkViewSettings.instance
        .rememberDuration('$connectionId|/01.mkv', 5025000); // 1:23:45
    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1:23:45'), findsOneWidget);
  });

  testWidgets('排序：按名称自然序，切到日期降序立即生效', (tester) async {
    Future<List<NetworkFile>> browse(NetworkConnection _, String path) async => [
          NetworkFile(
            name: 'EP10.mkv',
            path: '/EP10.mkv',
            lastModified: DateTime(2026, 1, 10).millisecondsSinceEpoch,
          ),
          NetworkFile(
            name: 'EP2.mkv',
            path: '/EP2.mkv',
            lastModified: DateTime(2026, 1, 2).millisecondsSinceEpoch,
          ),
        ];

    await tester.pumpWidget(MaterialApp(
      home: NetworkBrowserPage(
        connection: connection,
        browse: browse,
        cache: NetworkDirectoryCache(),
      ),
    ));
    await tester.pumpAndSettle();

    // 默认按名称自然序：EP2 在 EP10 之前
    var cards = tester
        .widgetList<VideoCard>(find.byType(VideoCard))
        .map((c) => c.video.name)
        .toList();
    expect(cards, ['EP2.mkv', 'EP10.mkv']);

    // 排序面板：只有名称/日期四项
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(find.text('按名称升序'), findsOneWidget);
    expect(find.text('按名称降序'), findsOneWidget);
    expect(find.text('按日期升序'), findsOneWidget);
    expect(find.text('按日期降序'), findsOneWidget);
    // 没有「按大小 / 按数量」这种远端排不动的选项
    expect(find.textContaining('大小'), findsNothing);
    expect(find.textContaining('数量'), findsNothing);

    await tester.tap(find.text('按日期降序'));
    await tester.pumpAndSettle();
    cards = tester
        .widgetList<VideoCard>(find.byType(VideoCard))
        .map((c) => c.video.name)
        .toList();
    expect(cards, ['EP10.mkv', 'EP2.mkv'], reason: '日期降序应把新的排前面');
  });
}
