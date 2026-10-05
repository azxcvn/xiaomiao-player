/// 隐私政策 / 用户协议长文正文的**按语言入口**。
///
/// 正文按语言拆成 `legal_zh.dart`（简中源文）/ `legal_zh_hant.dart`（繁中译文）/
/// `legal_en.dart`（英文译文）三个 Dart 文件（不塞 ARB，见 `02-实施方案.md` §1.11）；
/// 本文件只做「当前语言 → 正文」的分发。
///
/// ⚠️ 改中文条款必须同步改另外两个（三个文件头部都写了这条纪律）；
/// `test/legal_texts_test.dart` 断言每种支持语言的 4 段都非空。
library;

import 'dart:ui' show Locale;

import 'package:moumou/l10n/legal_en.dart';
import 'package:moumou/l10n/legal_zh.dart';
import 'package:moumou/l10n/legal_zh_hant.dart';

/// 是否繁体：`zh_Hant` 与简体**同为语言码 `zh`**，只能靠 script 区分。
///
/// 同时兼容两种写法：正确的 `Locale.fromSubtags(zh, Hant)`（`scriptCode == 'Hant'`）
/// 与写错的 `Locale('zh_Hant')`（语言码里含 `hant`、script 为空）——后者若判不出来，
/// 长文会静默退回简体（与 l10n 侧同一个坑，见 `06-阶段4-代码接入与生成物.md`）。
bool _isHant(Locale locale) {
  final script = locale.scriptCode?.toLowerCase() ?? '';
  return script == 'hant' || locale.languageCode.toLowerCase().contains('hant');
}

/// 长文正文（按当前 [locale] 取；未知语言回落中文，与
/// `l10n.yaml` 的 `preferred-supported-locales: [zh]` 一致）
({
  String policyTitle,
  String policyBody,
  String agreementTitle,
  String agreementBody,
}) legalTextsFor(Locale locale) => locale.languageCode == 'en'
    ? legalEn
    : (_isHant(locale) ? legalZhHant : legalZh);
