# 08 · 阶段 6：测试补齐与全量测试

> 第一轮已经建好测试夹具（把 535 处 `find.text('中文')` 钉在简体上），本轮**必须保住这个夹具**，只做加法。

---

## 1. 目标与产出

| 项 | 内容 |
|---|---|
| 目标 | 繁体有回归测试守着；既有 1834 条测试全绿 |
| 产出 | ① `test/l10n_test_helper.dart` 加繁体夹具 ② `test/language_picker_test.dart` 改断言 + 加用例 ③ `test/legal_texts_test.dart` 加繁体分支 ④ 新增 `test/zh_hant_locale_test.dart` |
| 前置 | 阶段 4（`AppLocalizations` 已认 `zh_Hant`）、阶段 5（门禁已登记） |
| 门禁 | **G1**、**G2**（全量）、**G3**、**G4**、**G5**（全量复跑） |
| 预计耗时 | 半天 |

---

## 2. 步骤 1：夹具加繁体（`test/l10n_test_helper.dart`）

**只加，不改**（`kTestLocaleZh` 一动，535 处既有断言会整片红）：

```dart
/// 测试用的繁体 locale（必须与生成物 `supportedLocales` 里的写法一致）
const Locale kTestLocaleZhHant =
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
```

> `Locale.fromSubtags` 是 **const 构造**（`sky_engine/lib/ui/platform_dispatcher.dart:2893`），所以可以写 `const`，也能放进 `const` 列表。
> 生成物里的 `supportedLocales` 就是这么写的 —— 两处写法必须一致，否则 `Locale` 不相等。

顺手把文件头注释里"钉简体"那段补一句：繁体用 `kTestLocaleZhHant`（`find.text` 断言繁体文案的新用例用它）。

---

## 3. 步骤 2：`test/language_picker_test.dart`

现状：文件头注释与用例名都写"两项自称"；第 59-72 行断言只有 `简体中文` / `English`。

1. **用例名与注释**：「弹窗：双语标题 + 两项自称 + 默认选中简体中文」→「弹窗：**标题随语言** + 三项自称 + 默认选中简体中文」
   （⚠️ 2026-10-05 用户改定：标题不再中英共存，`zh`=选择语言 / `zh_Hant`=選擇語言 / `en`=Choose Language，见 README §2 第 11 条）；
2. 第一个用例补一行：`expect(find.text('繁體中文'), findsOneWidget);`
3. **新增用例 A：选繁體中文 + 确定**
   - 点 `繁體中文` → 确定；
   - 断言 `settings.rawValue == 'zh_Hant'`；
   - 断言 `settings.locale == kTestLocaleZhHant`（**这一条是 §1.1 那个坑的守门人**：如果有人把 `locale` getter 改回 `Locale('zh_Hant')`，这条必须红）；
   - 断言 `prefs.getString('app_locale') == 'zh_Hant'`。
4. **新增用例 B：设置页副标题在繁体下显示「繁體中文」**
   - 先 `await settings.setLocale('zh_Hant')` 再 pump `SettingsPage`；
   - 断言 `find.text('繁體中文')` 命中副标题（注意：弹窗里也有这个词，但本用例不开弹窗）；
   - 若与「简体中文」同时出现会误判，用 `find.text` 的数量断言（`findsOneWidget`）。
5. **不动**「语言」组位置那个用例（「弹幕」下方、「下载」上方）。

---

## 4. 步骤 3：`test/legal_texts_test.dart`

现状（第 14 行）用 `for (final code in const ['zh', 'en'])` + `Locale(code)` —— 繁体是**同一个语言码 `zh`**，必须换成 Locale 列表：

```dart
    for (final locale in const <Locale>[
      Locale('zh'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('en'),
    ]) {
      test('$locale：四段都非空', () { ... });
    }
```

再补充：

| 用例 | 断言 |
|---|---|
| 繁体：标题已确认 | `policyTitle` / `agreementTitle` 等于阶段 3 用户确认的译法 |
| 繁体：应用名保留 | 正文含 `小喵Player`（与简体一致） |
| 繁体：是长文不是占位串 | `policyBody.length > 1000`、`agreementBody.length > 1000` |
| 繁体：宽松判定 | `legalTextsFor(const Locale('zh_Hant'))` 也返回繁体（守 `_isHant` 的 `languageCode.contains('hant')` 分支） |
| 未知语言 | 仍然回落简体（现有 `ja` 用例保留） |
| 英文 | 现有「无残留汉字」「Meow Player」用例保留 |

---

## 5. 步骤 4：新增 `test/zh_hant_locale_test.dart`

建议内容（纯 Dart 逻辑 + 少量文件读取，不依赖网络）：

1. **持久化与回落**
   - `setLocale('zh_Hant')` → `rawValue == 'zh_Hant'`、`locale == kTestLocaleZhHant`、prefs 写入 `zh_Hant`；
   - `setLocale('zh-Hant')`、`setLocale('zh_TW')`、`setLocale('')`、`setLocale('fr')` → 一律回落 `'zh'`。
2. **生成物对齐**
   - `AppLocalizations.supportedLocales` 含 `kTestLocaleZhHant`（用 `contains`）；
   - `lookupAppLocalizations(kTestLocaleZhHant).languageNameZhHant == '繁體中文'`；
   - `lookupAppLocalizations(kTestLocaleZhHant).languageNameZh == '简体中文'`（**语言名不自译**：繁体界面里"简体中文"仍写简体自称）。
3. **ARB 对称（永久防线）** —— 以后谁给模板加键忘了加繁体，这条就红：

```dart
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

Set<String> _placeholders(String s) => {
      ...RegExp(r'\{(\w+)\s*[,}]').allMatches(s).map((m) => m.group(1)!),
      ...RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!),
    };
```

   - 三条断言：`_keys(zh) == _keys(en)`、`_keys(zh) == _keys(zh_Hant)`、逐键占位符集合相等；
   - 若用户不希望测试依赖仓库文件（`flutter test` 工作目录 = 工程根，读文件是可行的），可只保留"生成物对齐"两条，但**建议保留**这条对称检查。

---

## 6. 步骤 5：门禁（全量复跑）

```powershell
D:\allexe\flutter\bin\flutter.bat analyze
D:\allexe\flutter\bin\flutter.bat test
py "杂项文件\繁体中文接入方案\tools\arb_hant.py" check
py -c "import io;print(io.open('l10n_untranslated.json',encoding='utf-8').read().strip())"
py "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --include-android
```

期望：`No issues found!` / `All tests passed!`（通过数 ≥ 1834，且比基线多出本轮新增用例）/ `CHECK PASS` / `{}` / `residual: 0  expired whitelist: 0`。

阶段报告里要写**实际通过数**（基线 1834 passed / 13 skipped），不要只写"全绿"。

---

## 7. 常见坑

1. **不许改既有 `find.text('中文')` 断言**去迁就繁体 —— 那些断言靠 `kTestLocaleZh` 钉着，本轮不该红。真红了说明**你的代码改动影响了简体路径**，要查代码不是改测试。
2. **`Locale.fromSubtags` 与 `Locale('zh_Hant')` 不相等**：测试里比较 Locale 时务必用同一个构造方式（夹具 `kTestLocaleZhHant`）。
3. **widget 测试里改语言后不会自动重建 `MaterialApp`**：`AppLocaleSettings` 只是 ChangeNotifier，测试宿主没监听它。要验"界面变繁体"，就**先把设置设好再 pump**，或自己包一层 `ListenableBuilder`。
4. **不要顺手修既有红**：测试红了但看起来与繁体无关 → 停下来报告（第一轮也是这么办的）。
5. **别在测试里放真机/网络依赖**。

---

## 8. 完成标准

- [x] 夹具加了 `kTestLocaleZhHant`（const `Locale.fromSubtags`），既有夹具 `kTestLocaleZh` 一字未改
- [x] `language_picker_test.dart`：三项断言（加 `繁體中文`）+ 2 个新用例（繁体写入持久化 / `locale == kTestLocaleZhHant`；设置页副标题显示「繁體中文」）
- [x] `legal_texts_test.dart`：循环改 Locale 列表（含 fromSubtags）+ **4 条**繁体用例（定稿标题 / 应用名与长文 / 无简体专用词 / 宽松判定 `Locale('zh_Hant')`）
- [x] `zh_hant_locale_test.dart`：新增 8 条（三值取值与回落 / 生成物对齐 / ARB 三边对称）
- [x] G1/G2/G3/G4/G5 全绿，实际通过数已记录

### 8.1 门禁实测（2026-10-05）

| 门禁 | 结果 |
|---|---|
| G1 `analyze` | `No issues found!` |
| G2 全量 `test` | **All tests passed!（+1849 ~13）** —— 基线 1834 → **+15 条**新增用例，13 skipped 不变 |
| G3 `arb_hant.py check` | `CHECK PASS`、`hard errors : 0`（提示 144 同形 + 1 故意项，见阶段 2） |
| G4 | `l10n_untranslated.json` = `{}` |
| G5 | `residual: 0  expired whitelist: 0` |

**新增 15 条**：`zh_hant_locale_test.dart` **8** 条 + `legal_texts_test.dart` **5** 条（循环多一个 locale 的「四段非空」1 条 + 4 条繁体用例）+ `language_picker_test.dart` **2** 条。

---

## 9. 执行记录

| 日期 | 新增/修改测试 | 通过数 | 结果 |
|---|---|---|---|
| 2026-10-05 | 夹具 `l10n_test_helper.dart`（+`kTestLocaleZhHant`）；改 `language_picker_test.dart`、`legal_texts_test.dart`；新增 `zh_hant_locale_test.dart` | **1849 passed / 13 skipped** | **阶段 6 完成**，G1–G5 全绿 |
| 2026-10-05 | 修正 1 处文档事实错误 | — | 写测试时实测发现：`Locale('zh_Hant')` 的 `scriptCode` 是 **`null`**（不是空串），`languageCode` 才是 `'zh_Hant'`。已在 `02-技术方案.md` §1.1 改正（结论不变：`legal.dart` 的 `_isHant` 用 `?? ''` 已兼容 null）。 |
| 2026-10-05 | 一次误报 | — | 第一次跑测试时把 `test/l10n_test_helper.dart`（库文件，无 `main()`）也当测试目标传了，多出的 1 个失败是**调用方式错误**，不是测试红；单独跑三个测试文件 26/26 通过。 |
| 2026-10-05 | **产品改动（用户看图后改定）**：语言窗标题去掉中英共存 —— `app_zh.arb` 改 `选择语言`、`app_en.arb` 改 `Choose Language`、`app_zh_Hant.arb` 改 `選擇語言`（模板元数据描述同步改）；`language_picker_dialog.dart` 注释同步；`gen-l10n` 重新生成；测试同步（`language_picker_test` 两处断言 + 用例名、`zh_hant_locale_test` 一处断言，并**新增 1 条三语言标题断言**）。空跑 G1 `No issues found!`、G2 **1849 → 1850 passed / 13 skipped**。 |
