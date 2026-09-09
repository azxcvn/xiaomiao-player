import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_diagnostics_panel.dart';

/// 播放诊断面板测试（§4.27）：
/// - 四组数值渲染（播放/视频/音频/缓存与丢帧）；
/// - 属性缺失显示占位符；
/// - 丢帧/软解等异常弹顶部告警卡；
/// - 读取失败显示降级提示；
/// - 定时刷新会拿到新值（用短间隔驱动）。
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(backgroundColor: Colors.black, body: child),
      );

  Future<void> pumpPanel(
    WidgetTester tester,
    Future<Map<String, String?>> Function() reader, {
    Duration interval = const Duration(hours: 1),
  }) async {
    await tester.pumpWidget(host(
      PlayerDiagnosticsPanel(readProperties: reader, interval: interval),
    ));
    // 首帧后的异步读取
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('渲染四组数值', (tester) async {
    await pumpPanel(tester, () async => const {
          'media-title': '测试视频.mkv',
          'file-format': 'Matroska',
          'video-codec': 'h264 (High)',
          'audio-codec-name': 'aac',
          'width': '1920',
          'height': '1080',
          'video-params/pixelformat': 'yuv420p',
          'container-fps': '23.976',
          'hwdec-current': 'mediacodec-copy',
          'current-vo': 'gpu',
          'video-sync': 'audio',
          'demuxer-cache-time': '12.0',
          'cache-used': '8388608',
          'cache-speed': '1048576',
          'video-bitrate': '1420000',
          'audio-params': '48000Hz stereo float',
          'drop-frame-count': '0',
        });
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('音频'), findsOneWidget);
    expect(find.text('缓存与丢帧'), findsOneWidget);
    expect(find.text('测试视频.mkv'), findsOneWidget);
    expect(find.text('1920×1080'), findsOneWidget);
    expect(find.text('23.98 fps'), findsOneWidget);
    expect(find.text('mediacodec-copy'), findsOneWidget);
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
    await pumpPanel(tester, () async => const {});
    expect(find.text('—'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('丢帧/软解时顶部出告警卡', (tester) async {
    await pumpPanel(tester, () async => const {
          'hwdec-current': 'no',
          'drop-frame-count': '5',
        });
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
      () async => {'drop-frame-count': '$dropped'},
      interval: const Duration(milliseconds: 200),
    );
    expect(find.text('0'), findsOneWidget);
    dropped = 42;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
