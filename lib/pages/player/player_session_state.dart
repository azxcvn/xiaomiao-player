/// 播放页「横竖屏共享」的会话状态（B4 / 决策 D2 治本方案）。
///
/// **为什么需要它**：`player_page.dart`（横屏）与 `player_portrait_page.dart`
/// （竖屏）历史上各自维护一份音量/倍速/手势实现（54 个同名私有方法），长期漂移，
/// 体检报告 P1-1/P1-2/P1-4/P1-5 都是同一根因的不同表现：
/// - P1-1 竖屏没有音量增强 → 横屏把 mpv `volume-max` 提到 100+cap、增益 150%
///   后切竖屏，竖屏的手势只调系统音量（clamp 到 100 后彻底空转），
///   指示器仍显示 100% = **UI 谎报响度**；
/// - P1-2 竖屏倍速基准取自设置（倍速记忆默认关）而非播放器真实倍速 →
///   长按倍速松手把用户的 2.0x 复位成 1.0x；
/// - P1-4 竖屏 `onSwipeCancel: () {}` → 误触 seek 不撤销；
/// - P1-5 竖屏剩余时长未钳制负值 → 显示 `-59:55`。
///
/// 本对象把这几类**必须两页一致**的状态与数学收敛到一处：音量（系统 +
/// mpv 增益 + 增强上限）、亮度、倍速、水平滑动 seek、双指缩放/平移。
/// 两页只保留各自的 UI 壳（指示器显隐、浮层渲染、setState）。
///
/// **生命周期**：由横屏页创建并持有、经构造函数注入竖屏页（与
/// `chapterTracker` / `subtitleController` 同款）；竖屏页不 dispose 共享实例。
/// **禁止做成全局单例**（§4.1：设置/播放器状态一律页面或服务持有）。
///
/// **可测性**：对播放器与系统的副作用全部经可注入回调（默认直连
/// [DeviceServices] 与 media_kit [Player]），单测可传假实现、不传 [player]
/// （media_kit `Player` 需要原生库，单测环境构造不出来）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/pages/player/views/player_gesture_indicator.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/utils/player_gestures.dart';

/// 垂直滑动的结果：调用方据此显示手势指示器（null = 本次无变化，不显示）
typedef GestureIndicatorEvent = ({
  GestureIndicatorKind kind,
  double value,
  bool boosting,
});

/// 水平滑动 seek 的浮层数据（目标位置 + 相对起点的位移）
typedef SwipeSeekData = ({Duration target, Duration delta});

class PlayerSessionState extends ChangeNotifier {
  PlayerSessionState({
    Player? player,
    PlayerControlsSettings? settings,
    Future<void> Function(double percent)? setSystemVolume,
    Future<void> Function(double? value)? setWindowBrightness,
    Future<void> Function(double volume)? setMpvVolume,
    Future<void> Function(double rate)? setPlaybackRate,
    Future<void> Function(Duration position)? seek,
    Duration Function()? readPosition,
    Duration Function()? readDuration,
  })  : _player = player,
        _settings = settings ?? PlayerControlsSettings.instance,
        _setSystemVolume = setSystemVolume ?? DeviceServices.setSystemVolume,
        _setWindowBrightness =
            setWindowBrightness ?? DeviceServices.setWindowBrightness,
        _setMpvVolume =
            setMpvVolume ?? ((v) async => await player?.setVolume(v)),
        _setPlaybackRate =
            setPlaybackRate ?? ((v) async => await player?.setRate(v)),
        _seek = seek ?? ((p) async => await player?.seek(p)),
        _readPosition =
            readPosition ?? (() => player?.state.position ?? Duration.zero),
        _readDuration =
            readDuration ?? (() => player?.state.duration ?? Duration.zero) {
    // 倍速记忆：启用时恢复上次倍速，否则本次会话从 1.0x 开始
    _rate.value = _settings.rememberSpeed ? _settings.lastSpeed : 1.0;
  }

  final Player? _player;
  final PlayerControlsSettings _settings;

  final Future<void> Function(double percent) _setSystemVolume;
  final Future<void> Function(double? value) _setWindowBrightness;
  final Future<void> Function(double volume) _setMpvVolume;
  final Future<void> Function(double rate) _setPlaybackRate;
  final Future<void> Function(Duration position) _seek;
  final Duration Function() _readPosition;
  final Duration Function() _readDuration;

  bool _disposed = false;

  // ── 倍速（唯一真值，P1-2）─────────────────────────────────

  final ValueNotifier<double> _rate = ValueNotifier(1.0);

  /// 用户选定的播放倍速（横竖屏读同一份；倍速面板 `speedListenable` 用它）
  ValueListenable<double> get rateListenable => _rate;

  /// 用户选定的播放倍速值
  double get rate => _rate.value;

  /// 应用用户选定的倍速（[remember] 时写入「倍速记忆」设置）
  void setRate(double v, {bool remember = true}) {
    _rate.value = v;
    unawaited(_setPlaybackRate(v));
    if (remember) unawaited(_settings.setSpeed(v));
    _notify();
  }

  /// 长按期间的**临时**倍速：只改播放器，不改用户选定倍速
  /// （倍速面板/长按结束的恢复基准仍是用户选定值）
  void applyTemporaryRate(double v) => unawaited(_setPlaybackRate(v));

  /// 长按结束：恢复用户选定倍速（不再依赖各页自己缓存的「长按前倍速」）
  void restoreRateAfterTemporary() => unawaited(_setPlaybackRate(_rate.value));

  // ── 杜比视界引导去重（B4/P1-6）─────────────────────────────

  /// 已认领过杜比检测的媒体路径（横竖屏两条触发路径共用同一标记）。
  ///
  /// 为什么要跨页去重：同一个媒体既可能在横屏页 open 时被检测，也可能在
  /// 竖屏页被 push / 切集时被检测——两页各自记 bool 就会「先横后竖」重复弹窗，
  /// 而按**路径**记还顺带解决「切回旧媒体不再重复弹」。
  String? _dolbyCheckedPath;

  /// 已认领检测的媒体路径（测试/诊断用）
  String? get dolbyCheckedPath => _dolbyCheckedPath;

  /// 认领一次杜比检测：返回 true = 由调用方执行检测并（必要时）弹引导；
  /// 返回 false = 该路径已被另一页认领（或路径为空），本次跳过。
  bool claimDolbyCheck(String path) {
    if (path.isEmpty || _dolbyCheckedPath == path) return false;
    _dolbyCheckedPath = path;
    return true;
  }

  // ── 音量 / 亮度（P1-1 / P1-5）──────────────────────────────

  /// 当前系统媒体音量（0 – 100）：手势直控系统音量 = 真实响度
  double _systemVolume = 50;

  /// 当前 mpv 增益音量（100 = 无增益；100 ~ 100+cap 为音量增强段）
  double _mpvVolume = 100;

  /// 音量增强上限（百分比；增强开关关闭时为 0）
  int _boostCap = 0;

  /// 进入播放前的系统音量（退出时按设置写回或恢复）
  double? _initialSystemVolume;

  /// 当前亮度（0 – 1，窗口亮度）
  double _brightness = 1.0;

  /// 音量/亮度浮点累加器（小步长滑动不丢失，参考 kt 项目）
  double _volumeAccum = 0;
  double _brightnessAccum = 0;

  double get systemVolume => _systemVolume;
  double get mpvVolume => _mpvVolume;
  int get boostCap => _boostCap;
  double? get initialSystemVolume => _initialSystemVolume;
  double get brightness => _brightness;

  /// 音量增强当前是否生效（开关开启且上限 > 0）
  bool get boostEnabled => _settings.volumeBoostEnabled && _boostCap > 0;

  /// 当前应展示的音量百分比（增强段可 > 100%；P1-1 指示器不再谎报）
  double get displayVolume =>
      displayVolumePercent(_systemVolume, _mpvVolume, boostEnabled: boostEnabled);

  /// 是否正处于「音量增强」段（指示器红色样式）
  bool get boosting =>
      isVolumeBoosting(_systemVolume, _mpvVolume, boostEnabled: boostEnabled);

  /// 进入播放：读系统音量/亮度作为本次会话起点，并把 mpv `volume-max`
  /// 扩展到 `100 + cap`（增强段上限），mpv 音量固定 100（0dB 增益）。
  Future<void> initFromDevice() async {
    final vol = await DeviceServices.getSystemVolume();
    _initialSystemVolume = vol;
    _systemVolume = vol ?? 50;
    _boostCap =
        _settings.volumeBoostEnabled ? _settings.volumeBoostCap : 0;
    _mpvVolume = 100;
    final player = _player;
    if (player != null) {
      try {
        final native = player.platform as NativePlayer;
        await native.waitForPlayerInitialization;
        await native.setProperty(
          'volume-max',
          '${mpvVolumeMaxForBoost(_boostCap)}',
        );
        await player.setVolume(100);
      } on AssertionError {
        // 播放器已被销毁（快速退出）：后续操作放弃
        return;
      } catch (_) {
        // waitForPlayerInitialization / setProperty 失败不影响音量基准
        try {
          await player.setVolume(100);
        } on AssertionError {
          return;
        }
      }
      if (_disposed) return;
    }
    final brightness = await DeviceServices.getBrightness();
    if (brightness != null) {
      _brightness = brightness;
      // 锁到窗口，使屏幕显示与指示器一致（播放期间亮度不随自动亮度漂移）
      await _setWindowBrightness(brightness);
    }
    _notify();
  }

  /// 退出播放：亮度交还系统（-1）、mpv 增益复位 100、系统音量按设置
  /// 写回（保存到系统）或恢复进入前的值。
  Future<void> restoreToDevice() async {
    await _setWindowBrightness(null);
    if (_mpvVolume > 100) {
      // 播放器销毁前尽力复位，防增益泄漏到下一次播放
      try {
        await _setMpvVolume(100);
      } catch (_) {}
      _mpvVolume = 100;
    }
    if (!_settings.saveVolumeToSystem) {
      await _setSystemVolume(_initialSystemVolume ?? _systemVolume);
    }
  }

  /// 垂直滑动（左半屏亮度 / 右半屏音量）。返回需要显示的指示器状态；
  /// null = 本次位移未积累出整数档或数值未变（无需刷新指示器）。
  ///
  /// 音量语义（v3 用户反馈 + 音量增强，§4.8/§4.23）：
  /// 1. 系统音量段：直控系统媒体音量 0 – 100；
  /// 2. 增强段（增强开启 + 系统音量满 100% + mpv 已有增益）：超额位移接管
  ///    mpv 增益 100 ~ 100+cap，指示器红色显示 110%~200%；
  /// 3. 增强段下滑：先回退 mpv 增益，触底 100 后转回系统音量段；
  /// 4. 系统音量段上滑跨过 100% 的那一帧：溢出位移转入 mpv 增益。
  GestureIndicatorEvent? verticalSwipe(
    double dyDelta,
    bool isLeftHalf,
    double viewportHeight,
  ) {
    if (viewportHeight <= 0) return null;
    if (isLeftHalf) return _brightnessSwipe(dyDelta, viewportHeight);
    return _volumeSwipe(dyDelta, viewportHeight);
  }

  GestureIndicatorEvent? _brightnessSwipe(double dyDelta, double viewportHeight) {
    _brightnessAccum +=
        brightnessDeltaForSwipe(
          dyDelta,
          viewportHeight,
          _settings.brightnessSensitivity,
        ) *
        100;
    final intDelta = _brightnessAccum.truncate();
    if (intDelta == 0) return null;
    _brightnessAccum -= intDelta;
    final newB = (_brightness * 100 + intDelta).clamp(0.0, 100.0) / 100;
    if ((newB - _brightness).abs() <= 0.0001) return null;
    _brightness = newB;
    unawaited(_setWindowBrightness(newB));
    _notify();
    return (
      kind: GestureIndicatorKind.brightness,
      value: newB,
      boosting: false,
    );
  }

  GestureIndicatorEvent? _volumeSwipe(double dyDelta, double viewportHeight) {
    final boostOn = boostEnabled;
    _volumeAccum +=
        volumeDeltaForSwipe(
          dyDelta,
          viewportHeight,
          _settings.volumeSensitivity,
        );
    final intDelta = _volumeAccum.truncate();
    if (intDelta == 0) return null;
    _volumeAccum -= intDelta;

    // 增强段：系统音量满 100% 且 mpv 已有增益（上滑续增、下滑回减，触底降系统）
    if (boostOn && _systemVolume >= 100.0 && _mpvVolume > 100.0) {
      final newMpv = (_mpvVolume + intDelta)
          .clamp(100.0, mpvVolumeMaxForBoost(_boostCap).toDouble());
      if ((newMpv - _mpvVolume).abs() > 0.001) {
        _mpvVolume = newMpv;
        unawaited(_setMpvVolume(newMpv));
        _notify();
      }
      if (_mpvVolume > 100.0) {
        return (
          kind: GestureIndicatorKind.volume,
          value: displayVolumePercent(100, _mpvVolume, boostEnabled: true),
          boosting: true,
        );
      }
      if (intDelta < 0) {
        // mpv 增益触底 100，继续下滑 → 转回系统音量段
        final newV = (_systemVolume + intDelta).clamp(0.0, 100.0);
        if ((newV - _systemVolume).abs() <= 0.001) return null;
        _systemVolume = newV;
        unawaited(_setSystemVolume(newV));
        _notify();
        return (
          kind: GestureIndicatorKind.volume,
          value: newV,
          boosting: false,
        );
      }
      return null;
    }

    // 系统音量段：先调系统音量（0-100）
    final prevVolume = _systemVolume;
    final newV = (_systemVolume + intDelta).clamp(0.0, 100.0);
    if ((newV - _systemVolume).abs() > 0.001) {
      _systemVolume = newV;
      unawaited(_setSystemVolume(newV));
      _notify();
    }
    // 本帧上滑跨过 100%（从 <100 冲到 100 且仍有溢出）：溢出部分转入 mpv 增益
    if (boostOn && intDelta > 0 && _systemVolume >= 100.0) {
      final overflow = prevVolume + intDelta - 100.0;
      if (overflow > 0) {
        final newMpv = (_mpvVolume + overflow)
            .clamp(100.0, mpvVolumeMaxForBoost(_boostCap).toDouble());
        _mpvVolume = newMpv;
        unawaited(_setMpvVolume(newMpv));
        _notify();
        return (
          kind: GestureIndicatorKind.volume,
          value: displayVolumePercent(100, _mpvVolume, boostEnabled: true),
          boosting: true,
        );
      }
    }
    return (
      kind: GestureIndicatorKind.volume,
      value: newV,
      boosting: false,
    );
  }

  /// 清空手势累加器（每次方向滑动开始时调用，避免跨手势残留）
  void resetGestureAccumulators() {
    _volumeAccum = 0;
    _brightnessAccum = 0;
  }

  // ── 水平滑动 seek（P1-4：撤销逻辑只此一份）──────────────────

  Duration _swipeSeekStart = Duration.zero;
  SwipeSeekData? _swipeSeekData;
  bool _swipeSeekVisible = false;
  Timer? _swipeSeekClearTimer;
  DateTime? _lastSwipeSeekTime;

  SwipeSeekData? get swipeSeekData => _swipeSeekData;
  bool get swipeSeekVisible => _swipeSeekVisible;

  /// 单指方向滑动开始：记录 seek 起点 + 清空累加器
  void beginSwipe() {
    _swipeSeekStart = _readPosition();
    resetGestureAccumulators();
  }

  /// 水平滑动：节流 40ms 实时 seek，并刷新浮层数据（每帧可见）
  void updateSwipe(double totalDx, double viewportWidth) {
    final duration = _readDuration();
    if (duration <= Duration.zero || viewportWidth <= 0) return;
    final target = swipeSeekTarget(
      _swipeSeekStart,
      totalDx,
      viewportWidth,
      duration,
    );
    final now = DateTime.now();
    if (_lastSwipeSeekTime == null ||
        now.difference(_lastSwipeSeekTime!) >=
            const Duration(milliseconds: 40)) {
      _lastSwipeSeekTime = now;
      unawaited(_seek(target));
    }
    _swipeSeekClearTimer?.cancel();
    _swipeSeekData = (target: target, delta: target - _swipeSeekStart);
    _swipeSeekVisible = true;
    _notify();
  }

  /// 单指滑动结束：浮层淡出（数据保留 250ms 让浮层播完淡出动画）
  void endSwipe() {
    _swipeSeekVisible = false;
    _lastSwipeSeekTime = null;
    _swipeSeekClearTimer?.cancel();
    _swipeSeekClearTimer = Timer(const Duration(milliseconds: 250), () {
      _swipeSeekData = null;
      _notify();
    });
    _notify();
  }

  /// 单指滑动被双指手势打断（意图改为缩放）：**撤销已发生的 seek**
  /// （P1-4：竖屏原先传空实现，误触 seek 不撤销、落点停在误触位置）
  void cancelSwipe() {
    final duration = _readDuration();
    if (_swipeSeekData != null && duration > Duration.zero) {
      unawaited(_seek(_swipeSeekStart));
    }
    discardSwipe();
  }

  /// 丢弃滑动 seek 浮层状态（不撤销 seek）：切集/重置时用，
  /// 避免上一集的浮层在新集上闪现
  void discardSwipe() {
    _swipeSeekVisible = false;
    _swipeSeekClearTimer?.cancel();
    _lastSwipeSeekTime = null;
    _swipeSeekData = null;
    _notify();
  }

  // ── 双指缩放 / 平移（D6：竖屏与横屏同口径）──────────────────

  double _zoomScale = 1.0;
  Offset _zoomOffset = Offset.zero;
  double? _zoomStartScale;

  double get zoomScale => _zoomScale;
  Offset get zoomOffset => _zoomOffset;

  /// 是否已缩放/平移（「还原画面」胶囊的显示条件）
  bool get zoomed => _zoomScale != 1.0 || _zoomOffset != Offset.zero;

  void zoomStart() => _zoomStartScale = _zoomScale;

  /// [viewportWidth]/[viewportHeight] 由**调用页**传入，不缓存在共享状态里：
  /// 横竖屏视口尺寸不同，被遮住的那一页仍可能因 setState 重建并写缓存，
  /// 会把当前可见页的尺寸覆盖掉（缩放边界随之算错）。
  void zoomUpdate(
    ScaleUpdateDetails d, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final start = _zoomStartScale;
    if (start == null) return;
    final minScale = _settings.enableShrinkVideo ? 0.75 : 1.0;
    // 双指最大放大倍率：4.0（最小受「允许缩小画面」设置控制）
    final newScale = (start * d.scale).clamp(minScale, 4.0);
    final ratio = newScale / _zoomScale;
    final focal = d.localFocalPoint;
    // 以双指焦点为中心缩放，再跟随焦点移动平移（PiliPlus 同款）
    _zoomOffset = focal - (focal - _zoomOffset) * ratio;
    _zoomScale = newScale;
    _zoomOffset += d.focalPointDelta;
    _zoomOffset = _clampZoomOffset(
      _zoomOffset,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    _notify();
  }

  void zoomEnd() {
    _zoomStartScale = null;
    if (_zoomScale == 1.0) _zoomOffset = Offset.zero;
    _notify();
  }

  void resetZoom() {
    _zoomScale = 1.0;
    _zoomOffset = Offset.zero;
    _notify();
  }

  /// 缩放平移边界：画面不能露出黑边（缩放 1 倍时归中）
  Offset _clampZoomOffset(
    Offset offset, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (viewportWidth <= 0 || viewportHeight <= 0) return offset;
    final maxDx = ((_zoomScale - 1).abs() * viewportWidth) / 2;
    final maxDy = ((_zoomScale - 1).abs() * viewportHeight) / 2;
    return Offset(
      offset.dx.clamp(-maxDx, maxDx),
      offset.dy.clamp(-maxDy, maxDy),
    );
  }

  /// 画面缩放矩阵：以视口中心为缩放原点，再按 [_zoomOffset] 平移。
  /// 显示时再钳制一次（横竖屏切换后视口尺寸变化，旧的偏移量可能越界）。
  Matrix4 zoomMatrix(double viewportWidth, double viewportHeight) {
    final w = viewportWidth / 2;
    final h = viewportHeight / 2;
    final offset = _clampZoomOffset(
      _zoomOffset,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    return Matrix4.identity()
      ..translateByDouble(offset.dx + w, offset.dy + h, 0, 1)
      ..scaleByDouble(_zoomScale, _zoomScale, _zoomScale, 1)
      ..translateByDouble(-w, -h, 0, 1);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _swipeSeekClearTimer?.cancel();
    _rate.dispose();
    super.dispose();
  }
}
