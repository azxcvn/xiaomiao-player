import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/subtitle_font_injection.dart';

/// 字幕字体注入决策纯函数测试。
///
/// 对应 `third_party/media_kit/FORK.md` 补丁 1/2 的**宿主侧判断**，以及
/// `docs/ARCHITECTURE.md` §4.10 的硬约定：`sub-fonts-dir` **只在构造
/// `PlayerConfiguration` 时注入**，运行期写它会打坏 libass 字体缓存。
///
/// 关键回归：默认「跟随系统字库」也必须**注入** `/system/fonts`
/// （`resolveSubtitleFontInjection` 永不返回 null）。历史 bug 是默认分支靠
/// 运行期 `setProperty('sub-fonts-dir', '/system/fonts')` 兜底，结果内嵌字幕
/// （含 PGS 等位图字幕）整条不渲染。
void main() {
  group('shouldInjectCustomSubtitleFont（是否注入用户自定义字体目录）', () {
    test('默认（跟随系统字库）：不注入用户目录', () {
      expect(
        shouldInjectCustomSubtitleFont(font: 'auto', fontsDir: ''),
        isFalse,
      );
    });

    test('字体为 auto 但目录非空：不注入（无家族名可匹配）', () {
      expect(
        shouldInjectCustomSubtitleFont(font: 'auto', fontsDir: '/data/fonts'),
        isFalse,
      );
    });

    test('选了字体家族名但目录为空：不注入（字体尚未落盘）', () {
      expect(
        shouldInjectCustomSubtitleFont(
            font: 'Source Han Sans SC', fontsDir: ''),
        isFalse,
      );
    });

    test('字体家族名与目录齐备：注入', () {
      expect(
        shouldInjectCustomSubtitleFont(
          font: 'Source Han Sans SC',
          fontsDir: '/data/user/0/com.example/files/fonts',
        ),
        isTrue,
      );
    });

    test('哨兵值与设置层默认值约定一致（subtitle_settings 用字面量 "auto"）', () {
      // 该断言是「契约哨兵」：若有人改动本常量，说明设置层默认值 'auto' 也需同步，
      // 此测试会提醒改动者去核对 SubtitleSettings._font / setFont('auto', '')。
      expect(kAutoSubtitleFont, 'auto');
    });
  });

  group('resolveSubtitleFontInjection（构造期必然注入一个字体目录）', () {
    test('默认：注入系统字库目录 + 默认族名（绝不是 null）', () {
      expect(
        resolveSubtitleFontInjection(font: 'auto', fontsDir: ''),
        const SubtitleFontInjection(
          fontsDir: kSystemFontsDir,
          fontName: kSystemFontName,
        ),
      );
    });

    test('选了族名但字体目录为空：回落系统字库（避免 libass 完全无字库）', () {
      expect(
        resolveSubtitleFontInjection(
          font: 'Source Han Sans SC',
          fontsDir: '',
        ),
        const SubtitleFontInjection(
          fontsDir: kSystemFontsDir,
          fontName: kSystemFontName,
        ),
      );
    });

    test('族名与目录齐备：注入用户字体目录与族名', () {
      final r = resolveSubtitleFontInjection(
        font: 'Source Han Sans SC',
        fontsDir: '/data/user/0/com.example/files/fonts',
      );
      expect(r.fontsDir, '/data/user/0/com.example/files/fonts');
      expect(r.fontName, 'Source Han Sans SC');
    });

    test('系统字库目录常量是 Android 系统字库路径', () {
      expect(kSystemFontsDir, '/system/fonts');
      expect(kSystemFontName, isNotEmpty);
    });

    test('注入目录永远非空（mpv_initialize 前必须有 sub-fonts-dir）', () {
      for (final font in ['auto', '', '   ', 'Noto Sans CJK SC']) {
        for (final dir in ['', '  ', '/data/fonts']) {
          final r = resolveSubtitleFontInjection(font: font, fontsDir: dir);
          expect(r.fontsDir.trim(), isNotEmpty,
              reason: 'font="$font" dir="$dir" 不应产生空字体目录');
          expect(r.fontName.trim(), isNotEmpty,
              reason: 'font="$font" dir="$dir" 不应产生空字体族名');
        }
      }
    });

    test('空白族名/目录按未设置处理，回落系统字库', () {
      expect(
        resolveSubtitleFontInjection(font: '   ', fontsDir: '/data/fonts'),
        const SubtitleFontInjection(
          fontsDir: kSystemFontsDir,
          fontName: kSystemFontName,
        ),
      );
      expect(
        resolveSubtitleFontInjection(font: 'Source Han Sans SC', fontsDir: '  '),
        const SubtitleFontInjection(
          fontsDir: kSystemFontsDir,
          fontName: kSystemFontName,
        ),
      );
    });
  });
}
