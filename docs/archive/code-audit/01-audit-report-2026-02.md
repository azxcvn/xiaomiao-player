# 小喵Player（Dart 移植版）全项目体检报告

> 审计方式：**纯静态代码审计（只读）**。本轮未修改任何文件、未运行 `flutter analyze`/`flutter test`、未编译、未联网、未触碰磁盘用户文件。
> 范围：`lib/` 255 个 dart（51021 非空行）、`test/` 134 个 dart（14876 非空行）、`android/` 全部 Kotlin + Manifest + Gradle、`third_party/`（media_kit fork / media_kit_libs_android_video / smb_connect）、`docs/archive/ARCHITECTURE.md`（1878 行）。
> 所有发现均带 `文件:行号` 证据；**凡未经独立复核或需真机/编译验证的，均明确标注「待验证」**。
> 本轮工作树全程 `git status` 干净，未产生任何代码改动。

---

## 0. 结论速览

体检项目整体**质量高于同类国产播放器移植项目**：分层（§3）基本没有反向依赖、并发原语（§4.29）与统一重试（§4.28）在 B 站/弹幕/下载域已真正落地、`docs/archive/ARCHITECTURE.md` 是被当契约维护的（§7 抽查 30 条历史坑，27 条在代码中确有对应防护）、B 站凭据加密与 WBI 混淆表 64 项均无回归、弹幕渲染层 registry 与调度器边界处理经得起推敲。

但存在一批**用户可直接感知、且与文档承诺相反**的缺陷，其中三类最严重：

1. **功能静默失效**：竖屏页完全没有实现「音量增强」，横屏建立的 mpv 增益还会被带进竖屏并失去控制，而指示器仍显示 100%（UI 谎报响度）；竖屏长按倍速会把用户倍速复位成 1.0x；竖屏切集不写入播放历史。
2. **不可恢复的数据丢失**：文件管理「只删视频文件，其它文件不会被删除」的弹窗承诺下，实际会删掉 `.mp3/.flac/.wav` 等音频；移动空文件夹会**删源且不建目标**；取消/失败留下与完整文件同名同扩展名的截断文件。
3. **同一约定「多数地方遵守、少数地方遗漏」**：`ensureLoaded` 漏了 `SuperResolutionService` 与 `ViewSettings`；`playerPanelAccent` 漏了被 11 个面板复用的 `PlayerOptionChip`；一次性迁移 `_legacyVariantMapping` 没有门控，导致调色板风格每次启动被改写；网络存储整个子系统绕过了 §4.28 的重试/超时分级，并出现 §7 明文禁止的无上限 `drain()`。**✅ 以上四类均已收口**（前两条 B1、迁移门控 B2、网络存储 B10）。

### 0.1 严重度统计

| 严重度 | 条数 | 说明 |
|---|---|---|
| **P0**（数据丢失 / 必崩） | **4** | 音频误删、空目录移动丢文件夹、主题风格持久化错乱、听视频在无播放列表来源下必崩 |
| **P1**（功能错误 / 资源泄漏） | **20** | 竖屏缺音量增强与真实倍速、竖屏不记历史、字幕样式每帧全量写 mpv、字幕记忆不失效、文件传输弹窗可被返回键绕过、WebDAV 全量 drain、网络存储无超时、SMB 预读内存累积、原生 fd 泄漏、`getVideos` 卡主线程、进度脏数据钉死 `_loadFuture`、**音轨放不出来静默无声（P1-39，2026-09 追加）**、**运行期写 `sub-fonts-dir` 导致内嵌位图字幕不渲染（P1-40，2026-09 追加）** 等 |
| **P2**（健壮性 / 体验 / 性能） | **42** | 切集无互斥、`_restoring` 无 finally 黑屏、章节串集、缩略图 LRU 失效、密码明文、代理缓存永不命中、下载残留清理等 |
| **P3**（优化 / 一致性 / 死代码） | **38** | 竖屏对齐细则、死字段死代码、文案与文档漂移、性能微优化等 |
| 文档一致性 | **60+** | §2 目录树漏 11 文件、§6 漏 21~22 个测试、§4 有 6 处描述与代码不符、2 份被引用的文档不存在 |

### 0.2 建议修复优先级（按「用户可感知 × 修复成本」排序）

| 顺序 | 事项 | 涉及文件 | 成本 |
|---|---|---|---|
| 1 | 「只删视频」不再删音频（与 `VideoScanner.videoExt` 共用唯一真值） | `file_operations_service.dart:433` | 极小 |
| 2 | 空文件夹移动/复制：循环前先建目标目录 | `file_operations_service.dart:177-189` | 极小 |
| 3 | 听视频入口空列表崩溃：`_videos.isEmpty ? 0 : clamp(...)` | `audio_player_page.dart:147` | 极小 |
| 4 | 调色板风格迁移加一次性门控 | `theme_controller.dart:98-135` | 小 |
| 5 | 竖屏补齐：音量增强 + 真实倍速基准 + 播放历史 + `onSwipeCancel` | `player_portrait_page.dart` | 中 |
| 6 | 文件传输进度弹窗包 `PopScope(canPop:false)` + 路由真实出栈绑定 | `folder_actions.dart:137/161` | 小 |
| 7 | 字幕样式滑杆改「按字段 + 松手提交」，`sub-fonts-dir` 只在构造注入 | `subtitle_panel.dart` / `subtitle_service.dart:426` | 中 |
| 8 | 字幕外挂记忆失效清理 + `clear()` 复位 `_appliedMedia` | `subtitle_service.dart:267/275/388` | 小 |
| 9 | 网络存储：`_drain` 改带上限取消 + 补超时分级 + SMB 预读取消/背压（**✅ B10 已完成**，另含 P2-18 值相等与 P2-17/D4 密码加密迁移） | `webdav_client.dart:189`、`network/*` | 中 |
| 10 | 原生：`detachFd` 泄漏、抓帧 `catch(Throwable)`、`getVideos` 放后台线程（**✅ B13 已完成**，提交 `047763f`，含 P2-31 原生 `release()` 一并收口） | `MediaInfoHelper.kt`、`MainActivity.kt` | 小 |
| 11 | `SuperResolutionService`/`ViewSettings` 补 `ensureLoaded`；`PlayerOptionChip` 改 `playerPanelScheme` | 3 处 | 小 |
| 12 | `PlaybackProgressService.load` 加 try/catch；`AsyncSerialQueue` 错误不再静默 | 2 处 | 小 |
| 13 | 文档同步（§2 漏文件、§6 漏测试、§4 六处不符、两份不存在的引用文档） | `docs/archive/ARCHITECTURE.md` | 小 |

---

## 1. P0 —— 数据丢失 / 必然崩溃

### P0-1 「只删文件夹内的视频文件」实际会删除音频文件

- **证据**：`lib/services/file_operations_service.dart:433-437` 的 `_deletableExt` 除视频扩展名外还含 `.mp3 .m4a .aac .flac .wav .ogg .opus`；`deleteFolder(deleteWholeFolder:false)`（`:406-420`）对每个直接子文件跑 `_isVideoFile()` 命中即 `entity.delete()`。
  而弹窗正文对用户的承诺是：`lib/widgets/file_operations_ui.dart:283`「仅删除该文件夹内的视频文件，其它文件不会被删除。」（多选版 `:287-288` 同义）。
- **交叉证据**：扫描器 `lib/services/video_scanner.dart:13-26` 的 `videoExt` **不含任何音频扩展名**——即「扫描器不认为音频是视频，删除器却认为它是视频」。
- **触发**：长按任一含音频的文件夹（如 `movie.mkv` + `OST.flac`）→ 删除 → 保持「删除所有文件」不勾 → 确认。
- **影响**：音频文件被永久删除（无回收站），且与用户刚刚读到的承诺相反。
- **建议**：删除集合与 `VideoScanner.videoExt` 共用同一份唯一真值（音频要么移出，要么把文案改成「视频与音频文件」并同步 §4.30 定稿表）；`_isVideoFile` 改为按扩展名精确取值而非对整条路径 `endsWith`。
- **严重度**：P0（不可恢复的数据丢失 + 违背显式用户同意）。
- **复核状态**：已由我本人读源码逐行确认。

### P0-2 移动/复制空文件夹：源被删除、目标不创建，且提示「成功」

- **证据**：`lib/services/file_operations_service.dart:177` `final entries = _collect(src, isDir: isDir);`，而 `_collect`（`:302-335`）**刻意不把源根目录本身放进列表**（注释见 `:301`）；`:189-197` 的目标目录 `create()` 只在**循环体内**执行。空目录 → `entries` 为空 → 循环体一次都不执行 → `$dest/$name` 从未创建。`move` 分支 `:227-230` 仍无条件 `Directory(src).delete(recursive: true)`，`return target`（`:238`）返回一个不存在的路径，调用方照常提示成功。
- **触发**：移动/复制一个空文件夹（或只含符号链接的目录——`_collect` 只收 `Directory`/`File`，`Link` 被静默丢弃，`:318-332`）。
- **影响**：移动 = **源文件夹被物理删除且目标不存在**（文件夹凭空消失，App 报成功）；复制 = 什么都没发生但报成功。
- **建议**：对目录源，循环之前无条件 `await Directory(target).create(recursive: true)`（或在 `entries.isEmpty` 时单独建根目录）；符号链接要么显式支持，要么在 UI 明示「链接不会随文件夹移动」。
- **严重度**：P0（数据丢失）。
- **复核状态**：已由我本人读源码逐行确认。

### P0-3 调色板风格持久化被「旧值迁移」吞掉：选前 8 个风格之一，重启后风格变了

- **证据**：`lib/theme/theme_controller.dart:98-107` 的 `_legacyVariantMapping` 有 8 项（旧 `DynamicSchemeVariant` 序号，来自初始提交 `eab43f3`），`load()` `:128-135` 对 `variantIndex < 8` **无条件**走旧映射；而 `setVariant` `:157-163` 写入的是**新** `FlexSchemeVariant.index`。
  两套序号只在 index 0 与 ≥8 时一致：存 1(fidelity)→读回 3(neutral)、存 3(neutral)→读回 5(expressive)……（`FlexSchemeVariant` 实际声明序为 tonalSpot0/fidelity1/monochrome2/neutral3/vibrant4/expressive5/content6/rainbow7/fruitSalad8…）
- **触发**：外观页选中「保真型/单色型/中性型/鲜艳型/鲜明型/柔和型/彩虹型」任一 → 退出 App → 重启。
- **影响**：用户选择被静默改写；与 §4.7「勿改枚举顺序（持久化 index）」的持久化契约冲突。`test/theme_controller_test.dart` 只断言默认值与标签表，没有 set→load 往返用例，所以没拦住。
- **建议**：迁移加一次性门控（新 key 或版本标记），迁移完成后按新枚举写回；补一条「set 全部风格 → load 往返一致」的用例。
- **严重度**：P0（持久化数据被破坏，功能可见错误）。
- **复核状态**：已由我本人用 `git show` 追到初始提交确认迁移来源，并读源码确认读写两侧不匹配。

### P0-4 听视频：播放列表为空时进入即崩溃（`ArgumentError`）

- **证据**：`lib/pages/player/audio_player_page.dart:146-148`
  ```dart
  _videos = filtered.isEmpty ? (widget.playlist ?? const []) : filtered;
  _currentIndex = _videos.indexWhere((v) => v.path == _path).clamp(0, _videos.length - 1);
  ```
  空表时等价 `(-1).clamp(0, -1)`；Dart `num.clamp` 文档要求 `lowerLimit.compareTo(upperLimit) <= 0`（`dart-sdk/lib/core/num.dart:405-416`），VM 实现在 `lowerLimit > upperLimit` 时抛 `ArgumentError`。
- **触发**：从**任何不传 `playlist` 的入口**进入播放页后点「听视频」——`main.dart:274`（外部打开视频）、`home_page.dart:349`（速览「最近播放」）、`home_page.dart:364`（打开链接）、`playback_history_page.dart:43`（历史记录）、`network_browser_page.dart:105`（网络存储）、`bili_play_launcher.dart:49/92`（番剧在线/UGC 直链）。
- **影响**：`initState` 抛异常，页面构建失败；「听视频」对整类来源完全不可用。
- **建议**：`_currentIndex = _videos.isEmpty ? 0 : _videos.indexWhere(...).clamp(0, _videos.length - 1);`，并在空表时禁用切歌 UI（该文件 `:265`、`:289` 已有 `if (_videos.isEmpty) return;` 守卫，说明作者本意即允许空表）。
- **严重度**：P0（必崩）。
- **复核状态**：已由我本人读源码确认调用点与 clamp 语义；**未真机复现**（本轮不跑编译/测试）。

---

## 2. P1 —— 功能错误 / 资源泄漏

### 2.1 播放器：竖屏页与横屏页的能力漂移

> ✅ **本组（P1-1 ~ P1-6）已由 B4 修复并真机验收**（2026-09）：根因收敛进
> `pages/player/player_session_state.dart` 的 `PlayerSessionState`（横屏创建、注入竖屏，
> 禁止全局单例），详见 `02-remediation-batches.md` §3 的 B4 记录与 `ARCHITECTURE.md` §4.33。
> P2-9 按决策 D5 作废（语义色豁免）；P1-6 的「PiP 生命周期」半条**前提有误**（见该条注释）。

> 结构性根因：`player_page.dart`（3574 行）与 `player_portrait_page.dart`（2241 行）有 **54 个同名私有方法**（弹幕装载、缩略图、切集、手势、指示器等），两页各自维护一份实现 → 长期漂移。已核实多处漂移实例。

- **P1-1 竖屏完全没有「音量增强」**（`player_portrait_page.dart:643-684`）
  `_onVerticalSwipe` 右半屏只做 `_volume` 0–100 钳制 + `setSystemVolume`；全文件对 `volumeBoost` / `_mpvVolume` / `volume-max` / `boosting` / `displayVolumePercent` **零命中**，`_showIndicator`（`:630`）连 `boosting` 形参都没有（横屏 `player_page.dart:1283` 有）。
  **后果不止「功能缺失」**：横屏已把共享 Player 的 `volume-max` 设为 `100+cap` 且 `_mpvVolume` 可达 150%，切到竖屏后该增益**无人能调回**——竖屏下滑只降系统音量、mpv 增益不变；上滑时 `_volume` 已 100 导致 clamp 后零位移，**手势彻底空转**；而指示器仍显示「100%」，即 **UI 谎报响度**（实际 150%）。
  可达路径：①「视频方向=锁定竖屏」→ 设完即 100% 时间在竖屏页；②自动模式下的竖拍/竖屏视频；③横屏底栏「选择屏幕」。已由独立复核确认（含 mpv 音量在全仓仅 `player_page.dart` 写入的核对）。
  **建议**：抽页面局部共享的增强状态对象（横屏页在 push 竖屏页时像 `chapterTracker`/`subtitleController` 一样传入），**禁止做成全局单例**（§4.1）；竖屏页 `_showIndicator` 补 `boosting` 形参；退出复位仍由横屏页独占（§4.8）。

- **P1-2 竖屏倍速基准取自设置而非播放器真实倍速 → 长按结束把用户倍速复位成 1.0x**
  `player_portrait_page.dart:413-415` `_speed = _settings.rememberSpeed ? _settings.lastSpeed : 1.0;`（注释写「跟随共享播放器当前设置」，但没读 `_player.state.rate`），而「倍速记忆」默认关（`player_controls_settings.dart:244`）。
  触发：横屏把倍速调到 2.0x → 切竖屏 → 长按倍速后松手 → `_onLongPressEnd` 用 `_speedBeforeLongPress`（=1.0）`setRate` → **2.0x 被静默复位**；同时倍速面板高亮也显示错误的 1.0x。
  **建议**：竖屏从共享 Player 取真实 rate 初始化（或由横屏页把当前 `_speed` 作为构造参数传入），两边共用同一 `ValueNotifier<double>` 避免第二份真值。

- **P1-3 竖屏切集不写播放历史、不回填时长**（`player_portrait_page.dart:837-915`，全文件无 `PlaybackHistory` 引用；对照 `player_page.dart:1899-1900` / `:3021-3029`）
  后果：竖屏连续看多集时，除进入播放器那一集外全部不进历史，首页「最近播放」与历史记录页看不到。

- **P1-4 竖屏 `onSwipeCancel: () {}` 空实现**（`player_portrait_page.dart:1913`）
  §4.8/§7 明确要求「滑动中途加入第二指先撤销 seek」，横屏有实现（`player_page.dart:1441-1450`），竖屏空转 → 误触 seek 不撤销，落点停在误触位置。

- **P1-5 竖屏「已播/剩余时长」未钳制负值**（`player_portrait_page.dart:1846`）
  横屏显式清零并注释原因（`player_page.dart:3111-3120`）；`formatDuration(-5000)` 经 `~/`+`%` 会得到 **"59:55"**（`formatters.dart:29-38`）。

- **P1-6 竖屏叠层：缩略图策略、杜比检测、PiP 生命周期未对齐**（P3 级表现，归此处便于成组修复）
  竖屏切集不触发杜比检测（横屏 `player_page.dart:1863/1940`）；竖屏页无 `didChangeAppLifecycleState`（进 PiP 不隐藏控制层）；竖屏底栏未传 `height`/`trackLeftInset`，与横屏对齐基准不同（`portrait_player_bottom_bar.dart:150-157` vs `player_bottom_bar.dart:132-141`）。
  - ⚠️ **2026-09 更正：本条「PiP 生命周期」的前提是错的**。本项目**设计上不做「按 Home
    自动进画中画」**（用户明确；`DeviceServices.setAutoPipEnabled` 全仓零调用，按 Home 一律
    退后台 + 暂停），画中画只有一个入口——顶栏槽位／「更多」里的**显式**按钮。所以真正要做的
    只是「退后台隐藏控制层、回前台恢复」这条与横屏对齐的行为，**不是**"进 PiP 要隐藏控制层"。
    按 Home 进小窗这个功能**不做、也不加开关**（决策 D11）。

### 2.2 播放器：并发与异常路径

- **P1-7 文件传输进度弹窗可被系统返回键关闭 → 传输在无 UI 下继续，结束后二次 pop 弹掉页面**（`widgets/folder_actions.dart:137-150`、`:161-165`）
  `DialogRoute(barrierDismissible: false)` 只挡遮罩点击，`FileOpProgressDialog` 内部**没有 `PopScope`**——项目自己在 §4.19 已确认「单靠 `barrierDismissible` 挡不住返回键」，门禁弹窗才额外包了 `PopScope(canPop:false)`（`privacy_policy_dialog.dart:71`）。
  后果：①`token.cancel()` 从未执行，复制/移动在后台继续且无取消入口；②结束后 `handle.dismiss()` 因 `_open` 仍为 true 而 `pop()` **当时的栈顶路由**（可能是文件管理页，也可能是用户期间 push 的播放页）——即 **§7 第 1876 行声称已修好的「第二次 pop 弹掉页面本身」并未真正关闭**。
  **建议**：弹窗内容包 `PopScope(canPop:false)`（或把返回键转成取消）；`_open` 的失效绑定到路由真实出栈（`push(...).whenComplete(...)`），而不是只依赖按钮回调。

- **P1-8 切集/重开同一媒体：外挂字幕丢失**（`subtitle_service.dart:267-269`、`:388-394`）
  `reapplyForMedia` 首行 `if (_appliedMedia == mediaPath) return;`，而 `clear()` 清空轨道却**不复位 `_appliedMedia`**。列表循环且播放列表只有 1 个视频时，EOF → `playFirst` → `openAndRestore` 重新 open（mpv 会丢弃所有 `sub-add` 外挂轨道）→ reapply 被早退 → 外挂/自动加载字幕消失，退出播放器重进才恢复。
  **建议**：`clear()` 内 `_appliedMedia = null;`（或在 open 处递增「媒体代数」令牌，由 open 而非路径决定是否需要 reapply）。

- **P1-9 字幕外挂记忆无失效清理 → 同名字幕永久失联**（`subtitle_service.dart:275-287`、`:290-295`、`:328-375`）
  `videoSubs` 非空即**跳过**同名扫描，对记忆里的路径直接 `sub-add` 且无存在性校验；对照弹幕侧有失效清理（`danmaku_service.dart:343-352`）。用户删/改字幕文件后再播同一视频 → 静默无字幕且永不重扫。这正是 §4.11 记录的「记忆死路径」教训，只在弹幕侧落实。
  **建议**：`reapplyForMedia` 逐条 `existsSync()` 校验，失效则 `removeImportedSubtitleFor` 并允许回落同名扫描。
  - **✅ 已修（B5，2026-09 真机验收）**：新增纯函数 `utils/subtitle_memory.dart` 的
    `partitionSubtitleMemoryPaths`（存在性由调用方注入，可单测），`reapplyForMedia` 挂载前分流、
    失效项从设置删除、**全部失效时照常回落同名扫描**（删掉字幕文件再放回去能重新自动加载）。
    见 `docs/archive/ARCHITECTURE.md` §4.34。

- **P1-10 字幕样式滑杆每次事件全量 `applyAllSettings`（16 次 mpv 属性串行写 + 写盘），且含 §4.10 明文禁止的运行时 `sub-fonts-dir` 写入**
  `subtitle_panel.dart:698-702/740-753/807-822/1094-1121/1328-1343`（含 RGBA 四通道）→ `subtitle_service.dart:398-437`。其中 `:426-430` 在「默认字体」分支写 `sub-fonts-dir='/system/fonts'`，而紧邻的 `:421-423` 注释自称「避免运行时写该属性」——与自身注释及 `docs/archive/ARCHITECTURE.md:556` 三方冲突。
  真正有功能风险的路径：本次 Player 以自定义字体目录初始化（`player_page.dart:462-471`）→ 用户在面板点「默认字体/清除字体目录」→ 再动任意样式滑杆 → 运行时改掉注入目录 → 命中 §4.10 记录过的「libass 字体缓存被破坏、字幕整条消失」。
  **建议**：拆成按字段 apply；滑杆改「松手提交」（复用弹幕面板 `_CommitSliderTile` 的纪律）；`sub-fonts-dir` 归入构造期注入，或写入前比对上次已写值。
  - **✅ 已修（B5，2026-09 真机验收）**：「运行期写 `sub-fonts-dir`」那一半**已由 B0.5 修掉**（字体目录构造期注入）；
    性能那一半改为**按字段写入**：新增纯函数件 `utils/subtitle_style_properties.dart`
    （`SubtitleStyleField` 14 字段 → mpv 属性表），滑杆每个事件只写**该字段那一条/那几条**属性
    （原先 16 条全量串行写）。见 `docs/archive/ARCHITECTURE.md` §4.34。
  - ⚠️ **本条的「滑杆改松手提交」建议经真机否证**：用户明确「拖动过程必须实时看见变化」——
    弹幕面板的松手提交是为「一次改动触发全层 canvas 重绘会卡」专门做的优化，字幕只有一条轨道、
    没有那个压力（决策 **D12**）。**字幕的实时路径同时修掉了一个真 bug**：旧代码
    `setter(v); applyAllSettings();` 不等设置 setter（首行 `await ensureLoaded()` 会挂起），
    下发的是**旧值**——发散操作（点预设色）就表现为「点了没反应」；现已改为**先 `await` 设置落值、
    再按字段下发**，并在松手时再精确收尾一次。

- **P1-11 `reload()` 的 `_loading` 是「丢弃式」而非「等待式」**（`subtitle_service.dart:153-169`、`audio_service.dart:175-191`）
  在飞时 `return;` 立即返回，调用方（`subtitle_service.dart:296/320`、`:299-318`）却假定 `_tracks` 已最新 → 「恢复上次选中字幕」静默失败；极端时序下 `fetchTracks` 中途被 `sub-add` 打断抛错，内层 catch 把整批置为 `[]` 且再也不会有流事件纠正 → UI 显示「当前视频没有字幕」。
  **建议**：`if (_loading) return _inFlight!;`（即 §4.29 `AsyncSingleFlight` 语义，项目已有现成原语）。
  - **✅ 已修（B5，2026-09 真机验收）**：改用**新原语 `AsyncCoalescedReload`**
    （`lib/utils/async_coalesced_reload.dart`）：在跑时只登记一次「待补跑」，所有等待者拿到的是
    **不早于自己请求**开跑的那一轮，完成后一起完成。⚠️ **本报告建议的 `AsyncSingleFlight` 不够**：
    单飞让后来者 join 早已开跑的旧轮，`sub-add` 之后照样是旧快照。
    另加两条：①读轨道抛错时**保留上一份快照**而不是清空（原先清空 → UI 闪「当前视频没有字幕」）；
    ②dispose 后迟到的刷新不再 `notifyListeners`。见 `docs/archive/ARCHITECTURE.md` §4.29/§4.34。

- **P1-12 `_restoring` 恢复封层只在成功路径清除，且只 catch `AssertionError` 无 `finally`**（`player_page.dart:704-731`、`1883-1897`；`player_portrait_page.dart:853-882`）
  封层是 `Colors.black` 全屏（`player_page.dart:3658-3675`）。`openAndRestore` 抛任何非 `AssertionError`（如 `prepare` 里未包 try 的 `setRate` 抛 PlatformException、`player.platform as NativePlayer` 抛 TypeError）→ 异常逃逸 + 封层永不清除 → 视频在下面播、用户只看到黑屏转圈。
  **建议**：`finally { if (mounted && _restoring) setState(() => _restoring = false); }`，并把异常分流（已知竞态静默、其它 toast + 复位）。

- **P1-13 `ChapterTracker.load()` 无会话号**（`chapter_tracker.dart:115-131`）
  快速切集时旧集章节覆盖新集（进度条圆点/章节名错配、点击跳错位置）；`load()` 在途时退出播放器会对已 dispose 的 ChangeNotifier `notifyListeners()`（debug 断言/假崩溃日志）。
  **建议**：套 `AsyncSession`（§4.29 已列该原语，弹幕已用）+ `dispose` 后判废。

- **P1-14 缩略图引擎每帧一次 `Isolate.run` + 每帧 `DynamicLibrary.open('libmpv.so')`**（`fast_thumbnails.dart:104-107/145-149`）
  单帧 63–134ms 的解码下，固定开销不可忽略；§7 只记录了 `Isolate.run` 闭包捕获 Completer 的坑，未评估逐帧建 isolate 的成本。**建议**：长驻 worker isolate（或至少把 `DynamicLibrary.open`+符号 lookup 缓存到 isolate 外）。**待验证**：未实测固定开销占比。

### 2.3 字幕 / 弹幕 / 音频（其余）

- **P1-15 弹幕合并/去重在 B 站分段流式加载下跨批次失效**（`danmaku_service.dart:523-527` vs `:288-294`/`:370-375`）
  同一句跨批次不聚合 → 计数分裂（应 `×5` 却呈 `×3`＋`×2`）；随后一切换开关触发全量重灌，计数又变——同一份数据两种呈现。**建议**：`appendBiliDanmaku` 先并入 `_rawEntries` 再对全量重跑 `_effectiveEntries`。
  - **✅ 已修（B6，2026-09 真机验收）**：`appendBiliDanmaku` 并入 `_rawEntries` 后按**全量**重算
    生效集，并用新的 `DanmakuScheduler.replaceAll()` 整体替换秒桶（**不动锚点与代数** → 不清屏、
    不重放，流式「先到先显」不变）。重算走 `AsyncCoalescedReload`（当前轮 + 一轮补跑），
    isolate 往返期间切集按 `_loadSession` 判废。见 `docs/archive/ARCHITECTURE.md` §4.11「生效集流水线」。
- **P1-16 合并/去重流水线跑在主 isolate**（`danmaku_service.dart:288-294`，两次全量 `sort` + 每条 3 个 `RegExp` 归一化）
  解析特意放进 `compute`，真正的瓶颈却留在 UI 线程；10 万条量级会卡顿，且每加一个屏蔽词就全量重跑。**建议**：整条链也放 isolate（返回值是纯 `List<DanmakuEntry>`，天然可跨 isolate）；正则提升为文件级 `final`。
  - **✅ 已修（B6，2026-09 真机验收）**：整条链抽成纯函数件 `utils/danmaku_pipeline.dart`
    （`effectiveDanmakuEntries` + `compute` 顶层入口 `runDanmakuPipeline`，入参是一条 record），
    重算一律 `await compute(...)`；两条建议全部落实——`danmaku_dedup.dart` 的 3 条归一化正则
    提升为**文件级 `final`**（原先每条弹幕重建 3 个 `RegExp`）、`danmaku_blocklist.dart` 的关键词表
    **每次过滤只归一化一次**。isolate 失败回落主 isolate、再失败原样装载（宁可漏过滤也不能没弹幕）。
- **P1-17 原生 `getVideos` 在 UI 线程执行**（`MainActivity.kt:224-227`）
  - **✅ 已修（B13，2026-09 真机验收）**：`getVideos` 改为与相邻 7 个通道方法一致的 `Thread{}` + `runOnUiThread`，并补 `catch (e: Throwable)` → `result.error("GET_VIDEOS_FAILED")`（错误不再逃到通道线程，Dart 侧 `home_page._load` 的 `finally` 正常复位 `_loading`）。
  同文件其余 7 个通道方法（`getVideoInfo`/`getVideoBasicMetadata`/`getMediaInfo`/`detectDolbyVision`/`getDeviceCapabilities`/`getWallpaperColors`/`mergeM4s`/`resolveVideoUri`）全部包了 `Thread{}`，唯独体量最大的 `getVideos` 没有；其内部是 MediaStore 全表 query + 逐条 `exists/length` + `.nomedia` 祖先链上溯 + `MediaMetadataRetriever` 兜底 + 可选的深度 6 全盘递归扫描。Dart 侧 `video_scanner.dart:42` 在主 isolate 发起。**后果**：库大时主线程秒级阻塞/ANR。**建议**：与相邻分支一致放 `Thread{}` + `runOnUiThread`。
- **P1-18 `detachFd()` 后 `pfd.close()` 是空操作 → fd 永久泄漏**（`MediaInfoHelper.kt:36/43`、`:102/107`、`:219/224`）
  - **✅ 已修（B13，2026-09 真机验收）**：三个入口收敛到 `withMediaInfo`，且修法是**调整顺序而非换机制** —— `MediaInfo()` 构造放在 `detachFd()` **之前**（构造失败时 fd 尚未易主，`pfd.close()` 是真关闭 → 消灭这条确定性泄漏），构造成功后才 `detachFd()`、此后 fd 只由 `mi.Close()` 关闭。
  - ⚠️ **修法本身踩过坑（必须记住）**：第一版写成「不 detach、把 `pfd.fd` 交给 `MediaInfo` 再用 `pfd.close()` 关」→ **双关同一个 fd → 真机进播放页/媒体信息页必闪退**；第二版改用 `Os.dup()` 中转 → `Os.dup` 返回 `FileDescriptor` 而 `Open` 要 `int`、`FileDescriptor.fd` 非 Kotlin 可见 API → **编译期 `Unresolved reference 'fd'`**。两条结论见 §3 B13 与 `MediaInfoHelper.withMediaInfo` 的函数头注释。
  `ParcelFileDescriptor.detachFd()` 的契约就是「交出所有权、本对象不再负责关闭」，唯一真正的关闭点是 `mi.Close()`（`:89/128/251`），而它在 `MediaInfo()` 构造抛异常的分支**永不执行**。触发：缺 `libmediainfo.so`/`libzen.so`（如 x86 模拟器）或 native 加载失败。**后果**：每次调用泄漏 1 个 fd → 累积到 `EMFILE` 后列表封面全空、字幕/音轨导入失败等大范围次生故障，日志只有一句「MediaInfo native lib unavailable」。**建议**：改用 `MediaInfo.Open(pfd.fd, …)` 由 `pfd.use{}` 托管，或失败分支显式关 fd。**待编译验证**：MediaInfo Java 绑定是否有 `Open(int, String)` 重载。
- **P1-19 抓帧路径只捕 `Exception`，漏掉 `OutOfMemoryError`**（`MainActivity.kt:1643`）
  - **✅ 已修（B13，2026-09 真机验收）**：`catch (e: Exception)` → `Throwable`（不再让 Dart Future 永久挂起）；`bitmap`/`cover` 的 `recycle()` 全部移进 `finally`（任一对象恰好回收一次）；`cropCover` 增加 **4K 降级**（2 的幂降采样到长边 ≤ 768 再裁剪，目标封面只有 384×216）——这是「抛 Error」的实际触发源。
  同分支内 `getMediaInfo`/`detectDolbyVision` 用的是 `catch (e: Throwable)`，此处不一致。抛 `Error` 时 `result.success()` 永不执行 → Dart 的 Future **永久挂起**（封面卡片卡在「生成中」）；且 `bitmap`/`cover` 的 `recycle()` 不在 `finally` 里。**建议**：改 `Throwable` + `finally` 回收 + 4K 源降级。

### 2.4 网络存储（系统性回落）

- **P1-20 WebDAV 忽略 Range 时用无上限 `drain()` 丢弃 → 静默下载整个文件**（`webdav_client.dart:127/139/143`，`_drain` 实现 `:189-195`）
  直接违反 §4.28/§7 明文铁律「超限/错误响应丢弃一律用带上限的 `drainStreamCapped`，不能 drain」。**触发**：任何不支持 Range 的 WebDAV 服务器上 seek 一次（代理每次分段请求都会调 `openStream(offset:)`）。**后果**：GB 级下载后丢弃。**建议**：换 `drainStreamCapped` 或 `stream.listen(null).cancel()`。
  - **✅ 已修（B10，2026-09 真机验收）**：`_drain` → `_discard`，**3 处调用点全部**改走带上限的 `drainStreamCapped`（2MB 封顶即取消订阅）。测试用本地 `HttpServer` 推 32MB 正文并断言**服务端真正推出去的字节数 < 8MB**（旧的无上限 `drain()` 会推完 32MB）。规范落点为 `docs/archive/ARCHITECTURE.md` §4.28/§4.35。
- **P1-21 整个网络存储子系统未接入 `utils/retry_policy.dart`，WebDAV/FTP 几乎没有任何超时**（`webdav_client.dart:124/178/179`、`ftp_client.dart:288-290/191-197`）
  全仓 `withRetry|sendGet|NetworkTimeoutTier` 命中全在 B 站/弹弹Play/Wyzie/短链——`services/network/**` **零命中**。FTP 的 `Socket.connect(timeout:)` 只管建连，控制连接应答与数据连接 `await for` 无读超时。**后果**：黑洞主机上「测试连接」永久转圈、浏览永久 loading、代理响应永久挂起 → mpv 无限缓冲。
  - **✅ 已修（B10，2026-09 真机验收）**：WebDAV 的 PROPFIND 走 `withRetry` + 12s 分级超时（每次尝试**新建 Request**）+ 响应体读超时；FTP 的控制连接**每条应答**、被动数据建连、目录列表读取全部有超时（`Socket.connect` 从写死 15s 改为 `NetworkTimeoutTier.api`）。两条额外纪律：**「测试连接」单次尝试**（`RetryPolicy.none`——重试会把 12 秒拖成 ~37 秒，验收 2 直接不成立）、**流式只加超时不重试**。黑洞地址 12 秒内报超时已由单测与真机双重验证。SMB 不接本工具（`smb_connect` 自带 `waitResponseTimeout`+5 次重试，应用层只在 `smb_pipeline` 给每块读取加 30s 上限）。§4.28/§4.35。
- **P1-22 SMB 并发预读管线无取消/无背压，出错后整文件累积在内存**（`smb_client.dart:107-167`）
  `StreamController` 没有 `onListen/onCancel/onPause`；消费者取消（mpv seek/退出、代理 `_limitBytes` 提前 close）后 4 个 worker 仍读到文件末尾、句柄不释放；出错时 `deliver()` 因 `isClosed` 直接 return 但 `completed[i] = data` 仍执行 → 累积整文件 → **OOM**。**建议**：`onCancel` 置取消标志并跳出、清空缓存、出错即停其它 worker、用 `onPause/onResume` 限在途块数。
  - **✅ 已修（B10，2026-09 真机验收）**：管线抽成可单测的纯逻辑件 `lib/services/network/smb_pipeline.dart`，**三条建议全部落实**：`onCancel` 停手 + 清 `completed`、出错即停其它 worker（并清缓存后 `addError`）、窗口 `maxBlocksAhead` 限在途 + `onPause` 一块不读。窗口按「离下一个待输出块的距离」判定（待输出块的属主恒在窗口内 → **不会死锁**，单测跑「暂停 → 恢复 → 必须读完」）；另给每块读取加 30s 超时。§4.35。
- **P1-23 fork 的 `_readQueue` 无 `catchError` + 不匹配响应不读 body + 读错误静默返回 -1**
  `third_party/smb_connect/lib/src/connect/smb_transport.dart:163`（对比同文件 `:713` 的发送队列有 `catchError`）→ 任一帧解码异常**永久毒化读队列**，此后所有响应不再分发，直到全部超时；`:187-189` mid 不匹配只 `print` 而不读走 payload → socket 流错位；`smb_file_stream.dart:136-138` 读错误返回 `-1`，`smb_random_access_file.dart:164-180` 在 `res<=0` 时既不推进位置也不报错 → **无限重发同一个 SMB READ**（上层 `_pipelinedStream:137` 无超时）→ SMB 播放永久转圈，且 `SmbClient.isConnected()` 恒 true 导致代理长期复用死连接。
  **建议**：fork 侧给 `_readQueue` 加 `catchError` 并把异常交给在途 completer；不匹配响应必须读走 body；恢复 `checkStatus`；应用侧给每次 `raf.read` 包超时。
  - **✅ 已修（B10，2026-09 真机验收）**：fork 升到 **`0.0.9-mk.2`**（`FORK.md` 补丁 6~8）：①`_readQueue` 末尾挂 `catchError`；②新增 `_skipFramePayload()`——**mid 不匹配的迟到响应必须读走 body**；③解码失败把异常交给该帧等待者 + `_failAllInFlight` 让其它在途请求立刻失败 + 断开这条连接（帧内游标位置不可知，**宁可让上层重连也不静默错位**）；④读失败按 NT 状态抛错、OK/EOF 返回 0（**不再返回 -1**——调用方 `position += res` 会位置倒退 → 无限重发同一个 READ），`length <= 0` 不发 0 长度读请求，错误/取消时 `finally` 关句柄；⑤`readInto` 无进展立即 `break`、`read()` 只返回真正读到的字节（旧实现到末尾会交出一整块零字节）；⑥应用侧每块读取 30s 超时（P1-22 的管线）。⚠️ **「恢复 checkStatus」只恢复到读路径**（0.0.9 里整份 `_checkStatus` 已被上游注释，全量恢复会改变所有命令的错误语义）——这条有意取舍写在 `FORK.md` §7。§4.35。

### 2.5 文件管理 / 扫描（其余）

- **P1-24 取消/失败留下与完整文件同名同扩展名的半成品，无临时名、无清理、无回滚**（`file_operations_service.dart:256-257`、`:263-269`、`:291-298`、`:212-216`）
  直接写最终文件名（无 `.part`），取消时 `output.close()` 把已写部分冲刷成正式文件。**后果**：MediaStore 会索引这个截断 mp4（缩略图/时长/播放全异常）；移动部分失败后源与半成品并存，重试还会生成 `X (1).mp4`。**建议**：写 `target.part`，全部成功后再 `rename`；失败路径删除半成品。
- **P1-25 同卷**目录**移动从不走 `rename`**（`file_operations_service.dart:160` 仅 `!isDir` 时尝试）
  与 §4.30「同卷 `rename` 原子秒移」不符 → 移动 20GB 剧集目录退化为整目录复制 + 删源，可能因空间不足失败。**建议**：目录也先试 `Directory(src).rename(target)`，仅 `FileSystemException` 时退化。
- **P1-26 `onMutated()` 位于 try 之外 + `scanVideos` 无错误处理**（`folder_actions.dart:267-268/359-360/513-514`、`video_scanner.dart:42-49`、`home_page.dart:91-125`）
  原生 `getVideos` 抛错时：删除/移动**已经成功**但成功提示不出现（用户重复操作）；首页 `_load` 因 `_loading` 只在成功分支复位而**永久转圈**且错误被吞。**建议**：`_load` 用 `try/finally` 复位 + 错误态；`scanVideos` 错误结构化。
- **P1-27 `VideoInfoService` 内存缓存无任何失效入口**（`video_info_service.dart:33-36/47-62`；`cache_manager_service.dart:54-62`）
  同路径换文件后显示上一个文件的封面/时长；「缓存管理 → 清除列表封面缓存」对列表**无可见效果**；`_fetchInfo` 无 try/catch（对比 `_fetchBasicMetadata:72-88` 有），一次原生异常即让该卡片**永久**只显示占位图。**建议**：补 `clearCache([path])`、文件操作后按新旧路径精准失效、`clearAll` 一并清 Dart 缓存、`Image.file` 加 `errorBuilder`。
- **P1-28 `PinnedFoldersSettings` 写入口未 `await ensureLoaded()`**（`pinned_folders_settings.dart:47/66/82/96`）
  违反 §7「设置单例 load 竞态 → setter 首行 await」约定（同类 `media_scan_settings.dart:87-166` 是正确范例）。冷启动早期固定可能被 `_load` 的 `clear+addAll` 抹掉；`retainExisting` 以 `existsSync` 判存活 → SD 卡/U 盘临时卸载时固定项被**永久删除并持久化**。**建议**：写入口补 `await ensureLoaded()`；区分「确定不存在」与「当前不可访问」。
- **P1-29 移动已固定文件夹 → 固定丢失（改名会保留、移动不会）**（`folder_actions.dart:267` vs `:413-427`）
  移动后旧绝对路径被 `retainExisting` 摘掉，新路径从未 `setPinned`。**建议**：移动成功且 `wasPinned` 时把新路径继续固定。

### 2.6 壳层 / 设置 / 状态（收敛遗漏）

- **P1-30 `SuperResolutionService` 是全仓唯一绕过 `ensureLoaded` 的单例**（`main.dart:142` 调 `load()`；服务无 `ensureLoaded`）
  `load()` 在 `_remember == false` 时把 `_mode/_quality` 强写回 `off/balanced` → 用户刚选的超分档位可能被启动读盘覆盖，表现为「设了没用」。
- **P1-31 `ViewSettings` 无 `ensureLoaded`，所有 setter 首行未 await `load()`**（`view_settings.dart:102-138`、`:140-209`）
  `load()` 尾部无条件覆盖 `_fields/_videoFields/_viewMode`；冷启动后立即改字段/视图模式会被读盘结果清掉（内存与磁盘不一致、界面回跳）。
- **P1-32 `playerPanelAccent` 约定漏掉被 11 个面板复用的 `PlayerOptionChip`**（`player_option_chip.dart:34`）
  仍用裸 `Theme.of(context).colorScheme.primary` → 浅色主题下暗底对比不足，正是 §7「暗色面板直接用 theme primary」那条坑的**未收口回归**（字幕/弹幕面板已改对）。**建议**：改 `playerPanelScheme(context)` 并把胶囊纳入 `player_panel_theme_test.dart`。
- **P1-33 `PlaybackProgressService.load()` 无 try/catch，脏数据会把 `_loadFuture` 永久钉死**（`playback_progress_service.dart:48-57`）
  `:53` 的 `Map<String,int>.from(jsonDecode(...))` 一旦抛，`ensureLoaded() => _loadFuture ??= load()` 缓存的是一个 **rejected Future** → 此后每次 `ensureLoaded` 立即失败、`_loaded` 恒 false → 本次进程内进度恢复与保存**全部失效**。对照 `PlaybackHistoryService._decode:157-176` 有完整防御。**建议**：try/catch + 失败回落空表并置 `_loaded = true`。
- **P1-34 `AsyncSerialQueue.add` 的 Future 被丢弃 → 串行写盘失败静默消失**（`async_serial_queue.dart:19-29` + `playback_progress_service.dart:87-91`）
  调用方只 `await _writeQueue.idle`，任务的 `completer.completeError` 无人监听 → 未处理异步错误；§4.29 的语义「错误抛给各自调用方」被用成了「异常吞掉」，用户以为已保存、重启丢进度。**建议**：调用方 `unawaited(...catchError(记日志))`。
- **P1-35 权限永久拒绝无 `openAppSettings` 出口**（`home_page.dart:128-152`、`:415-423`）
  只有「已授予/未授予」两态，被拒后仅 `setState` → Android 上 `permanentlyDenied` 后点按钮毫无反应、无任何引导 → 本地播放器等于不可用。**建议**：区分两态并给系统设置入口。
  - **✅ 已修（B14，2026-09，提交 `0fee9a6`）**：`_grantPermission` 判 `status.isPermanentlyDenied` → 权限页主按钮换成「去系统设置开启」（`openAppSettings`，失败降级 toast），并留「我已开启，重新检查」；`_load` 成功时复位该标记。§4.42。
- **P1-36 `requestLocalNetworkPermission()` 全仓零调用**（`device_services.dart:153-161`）
  而 `AndroidManifest.xml` 已声明 `ACCESS_LOCAL_NETWORK`（注释写明 Android 16+ 需运行时权限）→ 网络存储与自建弹幕服务器在 Android 16+ 可能被系统静默拦截且无提示、无补救路径。**建议**：在连接前申请，拒绝时 toast + 系统设置入口。
  - **❌ 本条为误报（B14 核实，2026-09 更正）**：`requestLocalNetworkPermission` **并非零调用**——`services/network/network_repository.dart`（连接前）、`services/danmaku_network_service.dart`（自建弹幕服务器搜索/拉取，2 处）共 **3 处真实生产调用**，由特性提交 `13757e0` 落地（早于体检）。故 B14 **不动代码**；`docs/archive/ARCHITECTURE.md` §7.1 中按「全仓零调用」记录的对应行同步作废。
- **P1-37 调色板风格持久化（见 P0-3）**、**P1-38 `CommonListController.reset()` 清掉在飞标志**（`common_list_controller.dart:129-139`）
  后者导致搜索页/索引页连续操作时旧结果覆盖新结果（违反 §4.29 防重入）。

---

## 2.6.1 【真机追加 · 2026-09】播放链路两个用户可感知缺陷（**已修，待真机复验**）

> 来源：用户真机播放一部内置「Dolby TrueHD 英语轨（ID 2，MLP FBA / `A_TRUEHD` / 8 channels / 3077 kb/s）
> + AC-3 国语轨（ID 3，6 channels / 384 kb/s）+ 4 条 PGS 中文字幕（ID 4~7，`S_HDMV/PGS`）」的 MKV 时报告：
> ①切到英语（TrueHD）音轨后**完全不输出声音**；②四条 PGS 字幕**无论选哪条都不显示**。
> 两条都已定位到应用层可修的部分并完成修改（`docs/archive/ARCHITECTURE.md` §4.32），本节按本报告的格式补录证据。

### P1-39 切到 Dolby TrueHD（8 声道）音轨后完全无声，且应用侧没有任何提示（静默失效）

- **证据（应用层）**：`lib/services/audio_service.dart` 的 `AudioController` 只订阅了
  `player.stream.tracks`；全仓对 `player.stream.log` / `player.stream.error` **零订阅**
  （`grep` 仅命中 `assert` / `FlutterError.onError` 等无关位置）。media_kit 已按
  `logLevel: MPVLogLevel.error`（默认）把 mpv 的错误日志做成 `PlayerLog` 流
  （`third_party/media_kit/lib/src/player/native/player/real.dart:2069-2120`，
  `prefix` 为 `ad`/`ao`/`cplayer`/`vd`/`ffmpeg`/`stream`），**应用侧没有任何消费者**。
- **真因（内核仓库，2026-09 查明并已修）**：自编内核
  `azxcvn/libmpv-android-video-build-thumbnail` 的 `buildscripts/flavors/default.sh`
  用 `--disable-decoders` + 逐个白名单开解码器，音频段只开了
  `aac/ac3/eac3/dca/flac/…`，**没有 `mlp`/`truehd`** → 该音轨没有任何解码器，音频链直接
  建不起来，mpv 只在错误日志里报错。
  ⚠️ **踩坑提醒**：同为该文件里有 `--enable-demuxer=truehd`，`strings libmpv.so` 里能搜到
  字符串 `truehd` —— 那只是**解封装器**的名字，**不能**据此认为解码器已编入（本次审计
  初判就被它误导过）。正确判据是解码器短名各出现 1 次
  （`hdmv_pgs_subtitle`/`truehd`/`mlp`），且**不能**用 codec 长名检索
  （`--enable-small` 会把 `long_name` 编掉，会误判成"没编入"）。
- **附带限制（解码器到位后仍需知道）**：Android 上 media_kit 写死 `ao=opensles`
  （`real.dart:2453`），而 **OpenSL ES 输出只支持双声道**
  （`ao_opensles.c`：`mp_chmap_from_channels(&ao->channels, 2)`）→ TrueHD 会被 mpv
  下混成 stereo 播放：**能出声，但不是多声道**。要真多声道需换 AO
  （`audiotrack`/`aaudio`）并重编内核（OpenSL ES 在 mpv 0.42 已被移除），属后续独立项。
- **触发**：播放含 TrueHD 8 声道轨的视频 → 音频面板选中该轨（本机为「英语」）→ 无声；
  切回 AC-3（本机为「中文」）立即恢复。
- **影响**：用户明确选择的高规格音轨**完全不可用且无任何反馈**；由于 UI 仍显示该轨为
  选中态，用户只能反复点按，无法判断是「文件问题」还是「播放器问题」。
- **修法（两侧都已实施）**：
  1. **内核侧（根治，已完成）**：`flavors/default.sh` 的**解码器/解封装器/解析器全部打开**
     （`--enable-decoders`/`--enable-demuxers`/`--enable-parsers`，删掉上游那份手写白名单）。
     ⚠️ 演进过程留档（都是真踩的坑）：①第一次只加 `--enable-decoder=mlp`，出包实测
     `ff_truehd_decoder = 0` —— `mlpdec.c` 里 `ff_mlp_decoder`（`AV_CODEC_ID_MLP`）与
     `ff_truehd_decoder`（`AV_CODEC_ID_TRUEHD`）是**两个独立解码器**、各有独立的
     `#if CONFIG_*_DECODER`，**不是别名**；②中途还写过 `--enable-decoder=hdmv_pgs_subtitle`
     （那是 codec **日志名**，configure 组件名是 `pgssub`）→ configure 直接报
     `Unknown option` 构建失败。最终**改为全开**，从根上消掉「白名单漏项 = 静默失效」
     这一整类问题。最终 commit **`b5da4f2`**（CI run #8），产物 4 个 ABI 验证通过：
     解码器符号 **161 → 523 个**。已替换进 `third_party/media_kit_libs_android_video/android/jars/`
     （md5 逐一核对一致；旧 jar 可从 git 历史 `1603a95` 恢复；无需改任何 Dart 代码，§4.9）。
     **体积代价（实测 arm64）**：`libmpv.so` 20.75 → 24.68 MB（+3.93 MB），jar 8.71 → 10.9 MB（+2.19 MB）。
  2. **应用侧（兜底 + 可诊断）**：`AudioController` 在**用户显式换轨后的 4 秒窗口**内订阅
     `Player.stream.log`（窗口限制避免播放中途的瞬时音频日志误触发换轨），用纯函数
     `isAudioPlaybackFailureLog(prefix, text)`（只认音频相关前缀 + 失败特征词）命中后，
     延时 600ms 读 `audio-params` **复核**（`no`/空 = 音频链真的没建起来；读属性异常一律
     判为未失败，避免误切），确认失败则用 `pickFallbackAudioTrack` 选一条**不同编码**的
     轨道（TrueHD→AC-3，内置优先于外部）自动切过去并 toast 说明原因；无路可退时也只 toast。
     `clear()`/`selectTrack()` 复位防重入与探测窗口。
- **严重度**：P1（功能静默失效，用户可感知且无从判断）。
- **复核状态**：**已真机验证回退生效**（用户实测：TrueHD 轨确实放不出来 → 自动回退到可用
  声道且能正常出声）；根因（内核缺解码器）由本人在内核仓库 `flavors/default.sh` 源码中
  确认；**新内核已在产物层面验证并替换进项目**（4 个 ABI 符号全绿），
  `flutter analyze` 无新增问题、1151 个测试全过。**剩最后一步真机复验**（换新内核后
  TrueHD 是否出声）。
- **真机复验要点**：①**旧内核**：切 TrueHD → 应出现「当前音轨无法播放，已自动切换到…」
  且有声音（**已通过**）；②**换新内核后**：切 TrueHD → 应直接出声、**不出现**该提示；
  ③只有一条音轨的视频切轨后无提示、无副作用。

### P1-40 内嵌 PGS 字幕选哪条都不显示（真因：内核 ffmpeg 白名单漏了 PGS 解码器；另修掉一处运行期 `sub-fonts-dir` 违规）

- **真因（内核仓库，2026-09 查明并已修）**：`buildscripts/flavors/default.sh` 的
  `--disable-decoders` 白名单里，字幕段开了 `ssa`/`ass`/`dvbsub`/`dvdsub`/`srt`/`webvtt`/…，
  **唯独没有 PGS 解码器（组件名 `pgssub`，codec 日志名才是 `hdmv_pgs_subtitle`）** →
  PGS 轨能列出、能选中，但**没有任何解码器可解，完全不渲染**（同文件里的文本字幕不受影响，
  所以症状表现为"只有 PGS 不显示"）。
  修法：**内核改为解码器/解封装器/解析器全开**（最终 commit `b5da4f2`，CI run #8；
  解码器符号 161 → 523），产物已替换进
  `third_party/media_kit_libs_android_video/android/jars/`（详见 P1-39 的修法说明）。
  顺带把上游白名单同样漏掉的 `sami`/`microdvd`/`mpl2`/`xsub`/`realtext`/`jacosub`/`pjs`/
  `dvb_teletext` 等字幕解码器一并补齐。
- **附带修掉的真实违规（运行期写 `sub-fonts-dir`）**：`lib/services/subtitle_service.dart`
  的 `applyAllSettings()` 默认字体分支在**运行期**执行
  `setProperty('sub-fonts-dir', '/system/fonts')`（紧邻注释却自称「避免运行时写该属性」），
  直接违反 `docs/archive/ARCHITECTURE.md` §4.10 与 §7 已写明的铁律；该方法在**每次 open 之后**
  （`reapplyForMedia` → `applyAllSettings`）与**每次切换字幕轨道之后**
  （`selectTrack` → `applyStyleOverride`）都会执行。
  位图字幕（PGS/DVD/DVB）也走 libass（mpv 只对 ASS 原生字幕直通，其余先由 FFmpeg 转成 ASS
  的 `DRAWING` 指令，见 `sd_ass.c` 的 `lavc_conv` 分支），所以这条路径打坏的是**全部内嵌
  字幕**。**真机复验表明它当时不是（唯一）根因**（改完仍不显示 PGS），但它是必须收口的
  违规——否则内核修好后仍会被它打坏。
  修法：新增纯函数 `resolveSubtitleFontInjection()`（`lib/models/subtitle_font_injection.dart`）
  **永不返回 null**：用户字体齐备 → 注入用户目录；否则注入 `kSystemFontsDir='/system/fonts'`
  + `kSystemFontName`；`applyAllSettings()` 删除运行期 `sub-fonts-dir` 写入，只按
  `auto` / 用户族名写 `sub-font`。
- **影响**：内嵌 PGS 字幕整体不可用（本机表现为 4 条 PGS 全灭）。
- **严重度**：P1（功能错误，用户可感知；附带文档明令禁止的回归）。
- **复核状态**：根因由本人在内核仓库源码中确认；**「位图字幕也走 libass」为读 mpv 0.41
  源码确认**；**新内核已在产物层面验证**（4 个 ABI 的 `ff_pgssub_decoder` 各 1）**并替换进项目**。
  **剩最后一步真机复验**（换新内核后 PGS 是否显示）。
- **真机复验要点**：①**换新内核后**播放该 MKV → 依次选中 4 条 PGS 字幕 → **应能显示**；
  ②外挂 ASS/SRT 字幕仍正常且样式滑杆可用；③导入自定义字体后重进播放器 → 字幕按新字体渲染
  （§4.10 不回归）。

---

## 3. P2 —— 健壮性 / 体验 / 性能（摘要）

> 每条格式：问题（证据）→ 建议。

**播放器**
1. `_openPortraitPlayer`/`_openAudioPlayer` 无重入保护（`player_page.dart:2667/2785`）→ 200ms 转场内连点两次会 push 两层，EOF 在被盖住的页面上执行。加 `if (_portraitActive) return;`。
2. 切集无并发互斥：`_isSwitchingVideo` 只用于抑制 EOF，不阻挡第二次切集（`player_page.dart:1861`、`player_portrait_page.dart:837`）→ 两个 `openAndRestore` 并发操作同一 Player。入口加守卫或用 `AsyncSerialQueue`。
3. 缩略图 LRU「访问即刷新」只做在 `getVideoFrameAt`，`peekFrame`/`peekNearestFrame`（拖动热路径）只读不刷（`device_services.dart:511-518` vs `551-590`）→ 高频查看的帧反被先淘汰，重新解码 63–134ms。
4. `_frameFailAt` 失败冷却表无上限、无过期清理（`device_services.dart:650`）→ 随拖动位置线性增长的慢性泄漏。
5. 缩略图气泡淡出 150ms/卸载 250ms/文档写 150ms 三处不一致，且不可见期间仍挂载转圈（`player_thumbnail_preview.dart:34-36/63-74`）。
6. `PlayerStatusBar` 横竖各一套定时器全在跑（`player_status_bar.dart:81-104`，时间 30s/电量 60s/网络 5s/网速 1s）→ 竖屏期间不可见页每秒 2 次 setState + 2 次通道调用。
7. 横竖两层 canvas 弹幕同时挂载（`player_page.dart:3178` + `player_portrait_page.dart:1895` 共享 controller）→ 每条弹幕 2 次 `TextPainter` 排版 + 2 次图片录制。建议只向可见层 `addDanmaku`。
8. `_markCompleted` 的「已看完」标记可能被更晚的 `_saveProgress` 覆盖（`player_page.dart:2950-2968` vs `:3030-3038`）。**待验证**：取决于 EOF 时 mpv `time-pos` 是否严格小于 `duration`。
9. `player_speed_indicator.dart:164`、`player_resume_indicator.dart:133`、`player_gesture_indicator.dart:48` 仍写死 `0xFF4FC3F7`（§5.3 第 5 条）。**待验证**：约定是否只约束面板外壳内容。

**字幕 / 弹幕**
10. 输入安全：`dandan_models.dart:56/57/116/117/118`、`danmaku_server.dart:70/71` 用裸 `as String?`/`as num?` 强转，与文件头自述「类型不符回退默认值」矛盾 → 自建服务器返回 `"type":1` 会抛 TypeError 导致整条响应失败，且 `danmaku_server_settings` 靠 catch 回退会**静默丢弃用户全部自建服务器**。
    - **✅ 已修（B6，2026-09 真机验收）**：`dandan_models.dart` 加 `_asString`/`_asDouble`、
      `danmaku_server.dart` 加 `_asBool`（`1`/`"true"` 算真、判不了回退默认值），`fromJson` 全部改宽松读取。
      单个坏字段只影响它自己，不再抛 `TypeError` 打断整条响应或让大 `catch` 丢掉整份服务器列表（§4.11）。
11. `dandan_play_api.dart:36` 的 `http.Client` 从不 close，且每进一次播放器（`danmaku_service.dart:134`）、每开一次网络面板（`player_danmaku_network_panel.dart:73`）各新建一个。
    - **✅ 已修（B6，2026-09 真机验收）**：`DandanPlayApi.close()`（幂等，**只关自建**的 client）→
      `DanmakuNetworkService.dispose()` → `DanmakuController.dispose()` 与网络弹幕面板 dispose
      （注入的服务不代关）逐级释放（§4.11）。
12. `dandan_play_api.dart:123` 的 `utf8.decode` 在 try 之外且无 `allowMalformed` → `FormatException` 逃出类契约（应 `DandanApiException`）。
    - **⏳ 未修（B6 未包含）**：B6 的条目清单（计划书 §3 P2-12）只写了
      `dandan_models`/`danmaku_server` 的裸强转，本条**不在 B6 范围**内，故按「禁止顺手修复」未动。
      仍待处理，建议并入后续批次（B12 下载/字幕页或单列一条）。
    - **✅ 已修（B14.6，2026-09 真机验收）**：本条的**真因与描述不同**——`_decode` 里其实早有
      `allowMalformed` + try，漏的是类内**另外三处裸 `jsonDecode`**（`searchAnime`/`getComments`/
      `matchDanmaku`）：`_decode` 对非 JSON 响应「按成功文本返回」，随后那三处裸解析直接把
      `FormatException` 抛给调用方（调用方只 catch `DandanApiException`）。新增 `_parseJson` 收口，
      三处全部改走它（§4.39）。
13. 网络弹幕搜索无会话号，且 `_loading` 期间静默吞掉新搜索（`player_danmaku_network_panel.dart:113-140`）→ 用户以为「搜索没反应」。
    - **✅ 已修（B6，2026-09 真机验收）**：去掉 `|| _loading` 的静默 return（键盘搜索键/历史胶囊/
      连按搜索按钮都照常发起）+ `AsyncSession` 判废旧响应 → 结果永远属于**最后一次**输入的关键词；
      loading 期间搜索按钮**仍在位**（只多一个转圈），按住不放也不会「没反应」（§4.11）。
14. `DanmakuManualMemory`/`SubtitleSettings` 记忆映射无上限、每次全量序列化写盘（`danmaku_memory.dart:61-79`、`subtitle_settings.dart:410-421`）；网络弹幕落盘 XML 无清理（`danmaku_network_service.dart:230-241`，缓存管理页只管列表封面）。
    - **✅ 已修（B14.6，2026-09 真机验收，按用户拍板 D20）**：①弹幕记忆**上限 200 条**、
      外挂字幕记忆**上限 100 条**，超限淘汰**最久未用**（`get()` 命中即刷新 LRU，写入后 `trimToLimit`）；
      ②网络弹幕 XML 的清理入口 = **缓存管理页新增一项「网络弹幕缓存」**（`CacheCategory.networkDanmaku`，
      `cacheSizeBytes`/`clearCache` 只删文件保目录）（§4.39）。
15. 本地弹幕装载每次列举整目录 + 整文件读 + 新建 isolate（`danmaku_service.dart:399-409`）。
    - **✅ 已修（B14.6，2026-09 真机验收，按用户拍板 D21）**：改为**按视频名推算文件名逐个直读**
      （`danmakuCandidateNames` + `existsSync`），只有直读全落空才列举整目录兜底（§4.39）。
16. 弹幕设置「速度/不透明度/区域/行高」每次 `onChanged` 都写盘 + 全层热更新（`danmaku_settings.dart:221-280`）→ 应松手落盘（同面板其他项已用 `_CommitSliderTile`）。
    - **✅ 已修（B5，2026-09 真机验收）**：四条滑杆全部改为 `_CommitSliderTile`（拖动只改本地预览、
      松手才提交 → 1 次写盘 + 1 次全量重绘），并给它补了 `hint` 支持；已无人使用的 `_SliderTile` 删除。
      ⚠️ 本条的「松手才提交」**只适用于弹幕**：字幕样式滑杆恰恰相反，必须实时（决策 D12，见 P1-10 的批注）。
17. 网络存储密码**明文**存 SharedPreferences（`network_connection_settings.dart:4-5/86-92`）而 `ARCHITECTURE.md:173` 写「密码加密」；B 站凭据已走 secure storage，此处退回明文。**建议**：走 Keystore 或至少同步修正文档。
    - **✅ 已修（B10，2026-09 真机验收）**：按决策 **D4** 引入加密——新增 `NetworkPasswordStore` 抽象（生产实现走 `flutter_secure_storage`，Android Keystore / EncryptedSharedPreferences），连接清单 JSON 改用 `toJson(includePassword: false)`（**连 `password` 字段都不写**）；**老账户明文迁移**照 D4 要求落地（读旧明文 → 加密写回 → 重写清单去明文）。两条硬约束：**迁移失败/读取失败一律保留明文、绝不丢密码**（`_plaintextFallback` 记录退化为明文存储的连接，下次启动再试迁移）；单测覆盖「清单无明文 / 重启恢复 / 迁移成功 / 迁移失败回退 / update 覆盖 / remove 清除」。§4.35。
18. `NetworkPath` 缺 `==`/`hashCode`，而代理用 `Map<NetworkPath,int>` 与 `path == entry.primaryPath`（`network_streaming_proxy.dart:266-278/318-321`）→ **缓存永不命中**，每个 HTTP 请求都重新查远端大小，`registerStream` 传入的 `fileSize`/`mimeType` 形同虚设。
    - **✅ 已修（B10，2026-09 真机验收）**：`NetworkPath` 补 `==`/`hashCode`（按 `value`，并声明「与其它类型不相等」）。根因值得记一笔：注册时 `knownSizes[primaryPath] = fileSize` 存的是**对象 A**，而请求路径由 URL 段重新 `NetworkPath.from` 构造**对象 B** → 标识比较永不相等。单测：值相等/`hashCode`/Map 命中 + 代理侧断言「注册了 `fileSize` 后 `getFileSize` 调用次数为 0、注册的 `mimeType` 生效」。§4.35。
19. FTP 忽略 `OPTS UTF8 ON` 结果、列表与命令一律 UTF-8（`ftp_client.dart:157/191-197/271-273`）→ GBK 服务器（IIS/老 Serv-U）中文文件名彻底不可用。
    - **✅ 已修（B10，2026-09 真机验收；决策 D7）**：登录探测 `OPTS UTF8 ON`——应答 200 → 该连接一律 UTF-8；**不认该命令时不写死结论**（照「不支持 → GBK」写死会把「实际是 UTF-8、只是没实现该命令」的服务器改成乱码），而是先按**严格 UTF-8 试解**目录列表，解不通才判定 GBK 并记住；此后该连接的**列表与命令共用同一套编码**（只列表按 GBK 解、命令仍发 UTF-8 会永远 `550`）。控制连接改为「按字节攒行、整行解码」（GBK 多字节不能流式凑）。新增直接依赖 `charset: ^2.0.1`（纯 Dart）。单测断言**控制连接收到的原始字节**确实是 GBK。§4.35。
20. FTP `isConnected()` 恒真（`_closed` 只在 `close()` 置位），远端断开后死连接被代理长期复用（`ftp_client.dart:30/204-210` + `network_streaming_proxy.dart:309-316`）。
    - **⏳ 未修（B10 未包含）· 部分缓解**：本条不在 B10 条目清单内，按「禁止顺手修复」未动 `isConnected()` 的语义。**但 B10 的「重试必须先保证连接可用」顺带缓解了最坏后果**：`_withControlRetry` 在控制连接超时/断开时即作废并重连（只因 `isOpen` 分辨不出死连接，故不能依赖它）。仍待处理：`NetworkClient.isConnected()` 对 FTP/SMB 都可能说谎，代理据此复用死连接的问题仍在。
21. PROPFIND 响应体无体积上限（`webdav_client.dart:179`）→ 超大目录可 OOM。
    - **⏳ 未修（B10 未包含）**：B10 给 `_propfind` 加了**超时**（P1-21）但没有加体积上限（`readBodyCapped`）——按「禁止顺手修复」保留原样。仍待处理：超大目录的 PROPFIND 响应仍可把内存吃满（12s 超时只能间接限制）。
22. 网络浏览页无会话号，旧响应可覆盖新列表（`network_browser_page.dart:54-94`）→ 「父目录标题 + 子目录内容」。
    - **⏳ 未修（B10 未包含）**：不在 B10 条目清单内。同类修法已有现成原语（`AsyncSession`，§4.29 C1），可并入后续批次。
23. 代理 `_ensureServer` 无在飞去重（`network_streaming_proxy.dart:99-106`）→ 并发注册可 bind 两个 HttpServer，前一个端口与订阅进程级泄漏。
    - **⏳ 未修（B10 未包含）**：不在 B10 条目清单内。可照 `AsyncSingleFlight`（§4.29 C1）或一个「在飞 Future」字段收口。

**文件管理 / 扫描**
24. 首页每次文件操作/下拉刷新整页闪空（`home_page.dart:91-125/411-431`），且 `_load` 可重入无去重 → 违背 §4.29 C2「刷新不闪空」；旧扫描结果可能覆盖缓存。
25. `VideoCard` 无 key、`didUpdateWidget` 不感知 `video.path` 变化（`video_card.dart:68-79/81-90/229-230`）→ 改名/移动后列表显示**错误的缩略图**（A 的封面 + B 的文件名），且 `Image.file` 无 `errorBuilder`。
26. `scanVideos(scanSettings: unfiltered)` 的「静态无过滤」实例会被 `ensureLoaded → load()` 用持久化黑白名单污染（`media_scan_settings.dart:48/73-84` + `video_scanner.dart:37`）→ 白名单模式下**无法添加任何新目录**（先有鸡还是先有蛋）。
27. 「只删视频」不递归，与树状模式的**聚合** `videoCount` 语义冲突（`file_operations_service.dart:408` vs `video_scanner.dart:243-268`）→ 树里显示 20 个只删掉顶层 3 个。
28. 投屏发现无并发保护：并发 `startDiscovery` 覆盖引用导致 UDP/定时器泄漏；弹窗 await 期间 dispose 后订阅永不取消（`cast_service.dart:26-40` + `cast_device_dialog.dart:53-65`）。
29. LAN 服务器 `_serve` 异常分支二次 `close()` 可逃逸为未处理异步异常；`discoverLanIp` 取「第一个站点本地地址」在多网卡（热点/VPN）下会给出电视不可达 URL（`lan_media_server.dart:166-172/29-40`）。

**下载 / 超分 / 更新 / 听视频**
30. 下载写盘失败路径：`sink.close()` 二次 await 必抛 → `client.close()` 被跳过（HttpClient 泄漏）；循环不检查 `done` 仍读完整段响应；半截 `.m4s` 残留（`download_task.dart:319-343`）。
    - **✅ 已修（B12，2026-09 真机验收）**：`_downloadToFile` 重写为异常安全——`client.close()` 进 `finally`、sink 只在 `finally` 里**安静关闭一次**（吞掉自身异常，不覆盖真正的失败原因）；监听 `sink.done`，写盘一失败下一块就抛「写入文件失败（磁盘空间或权限）」，不再把整段响应读完。单测：目录不可写 → 任务失败且假 client 的 `closed == true`。§4.37。
31. 删除/清除任务不清理临时与半成品；合并失败会**截断已有成品 mp4**（输出名恒为 `'$title.mp4'`）且原生未 `release()`（`download_task.dart:228-249`、`download_manager.dart:125-157`、`MainActivity.kt:649-724`）。
    - **✅ Dart 侧已修（B12，2026-09 真机验收）**：①合并改为**先写 `{id}.merge.mp4` 中间文件、成功后再改名到成品**，失败删中间产物、**原成品一个字节都不碰**；②成品名走 `FileOps.uniqueName` 避让（`X (1).mp4`），同名标题的不同集/重复下载不再互相覆盖；③新增 `deleteTempFiles()`（`.video.m4s`/`.audio.m4s`/`.merge.mp4`），`remove()` 与 `clearFinished()` 都调，且**等这次 `run()` 停手再删**（`awaitStopped()`，否则在途循环被 unlink 后继续写）。§4.37。
    - **⏳ 原生侧一半留给 B13**：`MainActivity.kt` 的 `mergeM4s` 失败分支仍不 `release()` muxer/extractor（B13 条目已列）。
    - **✅ 原生侧一半已修（B13，2026-09 真机验收）**：`mergeM4s` 的 muxer 与两个 extractor 改在 `finally` 中无条件 `release()`（`stop()` 在「没写过任何样本」时会抛，用 `started` 标志 + `runCatching` 兜住），失败分支不再整条泄漏资源；`catch` 放宽到 `Throwable`。至此 P2-31 两侧全部收口。
32. 响应无 Content-Length 时进度失真（新下载恒 0%、续传跳到阶段末），`download_task.dart:316-327`。
    - **✅ 已修（B12，2026-09 真机验收）**：新增 `downloadTotalBytes(resp, startBytes)`——`Content-Length` → `Content-Range` 的 `/total` → -1；**-1 时进度停在阶段起点**（UI 走不确定进度条），不再拿「已存在字节数」当总量。单测锁定四种来源组合与「续传只有 Content-Range 时逐步推进、不跳阶段末」。§4.37。
33. `merging` 状态暂停无效（`download_task.dart:147-153`）→ 按了没反应、随后自己变「完成」。
    - **✅ 已修（B12，2026-09 真机验收）**：新增 `canPause`（只认 pending/downloading），`pause()` 在合并中是**空操作**；下载管理页把合并中的暂停按钮**置灰** + tooltip「合并中，无法暂停」（验收允许的第二种口径）。顺带修掉「等待中任务暂停被跳过 → 队列仍会启动它」。§4.37。
34. 听视频返回无 pop-once 守卫（`audio_player_page.dart:452-455/477-482`）→ 快速返回两次会把下层播放页也弹掉（§7 同类坑）。
    - **⏳ 未修（不在任何批次清单内）**：本条既不在 B12 条目清单里、也不在 B13~B16 的清单里 → 按「禁止顺手修复」未动。修法很小（pop-once 守卫），可在 B14 或单独立项时收口。
    - **✅ 已修（B17，2026-09 真机验收）**：`AudioPlayerPage._exit()` 首行加 pop-once 守卫
      （`if (_exiting) return;`）——里面有 `await _saveProgress()`，await 窗口内连按两次返回会
      重入第二次 `pop()`，把下层播放页一起弹掉（§4.38）。
35. 字幕搜索 Enter 绕过 `_busy`，旧响应可覆盖新结果（`subtitle_download_page.dart:63-107/173`）。
    - **✅ 已修（B12，2026-09 真机验收）**：搜索改 `AsyncSession` 会话号裁决——Enter 与按钮都**不吞**新搜索（静默 return 才是「功能坏了」），**只有最新会话**能写结果/复位转圈，「重新搜索」主动 `invalidate`。单测覆盖「连按两次回车取最后一次关键词」与「旧响应不写结果也不提前关掉转圈」。§4.37。
36. 字幕批量下载期间改结果列表 → `RangeError` + 按钮永久卡死（`subtitle_download_page.dart:122-136`，`sub= _results[i]` 在 try 之外、`_downloading=false` 无 finally）。
    - **✅ 已修（B12，2026-09 真机验收）**：`_download` **先对选中项做快照**再循环（列表被新搜索整表替换也不会越界），`_downloading` 复位移进 `finally`。附：本批真机反馈的「搜索中按钮内转圈与底色同色看不见」也一并修掉（显式 `colorScheme.onPrimary`，§4.37）。
37. `update_service.dart:137-147` 未接入 §4.28（裸 `http.Client().get().timeout(30s)`、无重试、无体积上限）。
38. 设备信息页解码器清单全量 `for` 构建 + 每次击键重建（`device_info_page.dart:404/96-113/340`）；同页 `license_page.dart:88-93`。
    - **✅ 已修（B14，2026-09，提交 `0fee9a6`）**：①`_filtered` 结果按「查询词 + 筛选档」缓存（`_decoders` 变化时作废）；②页面改 `CustomScrollView`，清单表头与本体分离，本体走 `SliverList.builder` 只构建可见项；`license_page` 同族一并改懒构建。§4.42。
39. `main.dart:289-308` 每次 build 新建 `AppTheme.light()/dark()/amoled()`（各含一次 HCT 派生），无缓存 → 拖字号滑杆时上百次整 App 重建 + 主题派生。**待验证**：单次耗时，release 可能仍亚毫秒。
    - **✅ 已修（B14，2026-09）**：按「seed / mode / variant / fontFamily / fontWeight」五元组判等缓存 light+dark（五个输入缺一不可），输入未变直接复用。§4.42。
40. 播放历史 `_persist()` 未串行化（`playback_history_service.dart:148-154`）→ 并发落盘顺序不定，磁盘可能是较早快照。
    - **✅ 已修（B14，2026-09）**：对齐 `PlaybackProgressService` 的 §4.29 写法——快照调用时同步生成 + `AsyncSerialQueue` 串行 + `unawaited(add().catchError(记日志))` + `await idle`；新增 `flushPendingWrites()` 供退出前落盘与测试等待排空。§4.42。
41. `RawThumbImage._decode` 无 `catchError`、`instantiateCodec` 未 `dispose`（`raw_thumb_image.dart:41-70`）。
    - **✅ 已修（B14，2026-09）**：`ImmutableBuffer` / `ImageDescriptor` / `Codec` 在 `finally` 逐个 `dispose()`（`ui.Image` 归调用方）；解码链末尾补 `catchError`。⚠️ **报告原文的「无 catchError」部分失准**：`_decodeInto` 在体检时（提交 `5ca0ef2`）就已有 `try/catch`，「codec/descriptor 未释放」才是真缺陷。§4.42。
42. `MarqueeText` 在 build 中写状态、滚动时长固定 4s 不随文本长度归一化（`marquee_text.dart:74-82/37`）。
43. `AppFrameObserver` 全局单例持 Route 引用、`isPlayerTop` 不释放（`app_frame.dart:82-131`）。**待验证**：是否真会与 Navigator 栈漂移（推演未构造出反例）。

**哔哩哔哩（计划书 B11 点名、本摘要版 §3 未展开的两条，补记于此以便对号）**

- **P2-5 清晰度面板乐观高亮与真实档位脱节**（`player_quality_panel.dart` + `player_page.dart` 的 `_switchQuality`）：面板点的档先乐观高亮，但切换失败时回退到 `widget.currentQn`——那是**开面板那一刻**的快照（连切两档后已过时，A→B 成功后切 C 失败会把高亮跳回 A）；成功但服务端因权限回落到别的档时，高亮也不跟着改（一直在谎报用户点的那一档）。
  - **✅ 已修（B11，2026-09 真机验收）**：`onSelect` 改为返回**切换后的真实 qn**（`BiliMedia.currentQn` = 服务端实际给的 `playUrl.quality`）：成功钉真实档、失败回**切换前**那一档，并补 `didUpdateWidget` 同步。真机复验时用户追加口径（**D19**）：基准索要 1080P、服务端向下取最接近的可用档，因此「点没权限的更高档 → 高亮回到 1080P」是**设计内行为**；并要求「回落到的档等于当前在播档时**不要重开流**」→ 已实现（只纠正高亮 + toast 说明）。§4.36。
- **P2-13 `BiliBangumiService` 自建无 Cookie/无指纹的 `BiliHttp` + `BiliHttp` 无 `close()`**（`bili_bangumi_service.dart:13-17`、`bili_http.dart:30`）：每次进番剧详情/索引/搜索页（以及播放启动器补拉季详情、下载服务）各 new 一个 `BiliHttp` → 各带一个 `http.Client` 连接池且**从不释放**；同时这些请求不带登录 Cookie 与设备指纹（比 `BiliVideoService` 更易被风控）。
  - **✅ 已修（B11，2026-09 真机验收）**：`BiliHttp` 新增 `_ownsClient` + 幂等 `close()`（**只关自建的**，注入的归调用方；另加测试用 `clientFactory` 注入口）；`BiliBangumiService` 缺省 `http` 改为 `BiliAccount.instance.http`（Cookie + 指纹一体、不新建连接池）。
  - **✅ 同族另一处也已收口（B11 追加，经用户同意）**：`BiliDownloadService` 自建的短链 `http.Client`（`bili_download_service.dart:48-55` `_linkClient`）——同样「每次进视频/弹幕下载页漏一个且不关」，但不在 B11 条目清单内，先报备后由用户拍板在本批一并修：新增幂等 `close()`（只关自建的）+ `linkClientFactory`（测试观察）+ 两个下载页 `State.dispose` 调用。

---

## 4. P3 —— 优化 / 一致性 / 死代码（摘要）

> **收口状态（2026-09）**：用户拍板后，本池中「未认领」的条目已分给三批并全部完成——
> **B14.5**（§3 第 20/21/22/23/28/29/37 条）、**B14.6**（§3 第 12/14/15 条）、
> **B17**（协议/编码两条 + 听视频六条 + 其余五条 + 通知文案）。**剩余**：文档/注释漂移（→ B15，必须最后）、
> 死代码与性能微优化（→ B16，可做可不做）、以及两条**明确不做**（FTP Windows/IIS LIST、备用密钥注释，
> 见 `docs/archive/ARCHITECTURE.md` §7.1）。

- **死代码**：`lib/services/fullscreen_state.dart`（3 行墓碑注释，全仓无 import，自称「可安全删除」）；`utils/playback_restore.dart:136-184` `restorePlaybackPosition` 无调用方；`fast_thumbnails.dart:110-140` `grabImage`/`clearNativeCache` 无调用方；`network_streaming_proxy.dart:88-97` `stop()` 全仓仅测试调用；`utils/player_gestures.dart:104` `isVolumeBoosting` 无调用方；`network_connection.dart:35/90` `lastConnected` 只读不写；`_StreamEntry.fileSize` 死字段；`bili_fingerprint.dart:145`/`bili_account.dart:242` `resetForTest()` 全项目无调用者。
- **竖屏对齐细则**：底栏 `height`/`trackLeftInset` 未传；无 `didChangeAppLifecycleState`（PiP 不隐藏控制层）；切集不触发杜比检测；`dispose` 不释放自建 `_subtitleController`/`_audioController`（当前分支不可达）、（`player_portrait_page.dart:378-380/1809-1811`）。
- **输入/边界**：`bili_bangumi_url.dart:9-11` 正则无边界（`step2` 被当 `ep2`、`SS2`/`AV1` 同理）+ `bili_download_service.dart:96-99` 因「解析非空」短路导致 b23.tv 短链根本不展开；av 号在播放链路丢 `aid`（`bili_play_launcher.dart:81-82/117-121`）→ 文档 §4.16 宣称的 av 支持实际不可用；`WBI mixinKey` 永不过期（官方每日更替）；`v_voucher` 被当成功；`int.parse` 未捕获（`bili_bangumi_url.dart:50/55/65/84-85`、`webdav_client.dart:138`、`ftp_client.dart:328/345`）；`normalizeDanmakuText` 每条新建 3 个 `RegExp`。
  - **✅ 已修（B11，2026-09 真机验收）**：①令牌改为只认「**URL 路径里**（`/ep123`）」或「**整串就是令牌**（`ep123456`，数字 ≥3 位）」两种形态，BV 两侧加字母数字边界 → `step2`/`第12集 ep12 更新`/`SS2`/`AV1` 都不再算链接；②短链判据从「直接解析是否为空」改成「文本里有没有短链」（`b23.tv/av1234567` 这类巧合不再短路），且 `expandBiliShortLink` 的命中判定移到「解析出真实 URL 之后」（不再对短链本身判）；③`playBiliBvid(ctx, bvid)` → `playBiliUgc(ctx, {bvid, aid})`，**av 号走 aid 通道**、拿到真实 bvid 后优先用它；④WBI 密钥加时效（跨 UTC+8 自然日 / 超 6h / 时钟回拨 → 重取，重取失败退回旧密钥）；⑤`v_voucher` 单独判定（有凭证**且无流**）→ 报「触发风控验证」，不再显示「解析播放地址失败」。⚠️ `int.parse` 这一项**只修了链接解析这一处**（靠正则位数上限根治）；`webdav_client.dart:138` 的 `int.parse(start)` 仍未设防（不在 B11 清单内，属网络存储）；`normalizeDanmakuText` 的 3 个 `RegExp` 已在 B6 提升为文件级 `final`。细则见 `docs/archive/ARCHITECTURE.md` §4.36。
- **协议/编码**：FTP 只支持 Unix LIST（Windows/IIS 行被丢 → 目录显示「为空」）；软链名含 ` -> target`；`webdav_xml.dart:38-122` 不做 XML 实体反转义（`a&amp;b` → 404）；`dandan_play_api` 未让 `utf8.decode` 容错。
  - **✅ 已修（B17，2026-09 真机验收）**：①`stripSymlinkTarget` 剥掉 Unix 软链名尾部的 ` -> target`
    （否则拿目标路径当文件名拼远端路径，必 404）；②`unescapeXmlEntities` + 固定顺序
    `percentDecode(unescapeXmlEntities(href))`（`a&amp;b` 不再 404）。`dandan_play_api` 那条见
    §3 第 12 条（**B14.6** 已修）。
  - **⛔ 明确不做（D22，2026-09 用户拍板）**：**Windows/IIS 风格 `LIST` 行不做自动解析**，
    只在 `docs/archive/ARCHITECTURE.md` §4.35 声明「只支持 MLSD 与 Unix LIST，Windows/IIS 行跳过」。
- **分层**：`utils/subtitle_sort.dart:1` import `services/device_services.dart`，违反 §3（`utils` 应只依赖 `models`）。
- **文档/注释漂移**：`main.dart:221` 注释写「10 秒倒计时」但实现与 §4.19 都是 5 秒；`about_page.dart:59` 注释称 GitHub 地址「暂时留空」实际已用 `UpdateService.repoUrl`；`media_scan_settings.dart:208-217` 注释称「转为小写」未实现；`file_operations_service.dart:423-424` 注释称「保证不误删字幕/弹幕」与 P0-1 事实不符；`decode_settings`/`player_pressable` 两个文件完全未进 §2。
- **性能微优化**：`device_info_page` 筛选用 `for` 全量构建；多选态每帧重复整树排序（`home_page.dart:217-243/282-292` 各算一次 `_visibleNodes()`）；弹幕 `Future.delayed` 逐条调度（`danmaku_service.dart:642-654`）；`ShowDialog` 裸用未走 `showAppDialog` 共 3 处（`directory_picker_dialog.dart:10`、`bili_play_launcher.dart:126`、`audio_player_panels.dart:461`，违反 §4.5）。
- **听视频**：倍速吸附到本页档位后退出不还原（`audio_player_page.dart:137-141`）；封面取 `_durationNotifier.value ~/ 2`，切歌时该值刚被置 0 → 封面变首帧且存在跨曲竞态（`:199-207/246-260`）；定时关闭剩余时间在面板打开期间不刷新；本页档位含 3.5/4.0 与文件头注释「0.5–3.0」不一致；切歌的 `_player.open`（`:231`）**未调用 `_applyPlaybackTuning`**，违反 §4.26「每次 open 前重写调参」→ 听视频里本地↔在线切换会沿用上一档缓存/重连参数。
  - **✅ 已修（B17，2026-09 真机验收，六条全做）**：①倍速吸附记 `_entryRate`，`dispose` 时
    **用户没改过就写回原值**；②封面取帧在时长未知时先不取、等 duration 流回来补，结果按
    `_coverSession` 代数丢弃过期项；③定时剩余时间改 `ValueNotifier` + 面板 `ValueListenableBuilder`
    （面板打开期间会跳秒）；④注释改成 0.5–4.0 对齐实际档位（D23①）；⑤抽共用件
    `services/playback_tuning.dart`，切歌前 `await applyPlaybackTuning(...)` 再 `open`；
    ⑥`_exit()` 加 pop-once 守卫（§3 第 34 条）（§4.38）。
- **字幕下载页**：`_download()` 的 `_results[indices[i]]` 在 try 之外、`_downloading=false` 无 `finally`（`subtitle_download_page.dart:122-136`）→ 下载中「重新搜索」会越界抛未捕获异常且按钮永久卡死。
- **其余**：下载进度通知未节流（每 chunk `notifyListeners`，速度有 500ms 节流而进度没有）→ 整个任务列表按块重建；`WyzieApi` 的 `http.Client` 无 `close()`；解码面板点「当前已选档位」也弹「需重启应用」（`player_decode_panel.dart:45-56`）；超分 `apply` 的 `Player.platform as NativePlayer` 在 try 之外（`super_resolution_service.dart:135`）；更新弹窗 Markdown 未传 `onTapLink` → 链接点了没反应；下载文件名按「120 字符」而非 255 字节截断；下载/弹幕输出名仅按标题 → 同名集互相覆盖。
  - **✅ 已修（B17，2026-09 真机验收）**：①进度按 500ms 节流（**阶段收尾 `_flushProgress()` 补发**，
    否则节流窗口内的最终值会丢）；②`WyzieApi.close()` 见 §3（B12 同族收口）；③解码面板
    `_setMode`/`_setPreset` 首行判等返回，点当前档位不再弹「需重启」；④`as NativePlayer` 移进 try；
    ⑤`MarkdownBody` 补 `onTapLink`；⑥文件名改按 **UTF-8 255 字节**截断（不切坏多字节字符，含扩展名）；
    ⑦「输出名仅按标题互相覆盖」见 §3 第 31 条（**B12** 已用 `FileOps.uniqueName` 避让）（§4.40）。
- **安全/合规**：`dandan_play_keys.dart` 被 `.gitignore:62` 正确排除、`git ls-files` 无记录（**真实密钥未入库**，已验证），但 `:7` 注释里还明文留着备用 AppSecret1 —— 建议删除注释中的备用密钥；`requestLocalNetworkPermission` 零调用（**❌ B14 核实为误报，见 P1-36：实际 3 处调用**）；隐私文案承诺「通知权限用于推送播放状态/下载进度/更新提醒」但全仓无 `Permission.notification.request()`，实际只有前台服务保活通知（文案强于实现，B17 已改文案 D23②）；网络存储密码明文（见 P2-17，B10/D4 已改加密）。
  - **✅ 文案已修（B17，2026-09 真机验收，按用户拍板 D23②）**：隐私政策与用户协议两处正文的通知条款
    改为「**仅用于听视频后台播放的播放状态通知（前台服务保活）**，不用于推送下载进度/更新提醒/营销通知」，
    与实现一致（不改权限请求）。`dandan_play_keys.dart:7` 的备用密钥注释 → **用户拍板不管**
    （D23③，文件本身未入库）；`AppFrameObserver`（§3-43）→ **不验证也不修**（D23④）。
    两条都写进 `docs/archive/ARCHITECTURE.md` §7.1「明确不做」。
- **`analysis_options.yaml`**：只 include `flutter_lints` 且未关闭任何规则 → 8 处 `print(`（`network_streaming_proxy.dart:142/207/260/273/291`、`smb_client.dart:82/97/144`）必然触发 `avoid_print`；`analyzer.exclude` 里的 `参考项目/**` 无对应根目录（无效项）。文档 §7 第 1740 行「`--fatal-infos` 默认 on」**待验证**（公开资料显示默认 off，不建议据此改 CI）。

---

## 5. 文档 ↔ 代码一致性（`docs/archive/ARCHITECTURE.md` 为唯一契约）

### 5.1 §2 目录树

- **代码存在但文档缺失（11 个）**：`widgets/` 下 `app_dialog.dart`、`cast_device_dialog.dart`、`directory_picker_dialog.dart`、`file_operations_ui.dart`、`file_selection_ui.dart`、`folder_actions.dart`、`privacy_policy_dialog.dart`（7 个，该段实际 24 个只列 17）；`services/decode_settings.dart`；`services/fullscreen_state.dart`（墓碑文件）；`pages/player/views/player_pressable.dart`；`pages/player/views/player_quality_panel.dart`（§4.15 已列、§2 漏，自相矛盾）。
- **路径/描述错误**：`:328` 的 `utils/app_dialog.dart` 描述写成「见 `widgets/app_dialog.dart` 说明」——该 widgets 文件**不存在**（全树唯一没有自身描述的 dart 条目）。
- **树形结构错乱 5 处**：`models/` 连续两个 `└──`（`:129`/`:130`）；`pages/settings/` 下的 `subtitle/` 缩进成子目录（`:319`，实为兄弟）；`services/bilibili/pb/` 缩进与 `bilibili/` 同级（`:192`，读者会解析成 `services/pb/`）；`marquee_text.dart` 注释列错位（`:231`）；`utils/app_dialog.dart`/`anime4k_patch.dart` 备注列少 1 空格（`:328-329`）。
- **无「文档有、代码无」的幽灵文件**（抽查通过）。

### 5.2 §6 测试清单

- **文档列出但文件不存在**：0（112/112 全部存在）。
- **文件存在但文档未列（21~22 个）**：`bili_app_sign_test`、`bili_credential_test`、`bili_episode_picker_page_test`、`bili_fingerprint_test`、`bili_short_link_test`、`bili_wbi_test`、`bilibili_user_test`、`equalizer_preset_test`、`equalizer_settings_test`、`ftp_parser_test`、`http_byte_range_test`、`media_scan_settings_test`、`network_connection_test`、`network_connection_settings_test`、`network_mime_types_test`、`network_path_test`、`network_streaming_proxy_test`、`player_bottom_bar_test`、`speed_dial_fab_test`、`update_service_test`、`webdav_xml_test`（+ `test/pb_test_helper.dart` 为辅助文件，建议在 §6 注明）。
- **描述与实际断言不符 8 处**：§6:1615「进度条样式」（**代码中不存在该设置**）、1615「倍速不在顶栏动作之列」（无断言）、1700「筛选胶囊无数字文本/两行布局」（无断言）、1702「标准型独占首行」（只断言 5 个文案存在）、1626「32MB LRU」（只验容量淘汰最旧，无近期性）、1676「从 `data.url` query 解析 Cookie」（实际从 `token_info`+`cookie_info`，文档过时）、1629「胶囊 5 秒窗口」（测试注入 50ms，默认值无断言）、1618「面板二级导航」（用测试自造 mock 面板，真实面板未覆盖）。

### 5.3 §4 章节与代码不符（8 处；其中第 8 条已由 B11 修掉）

1. **§4.5/§4.11 引用了不存在的 API**：`PlayerPanelPage.bottomHeightFactor`（`player_panel.dart:6-11` 只有 `title`/`body`）+「网络弹幕搜索页用 0.82」（全仓 `0.82` 零命中；真实入口是 `showPlayerBottomPanel(heightFactor:)`，竖屏页 `:1294-1295` 注释明确「不再单独抬高」）。
2. **§1:64 与 §2:203 说「`checkForUpdate` 仍开发写死」**，而 §4.20:1136 与代码（`update_service.dart:57-108` 真抓 GitHub releases/latest）相反。
3. **§4.7 说 `variantLabels` 21 风格**，实际 22 项（`:72-93`）。
4. **§4.29:1427 把已收敛的落点写成旧成员名 `DanmakuScheduler._generation`**，实际已是 `AsyncSession _session`（`danmaku_scheduler.dart:58-60`）。
5. **§4.13:786 与 §2:121 对 `bilibili_user.dart` 字段描述不一致**（等级/经验/硬币）。
6. **§4.27 的 `implemented=false` 占位语义已死**（`player_action.dart:60-89` 全部为 true）。
7. **§4.16:988「进度每 500ms 刷新」** 与代码不符（只对**速度** 500ms 节流，进度按块刷新，`download_task.dart:326-335`）。
8. **§4.15「清晰度默认请求最高档（`qn=127`，服务端按账户权限回落）」与代码不符**：`bili_video_service.dart` 的 `defaultQn = 80`（1080P），源码注释也写成 127。
   - **✅ 已修（B11，2026-09）**：文档与源码注释一并纠正为「默认 **1080P**（`defaultQn = 80`），服务端按账号权限**向下取最接近的可用档**」——这也是用户拍板的设计口径（D19，§4.36）。B15 的「§4 与代码不符」清单因此少一条。

### 5.4 被文档当作权威、但**不存在**的文件（2 个）

- `docs/哔哩哔哩生态接入状况.md`（§4.13/§4.14/§4.15 引用；`docs/` 下只有 `ARCHITECTURE.md`）。
- `third_party/media_kit_libs_android_video/FORK.md`（§4.9:519 与 §7:1768 要求「升级前必读」；该目录只有 `android/`、`.gitignore`、`LICENSE`、`pubspec.yaml`）。

### 5.5 其它一致性

- `THIRD_PARTY_NOTICES.md`：26 项直接依赖与 `pubspec.lock` **逐项吻合**；但 Android 原生侧漏署名 `truetypeparser-light:2.1.4` 与 `androidx.documentfile:1.0.1`（`android/app/build.gradle.kts:70/72`）。
- `pubspec.yaml:35` `media_kit: ^1.1.11` 与 override 基线 1.2.6 字面不一致（语义上允许）。
- §3「单文件超过 ~400 行必须拆分」：实际 **20+ 个** UI 文件超限（`player_page.dart` 3574、`player_portrait_page.dart` 2241、`subtitle_panel.dart` 1555…），该条要么豁免播放页要么重写。
- `test_run.log`（149KB）与 `moumou.iml` 是否该入库**待验证**。

---

## 6. 测试资产体检

**总量**：134 个 dart（含 1 个非测试 helper），14876 非空行。`utils/`、`models/`、settings service 覆盖密度罕见地高。

**P0 覆盖盲区（零测试 import）**：
1. `services/danmaku_service.dart`（666 行，`DanmakuController` 状态机本体）——唯一 import 它的测试用的是自写 `_FakeDanmakuController`，**真实类从未被执行**。
2. `services/playback_progress_service.dart`（93 行）——含 30s 节流、`forcePersist`、写盘串行、`ensureLoaded` 竞态（注释自陈是「重启后恢复不了」的根因）；`DateTime.now()` 导致不可测，需抽可注入 clock。
3. `services/file_operations_service.dart`（373 行）——破坏性最强却零覆盖（复制/移动/重命名/删除/取消/进度）。
4. `services/bilibili/bili_fingerprint.dart`（155 行）——协议指纹编排层（utils 层已测 14 例）。
5. `services/video_scanner.dart`（280 行）——static 可变缓存 + 通道查询 + 过滤 + 建树。

**P1 盲区**：`audio_service`、`subtitle_service`、三个网络协议客户端、`network_repository`、`download_manager` 的下载循环、`cache_manager_service`、`decode_settings`、`video_info_service`、`crash_log_service`、`utils/app_dialog`、`widgets/folder_actions`（破坏性操作入口）、`player_settings_page`、`subtitle_panel`、`player_gesture_layer`。
**P2 盲区**：`player_page.dart`（3574）+ `player_portrait_page.dart`（2241）两个最大文件零直接测试。

**低价值/脆弱断言**：`player_panel_test.dart:17-24` 对非空 `IconData` 断言 `isNotNull`（恒真）；`danmaku_dedup_test.dart:12/15` 自比恒真 + no-op 死代码；`player_danmaku_panel_test.dart:83-88` 只断言不抛异常；`appearance_page_test.dart:44-58` 名字承诺布局但只断言文案存在；`update_service_test.dart:11-45` 常量填值测试（硬编码真实 GitHub/飞书地址）；多处硬编码 250ms 精确等待、按控件索引定位、精确像素断言。

**flaky 面**：`playback_history_test.dart:30/41/43/126`、`async_primitives_test.dart:39-194`、`chapter_tracker_test.dart:132-167`、`home_page_permission_test.dart:115-130` 依赖真实时钟/真实 compute isolate；4 个测试依赖真实 loopback 端口绑定。

**互相污染**：`settings_page_bili_login_test.dart:13-14` setUp 不调 `BiliAccount.resetForTest()`（该钩子全项目无调用者）；平台通道 mock 清理方式 4 种不一致；`settings_ui.dart:52` 模块级可变缓存跨用例不复位（而 `player_panel_theme_test.dart:100-122` 正靠它断言 `identical`）；`danmaku_network_service_test.dart:117-151` 临时目录未用 `addTearDown`。

**未发现的问题（正向结论）**：无 `tester.*` 漏 `await`（全量正则 0 命中）；无确凿定时器泄漏；46 个测试引用符号全部在 lib 中存在；**测试资产无任何凭据泄露**（对真实 AppId/AppSecret 逐字符在 `test/` 零命中）。

---

## 7. 已确认无问题的部分（避免后续误改）

- **B 站协议层**：WBI 混淆表 64 项与官方 `bilibili-API-collect` 逐项一致（§7:1839 的坑未回归）；空格 `%20`/大写十六进制编码正确；凭证仅走 `flutter_secure_storage`，日志只打布尔量，`lib/services/bilibili/` 无硬编码 secret；`dandan_play_keys.dart` 确实被 gitignore 且从未入库。
- **弹幕装载正确性**：`AsyncSession` 覆盖 4 条装载路径（同名/记忆/手动/网络+切集自动匹配），每个 await 后判废；`attachLayer/detachLayer` 注册表在横竖屏来回切换时不会重复挂载或失联；秒桶前向补发/seek 跳变判定的边界（负秒、超长、>4x、暂停 seek、EOF）未发现缺陷；时间轴偏移正负语义与 §4.11 一致。
- **音频滤镜链**：`af` 全项目只有 `audio_service.dart:292` 一处写入，不存在音量标准化/DRC 与均衡器互相覆盖（§7 记录的坑未回归）；均衡器滑杆松手提交、监听器退订完整。
- **原生构建配置**：`fileTree` 直引源 jar（未回归 §7「build/ 残留旧 jar」）；合并后 manifest 的 `minSdk 24 / targetSdk 36 / extractNativeLibs=false` 与 12 项权限正确；最终 APK 内 `libmpv.so` 确实含 `mk_thumbnail_grab/free/clear_cache` 与 `mpv_lavc_set_java_vm`（§4.9 自建内核链路是通的）；Dart↔Kotlin 37 个方法名**零缺失零拼错**。
- **§7 抽查 30 条历史坑**：27 条在代码中确有对应防护（固定路径清理、扩展名锁定、安全区 `left/right=false`、面板 `Material`、`Builder` 取面板 context、无全局 ValueNotifier、`hr-seek=absolute`、EOF 双标志防重入、`openAndRestore` 静默激活时间线、写盘串行队列、崩溃日志上限、面板强调色派生缓存、Stack 条件子项 `ValueKey`、媒体数字字段 `as num` 兜底等）。

---

## 8. 待验证清单（本轮无法确认，需要真机/编译/运行）

1. `AudioPlayerPage` 空列表崩溃：已确认调用点与 clamp 语义，**未真机复现**。
2. `player_seek_bar.dart:123-130` 用「上一次 build 捕获的 `valueMs`」seek 的复现窗口（依赖指针事件与重建的帧序），需真机确认；若不成立降为 P3。
3. `_markCompleted` 与 `_saveProgress` 的写入顺序（EOF 时 mpv `time-pos` 是否严格小于 `duration`）。
4. ~~运行时写 `sub-fonts-dir` **同值**是否真触发 libass 缓存重建~~ → **已由真机验证（2026-09）：不触发**。
   依据：删掉该写入后重新编译安装，PGS 字幕**仍然不显示**（症状完全不变）→ 该写入当时没有产生
   可见影响。但真因查明为**内核缺 `hdmv_pgs_subtitle` 解码器**（P1-40），而这条写入仍是
   `§4.10` 明令禁止的违规，故修复保留（防止内核修好后被它打坏）。
5. `MediaInfo.Open(int fd, name)` 重载是否存在（决定 P1-18 的修法）。
6. x86/x86_64 下 MediaInfo 原生库是否缺失（决定 P1-18 触发频率）。
7. `ParcelFileDescriptor.detachFd()` 后 `close()` 的实际行为（本轮按 Android 契约判断为空操作）。
8. `enterPip` 的 `aspectWidth/Height` 实际传参类型：**已核实 Dart 侧是 `int`**（`pip_aspect.dart` 返回 `({int width, int height})`），故该条**不成立**（Kotlin 的 `Number` 兜底属冗余但无害）。
9. `AppFrameObserver._stack` 是否真会与 Navigator 内部栈漂移（推演未构造出反例）。
10. `SeedColorScheme.fromSeeds` 单次耗时（决定 P2-39 是掉帧还是仅浪费 CPU）。
11. SMB2 credit 记账缺失（fork 去锁后 `_credits.acquire` 无调用点）在真实服务器上的表现，需抓包。
12. `/sdcard` FUSE 层对符号链接的删除语义（POSIX 语义为删链接，但 FUSE 存在差异）→ 影响「移动含外链目录」是否可能删掉链接目标内容。
13. 大小写不敏感卷（exFAT SD 卡）上 `A.mp4 → a.mp4` 是否被判为同名冲突。
14. `webdav_xml` 实体转义 href 的实际发生率；FTP 服务器是否需要 GBK。
15. `filterWyzieByLanguages` 对 `zh-CN`/`Chinese (Simplified)` 等语言串的处理（可能静默丢弃）。
16. `diagnosticsWarnings` 对未加载媒体的 `hwdec-current == 'no'` 是否常驻误报「软解码」。
17. `flutter analyze` / `flutter test` / `gradle assembleRelease` 全量结果（本轮按要求未运行）。

---

## 9. 审计方法与覆盖说明

- **方式**：11 个并行只读深审（播放器核心 / 字幕弹幕音频 / 网络存储 / B 站生态 / 文件管理与投屏 / 下载与媒体 / 壳层与设置 / Android 原生 / 文档一致性 / 测试资产 / 音量增强独立复核），每条高危发现再经独立子代理或我本人复核。
- **我自己复核过的条目**：听视频空列表崩溃（读源码 + clamp 契约）、音频误删（读 `_deletableExt` + UI 文案）、空目录移动（读 `_collect` + `_transfer` 循环）、WebDAV 无上限 `drain`（读 `_drain`）、调色板持久化（`git log -S` 追到初始提交）、音量增强竖屏缺失（读两页 `_onVerticalSwipe`/`_showIndicator` 并核对 mpv 音量写入点唯一性）、竖屏倍速基准（读两页 `initState`）、`ViewSettings`/`SuperResolutionService` 缺 `ensureLoaded`、`PlayerOptionChip` 裸 primary、`fullscreen_state.dart` 死文件、`main.dart` 注释 10 秒 vs 实现 5 秒、§4.5 `bottomHeightFactor` 不存在、Dart↔Kotlin 通道名与参数键全量比对、`dandan_play_keys.dart` gitignore 状态、`pip_aspect` 返回 int（推翻一条候选）。
- **限制**：全部结论基于**静态代码阅读**；未运行分析器/测试/编译，未真机验证，未联网取样真实接口响应。凡标注「待验证」的条目请以真机结果为准，不要直接据此改动。

---

*报告结束。本轮为调研轮，未改动任何代码；如需要，我可以在你确认后另开一轮按 §0.2 的顺序执行修复，并同步 `docs/archive/ARCHITECTURE.md`。*
