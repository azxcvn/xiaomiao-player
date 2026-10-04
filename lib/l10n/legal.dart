/// 隐私政策 / 用户协议长文正文的**按语言入口**。
///
/// 正文按语言拆成 `legal_zh.dart` / `legal_en.dart` 两个 Dart 文件（不塞 ARB，
/// 见 `02-实施方案.md` §1.11）；本文件只做「当前语言 → 正文」的分发。
///
/// ⚠️ 改中文条款必须同步改英文（两个文件头部都写了这条纪律）；
/// `test/legal_texts_test.dart` 断言每种支持语言的 4 段都非空。
library;

import 'dart:ui' show Locale;

import 'package:moumou/l10n/legal_en.dart';
import 'package:moumou/l10n/legal_zh.dart';

/// 长文正文（按当前 [locale] 取；未知语言回落中文，与
/// `l10n.yaml` 的 `preferred-supported-locales: [zh]` 一致）
({
  String policyTitle,
  String policyBody,
  String agreementTitle,
  String agreementBody,
}) legalTextsFor(Locale locale) =>
    locale.languageCode == 'en' ? legalEn : legalZh;
