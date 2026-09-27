/// 解码链选择（纯函数，可单测）——对齐参照项目 MPVRX 的
/// `ui/player/RendererBackendPolicy.preferredHwdecMode`。
///
/// ## 为什么不再「事后读 hwdec-current 改设置」
///
/// 曾经的实现是：播放开始后读 mpv 的 `hwdec-current`，发现实际生效档低于用户
/// 所选档就把**全局设置改掉**并 toast。它有两个错：
///
/// 1. `hwdec-current` 是 mpv **每部视频、当下生效**的方法名。mpv 自己就会在解码
///    失败时按序降级（`vd_lavc.c` 的 `receive_frame → force_fallback`），所以
///    「这个文件正在用 `mediacodec-copy`」只是本次的兜底结果，**不是**「设备不
///    支持直通」。拿它当设备级结论，会把一次兜底写成永久降档。
/// 2. 用户手动选的档位不该被程序改掉。mpv 收到
///    `mediacodec,mediacodec-copy,no` 这条链后自己会尽力往下试，试到哪个是哪个，
///    界面如实显示即可 —— 与 MPVRX 一致（它的 `HW = mediacodec-copy`、
///    `HWPlus = mediacodec` 只是标签，从不回写设置）。
///
/// ## 现在怎么定链
///
/// 开播**前**按渲染后端判一次（MPVRX 同一思路）：
/// - OpenGL（本项目默认 `vo=gpu`）：直通可用 → «直通优先» 链；
/// - Vulkan（`gpu-next` + Vulkan 后端）：直通要构建期支持 MediaCodec→Vulkan 的
///   帧映射才成立，普通构建直接走拷贝链，**不白试一次直通**
///   （对应 MPVRX 注释 `Fongmi can map direct MediaCodec frames into Vulkan;
///   other Vulkan builds start with copy mode.`）。哪天换成支持该映射的内核，
///   把 [kBuildSupportsMediaCodecVulkan] 改成 true 即可恢复直通优先。
library;

import 'package:moumou/services/decode_settings.dart';

/// 本构建（内核）是否支持把 MediaCodec 直通帧映射进 Vulkan。
///
/// 当前为 false：普通 libmpv 构建下 `mediacodec` 直通只对 OpenGL 生效。
const bool kBuildSupportsMediaCodecVulkan = false;

/// *直通优先* 链（对应「硬解+」）：`mediacodec` 直通 → `mediacodec-copy` 拷贝 →
/// 软解。末位 `no` = 允许软解兜底；mpv 自己会在这条链里逐档往下试。
const String kHwdecChainDirectFirst = 'mediacodec,mediacodec-copy,no';

/// *拷贝优先* 链：跳过直通，直接 `mediacodec-copy` → 软解。
const String kHwdecChainCopyFirst = 'mediacodec-copy,no';

/// Vulkan 后端下是否还能直通（对齐 MPVRX `canUseDirectMediaCodec`）。
bool canUseDirectMediaCodec({
  required bool usesVulkan,
  bool buildSupportsMediaCodecVulkan = kBuildSupportsMediaCodecVulkan,
}) => !usesVulkan || buildSupportsMediaCodecVulkan;

/// 本次播放该写入 mpv 的 `hwdec` 链。
///
/// - 软解 / 自动档：原样返回（`no` / `auto-safe`，不由本函数改写语义）；
/// - 硬解 / 硬解+：按 [usesVulkan] 在两条链里挑一条（用户所选档位本身不被改写，
///   「硬解+」在 Vulkan 下就是「拷贝优先」——这是渲染后端的客观限制）。
String preferredDecodeChain(
  DecodeMode mode, {
  required bool usesVulkan,
  bool buildSupportsMediaCodecVulkan = kBuildSupportsMediaCodecVulkan,
}) {
  switch (mode) {
    case DecodeMode.autoSafe:
    case DecodeMode.sw:
      return mode.hwdec;
    case DecodeMode.hwCopy:
      return kHwdecChainCopyFirst;
    case DecodeMode.hwPlus:
      return canUseDirectMediaCodec(
        usesVulkan: usesVulkan,
        buildSupportsMediaCodecVulkan: buildSupportsMediaCodecVulkan,
      )
          ? kHwdecChainDirectFirst
          : kHwdecChainCopyFirst;
  }
}
