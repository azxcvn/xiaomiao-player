import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/player_shader_pipeline.dart';

/// 超分/后处理共用的着色器链拼接规则：超分在前、后处理在后，空项不产生空段。
void main() {
  group('composeShaderChain', () {
    test('空链 + 空链 = 空链（mpv 收到 clr）', () {
      expect(composeShaderChain(const [], const []), isEmpty);
    });

    test('只有超分', () {
      expect(
        composeShaderChain(['/a.glsl', '/b.glsl'], const []),
        ['/a.glsl', '/b.glsl'],
      );
    });

    test('只有后处理', () {
      expect(
        composeShaderChain(const [], ['/v.glsl']),
        ['/v.glsl'],
      );
    });

    test('超分在前、后处理在后（先放大再加效果）', () {
      expect(
        composeShaderChain(['/anime.glsl'], ['/color.glsl', '/vignette.glsl']),
        ['/anime.glsl', '/color.glsl', '/vignette.glsl'],
      );
    });

    test('空字符串被过滤', () {
      expect(composeShaderChain([''], ['/x.glsl', '']), ['/x.glsl']);
    });
  });
}
