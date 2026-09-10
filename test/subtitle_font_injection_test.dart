import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/subtitle_font_injection.dart';

/// 自定义字幕字体注入决策纯函数测试。
///
/// 对应 `third_party/media_kit/FORK.md` 补丁 1/2 的**宿主侧判断**：只有「选了具体
/// 字体家族名 + 字体目录非空」时才在构造 `PlayerConfiguration` 时注入
/// `libassAndroidFontsDir`/`libassAndroidFontName`，否则走 `/system/fonts` 系统字库。
void main() {
  test('默认（跟随系统字库）：不注入', () {
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
      shouldInjectCustomSubtitleFont(font: 'Source Han Sans SC', fontsDir: ''),
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
}
