import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/l10n/legal.dart';

/// 长文（隐私政策 / 用户服务协议）按语言拆文件后的兜底测试。
///
/// 目的：将来新增语言（或重构正文文件）时，**漏写某一段会立刻红**，
/// 而不是等到用户在弹窗/协议页看到空白才发现。
void main() {
  final cjk = RegExp(r'[\u4e00-\u9fff]');

  group('legalTextsFor', () {
    for (final code in const ['zh', 'en']) {
      test('$code：四段都非空', () {
        final texts = legalTextsFor(Locale(code));
        expect(texts.policyTitle.trim(), isNotEmpty);
        expect(texts.policyBody.trim(), isNotEmpty);
        expect(texts.agreementTitle.trim(), isNotEmpty);
        expect(texts.agreementBody.trim(), isNotEmpty);
      });
    }

    test('en：正文里没有残留汉字（防止漏译/漏文件）', () {
      final texts = legalTextsFor(const Locale('en'));
      expect(cjk.hasMatch(texts.policyTitle), isFalse);
      expect(cjk.hasMatch(texts.policyBody), isFalse);
      expect(cjk.hasMatch(texts.agreementTitle), isFalse);
      expect(cjk.hasMatch(texts.agreementBody), isFalse);
    });

    test('zh：正文是中文原样（含「小喵Player」应用名）', () {
      final texts = legalTextsFor(const Locale('zh'));
      expect(texts.policyTitle, '用户隐私政策');
      expect(texts.agreementTitle, '用户服务协议与隐私政策');
      expect(texts.policyBody, contains('小喵Player'));
      expect(texts.agreementBody, contains('小喵Player'));
      // 正文是长文（不是占位串）：给个下限，防止误接成短文案
      expect(texts.policyBody.length, greaterThan(1000));
      expect(texts.agreementBody.length, greaterThan(1000));
    });

    test('en：应用名用 Meow Player', () {
      final texts = legalTextsFor(const Locale('en'));
      expect(texts.policyBody, contains('Meow Player'));
      expect(texts.agreementBody, contains('Meow Player'));
    });

    test('未知语言回落中文（与 preferred-supported-locales: [zh] 一致）', () {
      final texts = legalTextsFor(const Locale('ja'));
      expect(texts.policyTitle, '用户隐私政策');
    });
  });
}
