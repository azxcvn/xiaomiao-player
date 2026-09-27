/// 解码档位的自动回退（用户反馈：默认「硬解+」，设备不支持时要自己降档，
/// 并且**要让用户看见**——解码面板的胶囊跟着切 + toast 说明）。
///
/// ## 判定依据
///
/// 唯一可信的「实际生效档」是 mpv 运行时的 `hwdec-current`：
/// - `mediacodec` → 直通生效（硬解+）；
/// - `mediacodec-copy` → 直通不可用、拷回生效（硬解）；
/// - `no` → 硬件解码没起来（软解）。
///
/// `hwdec-current` 在**没有视频轨 / 还没建立视频链（mpv 要等第一帧输出后
/// 才让该属性可读）**时读不到（空串或报错），此时一律**不回退**：读不准就
/// 不动，绝不猜（读到的值只认精确匹配，像 `mediacodec,mediacodec-copy,no`
/// 这种原样回读的请求串不参与判定）。
///
/// ⚠️ `mediacodec` 直通失败的原因**不是** `vo=gpu`：Android 上直通靠
/// `hwdec_aimagereader.c` 读帧，`vo=gpu` 本身是支持的；失败的常见来源是
/// 设备/驱动，或渲染后端启用了 Vulkan（aimagereader 只支持 OpenGL 读取）。
/// 所以提示文案说「当前设备/渲染后端」，不把它一口咬定成设备的问题。
///
/// ## 为什么「软解」那一步要看设备能力
///
/// 「硬解+」直通失败 → 落到「硬解」是渲染器/直通层面的结论，降档无副作用；
/// 但 `hwdec-current == no` 只是**这一部视频**没硬解起来（例如设备没有 AV1
/// 硬解器）。直接把全局设置写死成「软解」，会让之后所有有硬解的 H.264/H.265
/// 也一起被迫软解——所以只有**设备整机没有任何硬件视频解码器**时才写设置，
/// 否则只提示（用户自己决定要不要手动降档）。
library;

import 'package:flutter/foundation.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/device_services.dart';

/// 实际生效档的提示文案（toast / 日志共用，避免两处漂移）
const String kDecodeFallbackHwCopyMessage = '当前设备/渲染后端不支持硬解+ 直通，已回退为「硬解」';
const String kDecodeFallbackSwMessage = '设备不支持硬件解码，已回退为「软解」';
const String kDecodeFallbackPerVideoMessage = '本视频硬解不可用，已用软解播放';

/// 把 mpv `hwdec-current` 归一成「实际生效的解码档」（纯函数，可单测）。
///
/// 只认精确值：读不到（null/空串）或读到不认识的值（含 mpv 原样回读请求串
/// 的情形）一律返回 null = **读不准，不参与判定**。
DecodeMode? effectiveDecodeFromHwdec(String? hwdecCurrent) {
  switch ((hwdecCurrent ?? '').trim().toLowerCase()) {
    case 'mediacodec':
      return DecodeMode.hwPlus;
    case 'mediacodec-copy':
      return DecodeMode.hwCopy;
    case 'no':
      return DecodeMode.sw;
    default:
      return null;
  }
}

/// 档位高低：硬解+ > 硬解 > 软解 > 自动（自动由 mpv 自己挑安全档，不参与比较）
int _decodeRank(DecodeMode mode) => switch (mode) {
      DecodeMode.hwPlus => 3,
      DecodeMode.hwCopy => 2,
      DecodeMode.sw => 1,
      DecodeMode.autoSafe => 0,
    };

/// 自动回退目标档（纯函数，可单测）：实际生效档**低于**所选档时回退到实际档。
///
/// - 选「自动」不回退（自动档由 mpv 挑安全档，语义上不承诺硬解）；
/// - 选「软解」不回退（已是最低档）；
/// - [effective] 为 null（读不到/不认识）→ 不回退。
DecodeMode? decodeFallbackTarget({
  required DecodeMode requested,
  required DecodeMode? effective,
}) {
  if (effective == null) return null;
  if (requested == DecodeMode.autoSafe || requested == DecodeMode.sw) return null;
  if (_decodeRank(effective) >= _decodeRank(requested)) return null;
  return effective;
}

/// 设备是否**整机没有任何硬件视频解码器**（纯函数，可单测）。
///
/// 取原生 `DeviceCapabilities.inspect` 的 `keyCodecs`（H.264 / H.265 / AV1 /
/// VP9 / 杜比视界）：五项都没有 `hasHardware` 才算「设备不支持硬解」。
/// 返回 null = **不知道**（能力表缺失/结构异常）——调用方据此保守处理，
/// 不拿「查不到」当「不支持」。
bool? deviceHasNoHardwareVideoDecoder(Map<String, dynamic>? capabilities) {
  final raw = capabilities?['keyCodecs'];
  if (raw is! List || raw.isEmpty) return null;
  var sawEntry = false;
  for (final entry in raw) {
    if (entry is! Map) continue;
    sawEntry = true;
    if (entry['hasHardware'] == true) return false;
  }
  return sawEntry ? true : null;
}

/// 读取设备能力表并判断「整机没有硬解器」；查不到返回 null（不知道）。
Future<bool?> readDeviceHasNoHardwareVideoDecoder() async {
  final caps = await DeviceServices.getDeviceCapabilities();
  return deviceHasNoHardwareVideoDecoder(caps);
}

/// 「本视频只能软解」提示的去重标记（每次 App 运行只提示一次，避免连看多集
/// 或连着播几个没硬解的编码时反复弹同一条 toast）。
bool _perVideoSoftHintShown = false;

/// 测试用：复位提示去重标记
@visibleForTesting
void resetDecodeFallbackHints() {
  _perVideoSoftHintShown = false;
}

/// 读 mpv 实际生效的 `hwdec-current`，按需自动回退解码档位。
///
/// 播放页在 `open` 完成后调用一次。返回**给用户看的提示文案**（null = 不用提示）；
/// 需要降档时本函数已把新档位写进 [settings]（解码面板胶囊随之切换）。
///
/// - [readProperty]：mpv 属性读取（播放页注入 `NativePlayer.getProperty`）；
/// - [hasVideoTrack]：当前媒体有没有视频轨。纯音频媒体 mpv 的 `hwdec-current`
///   会读成 `no`，那不是「设备不支持硬解」——没有视频轨就不判定（视频轨还没
///   上报时按「等下一轮」处理）；
/// - [settings] / [deviceHasNoHardwareDecoder]：测试注入用，默认走真实单例与
///   设备能力表；
/// - [retryDelay] / [maxAttempts]：视频链刚建立时 `hwdec-current` 可能还没值，
///   隔一会儿重试几次；全部读不到就放弃（不动设置、不提示）。
Future<String?> autoFallbackDecodeMode({
  required Future<String?> Function(String name) readProperty,
  bool Function()? hasVideoTrack,
  DecodeSettings? settings,
  Future<bool?> Function()? deviceHasNoHardwareDecoder,
  Duration retryDelay = const Duration(milliseconds: 600),
  int maxAttempts = 4,
}) async {
  final s = settings ?? DecodeSettings.instance;
  // 每次调用都以**当前**设置为准（切集期间用户可能刚改过档）
  final requested = s.mode;
  if (requested == DecodeMode.autoSafe || requested == DecodeMode.sw) return null;

  DecodeMode? effective;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (attempt > 0) await Future<void>.delayed(retryDelay);
    // 视频轨还没上报（或本来就是纯音频）：本轮不判定，等下一轮
    if (hasVideoTrack != null && !hasVideoTrack()) continue;
    effective = effectiveDecodeFromHwdec(await _readHwdecCurrent(readProperty));
    if (effective != null) break;
  }
  if (effective == null) return null; // 读不到/不认识：不动，绝不猜

  final target = decodeFallbackTarget(requested: requested, effective: effective);
  if (target == null) return null;

  if (target == DecodeMode.sw) {
    final noHw =
        await (deviceHasNoHardwareDecoder ?? readDeviceHasNoHardwareVideoDecoder)();
    if (noHw != true) {
      // 整机有硬解器 → 只是这一部视频（编码）没硬解起来：只提示，不改全局设置
      if (_perVideoSoftHintShown) return null;
      _perVideoSoftHintShown = true;
      return kDecodeFallbackPerVideoMessage;
    }
    await s.setMode(DecodeMode.sw);
    return kDecodeFallbackSwMessage;
  }

  await s.setMode(target);
  return kDecodeFallbackHwCopyMessage;
}

/// 读 mpv `hwdec-current`；异常/不可读一律返回 null（不把「读失败」当值用）。
Future<String?> _readHwdecCurrent(
  Future<String?> Function(String name) readProperty,
) async {
  try {
    return await readProperty('hwdec-current');
  } catch (_) {
    return null;
  }
}
