/// 每次 `open` 之前的播放器属性注入（§4.26 的姊妹文件）。
///
/// `playback_tuning.dart` 管的是**跟来源有关**的解封装/缓存/重连参数；
/// 本文件管的是**整条播放器生命周期内固定**的渲染与 seek 行为——它们同样
/// 只在 `open` 之前写入才有效（`gpu-api`/`gpu-context` 决定视频输出上下文
/// 怎么建、`profile` 决定视频滤镜链、`hr-seek` 决定 seek 是否帧级精确）。
///
/// ## 为什么必须收口在这里
///
/// 这几个属性原先写在播放页 `initState` 里以 `unawaited(...)` 异步下发，
/// 而 `open` 走的是另一条 await 链——两者**互相竞速**，属性常落在 `open`
/// 之后。同一类东西（`vo`/`hwdec` 与 `gpu-api`/`profile`）两套写法本身就是
/// 隐患：轻则 `profile` 偶尔不生效，重则**播放中途被重配视频输出**。
///
/// 现在与 [applyPlaybackTuning] 同一位置、同一时机：**任何打开媒体的地方，
/// 都在 `open` 前写完**（打开多少次就写多少次，写入幂等、成本极低）。
///
/// ## ⚠️ `gpu-context` 必须一起改（Vulkan 黑屏的根因，2026-09 定性）
///
/// 项目用的是 **pub 版** `media_kit_video`（1.3.1），它在
/// `AndroidVideoController.create` 里**硬写死**：
///
/// ```dart
/// 'opengl-es': 'yes',
/// 'gpu-context': 'android',   // ← 只准 OpenGL ES
/// ```
///
/// 而 mpv 建上下文时会**同时**校验 `gpu-context`（上下文名）与
/// `gpu-api`（允许的 api 类型，`video/out/gpu/context.c` 的
/// `create_in_contexts`）：
///
/// ```c
/// if (strcmp(type, "auto") == 0 || strcmp(type, ctx->type) == 0) found = true;
/// ```
///
/// 于是 `gpu-context='android'`（type=opengl）+ `gpu-api='vulkan'` 两个约束
/// **没有任何上下文能同时满足** → `Failed initializing any suitable GPU
/// context!` → vo 建不起来 → 黑屏，且 `gpu-api` 写死单值时 mpv 不做兜底
/// （`probing=false` 分支），所以**不会自动回退**（旧文案声称会回退，是错的）。
///
/// 参考项目 Kazumi 的 fork（`Predidit/media-kit` @ `994465d9`）正是这么解决的
/// ——它删掉了 `gpu-context`/`opengl-es` 两行，并改写成有序偏好：
///
/// ```dart
/// 'gpu-api': configuration.vo == 'gpu-next' ? 'vulkan,opengl' : 'auto',
/// ```
///
/// 本项目不改 fork，改为在**运行时覆盖**同样的两个值（pub 版顺序是"先建
/// controller 设 android → 再 open"，而我们这两条写在 open 之前，
/// 晚于 controller 创建、早于 vo 建立，因此能生效）。
library;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// 在 `open` 之前写入播放器级固定属性。失败一律静默（不阻断起播）。
///
/// [presetProfile] 是 mpv 内置 profile 名（编译在 libmpv.so 里，空串 =
/// 不应用任何 profile）；[useVulkan] 只在 [gpuNext] 为真时才写——`gpu-api`
/// 是「gpu-next 用哪个后端」的开关，`vo=gpu` 根本不认它。
///
/// 参数保持为纯值（不读单例）：本模块无状态、可直接单测调用契约。
Future<void> applyPreOpenPlayerProperties(
  Player player, {
  required bool gpuNext,
  required bool useVulkan,
  required String presetProfile,
}) async {
  try {
    final native = player.platform as NativePlayer;
    await native.waitForPlayerInitialization;

    // 帧级精确 seek：所有绝对 seek 都落在目标帧（对齐 mpvRx "seek absolute+exact"）
    await native.setProperty('hr-seek', 'absolute');

    // GPU 渲染后端：gpu-next + Vulkan 时，解开 pub 版硬写的 OpenGL ES 约束，
    // 并改成「Vulkan 优先、失败回落 OpenGL」的有序偏好（对齐 Kazumi fork）。
    // 必须在视频输出上下文创建**之前**写入——建好之后再改不会重建上下文。
    if (gpuNext && useVulkan) {
      // ★ 先解开 `gpu-context='android'`（pub 版硬写），否则下面那条
      //   `gpu-api=vulkan` 与它互斥，mpv 会一个上下文都建不出来。
      //   `auto` 是 mpv 的哨兵值，命中即走"Probing for best GPU context"。
      await native.setProperty('gpu-context', 'auto');
      // ★ `vulkan,opengl` = **有序偏好列表**（不是单值强制）：Vulkan 建得起来
      //   就用 Vulkan，建不起来 mpv 自动回落 OpenGL——这正是它比原来的
      //   `'vulkan'` 安全的地方（单值时 mpv 不做兜底）。
      await native.setProperty('gpu-api', 'vulkan,opengl');
      // 临时排查日志：确认这两条真的写进去了（`adb logcat -s flutter:I`）
      debugPrint('[渲染设置] 已写入 gpu-context=auto, gpu-api=vulkan,opengl');
    }

    // 解码性能预设（mpv 内置 profile）
    if (presetProfile.isNotEmpty) {
      await native.setProperty('profile', presetProfile);
    }
  } catch (e) {
    // 播放器未就绪 / 属性不支持时静默失败，不影响播放
    debugPrint('applyPreOpenPlayerProperties: failed: $e');
  }
}
