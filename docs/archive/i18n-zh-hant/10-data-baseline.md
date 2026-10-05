# 10 · 数据基线（实测）

> 本文件所有数字都在本仓库**实测过**，并给出复现命令。**复现结果与文档不符 = 代码已变化 → 停下来报告**，不要自己改口径。
> 唯一例外是 §4「未验证项」，那里的东西是**推导或估计**，不是实测。

---

## 1. ARB 与文案量

| 项 | 值 | 口径 |
|---|---|---|
| `lib/l10n/app_zh.arb` 键数 | **1278** | 非 `@` 开头的键 |
| 含汉字的键 | **1266** | 值里有 CJK 汉字（U+4E00–U+9FFF）的键 |
| 只含全角标点的键 | **11** | 值里没汉字但有全角标点/符号（如 `、`、`（{count}）`、`：`）→ **不用改字形，但要走一遍** |
| 纯 ASCII 的键 | **1** | `languageNameEn`（值 `English`） |
| 值内汉字数 | **8448** | 纯 CJK 汉字 |
| 值内非 ASCII 字符数 | **9003** | 汉字 + 全角标点 + 其他符号 —— **这才是"要过一遍"的真实量** |
| 每条平均长度 | **10.2** 字符 | 值的字符数均值 |
| 最长一条 | **165** 字符 | |
| 值里有 `{…}` 的键 | **177** | 占位符 / ICU 引用都算 |
| ICU 结构键（plural / select） | **43** | 值里含 `, plural,` / `, select,` / `, selectordinal,` |
| 元数据（`@key`） | **982** 条 | **只在模板** `app_zh.arb` 里 |
| 元数据里带 `placeholders` 的键 | **177** 个键 / **227** 个占位符名 | |
| `app_zh.arb` 体积 | 188,862 字节 | |
| `app_en.arb` 体积 | 75,815 字节 | 无元数据，故明显更小 |

## 2. 其他文案与代码量

| 文件 | 行数 | 汉字数 | 本轮动作 |
|---|---|---|---|
| `lib/l10n/legal_zh.dart` | 166 | **3561** | 参照它写繁体版 |
| `lib/l10n/legal_en.dart` | 172 | 229 | 参照它的**结构**写繁体版 |
| `lib/l10n/legal.dart` | 23 | — | 改分发（阶段 3） |
| `lib/l10n/label_maps.dart` | 650 | 1102 | **不动** |
| `lib/l10n/error_texts.dart` | 305 | 441 | **不动** |
| `lib/l10n/app_localizations.dart` | 7829 | 19828 | 阶段 4 重新生成 |
| `lib/l10n/app_localizations_zh.dart` | 4462 | 8448 | 阶段 4 重新生成（**预计涨到约 9000 行，估算非实测**） |
| `lib/l10n/app_localizations_en.dart` | 4686 | 8 | 阶段 4 重新生成（只多 1 个 getter） |
| `l10n.yaml` | 15 | — | **不动** |
| `android/.../values/strings.xml` | — | 240 | **默认不动**（9 条） |
| `android/.../values-en/strings.xml` | — | 53 | **不动**（9 条） |

## 3. 门禁与测试基线

| 项 | 值 |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | **1834 passed / 13 skipped** |
| 残留门禁 | `residual: 0  expired whitelist: 0`（`residual --include-android`） |
| `l10n_untranslated.json` | `{}` |
| 白名单 | `files` **7** 项 + `lines` **35** 项 |
| 第一轮迁移方案包 | `docs/archive/i18n-migration-plan/` **58** 个文件（含 2 个被忽略的 `.log`） |
| 第一轮回归测试包 | `docs/archive/i18n-regression-test-plan/` **97** 个文件（含 2 个被忽略的 `.log`） |
| 第一轮回归用例 | **355** 条（T0 10 / T1 35 / T2 47 / T3 64 / T4 60 / T5 34 / T6 59 / T7 46） |
| 仓库基线提交 | `908ff66`（`main` = PR #10 合并 English 后） |
| 版本号 | `1.3.6+4`（**本轮不动**） |

---

## 4. 未验证项（**推导/估计，必须在本轮执行时实测确认**）

| # | 项 | 现状 | 何时确认 |
|---|---|---|---|
| 1 | `zh_Hant` 生成物形态：`class AppLocalizationsZhHant extends AppLocalizationsZh` 生成在 **`app_localizations_zh.dart`** 内、**不新增文件** | 依据 Flutter SDK 源码推导（见 `02-technical-solution.md` §2 第 5 条），**未在本仓库实跑** | 阶段 4 重新生成后逐条核对 |
| 2 | `supportedLocales` 的实际排列顺序（`preferred-supported-locales: [zh]` 生效后） | 未实测；文档只断言"首项仍是 zh" | 阶段 4 |
| 3 | `app_localizations_zh.dart` 最终行数（估计约 9000） | 估计 | 阶段 4 |
| 4 | 系统字体对繁体字形的覆盖（是否出现豆腐块） | 未实测（UI 无自带字体，理论上系统字体覆盖） | 阶段 7 H-UI-011 |
| 5 | 繁体文案在真机上的溢出/截断 | 未实测（第一轮英文曾溢出，繁体字数≈简体，风险低） | 阶段 7 H-UI-004/007 |
| 6 | `zh_TW` / `zh_HK` 设备语言下的行为 | 未实测；本 App 无「跟随系统」，`locale` 永远显式给出 → 理论上不相关 | 阶段 7 H-I18N-008 |
| 7 | 繁体译文本身的用词准确度 | 由 AI 按术语表产出，无人工审校（拍板结论 2） | 阶段 7 H-UI-012 抽查 |

---

## 5. 复现命令（工作目录 = 工程根）

```powershell
# ARB 全量口径：键数 / 含汉字键 / 标点键 / 纯 ASCII 键 / 汉字数 / 非 ASCII 数 / 平均与最长 / ICU 键
py -c "import json,io,re;d=json.load(io.open('lib/l10n/app_zh.arb',encoding='utf-8'));v={k:x for k,x in d.items() if not k.startswith('@') and isinstance(x,str)};han=lambda s:sum(1 for c in s if '\u4e00'<=c<='\u9fff');na=lambda s:sum(1 for c in s if ord(c)>127);print('keys',len(v),'with_han',sum(1 for x in v.values() if han(x)>0),'punct_only',sum(1 for x in v.values() if han(x)==0 and na(x)>0),'pure_ascii',sum(1 for x in v.values() if na(x)==0),'han_chars',sum(han(x) for x in v.values()),'nonascii_chars',sum(na(x) for x in v.values()),'icu_keys',sum(1 for x in v.values() if re.search(r',\s*(plural|selectordinal|select)\s*,',x)),'avg',round(sum(len(x) for x in v.values())/len(v),1),'max',max(len(x) for x in v.values()))"

# 带占位符的键 / 占位符个数（按元数据）
py -c "import json,io;d=json.load(io.open('lib/l10n/app_zh.arb',encoding='utf-8'));m=[k for k in d if k.startswith('@') and k!='@@locale'];ph=[k for k in m if 'placeholders' in d[k]];print('metadata',len(m),'with_ph',len(ph),'ph_names',sum(len(d[k]['placeholders']) for k in ph))"

# 长文：行数 / 汉字 / 小节数
py -c "import io,re;[print(p,len(io.open(p,encoding='utf-8').readlines()),sum(1 for c in io.open(p,encoding='utf-8').read() if '\u4e00'<=c<='\u9fff'),len(re.findall(r'^[一二三四五六七八九十]+、',io.open(p,encoding='utf-8').read(),re.M))) for p in ['lib/l10n/legal_zh.dart','lib/l10n/legal_en.dart']]"

# Android 资源条数
py -c "import io,re;[print(p,len(re.findall(r'<string ',io.open(p,encoding='utf-8').read())),sum(1 for c in io.open(p,encoding='utf-8').read() if '\u4e00'<=c<='\u9fff')) for p in ['android/app/src/main/res/values/strings.xml','android/app/src/main/res/values-en/strings.xml']]"

# 白名单条数
py -c "import json,io;w=json.load(io.open('docs/archive/i18n-migration-plan/tools/whitelist.json',encoding='utf-8'));print('files',len(w['files']),'lines',len(w['lines']))"

# 第一轮回归用例条数
py -c "import io,re;t=io.open('docs/archive/i18n-regression-test-plan/03-test-case-list.md',encoding='utf-8').read();print('cases',len(set(re.findall(r'(?<![0-9A-Za-z])([0-9A-Z]+-[0-9A-Z]+-[0-9]{3})(?![0-9])',t))))"

# 门禁
D:\allexe\flutter\bin\flutter.bat analyze
D:\allexe\flutter\bin\flutter.bat test
py "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --include-android
py "docs\archive\i18n-zh-hant\tools\arb_hant.py" check
```

> 控制台中文会乱码（Windows 终端 + GBK），**这是正常的**：脚本的中文明细都写进 UTF-8 报告文件，用 read 工具看。
> `flutter` 把进度写 stderr，PowerShell 里可能出现 `[exit code: 1]` 的假失败 —— 以 `No issues found!` / `All tests passed!` 为准。

---

## 6. 环境（本机实测）

| 项 | 值 |
|---|---|
| Flutter | `D:\allexe\flutter\bin\flutter.bat`（Flutter 3.44.9 / Dart 3.12.2） |
| Python | `py` 启动器（3.12.x）；**`python` 不在 PATH** |
| adb | `C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| 真机 | 用户自己的 Android 设备（AI 不编译、不安装） |
