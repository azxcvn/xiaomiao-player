/// 超分辨率模型：Anime4K v4 模式 + 质量维度。
///
/// 设计参考 mpv-android-anime4k（参考项目/src）：
/// - [SuperResolutionMode]：7 档（关闭 + A/B/C/A+/B+/C+），不同模式针对不同
///   分辨率的动画，A+/B+/C+ 为双段放大链（更强重建、更慢）；
/// - [SuperResolutionQuality]：流畅(S)/均衡(M)/高清(L)，决定链内各着色器
///   使用哪个变体（S/M/L），在设置中调整，默认均衡；
/// - [buildAnime4KChain]：由 mode × quality 生成最终着色器文件名链
///   （纯函数，可单测）。
library;

/// 超分质量档（决定链内着色器变体 S/M/L）
///
/// 名称与说明在 `lib/l10n/label_maps.dart` 的 [superResolutionQualityLabel] /
/// [superResolutionQualityDescription]；**顺序即持久化语义**，不许调整。
enum SuperResolutionQuality {
  /// 流畅（Small 变体，低 GPU 占用）
  fast('S'),

  /// 均衡（Medium 变体，推荐）
  balanced('M'),

  /// 高清（Large 变体，高 GPU 占用）
  high('L');

  const SuperResolutionQuality(this.suffix);

  /// 着色器文件名中的变体后缀（S / M / L）
  final String suffix;

  /// 按持久化 index 反查（越界回退均衡）
  static SuperResolutionQuality fromIndex(int? index) {
    if (index == null || index < 0 || index >= values.length) {
      return SuperResolutionQuality.balanced;
    }
    return values[index];
  }
}

/// Anime4K 模式（播放器面板内切换）
///
/// 名称与说明在 [superResolutionModeLabel] / [superResolutionModeDescription]。
enum SuperResolutionMode {
  /// 关闭超分辨率
  off('off'),

  /// 模式 A：优化 1080p 动画
  a('a'),

  /// 模式 B：优化 720p 动画
  b('b'),

  /// 模式 C：优化 480p 动画
  c('c'),

  /// 模式 A+（A+A 双段链）：最高感知质量
  aPlus('a_plus'),

  /// 模式 B+（B+B 双段链）：高感知质量
  bPlus('b_plus'),

  /// 模式 C+（C+A 双段链）：略高感知质量
  cPlus('c_plus');

  const SuperResolutionMode(this.id);

  /// 持久化标识（稳定，勿改）
  final String id;

  /// 按持久化 id 反查模式（找不到返回关闭）
  static SuperResolutionMode byId(String? id) {
    if (id == null) return SuperResolutionMode.off;
    for (final m in values) {
      if (m.id == id) return m;
    }
    return SuperResolutionMode.off;
  }
}

/// 由 mode × quality 生成 Anime4K 着色器链（文件名列表，按 mpv 加载顺序）。
///
/// 结构对齐 mpv-android-anime4k 的 [Anime4KManager.getShaderChain]：
/// - 始终以 Clamp_Highlights 开头（防振铃）；
/// - A/B/C 单段链：Restore → Upscale → 预降采样 → 低档 Upscale；
/// - A+/B+/C+ 双段链：第一段放大后经预降采样，第二段用低一级变体重建再放大；
/// - 后置着色器处理 4 倍像素量，按官方最佳实践用低一级变体抵消性能开销
///   （高清 → M，均衡/流畅 → S）。
List<String> buildAnime4KChain(
  SuperResolutionMode mode,
  SuperResolutionQuality quality,
) {
  if (mode == SuperResolutionMode.off) return const [];

  final q = quality.suffix;
  final lowerQ = switch (quality) {
    SuperResolutionQuality.high => 'M',
    SuperResolutionQuality.balanced => 'S',
    SuperResolutionQuality.fast => 'S',
  };

  final shaders = <String>['Anime4K_Clamp_Highlights.glsl'];
  switch (mode) {
    case SuperResolutionMode.a:
      shaders
        ..add('Anime4K_Restore_CNN_$q.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.b:
      shaders
        ..add('Anime4K_Restore_CNN_Soft_$q.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.c:
      shaders
        ..add('Anime4K_Upscale_Denoise_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.aPlus:
      shaders
        ..add('Anime4K_Restore_CNN_$q.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Restore_CNN_$lowerQ.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.bPlus:
      shaders
        ..add('Anime4K_Restore_CNN_Soft_$q.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Restore_CNN_Soft_$lowerQ.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.cPlus:
      shaders
        ..add('Anime4K_Upscale_Denoise_CNN_x2_$q.glsl')
        ..add('Anime4K_AutoDownscalePre_x2.glsl')
        ..add('Anime4K_AutoDownscalePre_x4.glsl')
        ..add('Anime4K_Restore_CNN_$lowerQ.glsl')
        ..add('Anime4K_Upscale_CNN_x2_$lowerQ.glsl');
    case SuperResolutionMode.off:
      break;
  }
  return shaders;
}
