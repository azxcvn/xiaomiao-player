import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/super_resolution_mode.dart';
import 'package:moumou/utils/anime4k_patch.dart';

/// Anime4K 着色器安装期优化纯函数测试（§4.25）：
/// - pass 切分（`//!DESC`/`//!HOOK` 起始、许可注释独立成块）；
/// - 精度注入：mediump 默认、FSR 位运算 pass 保持 highp、函数签名/已限定符/
///   预处理指令/注释不动、空行不再中断注入（本项目对 mpvRx 的修正）；
/// - C.R.E.L.U. 采样合并：3×3 预取 + `go_0/go_1` 调用改写、非同纹理/非
///   C.R.E.L.U. pass 原样返回、越界偏移整体退回；
/// - 幂等 + 真实 assets 全量烟测（所有着色器都能改写且结构完好）。
void main() {
  group('splitAnime4kPasses', () {
    test('按 //!DESC 与 //!HOOK 切分，许可注释单独成块', () {
      const src = '// license\n'
          '//!DESC pass1\n'
          '//!HOOK MAIN\n'
          'vec4 hook() { return vec4(1.0); }\n'
          '//!DESC pass2\n'
          'vec4 hook() { return vec4(0.0); }\n';
      final parts = splitAnime4kPasses(src);
      expect(parts.length, 3);
      expect(parts.first.trim(), '// license');
      expect(parts[1], startsWith('//!DESC pass1'));
      expect(parts[2], startsWith('//!DESC pass2'));
    });

    test('无 //! 头时整段成块', () {
      const src = 'vec4 hook() { return vec4(1.0); }\n';
      expect(splitAnime4kPasses(src), [src]);
    });
  });

  group('精度注入', () {
    test('普通 pass 注入 mediump float + highp int', () {
      const src = '//!DESC p\n'
          '//!HOOK MAIN\n'
          'vec4 hook() {\n'
          '    vec4 result = vec4(1.0);\n'
          '    float g = 0.5;\n'
          '    return result * g;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, contains('precision mediump float;'));
      expect(out, contains('precision highp int;'));
      expect(out, contains('mediump vec4 result = vec4(1.0);'));
      expect(out, contains('mediump float g = 0.5;'));
      // 精度声明必须落在 pass 头之后、正文之前
      expect(out.indexOf('precision mediump float;'),
          lessThan(out.indexOf('mediump vec4 result')));
    });

    test('FSR 位运算 pass 保持 highp', () {
      const src = '//!DESC fsr\n'
          '//!HOOK MAIN\n'
          'vec4 hook() {\n'
          '    uint bits = floatBitsToUint(0.5);\n'
          '    vec4 result = vec4(1.0);\n'
          '    return result;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, contains('precision highp float;'));
      expect(out, isNot(contains('precision mediump float;')));
      expect(out, contains('highp vec4 result'));
    });

    test('函数签名/已限定符行/预处理指令/注释不动', () {
      const src = '//!DESC p\n'
          '//!HOOK MAIN\n'
          '#define KERNELSIZE 5 // note\n'
          '// 普通注释\n'
          'float get_luma(vec4 rgba) {\n'
          '    highp float already = 1.0;\n'
          '    mediump vec4 qualified = vec4(1.0);\n'
          '    return already + qualified.x + rgba.x;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, contains('#define KERNELSIZE 5 // note'));
      expect(out, contains('// 普通注释'));
      expect(out, contains('float get_luma(vec4 rgba) {')); // 函数签名
      expect(out, contains('highp float already = 1.0;'));
      expect(out, contains('mediump vec4 qualified = vec4(1.0);'));
      // 只注入一次精度声明
      expect('precision mediump float;'.allMatches(out).length, 1);
    });

    test('头与正文之间的空行不中断注入（本项目对 mpvRx 的修正）', () {
      const src = '//!DESC p\n'
          '//!HOOK MAIN\n'
          '\n'
          'vec4 hook() {\n'
          '    float g = 1.0;\n'
          '    return vec4(g);\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, contains('precision mediump float;'));
      expect(out, contains('mediump float g = 1.0;'));
    });

    test('多个 pass 各自注入（每块一次）', () {
      const src = '//!DESC p1\n'
          '//!HOOK MAIN\n'
          'vec4 hook() {\n'
          '    float a = 1.0;\n'
          '    return vec4(a);\n'
          '}\n'
          '//!DESC p2\n'
          '//!HOOK MAIN\n'
          'vec4 hook() {\n'
          '    float b = 2.0;\n'
          '    return vec4(b);\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect('precision mediump float;'.allMatches(out).length, 2);
      expect(out, contains('mediump float a = 1.0;'));
      expect(out, contains('mediump float b = 2.0;'));
    });
  });

  group('C.R.E.L.U. 采样合并', () {
    String creluPass() => '//!DESC conv\n'
        '//!HOOK MAIN\n'
        '//!BIND conv2d_tf\n'
        '#define go_0(x_off, y_off) (max((conv2d_tf_texOff(vec2(x_off, y_off))), 0.0))\n'
        '#define go_1(x_off, y_off) (max(-(conv2d_tf_texOff(vec2(x_off, y_off))), 0.0))\n'
        'vec4 hook() {\n'
        '    vec4 result = go_0(-1.0, -1.0);\n'
        '    result += go_1(0.0, 0.0);\n'
        '    return result;\n'
        '}\n';

    test('合并为 3×3 预取并改写调用', () {
      final out = optimizeAnime4kShader('t.glsl', creluPass());
      expect(out, contains('// optimized go_0 macro'));
      expect(out, contains('// optimized go_1 macro'));
      expect(out, contains('vec4 t_m1_m1 = conv2d_tf_texOff(vec2(-1.0, -1.0));'));
      expect(out, contains('vec4 t_0_0   = conv2d_tf_texOff(vec2(0.0, 0.0));'));
      expect(out, contains('max(t_m1_m1, 0.0)'));
      expect(out, contains('max(-t_0_0, 0.0)'));
      // 宏调用已全部改写
      expect(out, isNot(contains('go_0(-1.0')));
      expect(out, isNot(contains('go_1(0.0')));
      // 预取声明数 = 9
      expect('conv2d_tf_texOff('.allMatches(out).length, 9);
    });

    test('非 C.R.E.L.U.（无 max 宏）不合并', () {
      const src = '//!DESC conv\n'
          '//!HOOK MAIN\n'
          '//!BIND MAIN\n'
          '#define go_0(x_off, y_off) (MAIN_texOff(vec2(x_off, y_off)))\n'
          'vec4 hook() {\n'
          '    vec4 result = go_0(-1.0, -1.0);\n'
          '    return result;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, isNot(contains('optimized go_0 macro')));
      expect(out, contains('go_0(-1.0, -1.0)'));
    });

    test('go_0/go_1 引用不同纹理时不合并', () {
      const src = '//!DESC conv\n'
          '//!HOOK MAIN\n'
          '#define go_0(x_off, y_off) (max((tex_a_texOff(vec2(x_off, y_off))), 0.0))\n'
          '#define go_1(x_off, y_off) (max(-(tex_b_texOff(vec2(x_off, y_off))), 0.0))\n'
          'vec4 hook() {\n'
          '    vec4 result = go_0(0.0, 0.0) + go_1(0.0, 0.0);\n'
          '    return result;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, isNot(contains('optimized go_0 macro')));
    });

    test('偏移超出 3×3 时整体退回原 pass（防 t_unknown_* 编译失败）', () {
      const src = '//!DESC conv\n'
          '//!HOOK MAIN\n'
          '#define go_0(x_off, y_off) (max((t_texOff(vec2(x_off, y_off))), 0.0))\n'
          '#define go_1(x_off, y_off) (max(-(t_texOff(vec2(x_off, y_off))), 0.0))\n'
          'vec4 hook() {\n'
          '    vec4 result = go_0(2.0, 0.0) + go_1(0.0, 0.0);\n'
          '    return result;\n'
          '}\n';
      final out = optimizeAnime4kShader('t.glsl', src);
      expect(out, isNot(contains('_unknown')));
      expect(out, contains('go_0(2.0, 0.0)'));
    });
  });

  group('整体性质', () {
    test('幂等：重复优化结果不变', () {
      final src = File('assets/shaders/Anime4K_Upscale_CNN_x2_M.glsl')
          .readAsStringSync();
      final once = optimizeAnime4kShader('Anime4K_Upscale_CNN_x2_M.glsl', src);
      final twice =
          optimizeAnime4kShader('Anime4K_Upscale_CNN_x2_M.glsl', once);
      expect(twice, once);
    });

    test('非 .glsl 原样返回', () {
      expect(optimizeAnime4kShader('readme.txt', 'hello'), 'hello');
    });

    test('全部 assets 着色器可优化且结构完好', () {
      final files = Directory('assets/shaders')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.glsl'))
          .toList();
      expect(files, isNotEmpty);
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        final src = f.readAsStringSync();
        final out = optimizeAnime4kShader(name, src);
        expect(out, isNotEmpty, reason: name);
        // pass 头数量与括号配平都不变
        expect('//!DESC'.allMatches(out).length,
            '//!DESC'.allMatches(src).length,
            reason: name);
        expect('//!HOOK'.allMatches(out).length,
            '//!HOOK'.allMatches(src).length,
            reason: name);
        expect('{'.allMatches(out).length, '{'.allMatches(src).length,
            reason: name);
        expect('}'.allMatches(out).length, '}'.allMatches(src).length,
            reason: name);
        // 每个含 //!HOOK 的着色器都注入了精度
        if (src.contains('//!HOOK')) {
          expect(out, contains('precision '), reason: name);
        }
        // 不得残留未声明的预取变量
        expect(out, isNot(contains('t_unknown')), reason: name);
      }
    });

    test('全部链上着色器都被真实改写（至少一处精度注入）', () {
      final names = <String>{
        for (final m in SuperResolutionMode.values)
          for (final q in SuperResolutionQuality.values)
            ...buildAnime4KChain(m, q),
      };
      for (final name in names) {
        final src = File('assets/shaders/$name').readAsStringSync();
        final out = optimizeAnime4kShader(name, src);
        expect(out, contains('precision '), reason: name);
      }
    });
  });
}
