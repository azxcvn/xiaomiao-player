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

/// 降噪：双边滤波（Anime4K v3.2 `Denoise_Bilateral_Mean.glsl`，MIT）。
///
/// 源文件原样移植：只把 `INTENSITY_SIGMA` / `SPATIAL_SIGMA` 两个 #define
/// 换成参数，其它（高斯权重、内核大小推导、双重循环）保持原样。
/// 内核大小由 `SPATIAL_SIGMA` 推导并封顶 5×5（上限 1.0），最多 25 次抽样。
String denoiseShader({required double strength, required double radius}) {
  final s = glslFloat(strength);
  final r = glslFloat(radius);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: denoise (Anime4K v3.2 Bilateral Mean)

// MIT License
// Copyright (c) 2019-2021 bloc97
// 本文件移植自 Anime4K v3.2 glsl/Denoise/Anime4K_Denoise_Bilateral_Mean.glsl，
// 仅将两个 #define 参数化，算法保持不变。

#define INTENSITY_SIGMA $s
#define SPATIAL_SIGMA $r
#define INTENSITY_POWER_CURVE 1.0

#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1)
#define KERNELHALFSIZE (int(KERNELSIZE/2))
#define KERNELLEN (KERNELSIZE * KERNELSIZE)
#define GETOFFSET(i) vec2((i % KERNELSIZE) - KERNELHALFSIZE, (i / KERNELSIZE) - KERNELHALFSIZE)

vec4 gaussian_vec(vec4 x, vec4 s, vec4 m) {
    vec4 scaled = (x - m) / s;
    return exp(-0.5 * scaled * scaled);
}
float gaussian(float x, float s, float m) {
    float scaled = (x - m) / s;
    return exp(-0.5 * scaled * scaled);
}

vec4 hook() {
    vec4 sum = vec4(0.0);
    vec4 n = vec4(0.0);
    vec4 vc = HOOKED_tex(HOOKED_pos);
    vec4 is = pow(vc + 0.0001, vec4(INTENSITY_POWER_CURVE)) * INTENSITY_SIGMA;
    float ss = SPATIAL_SIGMA;
    for (int i = 0; i < KERNELLEN; i++) {
        vec2 ipos = GETOFFSET(i);
        vec4 v = HOOKED_texOff(ipos);
        vec4 d = gaussian_vec(v, is, vc) * gaussian(length(ipos), ss, 0.0);
        sum += d * v;
        n += d;
    }
    return sum / n;
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

/// 白平衡：色温 / 色调（Planckian 近似曲线，自写）。
///
/// [temperature] 与 [tint] 都是 -100~100，0 为原样；
/// 色温正 = 暖（往 3000K 偏），负 = 冷（往 10000K 偏）；
/// 色调正 = 品红，负 = 绿。增益按 Rec.709 亮度归一化，避免整体变亮/变暗。
String whiteBalanceShader({
  required double temperature,
  required double tint,
}) {
  final t = glslFloat(temperature);
  final ti = glslFloat(tint);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: white balance

vec3 kelvinRGB(float temp) {
    float t = temp / 100.0;
    float r, g, b;
    if (t <= 66.0) {
        r = 255.0;
        g = 99.4708025861 * log(t) - 161.1195681661;
        b = (t <= 19.0) ? 0.0 : 138.5177312231 * log(t - 10.0) - 305.0447927307;
    } else {
        r = 329.698727446 * pow(t - 60.0, -0.1332047592);
        g = 288.1221695283 * pow(t - 60.0, -0.0755148492);
        b = 255.0;
    }
    return clamp(vec3(r, g, b) / 255.0, 0.0, 1.0);
}

vec4 hook() {
    float temp = $t;
    float tint = $ti;
    float target = 6500.0 - temp * 35.0;
    vec3 wb = kelvinRGB(target) / max(kelvinRGB(6500.0), vec3(0.001));
    wb.g *= 1.0 - tint * 0.0015;
    wb.r *= 1.0 + tint * 0.0005;
    wb.b *= 1.0 + tint * 0.0005;
    wb /= max(dot(wb, vec3(0.2126, 0.7152, 0.0722)), 0.001);
    vec3 rgb = HOOKED_tex(HOOKED_pos).rgb;
    return vec4(clamp(rgb * wb, 0.0, 1.0), 1.0);
}
''';
}

/// 色阶（Levels）：黑位 / 白位 / 伽马（自写）。
///
/// 把 [inBlack]~[inWhite] 重新映射到 0~1，再做伽马，专门治“黑位发灰”。
String levelsShader({
  required double inBlack,
  required double inWhite,
  required double gamma,
}) {
  final ib = glslFloat(inBlack);
  final iw = glslFloat(inWhite);
  final g = glslFloat(gamma);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: levels

vec4 hook() {
    vec3 rgb = HOOKED_tex(HOOKED_pos).rgb;
    rgb = clamp((rgb - $ib) / max($iw - $ib, 0.0001), 0.0, 1.0);
    rgb = pow(rgb, vec3(1.0 / $g));
    return vec4(rgb, 1.0);
}
''';
}

/// 胶片曲线：曝光 + 暗部抬升 + 高光压缩（自写）。
///
/// [toe] > 1 提亮暗部，[shoulder] > 1 压缩高光，[amount] 与原始画面混合。
String filmicCurveShader({
  required double exposure,
  required double toe,
  required double shoulder,
  required double amount,
}) {
  final e = glslFloat(exposure);
  final t = glslFloat(toe);
  final s = glslFloat(shoulder);
  final a = glslFloat(amount);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: filmic curve

float toeMap(float x) {
    const float knee = 0.4;
    return (x < knee) ? knee * pow(max(x, 0.0) / knee, 1.0 / $t) : x;
}

float shoulderMap(float x) {
    const float knee = 0.6;
    if (x <= knee) return x;
    float pos = (x - knee) / (1.0 - knee);
    return knee + (1.0 - knee) * (1.0 - pow(1.0 - pos, $s));
}

vec4 hook() {
    vec3 c = HOOKED_tex(HOOKED_pos).rgb;
    vec3 m = max(c * $e, vec3(0.0));
    m = clamp(vec3(toeMap(m.r), toeMap(m.g), toeMap(m.b)), 0.0, 1.0);
    m = clamp(vec3(shoulderMap(m.r), shoulderMap(m.g), shoulderMap(m.b)), 0.0, 1.0);
    return vec4(mix(c, m, $a), 1.0);
}
''';
}

/// 胶片颗粒：中间调加权的静态颗粒（自写）。
///
/// [intensity] 0~0.2，[size] 1~4 像素。
String filmGrainShader({required double intensity, required double size}) {
  final i = glslFloat(intensity);
  final s = glslFloat(size);
  return '''
//!HOOK MAIN
//!BIND HOOKED
//!DESC Post-process: film grain

float grainHash(vec2 p) {
    vec3 s = fract(vec3(p.x, p.y, p.x) * 0.1031);
    s += dot(s, s.yzx + 33.33);
    return fract((s.x + s.y) * s.z);
}

vec4 hook() {
    vec3 rgb = HOOKED_tex(HOOKED_pos).rgb;
    vec2 cell = floor(HOOKED_pos * HOOKED_size / max($s, 1.0));
    float mono = grainHash(cell) - 0.5;
    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    float response = 1.0 - abs(luma * 2.0 - 1.0);
    return vec4(clamp(rgb + mono * $i * response, 0.0, 1.0), 1.0);
}
''';
}
