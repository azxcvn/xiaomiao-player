/// 字幕样式的「按字段 → mpv 属性」写入表（P1-10，纯函数、可单测）。
///
/// 背景：字幕样式面板的每一条滑杆原先都在 `onChanged` 里调用
/// `SubtitleController.applyAllSettings()` —— 一次拖动会让 16 个 mpv 属性
/// **串行写**一遍（还叠加一次 `SubtitleSettings` 写盘），既掉帧又违反
/// 「谁变写谁」的最小写入纪律。把「字段 → 属性」映射抽成纯数据表之后：
/// - 滑杆松手只写**该字段这一条/这一组**属性（`applyStyleField`）；
/// - `applyAllSettings()` 仍按同一张表全量写（初始化 / 切媒体 / 重置时用），
///   两张路径共用一份定义，不会再出现「某字段只在全量路径里写了」的漂移。
///
/// ⚠️ **`font` 字段只写 `sub-font`（族名）**：字体**目录**一律构造期注入
/// （§4.10），本表里**不允许**出现 `sub-fonts-dir`。
///
/// ⚠️ **字段名以 mpv 0.38+ 为准**（本项目内核 mpv v0.41）：`sub-border-*` 已被
/// 改名为 `sub-outline-*`（旧名仍是别名，故沿用旧名也能工作，但新代码优先用新名不是
/// 本表的事——保持与设置面板文案一致更重要）；`sub-shadow-color` 已并入
/// `sub-back-color`（别名），因此本表**不再写** `sub-shadow-color`；
/// `sub-border-style` 的合法取值见 [SubtitleBorderStyle]（旧值 `flat`/`box` 会被拒绝）。
library;

import 'package:moumou/models/subtitle_font_injection.dart';
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/services/subtitle_settings.dart';

/// 一个字幕样式字段（= 「按字段 apply」的粒度）。
///
/// **枚举顺序 = 全量写入顺序**（[allSubtitleStyleWrites] 依赖它），
/// 调整顺序会改变 mpv 属性写入次序，请勿随意重排。
///
/// ⚠️ **没有「阴影颜色」字段**：mpv 0.38 起 `sub-shadow-color` 就是
/// `sub-back-color` 的**别名**（同一个字段，两者不能各设）——分别写会互相覆盖。
enum SubtitleStyleField {
  delay,
  scale,
  position,
  color,
  borderStyle,
  borderSize,
  borderColor,
  shadowOffset,
  backColor,
  bold,
  italic,
  spacing,
  blur,
  font,
}

/// 一条待写入 mpv 的属性。
typedef SubtitlePropertyWrite = ({String name, String value});

/// 字幕样式的一份**纯数据快照**：脱离 [SubtitleSettings] 单例，便于单测
/// （单测不需要 SharedPreferences，也不会读到全局状态）。
class SubtitleStyleValues {
  const SubtitleStyleValues({
    this.delay = 0,
    this.scale = 1.0,
    this.position = 100,
    this.color = '#FFFFFF',
    this.borderStyle = SubtitleBorderStyle.none,
    this.borderSize = 2.5,
    this.borderColor,
    this.shadowOffset = 0,
    this.backColor,
    this.bold = false,
    this.italic = false,
    this.spacing = 0,
    this.blur = 0,
    this.font = kAutoSubtitleFont,
  });

  /// 从全局设置读一份快照（面板提交路径用）。
  factory SubtitleStyleValues.fromSettings(SubtitleSettings s) {
    return SubtitleStyleValues(
      delay: s.delay,
      scale: s.scale,
      position: s.position,
      color: s.color,
      borderStyle: s.borderStyle,
      borderSize: s.borderSize,
      borderColor: s.borderColor,
      shadowOffset: s.shadowOffset,
      backColor: s.backColor,
      bold: s.bold,
      italic: s.italic,
      spacing: s.spacing,
      blur: s.blur,
      font: s.font,
    );
  }

  final double delay;
  final double scale;
  final double position;
  final String color;
  final SubtitleBorderStyle borderStyle;
  final double borderSize;
  final String? borderColor;
  final double shadowOffset;
  final String? backColor;
  final bool bold;
  final bool italic;
  final double spacing;
  final double blur;
  final String font;
}

/// mpv 数值格式化：整数不写小数位，其余保留两位。
///
/// 与旧 `SubtitleController._fmtDouble` 行为一致（mpv 属性值是字符串）。
String formatMpvDouble(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

/// [SubtitleStyleField.font] 解析出的族名：
/// 「跟随系统字库」= 构造期注入的 [kSystemFontName]，否则用户族名。
String resolveSubtitleFontFamily(String font) {
  return font == kAutoSubtitleFont ? kSystemFontName : font;
}

/// 单个字段要写入 mpv 的属性列表（**只含该字段**，P1-10 的核心约定）。
///
/// `font` 是唯一的多属性字段：`sub-font` 生效依赖 provider/embeddedfonts
/// 两个常量开关，三条一起写；其余字段都是「一字段一属性」。
List<SubtitlePropertyWrite> subtitleStyleWrites(
  SubtitleStyleField field,
  SubtitleStyleValues v,
) {
  switch (field) {
    case SubtitleStyleField.delay:
      return [(name: 'sub-delay', value: formatMpvDouble(v.delay))];
    case SubtitleStyleField.scale:
      return [(name: 'sub-scale', value: formatMpvDouble(v.scale))];
    case SubtitleStyleField.position:
      return [(name: 'sub-pos', value: formatMpvDouble(v.position))];
    case SubtitleStyleField.color:
      return [(name: 'sub-color', value: v.color)];
    case SubtitleStyleField.borderStyle:
      return [(name: 'sub-border-style', value: v.borderStyle.mpvValue)];
    case SubtitleStyleField.borderSize:
      return [(name: 'sub-border-size', value: formatMpvDouble(v.borderSize))];
    case SubtitleStyleField.borderColor:
      return [(name: 'sub-border-color', value: v.borderColor ?? '#000000')];
    case SubtitleStyleField.shadowOffset:
      // 面板里这一项的文案是**「背景框大小」**（用户视角）：在 `background-box` 模式下
      // mpv 把它当作背景框的内边距（盒子大小 = 文字 + 描边粗细 + 本值，
      // 见 [SubtitleBorderStyle] 的文档）；在描边模式下它才是传统意义的阴影位移。
      return [
        (name: 'sub-shadow-offset', value: formatMpvDouble(v.shadowOffset)),
      ];
    case SubtitleStyleField.backColor:
      // 背景颜色**必须**连描边模式一起写：mpv 只在盒子模式下才把 `sub-back-color`
      // 画出来，默认的 `outline-and-shadow` 下完全不可见（真机「背景颜色怎么调都没
      // 效果」的根因）。而模式又是被背景颜色隐式驱动的（`SubtitleSettings.setBackColor`
      // 有背景色 = 背景框、选「无」= 描边），所以这两个属性同属一个字段、必须同一次
      // 下发，UI 才不会出现「改了颜色没反应」。
      //
      // ⚠️ 用的模式是 `background-box`（一个盒子、明确用 back-color），**不是**
      // `opaque-box`（描边盒 + 阴影盒两个盒子，阴影盒默认被压在下面 → 用户会以为
      // 「背景颜色滑杆是摆设、调描边颜色才能改色块」，真机踩过，见 [SubtitleBorderStyle]）。
      return [
        (name: 'sub-back-color', value: v.backColor ?? '#00000000'),
        (name: 'sub-border-style', value: v.borderStyle.mpvValue),
      ];
    case SubtitleStyleField.bold:
      return [(name: 'sub-bold', value: v.bold ? 'yes' : 'no')];
    case SubtitleStyleField.italic:
      return [(name: 'sub-italic', value: v.italic ? 'yes' : 'no')];
    case SubtitleStyleField.spacing:
      return [(name: 'sub-spacing', value: formatMpvDouble(v.spacing))];
    case SubtitleStyleField.blur:
      return [(name: 'sub-blur', value: formatMpvDouble(v.blur))];
    case SubtitleStyleField.font:
      return [
        (name: 'sub-font-provider', value: 'auto'),
        (name: 'embeddedfonts', value: 'yes'),
        (name: 'sub-font', value: resolveSubtitleFontFamily(v.font)),
      ];
  }
}

/// 全量写入计划（`applyAllSettings` 用）：按 [SubtitleStyleField] 声明顺序展开。
///
/// 注意**不含** `sub-ass-override`——那条由 `applyStyleOverride()` /
/// `_setOverrideProperty()` 单独处理（它涉及是否 `sub-reload`）。
///
/// `sub-border-style` 会出现两次（[SubtitleStyleField.borderStyle] 与
/// [SubtitleStyleField.backColor] 各一次），两次写的都是同一个值（同一个设置快照），
/// 幂等无害——保留是因为「背景颜色」那一次是**背景能画出来的前提**，缺它就会出现
/// 真机踩过的「改了背景色没反应」。
List<SubtitlePropertyWrite> allSubtitleStyleWrites(SubtitleStyleValues v) {
  return [
    for (final field in SubtitleStyleField.values)
      ...subtitleStyleWrites(field, v),
  ];
}
