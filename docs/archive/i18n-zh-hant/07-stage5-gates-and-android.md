# 07 · 阶段 5：门禁登记与 Android 资源

> 本阶段只做两件事：**把新增的繁体长文文件登记进门禁白名单**（否则门禁必红）、**确认 Android 资源要不要动**（默认不动）。

---

## 1. 目标与产出

| 项 | 内容 |
|---|---|
| 目标 | 残留中文门禁恢复 0/0/0；未翻译清单为空；Android 侧明确"不改"或"改哪一条" |
| 产出 | ① `i18n_scan.py` 的 `GENERATED_SKIP` 加一项 ② `whitelist.json` 的 `files` 加一项 ③（条件性）`values-zh-rTW/strings.xml` |
| 前置 | 阶段 3 已建 `lib/l10n/legal_zh_hant.dart`；阶段 4 已重新生成 l10n |
| 门禁 | **G4**（未翻译清单 `{}`）+ **G5**（残留 0/0/0） |
| 预计耗时 | 半天 |

---

## 2. 步骤 1：`GENERATED_SKIP` 登记

文件：`docs/archive/i18n-migration-plan/tools/i18n_scan.py`，第 51-57 行的集合 `GENERATED_SKIP`（现有 5 项：`app_localizations.dart`、`app_localizations_zh.dart`、`app_localizations_en.dart`、`legal_zh.dart`、`legal_en.dart`）。

加一行：

```python
    "lib/l10n/legal_zh_hant.dart",
```

理由与 `legal_zh.dart` / `legal_en.dart` 相同：**生成物与"按语言拆的正文文件"里的中文是译文本身，不是待翻译的硬编码文案**。

---

## 3. 步骤 2：白名单登记

文件：`docs/archive/i18n-migration-plan/tools/whitelist.json`，`files` 数组（现有 7 项）追加：

```json
    {
      "path": "lib/l10n/legal_zh_hant.dart",
      "reason": "隐私政策/用户协议繁体正文（阶段 3 新建，按语言拆 Dart 文件、不进 ARB）：繁体汉字是译文本身，不是待翻译的硬编码文案"
    },
```

要点：

- `files` 项是**整文件豁免**，与行号无关，不会像 `lines` 项那样因为改动而"过期"；
- 两道保险（`GENERATED_SKIP` + `whitelist.json`）都加，与 `legal_zh.dart` 现状一致；
- **不要动 `lines` 里的行号项**：那些中文是数据/日志，与繁体无关。如果门禁报"白名单过期项"，说明**别处的行号漂移了**（第一轮踩过这个坑：截图相册名 1417 → 1454）→ **停下报告，不要自己改行号**。

---

## 4. 步骤 3：Android 资源（默认不动）

现状：

| 文件 | 内容 |
|---|---|
| `android/app/src/main/res/values/strings.xml` | 默认（中文）9 条，`app_name = 小喵Player`，240 汉字 |
| `android/app/src/main/res/values-en/strings.xml` | 英文 9 条 |

### 4.1 ⚠️ 方案的默认结论是错的（2026-10-05 实测修正）

原文写的"默认一个字都不改"，理由是"9 条里没有必须区分简繁的内容"。**实测推翻了这个前提**：
逐条看 `values/strings.xml`，**7 条含有简体专用字形**，而 `values/` 是**所有未匹配语言的回落**，
所以繁体用户会在这些**用户可见**位置看到简体：

| # | 资源名 | 现值（简体） | 繁体应为 |
|---|---|---|---|
| 1 | `app_name` | 小喵Player | **相同**（不动） |
| 2 | `background_playback_channel_name` | 听视频后台播放 | 聽影片背景播放 |
| 3 | `background_playback_channel_description` | 在后台继续播放视频音频 | 在背景繼續播放影片音訊 |
| 4 | `background_playback_title` | 听视频 | 聽影片 |
| 5 | `background_playback_text` | 正在后台播放 | 正在背景播放 |
| 6 | `storage_internal` | 内部存储 | 內部儲存 |
| 7 | `storage_sd_card` | SD 卡 | **相同**（不动，但与 #6 同文件） |
| 8 | `log_read_failed` | 读取日志失败：%1$s | 讀取日誌失敗：%1$s |
| 9 | `crash_dialog_message` | 应用遇到错误已停止运行\n日志已保存… | 應用程式發生錯誤已停止運作\n日誌已儲存… |

**影响面**（都是用户能看见的）：通知栏/通知渠道名、后台播放通知标题与正文、存储卷展示名、崩溃提示弹窗。
**所以这一项不是"可做可不做"，而是"不做就是繁体体验里的简体残留"** —— 需要用户拍板，见 §4.2。

### 4.2 待拍板：要不要补繁体 Android 资源 —— **已拍板：方案 A（2026-10-05）**

| 方案 | 内容 | 代价 | 覆盖 |
|---|---|---|---|
| **A（已采纳）** | 新建 `values-b+zh+Hant/strings.xml`（9 条，两条原样） | 1 个文件 + 白名单 1 条 + 走查 3 条用例 | 所有**脚本为 Hant** 的 zh 语言（台/港/澳），BCP-47 限定符，minSdk ≥ 21 可用 |
| B | A 再加 `values-zh-rTW/`（内容相同） | 2 个文件（内容重复） | 覆盖那些只上报地区、不上报脚本的老设备 |
| C | 不改 | 0 | **繁体用户在上述 9 处看到简体** |

**已按 A 执行**：`android/app/src/main/res/values-b+zh+Hant/strings.xml`（9 条，`app_name` 与 `SD 卡` 原样照抄），
并已登记进 `whitelist.json`。三份 `strings.xml`（`values` / `values-en` / `values-b+zh+Hant`）的**键集合完全一致（各 9 条）**。

> 注：原方案否掉 `values-b+zh+Hant` 的理由（"多一份资源多一份维护"）在这个场景下不成立——正因为**只有脚本这一个维度**，`values-b+zh+Hant` 比 `values-zh-rTW` 更贴"通用繁體"的拍板口径。
> 若阶段 7 走查发现某些老设备（只上报 `zh-TW` 地区、不上报脚本）仍落到简体，再补 `values-zh-rTW/`（方案 B），属可选加固。

---

## 5. 门禁

```powershell
# G4：未翻译清单必须为空
py -c "import io;print(io.open('l10n_untranslated.json',encoding='utf-8').read().strip())"

# G5：残留中文门禁（含 Android）
py "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --include-android
```

期望：

- G4 输出 `{}`；
- G5 输出 `residual: 0  expired whitelist: 0`，exit 0。

> ⚠️ **G5 会重写 `docs/archive/i18n-migration-plan/05-residual-chinese-report.md`**（这是它的正常行为，第一轮如此）。这个文件是入库文件，重写后内容会出现在用户的 `git diff` 里 —— 属**预期改动**，在阶段报告里说明一句即可；如果用户不想要这个 diff，用 `git checkout --` 还原它。

---

## 6. 常见坑

1. **忘了登记 → 门禁红**：`lib/l10n/legal_zh_hant.dart` 有 3500+ 汉字，不登记必然报 residual。
2. **不要为了过门禁去改扫描口径**（不要把整个 `lib/l10n/` 目录加进跳过、不要放宽 CJK 判定）—— 那是把门禁关掉，不是修问题。
3. **`whitelist.json` 是 JSON**：手工编辑注意逗号与括号，改完可用 `py -c "import json,io;json.load(io.open(r'docs/archive/i18n-migration-plan/tools/whitelist.json',encoding='utf-8'));print('ok')"` 验一下格式。
4. **`expired whitelist` 不为 0 → 报告**，不要自己猜行号往哪挪。

---

## 7. 完成标准

- [x] `GENERATED_SKIP` 加了 `lib/l10n/legal_zh_hant.dart`（顺带把上方注释里的 `legal_zh/legal_en` 更新为三份）
- [x] `whitelist.json` 的 `files` 加了 `lib/l10n/legal_zh_hant.dart`（JSON 格式有效，扫描器已正常读取）
- [x] G4：`l10n_untranslated.json` = `{}`
- [x] G5：`residual: 0  expired whitelist: 0`
- [x] **Android：已按方案 A 执行**（`values-b+zh+Hant/strings.xml` 9 条 + 白名单登记；三份资源键集合一致）

---

## 8. 执行记录

| 日期 | 结果 |
|---|---|
| 2026-10-05 | **阶段 5 主体完成**。① `i18n_scan.py` 的 `GENERATED_SKIP` 加 `lib/l10n/legal_zh_hant.dart`（并把注释里的长文文件列表补成三份）。② `whitelist.json` 的 `files` 加同一条（理由：繁体正文是译文本身）。③ G4：`l10n_untranslated.json` = `{}`。④ G5：`py ... i18n_scan.py residual --include-android` → **`residual: 0  expired whitelist: 0`**，exit 0（注意它会重写 `05-residual-chinese-report.md`，属预期改动）。 |
| 2026-10-05 | **发现方案错误（需用户拍板）**：`values/strings.xml` 9 条里 **7 条含简体专用字形**（通知渠道名/标题/正文、存储卷名、日志读取失败、崩溃弹窗），而 `values/` 是所有未匹配语言的回落 → 繁体用户会在这 7 处看到简体。方案原写的"没有必须区分简繁的内容"是**误判**。已在 §4.1/§4.2 记下实测清单与 A/B/C 三个方案，**暂不动 Android 资源，等用户决定**。 |
| 2026-10-05 | **用户拍板方案 A，已执行**：新建 `android/app/src/main/res/values-b+zh+Hant/strings.xml`（9 条；`app_name`、`SD 卡` 照抄，其余 7 条转繁体）；`whitelist.json` 的 `files` 加同一条（现共 9 项）。校验：三份 `strings.xml` 键集合完全一致（各 9 条）、whitelist JSON 有效、**G5 复跑仍 `residual: 0  expired whitelist: 0`**。新文件 EOL 归一为 CRLF。阶段 7 走查补 3 条 Android 资源用例（见 `09-stage7-device-walkthrough.md` §3.5）。 |
