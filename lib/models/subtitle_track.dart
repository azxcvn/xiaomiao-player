import 'package:flutter/foundation.dart';

/// 字幕轨道（工作.md 阶段1 第 3 点）：播放器当前媒体可用的字幕轨道。
///
/// 数据来自 mpv `track-list` 子属性（内嵌字幕）或 `sub-add` 添加的外部字幕；
/// [external] 为 true 表示外挂字幕（切集后不会自动存在，需重新添加）。
@immutable
class SubtitleTrack {
  /// mpv 轨道 id（`track-list/$i/id`，字符串形式）
  final String id;

  /// 轨道标题（`title` 属性，可能为空）
  final String? title;

  /// 语言代码（`lang` 属性，可能为空）
  final String? language;

  /// 是否为外挂字幕（通过 `sub-add` 添加；切集后消失需重新添加）
  final bool external;

  /// 字幕编码格式（`codec` 属性：srt / ass / ssa / webvtt 等，可能为空）
  final String? codec;

  /// 字幕源路径（mpv `external-filename`，外挂字幕为文件绝对路径；内嵌为 null）。
  /// 用于切集重新添加外挂字幕后按路径恢复主/次勾选（轨道 id 重开会变）。
  final String? sourcePath;

  const SubtitleTrack({
    required this.id,
    this.title,
    this.language,
    this.external = false,
    this.codec,
    this.sourcePath,
  });

  /// 是否为内嵌样式字幕（ASS / SSA）：
  /// 这类字幕自带样式与字体，默认应尊重其内嵌样式而不是强制覆盖
  /// （工作.md 阶段1 第 3 点：内嵌字幕应启用自带样式与字体）。
  bool get isStyled => _isStyledSubtitle(codec);

  /// 展示名：优先标题，其次语言，最后回退「轨道 N」
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    if (language != null && language!.trim().isNotEmpty) return language!.trim();
    return '轨道 $id';
  }
}

/// 判断字幕编码是否为内嵌样式字幕（ASS/SSA）。null 视为普通文本字幕。
bool _isStyledSubtitle(String? codec) {
  if (codec == null) return false;
  final c = codec.toLowerCase();
  return c.contains('ass') || c.contains('ssa');
}

/// 字幕轨道在面板中的显示名（纯函数，可单测）。
/// 返回 `displayTitle` + 外挂标记 + 格式后缀，如「简体中文 · 外挂 · ass」。
String subtitleTrackLabel(SubtitleTrack track) {
  final parts = <String>[track.displayTitle];
  if (track.external) parts.add('外挂');
  if (track.codec != null && track.codec!.trim().isNotEmpty) {
    parts.add(track.codec!.trim());
  }
  return parts.join(' · ');
}

/// 支持的外挂字幕扩展名（参考小喵 player `isSupportedSubtitleFormat`）。
const Set<String> kSupportedSubtitleExtensions = {
  'srt', 'ass', 'ssa', 'sub', 'vtt', 'lrc', 'sbv', 'smi', 'pjs',
  'psb', 'rt', 'aqt', 'mpl2', 'txt', 'dvd', 'idx', 'sup',
};

/// 判断文件名是否为支持的字幕格式（纯函数，可单测；大小写不敏感）。
bool isSupportedSubtitleFile(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return false;
  final ext = filename.substring(dot + 1).toLowerCase();
  return kSupportedSubtitleExtensions.contains(ext);
}

/// 支持的自导入字体扩展名（.ttf / .otf / .ttc / .otc）。
///
/// ⚠️ 若调整此集合，必须同步更新 `third_party/media_kit` 中
/// `_hasFontFile()`（lib/src/player/native/player/real.dart）的扩展名判断，
/// 否则会出现「字体已导入但被判为不可用」的静默失效（详见该包的 FORK.md）。
const Set<String> kFontExtensions = {'ttf', 'otf', 'ttc', 'otc'};

/// 判断文件名是否为字体文件（自建字体选择器过滤用；大小写不敏感）。
bool isFontFile(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return false;
  final ext = filename.substring(dot + 1).toLowerCase();
  return kFontExtensions.contains(ext);
}

/// 字幕对齐（mpv `sub-align-x`）：水平位置三选。
enum SubtitleAlign {
  center('center', '居中'),
  left('left', '左对齐'),
  right('right', '右对齐');

  /// mpv 属性值
  final String mpvValue;
  final String label;
  const SubtitleAlign(this.mpvValue, this.label);

  static SubtitleAlign byMpvValue(String v) => switch (v) {
        'left' => SubtitleAlign.left,
        'right' => SubtitleAlign.right,
        _ => SubtitleAlign.center,
      };
}

/// 字幕描边模式（mpv `sub-border-style`）：决定字幕的「边框 / 背景」怎么画。
///
/// ⚠️ **mpv 0.38 起改了这一组选项**（本项目的内核是 mpv `v0.41.0-110`，见
/// [upstream f8e3cf9](https://github.com/mpv-player/mpv/commit/f8e3cf92b5f4b09177b39f0674c2d7cc776365a8)）：
/// - 合法取值只有 `none`(0) / `outline-and-shadow`(1) / `opaque-box`(3) /
///   `background-box`(4)，**旧值 `flat` / `box` 会被 mpv 拒绝**（写入静默失败，
///   mpv 保持默认 `outline-and-shadow`）——这正是「背景颜色怎么调都没效果」的根因；
/// - `sub-border-color` / `sub-border-size` 已改名为 `sub-outline-color` /
///   `sub-outline-size`（旧名保留为别名，故 App 现有写入仍有效）；
/// - `sub-shadow-color` 变成 `sub-back-color` 的**别名**（同一字段，两者不能各设）。
///
/// ⚠️ **[box] 用 `background-box`，不能用 `opaque-box`**（真机踩过）：
/// `opaque-box` 画的是**两个**盒子 —— 描边盒用 `sub-outline-color`，阴影盒才是
/// `sub-back-color` 且位置由 `sub-shadow-offset` 偏移；本 App 的阴影偏移默认 0，
/// 两个盒子完全重合、阴影盒被压在下面 → 用户看到的色块始终是**描边颜色**画的，
/// 「背景颜色」滑杆调的是一个看不见的盒子（表现为「背景颜色滑块是摆设、调描边颜色
/// 才能改到色块」）。`background-box` 只画**一个**盒子、且**明确用 `sub-back-color`**
/// （描边仍照旧画在文字轮廓上），两个控件才各管各的。
///
/// ⚠️ **盒子大小是「文字 + 描边粗细 + `sub-shadow-offset`」三者之和**（libass 的
/// 几何定义：盒子必须包住含描边的文字，无法解耦）。面板把 `sub-shadow-offset`
/// 暴露成「**背景框大小**」（管盒子的内边距），「描边粗细」管文字轮廓——两个滑杆
/// 各管一半，但描边变粗时盒子仍会跟着大一点，这是预期。mpv 自带的 box 观感
/// （内核 `libmpv.so` 的 `[sub-box]` profile）就是 `outline-size=0` + `shadow-offset=4`。
///
/// **本 App 不提供「描边模式」选择器**（用户拍板）：模式由「背景颜色」隐式驱动
/// ——有背景色 → [box]（否则 mpv 不画背景色），选「无」→ [outline]
/// （见 `SubtitleSettings.setBackColor`）。枚举保留三态供设置层与持久化表达。
enum SubtitleBorderStyle {
  /// 无边框、无背景（mpv `none`，对应 ASS `BorderStyle=0`）
  none('none', '无'),

  /// 描边 + 阴影（mpv `outline-and-shadow`，ASS `BorderStyle=1`，也是 mpv 默认）
  outline('outline-and-shadow', '描边'),

  /// 包住整段字幕的背景框，颜色 = `sub-back-color`（mpv `background-box`，libass 的 `BorderStyle=4`）
  box('background-box', '背景框');

  /// mpv 属性值
  final String mpvValue;
  final String label;
  const SubtitleBorderStyle(this.mpvValue, this.label);

  /// 从 mpv 取值 / 历史持久化值还原（兼容 0.38 之前的旧名）。
  ///
  /// 未知值一律回落 [outline]：那是 mpv 自己的默认值，也是 App 一直以来的实际观感。
  static SubtitleBorderStyle byMpvValue(String v) => switch (v) {
        'none' || 'flat' => SubtitleBorderStyle.none,
        'background-box' || 'box' => SubtitleBorderStyle.box,
        // 'opaque-box' 曾是本 App 用错的值（见类文档），一并归到背景框
        'opaque-box' => SubtitleBorderStyle.box,
        _ => SubtitleBorderStyle.outline,
      };
}

/// 字幕预设颜色（mpv `sub-color`，工作.md 阶段1 第 3 点样式项）。
class SubtitlePresetColor {
  final String label;
  final String hex;

  const SubtitlePresetColor(this.label, this.hex);

  /// 文字颜色常用预设（3~4 种常用色，对齐小喵 player 需求）
  static const List<SubtitlePresetColor> textPresets = [
    SubtitlePresetColor('白色', '#FFFFFF'),
    SubtitlePresetColor('黄色', '#FFEB3B'),
    SubtitlePresetColor('青色', '#4DD0E1'),
    SubtitlePresetColor('绿色', '#81C784'),
  ];

  /// 描边颜色常用预设（黑色、白色、黄色，去除了红色）
  static const List<SubtitlePresetColor> borderPresets = [
    SubtitlePresetColor('黑色', '#000000'),
    SubtitlePresetColor('白色', '#FFFFFF'),
    SubtitlePresetColor('黄色', '#FFEB3B'),
  ];

  /// 背景颜色常用预设（对齐小喵 player 需求）
  static const List<SubtitlePresetColor> backPresets = [
    SubtitlePresetColor('半透明黑', '#80000000'),
    SubtitlePresetColor('纯黑', '#FF000000'),
    SubtitlePresetColor('半透明白', '#80FFFFFF'),
    SubtitlePresetColor('半透明蓝', '#801A2332'),
  ];

  /// 兼容旧引用
  static const List<SubtitlePresetColor> presets = textPresets;

  static SubtitlePresetColor byHex(String hex) {
    final upper = hex.toUpperCase();
    for (final p in presets) {
      if (p.hex == upper) return p;
    }
    return presets.first;
  }
}

/// 颜色 RGBA 分量（各 0–255）。用于字幕颜色滑杆调节（工作.md 阶段1 第 3 点，
/// 需求：像小喵 player 一样通过滑块调 R/G/B/A 获得任意颜色）。
typedef SubtitleRgba = ({int r, int g, int b, int a});

/// 把 RGBA 分量格式化为 mpv 颜色的十六进制串：
/// - alpha == 255（不透明）→ `#RRGGBB`（6 位，保证兼容性）；
/// - alpha < 255 → `#AARRGGBB`（8 位，mpv 的 alpha 通道在前）。
/// 分量为 clamp 到 0–255 后取整。
String rgbaToMpvColor(SubtitleRgba c) {
  final r = c.r.clamp(0, 255);
  final g = c.g.clamp(0, 255);
  final b = c.b.clamp(0, 255);
  final a = c.a.clamp(0, 255);
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  if (a == 255) return '#${two(r)}${two(g)}${two(b)}';
  return '#${two(a)}${two(r)}${two(g)}${two(b)}';
}

/// 把 mpv 颜色串解析为 RGBA 分量。支持 `#RRGGBB`（不透明）与 `#AARRGGBB`
/// （8 位，alpha 在前）。非法输入回退为纯黑不透明。
SubtitleRgba mpvColorToRgba(String hex) {
  final h = hex.replaceAll('#', '').toUpperCase();
  int val(int start, int len) {
    final seg = h.substring(start, start + len);
    return int.tryParse(seg, radix: 16) ?? 0;
  }

  switch (h.length) {
    case 6:
      return (r: val(0, 2), g: val(2, 2), b: val(4, 2), a: 255);
    case 8:
      return (a: val(0, 2), r: val(2, 2), g: val(4, 2), b: val(6, 2));
    default:
      return (r: 0, g: 0, b: 0, a: 255);
  }
}
