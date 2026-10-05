# 05 · 阶段 3：长文正文（隐私政策 / 用户协议）

> 长文**不进 ARB**：第一轮已拍板"按语言拆 Dart 文件"（`lib/l10n/legal_zh.dart` / `legal_en.dart`）。
> 本轮加第三份 `lib/l10n/legal_zh_hant.dart`（正文 **3561 汉字**）。

---

## 1. 目标与产出

| 项 | 内容 |
|---|---|
| 目标 | 繁体用户看到的是繁体长文，段落结构与条款内容与简体版逐段对应 |
| 产出 | ① 新增 `lib/l10n/legal_zh_hant.dart` ② 改 `lib/l10n/legal.dart` 分发 ③ 改 `test/legal_texts_test.dart`（测试在阶段 6 一起改，本阶段先改代码） |
| 前置 | 阶段 1 术语表；阶段 2 不阻塞本阶段 |
| 门禁 | 段数/小节数比对脚本 + 无 `**` + 正文长度下限 |
| 预计耗时 | 半天 |

---

## 2. 先读懂现状（动手前必读这三个文件）

| 文件 | 作用 | 关键点 |
|---|---|---|
| `lib/l10n/legal_zh.dart` | 简体正文（**源文**，167 行） | `const ({String policyTitle, String policyBody, String agreementTitle, String agreementBody}) legalZh = (...)`；正文用 `'''` 多行字符串，段间空行原样保留 |
| `lib/l10n/legal_en.dart` | 英文正文（译文，172 行） | 四个字段名/顺序/类型必须与简体版**逐字一致**；正文里的 `**` 一律写成平文 |
| `lib/l10n/legal.dart` | 分发（23 行） | `legalTextsFor(Locale)` 目前是 `locale.languageCode == 'en' ? legalEn : legalZh` |

两个正文文件的头部注释都写了纪律：**改一种语言的条款必须同步改另一种**（本轮之后是三种）。

---

## 3. 步骤

### 步骤 1：新建 `lib/l10n/legal_zh_hant.dart`

结构照 `legal_en.dart` 写（文件头注释 → `library;` → 一个 `const (...) legalZhHant = (...)`），要求：

1. 四个字段名、顺序、类型与 `legal_zh.dart` **逐字一致**（否则 `legal.dart` 的类型不匹配、编译不过）；
2. 正文**逐段对应**：段落数、小节数、编号（一、二、三…）、空行位置与简体版一一对应；
3. **只做字形与用词转换**（术语表），**不许增删改条款内容**、不许调整段落顺序；
4. 正文里**不出现 `**`**（与现有两版一致：正文用纯 `Text()` 渲染，星号会原样显示）；
5. 应用名保留 `小喵Player`（与简体一致，不改成「小喵播放器」）；
6. 文件头注释照 `legal_en.dart` 的写法，写明"改简体条款必须同步改本文件"，并把"两个文件是一对"改成"三个文件是一组"。

**标题（**已定稿，照抄，不要再改**）**：

| 字段 | 简体现值 | 繁體定稿值 |
|---|---|---|
| `policyTitle` | 用户隐私政策 | 使用者隱私權政策 |
| `agreementTitle` | 用户服务协议与隐私政策 | 使用者服務條款與隱私權政策 |

> 这两处是**条款标题**，不是普通 UI 文案。用户已授权由 AI 直接定稿（2026-10），执行时**照抄上表**，不要再去问、也不要顺手改词；
> 日后若要调整，先分清是"产品改名"还是"译法调整"，并在阶段报告里写明改的是哪一处。
> 正文里出现这两篇名字的地方（导语、结尾）要与标题保持一致，但**不要改动条款句子结构**。

### 步骤 2：改 `lib/l10n/legal.dart`

现有分发只认 `languageCode == 'en'`；繁体是**同一个语言码 `zh`**，靠 script 区分，所以必须显式判 script：

```dart
import 'package:moumou/l10n/legal_zh_hant.dart';

/// 是否繁体（兼容 Locale.fromSubtags(zh, Hant) 与 Locale('zh_Hant') 两种写法）
bool _isHant(Locale locale) {
  final script = locale.scriptCode?.toLowerCase() ?? '';
  return script == 'hant' || locale.languageCode.toLowerCase().contains('hant');
}

({...}) legalTextsFor(Locale locale) => locale.languageCode == 'en'
    ? legalEn
    : (_isHant(locale) ? legalZhHant : legalZh);
```

要点：

- **必须先把 `en` 判完再判繁体**（英文的 languageCode 是 `en`，不冲突，但顺序写清楚更好读）；
- 用"script 或 languageCode 含 hant"的宽松判定：`Locale('zh_Hant')`（错误写法，`languageCode == 'zh_Hant'`、`scriptCode == ''`）也能落对，避免将来有人写错时**静默退回简体**；
- 注释里的"未知语言回落中文，与 `l10n.yaml` 的 `preferred-supported-locales: [zh]` 一致"这句要保留并补充繁体。

### 步骤 3：自检（本阶段的门禁）

```powershell
py -c "import io,re,os;files=['lib/l10n/legal_zh.dart','lib/l10n/legal_zh_hant.dart'];[print(os.path.basename(f),'sections=',len(re.findall(r'^[一二三四五六七八九十]+、',io.open(f,encoding='utf-8').read(),re.M)),'blocks=',len(re.findall(r'^第[一二三四五六七八九十]+部分',io.open(f,encoding='utf-8').read(),re.M)),'han=',sum(1 for c in io.open(f,encoding='utf-8').read() if '\u4e00'<=c<='\u9fff')) for f in files]"
```

期望：两个文件的 `sections` / `blocks` **相等**；繁体正文 `han` 数量应接近简体（3561 上下，±20%）。

再确认没有 Markdown 星号（只查**正文**，注释里的 `**` 是允许的）：

```powershell
py -c "import io,re;t=io.open('lib/l10n/legal_zh_hant.dart',encoding='utf-8').read();body=t.split('legalZhHant = (')[1];print('asterisks in body =',body.count('**'))"
```

期望：`0`。

---

## 4. 常见坑

1. **改条款 = 事故**：这不是"翻译得更好"的地方，只做字形与用词转换；条款有歧义 → 停下来问。
2. **段落结构必须一一对应**：将来用户改简体条款，维护者要能逐段对照三种语言；段数不一致 = 返工。
3. **`'''` 多行字符串里的 `$`**：Dart 会做插值，正文里如果有 `$`（价格、占位）要转义成 `\$`。现有两版正文没有 `$`；如果你的译文引入了，必须转义。
4. **别把长文塞进 ARB**（那是第一轮明确否掉的方案）。
5. **`legal_zh_hant.dart` 会出现大量汉字** —— 它必须进残留门禁白名单，否则阶段 5 的门禁会红（阶段 5 会做，这里先记住）。

---

## 5. 完成标准

- [x] `lib/l10n/legal_zh_hant.dart` 存在，四字段与简体版逐字对应（记录类型 `legalZhHant`）
- [x] 段落/小节/编号与简体版一一对应：`_stage3_legal_check.py` **LEGAL PASS**
- [x] 正文无 `**`；无未转义的 `$`
- [x] `legal.dart` 分发能区分 `zh` / `zh_Hant` / `en`（含 `_isHant` 宽松判定），注释已同步为"三份一组"
- [x] 标题照 §3 步骤 1 表格照抄（`使用者隱私權政策` / `使用者服務條款與隱私權政策`）
- [ ] （阶段 6 补）`test/legal_texts_test.dart` 覆盖 `zh_Hant`

### 5.1 自检结果（2026-10-05，`tools/_stage3_legal_check.py`）

| 项 | 简体 zh | 繁體 zh_Hant | 英文 en |
|---|---|---|---|
| 小节数（一、二、…） | 22 | **22** | 0（英文用小节标题，不编号） |
| 「第 N 部分」数 | 2 | **2** | 2 |
| 段落块数 | 56 | **56** | 56 |
| 正文行数 | 142 | **142** | — |
| 正文内 `**` | 0 | **0** | 0 |
| 正文内 `$` | 0 | **0** | 0 |
| 汉字数（整文件） | 3561 | 3833 | 229 |

> 汉字数 +7.6% 属正常：繁体用词更长（「本应用」→「本應用程式」、「账号」→「帳號」等），不是漏译或增写。

`flutter analyze` → **No issues found!**（新增 Dart 文件后先跑一遍，避免把编译错误带到阶段 4）

---

## 6. 执行记录

| 日期 | 结果 |
|---|---|
| 2026-10-05 | **阶段 3 完成**。① 新建 `lib/l10n/legal_zh_hant.dart`：两篇正文（隱私權政策 9 小节 + 服務條款 7 小节 + 隱私權政策 6 小节）逐段转译，标题按定稿写；`━━` 分隔线、邮箱、段落排版原样保留。② 改 `lib/l10n/legal.dart`：加 `legalZhHant` 分发与 `_isHant()`（兼容 `Locale.fromSubtags(zh,Hant)` 与写错的 `Locale('zh_Hant')`，避免长文静默退回简体）。③ 新增自检工具 `tools/_stage3_legal_check.py`，输出 `_evidence/阶段3/正文结构对比.md`。④ 结构门禁 PASS（小节 22/22、部分 2/2、段落 56/56、正文行 142/142、无 `**`、无未转义 `$`）。⑤ `flutter analyze` 无问题。未改任何条款内容，未跑保留字门禁（阶段 5）。 |
