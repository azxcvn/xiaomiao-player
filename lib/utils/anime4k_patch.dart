/// Anime4K 着色器「安装期」优化纯函数（对齐 mpvRx `Anime4KManager.optimizeShaderContent`）。
///
/// 首次把 `assets/shaders/*.glsl` 拷进沙盒时一次性改写源码，**运行期零成本**：
/// 1. 每个 pass 块（以 `//!` 头开始）注入 `precision mediump float;` +
///    `precision highp int;`，并把块内 float 类型变量声明显式加精度限定符——
///    Adreno 等移动驱动会在看到 `mat4` × float 字面量时把默认 mediump 静默
///    提升回 FP32（注释里写明「只有显式限定符无法被驱动覆盖」）；
/// 2. 依赖位运算的 FSR 类 pass（`floatBitsToUint` 等）保持 `highp`——
///    FP16 下这些位技巧会产生垃圾值；
/// 3. C.R.E.L.U. 卷积 pass 的重复纹理采样合并为 3×3 预取（每次卷积少 6 次
///    纹理读取）。
///
/// 与参考实现的差异（有意为之）：mpvRx 在 `//!` 头后遇到**空行**即放弃该
/// pass 的精度注入，而本项目全部着色器都在头与正文之间留有空行——照抄会导致
/// 一个 pass 都注入不上。这里把空行视为「头部间隙」继续向后找首个正文行，
/// 保证每个 pass 都注入（其余逻辑逐条对齐）。
library;

/// 补丁版本号：改动优化算法时 +1，[SuperResolutionService] 据此把已拷出的
/// 旧着色器重新拷贝并重写一遍（升级后无需清数据）。
const int kAnime4kPatchVersion = 1;

/// 需要 FP32（highp）的 GLSL 记号：命中任一即该 pass 不做 FP16 降精度。
///
/// 对齐 mpvRx `FP32_MARKERS`（FSR EASU/RCAS 的位运算与近似倒数/平方根）。
const List<String> kAnime4kFp32Markers = [
  'floatBitsToUint',
  'uintBitsToFloat',
  'floatBitsToInt',
  'intBitsToFloat',
  'bitfieldExtract',
  'bitfieldInsert',
  'FsrEasu',
  'FsrRcas',
  'APrxLoRcpF1',
  'APrxLoRsqF1',
  'APrxMedRcpF1',
];

/// float 类型关键字（长的在前，避免 `vec4` 被 `vec` 误匹配）。
const List<String> _floatTypes = ['mat4', 'mat3', 'mat2', 'vec4', 'vec3', 'vec2', 'float'];

/// pass 起始标记正则：优先用 `//!DESC`（Anime4K 每个 pass 都有），
/// 缺失时退回 `//!HOOK`——按 `//!HOOK` 切会把「头 + 正文」拆成两块。
final RegExp _passDescStart = RegExp(r'//!DESC');
final RegExp _passHookStart = RegExp(r'//!HOOK');

/// 把着色器源码拆成 pass 块（每块以 `//!` 头开头，首部许可注释单独成块）。
///
/// 不用 `String.split` 的零宽前瞻——Dart 对零宽匹配的切分语义与 Kotlin/JS
/// 不同，手工按匹配下标切分结果稳定可测。
List<String> splitAnime4kPasses(String content) {
  var starts = <int>[for (final m in _passDescStart.allMatches(content)) m.start];
  if (starts.isEmpty) {
    starts = [for (final m in _passHookStart.allMatches(content)) m.start];
  }
  if (starts.isEmpty) return [content];
  final parts = <String>[];
  if (starts.first > 0) parts.add(content.substring(0, starts.first));
  for (var i = 0; i < starts.length; i++) {
    final end = (i + 1 < starts.length) ? starts[i + 1] : content.length;
    parts.add(content.substring(starts[i], end));
  }
  return parts;
}

/// pass 正文是否含 FP32 敏感记号（含则保持 highp）。
bool anime4kPassNeedsHighp(String passBody) =>
    kAnime4kFp32Markers.any(passBody.contains);

/// 优化一个着色器文件的源码（非 `.glsl` 原样返回）。
///
/// 幂等：对已优化内容再跑一次结果不变（精度注入有 `precision` 前缀守卫，
/// C.R.E.L.U. 合并因宏已被注释掉而自然跳过）。
String optimizeAnime4kShader(String fileName, String content) {
  if (!fileName.endsWith('.glsl')) return content;
  return _optimizeCreluPasses(_injectPrecision(content));
}

/// 逐行注入精度限定符。
String _injectPrecision(String content) {
  final lines = content.split('\n');
  final out = <String>[];
  var inHeader = false;
  var injectedForBlock = false;
  var needsHighp = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.startsWith('//!')) {
      if (!inHeader) {
        inHeader = true;
        injectedForBlock = false;
      }
      out.add(line);
      continue;
    }

    if (inHeader) {
      // 空行留在头部间隙里，继续等首个正文行（见文件头「与参考实现的差异」）
      if (trimmed.isEmpty) {
        out.add(line);
        continue;
      }
      inHeader = false;
      if (!injectedForBlock &&
          !trimmed.startsWith('//') &&
          !trimmed.startsWith('precision')) {
        needsHighp = _passNeedsHighpFrom(lines, i);
        final floatPrecision = needsHighp ? 'highp' : 'mediump';
        out.add('precision $floatPrecision float;');
        out.add('precision highp int;');
        injectedForBlock = true;
      }
    }

    if (injectedForBlock) {
      out.add(_rewriteLineWithExplicitPrecision(
        line,
        needsHighp ? 'highp' : 'mediump',
      ));
    } else {
      out.add(line);
    }
  }
  return out.join('\n');
}

/// 从 [bodyStart] 起扫到下一个 `//!` 头之前，判断该 pass 是否需 FP32。
bool _passNeedsHighpFrom(List<String> lines, int bodyStart) {
  for (var j = bodyStart; j < lines.length; j++) {
    if (lines[j].trim().startsWith('//!')) break;
    if (kAnime4kFp32Markers.any(lines[j].contains)) return true;
  }
  return false;
}

/// 给单行里的 float 类型变量声明显式加精度限定符。
///
/// 只改真正的变量声明：跳过空行/注释/预处理指令、已带限定符的行、函数签名
/// （`vec4 hook() {`、`float get_luma(vec4 rgba) {`）。
String _rewriteLineWithExplicitPrecision(String line, String precision) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('//') || trimmed.startsWith('#')) {
    return line;
  }
  if (trimmed.startsWith('mediump ') ||
      trimmed.startsWith('highp ') ||
      trimmed.startsWith('lowp ')) {
    return line;
  }

  final leading = line.length - line.trimLeft().length;
  final indent = line.substring(0, leading);

  for (final type in _floatTypes) {
    if (!trimmed.startsWith('$type ') && !trimmed.startsWith('$type(')) {
      continue;
    }
    final afterType = trimmed.substring(type.length).trimLeft();
    final parenIndex = afterType.indexOf('(');
    // 函数定义：`类型 标识符(...)`（`(` 之前没有 `=`，且不是构造调用）
    final isFunctionDef = parenIndex > 0 &&
        !afterType.substring(0, parenIndex).contains('=') &&
        afterType[0] != '(';
    if (isFunctionDef) return line;
    return '$indent$precision $trimmed';
  }
  return line;
}

/// 对每个 pass 做 C.R.E.L.U. 纹理采样合并。
String _optimizeCreluPasses(String content) =>
    splitAnime4kPasses(content).map(_optimizeSinglePass).join();

/// C.R.E.L.U. 卷积 pass：把 `go_0/go_1` 宏的 9 次重复采样合并成 3×3 预取。
///
/// 只在同一 pass 同时存在 `go_0`（`max(tex)`）与 `go_1`（`max(-tex)`）宏、
/// 且两者引用**同一个**纹理时才改写；否则原样返回（对齐 mpvRx）。
String _optimizeSinglePass(String pass) {
  final go0 = RegExp(
    r'#define\s+go_0\([^\)]+\)\s+\(max\(\(?\s*([A-Za-z0-9_]+)_texOff\(vec2\([^\)]+\)\)\)?\s*,\s*0\.0\)\)',
  ).firstMatch(pass);
  final go1 = RegExp(
    r'#define\s+go_1\([^\)]+\)\s+\(max\(-\(?\s*([A-Za-z0-9_]+)_texOff\(vec2\([^\)]+\)\)\)?\s*,\s*0\.0\)\)',
  ).firstMatch(pass);
  if (go0 == null || go1 == null) return pass;

  final texName = go0.group(1)!;
  if (texName != go1.group(1)) return pass;

  var optimized = pass
      .replaceAll(go0.group(0)!, '// optimized go_0 macro')
      .replaceAll(go1.group(0)!, '// optimized go_1 macro');

  final hookStart = RegExp(r'vec4\s+hook\(\s*\)\s*\{');
  final declarations = <String>[
    'vec4 hook() {',
    '    vec4 t_m1_m1 = ${texName}_texOff(vec2(-1.0, -1.0));',
    '    vec4 t_m1_0  = ${texName}_texOff(vec2(-1.0, 0.0));',
    '    vec4 t_m1_1  = ${texName}_texOff(vec2(-1.0, 1.0));',
    '    vec4 t_0_m1  = ${texName}_texOff(vec2(0.0, -1.0));',
    '    vec4 t_0_0   = ${texName}_texOff(vec2(0.0, 0.0));',
    '    vec4 t_0_1   = ${texName}_texOff(vec2(0.0, 1.0));',
    '    vec4 t_1_m1  = ${texName}_texOff(vec2(1.0, -1.0));',
    '    vec4 t_1_0   = ${texName}_texOff(vec2(1.0, 0.0));',
    '    vec4 t_1_1   = ${texName}_texOff(vec2(1.0, 1.0));',
  ].join('\n');
  optimized = optimized.replaceFirst(hookStart, declarations);

  optimized = optimized.replaceAllMapped(
    RegExp(r'go_0\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
    (m) => 'max(t_${_mapCoord(m.group(1)!)}_${_mapCoord(m.group(2)!)}, 0.0)',
  );
  optimized = optimized.replaceAllMapped(
    RegExp(r'go_1\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
    (m) => 'max(-t_${_mapCoord(m.group(1)!)}_${_mapCoord(m.group(2)!)}, 0.0)',
  );

  // 防御：偏移超出 {-1,0,1}（未来出现更大卷积核）会引用未声明的 t_unknown_*，
  // 导致整个着色器编译失败被 mpv 丢弃——此时退回原始 pass，绝不赌内核是 3×3。
  if (optimized.contains('_unknown')) return pass;
  return optimized;
}

/// 采样偏移 → 预取变量名片段。
String _mapCoord(String c) => switch (c.trim()) {
      '-1.0' || '-1' => 'm1',
      '0.0' || '0' => '0',
      '1.0' || '1' => '1',
      _ => 'unknown',
    };
