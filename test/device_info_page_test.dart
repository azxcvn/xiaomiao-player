import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/settings/device_info_page.dart';

/// 设备信息页测试（工作.md 迁移功能：设备硬件与编解码能力检测页）：
/// 设备信息、屏幕 HDR 能力、关键编码器、解码器清单渲染与筛选/失败降级。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');

  Map<String, dynamic> sampleCaps() => {
        'device': {
          'manufacturer': 'Xiaomi',
          'model': '13',
          'release': '14',
          'sdkInt': '34',
        },
        'hdrCapabilities': ['HDR10', 'HDR10+', 'HLG'],
        'keyCodecs': [
          {
            'formatName': 'H.264 / AVC',
            'mimeType': 'video/avc',
            'hasHardware': true,
            'hasSoftware': true,
            'decoderName': 'c2.qti.avc.decoder',
            'maxResolution': '4096x2160 @ 60fps',
            'isHdrSupported': false,
          },
          {
            'formatName': 'AV1',
            'mimeType': 'video/av01',
            'hasHardware': false,
            'hasSoftware': true,
            'decoderName': 'c2.android.av1.decoder',
            'maxResolution': '1920x1080 @ 30fps',
            'isHdrSupported': false,
          },
        ],
        'decoders': [
          {
            'name': 'c2.qti.avc.decoder',
            'canonicalName': 'c2.qti.avc.decoder',
            'mimeType': 'video/avc',
            'formatName': 'H.264 / AVC',
            'isHardware': true,
            'isAlias': false,
            'mediaType': 'video',
            'maxResolution': '4096x2160 @ 60fps',
            'minResolution': '128x128',
            'maxChannels': 0,
            'maxInstances': 8,
            'alignment': '16x16',
            'bitrateRange': '64 kbps - 100 Mbps',
            'profiles': ['Main', 'High', 'High 10'],
            'colorFormats': ['YUV 420 Semi-Planar (NV12)'],
            'features': ['Adaptive Res', 'Low Latency'],
            'sampleRates': const [],
            'isHdrSupported': false,
          },
          {
            'name': 'c2.android.aac.decoder',
            'canonicalName': 'c2.android.aac.decoder',
            'mimeType': 'audio/mp4a-latm',
            'formatName': 'AAC',
            'isHardware': false,
            'isAlias': false,
            'mediaType': 'audio',
            'maxResolution': '',
            'minResolution': '',
            'maxChannels': 8,
            'maxInstances': 0,
            'alignment': '',
            'bitrateRange': '',
            'profiles': const [],
            'colorFormats': const [],
            'features': const [],
            'sampleRates': ['48.0 kHz', '44.1 kHz'],
            'isHdrSupported': false,
          },
        ],
      };

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceInfoPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染设备信息、HDR 能力、关键编码器与解码器清单', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDeviceCapabilities') return sampleCaps();
      return null;
    });
    await pumpPage(tester);
    expect(find.text('Xiaomi 13'), findsOneWidget);
    expect(find.text('Android 14 · API 34'), findsOneWidget);
    expect(find.text('屏幕 HDR 能力'), findsOneWidget);
    expect(find.text('HDR10'), findsOneWidget);
    expect(find.text('关键视频编码器'), findsOneWidget);
    expect(find.text('H.264 / AVC'), findsWidgets);
    // 关键编码器卡有「硬解/软解」徽章，筛选胶囊也含「硬解/软解」→ 各至少一个
    expect(find.text('硬解'), findsWidgets);
    expect(find.text('软解'), findsWidgets);
    expect(find.text('解码器清单'), findsOneWidget);
    expect(find.text('AAC'), findsOneWidget);
  });

  testWidgets('解码器筛选：硬解/软解/视频/音频胶囊', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDeviceCapabilities') return sampleCaps();
      return null;
    });
    await pumpPage(tester);

    // 滚动到「解码器清单」区，使筛选胶囊可见
    await tester.scrollUntilVisible(find.text('音频'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // 切到音频筛选：解码器清单只剩 AAC（关键编码器卡仍显示 H.264，AAC 只在清单）
    await tester.tap(find.text('音频'));
    await tester.pumpAndSettle();
    expect(find.text('AAC'), findsOneWidget);
    // 解码器清单里的 H.264 消失（关键编码器卡里的 H.264 仍在）
    expect(find.text('H.264 / AVC'), findsOneWidget);

    // 切到视频筛选：AAC 消失
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();
    expect(find.text('AAC'), findsNothing);
  });

  testWidgets('原生通道失败时显示错误与重试', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    await pumpPage(tester);
    expect(find.textContaining('无法读取设备能力'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('点击解码器进入详情页显示完整能力信息', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getDeviceCapabilities') return sampleCaps();
      return null;
    });
    await pumpPage(tester);

    // 滚动到解码器清单，点 H.264 解码器行（按唯一 decoder name 定位）
    await tester.scrollUntilVisible(find.text('c2.qti.avc.decoder'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('c2.qti.avc.decoder'));
    await tester.pumpAndSettle();

    // 详情页标题 + 展开字段
    expect(find.text('MIME 类型'), findsOneWidget);
    expect(find.text('video/avc'), findsOneWidget);
    expect(find.text('最大分辨率'), findsOneWidget);
    expect(find.text('4096x2160 @ 60fps'), findsOneWidget);
    expect(find.text('最大实例数'), findsOneWidget);
    expect(find.text('硬件特性'), findsOneWidget);
    expect(find.text('Adaptive Res'), findsOneWidget);
    // 滚动到底部验证 Profile / Level 区
    await tester.scrollUntilVisible(
      find.text('支持的 Profile / Level'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('支持的 Profile / Level'), findsOneWidget);
  });
}