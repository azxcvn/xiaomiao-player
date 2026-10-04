import 'package:canvas_danmaku/canvas_danmaku.dart' as canvas;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/pages/player/views/player_danmaku_panel.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 弹幕二级界面回归测试（阶段1+3）：
/// - 四个入口齐全：本地弹幕 / 网络弹幕 / 自动匹配 / 弹幕设置；
/// - 网络弹幕 / 自动匹配点击触发注入回调（阶段3 实现）；
/// - 弹幕设置点击触发注入回调（与底栏弹幕设置按钮同一回调）；
/// - 本地弹幕在无平台通道的测试环境（getSdkInt → 0）下点击不崩溃。
void main() {
  Widget buildPanel({
    required DanmakuController controller,
    VoidCallback? onSettingsTap,
    VoidCallback? onNetworkTap,
    VoidCallback? onAutoMatchTap,
  }) {
    return MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: PlayerDanmakuPanel(
          controller: controller,
          onSettingsTap: onSettingsTap ?? () {},
          onNetworkTap: onNetworkTap,
          onAutoMatchTap: onAutoMatchTap,
        ),
      ),
    );
  }

  testWidgets('四个入口齐全', (tester) async {
    await tester.pumpWidget(buildPanel(controller: _FakeDanmakuController()));
    expect(tester.takeException(), isNull);
    expect(find.text('本地弹幕'), findsOneWidget);
    expect(find.text('网络弹幕'), findsOneWidget);
    expect(find.text('自动匹配'), findsOneWidget);
    expect(find.text('弹幕设置'), findsOneWidget);
  });

  testWidgets('网络弹幕点击 → 触发注入回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildPanel(
      controller: _FakeDanmakuController(),
      onNetworkTap: () => tapped = true,
    ));
    await tester.tap(find.text('网络弹幕'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('自动匹配点击 → 触发注入回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildPanel(
      controller: _FakeDanmakuController(),
      onAutoMatchTap: () => tapped = true,
    ));
    await tester.tap(find.text('自动匹配'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('未注入回调时点击弹「即将上线」提示（兜底）', (tester) async {
    await tester.pumpWidget(buildPanel(controller: _FakeDanmakuController()));
    await tester.tap(find.text('网络弹幕'));
    await tester.pumpAndSettle();
    expect(find.text('「网络弹幕」功能即将上线'), findsOneWidget);
  });

  testWidgets('弹幕设置点击 → 触发注入回调（与底栏设置按钮同一行为）', (tester) async {
    var settingsTapped = false;
    await tester.pumpWidget(buildPanel(
      controller: _FakeDanmakuController(),
      onSettingsTap: () => settingsTapped = true,
    ));
    await tester.tap(find.text('弹幕设置'));
    await tester.pumpAndSettle();
    expect(settingsTapped, isTrue);
  });

  testWidgets('本地弹幕点击（测试环境无平台通道）不崩溃', (tester) async {
    await tester.pumpWidget(buildPanel(controller: _FakeDanmakuController()));
    await tester.tap(find.text('本地弹幕'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── 本地弹幕导入（T4-DMK-002 回归）────────────────────────────
  //
  // 真机 bug（Android 16，走自建选择器）：在自建选择器里点弹幕文件**没反应**，
  // 弹幕也没导入。根因是 `onPicked` 回调用的是**已被二级页替换掉的面板 context**
  // ——`PlayerPanel` 只渲染页面栈顶那一页，push 选择器后面板就被移出树，
  // 回调里再 `AppLocalizations.of(context)` 会命中
  // 「Looking up a deactivated widget's ancestor is unsafe」，
  // debug 构建下直接抛异常 → `onClose` 也不会被调用，于是「点了没反应」。
  // 下面这个宿主刻意复刻 `PlayerPanel` 的行为：**只挂载栈顶那页**。
  group('本地弹幕导入（自建选择器）', () {
    const channel = MethodChannel('moumou/video_info');
    const root = '/storage/emulated/0';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getSdkInt':
            return 35; // ≥ 30 → 走自建选择器（与真机 Android 16 同一分支）
          case 'listDirectory':
            if (call.arguments['path'] == root) {
              return [
                {
                  'name': 'EP01.xml',
                  'path': '$root/EP01.xml',
                  'isDirectory': false,
                  'size': 2048,
                  'modifiedMs': 0,
                },
              ];
            }
            return null;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('选文件 → 导入被调用、弹提示（带文件名）、回到弹幕面板（不抛异常）',
        (tester) async {
      final controller = _FakeDanmakuController()..loadResult = true;
      await tester.pumpWidget(
        MaterialApp(
          locale: kTestLocaleZh,
          localizationsDelegates: kTestLocalizationDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: _PanelHost(controller: controller),
          ),
        ),
      );

      await tester.tap(find.text('本地弹幕'));
      await tester.pumpAndSettle();
      // 自建选择器已就地切到二级页
      expect(find.text('EP01.xml'), findsOneWidget);

      await tester.tap(find.text('EP01.xml'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.loadedPaths, ['$root/EP01.xml']);
      // 提示带**弹幕文件名**（不再报条数）
      expect(find.text('已加载本地弹幕：EP01.xml'), findsOneWidget);
      // onClose 生效：回到弹幕面板
      expect(find.text('本地弹幕'), findsOneWidget);
      expect(find.text('EP01.xml'), findsNothing);
    });
  });
}

/// 复刻 `PlayerPanel` 的面板内导航：**只挂载页面栈顶那一页**（push 二级页后
/// 上一页会被移出树——这正是 T4-DMK-002 的触发条件）。
class _PanelHost extends StatefulWidget {
  final _FakeDanmakuController controller;

  const _PanelHost({required this.controller});

  @override
  State<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<_PanelHost> {
  Widget? _subPage;

  @override
  Widget build(BuildContext context) {
    return _subPage ??
        PlayerDanmakuPanel(
          controller: widget.controller,
          onSettingsTap: () {},
          onPushSubPage: (title, body) => setState(() => _subPage = body),
          onPopSubPage: () => setState(() => _subPage = null),
        );
  }
}

/// 测试假控制器（真实 [DanmakuController] 需要绑定 media_kit Player，
/// 单元测试环境不初始化原生播放器；面板 UI 测试只依赖其接口）。
class _FakeDanmakuController extends ChangeNotifier
    implements DanmakuController {
  @override
  void Function(String fileName)? onAutoLoadedDanmaku;

  @override
  void Function(String anime, String episode, String? serverName, bool autoMatch)?
      onNetworkDanmakuLoaded;

  @override
  bool get danmakuOn => true;

  @override
  int get danmakuCount => 0;

  /// 手动导入的返回值（本地弹幕导入回归用）
  bool loadResult = false;

  /// 手动导入收到的文件路径（按调用顺序）
  final List<String> loadedPaths = [];

  @override
  void attachLayer(canvas.DanmakuController<void> layer, {bool visible = false}) {}

  @override
  void detachLayer(canvas.DanmakuController<void> layer) {}

  @override
  void setLayerVisible(canvas.DanmakuController<void> layer, bool visible) {}

  @override
  void toggle() {}

  @override
  void setDanmakuOn(bool value) {}

  @override
  Future<void> loadForVideo(String mediaPath) async {}

  @override
  Future<bool> loadDanmakuFromFile(String path) async {
    loadedPaths.add(path);
    return loadResult;
  }

  @override
  Future<bool> loadNetworkDanmaku({
    required int episodeId,
    required String animeTitle,
    required String episodeTitle,
    String? serverUrl,
  }) async =>
      false;

  @override
  void loadBiliDanmaku(List<DanmakuEntry> entries) {}

  @override
  void appendBiliDanmaku(List<DanmakuEntry> entries) {}

  @override
  Future<List<DanmakuMatchItem>> matchCurrentVideo() async => const [];

  @override
  Future<void> saveAutoMatchCache({
    required int animeId,
    required String animeTitle,
    required String? serverUrl,
    required List<DandanEpisode> episodes,
  }) async {}

  @override
  Future<List<DandanEpisode>?> fetchAnimeEpisodes({
    required int animeId,
    required String animeTitle,
    String? serverUrl,
  }) async =>
      null;
}
