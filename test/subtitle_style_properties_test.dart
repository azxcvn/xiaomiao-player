import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/subtitle_font_injection.dart';
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/utils/subtitle_style_properties.dart';

/// 字幕样式「按字段 → mpv 属性」写入表测试（B5 / P1-10）。
///
/// 锁两件事：
/// 1. **一字段一写**：滑杆松手提交时只下发该字段的属性（旧实现每次事件全量写
///    16 条属性 + 一次设置写盘）；
/// 2. **运行期绝不写 `sub-fonts-dir`**（§4.10）：字体目录只在 `PlayerConfiguration`
///    构造期注入，运行期写它会打坏 libass 字体缓存让字幕整条消失。
void main() {
  const defaults = SubtitleStyleValues();

  List<String> namesOf(List<SubtitlePropertyWrite> writes) =>
      writes.map((w) => w.name).toList();

  String? valueOf(List<SubtitlePropertyWrite> writes, String name) {
    for (final w in writes) {
      if (w.name == name) return w.value;
    }
    return null;
  }

  group('formatMpvDouble（mpv 属性数值格式）', () {
    test('整数不写小数位', () {
      expect(formatMpvDouble(0), '0');
      expect(formatMpvDouble(100), '100');
      expect(formatMpvDouble(-3), '-3');
    });

    test('非整数保留两位', () {
      expect(formatMpvDouble(2.5), '2.50');
      expect(formatMpvDouble(1.234), '1.23');
    });
  });

  group('resolveSubtitleFontFamily（族名解析）', () {
    test('auto → 构造期注入的系统族名', () {
      expect(resolveSubtitleFontFamily(kAutoSubtitleFont), kSystemFontName);
    });

    test('用户字体 → 原族名', () {
      expect(resolveSubtitleFontFamily('Source Han Sans'), 'Source Han Sans');
    });
  });

  group('subtitleStyleWrites（单字段写入）', () {
    test('每个字段只写自己那几条（backColor 连描边模式、font 三条常量+族名）', () {
      final expected = <SubtitleStyleField, List<String>>{
        SubtitleStyleField.delay: ['sub-delay'],
        SubtitleStyleField.scale: ['sub-scale'],
        SubtitleStyleField.position: ['sub-pos'],
        SubtitleStyleField.color: ['sub-color'],
        SubtitleStyleField.borderStyle: ['sub-border-style'],
        SubtitleStyleField.borderSize: ['sub-border-size'],
        SubtitleStyleField.borderColor: ['sub-border-color'],
        SubtitleStyleField.shadowOffset: ['sub-shadow-offset'],
        // 背景色必须连描边模式一起写，否则 mpv 不画背景（见实现注释）
        SubtitleStyleField.backColor: ['sub-back-color', 'sub-border-style'],
        SubtitleStyleField.bold: ['sub-bold'],
        SubtitleStyleField.italic: ['sub-italic'],
        SubtitleStyleField.spacing: ['sub-spacing'],
        SubtitleStyleField.blur: ['sub-blur'],
        SubtitleStyleField.font: [
          'sub-font-provider',
          'embeddedfonts',
          'sub-font',
        ],
      };
      // 枚举必须与上表一一对应（新增字段时测试会失败，强迫同步登记）
      expect(expected.keys.toSet(), SubtitleStyleField.values.toSet());
      for (final entry in expected.entries) {
        expect(
          namesOf(subtitleStyleWrites(entry.key, defaults)),
          entry.value,
          reason: '字段 ${entry.key} 的写入属性表不应漂移',
        );
      }
    });

    test('样例外：只写改动字段，不带其它字段属性', () {
      final writes = subtitleStyleWrites(
        SubtitleStyleField.borderSize,
        const SubtitleStyleValues(borderSize: 4.5, color: '#FF0000'),
      );
      expect(writes.length, 1);
      expect(writes.single.name, 'sub-border-size');
      expect(writes.single.value, '4.50');
    });

    test('delay/scale/position/spacing/blur/shadowOffset 数值格式化', () {
      const v = SubtitleStyleValues(
        delay: -1.5,
        scale: 1.0,
        position: 87,
        spacing: 2.25,
        blur: 3,
        shadowOffset: 0,
      );
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.delay, v), 'sub-delay'),
          '-1.50');
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.scale, v), 'sub-scale'),
          '1');
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.position, v), 'sub-pos'),
          '87');
      expect(
          valueOf(subtitleStyleWrites(SubtitleStyleField.spacing, v), 'sub-spacing'),
          '2.25');
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.blur, v), 'sub-blur'),
          '3');
      expect(
          valueOf(
              subtitleStyleWrites(SubtitleStyleField.shadowOffset, v),
              'sub-shadow-offset'),
          '0');
    });

    test('颜色为 null 时回落 mpv 默认值', () {
      expect(
          valueOf(subtitleStyleWrites(SubtitleStyleField.borderColor, defaults),
              'sub-border-color'),
          '#000000');
      expect(
          valueOf(subtitleStyleWrites(SubtitleStyleField.backColor, defaults),
              'sub-back-color'),
          '#00000000');
    });

    test('颜色存在时原样下发（不额外转换）', () {
      const v = SubtitleStyleValues(
        color: '#FFEB3B',
        borderColor: '#112233',
        backColor: '#80000000',
      );
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.color, v), 'sub-color'),
          '#FFEB3B');
      expect(
          valueOf(
              subtitleStyleWrites(SubtitleStyleField.borderColor, v),
              'sub-border-color'),
          '#112233');
      expect(
          valueOf(subtitleStyleWrites(SubtitleStyleField.backColor, v), 'sub-back-color'),
          '#80000000');
    });

    test('布尔字段写 yes/no', () {
      const v = SubtitleStyleValues(bold: true, italic: false);
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.bold, v), 'sub-bold'),
          'yes');
      expect(valueOf(subtitleStyleWrites(SubtitleStyleField.italic, v), 'sub-italic'),
          'no');
    });

    test('描边模式取枚举的 mpvValue（mpv 0.38+ 的合法取值）', () {
      expect(
          valueOf(
              subtitleStyleWrites(
                  SubtitleStyleField.borderStyle,
                  const SubtitleStyleValues(
                      borderStyle: SubtitleBorderStyle.box)),
              'sub-border-style'),
          'background-box');
      expect(
          valueOf(
              subtitleStyleWrites(
                  SubtitleStyleField.borderStyle,
                  const SubtitleStyleValues(
                      borderStyle: SubtitleBorderStyle.outline)),
              'sub-border-style'),
          'outline-and-shadow');
      expect(
          valueOf(
              subtitleStyleWrites(
                  SubtitleStyleField.borderStyle,
                  const SubtitleStyleValues(
                      borderStyle: SubtitleBorderStyle.none)),
              'sub-border-style'),
          'none');
    });

    test('背景色字段连描边模式一起下发（否则 mpv 不画背景）', () {
      // 有背景色 → 背景框模式
      final withBack = subtitleStyleWrites(
        SubtitleStyleField.backColor,
        const SubtitleStyleValues(
          backColor: '#80000000',
          borderStyle: SubtitleBorderStyle.box,
        ),
      );
      expect(valueOf(withBack, 'sub-back-color'), '#80000000');
      expect(valueOf(withBack, 'sub-border-style'), 'background-box');
      // 选「无」→ 回落描边模式
      final noBack = subtitleStyleWrites(
        SubtitleStyleField.backColor,
        const SubtitleStyleValues(borderStyle: SubtitleBorderStyle.outline),
      );
      expect(valueOf(noBack, 'sub-back-color'), '#00000000');
      expect(valueOf(noBack, 'sub-border-style'), 'outline-and-shadow');
    });

    test('font=auto 写系统族名，font=用户字体写用户族名', () {
      expect(
          valueOf(subtitleStyleWrites(SubtitleStyleField.font, defaults), 'sub-font'),
          kSystemFontName);
      expect(
          valueOf(
              subtitleStyleWrites(
                  SubtitleStyleField.font,
                  const SubtitleStyleValues(font: 'Source Han Sans')),
              'sub-font'),
          'Source Han Sans');
    });

    test('font 字段同时打开 provider/embeddedfonts 两个常量开关', () {
      final writes = subtitleStyleWrites(SubtitleStyleField.font, defaults);
      expect(valueOf(writes, 'sub-font-provider'), 'auto');
      expect(valueOf(writes, 'embeddedfonts'), 'yes');
    });
  });

  group('allSubtitleStyleWrites（全量写入）', () {
    test('按枚举声明顺序展开，等于逐字段拼接', () {
      const v = SubtitleStyleValues(color: '#123456', bold: true, blur: 1.5);
      final all = allSubtitleStyleWrites(v);
      final expected = [
        for (final f in SubtitleStyleField.values) ...subtitleStyleWrites(f, v),
      ];
      expect(all, expected);
      // font 多两条常量开关，backColor 多一条描边模式
      expect(all.length, SubtitleStyleField.values.length + 3);
    });

    test('全量写入顺序（回归锁；不含已并入 back-color 的 sub-shadow-color）', () {
      expect(namesOf(allSubtitleStyleWrites(defaults)), [
        'sub-delay',
        'sub-scale',
        'sub-pos',
        'sub-color',
        'sub-border-style',
        'sub-border-size',
        'sub-border-color',
        'sub-shadow-offset',
        'sub-back-color',
        'sub-border-style',
        'sub-bold',
        'sub-italic',
        'sub-spacing',
        'sub-blur',
        'sub-font-provider',
        'embeddedfonts',
        'sub-font',
      ]);
    });

    test('绝不写 sub-shadow-color（mpv 0.38+ 它是 sub-back-color 的别名，会互相覆盖）',
        () {
      expect(
        namesOf(allSubtitleStyleWrites(defaults))
            .where((n) => n == 'sub-shadow-color'),
        isEmpty,
      );
      for (final field in SubtitleStyleField.values) {
        expect(
          namesOf(subtitleStyleWrites(field, defaults))
              .where((n) => n == 'sub-shadow-color'),
          isEmpty,
          reason: '字段 $field 不得写 sub-shadow-color',
        );
      }
    });
  });

  group('§4.10 硬约定：运行期绝不写 sub-fonts-dir', () {
    test('任何字段的任何写入都不含 sub-fonts-dir', () {
      const v = SubtitleStyleValues(font: 'Source Han Sans');
      for (final field in SubtitleStyleField.values) {
        final names = namesOf(subtitleStyleWrites(field, v));
        expect(
          names.where((n) => n == 'sub-fonts-dir'),
          isEmpty,
          reason: '字段 $field 不得写 sub-fonts-dir（字体目录只在构造期注入）',
        );
      }
      expect(
        namesOf(allSubtitleStyleWrites(v)).where((n) => n == 'sub-fonts-dir'),
        isEmpty,
      );
    });
  });
}
