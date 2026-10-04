# 06 · 遗留与待办（执行过程中累积，收口时必须处理）

> 本文件由执行 AI 维护：记录**执行过程中发现、但按用户拍板推迟**的事项。
> 与 `03-task-list.md`（逐文件勾选）互补：这里是"清单之外必须记住的事"。
>
> ⚠️ **读之前先看 §0**：本文写在执行过程中，§1 的「待办」与 §2 的「中间态」
> **绝大多数已在阶段 6–8 收口时处理完**；§0 是 2026-10-02 逐条回代码核对后的结果。

---

## 0. 收口后现状（2026-10-02 逐条核对）

> 核对方式：`i18n_scan.py residual / dupes`、`git show 7276793^:<文件>` 对比改造前原文、逐文件 grep 调用点。
> 结论：**§1 六项全部完成；§2 十四项中十项已完成、两项维持现状、两项另有结论**。

| 条目 | 原计划 | 现状（2026-10-02） |
|---|---|---|
| §1.1 / §1.2 ARB 同中文多键归并 / 键名修正 | 阶段 8 统一归并 | ✅ **已完成**：现只剩 **2 组 4 键**，且都是当时**故意保留**的（`commonPlay` vs `settingsGroupPlayback`；`commonSecondsValue`(int) vs `playerDelaySeconds`(String)）；9 处键名修正已落 |
| §1.3 全角标点 | 阶段 8 扩口径清零 | ✅ **已完成**：`residual --include-android --fullwidth` = 0 |
| §1.4 / §1.5 / §1.6 白名单与行豁免 | 阶段 6–8 维护 | ✅ **已完成**：白名单 **7 个整文件 + 35 条行豁免**，过期项 0 |
| §2.1 音轨回落提示 | 阶段 6 迁 | ✅ 已完成（`label_maps.audioFallbackReasonText`，`player_page.dart:503` 在用） |
| §2.2 缓存类别名 | 阶段 6 迁 | ✅ 已完成（`label_maps.cacheCategoryLabel`） |
| §2.3 两个页内枚举标签 | 阶段 4 已收口 | ✅ 已完成（页内私有映射 `_repeatModeLabel` / `_sleepPresetLabel`） |
| §2.4 8 个「文案生产」文件挪到阶段 6 | 阶段 6 | ✅ 已完成 |
| §2.5 相册名是否跟随语言 | **待用户确认** | ✅ **已拍板：保持中文**（2026-10）→「设计如此」 |
| §2.6 角标匹配键 | 阶段 5 已处理 | ✅ 维持原方案（匹配键保持中文 + 白名单行豁免） |
| §2.7 字面 `{name}` | 阶段 5 已落地 | ✅ 已完成 |
| §2.8 `BiliCoverImageProvider` 带 l10n | 阶段 5 已落地 | ✅ 已完成 |
| §2.9 码 + 参数 + UI 侧翻译 | 阶段 6 | ✅ 已完成（`utils/error_codes.dart` + `l10n/error_texts.dart`） |
| §2.10 默认弹幕服务器显示名 | 阶段 6 | ✅ 已完成（`label_maps.danmakuServerDisplayName`） |
| §2.11 无 UI 显示点的错误码 | 键保留备用 | ⏸ **维持现状**：界面本来就不显示这些原因，不是待办 |
| §2.12 阶段 6 顺带的结构性改动 | 真机验证时注意 | ✅ 改动已落地；**验证已移交** `docs/archive/i18n-regression-test-plan/`（355 条回归用例） |
| §2.13 长文落地 | 阶段 7 | ✅ 已完成；正文 Markdown 星号**已于 2026-10 修掉**（见 §0.1） |
| §2.14 Android 原生侧 | 用户打包核验 | ✅ **用户 2026-10 自测通过**（应用名 / 通知渠道名与描述 / 存储卷回退名 / 崩溃提示）；渠道名的卸载重装验证**用户明确不要求** |

### 0.1 收口后新发现并已修的问题（提交 `8227c21`，2026-10-02）

来源：回归扫描 `docs/archive/i18n-regression-test-plan/tools/_scan_regression.md`（29 条风险中的高/中危项）。

| # | 问题 | 修法 |
|---|---|---|
| R1 | 字幕下载设置项前缀 `'当前来源：'` 是**拼在字符串字面量里的中文**，英文界面中英混排（扫描口径抓不到） | 新增键 `subtitleCurrentSource` + 复用 `commonLabelWithColon` |
| R2 | 章节无标题时 `utils/chapter_utils.dart` 直接回中文「第 N 章」，英文界面拖进度条会显示中文 | 改纯数据 `ChapterHeading`（标题或序号），文案挪到 `label_maps.chapterHeadingLabel` + 新键 `playerChapterNumber` |
| R4 | 登录失败归因被合并：缺 SESSDATA 也报「Cookie 无效或已过期」 | 新增 `biliCookieMissingSessdata`、`biliLoginCredentialParseFailed`，恢复改造前的三条不同原因（zh 逐字一致） |
| 长文 | 中文正文 `**不会**` 的星号原样显示（§2.13 的「仍在的现状问题」） | 去掉 `legal_zh.dart` 正文两处星号（用户协议 + 隐私政策各一处） |

**两条要记住的教训**（本次核对新得出）：

1. **`residual = 0` 不等于没有残留**：R1/R2 都会进界面，却都不在扫描口径内 —— 盲区是「**拼在字符串字面量里的中文片段**」与「**utils 层产出的可展示文案**」（分层红线要求 utils 不 import l10n，于是文案被留在纯函数里）。英文界面全量走查不能省。
2. **迁移提交里混入过与 l10n 无关的行为改动**：`lib/utils/bili_image_url.dart:52-61`（非图床封面 URL 不再升 https / 不再剥 `@?/#`，由 `7276793` 带入，其单测在基线是**红的**、本提交才转绿）——不要默认「这批提交只有文案改动」。

**收口后状态**：`flutter analyze` 无问题、全量 `flutter test` 全绿、`residual` 三口径均 0、ARB **1276** 键（zh/en 对称）、`l10n_untranslated.json` = `{}`。

---

## 1. 用户已拍板：留到阶段 8 收口时统一处理

### 1.1 ARB 里「同一句中文分布在多个键」（阶段 4 结束时 17 组）

`02-implementation-plan.md` §1.10 要求「同一句中文必须复用同一个键」。阶段 0–3 结束时
ARB（zh 520 键）里约有 **10 组**相同中文分别定义在多个键上（例：`许可证书`×2、
`自动`×3、`绿色`/`黄色` 等颜色名×2、`默认`×2、`删除`×2 等）。成因：阶段 0–2 与
平行子代理各自按模块建键，未全局去重。

阶段 4 新增键 285 个（zh 805 键），又引入 **7 组**新的同中文重复（都是「通用的
`common*` 词」与「阶段 0–3 模块专用键」撞车）：

| 中文 | 阶段 4 新键（推荐保留） | 已有旧键（阶段 8 删） |
|---|---|---|
| 自定义 | `commonCustom` | `settingsAppearanceCustomColor` |
| 刷新 | `commonRefresh` | `settingsErrorLogRefresh` |
| 模糊 | `commonBlur` | `settingsWallpaperBlur` |
| 无 | `commonNone` | `subtitleBorderNone` |
| 播放 | `commonPlay` | `settingsGroupPlayback` |
| 删除 | `commonDelete` | `settingsErrorLogDelete` |
| 垂直位置 | `playerVerticalPosition` | `settingsWallpaperOffsetY` |

- **决策（用户 2026 夏，选 A）**：留到**阶段 8 收口**时统一归并（那时所有页面都迁完，
  一次改最省）。
- **处理方式（阶段 8 照做）**：逐组挑一个 `common*` 键作为唯一真源 → 把其余键的
  调用点改成它 → 从 zh/en 两个 ARB 删掉多余键 → `flutter gen-l10n` → `flutter analyze`
  → 全量 `flutter test`。**不要**只改键名不改调用点（会出现 undefined getter）。
- 已在阶段 1–3 先修好的 4 处（作为范例）：`重试`→`commonRetry`、`清除`→`commonClear`、
  `居中`→`commonCenter`、并删掉 `settingsLicenseRetry`/`settingsAppearanceClearWallpaper`/
  `settingsCacheClear`/`subtitleAlignCenter`。
- 阶段 4 已按 §1.10 直接复用的旧键（无需阶段 8 处理）：`硬解`→`decodeModeHwCopy`、
  `跳过片头/片尾`→`chapterSkipIntro/Outro`、`列表循环`→`loopModeLoopAll`、
  `音量增强`→`settingsPlayerVolumeBoost`、`听视频`→`playerActionListen`、
  9 档字重→`settingsFontWeight*`、`{value} 秒`→`commonSecondsValue`、
  12 个播放器动作名→`playerAction*`。

### 1.2 阶段 5 新增的同中文重复与「键名与语义不符」（阶段 8 一起收口）

阶段 5 新增键 332 个（zh 1137 键）。为守 §1.10「同中文必须复用」，**故意复用了**
几个语义上不贴切的旧键，阶段 8 建议改名（改名要同时动调用点）：

| 中文 | 阶段 5 复用的键 | 建议阶段 8 改名 |
|---|---|---|
| 确定删除「{name}」吗？ | `settingsErrorLogDeleteConfirm` | `commonDeleteConfirm` |
| 确定删除「{name}」吗？此操作不可撤销。 | `danmakuServerDeleteConfirm` | `commonDeleteConfirmIrreversible` |
| 采样率 | `settingsDecoderSampleRates` | `mediaInfoSampleRates`（或 `commonSampleRates`） |
| 语言 | `settingsGroupLanguage` | `commonLanguage` |
| 下载管理 | `settingsDownloadManager` | `downloadManagerTitle` |
| 视频下载 / 弹幕下载 / 字幕下载 | `settingsVideoDownload` 等 | `biliVideoDownloadTitle` 等 |
| 清晰度 | `playerQuality` | `commonQuality` |
| 重试 / 搜索 / 取消 / 保存 / 删除 / 关闭 / 返回 / 更多 / 全选… | `common*` | 无需改（就是通用词） |

另：阶段 5 有 8 组「同中文多键」新增（阶段 8 按 §1.1 的做法归并）：
`全部`（`commonAll` 唯一，无重复）、`未知`（`commonUnknown` 与
`subtitleUnknownSource` 不同中文，无重复）、`设置目录`/`未设置下载目录`
（`downloadSetDir`/`downloadNoDir` 唯一）——**实际新增重复为 0 组**
（阶段 5 全程按「先查旧键、同文案必复用」执行）。

### 1.3 全角标点不在扫描口径内（系统性缺口）

`i18n_scan.py` 的 CJK 判定是 `[\u4e00-\u9fff]`（汉字区），**不含全角标点**
（`（）：、；` 等 U+FFxx / U+3000 段）。所以：
- 只含全角标点的字面量不会被计入残留（例如 `file_operations_ui.dart` 里
  `'（${...}%）'`）；
- 英文界面下这些全角括号/冒号会原样出现（例：`已移动「X」到 Y：Z` 的 `：`
  留在 Dart 里，英文显示成 `Moved "X" to Y：Z`）。

阶段 5 已把**同一句里的汉字部分**全部迁走（含把 `（{percent}%）` 这种夹在
插值里的整句提成 `fileOpBytesProgress`），但**没有**单独为全角标点建键。
阶段 8 若要彻底清零：把 CJK 判定扩成 `[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]`
重扫一遍，再看剩多少（预计很少，且多为标点）。

### 1.4 阶段 6 新增的白名单条目（用户 2026 拍板：按「数据 / 文件名」处理，不翻译）

阶段 6 侦察时逐条确认这些中文**不是界面文案**，用户已拍板加白名单（`tools/whitelist.json`）：

| 位置 | 内容 | 理由 |
|---|---|---|
| `lib/utils/formatters.dart:24` | `小喵Player-…` | 红线 14：截图文件名不随语言变（此前竟漏在白名单外，被当成待迁 1 处） |
| `lib/utils/danmaku_local_file.dart:16` | `弹幕.xml` | 本地同名弹幕文件的**候选匹配名**（同列表另有 `danmaku.xml` 等 ASCII），翻译后匹配不到中文名文件 |
| `lib/models/network_connection.dart:133` | `未命名` | `fromJson` 里持久化字段 `name` 的兜底值，会被 `toJson` 写回 |
| `lib/services/download/download_task.dart` | `未命名` | `_sanitizeFileName` 写盘文件名兜底 |
| `lib/utils/wyzie_filename.dart:15` | `未命名` | 字幕落盘名 / 去重键兜底 |
| `lib/models/danmaku_server.dart:48` | `弹弹Play（默认）` | 内置默认服务器写入 prefs / 缓存的名字（**显示**走 `l10n.danmakuServerDefaultName`，见 2.10） |
| `lib/services/update/update_service.dart` | `_devBody`（326 字样例更新说明） | 开发/测试样例数据，只被 `test/update_dialog_test.dart` 渲染；生产真源是 GitHub Release 正文 |

`lib/utils/chapter_utils.dart` 等 5 个整文件豁免不变。

### 1.5 白名单口径修正：`danmaku_episode.dart` 整文件豁免 → 按行豁免（用户拍板）

`lib/utils/danmaku_episode.dart` 原先按整文件豁免（理由「集数正则」），但它同时有 2 条**给用户看的提示**（原 127/136 行「未能从文件名识别集数…」「未找到第 N 集…」，由网络弹幕集数面板显示）——整文件豁免把它们一起藏了起来，**哪个阶段都不会做**。用户 2026 拍板：纳入阶段 6。已做：
- 结果类型 `DanmakuEpisodeLocation.message` → `hint`（`DanmakuEpisodeLocateHint` 枚举，纯数据）；
- 两条提示走 `label_maps.danmakuEpisodeLocateHint` + ARB（zh 逐字不变）；
- 白名单：删整文件豁免，改为**行豁免**（正则那一行），理由写在条目里。

### 1.6 ARB 里「同中文、不同标点」的成对键（阶段 8 可归并）

阶段 6 为了**不改动界面文字**，对只在标点上不同的原句各建了一个键：
- `errorResponseParseFailed`（zh 全角冒号，弹弹Play 原句用 `：`）
- bili 侧原句用的是 ASCII 冒号 `响应解析失败: {error}` —— 已**统一到全角键**（唯一一处显示文案微调，1 个字符，无测试断言依赖）。

另有若干「同中文但语义不同」的键在阶段 8 一并归并（沿用 §1.1 的做法）。

---

## 2. 已知中间态（不是 bug，是分阶段的必然结果）

### 2.1 `audio_service.dart:369` 的回落提示仍是硬编码中文

阶段 1 把 `AudioTrack.displayTitle` 改成**纯数据**（无标题无语言时返回空串），
但 `audio_service.dart` 仍在拼 `'当前音轨无法播放，已自动切换到「${fallback.displayTitle}」'`。
→ 若某音轨既无标题也无语言，该 toast 会显示「」。**阶段 6 迁该文件时**一并改用
`label_maps.dart` 的 `audioTrackDisplayName(l10n, track)`（服务层拿不到 l10n，
按 §1.8 应把"轨道对象"透传给 UI 层，由 UI 拼文案）。

### 2.2 缓存类别名仍是中文

`cache_manager_service.dart` 的 `category.label`（"视频列表封面缩略图 / 网络弹幕缓存 /
哔哩封面缓存 / 其他缓存"）来自**服务层**，属阶段 6 的任务。
→ 英文界面下，缓存管理页的类别名、`settingsCacheClearCategoryTitle/Body`、
`settingsCacheCategoryCleared` 的插值仍是中文；
`settingsCacheClearAllBody` 里举例的两条类别名是**写死的英文**，阶段 6 迁服务层时
必须与之统一。

### 2.3 `AudioSleepPreset` / `AudioRepeatMode` 的标签没进 `label_maps.dart`（阶段 4 已收口，方式改了）

这两个枚举声明在**页面文件** `lib/pages/player/views/audio_player_panels.dart` 里，
阶段 4 已处理：**删掉枚举自带的 `label` 字段**（`audioRepeatSingle` 等键），
改为**在本文件内**加私有映射函数 `_repeatModeLabel(l10n, mode)` /
`_sleepPresetLabel(l10n, preset)`（表达式 switch，穷尽所有成员）。

为什么没放进 `label_maps.dart`：`label_maps.dart` 若 import 这个页面文件，
就成了 l10n → pages 的依赖（且与页面 import label_maps 形成环）。
§1.9 的约束是「`models/`/`utils/`/`services/` 不许 import l10n」——枚举本来就在 UI 层，
在本文件内映射不违反该约束。枚举名、成员顺序、icon/duration 值一律未动。

### 2.4 服务层/工具层的错误文案

`file_ops` / `webdav_client` / `player_diagnostics` / `build_info_service` /
`danmaku_search_store` / `wyzie_models` / `bilibili_user` / `danmaku_timeline`
这 8 个文件（用户拍板）已从阶段 1 挪到**阶段 6**——它们的中文是"给界面看的文案"，
要按 §1.8 改成「码 + 参数」、由 UI 层翻译，显示点在阶段 3–5 的页面里。

### 2.5 截图相册名 `albumPath: '小喵Player'` 保持不译（✅ 用户 2026-10 已拍板：保持中文）

`player_page.dart` / `player_portrait_page.dart` 的
`SaverGallery.saveImage(albumPath: '小喵Player')` 是**存进系统相册的相册名**。
阶段 4 把它进了白名单（不译），理由：截图文件名前缀按红线 13 固定为
`小喵Player-yyyy-MM-dd_HH-mm-ss.png`，相册名与文件名保持同一套命名才不会出现
「Meow Player 相册里装着 小喵Player-xxx.png」的错位。
**若要英文界面下相册名也变 Meow Player**：把这两处换成 `l10n.appTitle`
（`appTitle` 的 en 值就是 `Meow Player`）并从白名单删掉那 2 条行豁免即可，1 分钟改完。

> ✅ **2026-10 已拍板：保持中文**（用户原话「不用管，就用中文」）—— 上面那句「1 分钟改完」的方案**不再执行**；
> 相册名与截图文件名在两种语言下都保持 `小喵Player`，属「设计如此」，不算残留。
> （现有 3 处：`player_page.dart:1417`、`player_portrait_page.dart:694`、`bili_login_page.dart:169`。）

### 2.6 角标匹配键（阶段 5 已按同一方案处理）

`lib/widgets/bili_episode_tile.dart:76` 与阶段 4 的
`player_bili_playlist_panel.dart:208-210` 是同一份逻辑：`switch (badge)` 匹配的是
**B 站接口返回的角标原值**（`'会员'`/`'限免'`/`'预告'`，数据不是文案），
显示文案里 `'会员'` 那支本来就是 ASCII `'VIP'`。
→ 阶段 4/5 均按：匹配键保持中文（进 `whitelist.json` 行豁免）、
`限免`/`预告` 的显示走 `playerBiliFreeLimited`/`playerBiliPreview`、
`VIP` 保持字面量。

### 2.7 ARB 里写不出「字面花括号」（`{name}` 语法记号）

字幕来源的说明文案要显示 **字面** `{name}`（告诉用户接口地址里怎么占位）。
实测：
- 直接写 `{name}` → gen_l10n 当成占位符，生成 `String xxx(Object name)`；
- 按 ICU 惯例转义 `'{name}'` → **也不生效**，gen_l10n 仍当占位符，还把单引号
  当字面量输出（生成 `'… \'$name\' …'`）。

最终做法（阶段 5 落地）：ARB 里正常写占位符 `{placeholder}`，**调用点传字面量
`'{name}'`**：
```dart
l10n.subtitlePlaceholderHelp('{name}')
l10n.subtitleCustomSourceHelp('{name}')
```
这样 zh 输出与原文逐字一致，且 `'{name}'` 是纯 ASCII，扫描器不会当作待翻译文案。
（注意：`_CustomUrlDialog` 里那个示例 URL `'https://example.com/subtitle?name={name}'`
是纯 ASCII 的 Dart 字面量，**不进 ARB**，保持原样。）

### 2.8 `BiliCoverImageProvider` 构造多了 `l10n` 参数（阶段 5）

`bili_cover_image.dart` 的「哔哩封面不可用」提示在 `ImageProvider` 内部
（`_BiliCoverUnavailable.toString()`），链路拿不到 context。阶段 5 把
`AppLocalizations l10n` 加成了 `BiliCoverImageProvider` 的必填构造参数并透传给异常。
`l10n` **不参与** `operator ==` / `hashCode`（缓存键仍是 url + 解码尺寸），
调用点只有 `BiliCoverImage._build(context, …)` 一处。

### 2.9 阶段 6 的分层落地：码 + 参数 + UI 侧翻译（新增两个文件）

按 `02-implementation-plan.md` §1.8 落地：

- 新增 `lib/utils/error_codes.dart`（纯数据、无 Flutter / l10n 依赖）：`NetworkErrorCode` /
  `BiliApiErrorCode` / `DandanApiErrorCode` / `WyzieApiErrorCode` / `CustomSubtitleApiErrorCode` /
  `CustomSubtitleParseErrorCode` / `FileOpErrorCode` / `NetworkPathErrorCode` /
  `UpdateCheckErrorCode` / `CastErrorCode` / `LanMediaServerErrorCode`。
- 新增 `lib/l10n/error_texts.dart`（UI 侧翻译）：每个异常类型一个 `*ErrorText(l10n, e)`，
  外加统一入口 `serviceErrorText(l10n, Object error)`（§1.8 说的「集中用一个 errorText 翻译」）。
- 异常类型名**全部保留**，只把 `String message` 换成 `code + args`（`args` 键名与 ARB
  placeholder 一致）；`toString()` 变成 ASCII 调试串（`BiliApiException(networkFailed)`）。
- 「服务端自带 message」这类**第三方数据**不翻译：单独一个码（`serverMessage` /
  `smbServerMessage`），映射函数直接回传 `args['message']`。

### 2.10 默认弹幕服务器名：显示走 l10n，持久化与匹配逻辑不动（用户拍板）

`DanmakuServer.defaultName = '弹弹Play（默认）'` 仍是常量、仍会写进 prefs 与搜索缓存
（老用户零影响，白名单见 §1.4）；**界面显示**改成 `label_maps.danmakuServerDisplayName`
（`isDefault` → `l10n.danmakuServerDefaultName`）。服务层在 outcome 里对内置默认服务器
给**空串**，UI 侧渲染时回落 `l10n.danmakuServerDefaultName`；加载回执 toast 的拼装也从
服务层搬到 UI（`l10n.playerNetworkDanmakuLoadedManual` / `...Auto`）。

### 2.11 目前没有 UI 显示点的错误码（键已建，界面暂不显示）

这些中文原本就**到不了界面**（被上层 catch 吞掉或调用方只显示通用文案），阶段 6 仍按
「码 + 参数」改造，键保留备用：

- FTP `:149/:156`、WebDAV `:120/:124/:144/:145/:154/:159`：只走 `openStream` / `getFileSize`，
  被 `network_streaming_proxy.dart` 吞成 503 / 大小未知（只落调试日志）。
- `网络连接不存在` ×3：`network_playlist_source` / `network_subtitle_stream` 的调用方都
  catch 成空表。
- 登录链路 4 条（`loginQrFailed` / `loginCredentialParseFailed` / `loginCookieMissing` /
  `loginCookieInvalid` / `unknownError`）：登录页只显示已有通用 l10n，映射到同一批键。

### 2.12 阶段 6 顺带的类型与结构改动（阶段 8 与真机验证时注意）

| 位置 | 改动 |
|---|---|
| `lib/utils/loading_state.dart`、`lib/services/common_list_controller.dart` | `LoadError.message` / `error` 由 `String` 变 `Object`（承载异常对象，文案在 UI 层翻译） |
| `lib/utils/network_path.dart` | `ArgumentError`（中文消息）→ 新异常 `NetworkPathException(code)`；5 处测试断言 `throwsArgumentError` 改断言码 |
| `lib/services/cast/*` | `StateError('设备已离线')` / `FileSystemException('文件不存在')` → `CastException` / `LanMediaServerException`（带 path） |
| `lib/utils/dolby_vision_hint.dart` | **整个文件搬到 `lib/widgets/dolby_vision_hint.dart`**（utils 不许 import l10n），原文件删除；调用点只改 import |
| `lib/services/audio_service.dart` | `onAudioFallback` 第三参 `String reason` → `AudioFallbackReason` 枚举（文案在 `label_maps.audioFallbackReasonText`） |
| `lib/services/danmaku_service.dart` | `onNetworkDanmakuLoaded` 由「一句拼好的 String」改成「番剧/集名/服务器名(nullable) + 是否自动匹配」四参，UI 侧拼文案 |
| `lib/services/danmaku_search_store.dart` | `error`（拼好的中文）→ `errorKind`（`DanmakuSearchError`）+ `serverErrors` |
| `lib/services/danmaku_network_service.dart` | `DanmakuServerSearchOutcome.error` 由 `String` 变 `Object?`（异常对象）；默认服务器 `serverName` 传空串 |
| `lib/models/*` 删除的中文标签字段 | `EqualizerPreset.label`、`BiliUser.vipLabel`、`SubtitleEntry.displayName/displayLanguage`、`WyzieSubtitle.displayName/displayLanguage`、`BiliCoverSize.label`（**死字段**，全仓无人读） |
| `lib/models/bili_playlist.dart` | `BiliPlaylistItem.title` 不再造「第 N 集」，只回落空串；UI 用 `label_maps.biliPlaylistItemTitle` |
| `lib/services/media_scan_settings.dart` | 删掉已无消费点的 `FolderFilterMode.label` / `.subtitle` |
| `lib/models/wyzie_models.dart` | 删 `wyzieFallbackSources['all']`（UI 走 `l10n.commonAll`） |
| `lib/utils/custom_subtitle_parser.dart` | 默认 `sourceLabel` 由「自定义」→ ASCII `custom`，UI 映射回 `l10n.commonCustom` |
| `lib/utils/player_diagnostics.dart` | `formatDiagnosticSeconds` / `formatDiagnosticAvsync` / `diagnosticsWarnings` 三个含中文的纯函数**移到 `label_maps`**（`diagnosticSecondsText` / `diagnosticAvsyncText` / `diagnosticWarnings`），utils 只留数值格式化与阈值 |
| `lib/utils/danmaku_timeline.dart` | `formatDanmakuTimeOffset`（含「无偏移/延后/提前」）→ ASCII 的 `formatDanmakuOffsetDuration` + `label_maps.danmakuOffsetText` |
| `lib/utils/danmaku_episode.dart` | 见 §1.5 |
| `lib/services/build_info_service.dart` | `copyHint()` 返回 `BuildInfoCopyHint` 枚举，文案在关于页拼 |
| `lib/services/cache_manager_service.dart` | `CacheCategory` 只剩 `key`；一键清除弹窗正文 `settingsCacheClearAllBody` 增加 `{items}` 占位符（两条类别名由 UI 用同一套键渲染，见 §2.2 的收口） |
| `lib/services/update/update_service.dart` | 无更新说明时 `body` 给空串；弹窗侧回落 `l10n.updateNoNotes` |

### 2.13 阶段 7 长文（隐私政策 / 用户协议）的落地方式

按 `02-implementation-plan.md` §1.11 执行完毕：

- 正文按语言拆成 `lib/l10n/legal_zh.dart`（中文源文，由 `tools/_stage7_legal.py`
  从原 `lib/services/privacy_policy_content.dart` **逐字**生成，3418 汉字，与基线一致）
  与 `lib/l10n/legal_en.dart`（英文，AI 翻译）；**入口**是 `lib/l10n/legal.dart` 的
  `legalTextsFor(Locale)`（未知语言回落中文）。
- 原 `lib/services/privacy_policy_content.dart` 的 4 个常量已删除（**避免两处真源**），
  两个消费点（隐私弹窗、协议页）改为 `legalTextsFor(Localizations.localeOf(context))`。
- 弹窗的 4 条界面文案进 ARB（`legalAgreeCheckbox` / `legalDisagreeExit` /
  `legalAgreeWithCountdown` / `legalAgreeContinue`）；协议页标题复用既有键
  `settingsAboutUserAgreement`（同中文，§1.10）。
- 兜底测试 `test/legal_texts_test.dart`：断言 zh / en 两套的 4 段都非空、en 无残留汉字、
  未知语言回落中文。
- **~~仍在的现状问题~~ → 已修（2026-10，提交 `8227c21`）**：中文正文里的 `**不会**` 这类
  Markdown 星号在纯 `Text()` 下会原样显示（改造前就有）。已去掉 `legal_zh.dart` 正文两处
  星号（用户协议 + 隐私政策各一处）；英文侧本来就没有照抄星号（只在文件头注释里说明约定）。
  见 §0.1。
- 条款纪律：**改中文条款必须同步改英文**（两个文件头部都写了这条）。

### 2.14 阶段 8 收尾（Android 原生 + 重复键归并 + 全角标点）

**Android 原生**（`02-implementation-plan.md` §1.12；✅ **用户 2026-10 已自测通过**：应用名 / 通知渠道名与描述 / 存储卷回退名 / 崩溃提示，见 §0）：

- 新建 `android/app/src/main/res/values/strings.xml`（默认=中文）与 `values-en/strings.xml`，
  9 个键：`app_name`、`background_playback_channel_{name,description}`、
  `background_playback_{title,text}`、`storage_{internal,sd_card}`、`log_read_failed`、
  `crash_dialog_message`；应用名固定 zh=`小喵Player` / en=`Meow Player`（红线 15）。
- `AndroidManifest.xml` 的 `android:label` → `@string/app_name`。
- `BackgroundPlaybackService.kt`：渠道名/描述/标题/正文 4 处改 `getString`；
  **渠道 ID `moumou_background_playback` 未动**（改了会变成新渠道）。
- `MainActivity.kt`：存储卷回退名 2 处 + 「读取日志失败」1 处改 `getString`。
- `CrashHandler.kt`：**只迁了用户可见的那条 Toast**（`R.string.crash_dialog_message`）；
  其余 17 条是日志消息与**崩溃日志文件内容**（【时间】【设备型号】…），按红线 13
  保持中文并进白名单（用户 2026 拍板：这是与 §1.12.5「18 条表头改资源」的冲突，
  以红线 13 为准）。
- `VideoFsWalker.kt` 的 9 条全是日志（`Log.*` 与只被 `Log.w` 使用的 `capacityNote()`），
  保持中文并进白名单。
- ⚠️ 真机注意：通知渠道名只在**新装**时生效（Android 会缓存已创建渠道的名称与描述）；
  渠道 ID 不变 → 老用户升级后设置页里仍是旧名，属系统行为。
  （✅ 用户 2026-10：**此项不处理**，不作为验收项。）

**工具侧改动（阶段 8 新增口径）**：

| 项 | 说明 |
|---|---|
| `residual --include-android` | 现在真的会扫 `android/` 下的 `.kt` / `.xml`（此前 `iter_dart` 只认 `.dart`，该开关等于空转）；Kotlin 注释与 `Log.*`/`println`/`Timber.*` 日志调用参数区被排除 |
| `residual --fullwidth` | 口径扩成「汉字 + 全角标点」（06-遗留 §1.3 的缺口）；**默认口径不变**，阶段 0–7 的结论不受影响 |
| 白名单过期判定的作用域 | 没扫 android 就不判 android 条目；没开 `--fullwidth` 就不判「只含全角标点」的条目（否则默认口径下会报 17 条假过期） |

**全角标点收口**（用户拍板做）：`residual --include-android --fullwidth` 从 20 处 → **0**。
新增 7 个键（`commonListSeparator`、`commonLabelWithColon`、`mediaInfoStreamsGroupTitle`、
`settingsFontPreviewSample`、`folderActionDestWithTarget`、`fileOpItemIssue`、`fileOpItemFailed`），
并把 `custom_subtitle_parser` 的语言数组拼接由「、」改为 ASCII `, `（纯函数层拿不到 l10n，
对应测试同步改）。集数正则里的【】与 `capacityNote` 的「、」进白名单。

**重复键归并（§1.1）+ 键名修正（§1.2）**：`tools/_stage8_merge.py`

- 同中文多键从 **17 组（35 键）→ 2 组（4 键）**：
  1. 「播放」`commonPlay`('Play'，动作) vs `settingsGroupPlayback`('Playback'，设置分组标题)
     —— **故意不并**：中文同、语义与英文都不同；
  2. 「{value} 秒」`commonSecondsValue`（占位符 `int`）vs `playerDelaySeconds`（`String`，带正负号）
     —— **不能并**：占位符类型不同，并了调用点类型不匹配（`tools/_stage8_merge_fix.py` 记录了这个坑）。
- 归并 21 组（删 21 个旧键）、改名 9 个（§1.2 的清单）、新增 4 个通用键
  （`commonColorCyan/Green/Yellow`、`commonDefault`）；改写 17 个文件、39 处调用点。
- **教训**：判重不能只看「中文 + 占位符名」，还要看**占位符类型**（int / String）。

**阶段 8 结束时的数字**：全仓残留 **0**（三种口径都是 0）、白名单过期 **0**、
ARB **1272** 键（zh/en 对称）、`l10n_untranslated.json` = `{}`、
`flutter analyze` 无问题、全量 `flutter test` 全绿（+1817 ~13）。

> 这是**阶段 8 当时**的数字。收口后（2026-10-02）现为 **1276** 键、全量测试 **1816** 通过
> （删掉 `chapterNumberFallbackLabel` 那条已无对应 API 的测试 → 少 1 条），详见 §0。

---

## 3. 工具侧的口径（执行时改过，收口时注意）

| 项 | 现状 |
|---|---|
| 日志不算残留 | `tools/i18n_scan.py` 的 `LOG_CALL` 认 `debugPrint`/`print`/`debugPrintStack`/`developer.log`/`appendDartLog`/`CrashLogService.appendDartLog`（含多行调用）。全仓 58 处中文日志被排除 |
| 生成物跳过 | `GENERATED_SKIP`：`lib/l10n/app_localizations*.dart`、`lib/l10n/legal_zh.dart`、`legal_en.dart` 不参与任何统计/门禁 |
| 白名单 | 整文件豁免 6 个（生成物/正文常量/关键词表）；行豁免 7 条：`ftp_client.dart:287`（GBK 解码）、阶段 4 新增 `player_page.dart:1406` / `player_portrait_page.dart:688`（截图相册名）、`player_bili_playlist_panel.dart:208/209/210`（B 站角标匹配键）。行号一变就会报「过期项」 |
| 阶段归属 | 加了 `PHASE6_FILES`：8 个"文案生产"文件从阶段 1 挪到阶段 6（见 2.4） |
| 新增测试文件 | `test/language_picker_test.dart`、`test/app_smoke_test.dart`（AI 追加，已登记进 `NEW_FILE_TASKS`）|
| 清单口径 | `scan_files()`（`tasks` 用）阶段 4 起也认白名单：整文件豁免不再计为任务文件、行豁免不再计入「N 处」。修正前 `tasks` 会把 4 个整文件豁免（字幕语言/自动匹配/集数正则/章节关键词表）与 5 条行豁免算成待办（89 文件 → 82 文件）|
| 阶段 4 键表 | `tools/_stage4_arb.py`（285 键的 zh/en/描述/占位符表，可重跑：先 `git checkout -- lib/l10n/app_*.arb` 再跑，最后必须 `flutter gen-l10n`）；`tools/_stage4_keys.md` 为生成的中英对照 |
| 阶段 5 工具 | `_stage5_arb.py`（332 键表，同上可重跑）、`_stage5_groups.py`（把 `05-residual-chinese-report.md` 按 A–D/M 分组并给出「原文 → 建议调用」，含人工 `OVERRIDE` 表）、`_stage5_keys.md`（中英对照）、`_stage5_verify.py`（新增键是否有调用点）。注意 `_stage5_groups.py` 的匹配器有个已知坑：`\$(\w+)` 在 Python 里会把紧随其后的汉字也吃进 `\w`（`$label链接待接入`），这类行必须写进 `OVERRIDE` |
| 白名单（阶段 5 后） | 整文件 6 个；行豁免共 **10** 条：`ftp_client.dart:287`；截图相册名 3 处（`player_page.dart:1406`、`player_portrait_page.dart:688`、`bili_login_page.dart:169`）；B 站角标匹配键 6 条（`player_bili_playlist_panel.dart:208/209/210`、`bili_episode_tile.dart:81/82/83`）|
| 白名单（阶段 6 后） | 整文件 **5** 个（`danmaku_episode.dart` 改为按行豁免）；行豁免 **17** 条 = 原 10 条（行号按阶段 6 改动更新：`ftp_client.dart:311`、相册名 `player_page.dart:1417` / `player_portrait_page.dart:694` / `bili_login_page.dart:169`、角标键 `player_bili_playlist_panel.dart:209/210/211` + `bili_episode_tile.dart:81/82/83`）+ 新增 7 条数据/文件名（`formatters.dart:24`、`danmaku_local_file.dart:16`、`network_connection.dart:133`、`danmaku_server.dart:48`、`wyzie_filename.dart:15`、`download_task.dart:605`、`update_service.dart:166`）|
| 阶段 6 键表 | `tools/_stage6_arb.py`（139 键）+ `tools/_stage6_arb2.py`（4 键：弹幕回执 2 + 拾遗 2），两者都**只新增**、可反复运行；`tools/_stage6_verify.py` 直接 import 键表核对「键是否都有调用点」。跑完键表**必须** `flutter gen-l10n` |
| 阶段 6 后的残留 | 全仓残留 **9** 条，全部是阶段 7 的长文（`privacy_policy_content.dart` 4 + `privacy_policy_dialog.dart` 4 + `privacy_policy_page.dart` 1）；`lib/models`、`lib/utils` 已 0，`lib/services` 只剩阶段 7 那 4 条 |
| 阶段 7 工具 | `tools/_stage7_legal.py`（从 `privacy_policy_content.dart` **逐字**生成 `legal_zh.dart`，3418 汉字与基线一致，可反复运行）、`tools/_stage7_arb.py`（弹窗 4 键，只新增）、`tools/_stage7_verify.py`（核对 zh/en 四段齐全、英文 0 汉字、**段落数与小节数一一对应**、无 Markdown 星号残留）|
| 白名单（阶段 7 后） | 整文件 **6** 个（新增 `lib/l10n/legal_en.dart`，与 `legal_zh.dart` 一样属「某一种语言的正文常量」而不是待翻译文案）；行豁免 **17** 条不变；**全仓残留 0、白名单过期 0** |

## 4. 阶段收口时的硬经验（踩过坑）

1. **改 ARB 必须紧跟 `flutter gen-l10n`**，否则调用点全部 `undefined_getter`（编译不过）。
   子代理作业顺序因此固定为：**先写全部 ARB 键 → gen-l10n → 再改 Dart**。
2. **`initState` 里不许查 InheritedWidget**：`AppLocalizations.of(context)` 不能出现在
   `initState` 直接/间接调用的异步方法开头（会在 debug 下断言失败、页面永远 loading）。
   正解：只存状态（如 `bool _failed`），文案在 `build` 里取；确实要文案就 `didChangeDependencies`。
3. **需要在「首帧之前」就有文案时用 `didChangeDependencies` + 一次性标志**：
   阶段 4 的字幕延迟面板要把 `+0.5 秒` 这种带单位文本写进 `TextEditingController`
   的初值，而 `initState` 取不到 l10n → 改在 `didChangeDependencies` 里写一次
   （`if (_inputInitialized) return;`），行为与原先一致。
4. **ARB 占位符声明成 `String` 后，调用点不能直接传 `Object`/`int`/`String?`**：
   `catch (e)` 的 `e` 是 `Object`、端口号是 `int`、`result.errorMessage` 是 `String?`，
   直接传会报 `argument_type_not_assignable`（gen_l10n 只支持
   `String/int/double/num/DateTime`）。正解：调用点写 `'$e'` / `'$def'` /
   `'${result.errorMessage}'`——显示文本与原先的插值完全一致。
   阶段 5 共踩到 4 处（account_edit/network_browser/cast_device_dialog）。
5. **相邻字符串字面量会被当成一条文案**：`'按${fieldLabel}' '${orderLabel}'`
   实际输出「按名称升序」。阶段 5 因此把 `networkSortByPrefix`（只覆盖 `按{field}`）
   换成 `networkSortByBoth`（`按{field}{order}` / en `{field} {order}`）——
   **子代理按报告里被截断的单行字面量建键时，必须回看源码确认是否还有相邻片段**。
6. **顶层函数/无 context 的私有方法要加 `AppLocalizations l10n` 参数时，先 grep
   `test/`**：`buildFileSelectionAppBar` 被 `test/file_operations_ui_test.dart` 直接调用，
   加参数会让该测试**编译不过**（不是断言失败）。阶段 5 同步改了该测试的 pump 包装
   （Builder + 夹具三件套 + `AppLocalizations.of(context)`）。
7. **阶段 6 经验（服务层改造）**
   - **文件所有权必须互斥**：跨文件重构（异常签名一变、所有 UI 显示点同时红）只能靠
     分组并行推进，但**同一个文件被两个组同时改会丢改动**。阶段 6 的分组因此按文件
     划分（`player_page.dart` 一度同时落在 A/C 两组，靠消息重新分派才避免）。
   - **改异常消息 = 同时动 5 处**：异常类构造、抛出点、UI 显示点、错误码表、测试断言。
     只改前两处必然编译不过。
   - **String 错误管道要一起改类型**：`LoadError.message` / `CommonListController.error`
     原本是 `String`，服务层出码后必须变 `Object`（承载异常对象），否则页面无法翻译。
   - **「服务端 message 优先」的分支要拆成两个码**（`serverMessage` 透传第三方数据 /
     `serverCodeFailed` 走 l10n），否则英文界面会显示服务端返回的中文。
   - **白名单行号会漂移**：改完任何被行豁免的文件都要重跑 `residual` 看「过期项」并更新行号
     （阶段 6 踩到 `ftp_client.dart:287 → 311`）。整文件豁免若掩盖了真文案（如
     `danmaku_episode.dart` 的两条提示），要按行拆分（见 §1.5）。
   - **生成脚本被 import 时不能有模块级副作用**：`_stage6_arb*.py` 顶部原本执行
     `sys.stdout = io.TextIOWrapper(sys.stdout.buffer, ...)`，被 `_stage6_verify.py`
     import 时会把底层 buffer 关掉（`ValueError: I/O operation on closed file`）→
     把 stdout 包装移进 `if __name__ == '__main__':`。
   - **键表用 import 复用而不是解析 Markdown**：`tools/_stage6_verify.py` 直接
     `import _stage6_arb` 拿键名，比从报告里正则捞更可靠（列出「无调用点」的键）。

