# 02 · 技术方案

> 只讲"怎么接、为什么会这样、哪里会踩坑"。逐阶段的动手步骤在各阶段 md 里。

---

## 1. locale 设计（三条铁律）

| 项 | 值 | 说明 |
|---|---|---|
| ARB 文件 | `lib/l10n/app_zh_Hant.arb` | 文件名必须是 `app_<language>_<Script>.arb` 形式，script 是 4 个字符、首字母大写 |
| ARB 里的 locale | `"@@locale": "zh_Hant"` | **必须与文件名一致**，否则 `flutter gen-l10n` 直接抛 `L10nException` |
| 持久化值（`app_locale`） | `'zh_Hant'` | 沿用现有 ASCII 风格（`'zh'` / `'en'`），无空格无连字符 |
| 运行时 Locale 对象 | `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')` | **只能用这个写法** |

### 1.1 为什么不能用 `Locale('zh_Hant')`

`Locale('zh_Hant')` 会把 `zh_Hant` 整个塞进 **languageCode**（`scriptCode` 与 `countryCode` 都是 **`null`**，不是空串——阶段 6 写测试时实测确认）。后果：

1. `MaterialApp.locale` 的显式值**同样要走** `basicLocaleListResolution(supportedLocales)`，不是"直接用它"；
2. `supportedLocales` 里那一项是 `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`，与 `Locale('zh_Hant')` **不相等**；
3. 语言码 `zh_hant` 也匹配不上 `zh` 那一项；
4. 于是回落规则生效 → 取 `supportedLocales` **首项 = `Locale('zh')` = 简体**。

**结果：界面看起来"繁体没生效"，但不报任何错**。这是本轮最容易踩、最难查的坑。

`AppLocaleSettings.locale` 的正确写法（阶段 4 会改）：

```dart
/// 当前语言对应的 Locale（**永远非空**，默认简体中文，无「跟随系统」）
Locale get locale => _value == zhHantCode
    ? Locale.fromSubtags(languageCode: zhCode, scriptCode: 'Hant')
    : Locale(_value);
```

---

## 2. `gen_l10n` 的实际行为（依据 Flutter SDK 源码）

SDK 路径：`D:\allexe\flutter\packages\flutter_tools\lib\src\localizations\`（Flutter 3.44.9）。
下面每条都标了源码位置，执行者可以自己核对；**如果实际生成结果与此不符 → 停下来报告**。

| # | 行为 | 依据 |
|---|---|---|
| 1 | `@@locale` 存在时与文件名比对，不一致抛异常；不存在则用文件名 | `gen_l10n_types.dart:636-683` |
| 2 | 文件名按 `language_script_COUNTRY` 解析，script 的判据是"这段有 4 个字符" | `localizations_utils.dart:42-56` |
| 3 | 解析**不启用** `deriveScriptCode` → `app_zh.arb` 仍然是 `Locale('zh')`，不会变成 `zh_Hans` | 调用点 `gen_l10n_types.dart:689` 未传该参数（启用逻辑在 `localizations_utils.dart:67-86`） |
| 4 | 有 script、无 country 的 locale 生成为 `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')` | `gen_l10n.dart:1109-1123` |
| 5 | **同语言的子类合并进基类 locale 的文件**：`zh_Hant` 与 `zh` 同语言 → `class AppLocalizationsZhHant extends AppLocalizationsZh` 生成在 **`lib/l10n/app_localizations_zh.dart`** 里，**不新增生成文件** | `gen_l10n.dart:1139-1167`（`isBaseClassLocale` + `getLocalesForLanguage`） |
| 6 | 子类只 override「Hant 文件里存在的键」；缺失的键记进 `untranslated-messages-file`，并**静默继承简体译文** | `gen_l10n.dart:1057-1077` |
| 7 | `lookupAppLocalizations` 生成的是**嵌套 switch**（**2026-10-05 实测修正**，原方案写成 `case 'zh_Hant'` 是错的）：先 `switch (locale.languageCode)` 的 `case 'zh': {`，内层 `switch (locale.scriptCode)` 的 `case 'Hant': return AppLocalizationsZhHant();`；`scriptCode` 不匹配时 `break` 出去，落到第二个 switch 返回 `AppLocalizationsZh()` | 实测生成物 `lib/l10n/app_localizations.dart:7821-7848` |
| 7b | `delegate.isSupported` 判的是 `['en', 'zh'].contains(locale.languageCode)`（**不含 `zh_Hant`**）→ 这正是不许写 `Locale('zh_Hant')` 的硬证据：那种写法语言码是 `zh_Hant`，**连 supported 都算不上** | 实测生成物 `app_localizations.dart:7815` |
| 8 | `preferred-supported-locales: [zh]` 决定 `supportedLocales` 的**首项**，也就是"设备语言不支持时的回落项"。实测生成结果：`[Locale('zh'), Locale('en'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]` | `l10n.yaml` 现有配置 + 实测生成物 `app_localizations.dart:96-100` |
| 9 | 框架文案无需自备：`flutter_localizations` 已含 `zh_Hant` / `zh_Hant_TW` / `zh_Hant_HK` 的 Material/Cupertino/Widgets 文案 | `D:\allexe\flutter\packages\flutter_localizations\lib\src\l10n\generated_material_localizations.dart:45489`、`45862`、`45881` |

### 2.1 运行时解析链路（照这个顺序排查问题）

```
AppLocaleSettings.instance.locale          （阶段 4 起可能返回 zh_Hant）
  → MaterialApp.locale
  → WidgetsApp 用 [该 locale] 对 supportedLocales 做 basicLocaleListResolution
  → 命中 Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')（supportedLocales 第 3 项）
  → AppLocalizations.delegate.load(locale)
  → isSupported：['en','zh'].contains('zh') ✓
  → lookupAppLocalizations：languageCode 'zh' → scriptCode 'Hant' → AppLocalizationsZhHant()
     （继承 AppLocalizationsZh，只覆盖 Hant 文件里有的键）
```

**实测生成物规模**（`flutter gen-l10n` 后）：

| 文件 | 变化 |
|---|---|
| `app_localizations.dart` | 7848 行；`supportedLocales` 三项；`lookupAppLocalizations` 多出嵌套 Hant 分支 |
| `app_localizations_zh.dart` | 4462 → **8925 行**（末尾新增 `class AppLocalizationsZhHant extends AppLocalizationsZh`） |
| `app_localizations_en.dart` | 4686 → **4689 行**（只多 `languageNameZhHant`） |
| `app_localizations_zh_Hant.dart` | **不存在**（同语言子类不单独成文件） |
| `l10n_untranslated.json` | `{}` |

**注意**：本 App **没有「跟随系统」**，`locale` 永远由设置显式给出。所以设备语言是 `zh_TW`/`zh_HK` 也**不会**自动变繁体——必须用户手动选。这是拍板结论 3，不是 bug。

---

## 3. 关键坑（按踩坑概率排序）

1. **`Locale('zh_Hant')` 静默回落简体** —— 见 §1.1。
2. **缺键不报错**：Hant ARB 少写一个键，编译和界面都不报错，只是那一句显示简体。唯一防线是 G3（`arb_hant.py check`）和 G4（`l10n_untranslated.json` 必须 `{}`）。
3. **`@@locale` 与文件名不一致 → `gen-l10n` 直接失败**，错误信息很直白（`The locale specified in @@locale and the arb filename do not match`）。
4. **Hant 文件不写 `@` 元数据**：元数据（占位符声明、描述）只在模板 `app_zh.arb` 里，`app_en.arb` 也没写。往 `app_zh_Hant.arb` 里塞 `@key` 会被工具判为硬错误（`arb_hant.py check` 的第 2 条硬门禁）。
5. **占位符与 ICU 结构必须与模板逐字一致**：`{count, plural, =1{…} other{…}}` 的内层 `{count}` 不能漏，占位符名字不能改。硬错误由 `arb_hant.py apply/check` 拦。
6. **生成物 diff 会非常大**：`app_localizations_zh.dart` 现在 4463 行，加完子类约 9000 行。这是**预期**的，不要为了"diff 好看"去手改生成物。
7. **不要手改 `lib/l10n/app_localizations*.dart`**：一律由 `flutter gen-l10n` 产出（`flutter gen-l10n` 是代码生成，**不是** `flutter build`，允许跑）。
8. **术语一致性 > 文采**：同一个词在全 App 必须同一种译法，以 `03-stage1-terminology.md` 为准；术语表里没有的新词，翻完后**回填术语表**。
9. **别顺手改别的**：本轮只碰下面第 4 节列的文件。看到别处有错别字、有坏味道，记下来报告，不要动。

---

## 4. 本轮全部改动清单（超出这张表 = 违规）

| 文件 | 动作 | 阶段 |
|---|---|---|
| `lib/l10n/app_zh.arb` | 加 `languageNameZhHant` + 其 `@` 元数据 | 2 |
| `lib/l10n/app_en.arb` | 加 `languageNameZhHant` | 2 |
| `lib/l10n/app_zh_Hant.arb` | **新增**（1278 键，无元数据） | 2 |
| `lib/l10n/legal_zh_hant.dart` | **新增**（长文正文，四字段） | 3 |
| `lib/l10n/legal.dart` | 分发加 Hant 分支 | 3 |
| `lib/services/app_locale_settings.dart` | 加第三值 + `locale` getter | 4 |
| `lib/widgets/language_picker_dialog.dart` | 语言列表加第三项 | 4 |
| `lib/pages/settings/settings_page.dart` | 语言副标题三选一 | 4 |
| `lib/l10n/app_localizations.dart` | **重新生成**（入库） | 4 |
| `lib/l10n/app_localizations_zh.dart` | **重新生成**（入库，含 `AppLocalizationsZhHant`） | 4 |
| `docs/archive/i18n-migration-plan/tools/i18n_scan.py` | `GENERATED_SKIP` 加 `lib/l10n/legal_zh_hant.dart` | 5 |
| `docs/archive/i18n-migration-plan/tools/whitelist.json` | `files` 加 `lib/l10n/legal_zh_hant.dart` | 5 |
| `test/language_picker_test.dart` | 改断言（两项 → 三项） | 6 |
| `test/legal_texts_test.dart` | 加 `zh_Hant` 分支 | 6 |
| `test/l10n_test_helper.dart` | 加 `kTestLocaleZhHant`（可选，供新测试用） | 6 |
| `test/zh_hant_locale_test.dart` | **新增**（locale 值/持久化/回落） | 6 |

**条件性改动（默认不做）**：`android/app/src/main/res/values-zh-rTW/strings.xml` —— 仅当用户拍板"繁体应用名与简体不同"时才建（见阶段 5）。

### 4.1 明确不做

- **不改 `l10n.yaml`**：`preferred-supported-locales: [zh]` 正好继续保证"不支持的语言回落简体"，老用户现状不变。
- **不引入字体**：UI 无自带字体，繁简由系统字体渲染（系统字体一定覆盖常用繁体字）。
- **不做「跟随系统」**：不加 `localeListResolutionCallback`。将来若要做，注意 `zh_TW`（无 script）会匹配到 `Locale('zh')` = 简体，需要另加 `zh_Hant_TW` 条目或自定义解析——**那是另一个需求，本轮不碰**。
- **不动数据层中文**：字幕简繁轨识别（`lib/utils/subtitle_language.dart`）、同名外挂字幕后缀（`subtitle_auto_match.dart`）、章节关键词、B 站角标匹配键等，都是"匹配键/数据"，翻了功能就坏（第一轮已写进白名单）。
- **不加 `zh_Hant_TW` / `zh_Hant_HK`**（拍板结论 1）。

---

## 5. 回滚方式

本轮改动集中在 3 个语言相关 lib 文件 + 3 个 ARB + 1 个长文文件 + 测试。回滚：

1. 删掉 `lib/l10n/app_zh_Hant.arb` 与 `lib/l10n/legal_zh_hant.dart`；
2. `git checkout --` 还原其余被改文件（含门禁配置与测试）；
3. 重跑 `flutter.bat gen-l10n` → 生成物回到两语言状态；
4. 跑 G1/G2 确认回到基线。

因为用户随时可以要求回滚，**阶段 4 之前不要动生成物**（生成物一旦重新生成，diff 就很大）。
