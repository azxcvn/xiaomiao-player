import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_danmaku_panel.dart';
import 'package:moumou/pages/player/views/subtitle_file_picker.dart';
import 'package:moumou/services/device_services.dart';

/// 文件选择器分派测试（用户反馈：Android 11 上系统选择器把 XML 弹幕置灰）：
/// - 分派边界：Android 10 及以下（API ≤ 29）走系统 SAF 选择器，Android 11 起走自建；
/// - 弹幕必须走**弹幕专用**通道方法（字幕白名单里没有 text/xml，会置灰 .xml）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');
  Object? Function(MethodCall call)? handler;

  setUp(() {
    handler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return handler?.call(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('shouldUseSystemPicker（分派边界）', () {
    test('Android 10 及以下（API ≤ 29）走系统选择器', () {
      expect(DeviceServices.shouldUseSystemPicker(24), isTrue, reason: 'Android 7');
      expect(DeviceServices.shouldUseSystemPicker(28), isTrue, reason: 'Android 9');
      expect(
        DeviceServices.shouldUseSystemPicker(29),
        isTrue,
        reason: 'Android 10：分区存储、没有「所有文件访问」，必须 SAF',
      );
      expect(DeviceServices.systemPickerMaxSdk, 29);
    });

    test('Android 11（API 30）起走自建选择器', () {
      expect(
        DeviceServices.shouldUseSystemPicker(30),
        isFalse,
        reason: 'Android 11 起有「所有文件访问」，自建选择器可用（原先错写成 ≤30）',
      );
      expect(DeviceServices.shouldUseSystemPicker(36), isFalse);
    });

    test('SDK 读不到（≤0）不当作系统选择器', () {
      expect(DeviceServices.shouldUseSystemPicker(0), isFalse);
      expect(DeviceServices.shouldUseSystemPicker(-1), isFalse);
    });
  });

  group('系统选择器通道方法', () {
    test('openDanmakuPicker：走弹幕专用方法（不是字幕那条）', () async {
      final methods = <String>[];
      handler = (call) {
        methods.add(call.method);
        return 'content://provider/danmaku.xml';
      };

      expect(await DeviceServices.openDanmakuPicker(), 'content://provider/danmaku.xml');
      expect(methods, ['openDanmakuPicker']);
    });

    test('DanmakuFileService：弹幕走弹幕选择器并拷贝为真实路径', () async {
      final methods = <String>[];
      handler = (call) {
        methods.add(call.method);
        return switch (call.method) {
          'openDanmakuPicker' => 'content://provider/danmaku.xml',
          'copyDanmakuFromUri' => '/data/user/0/moumou/files/danmaku/danmaku.xml',
          _ => null,
        };
      };

      final path = await DanmakuFileService.pickWithSystemPicker();
      expect(path, '/data/user/0/moumou/files/danmaku/danmaku.xml');
      expect(methods, ['openDanmakuPicker', 'copyDanmakuFromUri']);
      expect(
        methods,
        isNot(contains('openDocumentPicker')),
        reason: '复用字幕选择器会把 .xml（text/xml）置灰',
      );
    });

    test('SubtitleFileService：字幕仍走字幕选择器', () async {
      final methods = <String>[];
      handler = (call) {
        methods.add(call.method);
        return switch (call.method) {
          'openDocumentPicker' => 'content://provider/sub.ass',
          'copySubtitleFromUri' => '/data/user/0/moumou/files/subtitle/sub.ass',
          _ => null,
        };
      };

      final path = await SubtitleFileService.pickWithSystemPicker();
      expect(path, '/data/user/0/moumou/files/subtitle/sub.ass');
      expect(methods, ['openDocumentPicker', 'copySubtitleFromUri']);
    });

    test('用户取消（原生返回 null）→ null，不发起拷贝', () async {
      final methods = <String>[];
      handler = (call) {
        methods.add(call.method);
        return null;
      };

      expect(await DanmakuFileService.pickWithSystemPicker(), isNull);
      expect(await SubtitleFileService.pickWithSystemPicker(), isNull);
      expect(methods, ['openDanmakuPicker', 'openDocumentPicker']);
    });
  });
}
