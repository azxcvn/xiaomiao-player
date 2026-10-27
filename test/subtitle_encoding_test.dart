import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/subtitle_encoding.dart';

/// 外挂字幕编码识别 / 转码规则：GBK / GB18030 老中文字幕转 UTF-8，
/// 本来正常的 UTF-8 / UTF-16（带 BOM）与位图字幕一律不动。
void main() {
  const sample = '1\n00:00:01,000 --> 00:00:04,000\n这是 GBK 编码的中文字幕\n';

  test('UTF-8 字幕：不需要转（返回 null）', () {
    expect(transcodeSubtitleToUtf8('a.srt', utf8.encode(sample)), isNull);
    expect(isValidUtf8(utf8.encode(sample)), isTrue);
  });

  test('GBK 字幕：解出正确的中文并转成 UTF-8', () {
    final gbkBytes = const GbkCodec().encode(sample);
    expect(isValidUtf8(gbkBytes), isFalse, reason: '样本本身要确实不是 UTF-8');

    final text = transcodeSubtitleToUtf8('a.srt', gbkBytes);
    expect(text, sample);
    expect(isValidUtf8(utf8.encode(text!)), isTrue);
  });

  test('ASS / VTT / TXT 等文本字幕同样处理', () {
    const ass = '[Script Info]\nTitle: 简体测试\n';
    expect(transcodeSubtitleToUtf8('a.ass', const GbkCodec().encode(ass)), ass);
    expect(transcodeSubtitleToUtf8('a.vtt', const GbkCodec().encode(ass)), ass);
    expect(transcodeSubtitleToUtf8('a.txt', const GbkCodec().encode(ass)), ass);
  });

  test('带 UTF-16 / UTF-32 BOM 的不动（mpv 自己认 BOM）', () {
    expect(
      transcodeSubtitleToUtf8('a.srt', [0xFF, 0xFE, 0x2D, 0x4E]),
      isNull,
      reason: 'UTF-16LE',
    );
    expect(
      transcodeSubtitleToUtf8('a.srt', [0xFE, 0xFF, 0x4E, 0x2D]),
      isNull,
      reason: 'UTF-16BE',
    );
    expect(
      transcodeSubtitleToUtf8('a.srt', [0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00]),
      isNull,
      reason: 'UTF-32BE',
    );
    expect(hasUtf16OrUtf32Bom([0x41, 0x42]), isFalse);
  });

  test('位图字幕（sub / idx / sup）不处理，避免转坏', () {
    final bytes = const GbkCodec().encode('看起来像中文的字节');
    expect(transcodeSubtitleToUtf8('a.sup', bytes), isNull);
    expect(transcodeSubtitleToUtf8('a.idx', bytes), isNull);
    expect(transcodeSubtitleToUtf8('a.sub', bytes), isNull);
    expect(transcodeSubtitleToUtf8('a.dvd', bytes), isNull);
  });

  test('含 NUL 的二进制：不动', () {
    expect(transcodeSubtitleToUtf8('a.srt', [0x41, 0x00, 0xFF]), isNull);
  });

  test('GBK 也解不通（替换字符过多）：不动', () {
    // 0xFF 不是合法 GBK 首字节，连续 64 个 → 全是替换字符
    expect(transcodeSubtitleToUtf8('a.srt', List<int>.filled(64, 0xFF)), isNull);
  });

  test('文本字幕扩展名判断：大小写不敏感、无扩展名不算', () {
    expect(isTextSubtitleFile('a.SRT'), isTrue);
    expect(isTextSubtitleFile('a.Ass'), isTrue);
    expect(isTextSubtitleFile('a.sup'), isFalse);
    expect(isTextSubtitleFile('noext'), isFalse);
    expect(isTextSubtitleFile('a.'), isFalse);
  });
}
