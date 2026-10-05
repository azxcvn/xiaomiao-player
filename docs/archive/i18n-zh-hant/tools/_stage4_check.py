# -*- coding: utf-8 -*-
"""阶段 4 生成物核对：`flutter gen-l10n` 之后，生成物必须与方案预期一致。

用法（工作目录 = 工程根 C:\\Users\\root\\Desktop\\moumou）：

    py "docs\\archive\\i18n-zh-hant\\tools\\_stage4_check.py"

预期（见 `06-stage4-code-integration.md` §5，**2026-10-05 按实测形状修正**）：
1. `app_localizations.dart` 的 `supportedLocales` 里出现
   `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`，且首项仍是 `Locale('zh')`；
2. 同文件的 `lookupAppLocalizations` 生成**嵌套 switch**：先 `switch (locale.languageCode)`
   的 `case 'zh':`，内层 `switch (locale.scriptCode)` 的 `case 'Hant':` → 返回
   `AppLocalizationsZhHant()`（**不是** `case 'zh_Hant'`）；
3. `isSupported` 的语言集合是 `['en', 'zh']`（**不含 `zh_Hant`**）——这正是
   `Locale('zh_Hant')` 写法会静默回落简体的原因；
4. `app_localizations_zh.dart` 里出现 `class AppLocalizationsZhHant extends AppLocalizationsZh`；
5. **不出现** `app_localizations_zh_Hant.dart`（同语言子类不单独成文件）；
6. `app_localizations_en.dart` 里出现 `languageNameZhHant`；
7. `l10n_untranslated.json` == `{}`。
只读生成物，不写源码。
"""

import io
import json
import os
import re
import sys

# 归档位置：<repo>/docs/archive/i18n-zh-hant/tools → 上溯 5 层回到仓库根
ROOT = os.path.dirname(
    os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )
)
L10N = os.path.join(ROOT, "lib", "l10n")


def read(path):
    return io.open(path, encoding="utf-8").read()


def main():
    errors = []
    notes = []

    files = sorted(f for f in os.listdir(L10N) if f.startswith("app_localizations"))
    notes.append("generated files: " + ", ".join(files))

    main_dart = os.path.join(L10N, "app_localizations.dart")
    zh_dart = os.path.join(L10N, "app_localizations_zh.dart")
    en_dart = os.path.join(L10N, "app_localizations_en.dart")
    hant_dart = os.path.join(L10N, "app_localizations_zh_Hant.dart")

    main_text = read(main_dart)
    zh_text = read(zh_dart)
    en_text = read(en_dart)

    m = re.search(r"static const List<Locale> supportedLocales = <Locale>\[(.*?)\];", main_text, re.S)
    if not m:
        errors.append("supportedLocales not found in app_localizations.dart")
        entries = []
    else:
        entries = [x.strip() for x in m.group(1).split(",") if x.strip()]
    notes.append("supportedLocales: " + " | ".join(entries))

    if entries and entries[0] != "Locale('zh')":
        errors.append("first supported locale is not Locale('zh') (fallback must stay Simplified): " + entries[0])
    if not any("scriptCode: 'Hant'" in e for e in entries):
        errors.append("supportedLocales has no Locale.fromSubtags(..., scriptCode: 'Hant') entry")

    if re.search(r"case 'zh':\s*\{\s*switch \(locale\.scriptCode\)\s*\{\s*case 'Hant':\s*return AppLocalizationsZhHant\(\);", main_text) is None:
        if "case 'Hant':" not in main_text or "AppLocalizationsZhHant()" not in main_text:
            errors.append(
                "app_localizations.dart lookup has no nested 'zh' -> scriptCode 'Hant' -> AppLocalizationsZhHant() branch"
            )
    if re.search(r"<String>\['en', 'zh'\]\.contains\(locale\.languageCode\)", main_text) is None:
        errors.append("isSupported no longer checks against ['en', 'zh'] (script-less) — verify fallback behavior")

    if "class AppLocalizationsZhHant extends AppLocalizationsZh" not in zh_text:
        errors.append("app_localizations_zh.dart has no 'class AppLocalizationsZhHant extends AppLocalizationsZh'")
    notes.append("app_localizations_zh.dart lines: %d" % len(zh_text.splitlines()))
    notes.append("app_localizations_en.dart lines: %d" % len(en_text.splitlines()))

    if os.path.exists(hant_dart):
        errors.append("app_localizations_zh_Hant.dart must NOT exist (same-language subclass shares zh file)")

    if "languageNameZhHant" not in en_text:
        errors.append("app_localizations_en.dart has no languageNameZhHant")

    zh_hant_arb = os.path.join(L10N, "app_zh_Hant.arb")
    if "languageNameZhHant" not in read(zh_hant_arb):
        errors.append("app_zh_Hant.arb has no languageNameZhHant")

    untranslated_path = os.path.join(ROOT, "l10n_untranslated.json")
    try:
        untranslated = json.loads(read(untranslated_path))
    except Exception as e:  # noqa: BLE001
        errors.append("l10n_untranslated.json unreadable: %s" % e)
        untranslated = {"<unreadable>": True}
    notes.append("l10n_untranslated.json entries: %d" % len(untranslated))
    if untranslated:
        errors.append("l10n_untranslated.json is not empty: %s" % list(untranslated)[:5])

    print("STAGE4 " + ("FAIL" if errors else "PASS"))
    for n in notes:
        print("  " + n)
    for e in errors:
        print("  - " + e)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
