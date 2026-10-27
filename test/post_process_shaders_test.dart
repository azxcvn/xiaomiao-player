import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/post_process_shaders.dart';

/// 后处理着色器生成（PPSSPP 移植）纯函数测试：
/// - 参数必须烧成 GLSL 字面量（mpv 用户着色器没有运行时 uniform）；
/// - 输出必须是合法 mpv 用户着色器（HOOK/VOID 头、无 uniform）；
/// - alpha 必须为 1.0（PPSSPP 原版部分 shader 把 alpha 写成 0）；
/// - 结构（花括号配平、抽样次数）不能错。
void main() {
  group('glslFloat', () {
    test('整数值必须带小数点', () {
      expect(glslFloat(1), '1.0');
      expect(glslFloat(0), '0.0');
      expect(glslFloat(170), '170.0');
      expect(glslFloat(-100), '-100.0');
    });

    test('小数去掉尾零', () {
      expect(glslFloat(0.6), '0.6');
      expect(glslFloat(1.2), '1.2');
      expect(glslFloat(1.25), '1.25');
      expect(glslFloat(0.05), '0.05');
    });
  });

  group('postProcessShaderFileName', () {
    test('同一内容稳定同名（避免无谓重载）', () {
      final src = vignetteShader(
        power: 0.6,
        aspect: 1.0,
        radius: 0.0,
        softness: 0.5,
      );
      expect(
        postProcessShaderFileName('vignette', src),
        postProcessShaderFileName('vignette', src),
      );
    });

    test('参数变了就是新文件名（mpv 才会重载着色器）', () {
      final a = postProcessShaderFileName(
        'vignette',
        vignetteShader(power: 0.5, aspect: 1.0, radius: 0.0, softness: 0.5),
      );
      final b = postProcessShaderFileName(
        'vignette',
        vignetteShader(power: 0.7, aspect: 1.0, radius: 0.0, softness: 0.5),
      );
      expect(a, isNot(b));
    });

    test('保留 .glsl 扩展名、带效果前缀', () {
      final name = postProcessShaderFileName(
        'scanlines',
        scanlinesShader(density: 1.0, intensity: 1.0),
      );
      expect(name, startsWith('scanlines_'));
      expect(name, endsWith('.glsl'));
    });
  });

  void expectUserShader(String src) {
    expect(src, contains('//!HOOK MAIN'));
    expect(src, contains('//!BIND HOOKED'));
    // mpv 用户着色器没有 uniform，参数只能是字面量
    expect(src, isNot(contains('uniform')));
    // 花括号配平（结构没写坏）
    expect('{'.allMatches(src).length, '}'.allMatches(src).length);
  }

  group('暗角', () {
    test('四个参数烧进源码、alpha = 1.0', () {
      final src = vignetteShader(
        power: 0.8,
        aspect: 1.5,
        radius: 0.2,
        softness: 0.4,
      );
      expectUserShader(src);
      expect(src, contains('0.8'));
      expect(src, contains('1.5'));
      // 半径 0.2 + 柔和度 0.4 → 过渡区间写成 [0.2, 0.6]
      expect(src, contains('smoothstep(0.2, 0.6, d)'));
      expect(src, contains('return vec4(rgb * v, 1.0);'));
    });

    test('半径 / 柔和度变化会生成不同源码', () {
      final base = vignetteShader(
        power: 0.3,
        aspect: 1.0,
        radius: 0.0,
        softness: 0.5,
      );
      expect(
        base,
        isNot(vignetteShader(
          power: 0.9,
          aspect: 1.0,
          radius: 0.0,
          softness: 0.5,
        )),
      );
      expect(
        base,
        isNot(vignetteShader(
          power: 0.3,
          aspect: 1.0,
          radius: 0.4,
          softness: 0.5,
        )),
      );
    });
  });

  group('扫描线', () {
    test('参数烧进源码、alpha = 1.0（PPSSPP 原版写了 0）', () {
      final src = scanlinesShader(density: 1.4, intensity: 1.8);
      expectUserShader(src);
      expect(src, contains('1.4'));
      expect(src, contains('1.8'));
      expect(src, contains('clamp(pos1, 0.0, 1.0)'));
      expect(src, contains('), 1.0);'));
    });
  });

  group('自然色彩', () {
    test('16 次局部抽样 + YIQ 提亮/提色，alpha = 1.0', () {
      final src = naturalColorsShader(luma: 1.3, chroma: 1.15);
      expectUserShader(src);
      expect(src, contains('RGBtoYIQ'));
      expect(src, contains('YIQtoRGB'));
      expect(src, contains('1.3'));
      expect(src, contains('1.15'));
      expect('tap(vec2('.allMatches(src).length, 16);
      expect(src, contains('return vec4(YIQtoRGB * c1, 1.0);'));
    });
  });

  group('泛光', () {
    test('循环内 3 次采样 + 混合强度，alpha = 1.0', () {
      final src = bloomShader(amount: 0.7, spread: 0.5);
      expectUserShader(src);
      expect(src, contains('0.7'));
      expect(src, contains('0.5'));
      // 3 条采样在 for 循环里（i = -3..2 共 18 次）
      expect('HOOKED_texOff('.allMatches(src).length, 3);
      expect(src, contains('for (int i = -3; i < 3; i++)'));
      expect(src, contains('mix(color, bloom, 0.7)'));
    });
  });

  group('卡通', () {
    test('9 点取样 + 边缘强度，alpha = 1.0', () {
      final src = cartoonShader(edgeStrength: 0.6);
      expectUserShader(src);
      expect(src, contains('0.6'));
      expect('tap(vec2('.allMatches(src).length, 9);
      expect(src, contains('return vec4(0.25 * lc *'));
    });
  });
}
