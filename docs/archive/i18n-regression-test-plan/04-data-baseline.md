# 04 · 数据基线（被测对象 / 环境 / 判定口径）

> 本文件是**唯一权威的基线**。执行测试的 AI 不要自己重新统计，直接用这里的数字；
> 一旦实测与这里不符 → **停下来报告**（说明代码或环境已变），不要自行改基线。
> 基线采集时间：2026-10-02，采集人：上一轮迁移执行者（本机实测）。

---

## 1. 被测对象

| 项 | 值 |
|---|---|
| 仓库根 | `C:\Users\root\Desktop\moumou` |
| 分支 | `English` |
| 基线 commit | `3f90e5097b76abee45bc5e4b29fe5c1cc873ef6d`（短号 `3f90e50`，`fix: 修复本地弹幕导入点了没反应`） |
| 迁移提交链 | `7276793`(阶段0-3) → `331b03f`(4) → `d831326`(5) → `4425fb1`(6) → `ee0514d`(7) → `8b741bc`(8) → `629389e`(docs) → `8227c21`(收口：R1/R2/R4 三处残留 + 长文星号) → `a326a34`(阶段1-2 缺陷修复：深层目录补扫 + 在线播放白名单/CA 库 + mpv 错误提示) → `0c491bf`(阶段 3 缺陷修复：定时关闭胶囊溢出 / 外部音轨移除后落回内嵌轨 / 双指缩小副标题 / 动态范围压缩参数 / 音频滤镜失败兜底) → `8c6a931`(换入新 libmpv 内核产物：补开 pan/dynaudnorm/acompressor/lowshelf/extrastereo) → `3f90e50`(阶段 4 缺陷修复：本地弹幕导入不再用失效 context + 成功提示带文件名) |
| 改造前基线 | `7276793^`（用于 `git diff` 对照） |
| 包名 | `com.azxcvn.moumou` |
| 版本 | `pubspec.yaml` 的 `version: 1.3.6+4` → versionName `1.3.6` / versionCode `4`（**测试期间不许改版本号**）。⚠️ 新包的 versionCode 恒为 `4`；设备上若残留 versionCode `4004` 的旧包（策划时的状态），`install -r` 会撞版本降级 → **先卸载再装**。用仓库脚本 `tools/build_and_install.ps1 -Debug` 时会带 `-r`，所以先手动 `adb uninstall`（见 `01-执行协议.md` §3.1） |
| 应用名 | zh = `小喵Player`，en = `Meow Player`（ARB `appTitle` + Android `@string/app_name`） |
| 规模 | `lib/**` 306 个 dart 文件；`test/**` 190 个 dart 文件；迁移共改 246 个文件（+30313 / −2727 行） |

**注意**：如果被测 commit 已经不是 `3f90e50`（比如又修了缺陷重新提交），必须在本文件与 `07-遗留与待办.md` 里登记新 commit，并在报告里写明「本轮测的是哪个 commit」。

---

## 2. 运行环境（本机实测）

| 项 | 值 |
|---|---|
| OS | Windows（PowerShell 7） |
| Flutter | `3.44.9`（stable，framework revision `6b182d2c75`） |
| Dart | `3.12.2` |
| adb | `C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| 设备 | **MuMu 模拟器**，序列号 `emulator-5554`（`product:vermeer model:23113RKC6C`） |
| 模拟器进程 | `MuMuNxMain` / `MuMuNxService` / `MuMuNxDevice`（安装目录 `D:\allexe\木木模拟器\MuMuPlayer`） |
| Android | 15（API 35） |
| 屏幕 | 物理 1440×2560，密度 640dpi（**截图坐标换算：缩略图坐标 × 1.4985 = 实际像素**） |
| ABI | `x86_64, arm64-v8a, x86`（含 Intel Houdini 翻译层） |
| 系统语言 | `zh-Hans-CN`（**系统语言与 App 内语言是两件事**，见 §4） |
| adb shell 身份 | `uid=2000(shell)`（非 root） |
| Python（跑扫描脚本用） | `C:\Users\root\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |

---

## 3. 构建与安装口径（**本测试任务的特批**）

> 仓库根 `AGENTS.md` 写着「禁止私自编译、不 `flutter run`、不 `adb install`」。
> **那是给「改代码」任务的约束；本轮测试任务由用户特批放开**，理由：不编译新包就无法验证真实行为。
> 执行测试的 AI 以**本文件与 `01-执行协议.md`** 为准；红线只保留：不改版本号、不 force push、不动 `main`。

| 项 | 口径 |
|---|---|
| 构建 | 允许 `flutter build apk --debug`（或用户指定的其它模式）；**每次改完代码都要重新装一次**，否则测的是旧包 |
| 安装 | 允许 `adb -s emulator-5554 install -r <apk>` |
| 运行 | 允许 `flutter run`、`adb shell am start -n com.azxcvn.moumou/.MainActivity`、`am force-stop`（重启验证用） |
| 判定「装的是哪个包」 | 关于页底部有 `v1.3.6 / debug|release / <git 短号>` 徽标；**每次开始一轮测试前先核对短号 = 当前 HEAD** |
| 被测模式 | 默认 **debug**（能抓 Flutter 异常日志、能连 Dart VM）；**release 专项**见 `03-测试用例清单.md` 的 R 系列用例 |
| 打包体积/时机 | 首次构建较慢（含 libmpv），后续增量；构建日志写进 `tools/_build_*.log` 备查 |
| 权限 | 首次启动需授予「所有文件访问权限」（`MANAGE_EXTERNAL_STORAGE`），首页会走权限门禁 |

**debug 下的已知噪音**（不是缺陷，别报）：启动时必有一条 `Zone mismatch`（`main.dart` 的 `ensureInitialized` 在 `runZonedGuarded` 之外，改造前就有）。

---

## 4. 语言与文案基线

| 项 | 值 |
|---|---|
| 语言实现 | 官方 `gen_l10n`（`l10n.yaml`），模板 `lib/l10n/app_zh.arb`（源语言=中文），生成物**入库** |
| 可选语言 | **只有 简体中文 / English**，**没有「跟随系统」** |
| 持久化键 | `app_locale`，值只允许 `'zh'` / `'en'`，缺省/非法值回落 `'zh'`（默认中文） |
| 语言入口 | 「我的」页 → 「语言」组 → 「语言设置」项（组位置在「弹幕」下方、「下载」上方） |
| 首启弹窗 | 仅**全新安装**、且**本次刚同意隐私政策**时弹一次；默认选中简体中文；可取消（取消=保持中文） |
| ARB 键数 | **1278**（zh / en **完全对称**，无空值）—— 迁移完成时是 1272；本地修复 R1/R2/R4 新增 `subtitleCurrentSource`、`playerChapterNumber`、`biliCookieMissingSessdata`、`biliLoginCredentialParseFailed` 四键（已随 `8227c21` 提交，见 `07-遗留与待办.md` §4）；2026-10-04 修 `DEF-2-02` 时新增 `playerPlaybackFailed`、修阶段 3 缺陷时新增 `playerAudioEffectsUnsupported`（见 §9 O6 与 `07` §12） |
| 占位符键 | 176 个；复数（plural）键 44 个；多行（含 `\n`）键 21 个 |
| 中文侧含全角标点的键 | 249 个（这是设计：中文用全角，英文用半角） |
| 英文侧含汉字的键 | **只有 2 个，且是故意的**：`languageNameZh`（`简体中文`，语言自称不翻译）、`languagePickerTitle`（`选择语言 / Choose Language`，双语标题） |
| 未翻译清单 | `l10n_untranslated.json` = `{}`（必须保持为空） |

### 4.1 键值抽样（判定文案是否符合预期时对照）

| 键 | 中文（zh） | 英文（en） |
|---|---|---|
| `appTitle` | 小喵Player | Meow Player |
| `navHome` / `navMine` | 首页 / 我的 | Home / Mine |
| `commonLanguage` / `settingsLanguage` | 语言 / 语言设置 | Language / Language settings |
| `languageNameZh` / `languageNameEn` | 简体中文 / English | 简体中文 / English |
| `languagePickerTitle` | 选择语言 / Choose Language | 选择语言 / Choose Language |
| `commonCancel` / `commonDelete` / `commonRetry` | 取消 / 删除 / 重试 | Cancel / Delete / Retry |
| `commonPlay` / `settingsGroupPlayback` | 播放 / 播放 | Play / Playback（**故意不合并**：中文同、英文不同） |
| `commonSecondsValue` / `playerDelaySeconds` | `{value} 秒` / `{value} 秒` | `{value} s` / `{value} s`（**故意不合并**：占位符一个是 int、一个是 String） |
| `commonListSeparator` | 、 | `, ` |
| `commonLabelWithColon` | `{label}：` | `{label}: ` |
| `commonDeleteConfirmIrreversible` | 确定删除「{name}」吗？此操作不可撤销。 | Delete "{name}"? This cannot be undone. |
| `fileOpBytesProgress` | `{done} / {total}（{percent}%）` | `{done} / {total} ({percent}%)` |
| `settingsCacheClearAllBody` | 将删除全部缓存（当前共 {size}）：\n{items}\n\n此操作不可恢复。 | This deletes all caches ({size} in total):\n{items}\n\nThis cannot be undone. |
| `errorResponseParseFailed` | 响应解析失败：{error} | Failed to parse the response: {error} |
| `danmakuServerDefaultName` | 弹弹Play（默认） | Dandanplay (default) |
| `updateNoNotes` | 暂无更新说明 | No release notes available |
| `settingsFontPreviewSample` | `0123456789，。！？；：“”（）【】…·` | `0123456789 ,.!?;:"()[]...·` |
| `legalAgreeWithCountdown` | 同意并继续 ({seconds} 秒) | Agree and continue ({seconds}s) |

完整抽样表（含全部 `language*` 键）见 `tools/_arb_sample.md`（由脚本生成，可重跑）。

### 4.2 判「设计如此」清单（**以下情况不算缺陷，不要报 bug**）

| # | 现象 | 理由 |
|---|---|---|
| 1 | 日志/`logcat` 里的中文不翻译 | 红线 13：日志（含崩溃日志**文件内容**）永远中文 |
| 2 | 崩溃日志表头（【时间】【设备型号】…）仍中文 | 同上（`CrashHandler.kt` 只把用户可见 Toast 迁进了资源） |
| 3 | 截图文件名 `小喵Player-yyyy-MM-dd_HH-mm-ss.png` | 红线 14：不随语言变 |
| 4 | 截图相册名 `小喵Player` | 与文件名保持同一套命名，故意不译（**用户 2026-10 已拍板：保持中文**） |
| 5 | B 站接口返回的角标原值（`会员`/`限免`/`预告`）作匹配键 | 那是**数据**不是文案；显示文案走 l10n |
| 6 | 本地同名弹幕候选名 `弹幕.xml` | 文件匹配名，译了就找不到中文名弹幕 |
| 7 | `未命名` 作为持久化/文件名兜底 | 写盘与 prefs 兜底值（界面显示走 l10n） |
| 8 | 默认弹幕服务器持久化名 `弹弹Play（默认）` | prefs/缓存里的值不动，界面显示走 `danmakuServerDefaultName` |
| 9 | 英文界面里第三方返回的中文 | 服务端数据，不翻 |
| 10 | 语言弹窗标题是中英双语 | `languagePickerTitle` 故意如此 |
| 11 | 中文界面里出现半角数字/英文（如 `v1.3.6`、`H.264`、`VIP`） | 专有名词/格式，不译 |
| 12 | 通知渠道名在**老渠道**上仍是旧名 | Android 会缓存已创建渠道的名称，只在全新安装生效 |
| 14 | **应用名 / 通知渠道名 / 存储卷回退名 / 崩溃提示跟随「系统语言」而不是 App 内语言** | **用户 2026-10 已拍板：接受**（原生资源跟随系统语言是 Android 常规行为）→ 不作为缺陷；对应用例 `T7-SYS-105` 只记录现象 |
| 13 | ~~中文正文里的 `**` 星号原样显示~~ | **已修（2026-10，随 `8227c21` 提交）**：`legal_zh.dart` 正文两处星号已去掉，现在中英正文都看不到 `**` |

---

## 5. 自动化门禁基线（阶段 0 与每阶段收口都要复跑）

| 门禁 | 命令 | 基线期望 |
|---|---|---|
| 静态分析 | `flutter analyze` | `No issues found!` |
| 全量测试 | `flutter test --timeout=30s` | `All tests passed!`（改造完成时 `+1817 ~13`；收口后 `+1816 ~13`——少的那条是随 R2 删除的 `chapterNumberFallbackLabel` 测试；**skip 数会随环境浮动，以「无 failed」为准**） |
| 残留中文（默认口径） | `python "杂项文件\多语言支持方案\tools\i18n_scan.py" residual` | 0 |
| 残留中文（含 Android） | 同上 `--include-android` | 0 |
| 残留中文（含全角标点） | 同上 `--include-android --fullwidth` | 0 |
| 白名单过期 | `residual` 报告里的「过期项」 | 0 |
| 未翻译清单 | `lib/../l10n_untranslated.json` | `{}` |
| ARB 对称性 | 见 §4 | zh/en 各 1278 键、无空值 |

> 扫描脚本只读源码；`residual` 会覆盖写 `杂项文件/多语言支持方案/05-残留中文报告.md`（那是迁移方案目录的产物，测试期间**只读参考**，不要删）。
> `flutter` 命令常把 "Flutter assets will be downloaded…" 写进 stderr，PowerShell 可能报 `[exit code: 1]` 假失败 —— **以 flutter 自己打印的 `All tests passed!` / `No issues found!` 为准**。

### ⚠️ 5.1 `residual = 0` **不等于**没有残留（重要）

开工前的回归风险扫描已确认**两处中文会进界面，但脚本口径抓不到**：

| 位置 | 现象 | 为什么脚本漏了 |
|---|---|---|
| `lib/pages/subtitle/subtitle_download_page.dart:378` | 英文界面「字幕下载」设置卡副标题中英混排（`当前来源：Wyzie Subtitle Service`） | 中文是**拼在字符串字面量里的片段**（`'当前来源：' + 来源名`），不是独立字面量 |
| `lib/utils/chapter_utils.dart:196` | 英文界面拖进度条时，**无标题章节**的胶囊显示「第 2 章」 | 文案由 **`utils/` 层纯函数产出**（分层红线要求它不 import l10n），扫描只按「字面量」看 |

结论：**脚本门禁只是底线，英文全量走查（`T7-I18N-*`）是必做项**。发现新残留时按「新发现」登记（不要改基线数字），并在报告里写明「脚本口径之外的第 N 处」。

> **进展（2026-10）**：这两处已修复并随 `8227c21` 提交（见 `07-遗留与待办.md` §4）。表格保留，作为「扫描口径盲区」的证据；对应回归用例 `T7-I18N-107` / `T3-PLR-123` 改为**验证修复生效**。

---

## 6. 测试覆盖基线

| 项 | 值 |
|---|---|
| 测试文件 | 190 个（`test/**.dart`，含 2 个夹具：`l10n_test_helper.dart`、`pb_test_helper.dart`） |
| widget 测试 | 45 个（含 `testWidgets`） |
| 纯 unit 测试 | 143 个 |
| 引用 l10n 标识符的测试 | 51 个（其中 38 个直接 `import 'l10n_test_helper.dart'`） |
| l10n 测试夹具 | `test/l10n_test_helper.dart`（`kTestLocaleZh` / `kTestLocalizationDelegates` / `kTestSupportedLocales` / `pinPlatformLocaleZh()` / `pumpAppZh()`） |
| 关键回归测试 | `test/app_smoke_test.dart`（真实 `MoumouApp` 启动链路）、`test/language_picker_test.dart`（语言入口）、`test/legal_texts_test.dart`（中英长文齐全）、`test/privacy_policy_dialog_test.dart`（隐私弹窗双语） |
| 页面级 widget 测试（约 20 个） | `about_page_card_test` / `appearance_page_test` / `danmaku_server_page_test` / `device_info_page_test` / `file_operations_ui_test` / `home_page_permission_test` / `network_browser_page_test` / `open_link_dialog_test` / `options_sheet_video_fields_test` / `playback_history_page_test` / `player_settings_page_test` / `settings_page_bili_login_test` / `speed_dial_fab_test` / `subtitle_download_page_test` / `update_dialog_test` / `video_card_*` / `wallpaper_editor_page_test` 等 |
| 测试默认 locale | 默认 `en_US` → **组件测试必须走夹具**；真机测试不受影响 |
| **零覆盖的域**（补 L1 测试的落点） | ① 整个 `android/` 原生侧（无 test/androidTest 源集）② `player_page.dart` / `player_portrait_page.dart` 本体 ③ `audio_player_page.dart`（听视频）④ 投屏端到端 ⑤ 网络存储真实协议链路 ⑥ B 站页面层（首页/详情/登录/账号页）⑦ 下载持久化与合并阶段、`download_manager_page` ⑧ 首启完整时序与外部打开视频冷/热启动 ⑨ `error_log_page` 与崩溃日志写入 ⑩ `settings_page` 本体、`license_page`、`font_page`、`cache_management_page`、`decoder_detail_page` |

> 功能点总表（481 条，含入口路径与可测性判定）与「不存在/未接入功能」清单见 `tools/_scan_features.md`；
> 其 §14.4 就是上表最后一行的来源，补自动化测试时按它逐域补。

---

## 7. 环境自检（开工第一条命令，输出贴进报告）

```powershell
# 工作目录 = 工程根
cd C:\Users\root\Desktop\moumou
git rev-parse HEAD; git rev-parse --abbrev-ref HEAD; git status --short
flutter --version
& "C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices -l
& "C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell "getprop ro.build.version.release; getprop ro.product.locale; wm size; wm density"
& "C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell "dumpsys package com.azxcvn.moumou | grep -E 'versionName|versionCode'"
```

判定：HEAD = `3f90e50`（或已登记的新 commit）、分支 = `English`、设备在列表里且状态 `device`、系统语言 = `zh-Hans-CN`。任何一项不符 → 先报告再动手。

> 实测注意（2026-10-04）：本机 `getprop persist.sys.locale` 返回**空**，`settings get system system_locales` 返回 `null` —— 判断系统语言请用 `getprop ro.product.locale`（= `zh-Hans-CN`）。

---

## 8. 已知限制（写进最终报告，别当成测过了）

1. ~~**Android 原生侧的 l10n 从未编译验证过**~~ → **用户已于 2026-10 自测通过**（应用名、通知渠道名/描述、存储卷回退名、崩溃提示）。测试 AI 在阶段 7 只需抽查，不必重复深挖；通知渠道名的卸载重装验证**用户已明确不要求**（见 `07-遗留与待办.md` §1）。
2. **模拟器环境 ≠ 真机**：x86_64 + Houdini 翻译层、软硬解支持与真实手机不同；解码能力类结论（硬解/软解/不支持）只代表模拟器。
3. **崩溃路径**：主动触发崩溃的方式由用户提供（见 `05-素材需求清单.md` M13）；未提供则该项记为「未验证」。
4. **网络依赖项**：B 站、GitHub 更新源、Wyzie/自定义字幕源、局域网设备是否可达，取决于本机网络与素材（见 `05-素材需求清单.md`）。
5. **通知渠道名**只在全新安装时生效；若要验证 en 渠道名，必须**卸载后重装**（会清掉 App 数据，需先记录当前设置项）。
6. 模拟器共享目录里的素材（`MuMuShared` 等）属于**用户数据**，界面显示中文不算残留 —— 判定残留只以脚本 + 界面框架文案为准。
7. **开工前已定位 29 条回归风险（高 2 / 中 6 / 低 21）+ 11 条结构性隐患 + 2 处确认残留 + 4 条未确认项**：全部列在 `07-遗留与待办.md` §1.1（R1–R19），并已转成 `03-测试用例清单.md` 附录 B 的 20 条定向核查用例。**这些不是「待发现的问题」，而是「待你给结论的问题」**。
8. **迁移提交里混入了至少 1 处与 l10n 无关的行为改动**（`lib/utils/bili_image_url.dart:52-61`，非图床封面 URL 不再被规整，其单元测试在基线是红的、本提交才转绿）—— 提醒：不要默认「这批提交只有文案改动」，逐条回归仍必要。

---

## 9. 开工前准备核查（2026-10-04，由策划者实测，不是测试结论）

> 这一节是「开工前把环境和素材摸清」的记录，用来省掉你重复摸索。**它不是测试证据**，阶段 0 仍要自己复跑一遍。
> 证据截图：`_evidence/阶段0/READY_0*.png`。

| 项 | 实测结果 |
|---|---|
| adb 通路 | `adb devices -l` → `emulator-5554  device`（首次列表可能短暂显示 `offline`，等一秒重查即可） |
| 可操作性 | `screencap` / `input tap` / `input swipe` / `am start` / `am force-stop` / `monkey` 全部实测可用，截图 1440×2560 可读 |
| 素材落位 | 设备侧 `/sdcard/素材收集清单/`，M01–M20 **20 个目录、49 个文件**，MT管理器可见；PC 侧源目录 `C:\Users\root\Desktop\素材收集清单` |
| 素材完整性 | 与 PC 侧**逐文件比对字节数**：仅 **1 个文件没过来**——M05 的「超长文件名 mp4」（文件名 22×「超级长的视频文件」+「名.mp4」，UTF-8 远超 Android 的 255 字节文件名上限，物理上装不下）。其余 49 个文件字节数完全一致 |
| 额外素材 | `/sdcard/测试路径/`（约 3.0 GB：内嵌字幕、自带章节、系列集、音频、字体文件、背景测试图等）。**不在 M01–M20 清单里**，可作补充素材用 |
| 现装包（**2026-10-04 16:11 已更新为修复后的包**） | 策划时设备上装的是**修复前**的 debug 包（`versionCode 4004`；kernel_blob 里有 `chapterNumberFallbackLabel`、没有 `subtitleCurrentSource`/`chapterHeadingLabel`）。策划者随后用仓库脚本 `tools/build_and_install.ps1 -Debug` **卸载旧包 + 重新构建 + 安装**：现装 `versionName 1.3.6` / `versionCode 4` / DEBUGGABLE / `--dart-define=GIT_HASH=8227c21`，关于页徽标实测 **`v1.3.6 / debug / 8227c21`**；kernel_blob 里新键齐全、`chapterNumberFallbackLabel` 已消失 → **确认装的就是修复后的包**（证据 `_evidence/阶段0/READY_07`–`READY_10`）。⚠️ 这次是**全新安装**（卸载清掉了 App 数据），首启隐私弹窗与语言弹窗已各走过一遍 |
| 第二存储卷（M16） | `/storage` 下只有 `emulated`（**单卷**）；MuMu 的共享目录在 `/mnt/shared/MuMuShared`，不是 Android 认可的存储卷 → 「第二个存储卷」大概率**不可测**，阶段 2 用界面上的存储卷列表实测确认后再下结论 |
| adb pull 注意 | 目标路径请用**正斜杠**：`adb pull /data/local/tmp/s.png "…/_evidence/阶段0/x.png"`。用反斜杠写到这个中文目录会报 `cannot create file/directory`（本机 2026-10-04 实测、可复现）。备用做法：先 pull 到 `$env:TEMP` 再 `Copy-Item` 落位 |
| 首页观察 | App 首页出现**重复卡片**（`M01`、`M02` 各两张，另有一张名为 `1` 的目录），但设备上只有一份副本 → 疑为媒体库**缓存/索引残留**（与 l10n 无关）。阶段 2 先刷新/重扫再判定，别当回归报 |
