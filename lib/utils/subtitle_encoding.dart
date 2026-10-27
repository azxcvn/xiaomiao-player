/// 外挂字幕文本编码：识别 + 转 UTF-8（纯函数，可单测）。
///
/// 为什么需要：外挂字幕是把**原始文件路径**直接交给 mpv `sub-add`，mpv 按
/// UTF-8（或 BOM）解码——GBK / GB18030 的老中文字幕在画面上就是乱码。
/// 这里在交给 mpv 之前判断一次：解不成 UTF-8 的按 GBK 解（GBK 是 GB18030 的
/// 子集，覆盖绝大多数中文老字幕），由调用方落成一份 UTF-8 副本再 `sub-add`。
///
/// **只处理文本字幕**：`sub` / `idx` / `sup` 是位图字幕，硬转会毁掉原本能
/// 正常显示的字幕，所以扩展名白名单里刻意不含它们。
library;

import 'dart:convert';

import 'package:charset/charset.dart';

/// 可安全做「文本 → UTF-8」转换的字幕扩展名（位图字幕不在此列）
const Set<String> kTextSubtitleExtensions = {
  'srt',
  'ass',
  'ssa',
  'vtt',
  'lrc',
  'sbv',
  'smi',
  'pjs',
  'psb',
  'rt',
  'aqt',
  'mpl2',
  'txt',
};

/// 文件名是否为文本字幕（大小写不敏感；没有扩展名的不算）
bool isTextSubtitleFile(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return false;
  return kTextSubtitleExtensions.contains(
    filename.substring(dot + 1).toLowerCase(),
  );
}

/// UTF-8 能否严格解通（不允许任何非法字节序列）
bool isValidUtf8(List<int> bytes) {
  try {
    utf8.decode(bytes);
    return true;
  } catch (_) {
    return false;
  }
}

/// 是否带 UTF-16 / UTF-32 BOM。
///
/// 这类文件 mpv 自己认 BOM，也能正常显示——不要去转（转了反而多一层风险）。
/// UTF-32LE 的 BOM 以 `FF FE` 开头，被 UTF-16LE 的判断顺带覆盖；UTF-32BE
/// 的 `00 00 FE FF` 需要单独判。
bool hasUtf16OrUtf32Bom(List<int> bytes) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    return true;
  }
  return bytes.length >= 4 &&
      bytes[0] == 0x00 &&
      bytes[1] == 0x00 &&
      bytes[2] == 0xFE &&
      bytes[3] == 0xFF;
}

/// GBK 解码允许的最大替换字符占比：超过就不当成中文文本（多半是二进制或
/// 别的编码），宁可不动也别把本来能认的文件改成乱码。
const double _maxReplacementRatio = 0.05;

/// 需要转码时返回 UTF-8 文本；不需要 / 不该转时返回 null。
///
/// 返回 null 的几种情况（调用方一律继续用原文件）：
/// - 不是文本字幕扩展名（位图字幕）；
/// - 本来就是合法 UTF-8；
/// - 带 UTF-16 / UTF-32 BOM（mpv 自己认）；
/// - 含 NUL 字节（二进制，转码只会更糟）；
/// - 按 GBK 解出来替换字符太多（不像中文文本）。
String? transcodeSubtitleToUtf8(String filename, List<int> bytes) {
  if (bytes.isEmpty || !isTextSubtitleFile(filename)) return null;
  if (hasUtf16OrUtf32Bom(bytes)) return null;
  if (isValidUtf8(bytes)) return null;
  if (bytes.contains(0)) return null;

  final text = const GbkCodec(allowMalformed: true).decode(bytes);
  if (text.contains('\u0000')) return null;
  final replacements = _countReplacementChars(text);
  if (replacements > 0 && replacements / text.length > _maxReplacementRatio) {
    return null;
  }
  return text;
}

int _countReplacementChars(String text) {
  var count = 0;
  for (final unit in text.codeUnits) {
    if (unit == 0xFFFD) count++;
  }
  return count;
}
