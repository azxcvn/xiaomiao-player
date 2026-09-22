import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/utils/player_orientation.dart';

/// 播放页方向策略测试（用户反馈：退出播放后系统自动旋转失效 + 播放界面内
/// 竖起来进不了竖屏 + 竖屏视频进页先横屏再转竖屏）：
/// - [PlayerOrientation]：退出播放要「交还系统」（空列表 = 不指定方向），
///   钉成竖屏会让 Activity 的 requestedOrientation 永久停在竖屏；
/// - [shouldFollowPhoneOrientation]：跟随手机方向的三个前置条件；
/// - [isPortraitDisplay]：由编码宽高 + 旋转角判显示方向（竖拍视频
///   编码 1920x1080 + rotate 90 要交换宽高，否则会误判成横屏）；
/// - [DeviceServices]：系统「自动旋转」开关的读取与缓存（读不到时保留旧值）、
///   播放页方向预读（本地路径才发起通道调用）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerOrientation', () {
    test('appDefault 必须是空列表（不指定方向 = 交还系统）', () {
      expect(PlayerOrientation.appDefault, isEmpty);
    });

    test('锁定竖屏/横屏的方向集合', () {
      expect(PlayerOrientation.portrait, [DeviceOrientation.portraitUp]);
      expect(PlayerOrientation.landscape, [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  });

  group('shouldFollowPhoneOrientation', () {
    test('开关 + 「自动」+ 系统自动旋转，三者同时成立才跟随', () {
      expect(
        shouldFollowPhoneOrientation(
          mode: VideoOrientationMode.auto,
          followPhoneRotation: true,
          systemAutoRotate: true,
        ),
        isTrue,
      );
      // 开关关闭
      expect(
        shouldFollowPhoneOrientation(
          mode: VideoOrientationMode.auto,
          followPhoneRotation: false,
          systemAutoRotate: true,
        ),
        isFalse,
      );
      // 系统自动旋转关闭（系统根本不会转窗口，跟随会退化成固定方向）
      expect(
        shouldFollowPhoneOrientation(
          mode: VideoOrientationMode.auto,
          followPhoneRotation: true,
          systemAutoRotate: false,
        ),
        isFalse,
      );
    });

    test('锁定竖屏/锁定横屏是用户的明确指定，不受开关影响', () {
      for (final mode in [
        VideoOrientationMode.portrait,
        VideoOrientationMode.landscape,
      ]) {
        expect(
          shouldFollowPhoneOrientation(
            mode: mode,
            followPhoneRotation: true,
            systemAutoRotate: true,
          ),
          isFalse,
          reason: '$mode 下不应跟随手机方向',
        );
      }
    });
  });

  group('isPortraitDisplay', () {
    test('无旋转：宽 > 高 = 横屏，高 > 宽 = 竖屏', () {
      expect(isPortraitDisplay(width: 1920, height: 1080), isFalse);
      expect(isPortraitDisplay(width: 1080, height: 1920), isTrue);
    });

    test('旋转 90/270（含负数与超过 360）交换宽高：竖拍视频不再误判成横屏', () {
      for (final rotation in [90, 270, -90, 450]) {
        expect(
          isPortraitDisplay(width: 1920, height: 1080, rotation: rotation),
          isTrue,
          reason: '编码 1920x1080 + rotate $rotation，显示方向是竖屏',
        );
        expect(
          isPortraitDisplay(width: 1080, height: 1920, rotation: rotation),
          isFalse,
          reason: '编码 1080x1920 + rotate $rotation，显示方向是横屏',
        );
      }
    });

    test('旋转 0/180/360 不交换宽高', () {
      for (final rotation in [0, 180, 360]) {
        expect(
          isPortraitDisplay(width: 1920, height: 1080, rotation: rotation),
          isFalse,
        );
      }
    });

    test('正方形按竖屏处理（与历史判定 displayRatio <= 1 一致）', () {
      expect(isPortraitDisplay(width: 1000, height: 1000), isTrue);
    });

    test('尺寸未知返回 null（调用方回落到播放器上报）', () {
      expect(isPortraitDisplay(width: 0, height: 0), isNull);
      expect(isPortraitDisplay(width: 1920, height: 0), isNull);
      expect(isPortraitDisplay(width: 0, height: 1080), isNull);
    });
  });

  group('DeviceServices 系统自动旋转开关', () {
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

    test('1 = 开启、0 = 关闭、-1（读不到）= null', () async {
      handler = (call) {
        expect(call.method, 'isAutoRotateEnabled');
        return 1;
      };
      expect(await DeviceServices.readAutoRotateEnabled(), isTrue);

      handler = (call) => 0;
      expect(await DeviceServices.readAutoRotateEnabled(), isFalse);

      handler = (call) => -1;
      expect(await DeviceServices.readAutoRotateEnabled(), isNull);
    });

    test('通道异常时返回 null（不抛给调用方）', () async {
      handler = (call) => throw PlatformException(code: 'boom');
      expect(await DeviceServices.readAutoRotateEnabled(), isNull);
    });

    test('refreshAutoRotate 写缓存；读不到时保留上一次的值', () async {
      handler = (call) => 0;
      await DeviceServices.refreshAutoRotate();
      expect(DeviceServices.cachedAutoRotateEnabled, isFalse);

      // 读不到（原生返回 -1）→ 保留 false，不会被重置成默认 true
      handler = (call) => -1;
      await DeviceServices.refreshAutoRotate();
      expect(DeviceServices.cachedAutoRotateEnabled, isFalse);

      handler = (call) => 1;
      await DeviceServices.refreshAutoRotate();
      expect(DeviceServices.cachedAutoRotateEnabled, isTrue);
    });

    test('probeVideoOrientation：回传宽高 + 旋转角', () async {
      MethodCall? seen;
      handler = (call) {
        seen = call;
        return <Object?, Object?>{
          'width': 1920,
          'height': 1080,
          'rotation': 90,
        };
      };
      final probe = await DeviceServices.probeVideoOrientation('/sdcard/a.mp4');
      expect(seen?.method, 'probeVideoOrientation');
      expect(seen?.arguments, {'path': '/sdcard/a.mp4'});
      expect(probe, isNotNull);
      expect(probe!.width, 1920);
      expect(probe.height, 1080);
      expect(probe.rotation, 90);
    });

    test('probeVideoOrientation：宽高读不到（全 0）= null', () async {
      handler = (call) =>
          <Object?, Object?>{'width': 0, 'height': 0, 'rotation': 0};
      expect(
        await DeviceServices.probeVideoOrientation('/sdcard/a.mp4'),
        isNull,
      );
    });

    test('probeVideoOrientation：非本地路径（含 ://）不发通道调用', () async {
      var called = false;
      handler = (call) {
        called = true;
        return <Object?, Object?>{'width': 1920, 'height': 1080};
      };
      expect(
        await DeviceServices.probeVideoOrientation(
          'http://127.0.0.1:8080/a.mkv',
        ),
        isNull,
      );
      expect(called, isFalse);
    });

    test('probeVideoOrientation：通道异常 = null（不抛给调用方）', () async {
      handler = (call) => throw PlatformException(code: 'boom');
      expect(
        await DeviceServices.probeVideoOrientation('/sdcard/a.mp4'),
        isNull,
      );
    });
  });
}
