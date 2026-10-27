/// 后处理着色器源码生成（纯函数，可单测）。
///
/// 三个风格化效果移植自 PPSSPP 的 post-processing shader（GPL-2.0-or-later，
/// 与本项目 GPL-3.0 兼容，来源与作者见 THIRD_PARTY_NOTICES.md）：
/// - 暗角：`vignette.fsh`（Henrik Rydgård）
/// - 扫描线：`scanlines.fsh`（PPSSPP 自带）
/// - 自然色彩：`natural.fsh` + `natural.vsh`（ShadX，PPSSPP 版由 SimoneT 修改）
///
/// 移植约定（PPSSPP 与 mpv 用户着色器的差异）：
/// - **参数**：PPSSPP 用 `uniform`（u_setting/u_texelDelta）由宿主逐帧写入；
///   mpv 的用户着色器**没有运行时 uniform**，所以参数在生成源码时直接烧成
///   字面量（与 mpvRx 的做法一致，实现与代码均为本项目自己写的）；
/// - **采样**：`texture2D(sampler0, uv)` → `HOOKED_tex(uv)`，像素偏移采样 →
///   `HOOKED_texOff(vec2)`；`v_texcoord0.xy` → `HOOKED_pos`；
/// - **alpha**：PPSSPP 部分 shader 把 alpha 写成 0（它不参与视频合成），
///   这里统一输出 `alpha = 1.0`，否则 mpv 会画出透明/黑屏；
/// - **暗角的强度**：PPSSPP 原版把暗角系数乘了两次（`rgb *= v` 后又
///   `gl_FragColor.rgb = v * rgb`），这里只乘一次，观感更接近"轻微压角"，
///   强度仍由参数控制。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 浮点数 → 合法 GLSL 字面量（必须有小数点：`1` → `1.0`）
String glslFloat(double value) {
  final s = value.toStringAsFixed(4);
  final trimmed = s
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '.0');
  return trimmed;
}

/// 着色器源码 → 落盘文件名（内容 hash 后缀）。
///
/// **必须带 hash**：mpv 只在 `glsl-shaders` 的**值**变化时才重载着色器。参数
/// 改了、文件内容重写了，但链里的路径没变的话，mpv 会认为"没变化"而不重读
/// 文件——表现就是"拉滑杆没反应，退出重进播放才生效"。换文件名 = 换链值，
/// mpv 才会重新加载（见 `services/post_process_service.dart`）。
String postProcessShaderFileName(String base, String source) {
  final hash = md5.convert(utf8.encode(source)).toString().substring(0, 10);
  return '${base}_$hash.glsl';
}

/// 暗角：四角压暗。
///
/// - [power]：压暗强度；[aspect]：宽高比拉伸（>1 压左右，<1 压上下）；
/// - [radius]：从画面中心算起、暗角**开始**的位置（0 = 中心就开始，0.9 = 只在最边缘）；
/// - [softness]：过渡宽度（越小越像"硬边"，越大越柔和）。
String vignetteShader({
  required double power,
  required double aspect,
  required double radius,
  required double softness,
}) {
  final p = glslFloat(power);
  final a = glslFloat(aspect);
  final r = glslFloat(radius);
  final rEnd = glslFloat(radius + softness);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: vignette
vec4 hook() {
    vec2 diff = HOOKED_pos - 0.5;
    diff.x *= $a;
    diff.y /= $a;
    // 0 = 画面中心，1 = 四角（对角线长度的倒数归一化）
    float d = length(diff) / 0.70710678;
    float f = smoothstep($r, $rEnd, d);
    float v = 1.0 - $p * f;
    vec3 rgb = HOOKED_tex(HOOKED_pos).rgb;
    return vec4(rgb * v, 1.0);
}
''';
}

/// 扫描线（CRT 观感）：`density` 控制线密度，`intensity` 控制明暗幅度
String scanlinesShader({required double density, required double intensity}) {
  final d = glslFloat(density);
  final i = glslFloat(intensity);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: scanlines
vec4 hook() {
    float pos0 = ((HOOKED_pos.y + 1.0) * 170.0 * $d);
    float pos1 = cos((fract(pos0) - 0.5) * 3.1415926 * $i) * 1.5;
    vec4 rgb = HOOKED_tex(HOOKED_pos);
    // 轻微对比曲线 + 暖色偏移（PPSSPP 原版观感）
    vec3 color = rgb.rgb * 0.5 + 0.5 * rgb.rgb * rgb.rgb * 1.2;
    color *= vec3(0.9, 1.0, 0.7);
    color *= 1.1 - 0.6 * (dot(HOOKED_pos - 0.5, HOOKED_pos - 0.5) * 2.0);
    return vec4(mix(vec3(0.0), color, clamp(pos1, 0.0, 1.0)), 1.0);
}
''';
}

/// 自然色彩：16 抽样的局部平滑 + YIQ 空间提亮/提饱和
String naturalColorsShader({required double luma, required double chroma}) {
  final l = glslFloat(luma);
  final c = glslFloat(chroma);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: natural colors
const mat3 RGBtoYIQ = mat3(0.299, 0.596, 0.212,
                           0.587,-0.275,-0.523,
                           0.114,-0.321, 0.311);
const mat3 YIQtoRGB = mat3(1.0, 1.0, 1.0,
                           0.9556880603611567,-0.2715817969440586,-1.1081773266826620,
                           0.6198580944563708,-0.6468738161384013, 1.7050645599191817);

vec3 tap(vec2 off) {
    return HOOKED_texOff(off).rgb;
}

vec4 hook() {
    vec3 c0 = vec3(0.0);
    c0 += tap(vec2(-0.5, -0.5));
    c0 += tap(vec2(-0.5, -1.5)) * 0.25;
    c0 += tap(vec2(-1.5, -0.5)) * 0.25;
    c0 += tap(vec2(-1.5, -1.5)) * 0.125;
    c0 += tap(vec2(0.5, -0.5));
    c0 += tap(vec2(0.5, -1.5)) * 0.25;
    c0 += tap(vec2(1.5, -0.5)) * 0.25;
    c0 += tap(vec2(1.5, -1.5)) * 0.125;
    c0 += tap(vec2(-0.5, 0.5));
    c0 += tap(vec2(-0.5, 1.5)) * 0.25;
    c0 += tap(vec2(-1.5, 0.5)) * 0.25;
    c0 += tap(vec2(-1.5, 1.5)) * 0.125;
    c0 += tap(vec2(0.5, 0.5));
    c0 += tap(vec2(0.5, 1.5)) * 0.25;
    c0 += tap(vec2(1.5, 0.5)) * 0.25;
    c0 += tap(vec2(1.5, 1.5)) * 0.125;
    c0 *= 0.153846154;

    vec3 c1 = RGBtoYIQ * c0;
    c1 = vec3(pow(c1.x, $l), c1.yz * $c);
    return vec4(YIQtoRGB * c1, 1.0);
}
''';
}

/// 泛光：高光外溢（PPSSPP `bloom.fsh`，18 抽样，低端 GPU 也能跑）。
///
/// [amount] 为混合强度（0 = 关），[spread] 为抽样权重（越大光晕越亮）。
String bloomShader({required double amount, required double spread}) {
  final a = glslFloat(amount);
  final w = glslFloat(spread);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: bloom
vec4 hook() {
    vec3 color = HOOKED_tex(HOOKED_pos).xyz;
    vec4 sum = vec4(0.0);
    // PPSSPP 的偏移单位是 UV（0.004），mpv 的 texOff 用像素：乘源尺寸换算
    vec2 stepUv = vec2(0.004, 0.004) * HOOKED_size;
    for (int i = -3; i < 3; i++) {
        sum += HOOKED_texOff(vec2(-1.0, float(i)) * stepUv) * $w;
        sum += HOOKED_texOff(vec2(0.0, float(i)) * stepUv) * $w;
        sum += HOOKED_texOff(vec2(1.0, float(i)) * stepUv) * $w;
    }
    vec3 bloom;
    if (color.r < 0.3 && color.g < 0.3 && color.b < 0.3) {
        bloom = sum.xyz * sum.xyz * 0.012 + color;
    } else if (color.r < 0.5 && color.g < 0.5 && color.b < 0.5) {
        bloom = sum.xyz * sum.xyz * 0.009 + color;
    } else {
        bloom = sum.xyz * sum.xyz * 0.0075 + color;
    }
    return vec4(mix(color, bloom, $a), 1.0);
}
''';
}

/// 卡通：边缘检测 + 色阶量化（PPSSPP `cartoon.fsh`，作者 guest(r)，GNU-GPL）。
///
/// [edgeStrength] 越大边缘越黑、线条越重（PPSSPP 的 `Black border` 参数）。
String cartoonShader({required double edgeStrength}) {
  final e = glslFloat(edgeStrength);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: cartoon
vec3 tap(vec2 off) {
    return HOOKED_texOff(off).xyz;
}

vec4 hook() {
    // 3x3 九点（PPSSPP 顶点着色器里的 0.8 像素偏移）
    vec3 c00 = tap(vec2(-0.8, -0.8));
    vec3 c10 = tap(vec2(0.0, -0.8));
    vec3 c20 = tap(vec2(0.8, -0.8));
    vec3 c01 = tap(vec2(-0.8, 0.0));
    vec3 c11 = tap(vec2(0.0, 0.0));
    vec3 c21 = tap(vec2(0.8, 0.0));
    vec3 c02 = tap(vec2(-0.8, 0.8));
    vec3 c12 = tap(vec2(0.0, 0.8));
    vec3 c22 = tap(vec2(0.8, 0.8));

    vec3 dt = vec3(1.0, 1.0, 1.0);
    float d1 = dot(abs(c00 - c22), dt);
    float d2 = dot(abs(c20 - c02), dt);
    float hl = dot(abs(c01 - c21), dt);
    float vl = dot(abs(c10 - c12), dt);
    float d = $e * (d1 + d2 + hl + vl) / (dot(c11, dt) + 0.15);

    float lc = 4.0 * length(c11);
    float f = fract(lc);
    f *= f;
    lc = 0.25 * (floor(lc) + f * f) + 0.05;
    vec3 q = 4.0 * normalize(c11);
    vec3 frct = fract(q);
    frct *= frct;
    q = floor(q) + 0.05 * dt + frct * frct;
    return vec4(0.25 * lc * (1.1 - d * sqrt(d)) * q, 1.0);
}
''';
}
