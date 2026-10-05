# 06 · 阶段 4：代码接入与生成物

> 只改 **3 个 lib 文件**，然后重新生成 l10n。这一阶段之后，繁体就能真的在 App 里选出来了。

---

## 1. 目标与产出

| 项 | 内容 |
|---|---|
| 目标 | `app_locale` 支持第三个值 `zh_Hant`，语言入口与设置页副标题认得它 |
| 产出 | ① `lib/services/app_locale_settings.dart` ② `lib/widgets/language_picker_dialog.dart` ③ `lib/pages/settings/settings_page.dart` ④ 重新生成的 `lib/l10n/app_localizations.dart` / `app_localizations_zh.dart` |
| 前置 | 阶段 2 的 `app_zh_Hant.arb` + `languageNameZhHant` 已就位；阶段 3 的 `legal.dart` 已改 |
| 门禁 | **G1**：`flutter analyze` → `No issues found!` |
| 预计耗时 | 半天 |

**`l10n.yaml` 不改**（`preferred-supported-locales: [zh]` 正好继续保证"不支持的语言回落简体"）。

---

## 2. 步骤 1：`lib/services/app_locale_settings.dart`

现状（改前）：第 10-13 行的类注释、第 28-33 行的语言取值、第 39 行的 `locale` getter、第 48-60 行的 `setLocale` / `_normalize`，全都写着"只允许 `'zh'` / `'en'`"。

### 2.1 语言取值加第三个

```dart
  /// 支持的语言取值（语言选项用自称且不翻译：简体中文 / 繁體中文 / English）
  static const String zhCode = 'zh';
  static const String zhHantCode = 'zh_Hant';
  static const String enCode = 'en';

  /// 当前语言取值（`'zh'` / `'zh_Hant'` / `'en'`）
  String _value = zhCode;
```

### 2.2 `locale` getter（**本轮最关键的一处**）

```dart
  /// 当前语言对应的 Locale（**永远非空**，默认简体中文，无「跟随系统」）
  ///
  /// 繁体必须走 `Locale.fromSubtags`：`Locale('zh_Hant')` 会把 `zh_Hant`
  /// 整个塞进 languageCode，既匹配不上 `supportedLocales` 里的
  /// `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`，也匹配不上
  /// `Locale('zh')`，最终**静默回落简体**（界面看着像"繁体没生效"，但不报错）。
  Locale get locale => _value == zhHantCode
      ? Locale.fromSubtags(languageCode: zhCode, scriptCode: 'Hant')
      : Locale(_value);
```

### 2.3 `_normalize` 变三值

```dart
  /// 缺省 / 空值 / 非法值一律回落简体中文
  static String _normalize(String? value) {
    if (value == zhHantCode) return zhHantCode;
    if (value == enCode) return enCode;
    return zhCode;
  }
```

### 2.4 注释同步

把类头注释、`setLocale` 注释里"只允许 `'zh'` / `'en'`"这类描述改成三值。**注释不改 = 下一轮维护者按错注释写代码**。

`setLocale` / `load` / `resetForTest` 的逻辑**不用改**（都走 `_normalize`）。

---

## 3. 步骤 2：`lib/widgets/language_picker_dialog.dart`

现状：第 8-14 行的文件注释写"选项只有 简体中文 / English 两项"；第 41-45 行构造 `options`。

```dart
    final l10n = AppLocalizations.of(context);
    // 语言名用「自称」：三个选项在任何语言下都显示各自母语写法
    final options = <(String, String)>[
      (AppLocaleSettings.zhCode, l10n.languageNameZh),
      (AppLocaleSettings.zhHantCode, l10n.languageNameZhHant),
      (AppLocaleSettings.enCode, l10n.languageNameEn),
    ];
```

顺序固定为「简体中文 / 繁體中文 / English」（简繁相邻，英文最后），并同步更新文件头注释。

**其余逻辑不许动**：仍是"选择"不是"门禁"、允许关闭、关闭 = 保持当前语言、默认选中当前语言。

---

## 4. 步骤 3：`lib/pages/settings/settings_page.dart`

现状（第 171-186 行）副标题是二选一：

```dart
                  subtitle: Text(
                    AppLocaleSettings.instance.rawValue ==
                            AppLocaleSettings.enCode
                        ? l10n.languageNameEn
                        : l10n.languageNameZh,
                  ),
```

改成调用一个私有辅助函数（放在本文件底部或 `SettingsPage` 类附近，与文件现有风格一致）：

```dart
                  // 副标题显示**当前语言**：语言名用自称，不翻译
                  subtitle: Text(_languageNameOf(l10n)),
```

```dart
/// 当前语言的**自称**（不翻译）：简体中文 / 繁體中文 / English
String _languageNameOf(AppLocalizations l10n) =>
    switch (AppLocaleSettings.instance.rawValue) {
      AppLocaleSettings.enCode => l10n.languageNameEn,
      AppLocaleSettings.zhHantCode => l10n.languageNameZhHant,
      _ => l10n.languageNameZh,
    };
```

> 用 `switch` 表达式（本仓库 `lib/l10n/label_maps.dart` 就是这个风格），字符串 switch 必须带默认分支 `_`。样式跟随所在文件；如果该文件通篇不用 switch 表达式，用等价的 `if/else` 也行，**但同一文件内风格要统一**。

**「语言」组的位置不许动**（在「弹幕」组下方、「下载」组上方，第一轮已拍板并有测试守着）。

---

## 5. 步骤 4：重新生成 l10n

```powershell
D:\allexe\flutter\bin\flutter.bat gen-l10n
```

- 这是**代码生成**，不是 `flutter build`，允许执行。
- 如果报找不到 package config，先跑一次 `D:\allexe\flutter\bin\flutter.bat pub get`（也只允许这一条）。
- 生成物**入库**，与第一轮一致。

**预期生成结果**（与 `02-技术方案.md` §2 的源码依据对应；**2026-10-05 已按实测修正**）：

| 文件 | 预期变化（实测） |
|---|---|
| `lib/l10n/app_localizations.dart` | `supportedLocales` 增加 `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`（三项，首项仍是 `Locale('zh')`）；`lookupAppLocalizations` 增加**嵌套分支**：`case 'zh':` → 内层 `switch (locale.scriptCode)` → `case 'Hant': return AppLocalizationsZhHant();`（**不是** `case 'zh_Hant'`）；`isSupported` 仍是 `['en','zh'].contains(...)`（不含 `zh_Hant`）。实测 7848 行 |
| `lib/l10n/app_localizations_zh.dart` | **文件末尾新增** `class AppLocalizationsZhHant extends AppLocalizationsZh`（只覆盖 Hant ARB 里有的键）；实测 4462 → **8925 行** |
| `lib/l10n/app_localizations_en.dart` | 只多一个 `languageNameZhHant` getter；实测 4686 → **4689 行** |
| `lib/l10n/app_localizations_zh_Hant.dart` | **不应存在**（同语言子类不单独成文件） |
| `l10n_untranslated.json` | 重写为实际缺键清单（阶段 2 做全了就是 `{}`）；实测 `{}` |

**核对方式**：跑 `py "杂项文件\繁体中文接入方案\tools\_stage4_check.py"`，上面每条都做成断言，输出 `STAGE4 PASS` 才算过。

**任一条与预期不符 → 停下来报告**（不要自己"适应"结果，因为后面阶段的门禁判断都建立在这张表上）。

---

## 6. 步骤 5：门禁

```powershell
D:\allexe\flutter\bin\flutter.bat analyze
```

期望 `No issues found!`。常见报错与对策：

| 报错 | 原因 | 对策 |
|---|---|---|
| `The getter 'languageNameZhHant' isn't defined` | 生成物没重新生成 / ARB 里没这个键 | 回到步骤 1（模板加键）→ 步骤 4 重新生成 |
| `Const variable zhHantCode is not a constant` 之类 | 常量定义位置/写法问题 | 按 §2.1 原样写 |
| switch 不穷尽 | 字符串 switch 少了默认分支 | 补 `_ =>` |

---

## 7. 常见坑

1. **不要手改生成物**：`lib/l10n/app_localizations*.dart` 一律由 `gen-l10n` 产出；手改会在下次生成时丢掉。
2. **不要顺手改 `main.dart`**：`locale:` / `supportedLocales:` 都从设置与 `AppLocalizations` 取，无需改动。
3. **不要把 `zh_Hant` 写成 `zh-Hant`**：ARB 文件名、`@@locale`、生成物、持久化值统一用**下划线**形式 `zh_Hant`（这是 `gen_l10n` 的文件名规范）。
4. **不要加「跟随系统」**（拍板结论 3）。
5. **不要在 `AppLocaleSettings` 里加"从系统语言推断"的逻辑**：本轮只要"用户手动选"。
6. **行尾（EOL）**：仓库工作区是 **CRLF**（`core.autocrlf=true`，无 `.gitattributes`）。
   用"整文件重写"的方式落盘（`write` 工具 / 脚本生成）会写出 **LF**，`git` 会警告
   `LF will be replaced by CRLF ...`，并与仓库其它文件不一致。
   **改完跑一次** `py "杂项文件\繁体中文接入方案\tools\_eol_fix.py"`（`--check` 只检查）。
   > 用编辑工具做**定向替换**不会破坏 CRLF（阶段 4 实测：`edit` 改过的文件仍是 CRLF）。

---

## 8. 完成标准

- [x] `app_locale_settings.dart` 三值 + `locale` getter 用 `Locale.fromSubtags`，注释已同步
- [x] `language_picker_dialog.dart` 三项（简繁相邻、英文最后），注释已同步
- [x] `settings_page.dart` 副标题三选一（新增文件级 `_languageNameOf(l10n)`，用 `switch` 表达式）
- [x] `gen-l10n` 已跑，生成结果与 §5 预期表逐条一致（`_stage4_check.py` → **STAGE4 PASS**）
- [x] G1 `analyze`：`No issues found!`
- [x] `l10n_untranslated.json` = `{}`（G4 提前达成）

---

## 9. 执行记录

| 日期 | 结果 |
|---|---|
| 2026-10-05 | **阶段 4 完成**。① `app_locale_settings.dart`：加 `zhHantCode`；`locale` getter 改 `Locale.fromSubtags(languageCode: zhCode, scriptCode: 'Hant')`（并在注释里写明写错会静默回落简体）；`_normalize` 改三值 if 链；类注释与 `setLocale` 注释同步为三值。② `language_picker_dialog.dart`：选项三项、头注释与标题注释同步。③ `settings_page.dart`：副标题二选一 → `Text(_languageNameOf(l10n))`，文件末尾新增 `_languageNameOf`（`switch` 表达式，默认分支回落简体）。④ `flutter gen-l10n` 重新生成：`app_localizations.dart` 7848 行、`app_localizations_zh.dart` 8925 行（含 `AppLocalizationsZhHant` 子类）、`app_localizations_en.dart` 4689 行、无 `app_localizations_zh_Hant.dart`、`l10n_untranslated.json` = `{}`。⑤ 新增核对工具 `tools/_stage4_check.py`（7 条断言）→ STAGE4 PASS。⑥ `flutter analyze` → No issues found! |
| 2026-10-05 | **预期的偏差（已修正文档）**：原方案预测 `lookupAppLocalizations` 会增加 `case 'zh_Hant'`，实测是**嵌套 switch**（`case 'zh':` → 内层 `switch (locale.scriptCode)` → `case 'Hant'`），且 `isSupported` 判的是不含 script 的 `['en','zh']`。**这不影响结论**（zh_Hant 能正确解析），但把这条实测形状回填进 `02-技术方案.md` §2 与本文 §5，并写进核对脚本的断言。 |
| 2026-10-05 | **G2 全量测试**（仓库规则要求改 Dart 就跑）：`flutter test` → **All tests passed!（+1834 ~13）**，与基线完全一致，未新增失败。 |
| 2026-10-05 | **EOL 修正**：`write` 全量重写的 4 个文件（`legal.dart`、`app_locale_settings.dart`、`legal_zh_hant.dart`、`app_zh_Hant.arb`）落盘为 LF，与仓库 CRLF 约定不符（`git` 警告 2 处）。新增 `tools/_eol_fix.py` 做字节级归一，4 个文件已修为 CRLF，警告消失；`--check` 复查 PASS。归一后重跑 G3/G4/长文核对/`analyze` 全部仍 PASS。 |
