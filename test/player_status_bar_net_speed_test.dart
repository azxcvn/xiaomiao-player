import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_status_bar.dart';
import 'package:moumou/services/bilibili/bili_stream_proxy.dart';
import 'package:moumou/services/player_controls_settings.dart';

/// 顶部信息行网速来源分流测试（工作.md：链接播放网速恒 0 KB/s 的修复）：
/// - 直连播放（两个本地代理都查不到）→ 读 directNetSpeedReader（mpv cache-speed）；
/// - B 站代理有注册流（recentTotal 非 null）→ **不走** reader（B 站聚合优先）；
/// - reader 返回 null（属性未激活）→ 保持原显示不崩溃。
void main() {
  setUp(() {
    PlayerControlsSettings.instance.reset();
  });

  tearDown(() {
    BiliStreamProxy.instance.stop();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required String streamUrl,
    Future<double?> Function()? reader,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerStatusBar(
            isOnlinePlayback: true,
            streamUrl: streamUrl,
            directNetSpeedReader: reader,
          ),
        ),
      ),
    );
    // initState 立即跑一次 _tickNetSpeed（同步段查代理 → await reader），
    // pump 触发微任务；再推进 1 秒触发 Timer.periodic 采样
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('直连播放：两代理查不到时读 directNetSpeedReader 显示网速',
      (tester) async {
    await pumpBar(
      tester,
      // 非 127.0.0.1 的直链：NetworkStreamingProxy 按 URL 查不到、
      // BiliStreamProxy 无注册流 → 均 null → 走 reader
      streamUrl: 'https://example.com/movie.m3u8',
      reader: () async => 12345.0,
    );
    // 12345 B/s = 12.06 KB/s
    expect(find.text('12.06 KB/s'), findsOneWidget);
  });

  testWidgets('B 站代理有注册流：不走 reader（聚合速率优先）', (tester) async {
    var readerCalled = false;
    // HttpServer.bind 与 FakeAsync 冲突：注册（起真实 server）放 runAsync
    await tester.runAsync(() async {
      final reg = await BiliStreamProxy.instance.registerStreams(
        videoUrl: 'https://cdn.example.com/v.m4s',
      );
      expect(reg, isNotNull);
    });

    await pumpBar(
      tester,
      streamUrl: 'https://cdn.example.com/v.m4s',
      reader: () async {
        readerCalled = true;
        return 999999.0;
      },
    );
    // BiliStreamProxy 命中（0 B/s，窗口无数据）→ 不显示 reader 的假值
    expect(readerCalled, isFalse);
    expect(find.text('999.99 KB/s'), findsNothing);
    expect(find.text('0.00 KB/s'), findsOneWidget);
  });

  testWidgets('reader 返回 null（cache-speed 未激活）：保持显示不崩溃',
      (tester) async {
    await pumpBar(
      tester,
      streamUrl: 'https://example.com/v.mp4',
      reader: () async => null,
    );
    expect(find.text('0.00 KB/s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本地播放（isOnlinePlayback=false）：网速胶囊不显示',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerStatusBar(isOnlinePlayback: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0.00 KB/s'), findsNothing);
  });
}
