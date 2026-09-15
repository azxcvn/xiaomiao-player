import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_diagnostics_panel.dart';
import 'package:moumou/utils/player_diagnostics.dart';

/// 播放诊断面板测试（§4.27）：
/// - 四组数值渲染（播放/视频/音频/缓存与丢帧）；
/// - 属性缺失显示占位符；
/// - 丢帧/软解等异常弹顶部告警卡；
/// - 读取失败显示降级提示；
/// - 定时刷新会拿到新值（用短间隔驱动）；
/// - **读取容错**：读不到时保留上次值、点名失败键、卡死超时后不冻结面板。
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(backgroundColor: Colors.black, body: child),
      );

  Future<void> pumpPanel(
    WidgetTester tester,
    Future<Map<String, String?>> Function() reader, {
    Duration interval = const Duration(hours: 1),
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    await tester.pumpWidget(host(
      PlayerDiagnosticsPanel(
        readProperties: reader,
        interval: interval,
        timeout: timeout,
      ),
    ));
    // 首帧后的异步读取
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 把「只关心某几个字段」的用例补成**全部可读且不触发告警**的属性表。
  ///
  /// 面板会把「本次读不到的键」列入降级提示，因此用局部属性表驱动会顺带触发
  /// "读取失败"——这本身是正确行为，但会干扰只验证取值的断言。本助手把未列出
  /// 的键填成可读值，其中**告警判据字段**（丢帧/抖动/同步/时间戳/硬解）填 0
  /// 或安全值，避免填 `1` 反而触发告警（`vsync-jitter` 单位是秒，`1` = 1000ms）。
  String safeDefault(String key) => switch (key) {
        // 告警判据：填 0 不会触发，同时仍是"读到了"的合法值
        'frame-drop-count' ||
        'decoder-frame-drop-count' ||
        'vo-delayed-frame-count' ||
        'avsync' =>
          '0',
        // 软解告警判据：非 no 即可
        'hwdec-current' => 'mediacodec-copy',
        _ => '1',
      };

  Map<String, String?> allReadable(Map<String, String?> partial) => {
        for (final key in kPlayerDiagnosticsProperties) key: safeDefault(key),
        ...partial,
      };

  testWidgets('渲染四组数值', (tester) async {
    await pumpPanel(tester, () async => allReadable(const {
          'media-title': '测试视频.mkv',
          'file-format': 'Matroska',
          'audio-codec-name': 'aac',
          'width': '1920',
          'height': '1080',
          'video-params/pixelformat': 'yuv420p',
          'container-fps': '23.976',
          'hwdec-current': 'mediacodec-copy',
          'current-vo': 'gpu-next',
          'current-gpu-context': 'androidvk',
          'video-sync': 'audio',
          'demuxer-cache-time': '12.0',
          // ⚠️ 缓存字节数取自整表 JSON（子属性路径在该 libmpv 构建下不可用）
          'demuxer-cache-state': '{"fw-bytes":8388608,"total-bytes":12800000}',
          'cache-speed': '1048576',
          'video-bitrate': '1420000',
          'audio-params': '48000Hz stereo float',
          'frame-drop-count': '0',
        }));
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
    expect(find.text('缓存与丢帧'), findsOneWidget);
    expect(find.text('测试视频.mkv'), findsOneWidget);
    expect(find.text('1920×1080'), findsOneWidget);
    expect(find.text('23.98 fps'), findsOneWidget);
    expect(find.text('mediacodec-copy'), findsOneWidget);
    // 视频输出 + 实际图形后端拼在一行
    expect(find.text('gpu-next · androidvk'), findsOneWidget);
    expect(find.text('8.0 MB'), findsOneWidget);
    expect(find.text('1.00 MB/s'), findsOneWidget);
    expect(find.text('1.42 Mb/s'), findsOneWidget);
    expect(find.text('48000Hz stereo float'), findsOneWidget);
    expect(find.text('12.0 s'), findsOneWidget);
    // 无异常 → 不出现告警图标
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('属性缺失显示占位符', (tester) async {
    // 全部键都可读但值为 1/空 → 面板显示占位符（与"读取失败"是两回事）
    await pumpPanel(
      tester,
      () async => {for (final k in kPlayerDiagnosticsProperties) k: null},
    );
    expect(find.text('—'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('只有 vo 没有图形后端时不留半截值', (tester) async {
    await pumpPanel(
      tester,
      () async => allReadable(const {'current-vo': 'gpu-next'})
        ..['current-gpu-context'] = null,
    );
    expect(find.text('gpu-next'), findsOneWidget);
    expect(find.text('gpu-next · —'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('有图形后端但未取到 vo 时也能显示后端', (tester) async {
    await pumpPanel(
      tester,
      () async => allReadable(const {'current-gpu-context': 'android'})
        ..['current-vo'] = null,
    );
    expect(find.text('android'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('丢帧/软解时顶部出告警卡', (tester) async {
    await pumpPanel(tester, () async => allReadable(const {
          'hwdec-current': 'no',
          'frame-drop-count': '5',
        }));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    expect(find.textContaining('已丢帧 5 帧'), findsOneWidget);
    expect(find.textContaining('软解'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('读取失败显示降级提示', (tester) async {
    await pumpPanel(tester, () async => throw StateError('boom'));
    expect(find.textContaining('无法读取播放器属性'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('定时刷新取到新值', (tester) async {
    var dropped = 0;
    await pumpPanel(
      tester,
      () async => {'frame-drop-count': '$dropped'},
      interval: const Duration(milliseconds: 200),
    );
    expect(find.text('0'), findsOneWidget);
    dropped = 42;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // ── 读取容错（历史 bug 修复）：读不到 / 卡住时不再把面板打成一片横杠 ──

  testWidgets('读取失败时保留上一次的好值，不被空表覆盖', (tester) async {
    var call = 0;
    await pumpPanel(
      tester,
      () async {
        call++;
        // 第一次全部可读；第二次 mpv 属性全不可用（成片 null）
        return call == 1
            ? allReadable(const {
                'current-vo': 'gpu-next',
                'current-gpu-context': 'android',
                'width': '1920',
                'height': '1080',
              })
            : <String, String?>{};
      },
      interval: const Duration(milliseconds: 200),
    );
    expect(find.text('gpu-next · android'), findsOneWidget);
    expect(find.text('1920×1080'), findsOneWidget);
    expect(find.textContaining('读取失败'), findsNothing);

    // 第二次采样：属性全部读不到 → 数值必须保留（而不是变横杠）
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('gpu-next · android'), findsOneWidget);
    expect(find.text('1920×1080'), findsOneWidget);

    // 同时给出降级提示，且点名是哪些键读不到（读取失败 → 顶部提示从无到有）
    expect(find.textContaining('读取失败'), findsOneWidget);
    // 提示卡会列出具体键名（默认最多 6 个）；此处只需确认列的是属性名而非空话
    expect(find.textContaining('audio-bitrate'), findsOneWidget);
    // 全部属性都读不到 → 计数等于清单长度
    expect(
      find.textContaining('${kPlayerDiagnosticsProperties.length} 项'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('全部可读时不出现读取失败提示', (tester) async {
    await pumpPanel(tester, () async => allReadable(const {
          'current-vo': 'gpu-next',
          'frame-drop-count': '0',
        }));
    expect(find.textContaining('读取失败'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('读取卡死时不冻结面板：超时后仍会重试并恢复', (tester) async {
    var call = 0;
    await pumpPanel(
      tester,
      () {
        call++;
        if (call == 1) {
          // 第一次永不完成：模拟 getProperty 卡住（GPU-next/Vulkan 异常时）
          return Completer<Map<String, String?>>().future;
        }
        return Future.value(allReadable(const {'current-vo': 'gpu-next'}));
      },
      interval: const Duration(milliseconds: 200),
      timeout: const Duration(milliseconds: 300),
    );
    // 尚未超时：显示占位符，且没有卡在 loading
    expect(find.text('—'), findsWidgets);

    // 超过超时点 + 下一个 tick → 必须能重新发起读取并拿到值
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(call, greaterThan(1)); // 关键：没有被 _reading 永久锁死
    // 恢复读取后拿到值（拼在「视频输出」一行：`gpu-next · <后端>`）
    expect(find.textContaining('gpu-next'), findsOneWidget);

    // 卡死阶段留下的失败提示，在恢复读取后被清掉
    expect(find.textContaining('读取失败'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
