# 繁体中文（zh_Hant）接入 · 收口报告

| 项 | 值 |
|---|---|
| 轮次 | 第三轮（在第一轮 English、第二轮回归测试之后） |
| 工程 | `C:\Users\root\Desktop\moumou`（小喵 Player，Flutter / Android） |
| 起始基线 | `main` = `908ff66`，`flutter test` = 1834 passed / 13 skipped |
| 收口日期 | 2026-10-05 |
| 阶段 | 1 定调与术语表 → 2 ARB 译文 → 3 长文正文 → 4 代码接入与生成物 → 5 门禁登记与 Android 资源 → 6 测试补齐与全量测试 → 7 真机走查 |
| 结论 | **7 个阶段全部收口；真机走查 38/38 通过，无缺陷；门禁全绿** |
| 版本号 | `1.3.6+4`（**未改**，用户未指示升版本） |
| 提交状态 | **改动全部停在本地，未提交、未推送** |

---

## 1. 交付内容

| 交付物 | 说明 |
|---|---|
| 第三门语言 `zh_Hant`（通用繁體，台湾用词为主） | 语言窗第三项「繁體中文」，选中即生效、持久化，无「跟随系统」 |
| `lib/l10n/app_zh_Hant.arb` | 1283 行 / **1279 键**，与模板键集合、占位符、ICU 结构完全同构 |
| `lib/l10n/legal_zh_hant.dart` | 隐私政策 + 用户服务协议繁体正文（171 行，与简体版逐段/逐行结构对应） |
| Android 繁体资源 | `values-b+zh+Hant/strings.xml`（9 条，BCP-47 脚本限定符） |
| 测试 | 新增 `test/zh_hant_locale_test.dart`（9 条）＋ 改 3 个测试文件（夹具 + 断言） |
| 执行包（本目录，不进 Git） | 7 份阶段文档 + README（含 11 条拍板结论）+ 4 个工具 + 3 份证据报告 |

---

## 2. 用例统计（阶段 7 真机走查，用户执行）

| 分组 | 条数 | 通过 | 不通过 | 未验证 |
|---|---|---|---|---|
| H-I18N（语言入口与切换） | 11 | 11 | 0 | 0 |
| H-LEGAL（长文） | 3 | 3 | 0 | 0 |
| H-UI（页面抽查） | 12 | 12 | 0 | 0 |
| H-DATA（数据层不受影响） | 9 | 9 | 0 | 0 |
| H-AND（Android 原生资源） | 3 | 3 | 0 | 0 |
| **合计** | **38** | **38** | **0** | **0** |

用户结论原话：「阶段 7 我测试没什么问题」。

---

## 3. 缺陷清单

**无**。（缺陷记录模板见 `09-阶段7-真机走查与收口.md` §4，本轮未用到。）

---

## 4. 最终门禁复跑结果（2026-10-05，收口时实跑）

| 门禁 | 命令 | 结果 |
|---|---|---|
| G1 静态分析 | `flutter analyze` | `No issues found!` |
| G2 全量测试 | `flutter test` | **All tests passed!（1850 passed / 13 skipped）** —— 基线 1834 → **+16** |
| G3 ARB 硬门禁 | `arb_hant.py check` | `CHECK PASS`、**硬错误 0**；提示：与简体同形 144 键（已逐条解释）、简体特征字 1 键（`languageNameZh` 故意保持简体） |
| G4 未翻译清单 | `l10n_untranslated.json` | `{}` |
| G5 残留中文门禁 | `i18n_scan.py residual --include-android` | `residual: 0  expired whitelist: 0` |
| 长文结构 | `_stage3_legal_check.py` | `LEGAL PASS`（小节 22/22、部分 2/2、段落 56/56、正文行 142/142） |
| 生成物形状 | `_stage4_check.py` | `STAGE4 PASS`（7 条断言） |
| 行尾约定 | `_eol_fix.py --check` | `CHECK PASS`（0 个非 CRLF） |

---

## 5. 改动文件全清单

**修改（15 个，`git diff --stat` 合计 +4653 / −39）**

| 文件 | 阶段 | 说明 |
|---|---|---|
| `lib/l10n/app_zh.arb` | 2 / 6 | 加 `languageNameZhHant`；语言名描述改「三版」；语言窗标题改「选择语言」 |
| `lib/l10n/app_en.arb` | 2 / 6 | 加 `languageNameZhHant`；标题改 `Choose Language` |
| `lib/l10n/app_localizations.dart` | 4 | 重新生成（supportedLocales 三项 + 嵌套 Hant 查找分支） |
| `lib/l10n/app_localizations_zh.dart` | 4 | 重新生成（4462 → 8925 行，末尾 `AppLocalizationsZhHant`） |
| `lib/l10n/app_localizations_en.dart` | 4 | 重新生成（+`languageNameZhHant`） |
| `lib/l10n/legal.dart` | 3 | 分发加繁体 + `_isHant()`（兼容 `Locale.fromSubtags` 与写错的 `Locale('zh_Hant')`） |
| `lib/services/app_locale_settings.dart` | 4 | 加 `zhHantCode`；`locale` getter 用 `Locale.fromSubtags`；`_normalize` 三值 |
| `lib/widgets/language_picker_dialog.dart` | 4 / 6 | 三项；注释注明标题已改定（不再中英共存） |
| `lib/pages/settings/settings_page.dart` | 4 | 副标题三选一（`_languageNameOf`） |
| `test/l10n_test_helper.dart` | 6 | 加 `kTestLocaleZhHant` |
| `test/language_picker_test.dart` | 6 | 三项断言 + 2 条新用例 + 标题断言 |
| `test/legal_texts_test.dart` | 6 | Locale 列表 + 3 条繁体用例 |
| `docs/archive/i18n-migration-plan/tools/i18n_scan.py` | 5 | `GENERATED_SKIP` 加 `legal_zh_hant.dart` |
| `docs/archive/i18n-migration-plan/tools/whitelist.json` | 5 | `files` 加 2 条（繁体长文、Android 繁体资源）→ 共 9 项 |
| `docs/archive/i18n-migration-plan/05-residual-chinese-report.md` | 5 | 门禁产物重写（**预期改动**；不想要这个 diff 可 `git checkout --` 还原） |

**新增（4 个）**

| 文件 | 行数 |
|---|---|
| `lib/l10n/app_zh_Hant.arb` | 1283 行 / 72.8 KB |
| `lib/l10n/legal_zh_hant.dart` | 171 行 |
| `test/zh_hant_locale_test.dart` | 150 行（9 条用例） |
| `android/app/src/main/res/values-b+zh+Hant/strings.xml` | 33 行（9 条） |

---

## 6. 过程中的判断与偏差（留痕，供后人复盘）

| # | 事件 | 处理 |
|---|---|---|
| 1 | 方案预测 `lookupAppLocalizations` 会出现 `case 'zh_Hant'`，实测是**嵌套 switch**（`case 'zh':` → 内层 `switch (locale.scriptCode)` → `case 'Hant'`），且 `isSupported` 判的是不含 script 的 `['en','zh']` | 属**预期形状写错、结论不变**；已回填 `02-技术方案.md` §2 与阶段 4 文档，并做成脚本断言 |
| 2 | 方案写「Android 资源默认不动，9 条里没有必须区分简繁的内容」 | **实测推翻**：9 条里 7 条含简体专用字形且用户可见。停下来问用户 → 拍板方案 A（建 `values-b+zh+Hant/`） |
| 3 | 文档写 `Locale('zh_Hant')` 的 `scriptCode` 是「空串」 | 阶段 6 写测试时实测是 **`null`**；已改正，结论不变（`legal.dart` 的 `?? ''` 已兼容） |
| 4 | 用整文件重写落盘的 4 个文件变成 **LF**，与仓库 CRLF 约定不符（git 警告 2 处） | 新增 `tools/_eol_fix.py` 做字节级归一；结论：**定向替换不破坏 CRLF，整文件重写才会** |
| 5 | 用户看图后改定：语言窗标题去掉中英共存 | 改 3 个 ARB + 注释 + 生成物 + 测试，并新增 1 条「标题随语言」断言；记入 README §2 第 11 条 |

---

## 7. 没做与没验到的

1. **译文无人工/母语审校**（拍板结论 2：AI 按术语表重译）。144 条「与简体同形」的键我逐条解释过，但只有我审过一遍。
2. **术语表低频词未穷尽**：审计只列了 Top 40/60/60，剩余未覆盖命中按"句式碎片/同形词"判断，未逐条确认。
3. **`values-b+zh+Hant/` 的老设备覆盖**：只上报地区（`zh-TW`）不上报脚本的设备可能仍落简体；阶段 7 的 H-AND 三条已通过（说明测试机命中正常），但**未在多台/多版本设备上验证**；后补方案是再加 `values-zh-rTW/`（阶段 5 §4.2 方案 B）。
4. **第一轮归档包里的旧标题记录未改**：`docs/archive/i18n-regression-test-plan/`（T1-I18N-001 预期、数据基线）与 `docs/archive/i18n-migration-plan/02-implementation-plan.md` §1.7 仍写「刻意双语」。那是**已执行轮次的历史记录**，我按"不改写历史"处理；新口径在 README §2 第 11 条。
5. **未做版本号变更**（用户未指示）。
6. 第一轮遗留：`docs/archive/` 下 4 个被 `*.log` 忽略的日志文件仍未入库（与本轮无关）。

---

## 8. 提交建议（**等用户说"提交"再动手**）

- 一次提交（一批改动只提交一次）；
- 标题：`feat: 新增繁體中文（zh_Hant）语言支持`
- 正文（每行一条、越短越好、不写原理与测试结果）：

```
- 新增繁體中文（zh_Hant）语言支持
- 新增繁體長文正文與 Android 繁體資源
- 語言窗標題改為跟隨界面語言
- 補充繁體相關測試
```

- 推送后给提交 SHA 与 `local == remote` 校验结果；不 force push、不改写历史。

---

## 9. 归档

收口报告与整个执行包**现在都在** `杂项文件\繁体中文接入方案\`（该目录被 `.gitignore` 忽略，不进 Git）。
**归档时机**：等用户下命令后整包移到 `docs/archive/i18n-zh-hant/` —— 未收到命令前不移动。
