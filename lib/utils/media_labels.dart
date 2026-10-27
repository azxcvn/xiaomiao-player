/// 视频列表字段的展示文本（胶囊标签用）：分辨率 / 帧率 / 字幕类型。
library;

/// 分辨率 → `1080p`（宽高任一为 0 时返回 null）。
///
/// 取**短边**作为 p 值：1920×1080 → `1080p`，竖屏 1080×1920 也叫 `1080p`
/// （竖屏片源同样按短边命名），非 16:9 的 1920×800 这类也按短边算。
String? videoResolutionLabel(int width, int height) {
  if (width <= 0 || height <= 0) return null;
  final shortSide = width < height ? width : height;
  return '${shortSide}p';
}

/// 帧率 → `23.98`（整数帧率不带小数：24 → `24`；非正数 / 非法值返回空串）
String videoFrameRateLabel(double frameRate) {
  if (frameRate <= 0 || !frameRate.isFinite) return '';
  return frameRate.toStringAsFixed(frameRate % 1 == 0 ? 0 : 2);
}

/// 分辨率与帧率合并成一个标签：`1080p@23.98`。
///
/// [showResolution] / [showFrameRate] 对应两个字段各自的勾选状态：
/// 只勾了其中一个时只显示有的部分（帧率单独显示补 ` fps` 后缀，
/// 避免只剩一个 `23.98` 看不出是什么）；两边都没数据返回 null（不显示标签）。
String? videoQualityLabel({
  required bool showResolution,
  required bool showFrameRate,
  required int width,
  required int height,
  required double frameRate,
}) {
  final resolution = showResolution
      ? videoResolutionLabel(width, height)
      : null;
  final fps = showFrameRate ? videoFrameRateLabel(frameRate) : '';
  if (resolution != null && fps.isNotEmpty) return '$resolution@$fps';
  if (resolution != null) return resolution;
  if (fps.isNotEmpty) return '$fps fps';
  return null;
}

/// 内嵌字幕编码串 → 每个字幕类型一个标签（原生侧已归一化并去重，
/// 例：`PGS SRT`）。空串 / 全是空白时返回空列表。
List<String> subtitleTypeLabels(String subtitleCodec) {
  return subtitleCodec
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
}
