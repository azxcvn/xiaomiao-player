/// 后处理预设：只负责“一键写入参数”，不维护第二套状态。
///
/// 用户点一个预设，等价于把后处理面板里对应的开关和滑杆批量设置一遍；
/// 之后在面板里继续拖动，就会从预设变成“自定义/已微调”。
library;

/// 预设分组（按片源问题分类，不按效果名）
enum PostProcessPresetGroup { clean, film, tv, lowBitrate, streaming, style }

/// 预设强度（风格化预设没有强度）
enum PostProcessPresetStrength { light, standard, strong }

extension PostProcessPresetStrengthX on PostProcessPresetStrength {
  /// 数值参数的缩放系数：轻 0.6 / 标准 1.0 / 强 1.4
  double get scale => switch (this) {
        PostProcessPresetStrength.light => 0.6,
        PostProcessPresetStrength.standard => 1.0,
        PostProcessPresetStrength.strong => 1.4,
      };
}

/// 所有预设。前四组各有 轻/标准/强 三档；风格组是三个独立的风格。
enum PostProcessPreset {
  cleanLight(PostProcessPresetGroup.clean, PostProcessPresetStrength.light),
  cleanStandard(
    PostProcessPresetGroup.clean,
    PostProcessPresetStrength.standard,
  ),
  cleanStrong(PostProcessPresetGroup.clean, PostProcessPresetStrength.strong),
  filmLight(PostProcessPresetGroup.film, PostProcessPresetStrength.light),
  filmStandard(PostProcessPresetGroup.film, PostProcessPresetStrength.standard),
  filmStrong(PostProcessPresetGroup.film, PostProcessPresetStrength.strong),
  tvLight(PostProcessPresetGroup.tv, PostProcessPresetStrength.light),
  tvStandard(PostProcessPresetGroup.tv, PostProcessPresetStrength.standard),
  tvStrong(PostProcessPresetGroup.tv, PostProcessPresetStrength.strong),
  lowBitrateLight(
    PostProcessPresetGroup.lowBitrate,
    PostProcessPresetStrength.light,
  ),
  lowBitrateStandard(
    PostProcessPresetGroup.lowBitrate,
    PostProcessPresetStrength.standard,
  ),
  lowBitrateStrong(
    PostProcessPresetGroup.lowBitrate,
    PostProcessPresetStrength.strong,
  ),
  streamingLight(
    PostProcessPresetGroup.streaming,
    PostProcessPresetStrength.light,
  ),
  streamingStandard(
    PostProcessPresetGroup.streaming,
    PostProcessPresetStrength.standard,
  ),
  streamingStrong(
    PostProcessPresetGroup.streaming,
    PostProcessPresetStrength.strong,
  ),
  cinematic(PostProcessPresetGroup.style, null),
  soft(PostProcessPresetGroup.style, null),
  retro(PostProcessPresetGroup.style, null);

  const PostProcessPreset(this.group, this.strength);

  final PostProcessPresetGroup group;

  /// 风格化预设为 null（没有强度档）
  final PostProcessPresetStrength? strength;

  /// 数值缩放系数（风格化固定 1.0）
  double get scale => strength?.scale ?? 1.0;

  bool get isStyle => group == PostProcessPresetGroup.style;
}
