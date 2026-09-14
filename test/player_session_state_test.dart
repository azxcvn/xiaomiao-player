import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/player_session_state.dart';
import 'package:moumou/pages/player/views/player_gesture_indicator.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 横竖屏共享会话状态测试（B4 / 决策 D2 治本方案）。
///
/// 覆盖四类原先「两页各一份实现」导致的漂移（体检报告 P1-1/P1-2/P1-4 +
/// 决策 D6）：
/// - P1-1 音量增强段（系统音量满 100% 后接管 mpv 增益、指示器不再谎报响度）；
/// - P1-2 倍速唯一真值（临时倍速不改用户选定倍速，恢复时回到用户值）；
/// - P1-4 滑动被双指打断必须撤销已发生的 seek；
/// - D6 缩放边界（0.75–4x、可禁缩小、平移不露黑边）。
///
/// ⚠️ 不构造 media_kit `Player`（原生库在单测环境不可用，会抛异常），
/// 会话状态对播放器/系统的副作用全部经注入回调，位置/时长也由注入读取器提供。
void main() {
  late PlayerControlsSettings settings;
  late List<String> calls;
  late double fakeSystemVolume;
  late double fakeMpvVolume;
  late Duration fakePosition;
  late Duration fakeDuration;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = PlayerControlsSettings.instance;
    settings.reset();
    await settings.load();
    calls = [];
    fakeSystemVolume = 50;
    fakeMpvVolume = 100;
    fakePosition = Duration.zero;
    fakeDuration = const Duration(minutes: 10);
  });

  /// 建一个会话状态并走一次设备初始化（读系统音量/亮度在单测环境返回 null，
  /// 会话状态回落到「系统音量 50」，并据设置算出音量增强上限——与真机
  /// 进入播放器时同一条初始化路径）。
  Future<PlayerSessionState> build() async {
    final s = PlayerSessionState(
      settings: settings,
      setSystemVolume: (v) async {
        fakeSystemVolume = v;
        calls.add('sys:${v.toStringAsFixed(1)}');
      },
      setWindowBrightness: (v) async => calls.add('bright:$v'),
      setMpvVolume: (v) async {
        fakeMpvVolume = v;
        calls.add('mpv:${v.toStringAsFixed(1)}');
      },
      setPlaybackRate: (v) async => calls.add('rate:${v.toStringAsFixed(2)}'),
      seek: (p) async => calls.add('seek:${p.inMilliseconds}'),
      readPosition: () => fakePosition,
      readDuration: () => fakeDuration,
    );
    await s.initFromDevice();
    calls.clear();
    return s;
  }

  /// 垂直滑动 [steps] 次、每次 [dy]，返回最后一次的指示器事件
  ({GestureIndicatorKind kind, double value, bool boosting})? swipe(
    PlayerSessionState s,
    double dy,
    int steps, {
    bool isLeftHalf = false,
    double height = 1000,
  }) {
    ({GestureIndicatorKind kind, double value, bool boosting})? last;
    for (var i = 0; i < steps; i++) {
      final e = s.verticalSwipe(dy, isLeftHalf, height);
      if (e != null) last = e;
    }
    return last;
  }

  group('音量手势（P1-1 音量增强，横竖屏共用同一实现）', () {
    test('增强关闭：上滑只抬系统音量，最高 100%', () async {
      final s = await build();
      final e = swipe(s, -100, 20); // 每次 10（100/1000*100）
      expect(e, isNotNull);
      expect(e!.boosting, isFalse);
      expect(e.value, 100);
      expect(fakeSystemVolume, 100);
      // 增强关闭时不会动 mpv 增益
      expect(calls.where((c) => c.startsWith('mpv:')), isEmpty);
      expect(fakeMpvVolume, 100);
    });

    test('增强开启：系统音量满 100% 后上滑接管 mpv 增益，指示器显示 >100%', () async {
      await settings.setVolumeBoostEnabled(true);
      await settings.setVolumeBoostCap(60); // 上限 160%
      final s = await build();
      // 起点系统 50，每档 +10：5 档刚好把系统音量推到 100（还没有溢出）
      swipe(s, -100, 5);
      expect(fakeSystemVolume, 100);
      expect(fakeMpvVolume, 100, reason: '跨过 100% 的那一档不产生增益溢出');
      // 第 6 档起溢出转 mpv 增益
      final e = swipe(s, -100, 1);
      expect(fakeMpvVolume, 110);
      expect(e!.boosting, isTrue);
      expect(e.value, 110);
      expect(e.kind, GestureIndicatorKind.volume);
    });

    test('增强段下滑：先退 mpv 增益，触底后转回系统音量段', () async {
      await settings.setVolumeBoostEnabled(true);
      await settings.setVolumeBoostCap(60);
      final s = await build();
      swipe(s, -100, 5); // 系统 100
      swipe(s, -100, 2); // mpv 120
      expect(fakeMpvVolume, 120);
      // 下滑 1 档：mpv 120 → 110，仍在增强段
      final boosted = swipe(s, 100, 1);
      expect(fakeMpvVolume, 110);
      expect(boosted!.boosting, isTrue);
      // 再下滑 1 档：mpv 触底 100，同档继续降系统音量（100 → 90）
      final back = swipe(s, 100, 1);
      expect(fakeMpvVolume, 100);
      expect(fakeSystemVolume, 90);
      expect(back!.boosting, isFalse);
      expect(back.value, 90);
    });

    test('增强上限封顶：不会超过 100+cap', () async {
      await settings.setVolumeBoostEnabled(true);
      await settings.setVolumeBoostCap(20); // 最高 120%
      final s = await build();
      swipe(s, -100, 10);
      swipe(s, -100, 10);
      expect(fakeMpvVolume, 120);
    });

    test('亮度手势：左半屏只调窗口亮度，不动音量', () async {
      final s = await build();
      // 初始亮度 1.0（最亮）→ 下滑 3 档降低（每档 0.1）
      final e = swipe(s, 100, 3, isLeftHalf: true);
      expect(e!.kind, GestureIndicatorKind.brightness);
      expect(e.value, closeTo(0.7, 0.0001));
      expect(calls.where((c) => c.startsWith('sys:')), isEmpty);
    });
  });

  group('杜比引导去重（B4/P1-6：横竖屏两条触发路径）', () {
    test('同一路径只认领一次（横屏检测过，竖屏 push 时不再重复弹窗）', () async {
      final s = await build();
      expect(s.claimDolbyCheck('/media/dv.mkv'), isTrue);
      expect(s.claimDolbyCheck('/media/dv.mkv'), isFalse);
      expect(s.dolbyCheckedPath, '/media/dv.mkv');
    });

    test('切到新媒体会重新认领（切走再切回同样重新检测）', () async {
      final s = await build();
      expect(s.claimDolbyCheck('/a.mkv'), isTrue);
      expect(s.claimDolbyCheck('/b.mkv'), isTrue);
      // 只记住「最后一次认领的路径」：作用是同一媒体在横竖屏两条触发路径
      // 之间去重（横屏 open 认领过 → 竖屏 push 不再重复弹）。
      // 切回旧媒体会重新检测一次——与修复前横屏页「切集即重新检测」一致，
      // 用户已勾「不再提示」时由 DolbyVisionSettings.suppressed 持久拦下。
      expect(s.claimDolbyCheck('/a.mkv'), isTrue);
      expect(s.claimDolbyCheck('/a.mkv'), isFalse);
    });

    test('空路径不认领（避免把「无媒体」记成已检测）', () async {
      final s = await build();
      expect(s.claimDolbyCheck(''), isFalse);
      expect(s.dolbyCheckedPath, isNull);
    });
  });

  group('倍速唯一真值（P1-2）', () {
    test('setRate 写入播放器并通知监听者；remember 时写入设置', () async {
      final s = await build();
      var notifierHits = 0;
      var sessionHits = 0;
      s.rateListenable.addListener(() => notifierHits++);
      s.addListener(() => sessionHits++);
      s.setRate(2.0);
      s.setRate(2.0, remember: false);
      expect(s.rate, 2.0);
      // ValueNotifier 只在值变化时通知（两次 2.0 → 1 次）；ChangeNotifier 每次都通知
      expect(notifierHits, 1);
      expect(sessionHits, 2);
      expect(calls.where((c) => c == 'rate:2.00').length, 2);
      // 写记忆是异步的（unawaited(_settings.setSpeed)）
      await Future.delayed(const Duration(milliseconds: 10));
      expect(settings.lastSpeed, 2.0);
    });

    test('临时倍速（长按）不改用户选定倍速，恢复时回到用户值', () async {
      final s = await build();
      s.setRate(2.0);
      s.applyTemporaryRate(3.5);
      expect(s.rate, 2.0, reason: '长按期间面板/恢复基准仍是用户选定倍速');
      s.restoreRateAfterTemporary();
      expect(calls.last, 'rate:2.00');
    });

    test('倍速记忆开启时按上次倍速初始化', () async {
      await settings.setRememberSpeed(true);
      await settings.setSpeed(1.5);
      final s = await build();
      expect(s.rate, 1.5);
    });
  });

  group('水平滑动 seek（P1-4 撤销）', () {
    test('updateSwipe 产生浮层数据并节流后 seek', () async {
      final s = await build();
      fakePosition = const Duration(minutes: 1);
      s.beginSwipe();
      s.updateSwipe(400, 800); // 满屏 90 秒 → 400px = 45 秒
      expect(s.swipeSeekVisible, isTrue);
      expect(s.swipeSeekData!.target, const Duration(minutes: 1, seconds: 45));
      expect(s.swipeSeekData!.delta, const Duration(seconds: 45));
      expect(calls.last, 'seek:105000');
    });

    test('cancelSwipe 撤销已发生的 seek 并清掉浮层（竖屏原先空实现）', () async {
      final s = await build();
      fakePosition = const Duration(minutes: 1);
      s.beginSwipe();
      s.updateSwipe(400, 800);
      calls.clear();
      s.cancelSwipe();
      expect(calls, contains('seek:60000'), reason: '落点必须回到滑动起点');
      expect(s.swipeSeekData, isNull);
      expect(s.swipeSeekVisible, isFalse);
    });

    test('cancelSwipe 未滑动过时不 seek（点按缩放不产生副作用）', () async {
      final s = await build();
      s.beginSwipe();
      calls.clear();
      s.cancelSwipe();
      expect(calls, isEmpty);
    });

    test('endSwipe 保留浮层数据 250ms 让淡出动画播完', () async {
      final s = await build();
      fakePosition = const Duration(minutes: 1);
      s.beginSwipe();
      s.updateSwipe(80, 800);
      s.endSwipe();
      expect(s.swipeSeekVisible, isFalse);
      expect(s.swipeSeekData, isNotNull);
      await Future.delayed(const Duration(milliseconds: 300));
      expect(s.swipeSeekData, isNull);
    });

    test('时长未知时不产生浮层（不 seek）', () async {
      final s = await build();
      fakeDuration = Duration.zero;
      s.beginSwipe();
      s.updateSwipe(400, 800);
      expect(s.swipeSeekData, isNull);
      expect(calls, isEmpty);
    });
  });

  group('双指缩放 / 平移（D6 竖屏与横屏同口径）', () {
    ScaleUpdateDetails update({
      required double scale,
      double focalX = 400,
      double focalY = 300,
      Offset delta = Offset.zero,
    }) =>
        ScaleUpdateDetails(
          scale: scale,
          localFocalPoint: Offset(focalX, focalY),
          focalPointDelta: delta,
        );

    test('缩放区间 0.75–4.0（允许缩小时）', () async {
      final s = await build();
      expect(settings.enableShrinkVideo, isTrue);
      s.zoomStart();
      s.zoomUpdate(update(scale: 0.1), viewportWidth: 800, viewportHeight: 600);
      expect(s.zoomScale, 0.75);
      s.zoomStart();
      s.zoomUpdate(update(scale: 100), viewportWidth: 800, viewportHeight: 600);
      expect(s.zoomScale, 4.0);
    });

    test('禁止缩小时下限为 1.0', () async {
      await settings.setEnableShrinkVideo(false);
      final s = await build();
      s.zoomStart();
      s.zoomUpdate(update(scale: 0.2), viewportWidth: 800, viewportHeight: 600);
      expect(s.zoomScale, 1.0);
    });

    test('平移被钳制在画面内（不露黑边）', () async {
      final s = await build();
      s.zoomStart();
      s.zoomUpdate(update(scale: 2.0, delta: const Offset(9999, 9999)), viewportWidth: 800, viewportHeight: 600);
      // 2 倍时最大平移 = (2-1)*800/2 = 400，(2-1)*600/2 = 300
      expect(s.zoomOffset.dx, 400);
      expect(s.zoomOffset.dy, 300);
      final m = s.zoomMatrix(800, 600);
      expect(m.storage[0], 2.0); // 缩放分量
    });

    test('缩放回 1.0 时归中并视为未缩放（隐藏「还原画面」）', () async {
      final s = await build();
      s.zoomStart();
      s.zoomUpdate(update(scale: 2.0), viewportWidth: 800, viewportHeight: 600);
      s.zoomStart();
      s.zoomUpdate(update(scale: 0.5), viewportWidth: 800, viewportHeight: 600);
      s.zoomEnd();
      expect(s.zoomScale, 1.0);
      expect(s.zoomOffset, Offset.zero);
      expect(s.zoomed, isFalse);
    });

    test('resetZoom 立即还原', () async {
      final s = await build();
      s.zoomStart();
      s.zoomUpdate(update(scale: 3.0), viewportWidth: 800, viewportHeight: 600);
      expect(s.zoomed, isTrue);
      s.resetZoom();
      expect(s.zoomed, isFalse);
    });
  });
}
