import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/playback_history_page.dart';
import 'package:moumou/services/playback_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 历史记录页测试（工作.md：播放历史记录功能）：
/// 空态提示、条目渲染、左滑删除单条、一键清空二次确认、关闭记录开关。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaybackHistoryService.instance.debugReset();
    // 原生视频信息通道 mock（VideoCard 缩略图请求；返回 null → 占位图）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('moumou/video_info'),
            (call) async {
      return null;
    });
  });

  /// 预置历史条目（新→旧写入存储）
  Future<void> seedEntries(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'playback_history_entries',
      jsonEncode(entries),
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlaybackHistoryPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空态：无历史显示提示，开关默认开启', (tester) async {
    await pumpPage(tester);
    expect(find.text('暂无播放历史'), findsOneWidget);
    expect(find.text('播放历史记录'), findsOneWidget);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
  });

  testWidgets('渲染历史条目（本地 + 在线直链）', (tester) async {
    await seedEntries([
      {
        'path': 'https://example.com/movie.mp4',
        'title': 'movie.mp4',
        'isUrl': true,
        'playedAtMs': 2000,
        'durationMs': 0,
      },
      {
        'path': '/storage/emulated/0/Download/a.mkv',
        'title': 'a.mkv',
        'isUrl': false,
        'playedAtMs': 1000,
        'durationMs': 60000,
      },
    ]);
    await pumpPage(tester);
    expect(find.text('movie.mp4'), findsOneWidget);
    expect(find.text('a.mkv'), findsOneWidget);
    expect(find.text('暂无播放历史'), findsNothing);
  });

  testWidgets('垃圾桶按钮删除单条历史', (tester) async {
    await seedEntries([
      {
        'path': '/storage/emulated/0/a.mkv',
        'title': 'a.mkv',
        'isUrl': false,
        'playedAtMs': 1000,
        'durationMs': 0,
      },
      {
        'path': '/storage/emulated/0/b.mkv',
        'title': 'b.mkv',
        'isUrl': false,
        'playedAtMs': 2000,
        'durationMs': 0,
      },
    ]);
    await pumpPage(tester);
    expect(find.text('a.mkv'), findsOneWidget);
    expect(find.text('b.mkv'), findsOneWidget);
    expect(find.byTooltip('删除该条记录'), findsNWidgets(2));

    // 点列表第一项（最新条目 b.mkv）的垃圾桶
    await tester.tap(find.byTooltip('删除该条记录').first);
    await tester.pumpAndSettle();

    // 条目按新→旧排列：b.mkv（最新）被删，a.mkv 保留
    expect(find.text('b.mkv'), findsNothing);
    expect(find.text('a.mkv'), findsOneWidget);
    // 持久化也被删除：重读存储确认
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('playback_history_entries')!;
    expect(raw.contains('b.mkv'), isFalse);
    expect(raw.contains('a.mkv'), isTrue);
  });

  testWidgets('一键清空：二次确认弹窗，取消保留 / 确认清空', (tester) async {
    await seedEntries([
      {
        'path': '/storage/emulated/0/a.mkv',
        'title': 'a.mkv',
        'isUrl': false,
        'playedAtMs': 1000,
        'durationMs': 0,
      },
    ]);
    await pumpPage(tester);

    // 点右上角清空 → 弹出二次确认
    await tester.tap(find.byTooltip('清除全部历史'));
    await tester.pumpAndSettle();
    expect(find.text('清除历史记录'), findsOneWidget);
    expect(find.text('确定要清除全部播放历史吗？此操作不可恢复。'), findsOneWidget);

    // 取消：历史保留
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('a.mkv'), findsOneWidget);

    // 再次清空 → 确认：历史清空、回到空态
    await tester.tap(find.byTooltip('清除全部历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    expect(find.text('暂无播放历史'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('playback_history_entries')!), isEmpty);
  });

  testWidgets('无历史时清空按钮禁用', (tester) async {
    await pumpPage(tester);
    final btn = tester.widget<IconButton>(find.byType(IconButton));
    expect(btn.onPressed, isNull);
  });

  testWidgets('关闭播放历史记录开关（写入持久化）', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(PlaybackHistoryService.instance.enabled, isFalse);
    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('playback_history_enabled'), isFalse);
  });
}
