# 04 · 阶段 2：ARB 译文（`app_zh_Hant.arb`）

> 本轮工作量最大的一阶段：**1278 个键**（含汉字 1266 / 只含全角标点 11 / 纯 ASCII 1）、**8448 个汉字**（含全角标点等非 ASCII 字符共 9003 个）。翻译质量与门禁全靠本阶段。

---

## 1. 目标与产出

| 项 | 内容 |
|---|---|
| 目标 | 产出繁体 ARB，且与模板**键集合、占位符、ICU 结构完全同构** |
| 产出 | ① `lib/l10n/app_zh_Hant.arb`（新增，1278 键，无 `@` 元数据）② `app_zh.arb` / `app_en.arb` 各加一个键 `languageNameZhHant` |
| 前置 | 阶段 1 术语表已定稿 |
| 门禁 | **G3**：`py "docs\archive\i18n-zh-hant\tools\arb_hant.py" check` → `CHECK PASS` / `hard errors : 0` |
| 预计耗时 | 1 天 |

**本阶段不碰任何 Dart 代码、不跑 `gen-l10n`**（生成物留到阶段 4）。

---

## 2. 步骤

### 步骤 1：模板与英文 ARB 加 `languageNameZhHant`

在 `lib/l10n/app_zh.arb` 里 `languageNameZh` / `languageNameEn` 旁边（约 325 行）加：

```json
  "languageNameZhHant": "繁體中文",
  "@languageNameZhHant": {
    "description": "繁體中文的语言名（自称，任何语言下都不翻译）"
  },
```

在 `lib/l10n/app_en.arb` 里对应位置（约 201 行）加（**英文 ARB 不写元数据**）：

```json
  "languageNameZhHant": "繁體中文",
```

规律回顾：`languageNameZh` 在英文 ARB 里也是 `"简体中文"` —— 语言名一律用**自称**，不翻译。

> ⚠️ 顺序很重要：**先加模板键，再 `seed`**，否则骨架里没有这个键。

### 步骤 2：生成骨架

```powershell
py "docs\archive\i18n-zh-hant\tools\arb_hant.py" seed
```

预期输出：`SEED ok` / `keys : 1278` / `metadata : dropped (template only)`。
骨架里所有值**先原样拷简体**（这样中途任何时刻文件都是合法的、不会出现空文案），接下来逐批替换。

### 步骤 3：分批翻译 + 回填

**每批 ≤ 150 键**，把译文写成 JSON（`{键: 译文}`）放到 `tools\_hant_batchN.json`，然后：

```powershell
py "docs\archive\i18n-zh-hant\tools\arb_hant.py" apply --batch "docs\archive\i18n-zh-hant\tools\_hant_batch1.json"
py "docs\archive\i18n-zh-hant\tools\arb_hant.py" status
```

`apply` 会在**任何一个键**的占位符/ICU 结构不对时**整体拒绝、不写盘**（exit 1），错误逐条打印。

建议分批（按键前缀，实测键数）：

| 批次 | 范围 | 键数 |
|---|---|---|
| 1 | `common*`(94) + 零散单键（`appTitle` 及不以组前缀开头的） | ~120 |
| 2 | `settings*` 前一半 | ~150 |
| 3 | `settings*` 后一半 | ~144 |
| 4 | `player*` 前一半 | ~150 |
| 5 | `player*` 后一半 | ~145 |
| 6 | `bili*`(105) + `media*`(67) | 172 |
| 7 | `subtitle*`(62) + `danmaku*`(35) + `audio*`(15) + `decode*`(18) | 130 |
| 8 | `network*`(45) + `file*`(40) + `folder*`(21) + `ftp*`(12) + `webdav*`(9) + `smb*`(5) + `net*`(8) + `download*`(15) + `cache*`(4) + `directory*`(5) | 164 |
| 9 | 其余（`super*`19 `home*`19 `error*`15 `update*`11 `cast*`8 `options*`7 `chapter*`6 `video*`6 `playlist*`4 `custom*`4 `legal*`4 `language*`3 `open*`3 `build*`3 等） | ~110 |

> 每批生成方式：读 `lib/l10n/app_zh.arb` 里该前缀的键值 → 按术语表逐条译 → 写成批次 JSON。
> **不要用 OpenCC 之类的字符级机转**（会留下大陆用词），逐条译。

### 步骤 4：门禁与逐条复核

```powershell
py "docs\archive\i18n-zh-hant\tools\arb_hant.py" check
```

`check` 会：

1. 校验硬门禁（`@@locale`、键集合、占位符集合、ICU 类型、空值、非法元数据）→ 任一不过 = exit 1，**必须修到 0**；
2. 把两条**提示**写进 `tools\_hant_check_report.md`（UTF-8，用 read 工具看）：
   - **疑似未转换**：与简体逐字相同且含汉字 —— 多数是漏翻（`appTitle`「小喵Player」这类相同是正常的）；
   - **命中简体特征字**：值里出现简体专属字形 —— 逐条确认。

**"疑似未转换"和"简体特征字"不要求归零**（一定会有合法项），但**每一条都必须能解释**；解释不了的就是漏翻，回去改。

---

## 3. 常见坑

1. **占位符必须逐字一致**：`{name}`、`{count}`、`{count, plural, =1{…} other{…}}` 的内层 `{count}` 都不能漏、不能改名。批量 JSON 里写错会被 `apply` 拦下（好），但如果漏掉的是 **ICU 结构而占位符名恰好一样**，只有 `check` 的 ICU 校验能发现。
2. **不许给 `app_zh_Hant.arb` 加 `@` 元数据**：元数据只在模板（`app_en.arb` 也没有）。加了 = 硬错误。
3. **不许改键名、不许删键、不许加模板里没有的键**。
4. **JSON 转义**：文案里如果有 `"`，写成 `\"`；`\n` 是换行。写批次 JSON 时不要手拼字符串，用编辑工具写文件。
5. **ASCII / 数字 / 单位 / emoji / 产品名原样保留**（见 `03-stage1-terminology.md` §4）。
6. **别顺手改 `app_zh.arb` 里除 `languageNameZhHant` 之外的东西**。
7. **`l10n_untranslated.json` 在本阶段不会更新**（它由 `gen-l10n` 产出，阶段 4 才跑）——所以本阶段的门禁只有 G3。

---

## 4. 完成标准

- [x] `app_zh.arb` 加了 `languageNameZhHant`（带元数据；顺带把 `languageNameZh` / `languageNameEn` 的描述从「中英两版」改成「三版」）
- [x] `app_en.arb` 加了 `languageNameZhHant`（无元数据）
- [x] `lib/l10n/app_zh_Hant.arb` 存在，`@@locale` = `zh_Hant`，**1279 键**（模板 1278 + `languageNameZhHant`），无 `@` 元数据
- [x] G3 `check`：`CHECK PASS`、`hard errors : 0`
- [x] `_hant_check_report.md` 的提示**逐条有解释**：144 条"与简体相同"全部是繁简同形词（`取消`/`日期`/`播放`/`硬解`…）+ 语言自称 2 条；"简体特征字"**只剩 1 条**，即 `languageNameZh` = `简体中文`（**故意保持简体**，语言自称不自译）
- [x] 术语表回填：新增 **§3.11**（约 90 条，阶段 2 翻译时实际用到的词）

### 4.1 实测结果（2026-10-05）

| 项 | 值 |
|---|---|
| 批次 | **9 批**全部 apply 成功（94 / 147 / 147 / 148 / 147 / 172 / 130 / 164 / 130） |
| `status` | `translated 1123 / remaining 156`（156 = 繁简同形词，diff 为空属正常） |
| `check` | 键 1279 = 模板 1279；占位符 177 键、ICU 43 键**结构全对**；硬错误 0 |
| 提示（需解释项） | "与简体相同" 144 条已逐条确认；"简体特征字" 1 条 = `languageNameZh`（故意） |
| 工具修正 | `arb_hant.py` 的简体特征字表原含「硬」「存」，二者**繁体同样这么写**，导致 52 条提示里 50 条是误报 → 已剔除并加注释 |

### 4.2 翻译时的判断（与直译不同、需留痕的地方）

| 键 | 简体 | 繁體 | 判断 |
|---|---|---|---|
| `commonQuality` | 清晰度 | 畫質 | 台湾说法 |
| `commonAscending` / `commonDescending` | 升序 / 降序 | 遞增 / 遞減 | 台湾说法 |
| `settingsAppearanceSdkTooLow` | 安卓版本过低… | Android 版本過低… | 台湾直接写 Android |
| `wallpaperScaleFit` / `Fill` | 适应 / 填充 | 符合 / 填滿 | 台湾说法 |
| `mediaInfoProfile` | 配置 | Profile | 与同文件「支援的 Profile / Level」统一 |
| `settingsAppearanceWallpaperActiveDesc` | 顶部栏 | 頂端列 | 台湾说法 |
| `fileSelectionExit` | 退出多选 | 結束多選 | 台湾说法 |
| `settingsFontPreviewSample` | `…；：“”（）【】…·` | 原样保留 | 这是**字形预览样本**，改成「」会改变演示的字形集，故不动 |
| `settingsPlayerPinchToZoomDesc` | 允许双指去缩小画面 | 允許雙指縮小畫面 | 原文「去」是病句，译文按语义写，未增删语义 |

---

## 5. 执行记录

| 日期 | 批次 | 结果 |
|---|---|---|
| 2026-10-05 | 1 `common*` | apply 94 通过 |
| 2026-10-05 | 2 `settings*` 前半 | apply 147 通过 |
| 2026-10-05 | 3 `settings*` 后半 | apply 147 通过 |
| 2026-10-05 | 4 `player*` 前半 | apply 148 通过 |
| 2026-10-05 | 5 `player*` 后半 | apply 147 通过 |
| 2026-10-05 | 6 `bili*` + `media*` | apply 172 通过 |
| 2026-10-05 | 7 `subtitle*` `danmaku*` `audio*` `decode*` | apply 130 通过 |
| 2026-10-05 | 8 网络/文件/下载 | apply 164 通过 |
| 2026-10-05 | 9 其余 | apply 130 通过 |
| 2026-10-05 | 收口 | `check` PASS / 硬错误 0 / 提示逐条解释完毕 |

工作文件：`tools/_hant_src1..9.txt`（取源）、`tools/_hant_batch1..9.json`（译文批次）、`tools/_hant_check_report.md`（门禁报告）。
