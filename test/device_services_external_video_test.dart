import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/device_services.dart';

/// 外部打开视频的通道封装测试（注册系统播放器，工作.md）：
/// takeExternalVideo 取走即清语义由原生保证，这里验证 Dart 侧的
/// 参数传递与返回解析（含异常/空值降级）。
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

  test('takeExternalVideo：解析原生返回的 uri/title', () async {
    handler = (call) {
      expect(call.method, 'takeExternalVideo');
      return {'uri': 'content://media/1', 'title': 'a.mkv'};
    };
    final pending = await DeviceServices.takeExternalVideo();
    expect(pending, isNotNull);
    expect(pending!['uri'], 'content://media/1');
    expect(pending['title'], 'a.mkv');
  });

  test('takeExternalVideo：无待处理返回 null', () async {
    handler = (call) => null;
    expect(await DeviceServices.takeExternalVideo(), isNull);
  });

  test('takeExternalVideo：字段缺失降级为空串', () async {
    handler = (call) => <String, dynamic>{};
    final pending = await DeviceServices.takeExternalVideo();
    expect(pending, isNotNull);
    expect(pending!['uri'], '');
    expect(pending['title'], '');
  });

  test('resolveVideoUri：解析原生返回的 path/title', () async {
    handler = (call) {
      expect(call.method, 'resolveVideoUri');
      expect(call.arguments['uri'], 'content://media/1');
      return {'path': '/storage/emulated/0/a.mkv', 'title': 'a.mkv'};
    };
    final resolved = await DeviceServices.resolveVideoUri('content://media/1');
    expect(resolved, isNotNull);
    expect(resolved!.path, '/storage/emulated/0/a.mkv');
    expect(resolved.title, 'a.mkv');
  });

  test('resolveVideoUri：直链 title 为 null 时降级空串', () async {
    handler = (call) => {'path': 'https://x.com/v.mp4', 'title': null};
    final resolved = await DeviceServices.resolveVideoUri('https://x.com/v.mp4');
    expect(resolved!.path, 'https://x.com/v.mp4');
    expect(resolved.title, '');
  });

  test('resolveVideoUri：原生返回 null（解析失败）→ null', () async {
    handler = (call) => null;
    expect(await DeviceServices.resolveVideoUri('content://bad'), isNull);
  });

  test('resolveVideoUri：path 为空 → null', () async {
    handler = (call) => {'path': '', 'title': 'x'};
    expect(await DeviceServices.resolveVideoUri('content://x'), isNull);
  });

  test('通道异常（MissingPluginException 等）静默降级', () async {
    handler = (call) => throw PlatformException(code: 'UNAVAILABLE');
    expect(await DeviceServices.takeExternalVideo(), isNull);
    expect(await DeviceServices.resolveVideoUri('content://x'), isNull);
  });
}
