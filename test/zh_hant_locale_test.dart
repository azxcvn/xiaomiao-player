import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/app_locale_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 繁体（`zh_Hant`）语言入口与生成物对齐（繁体轮阶段 6）。
///
/// 守三类事：
/// 1. `app_locale` 三值（`'zh'` / `'zh_Hant'` / `'en'`），其余一律回落简体；
/// 2. 繁体 Locale **必须**与生成物 `supportedLocales` 里的写法一致
///    （`Locale.fromSubtags`），写成 `Locale('zh_Hant')` 会静默回落简体；
/// 3. ARB 三边（简/繁/英）**键集合与占位符对称** —— 永久防线：以后谁给模板加键
///    忘了加繁体，这里立刻红（比 `l10n_untranslated.json` 更早发现）。
void main() {
  final settings = AppLocaleSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings.resetForTest();
  });

  group('app_locale 取值', () {
    test('zh_Hant：写入、Locale 对象、持久化都正确', () async {
      await settings.setLocale(AppLocaleSettings.zhHantCode);

      expect(settings.rawValue, 'zh_Hant');
      expect(settings.locale, kTestLocaleZhHant);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'zh_Hant');
    });

    test('非法值一律回落简体（含写错形式 zh-Hant / zh_TW）', () async {
      for (final bad in const [
        'zh-Hant',
        'zh_TW',
        'zh-Hant-TW',
        'hant',
        'fr',
        '',
      ]) {
        await settings.setLocale(bad);
        expect(settings.rawValue, 'zh', reason: 'bad value: "$bad"');
        expect(settings.locale, kTestLocaleZh, reason: 'bad value: "$bad"');
      }
    });

    test('Locale.fromSubtags 与 Locale(zh_Hant) 不是同一个东西（守 06 文档里的坑）', () {
      expect(kTestLocaleZhHant, isNot(const Locale('zh_Hant')));
      expect(kTestLocaleZhHant.languageCode, 'zh');
      expect(kTestLocaleZhHant.scriptCode, 'Hant');
      // 写错的那种：`zh_Hant` 被整个塞进 languageCode，scriptCode 是 **null**（不是空串）
      expect(const Locale('zh_Hant').languageCode, 'zh_Hant');
      expect(const Locale('zh_Hant').scriptCode, isNull);
    });
  });

  group('生成物对齐', () {
    test('supportedLocales 含繁体项，且首项仍是简体（回落行为不变）', () {
      expect(
        AppLocalizations.supportedLocales.contains(kTestLocaleZhHant),
        isTrue,
      );
      expect(AppLocalizations.supportedLocales.first, kTestLocaleZh);
    });

    test('语言窗标题随界面语言（**不做中英共存**）', () {
      expect(lookupAppLocalizations(kTestLocaleZh).languagePickerTitle, '选择语言');
      expect(
        lookupAppLocalizations(kTestLocaleZhHant).languagePickerTitle,
        '選擇語言',
      );
      expect(
        lookupAppLocalizations(const Locale('en')).languagePickerTitle,
        'Choose Language',
      );
    });

    test('繁体下语言名用「自称」：简体中文 / 繁體中文 / English', () {
      final hant = lookupAppLocalizations(kTestLocaleZhHant);

      expect(hant.languageNameZhHant, '繁體中文');
      expect(hant.languageNameZh, '简体中文');
      expect(hant.languageNameEn, 'English');
      // 语言自称不随界面语言变；应用名与简体一致
      expect(hant.languagePickerTitle, '選擇語言');
      expect(hant.appTitle, '小喵Player');
    });
  });

  group('ARB 对称（三边键集合与占位符）', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;

    Set<String> keys(Map<String, dynamic> data) =>
        data.keys.where((k) => !k.startsWith('@')).toSet();

    Set<String> placeholders(String text) => {
          ...RegExp(r'\{(\w+)\s*[,}]').allMatches(text).map((m) => m.group(1)!),
          ...RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!),
        };

    test('简 / 繁 / 英 三边键集合一致', () {
      final zh = keys(arb('app_zh.arb'));
      final en = keys(arb('app_en.arb'));
      final hant = keys(arb('app_zh_Hant.arb'));

      expect(zh.length, greaterThan(1000));
      expect(en, zh);
      expect(hant, zh);
    });

    test('逐键占位符一致（繁体与英文都不得漏/改占位符）', () {
      final zh = arb('app_zh.arb');
      final en = arb('app_en.arb');
      final hant = arb('app_zh_Hant.arb');

      for (final key in keys(zh)) {
        final source = zh[key] as String;
        expect(
          placeholders(hant[key] as String),
          placeholders(source),
          reason: 'zh_Hant 占位符不一致: $key',
        );
        expect(
          placeholders(en[key] as String),
          placeholders(source),
          reason: 'en 占位符不一致: $key',
        );
      }
    });

    test('繁体 ARB：@@locale 正确，且不写 @ 元数据', () {
      final hant = arb('app_zh_Hant.arb');

      expect(hant['@@locale'], 'zh_Hant');
      expect(
        hant.keys.where((k) => k.startsWith('@') && k != '@@locale'),
        isEmpty,
      );
    });
  });
}
