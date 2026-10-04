# 07 · 遗留与待办（执行过程中累积）

> 本文件由**执行测试的 AI** 维护：未验证项、阻塞、已修缺陷、素材缺口全部登记在这里。
> 与 `03-测试用例清单.md`（逐条勾选）互补：这里是「用例之外必须记住的事」。
> 规则：**只允许追加与更新状态，不许删除历史条目**（用户要靠它看全过程）。

---

## 1. 开工前已知的待验证项（上一轮迁移带过来的，必须在本轮有结论）

| # | 事项 | 为什么必须验 | 对应阶段 | 状态 |
|---|---|---|---|---|
| 1 | **Android 原生侧 4 处文案**：应用名（zh=`小喵Player`/en=`Meow Player`）、后台播放通知渠道名/描述/标题/正文、存储卷回退名（内部存储/SD 卡）、崩溃提示 Toast | 迁移期间**按红线没编译**，只做了静态核对 | 阶段 7 + 阶段 3（后台播放） | **已验证**（用户 2026-10 自测通过）；测试 AI 只需在回归时抽查，不必重复深挖 |
| 2 | **通知渠道名只在全新安装生效** | Android 缓存已创建渠道的名称；老渠道升级后仍是旧名（系统行为，不算缺陷） | 阶段 7 | **用户已明确不处理**（2026-10：「无所谓不用管」）→ 不作为验收项；测试 AI 不要为它卸载重装 |
| 3 | **`02-实施方案.md` §3.3 的 17 项人工验收清单** | 原本「阶段 8 前必须逐项过」，实际只过了局部 | 分散在各阶段 | 已转化为本方案的 355 条用例，按阶段执行 |
| 4 | 中文正文里的 `**` 星号原样显示 | 改造前就有；英文侧没有照抄星号 | 阶段 1（长文） | **已修**（随 `8227c21` 提交）：`legal_zh.dart` 正文两处星号已去掉；现在中英正文都看不到 `**` |
| 5 | 截图**相册名** `小喵Player` 是否要跟随语言 | 迁移时进了白名单（与文件名同套命名） | 阶段 3（截图） | **用户已拍板（2026-10）：保持中文**，列为「设计如此」（`04-数据基线.md` §4.2 第 4 条） |
| 6 | 后台播放前台服务通知（听视频）在双语下的标题/正文 | 走 Android 资源（`values`/`values-en`），只在真机可见 | 阶段 3 + 7 | **阶段 3 已随 `T3-PLR-029` 复核通过**（2026-10-04，真机；通知标题/正文随语言正确）。渠道名按 `§1.2` 不处理 |
| 7 | 「无 UI 显示点」的错误码链路（FTP/WebDAV 的 5 处、`网络连接不存在` ×3、登录链路 4 条） | 迁移时这些中文本来就被上层吞掉，界面看不到；本轮**无法从界面验证** | 阶段 5/6 | 待确认（拟记「不可测」+ 理由） |
| 8 | 全角标点收口（`residual --fullwidth` 从 20 → 0） | 依赖脚本口径；界面表现（英文下是否还有全角标点）要目视 | 阶段 7 | 待验证 |
| 9 | B 站角标匹配键（`会员`/`限免`/`预告`）仍为中文 | 那是接口数据不是文案；要确认显示文案正确 | 阶段 6 | 待验证 |
| 10 | `未命名` 兜底（账户名/下载文件名/字幕文件名） | 兜底值是中文，界面显示走 l10n；要确认英文界面下显示正确 | 阶段 5/6 | 待验证 |

### 1.1 回归风险扫描已定向找出的问题（**本轮必须逐条给结论**，来源 `tools/_scan_regression.md`）

> 这份清单是**在开工前**用只读代码扫描得到的：**29 条风险（高 2 / 中 6 / 低 21）**+ 11 条结构性隐患 + **2 处确认的硬编码中文残留**；另核对了 16 类「明确不受影响」的改动（用于给测试减负，见 `_scan_regression.md` §3）。
> 其中带「疑似缺陷」的条目，本轮的结论必须是「确认 / 排除」，不能只写「看过」——对应用例见 `03-测试用例清单.md` 附录 B。

| # | 事项 | 位置 | 性质 | 对应用例 | 状态 |
|---|---|---|---|---|---|
| R1 | **「当前来源：」中文残留**（英文界面中英混排） | `lib/pages/subtitle/subtitle_download_page.dart:378` | **确认缺陷 → 已修并提交（`8227c21`）**：新增 `subtitleCurrentSource` 键 + 复用 `commonLabelWithColon` | `T7-I18N-107` | 已修，待复核 |
| R2 | **章节无标题时回退文案「第 N 章」仍中文** | `lib/utils/chapter_utils.dart:196` → `player_page.dart:3928` / `player_portrait_page.dart:2532` | **确认缺陷 → 已修并提交（`8227c21`）**：`chapter_utils` 改为回「标题或序号」纯数据（`ChapterHeading`），文案挪到 `label_maps.chapterHeadingLabel` | `T3-PLR-123` | 已修，待复核 |
| R3 | 网络弹幕「加载成功」toast 丢了「已加载弹幕：」前缀，只剩「番剧 · 集（来源）」 | `player_page.dart:526-530`、`player_portrait_page.dart:471-475`；ARB `playerNetworkDanmakuLoadedManual/Auto` | 疑似回归（可读性） | `T3-PLR-122` | 待验证 |
| R4 | 登录失败归因合并：缺 SESSDATA 被报成「Cookie 无效或已过期」 | `lib/l10n/error_texts.dart:129-134`；抛出点 `bili_account.dart:124/133` | **确认缺陷 → 已修并提交（`8227c21`）**：新增 `biliCookieMissingSessdata`、`biliLoginCredentialParseFailed` 两键，恢复与改造前逐字一致的三条不同原因 | `T6-BILI-115` | 已修，待复核 |
| R5 | 旧下载任务的失败原因丢失（`error` → `errorCode`+`errorArgs`，旧键被静默忽略） | `lib/services/download/download_task.dart:129-146/189-203` | 疑似回归（升级场景丢原因，不崩） | `T6-DL-110` | 待验证 |
| R6 | 非图床封面 URL 不再被规整（**与 l10n 无关**，由 `7276793` 混入）→ 缓存键变化、可能重复下载 | `lib/utils/bili_image_url.dart:52-61`、`bili_cover_image.dart:84-90` | 行为变化（需确认是修好还是回归） | `T6-BILI-113` | 待验证 |
| R7 | 英文侧「亿/万」直译成 `1.2 ten thousand` | `app_en.arb:828-829`；`bili_season_page.dart:369-377` | 翻译质量问题（英文界面） | `T6-BILI-114` | 待验证 |
| R8 | 播放设置·解码说明英文分号后缺空格（两段 l10n 直接相邻拼接） | `player_settings_page.dart:388-389`；`app_en.arb:255-256` | 排版缺陷（英文界面） | `T7-I18N-108` | 待验证 |
| R9 | 异常 `toString()` 由中文文案变 `类名(错误码)`：凡未走 `serviceErrorText` 的兜底路径会露出类名 | 定义 9 处；兜底 `error_texts.dart:40` | **可达性未确认** | `T3-PLR-124`、`T6-DL-111` | 待验证 |
| R10 | `error_texts.dart:215` 对 `args['reason']` 做 `as` 强转，畸形 args 会在错误分支再抛 TypeError | `lib/l10n/error_texts.dart:215` | **可达性未确认** | `T4-SUB-111` | 待验证 |
| R11 | 封面失败占位文案可能带旧语言（缓存键不含语言，`未确认`） | `bili_cover_image.dart:131-134/167/173/190-199` | **未确认** | `T7-I18N-109` | 待验证 |
| R12 | 取消判定改异常标记位：新增取消路径若忘记置位，会被计入「失败项」 | `file_operations_service.dart:11-26/231/312`；`folder_actions.dart:262/279/287/415` | 已核对现有两处等价，防回归 | `T2-HOME-117` | 待验证 |
| R13 | `LoadError`/`CommonListController` 错误对象化：断网错误提示是否仍是可读句 | `loading_state.dart:26/38/57`、`common_list_controller.dart:43/73/83/168` | 定向核查 | `T6-BILI-116` | 待验证 |
| R14 | 默认弹幕服务器在服务层用空串/null → **日志行**变成 `[]`（排障可读性下降，界面已兜底） | `danmaku_network_service.dart:166…229` | 低风险，定向核查 | `T4-DMK-112` | 待验证 |
| R15 | 枚举/模型删除 `label` 字段、主题色名改下标对齐 → **老存档逐项读回**是否正常（顺序错不报错、只会静默错名） | `label_maps.dart:51-76` vs `theme_controller.dart:59-84` 等 | 定向核查（升级场景） | `T7-I18N-110` | 待验证 |
| R16 | 同一键服务两个语义：`commonColorCyan/Green`（主题色 vs 字幕预设色）、`commonPlay`（分组标题 vs 按钮）、`decodeModeHwCopy/Sw`（档位 vs 行标/筛选） | `label_maps.dart:57/58/350-352`、`app_en.arb:497` | 语义隐患：英文可能词不达意 | `T7-I18N-111` | 待验证 |
| R17 | 「空串 = 由 UI 兜底」隐式契约：`SubtitleTrack/AudioTrack/BiliPlaylistItem/SubtitleEntry/WyzieSubtitle` 的展示名可能返回空串，漏兜底即**界面空白**（不崩） | `models/*` + `label_maps.dart` | 定向核查 | `T4-SUB-112` | 待验证 |
| R18 | 按 id/hex 映射的三张表在未知值上「原样回显」：英文界面可能直接显示 ASCII id（如 wyzie 来源键 `bravo`、未知主题色 hex） | `label_maps.dart:347-359/515-524/539-546` | 定向核查 | `T7-I18N-112` | 待验证 |
| R19 | 应用名/通知/存储卷名/崩溃提示**跟随系统语言**而非 App 内语言（详见下方 §5 阻塞） | `AndroidManifest.xml:27`、`res/values{,-en}/strings.xml`、`BackgroundPlaybackService.kt:36/54/67`、`MainActivity.kt:916/1552`、`CrashHandler.kt:139` | **用户 2026-10 已拍板：接受**（记入 `04-数据基线.md` §4.2 第 14 条「设计如此」） | `T7-SYS-105` | 已拍板，只记录现象，不算缺陷 |

**扫描口径的两个重要提醒**（写进 `04-数据基线.md` §5）：

1. `residual = 0` **不能证明没有残留**：确认的 R1/R2 两处中文都进了界面，却不在扫描口径内 —— 盲区是「**拼在字符串字面量里的中文片段**」与「**utils 层返回的可展示文案**」。所以英文全量走查（`T7-I18N-*`）是**必做**，不能只看脚本。
2. **风险 6（封面 URL 规整）与 l10n 无关**，是迁移提交里混入的行为改动：它的测试在基线是**红的**、本次才转绿。这类「混入改动」正是本轮回归最该盯的东西。

---

## 2. 缺陷登记（本阶段新增，由 `06-缺陷与汇报模板.md` §1 的缺陷单汇总）

| ID | 阶段 | 标题 | 级别 | 是否回归 | 状态 | 证据 |
|---|---|---|---|---|---|---|
| `DEF-2-01` | 2 | 深层路径下的 `.nomedia` / 隐藏目录扫不到（浅层正常） | P2 | **否**（改造前老限制，来自 `0b5e233`） | **已修，待重编译验证** | 用户实测 2026-10-04（口述，未截图）；详见 §11.2 |
| `DEF-2-02` | 2 | **在线（http/https）播放全部失败**：`demuxer-lavf-o` 的协议白名单被自己切碎成 `udp` + mbedTLS 无 CA 证书库 | P1 | **否**（改造前 `0428007` 引入，与 l10n 无关） | **已修，模拟器实测通过** | 修复后 https m3u8 正常播放（时长 `24:17`、网速 600–900 KB/s）；详见 §11.3 |
| `DEF-3-01` | 3 | 英文下听视频「定时关闭」最右侧胶囊（`After current track`）超出 44px | P2 | **否**（英文文案长度问题，改造前无英文界面） | **已修并推送（`0c491bf`），用户 2026-10-04 实测通过** | 用户实测 2026-10-04（口述）；详见 §12.2 |
| `DEF-3-02` | 3 | 外部音轨移除后**不落回内嵌音轨**，变成「没选中任何音轨」（mpv 把 `aid` 置成 `no`） | P2 | **否**（音轨逻辑来自改造前，与 l10n 无关） | **已修并推送（`0c491bf`），用户 2026-10-04 实测通过** | 用户实测 2026-10-04（口述）；详见 §12.2 |
| `DEF-3-03` | 3 | 播放设置「双指缩小视频」副标题「双指缩放画面」与实际行为不符（该开关只放开 0.75 倍缩小下限） | P3 | **否**（文案描述问题） | **已修并推送（`0c491bf`），用户 2026-10-04 实测通过** | 用户实测 2026-10-04（口述）；详见 §12.2 |
| `DEF-3-04` | 3 | **反向立体声 / 音量标准化 / 动态范围压缩 / 低音增强 / 虚拟环绕全部无效**：`Option af: item 'dynaudnorm' isn't supported`、`Audio filter initialized failed`；开了之后还会「之后每个视频都没声音」（issue #8） | P1 | **否**（内核滤镜白名单来自改造前，与 l10n 无关） | **已修复并推送**（App 兜底 `0c491bf` + 新内核产物 `8c6a931`；内核 `caa8be1` / CI run #16 success），**用户 2026-10-04 实测通过** | 见 §12.3；证据：新旧 `libmpv.so` 的 `ff_af_*` 符号对比（1 个 → 6 个） |
| `DEF-4-01` | 4 | **本地弹幕导入失效**：Android 16 走自建选择器，点弹幕文件后毫无反应、弹幕也没导入（无任何提示） | P1 | **是**（l10n 迁移把 `AppLocalizations.of(context)` 提到了 await **之前**；改造前是「先导入 → 再判 `context.mounted` → 才用 context」，所以老代码能正常导入、只是不弹提示） | **已修并推送（`3f90e50`），用户 2026-10-04 重编复测通过** | 新增回归测试（未修复时必失败，报 `Looking up a deactivated widget's ancestor is unsafe.` 且导入回调根本没执行）；详见 §13.1 |

---

## 3. 未验证登记（`NV-*`）

| 用例 ID | 原因类别 | 缺什么（素材 ID） | 补齐后能否补测 | 已做的部分 |
|---|---|---|---|---|
| `T1-SYS-014` | 需改代码 / 装特殊包才能真造崩溃 | M17 | 能（用户若提供崩溃入口或允许临时注入） | 阶段 1 按 M17「随便你」评估后放弃：收益低、会污染错误日志页 |
| `T1-SYS-015` | 需构造「读日志目录权限异常」 | — | 不能（模拟器上无法稳定构造该权限态） | 未做 |
| `T1-SYS-111` | 需造 51 个崩溃日志文件 | M17 | 不能（同上，且会污染错误日志页） | 未做 |

> **2026-10-04 更新（阶段 7 收口）**：`T1-SYS-014`（崩溃提示 Toast）与 `T1-SYS-015`（读日志失败提示）的主体，
> 分别由阶段 7 的 `T7-SYS-006`（崩溃 Toast 与崩溃日志）、`T7-SYS-008`（读取日志失败提示）覆盖，用户实测通过 →
> **已从本表移出**（留痕见 §3.1）。至此全轮只剩 `T1-SYS-111` 一条未验证。

> **2026-10-04 更新**：`T5-CAST-001` / `002` / `003` / `007` / `102` 曾因「本机没有可被发现的 DLNA 渲染器（M12）」登记为未验证；
> 用户随后实测这 5 条**全部通过** → 已移出本表（不再计入未验证），仅在此留痕，见 §3.1 与 §14.2。

### 3.1 曾登记、后补测通过（留痕，**不计入未验证**）

| 用例 ID | 原登记原因 | 补测结果 |
|---|---|---|
| `T1-SYS-014` | 需改代码 / 装特殊包才能真造崩溃（M17） | **已复核通过**：主体由阶段 7 的 `T7-SYS-006` 覆盖（2026-10-04，用户实测） |
| `T1-SYS-015` | 需构造「读日志目录权限异常」 | **已复核通过**：主体由阶段 7 的 `T7-SYS-008` 覆盖（同上） |
| `T5-CAST-001` | 环境不具备：局域网内没有可被发现的 DLNA 渲染器（M12） | **已补测通过**（2026-10-04，用户实测） |
| `T5-CAST-002` | 同上 | **已补测通过** |
| `T5-CAST-003` | 同上 | **已补测通过** |
| `T5-CAST-007` | 同上（英文下重走 001–003） | **已补测通过** |
| `T5-CAST-102` | 同上（只列 MediaRenderer） | **已补测通过** |

---

## 4. 已修缺陷（按 `01-执行协议.md` §1.3 修的）

| 缺陷 ID | 改了哪些文件 | 改动摘要 | 验证方式 | 是否已获用户允许提交 |
|---|---|---|---|---|
| R1 | `lib/l10n/app_zh.arb`（+`app_en.arb` + 生成物）、`lib/pages/subtitle/subtitle_download_page.dart` | 新增键 `subtitleCurrentSource`（当前来源 / Current source），前缀改用 `commonLabelWithColon`；中文渲染逐字不变 | `flutter analyze` 无问题；`flutter test test/subtitle_download_page_test.dart` 通过 | 已提交（`8227c21`） |
| R2 | `lib/utils/chapter_utils.dart`、`lib/services/chapter_tracker.dart`、`lib/l10n/label_maps.dart`（+ARB + 生成物）、`lib/pages/player/player_page.dart`、`lib/pages/player/player_portrait_page.dart`、`test/chapter_utils_test.dart`、`lib/pages/player/views/player_thumbnail_preview.dart`、`test/player_thumbnail_preview_test.dart` | `chapterTitleAt(String?)` → `chapterHeadingAt(ChapterHeading?)`：utils 只回「真实标题」或「回退序号」，`label_maps.chapterHeadingLabel` 负责文案（`playerChapterNumber` = 第 {number} 章 / Chapter {number}）；删除 `chapterNumberFallbackLabel` | `flutter analyze` 无问题；全量 `flutter test` 通过（1816 通过 / 13 跳过）；三种口径 `residual` 均为 0 | 已提交（`8227c21`） |
| R4 | `lib/l10n/app_zh.arb`（+`app_en.arb` + 生成物）、`lib/l10n/error_texts.dart` | 新增 `biliCookieMissingSessdata`（Cookie 缺少 SESSDATA，无法登录 / …has no SESSDATA）、`biliLoginCredentialParseFailed`（登录凭证解析失败（缺少 SESSDATA） / …no SESSDATA），把 `loginCookieMissing`、`loginCredentialParseFailed` 从「无效或已过期」「登录失败，请重试」改回各自的原始原因（**zh 与改造前逐字一致**） | `flutter analyze` 无问题；全量 `flutter test` 通过；`residual` 三口径为 0 | 已提交（`8227c21`） |
| 长文星号 | `lib/l10n/legal_zh.dart`（正文两处） | 去掉「本应用**不会**用它推送…」的 Markdown 星号（`Text()` 不渲染 Markdown，原来会原样显示）；英文正文本来就没有 | `flutter analyze` 无问题；`flutter test test/legal_texts_test.dart` 通过 | 已提交（`8227c21`） |

---

## 5. 阻塞（必须用户拍板/配合）

| # | 阻塞事项 | 影响范围 | 需要用户做什么 | 状态 |
|---|---|---|---|---|
| 1 | **Android 应用名/通知渠道名跟随「系统语言」而不是「App 内语言」** | 英文系统的老用户覆盖安装后，桌面名会从「小喵Player」静默变成 `Meow Player`；应用内选中文也管不住（通知渠道名、存储卷名、崩溃提示同理）。反向：中文系统 + 应用内英文时，这些仍是中文 | 拍板二选一：① **接受**（原生资源跟随系统语言，属 Android 常规行为）→ 在 `04-数据基线.md` §4.2 记为「设计如此」；② **不接受**（要求跟随 App 内语言）→ 需要额外开发：把 `app_locale` 同步给 Android 侧（如 `AppCompatDelegate.setApplicationLocales` 或启动时重建 Activity 覆盖 configuration），属于**新功能**而非本轮测试范围 | **已收口（2026-10）**：用户选 ① —— 已记入 `04-数据基线.md` §4.2 第 14 条「设计如此」 |
| 2 | R1/R2 两处确认的中文残留是否**本轮就修** | 影响英文界面观感（字幕下载页副标题中英混排、章节胶囊显示「第 N 章」） | 拍板：① 测试 AI 直接修 ② 本轮只登记，另开修复任务 | **已收口**：用户选 ①；R1/R2（含 R4、长文星号）已修并随 `8227c21` 提交 —— 本轮只做**复核** |
| 3 | 素材到位情况（`05-素材需求清单.md` M01–M20） | 决定多少条用例会落成「未验证」 | 提供素材 TXT 汇总；确认是否允许卸载重装 | **已提供**：素材已拷入设备 `/sdcard/素材收集清单`（M01–M20）；卸载重装已授权（M19 = 允许）。核对结果见 `05-素材需求清单.md` §6 |

---

## 6. 阶段进度

| 阶段 | 名称 | 状态 | 收口报告位置 |
|---|---|---|---|
| 0 | 基线与环境 | **已完成**（2026-10-04） | 见对话「阶段 0 报告」；证据 `_evidence/阶段0/`（10 条用例：9 通过 + 1 部分验证） |
| 1 | 启动链路与首启流程（含长文、崩溃日志） | **已完成**（2026-10-04）：32 通过 · 0 不通过 · 3 未验证 | 见对话「阶段 1 报告」；逐条结论见 §10，证据 `_evidence/阶段1/` |
| 2 | 媒体库与首页 | **已完成**（2026-10-04）：44 通过 · **2 条缺陷（3 个用例）** | 见对话「阶段 2 报告」；逐条结论见 §11，缺陷见 §2 |
| 3 | 播放器与音频/听视频 | **已完成**（2026-10-04）：64 条 = 58 首轮通过 + 6 条修复后实测通过；4 个缺陷（`DEF-3-01`～`DEF-3-04`）全部修复并推送 | 逐条结论见 §12，缺陷见 §2 |
| 4 | 字幕与弹幕 | **已完成**（2026-10-04）：60 条 = 59 条首轮通过 + 1 条修复后复测通过；1 个缺陷（`DEF-4-01`，**是回归**）已修并推送 | 逐条结论见 §13，缺陷见 §2 |
| 5 | 网络存储与投屏 | **已完成**（2026-10-04）：34 条 = **34 通过 · 0 未验证 · 0 缺陷** | 逐条结论见 §14；曾登记后补测通过的 5 条见 §3.1 |
| 6 | 哔哩哔哩与下载/更新 | **已完成**（2026-10-04）：59 条 = **59 通过 · 0 未验证 · 0 缺陷** | 逐条结论见 §15 |
| 7 | 多语言专项与 Android 原生侧 | **已完成**（2026-10-04）：46 条 = **46 通过 · 0 未验证 · 0 缺陷**；并顺带关闭 2 条历史未验证项 | 逐条结论见 §16；全轮总报告见 `08-最终总报告.md` |

---

## 7. 素材缺口汇总（全部阶段结束后填，给用户一次补齐）

| 素材 ID | 状态 | 导致多少条用例未验证 | 补上后可补测的用例 ID |
|---|---|---|---|
| ~~**M12** 局域网 DLNA 渲染器~~ | **缺口已关闭**：用户 2026-10-04 实测投屏通过（原先按「无」暂记的 5 条全部补测通过，见 §3.1） | 0 条 | — |
| M17 崩溃触发方式 | 已备（用户授权随意） | 2 条（含 1 条材料不具备） | `T1-SYS-014`、`T1-SYS-111`（另 `T1-SYS-015` 属无法构造，非素材问题） |

---

## 8. 执行过程中的环境变更记录（改过就写）

| 时间 | 变更 | 原因 | 是否已还原 |
|---|---|---|---|
| 2026-10-04 16:11 | 卸载设备上的旧包 → `tools/build_and_install.ps1 -Debug` 重新构建并安装（`versionCode 4`、`GIT_HASH=8227c21`、DEBUGGABLE）；关于页徽标实测 `v1.3.6 / debug / 8227c21` | 设备上原是**修复前**的包（`versionCode 4004`，缺 `8227c21` 的 4 处修复），不重装就测不到修复 | 不适用（这就是目标状态）。**副作用：卸载导致 App 数据清空** → 现为全新安装态，首启隐私弹窗与语言弹窗已各走过一遍 |
| 2026-10-04 16:13 | `appops set com.azxcvn.moumou MANAGE_EXTERNAL_STORAGE allow`（授予「所有文件访问」） | 首页需要该权限才能扫到素材（`T0-SYS-004`） | 保持授权（权限门禁本身的用例在阶段 1：`pm clear` 后走界面授权） |
| 2026-10-04 16:14 | 安装 M18 旧包（`versionCode 2004`、release、arm64-v8a）验证「新旧对照」可行性 | `T0-SYS-006`：确认旧包在 MuMu 上能不能跑 | **已恢复**：16:15 卸载旧包 + 装回 `app-debug.apk`（`versionCode 4`、全新安装、已授权）；旧包仅用于对照，用时再装 |
| 2026-10-04 17:5x | **基准 commit 推进**：`8227c21` → `a326a34`（已推送 `English`）。改动＝`DEF-2-01`（补扫深度）+ `DEF-2-02`（在线播放白名单/CA 库/错误提示）+ 1 个 ARB 键 `playerPlaybackFailed`（键数 1276 → **1277**） | 阶段 1/2 暴露的两个缺陷按用户要求修复 | **已由用户用自己脚本重编重装并复测通过**（2026-10-04）；测试包内 `04-数据基线.md` §1/§7、`README.md`、`01-执行协议.md` 的 commit 与键数已同步 |
| 2026-10-04 19:3x | **基准 commit 推进**：`a326a34` → `0c491bf`（已推送 `English`，`local == remote` 已校验）。改动＝阶段 3 的 `DEF-3-01`/`DEF-3-02`/`DEF-3-03` + `DEF-3-04` 的 App 侧兜底 + 动态范围压缩参数修正 + 1 个 ARB 键 `playerAudioEffectsUnsupported`（键数 1277 → **1278**） | 阶段 3 暴露的缺陷按用户要求修复（用户 2026-10-04 授权「修好之后直接 push，我去 CI 看构建」） | 测试包内 `04-数据基线.md`、`README.md`、`01-执行协议.md`、`03` 的 commit 与键数已同步 |
| 2026-10-04 20:0x | **内核侧改动 + 产物换入**：内核仓库 `libmpv-android-video-build-thumbnail` 补开 5 个音频滤镜（`caa8be1` 推 `main`，CI run #16 success 38 分钟）；把 CI 产物 4 个 `default-*.jar` 替换进 `third_party/media_kit_libs_android_video/android/jars/`（与产物 hash 一致） | `DEF-3-04`：内核缺滤镜导致五个音效无效、且会让后续视频整段无声 | **已推送**：App 仓库 `8c6a931`（`English`，local == remote，工作区干净）；内核仓库 `caa8be1`（`main`，local == remote，工作区干净）。用户已重编 App 实测无异常 |
| 2026-10-04 20:3x | **基准 commit 推进**：`8c6a931` → `3f90e50`（已推送 `English`，`local == remote` 已校验）。改动＝阶段 4 的 `DEF-4-01`（本地弹幕导入不再用失效 context）+ 成功提示改为带文件名（键 `playerLocalDanmakuLoaded` 的参数 `count` → `name`，**键数不变仍 1278**） | 阶段 4 暴露的缺陷按用户要求修复 | 测试包内 `04-数据基线.md`、`README.md`、`01-执行协议.md`、`03` 的 commit 已同步；用户已重编复测通过 |

---

## 9. 执行中观察（尚未判定，留给对应阶段的用例）

> 这里只记「看到了但还不能下结论」的现象，避免它们在阶段之间丢掉；定性后要挪到 §2 缺陷登记或 `04-数据基线.md` §4.2。

| # | 观察 | 现象 | 处理 |
|---|---|---|---|
| O1 | 首页出现**重复文件夹卡片** | 在「**先未授权扫描 → 再授权再扫描**」的状态下，首页出现重复卡片（`M01`/`M02` 各两张，另有一张名为 `1` 的目录）；**授权后全新安装首次扫描不再出现**（实测 16:15，列表为 `M01`/`M02`/`M03`/`M05`/`M06`/`同名字幕含简体繁体`…） | 判定与 l10n 无关（权限/扫描时序的合并问题），留到阶段 2 的扫描类用例复现定性；**暂不计缺陷**，也不写进「设计如此」 |
| O2 | 系统语言取不到 | `getprop persist.sys.locale` 为空、`settings get system system_locales` 为 `null` | 改用 `getprop ro.product.locale`（= `zh-Hans-CN`）；已更新 `04-数据基线.md` §7 与 `01-执行协议.md` §3.7 |
| O3 | MuMu 共享目录的可见性不一致 | `/mnt/shared/MuMuShared/` 在 MT管理器里能浏览（里面有 `素材收集清单`、`新建文件夹`、`1` 等），但 `adb shell ls` 报 `No such file or directory` | 共享目录对 shell 不可见——阶段 2 的「存储卷/共享目录」用例必须**以 App 界面为准**（直接关系 M16 的定性） |
| O4 | 外部打开视频时 flutter deep-link 报路由异常 | 16:34:30 从 MT管理器用本 App 打开 `…/M01/H264和MP4格式.mp4` 后，日志出现 `Could not find a generator for route RouteSettings("/storage/emulated/0/素材收集清单/M01/H264和MP4格式.mp4", null)`（栈：`_WidgetsAppState.didPushRouteInformation` → `pushNamed`） | **判定：老问题，不是 l10n 回归** —— `git diff 7276793^ HEAD -- android/app/src/main/AndroidManifest.xml` 只有 `android:label` 一处差异，deep-link 相关配置两版都没有；且**播放正常**（紧接着 `VideoOutputManager.create` 起了播放器）。唯一影响：这条异常会写进 App 自己的错误日志页。按 P3 观察先登记，不修（要修就是加 `flutter_deeplinking_enabled=false` 或补 `onGenerateRoute`，属功能改动） |
| O5 | 设备上现装的包是**用户自建**的 8227c21 debug | `versionCode=4004` / `application-debuggable` / 只含 `x86_64`（75 MB）；kernel_blob 里有 `GIT_HASH=8227c21`、R1/R2/R4 新键齐全、无 `chapterNumberFallbackLabel` | **基线 commit 未跑偏**（仍是 8227c21），无需处理；但注意 `4004 > 4`：若要装回策划者构建的 `build/app/outputs/flutter-apk/app-debug.apk`（versionCode `4`），**必须先卸载** |
| O6 | 修 `DEF-2-02` 时新增了 1 个 ARB 键 | `playerPlaybackFailed`（播放失败：{error} / Playback failed: {error}）→ ARB 键数 **1276 → 1277** | `04-数据基线.md` §4/§5、`README.md` §7 与 `03` 的 `T0-REG-004` 结果均已标注新数字；复跑该用例时以 1277 为准 |
| O7 | 在线播放中偶发一次 TLS 手抖 | `ffmpeg: tls: mbedtls_ssl_handshake returned -0x7280`（修复 `DEF-2-02` 后仍偶现一次，mpv 靠重连参数自愈、播放未中断） | 记观察：若真机上出现「播着播着卡住」，先看这条；根治要重编内核（mbedTLS → OpenSSL，见 `docs/archive/ARCHITECTURE.md` §4.15） |
| O8 | 「反向立体声」同样不可用（**已确认**） | 该档位走 `af` 的 `pan=[stereo|c0=c1|c1=c0]`，而设备上的 `libmpv.so` 里**没有 `pan` 滤镜**（与 `DEF-3-04` 同一根因） | 用户 `T3-PLR-034` 首轮反馈「无异常」，复核时确认**同样报错**（2026-10-04：「反向力提升确实也是这样」）→ 已并入 `DEF-3-04`，`T3-PLR-034` 改计为发现问题 |

---

## 10. 阶段 1 执行记录（2026-10-04）

> 结论：**35 条 = 32 通过 · 0 不通过 · 3 未验证**。`03-测试用例清单.md` 阶段 1 的勾选已同步；本节是逐条结论与证据索引。
> 分工：策划者（AI）执行 11 条并留截图；其余 24 条由用户在模拟器上执行，2026-10-04 批量反馈「A–E 组测试无异常」。

### 10.1 由 AI 执行（11 条，均留证）

| 用例 | 结果 | 关键事实 / 证据 |
|---|---|---|
| `T1-SYS-002` | 通过 | 首启隐私弹窗：标题「用户隐私政策」；长文可滚动；勾选框 + 倒计时按钮 + 「不同意并退出」。四处文案与 ARB 一致（`legalAgreeCheckbox` / `legalAgreeWithCountdown` / `legalAgreeContinue` / `legalDisagreeExit`）。证据 `T1-SYS-002_首启弹窗_第一屏.png`、`T1-SYS-002_长文滚动.png` |
| `T1-SYS-003` | 通过 | 倒计时 4 秒 → 1 秒递减、期间按钮灰且不可点；倒计时结束后**未勾选仍不可点**（标签去掉秒数，变 `同意并继续`）；勾选后才可点（实心色）。证据 `T1-SYS-003_a_倒计时中.png` ~ `T1-SYS-003_d_勾选后.png` |
| `T1-SYS-004` | 通过 | 点「不同意并退出」→ 回到桌面、**不进主界面**；进程作为缓存后台进程存在（Android 正常行为）。证据 `T1-SYS-004_拒绝退出后.png` |
| `T1-SYS-005` | 通过 | 同意后杀进程重启：直接进首页，不再弹隐私窗（与 `T1-SYS-011` 同一次重启） |
| `T1-SYS-008` | 通过 | 底部胶囊中文 `首页/我的`、英文 `Home/Mine`，来回切换无白屏。证据 `T1-SYS-008_en_Mine顶部.png`、`T1-SYS-010_b_切成中文后立即生效.png` |
| `T1-SYS-010` | 通过 | 我的 → 语言设置 → 简体中文 → OK：当前页**立即**变中文（未重启）；prefs `app_locale=zh`。证据 `T1-SYS-010_a_语言设置弹窗.png`、`T1-SYS-010_b_切成中文后立即生效.png` |
| `T1-SYS-011` | 通过 | 切英文 → `am force-stop` → 重启仍是英文（prefs `app_locale=en`）。证据 `T1-SYS-011_重启后仍英文.png` |
| `T1-I18N-001` | 通过 | 同意隐私后**立即**弹语言窗：标题 `选择语言 / Choose Language`、选项「简体中文」「English」、**默认勾选简体中文**；此刻 prefs 只有 `privacy_policy_accepted=true`、**没有 `app_locale`**（正好构成 §10.3 之外需要的「升级态」）。证据 `T1-I18N-001_同意隐私后弹语言窗.png` |
| `T1-I18N-002` | 通过 | 选 English → OK：界面**立即**变英文（`Meow Player`），prefs `app_locale=en`；复数正确（`1 video` / `3 videos`）。证据 `T1-I18N-002_选英文后立即变英文.png` |
| `T1-I18N-004` | 通过 | 选过语言后杀进程重启不再弹语言窗（与 `T1-SYS-011` 同一次重启） |
| `T1-I18N-006` | 通过 | 「语言」组在「弹幕」组下方、「下载」组上方；组内项「语言设置」副标题显示当前语言。证据 `T1-I18N-006_en_语言组位置.png` |

### 10.2 由用户执行（24 条，批量反馈无异常 → 全部记通过）

| 组 | 用例 |
|---|---|
| A 权限与隐私 | `T1-SYS-001`、`T1-SYS-101`、`T1-SYS-006`、`T1-SYS-007` |
| B 我的页与语言 | `T1-SYS-009`、`T1-SYS-012`、`T1-I18N-003`、`T1-I18N-005` |
| C 关于页与日志 | `T1-SYS-013`、`T1-SYS-110`、`T1-SYS-106`、`T1-SYS-107`、`T1-SYS-108`、`T1-SYS-109` |
| D 启动与外观 | `T1-SYS-016`、`T1-SYS-105`、`T1-SYS-017`、`T1-SYS-112` |
| E 其余 | `T1-SYS-102`、`T1-SYS-103`、`T1-SYS-104` |

> 收口核查：`T1-SYS-012` 需临时把**系统语言**切英文再切回 —— 已确认 `ro.product.locale` 还原为 `zh-Hans-CN` ✓。
> `T1-SYS-112`（外部打开视频）收口时在日志里看到 O4 的路由异常，但**播放确实起来了**，用户反馈一致。

### 10.3 未验证（3 条，见 §3）

`T1-SYS-014` 崩溃提示 · `T1-SYS-015` 读日志失败分支 · `T1-SYS-111` 崩溃日志裁剪 —— 三条都需要构造模拟器上做不到 / 收益很低的特殊状态。

---

## 11. 阶段 2 执行记录（2026-10-04，用户实测）

> 结论：**47 条 = 44 通过 · 3 条发现问题（2 个缺陷）**。`03-测试用例清单.md` 阶段 2 的勾选已同步。
> 全部由用户在模拟器上执行；反馈原文口径：「除了上述反馈的问题，其他都无异常」。

### 11.1 通过（44 条）

- 扫描与视图：`T2-HOME-001`~`004`、`007`~`010`、`114`
- 卡片与信息：`T2-HOME-011`~`014`、`108`~`111`、`116`
- 多选与文件操作：`T2-HOME-016`~`023`、`101`~`107`
- 入口与工具页：`T2-SET-001`、`T2-SET-002`、`T2-HOME-025`、`026`、`027`、`028`、`112`、`113`、`115`
- 空态：`T2-HOME-015`

> `T2-HOME-008`（第二存储卷 / M16）：用户实测无异常 → 通过。

### 11.2 `DEF-2-01` · 深层路径下的 `.nomedia` / 隐藏目录扫不到 · P2

- **用例**：`T2-HOME-005`、`T2-HOME-006`
- **语言**：简体中文（与语言无关）
- **环境**：commit `8227c21` · debug · 系统语言 `zh-Hans-CN` · 设备 `emulator-5554`
- **前置**：媒体扫描设置里开启「包含 .nomedia 目录」/「包含隐藏目录」
- **复现**：
  1. 用 M07 的深层目录素材：`/storage/emulated/0/素材收集清单/M07/多级子目录/子目录1/子目录2/子目录3/子目录4/带nomedia/`
  2. 开启对应开关 → 回首页刷新
  3. 对照浅层：同类目录放在根目录下、或一两层
- **实际结果**：**深层扫不到**（开关打开也不出现）；**浅层正常**（根目录下、或一两层的能扫到）。隐藏目录（`T2-HOME-006`）现象相同。
- **期望结果**：开关打开后，**任意层级**的 `.nomedia` / 隐藏目录（及其中视频）都应被扫描出来
- **证据**：用户实测口述（2026-10-04），未截图
- **是否回归**：**否** —— `PRIMARY_MAX_DEPTH = 6` 来自改造前的 `0b5e233`（补扫 walker 在 `7276793^` 就存在）
- **根因**：`VideoFsWalker.kt` 的 `PRIMARY_MAX_DEPTH`（主卷最大递归深度）**原来是 6**，而深度判定卡的是**目录**（文件不判）→ `depth > 6` 的目录**整个不被列目录**，里面的视频永远不出现。用户路径 `素材收集清单(1)/M07(2)/多级子目录(3)/子目录1(4)/子目录2(5)/子目录3(6)/子目录4(7)/带nomedia(8)` 是 **8 层** → 命中；根目录与一两层不命中 → 现象完全对上
- **处理**：**已修**（用户 2026-10-04 授权「帮我修」）：`android/app/src/main/kotlin/com/azxcvn/moumou/VideoFsWalker.kt` 的 `PRIMARY_MAX_DEPTH` **6 → 20**（与非主卷 `EXTERNAL_MAX_DEPTH` 及参考项目 mpvRx 一致；递归成本由 `WALK_BUDGET_MS` 时间预算 + 广度优先 + frontier 续扫 + `DIR_RESCAN_INTERVAL_MS` 兜，不靠深度上限）
- **验证**：`flutter build apk --debug` 编译通过（16.6s，**未安装**）；**待在用户重新构建安装后的新包里实测确认**

### 11.3 `DEF-2-02` · 在线播放全部失败（协议白名单被切碎 + mbedTLS 无 CA 库）· P1 · **已修**

- **用例**：`T2-HOME-024`（用户另外反馈了第二条 m3u8、并确认真机同样播不了）
- **环境**：commit `8227c21` · debug · 系统语言 `zh-Hans-CN` · 设备 `emulator-5554`（用户真机同样复现）
- **现象**：在线直链打开后 `00:00 / 00:00`、网速 `0.00 KB/s`、无限转圈；**本地文件播放完全正常**
- **排查过程（结论都有证据）**：
  1. 链接本身没问题：主/子播放列表 200、分段 206（支持 Range），PC 侧直连也通
  2. 用同一台 PC 起 http 服务做对照：**纯 http 能正常播放**（服务端日志可见 `UA=libmpv` 拉走整个文件）→ 说明 mpv 网络栈正常，问题在 https
  3. 给播放器接上 `Player.stream.error`/`stream.log` 后，mpv 直接给出原因：
     `ffmpeg: https: Protocol 'https' not on whitelist 'udp'!` → `lavf: avformat_open_input() failed`
  4. 打印读回来的 `demuxer-lavf-o`：`…,protocol_whitelist=udp,rtp,tcp,tls,data,file,http,https,crypto`
     —— **mpv 读回来时方括号丢了**；原「按括号深度切分后合并」的实现把这个列表值**切碎**，
     写回去只剩 `protocol_whitelist=udp` → 之后所有 http/https 都被 ffmpeg 拒绝
  5. 第二层：白名单修好后仍报 `ffmpeg: tls: mbedtls_ssl_handshake returned -0x7280`
     —— 自编 libmpv 是 mbedTLS 后端，而 **ffmpeg 的 mbedTLS 没有默认 CA 证书库路径**
     （`libmpv.so` 里只有 `mbedtls_x509_crt_parse_file`/`ca_file`，没有任何默认 CA 路径串）
- **是否回归**：**否** —— 调参模板来自改造前的 `0428007`，与多语言改造无关
- **修复（应用层，3 处）**：
  1. `lib/utils/mpv_tuning.dart`：新增 `kPlaybackProtocolWhitelist` + `buildDemuxerLavfO()`，
     **整串重建** `demuxer-lavf-o`（media_kit 三项默认值 + 白名单 + 在线重连参数）；
     删掉会被切碎的 `mergeDemuxerLavfOptions`/`splitLavfOptions`
  2. `lib/services/tls_ca_bundle.dart`（新增）+ `assets/certs/cacert.pem`（Mozilla CA 库，188 KB）：
     拷到沙盒并写 mpv `tls-ca-file`；`pubspec.yaml` 注册 `assets/certs/`
  3. `lib/pages/player/player_page.dart`：`PlayerConfiguration.protocolWhitelist` 用同一常量；
     并把 `Player.stream.error` 接成「播放失败：<原因>」提示 + warn/error 落 logcat
     （此前完全静默，所以只能看到无限转圈）；新增 ARB 键 `playerPlaybackFailed`
- **验证**：`flutter analyze` 无问题；`test/mpv_tuning_test.dart`（含「白名单不得被切碎」回归断言）+
  `test/tls_ca_bundle_test.dart` 通过；`flutter build apk --debug` 通过；
  **模拟器实测**：https m3u8 打开后 `00:10 / 24:17`、网速 903 KB/s，65 秒时画面已推进到后面（正常播放）
- **遗留观察**：播放中偶发一次 `mbedtls_ssl_handshake returned -0x7280`（mpv 靠重连参数自愈，未中断播放）；
  模拟器上画面推进略慢，属 debug 构建 + 模拟器解码性能，真机待用户确认
- **仍需用户做**：用你自己的脚本重新构建安装后，在真机上复测两条 m3u8 与 https mp4

---

## 12. 阶段 3 执行记录（2026-10-04，用户实测）

> 结论：**64 条 = 58 条首轮通过 · 6 条发现问题、修复后复测通过**（`DEF-3-01`～`DEF-3-04` 全部收口）。`03-测试用例清单.md` 阶段 3 的勾选已同步。
> 全部由用户执行（真机 + 模拟器）；反馈原文口径：「除了上述这些，其他都没有什么问题」。

### 12.1 首轮通过（58 条）

- 基础播放与控制面板：`T3-PLR-001`～`017`
- 手势：`T3-PLR-018`～`024`
- 截图 / 画中画 / 听视频 / 后台播放：`T3-PLR-025`～`027`、`029`、`030`
- 音频：`T3-PLR-031`、`033`、`037`～`040`
- 附录 A.3 补充：`T3-PLR-101`～`108`、`110`～`121`
- 附录 B 定向核查：`T3-PLR-122`（R3 网络弹幕 toast **有**「已加载弹幕」前缀 → **排除回归**）、
  `T3-PLR-123`（R2 章节英文显示 `Chapter N` → **修复生效**）、`T3-PLR-124`（R9-① 未见 `类名(错误码)` → **排除**）

> 首轮把 `T3-PLR-034`（反向立体声）计为通过，复核时用户确认它**同样报错**（见 §9 O8）→ 已改计为发现问题、并入 `DEF-3-04`；
> 两处需要人工操作 / 特殊素材的子项（`T3-PLR-023` 双指缩放需人工多点触控、`T3-PLR-037` 杜比视界提示需偏色视频）
> 用户实测同样无异常 → 一并计为通过。

### 12.2 已修（3 条，随 `0c491bf` 推送，用户 2026-10-04 实测通过）

| 用例 | 现象 | 根因 | 修法 | 涉及文件 |
|---|---|---|---|---|
| `T3-PLR-028` | 英文下听视频「定时关闭」最右侧胶囊（`After current track`）超出 44px | 英文文案远长于中文，而胶囊在等宽三列网格里宽度固定 | 英文 `audioSleepEndOfTrack` 缩成 **`After track`**；并给胶囊文案加 `Flexible` + 省略号（任何语言都不再溢出） | `lib/l10n/app_en.arb`(+生成物)、`lib/pages/player/views/audio_player_panels.dart` |
| `T3-PLR-032` | 导入外部音轨后点「移除」，不落回内嵌音轨，界面变成「没有任何音轨选中」 | `audio-remove` 掉**当前正在播**的轨道后，mpv 把 `aid` 置成 `no` | 移除当前音轨后显式落回「导入前选中的那条内嵌轨」（没记录→第一条内嵌轨；导入前是「关闭」→保持关闭；无内嵌轨→保持无选中）；新增纯函数 `pickTrackAfterExternalRemoval` + 7 条单测 | `lib/services/audio_service.dart`、`test/audio_fallback_test.dart` |
| `T3-PLR-109` | 「双指缩小视频」副标题「双指缩放画面」与实际行为不符 | 该开关只放开 0.75 倍**缩小**下限（关着只能放大、不能缩小），副标题却写成通用「缩放」 | 中文改「**允许双指去缩小画面**」，英文 `Allow two-finger pinch to shrink the picture` | `lib/l10n/app_zh.arb`、`app_en.arb`(+生成物) |

验证：`flutter analyze` 无问题；全量 `flutter test` 通过（**1830 通过 / 13 跳过**）。已提交并推送：`0c491bf`。

### 12.3 `DEF-3-04` · 音频效果全线无效（根因在 libmpv 内核；App 兜底 + 新内核产物，**已修复并实测通过**）

- 用例：`T3-PLR-034`（反向立体声）、`T3-PLR-035`（音量标准化 / 动态范围压缩）、`T3-PLR-036`（低音增强 / 虚拟环绕）
- 现象：开关一开就提示 `Option af: item 'dynaudnorm' isn't supported`、`Audio filter initialized failed`；
  并且**开了这些开关之后，再进任何视频都没声音**（issue #8：关掉这些开关再进才恢复）
- 证据（对设备上实际加载的 `libmpv.so` 做符号 / 字符串扫描，26 MB，符号表完整）：
  - ffmpeg 音频滤镜**只有 `ff_af_equalizer` 一个**，视频滤镜只有 `ff_vf_overlay`；
  - `dynaudnorm` / `acompressor` / `lowshelf` / `extrastereo` / `pan` 这些名字在 `.so` 里**一次都不存在**。
- 对应内核仓库 `azxcvn/libmpv-android-video-build-thumbnail` 的 `buildscripts/flavors/default.sh`：`--disable-filters`，
  只开了 `--enable-filter=overlay` 与 `--enable-filter=equalizer`（脚本注释写明「滤镜仍保持上游的精确白名单，未改动」）。
  ffmpeg 版本 `v_ffmpeg=9.0`；滤镜实现位置：`lowshelf`/`equalizer` 在 `af_biquads.c`，`acompressor` 在 `af_sidechaincompress.c`（`CONFIG_ACOMPRESSOR_FILTER`）。
- 为什么「没声音」：写在 `lavfi=[…]` 里的滤镜（acompressor / lowshelf / extrastereo）**属性写入是成功的**，
  失败发生在 mpv 建滤镜图/初始化音频链时 → 整条音频链挂掉；而这些开关是**持久化**的 → 之后每个视频都没声音。
  直接写名字的 `dynaudnorm` / `pan` 则是**选项解析就失败**（属性没写进去），只报错、不影响当前声音。
- **顺带查出的第二个坑**：动态范围压缩的 `acompressor=threshold=-20dB` **参数本身也是错的** ——
  ffmpeg 的 `acompressor` threshold 是**线性值**（范围 0.000976563–1、默认 0.125），不认 `dB` 后缀，
  就算内核把 `acompressor` 编进来也照样建不起来。已改成 `threshold=0.1`（= -20 dB）。
- **与 l10n 无关**：内核白名单改造前就存在；现在能看见报错，是因为修 `DEF-2-02` 时给播放器接上了 mpv 错误提示。
- **用户决定（2026-10-04）**：走方案 A —— 先由 AI 在 App 侧做兜底，用户随后重编内核，等 CI 跑完、本阶段缺陷全部收口后再进阶段 4。
- **App 侧已做（随 `0c491bf` 推送）**：
  1. `lib/models/audio_track.dart`：`acompressor` 的 threshold 改成线性值 `0.1`（回归断言：链里不得出现 `dB`）；
  2. `lib/services/audio_service.dart`：新增纯函数 `isAudioFilterFailureLog` / `unsupportedAudioFilterFromLog`；
     `AudioController` 接住 af 失败日志 —— 能认出滤镜名的（`dynaudnorm` / `pan`）就**记住并跳过它**重写 af 链，
     认不出的（`lavfi=[…]` 图建不起来）就**整个会话停用 af**，把声音救回来；
     失败判定不看时间窗口，而是比对「最近一次真正写进 mpv 的链」是否为空；
     滤镜能力是**内核属性**，切集不清空（否则每集都要重踩一次无声）；
  3. `player_page.dart`：新增回调提示「当前播放内核不支持所选音效，已自动跳过」（新键 `playerAudioEffectsUnsupported`），
     并且不再把裸的 mpv 滤镜报错当播放失败弹一遍；
  4. `isAudioPlaybackFailureLog` 排除 af 失败日志 —— 否则「Audio filter initialized failed」会被误判成
     「这条音轨放不出来」，把用户选的音轨白白切走。
- **内核侧（用户 2026-10-04 决定走方案 A，已执行）**：`azxcvn/libmpv-android-video-build-thumbnail` 的
  `buildscripts/flavors/default.sh` 在上游白名单（`overlay` / `equalizer`）之上补开
  `--enable-filter=pan`、`dynaudnorm`、`acompressor`、`lowshelf`、`extrastereo`
  → 提交 `caa8be1` 推 `main` → CI `Build libmpv-android` **run #16 success（38 分钟）**。
- **产物符号级验证（不是只看 CI 变绿）**：解出 4 个 jar 里的 `libmpv.so` 逐个扫描，
  新内核 `ff_af_*` = `acompressor, dynaudnorm, equalizer, extrastereo, lowshelf, pan`（6 个，旧内核只有 `equalizer`），
  `ff_vf_overlay` 仍在；4 个 ABI（arm64-v8a / armeabi-v7a / x86 / x86_64）结果一致。
- **jar 已替换并推送**：`third_party/media_kit_libs_android_video/android/jars/` 下 4 个 jar 已换成 CI 产物（hash 一致），
  随 **`8c6a931`** 提交并推 `English`（local == remote，工作区干净）。
- **用户实测：2026-10-04 用自己脚本重编 App 后「无异常」** —— 反向立体声 / 音量标准化 / 动态范围压缩 /
  低音增强 / 虚拟环绕 五个音效全部通过，`DEF-3-04` 收口。
- 复核判据（留档，供阶段 4/7 复用）：不再弹「当前播放内核不支持所选音效」；反向立体声左右互换、
  低音增强/虚拟环绕听感有变化、动态范围压缩（参数 `threshold=0.1`）不报错。若日后又失败，
  `adb logcat` 里的 `[mpv error]` 行可直接定位是哪个滤镜，再用 `ff_af_*` 符号比对内核产物即可。

---

## 13. 阶段 4 执行记录（2026-10-04，真机 Android 16，用户实测）

> 结论：**60 条 = 59 通过 · 1 条发现问题**（`DEF-4-01`，已修待复核）。`03-测试用例清单.md` 阶段 4 的勾选已同步。
> 用户反馈原文口径：「除这条外，其余无异常」——包含三个定向核查 `T4-SUB-111`（R10）/ `T4-SUB-112`（R17）/ `T4-DMK-112`（R14）。

### 13.1 `DEF-4-01` · 本地弹幕导入失效（P1，**是回归**）

- 用例：`T4-DMK-002`
- 环境：真机 **Android 16**（SDK 36 → `DeviceServices.shouldUseSystemPicker` 为 false → 走**自建选择器**）
- 现象：播放器 → 更多 → 弹幕 → 本地弹幕 → 在文件选择器里点弹幕文件 → **毫无反应**（选择器不关、无提示、弹幕也没导入）
- 根因（代码级，已用回归测试复现）：
  1. `PlayerPanel` 的面板导航**只渲染页面栈顶那一页**（`lib/widgets/player_panel.dart` 用 `_pages.last`）→ push 自建选择器二级页后，
     **弹幕面板自身的 element 已被移出树**（这一点与真正的 `Navigator` 不同：路由栈上一页仍会挂着）；
  2. `_loadPickedFile(context, path)` 的第一行是 `final l10n = AppLocalizations.of(context);`，用的是**那个已被替换掉的面板 context** →
     debug 构建下命中断言 `Looking up a deactivated widget's ancestor is unsafe.` → 回调抛异常 →
     `SubtitleFilePickerPanel._pickFile` 里的 `widget.onClose()` 也不会执行 → 于是「点了一点动静都没有」，
     而且 `loadDanmakuFromFile` 一次都没跑（弹幕自然没导入）。
  3. 为什么字幕（`T4-SUB-002`）与音频（`T3-PLR-032`）导入没事：它们的 `onPicked` 只调控制器、**完全不碰 context**。
- **是否回归：是**。改造前同一函数是「**先** `loadDanmakuFromFile` → **再** `if (!context.mounted) return;` → 才 `_toast(context, …)`」：
  context 失效时只是**不弹提示**、导入照旧成功。迁移期为了取 l10n 文案，把 `AppLocalizations.of(context)` 提到了 await **之前**，
  才变成「先炸、导入不执行」。
- 修法（`lib/pages/player/views/player_danmaku_panel.dart`）：在 `_importLocalDanmaku` 里、**面板还在树上时**就把 `l10n` 与
  `ScaffoldMessenger` 取好，回调改为收这两个对象（`_loadPickedFile(ScaffoldMessengerState messenger, AppLocalizations l10n, String path)`），
  提示前判 `messenger.mounted`；系统选择器那条路径同样改用这两个对象。
- 提示文案（用户 2026-10-04 要求）：成功提示从「已加载本地弹幕（N 条）」改成 **`已加载本地弹幕：<弹幕文件名>`**
  （键 `playerLocalDanmakuLoaded` 的参数由 `count` 改为 `name`；文件名取纯函数 `danmakuFileNameOf`，加了 3 条单测）。
  与「已自动加载弹幕：{fileName}」同款写法。
- 回归测试：`test/player_danmaku_panel_test.dart` 新增「本地弹幕导入（自建选择器）」用例，宿主刻意复刻 `PlayerPanel`
  「只挂载栈顶那页」的行为；**未修复的代码上该用例必失败**（实测报 `Looking up a deactivated widget's ancestor is unsafe.`，
  且 `loadedPaths` 为空 = 导入回调根本没执行），修复后通过。
- 同类排查：全仓 `_pushSubPage` / `onPicked` 调用点逐个看过——只有弹幕这一处回调碰 context（字幕、音频、章节面板均安全）。
- 验证：`flutter analyze` 无问题；全量 `flutter test` 通过（**1834 通过 / 13 跳过**）。**已提交并推送 `3f90e50`**（用户 2026-10-04 重编复测通过后授权提交）。

---

## 14. 阶段 5 执行记录（2026-10-04，真机 Android 16 + PC 侧自建 FTP，用户实测）

> 结论：**34 条 = 34 通过 · 0 未验证 · 0 缺陷**。`03-测试用例清单.md` 阶段 5 的勾选已同步。
> 用户反馈原文口径：「我已经测试无异常，阶段5收尾」；随后对原先按「M12 = 无」暂记未验证的 5 条投屏用例答复「已经测过了」→ 一并计为通过。

### 14.1 通过（34 条）

- 网络存储 19 条：`T5-NET-001`～`012`、`T5-NET-101`～`111`
- 投屏 / 局域网媒体服务 15 条：`T5-CAST-001`～`007`、`T5-CAST-101`～`104`

### 14.2 曾记「未验证（缺 M12）」、后补测通过（5 条，留痕）

`T5-CAST-001`（列出渲染器）、`002`（推流）、`003`（设备离线提示）、`007`（英文重走 001–003）、`102`（只列 MediaRenderer）。

- 首次收口时按 `05-素材需求清单.md` §5「M12 = 无」登记为未验证；
- 2026-10-04 用户答复「已经测过了」→ **全部计为通过**，未验证登记已关闭（留痕见 §3.1，素材缺口汇总 §7 的 M12 行同时关闭）。

### 14.3 本阶段为测试搭的环境（PC 侧，测完已停）

- 为 `T5-NET-002`（中文文件名 / MLSD→LIST 回退）在 PC 上用 **pyftpdlib** 自建 FTP 服务：
  监听 `0.0.0.0:21`，**固定 PASV 播报 `192.168.8.13`**（本机另有 169.254.x 虚拟网卡，不固定会播错地址）、
  被动口 `60000–60049`，账号 `test/test123`（只读）+ 匿名（只读）。
- 起服务前的自测留证：登录成功 / `PASV` 播报 `192.168.8.13:60030` / FEAT 有 `UTF8`、`MLST`、`MDTM`、`SIZE`、`REST STREAM` /
  `SIZE` = 271,767,581 字节 / `REST 1048576` → `350 Restarting at position 1048576` / `MLSD` 与 `LIST` 都能列目录 /
  `CWD 中文目录` 正常 / 匿名登录 `230 Login successful`。
- 素材：共享目录里补了中文名项 `中文目录/测试视频-中文名.mp4`、`中文目录/子目录（中文）/中文子目录里的视频.mkv`
  （用硬链接，不额外占空间）。
- 脚本与日志：`C:\Users\root\Desktop\新建文件夹\ftp_server.py`、`ftp_server.log`。
- **收尾时已停服务**：无残留 python 进程、21 端口无监听、`192.168.8.13:21` 连不上。
- 防火墙：WLAN 属**专用网络**，而 `python.exe` 的入站放行规则正好是 Private / TCP any 端口 → **未改动任何系统设置**。

---

## 15. 阶段 6 执行记录（2026-10-04，真机 Android 16，用户实测）

> 结论：**59 条 = 59 通过 · 0 未验证 · 0 缺陷**。`03-测试用例清单.md` 阶段 6 的勾选已同步。
> 用户反馈原文口径：「没有什么问题，你的那两条单测也不用跑了，我要求没有那么高，这个阶段到此为止，收尾」。

### 15.1 通过（59 条）

- 哔哩哔哩 16 条：`T6-BILI-001`～`016`
- 下载与更新 14 条：`T6-DL-001`～`014`
- 设备信息与播放设置 2 条：`T6-SET-001`、`T6-SET-002`
- 附录 A 补充 21 条：`T6-BILI-101`～`112`、`T6-DL-101`～`109`
- 附录 B 定向核查 6 条：`T6-BILI-113` / `114` / `115` / `116`、`T6-DL-110` / `111`
  - `T6-BILI-113`（R6）：用户确认**本轮不必跑**其中那两条代码侧单测（原话「我要求没有那么高」）→ 该条按用户在真机上的实测结论计入。

### 15.2 需要素材 / 构造条件的几组用例，用户均已实测通过

这几组的素材或构造条件在开工前是存疑的，**用户已实测确认通过**，此处只记录结论，不再是未验证项：

| 组 | 用例 | 素材/条件 | 结论 |
|---|---|---|---|
| 更新检查 | `T6-DL-012`、`T6-DL-013`、`T6-DL-014` | 真机访问 GitHub Releases | **通过** —— 用户明确「真机就是能，点检查更新会检查到」，且长期在用 |
| 升级场景 | `T6-DL-006`（旧任务读回部分）、`T6-DL-110` | 素材 M18 旧包 + 覆盖安装 | **通过** |
| 写盘失败 | `T6-DL-108`、`T6-DL-111` | 磁盘满 / 目录不可写 | **通过** |

### 15.3 本阶段为测试搭的环境

- 无（本阶段不需要 PC 侧服务；阶段 5 的 FTP 服务已停，`21` 端口无监听、无残留进程）。

---

## 16. 阶段 7 执行记录（2026-10-04，真机 Android 16，用户实测）

> 结论：**46 条 = 46 通过 · 0 未验证 · 0 缺陷**。`03-测试用例清单.md` 阶段 7 的勾选已同步。
> 用户反馈原文口径：「已测试无异常，阶段7收尾」。

### 16.1 通过（46 条）

- 双语全页面走查 10 条：`T7-I18N-001`～`010`
- 多语言机制专项 10 条：`T7-I18N-011`～`020`
- Android 原生侧 9 条：`T7-SYS-001`～`009`
- 附录 A.7 补充 10 条：`T7-I18N-101`～`106`、`T7-SYS-101`～`104`
- 附录 B 定向核查 7 条：`T7-I18N-107`（R1）、`108`（R8）、`109`（R11）、`110`（R15）、`111`（R16）、`112`（R18）、`T7-SYS-105`（R19）

### 16.2 本阶段顺带关闭的历史未验证项

- `T1-SYS-014`（崩溃提示 Toast）与 `T1-SYS-015`（读日志失败提示）：主体分别由本阶段的 `T7-SYS-006`、`T7-SYS-008` 覆盖，
  用户实测通过 → **未验证登记关闭**（见 §3）。
- 全轮仅剩 1 条未验证：`T1-SYS-111`（需造 51 个崩溃日志文件验证日志裁剪）—— 无对应用例覆盖，且会污染错误日志页。

### 16.3 收口时修的一处白名单行号漂移（**不是产品残留**）

收口跑残留门禁时三口径报 `residual: 1`、`过期白名单: 1`：

- 残留项 = `lib/pages/player/player_page.dart` 的截图相册名 `'小喵Player'` —— **用户已拍板「保持中文」、属「设计如此」**，
  白名单里本来就声明了这条；
- 但**白名单按行号匹配**，而阶段 3/4 的修复让这一行从 **1417 漂到 1454** → 该字面量被当成残留、原条目被当成过期项。
- 处理：把 `杂项文件/多语言支持方案/tools/whitelist.json` 中该条目的行号同步为 **1454**（条目本身、理由与白名单性质均未改），
  并在理由里记下漂移过程。处理后三口径恢复 **0 / 0 / 0**。

### 16.4 收口门禁（2026-10-04，全绿）

| 门禁 | 结果 |
|---|---|
| `flutter analyze` | **No issues found!** |
| 全量 `flutter test` | **1834 通过 / 13 跳过** |
| `residual`（默认 / `--include-android` / `--fullwidth`） | **0 / 0 / 0**，白名单过期 **0** |
| ARB 对称性 | zh / en 各 **1278** 键，无空值；`l10n_untranslated.json` = `{}` |
| 仓库 | 工作区干净，`HEAD == origin/English == 3f90e50`，版本号仍 `1.3.6+4` |
