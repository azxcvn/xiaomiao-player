import 'package:flutter/services.dart';
import 'package:moumou/models/player_action.dart';

/// 播放页方向策略（横屏页 / 竖屏页 / 听视频页共用一份，避免各处硬编码漂移）。
///
/// ⚠️ 播放期的方向是**临时**的：退出播放必须走 [restoreAppDefault] 把方向
/// 策略交还系统。历史 bug（用户反馈）：退出播放时把方向钉成 `portraitUp`
/// 后再没恢复，Activity 的 `requestedOrientation` 一直停在竖屏——用户开着
/// 系统自动旋转，退出播放后 App 却永远竖屏、左右横屏都不生效（VR 眼镜
/// 横屏进入、播完一个视频就变竖屏，只能重启 App），根因就是少了这条恢复路径。
class PlayerOrientation {
  const PlayerOrientation._();

  /// App 默认方向策略 = **不指定任何方向**（原生 `SCREEN_ORIENTATION_UNSPECIFIED`）：
  /// 交还系统决定，跟随系统「自动旋转」开关与用户当前的旋转锁定，等价于
  /// 进播放器之前 App 的行为（AndroidManifest 未声明 `screenOrientation`）。
  static const List<DeviceOrientation> appDefault = <DeviceOrientation>[];

  /// 锁定竖屏（「视频方向 = 锁定竖屏」/ 竖屏播放页）
  static const List<DeviceOrientation> portrait = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  /// 锁定横屏（「视频方向 = 锁定横屏」/ 横屏播放页）
  static const List<DeviceOrientation> landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// 恢复 App 默认方向策略：退出播放 / 销毁播放页时调用。
  ///
  /// 不 await（退出路径要立刻 pop，方向与保存进度并行；调用方用 `unawaited`）。
  static Future<void> restoreAppDefault() =>
      SystemChrome.setPreferredOrientations(appDefault);
}

/// 由「编码宽高 + 旋转角」判断**显示方向**是否为竖屏；尺寸未知返回 null。
///
/// 手机竖拍视频常见「编码尺寸是横屏 + rotation 90/270」，显示方向要交换宽高，
/// 只按 `width > height` 判会误判成横屏。算法与 mpv `video-params` 的判定一致
/// （也同参考实现 mpvRx 的 `PlayerActivity.applyInitialVideoOrientation`）：
/// 旋转 90/270 → 互换宽高；宽 ≤ 高即竖屏（正方形按竖屏处理，与历史行为一致）。
bool? isPortraitDisplay({
  required int width,
  required int height,
  int rotation = 0,
}) {
  if (width <= 0 || height <= 0) return null;
  final normalized = ((rotation % 360) + 360) % 360;
  final swapped = normalized == 90 || normalized == 270;
  final displayWidth = swapped ? height : width;
  final displayHeight = swapped ? width : height;
  return displayWidth <= displayHeight;
}

/// 播放界面是否「跟随手机方向」（横竖屏由重力感应 / 系统自动旋转决定）。
///
/// 三个条件同时成立才生效：
/// - 设置开关「界面跟随重力旋转」（设置-播放设置-视频方向，默认关闭）；
/// - 「视频方向」= 自动（锁定竖屏 / 锁定横屏是用户的明确指定，优先级更高）；
/// - 系统「自动旋转」开着——关掉时系统根本不会转窗口，跟随只会退化成
///   「固定在当前方向」，所以直接回落到「按视频方向」的原有行为。
bool shouldFollowPhoneOrientation({
  required VideoOrientationMode mode,
  required bool followPhoneRotation,
  required bool systemAutoRotate,
}) =>
    followPhoneRotation &&
    systemAutoRotate &&
    mode == VideoOrientationMode.auto;
