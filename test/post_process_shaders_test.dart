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

  group('降噪', () {
    test('双边滤波：两个 sigma 烧进源码，MIT 署名保留', () {
      final src = denoiseShader(strength: 0.1, radius: 1.0);
      expectUserShader(src);
      expect(src, contains('INTENSITY_SIGMA 0.1'));
      expect(src, contains('SPATIAL_SIGMA 1.0'));
      expect(src, contains('KERNELLEN'));
      expect(src, contains('bloc97'));
      expect(src, contains('return sum / n;'));
    });

    test('半径不同 → 内核大小不同、源码不同', () {
      final small = denoiseShader(strength: 0.1, radius: 0.3);
      final big = denoiseShader(strength: 0.1, radius: 1.0);
      expect(small, contains('SPATIAL_SIGMA 0.3'));
      expect(big, contains('SPATIAL_SIGMA 1.0'));
      expect(small, isNot(big));
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

  group('白平衡', () {
    test('色温/色调烧进源码，增益按亮度归一化', () {
      final src = whiteBalanceShader(temperature: 30, tint: -20);
      expectUserShader(src);
      expect(src, contains('float temp = 30.0;'));
      expect(src, contains('float tint = -20.0;'));
      expect(src, contains('kelvinRGB'));
      expect(src, contains('dot(wb, vec3(0.2126, 0.7152, 0.0722))'));
    });
  });

  group('色阶', () {
    test('黑位/白位/伽马烧进源码', () {
      final src = levelsShader(inBlack: 0.05, inWhite: 0.95, gamma: 1.2);
      expectUserShader(src);
      expect(src, contains('clamp((rgb - 0.05)'));
      expect(src, contains('0.95 - 0.05'));
      expect(src, contains('vec3(1.0 / 1.2)'));
    });
  });

  group('胶片曲线', () {
    test('曝光/暗部/高光/强度烧进源码，toe+shoulder 双段', () {
      final src = filmicCurveShader(
        exposure: 1.2,
        toe: 1.5,
        shoulder: 2.0,
        amount: 0.8,
      );
      expectUserShader(src);
      expect(src, contains('max(c * 1.2, vec3(0.0))'));
      expect(src, contains('1.0 / 1.5'));
      expect(src, contains('pow(1.0 - pos, 2.0)'));
      expect(src, contains('mix(c, m, 0.8)'));
    });
  });

  group('胶片颗粒', () {
    test('强度/尺寸烧进源码，中间调加权', () {
      final src = filmGrainShader(intensity: 0.05, size: 2.0);
      expectUserShader(src);
      expect(src, contains('mono * 0.05 * response'));
      expect(src, contains('max(2.0, 1.0)'));
      expect(src, contains('float response = 1.0 - abs(luma * 2.0 - 1.0);'));
    });
  });
}
