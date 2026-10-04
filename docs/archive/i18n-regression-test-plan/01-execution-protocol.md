# 01 · 执行协议（测试 AI 必读，先读这一份）

> 你的任务：在这个仓库里，对「接入官方 l10n 多语言」之后的 App 做**全量回归测试**，判断原有功能有没有被这轮改造影响。
> 本协议是**硬约束**。与 `02-test-plan.md` 冲突时以本协议为准；与仓库根 `AGENTS.md` 冲突时**以本协议为准**（用户已特批，见 §1.1 的说明）。
> 「必须 / 禁止 / 不允许」都是门禁级要求。**违反即回滚该次动作并在报告里说明**。

---

## 0. 开工前必须读的东西（按序，读完再动手）

| 顺序 | 文件 | 读它是为了 |
|---|---|---|
| 1 | `AGENTS.md`（仓库根） | 仓库通用协作规则（注意：其中「禁止编译/安装」被本任务特批覆盖，见 §1.1） |
| 2 | `docs/archive/i18n-regression-test-plan/README.md` | 目录索引与本轮任务说明 |
| 3 | `docs/archive/i18n-regression-test-plan/01-execution-protocol.md` | 本文件：红线、循环、门禁、提问规则 |
| 4 | `docs/archive/i18n-regression-test-plan/02-test-plan.md` | 测什么、怎么测、分几个阶段、每阶段门槛 |
| 5 | `docs/archive/i18n-regression-test-plan/04-data-baseline.md` | 被测 commit / 环境 / 文案基线 / **「设计如此」清单** |
| 6 | `docs/archive/i18n-regression-test-plan/05-material-requirements.md` | 你手上有什么素材、缺什么 |
| 7 | `docs/archive/i18n-regression-test-plan/03-test-case-list.md` | **你的待办**：逐条用例，勾选进度写在这里 |
| 8 | `docs/archive/i18n-regression-test-plan/07-open-items-and-todo.md` | 未验证项与阻塞的登记处 |
| 9 | `docs/PROJECT.md` | 模块职责与功能全貌（判断「这个功能本来该是什么样」） |
| 参考 | `docs/archive/i18n-migration-plan/**`（上一轮迁移的文档与工具） | **只读**：迁移改了哪些文件、哪些地方「故意不翻译」。其中 `06-open-items-and-todo.md` §2.12 是最重要的回归风险来源 |

---

## 1. 红线

### 1.1 本轮特批（覆盖仓库根 `AGENTS.md` 的禁令）

1. **允许编译、安装、运行**：`flutter build apk --debug`、`adb install -r`、`flutter run`、`am start` / `am force-stop`。
   理由：不编译新包就无法验证真实行为。**这个特批只对本测试任务有效**，且只针对**模拟器 `emulator-5554`**。
2. 只允许装到**模拟器**；不碰用户真机、不 `adb reboot`、不改模拟器系统设置里与本测试无关的项（需要改系统语言时见 §3.7，改完要还原）。

### 1.2 仍然禁止（不得违反）

1. **禁止改版本号**：`pubspec.yaml` 的 `version:` 一个字都不许动。
2. **禁止 `git commit` / `git push` / 建 tag / 改历史 / `force push`**：除非用户在对话里明确说「提交」。改动只停在本地工作区。
3. **禁止 `dart format`**：本仓库是旧版格式化风格；改动风格必须与所在文件现状一致。
4. **禁止为了「让用例变绿」而降级验证**：不许放宽预期、不许删/改断言来掩盖现象、不许把「没做」写成「已通过」、不许把「不可测」直接跳过后不登记。
5. **禁止改动基线文档来迁就代码**：`01/02/04/05` 是基线；发现问题只能**新增记录**（写进 `07-open-items-and-todo.md` 或报告），不许改基线数字。`03-test-case-list.md` 只允许勾选与追加「实际结果」列。
6. **禁止动上一轮迁移目录** `docs/archive/i18n-migration-plan/**`（只读参考；特别是别覆盖 `05-residual-chinese-report.md` 之外的报告文件）。
7. **禁止把凭据写进会进 Git 的地方**：素材里的账号/密码/密钥/Token **不许**写进 `lib/`、`test/`、`docs/`（含本目录 `docs/archive/i18n-regression-test-plan/**`，它已入库）、`README`；确需临时记录时写在 `.gitignore` 覆盖的位置（如 `杂项文件/` 下的临时目录），用完删除。
8. **清数据 / 卸载重装已获授权**（`05-material-requirements.md` M19 = 用户答「允许」）：卸载重装是**常规安装手段**——本地构建的 versionCode 是 `4`，低于设备现装的 `4004`，直接覆盖会撞版本降级失败（见 §3.1）。但仍要求：动手前先把当前设置项记进报告（否则清完无法对比），且只在「需要装新包」或「需要验证全新安装」时做，不要当重启手段。
9. **禁止把截图/录屏写到 `/sdcard` 顶层**（会被 MediaProvider 索引、污染被 App 扫描的媒体库）：设备侧一律用 `/data/local/tmp`，产物拉到本地 `docs/archive/i18n-regression-test-plan/_evidence/`。
10. **禁止谎报**：所有结论必须有证据（截图 / logcat / 命令输出）。没测的写「未验证」，测不了的写「不可测 + 原因」。

### 1.3 改代码的权限（用户已允许，但有条件）

用户可以接受你**直接修缺陷**，但必须走这个顺序，任何一步没做都算违规：

1. **先复现**：给出稳定复现步骤 + 证据（截图/日志），写进缺陷单。
2. **判定归属**：确认是本轮 l10n 改造引起的回归，还是**改造前就存在**的老问题（用 `git stash` / 对比旧包 / `git log` 判断）。老问题只登记，**不修**（除非用户点头）。
3. **改最小范围**：只改与缺陷直接相关的代码；**不许顺手重构**、不许改无关文案、不许动业务逻辑的其它分支。
4. **改完必跑**：`flutter analyze`（必须 `No issues found!`）+ 相关测试文件 + （若动到公共层）全量 `flutter test`。
5. **登记**：在 `07-open-items-and-todo.md` 记「缺陷 ID / 改了哪些文件 / 为什么 / 验证结果」，并在阶段报告里如实说明。
6. **不要提交**：等用户说「提交」。

---

## 2. 工作粒度与循环

**粒度**：严格按 `03-test-case-list.md` **一条用例一个闭环**。禁止「一口气点一堆然后再看」——那样出问题无法定位。

**单条用例循环（必须按序）**：

1. 从 `03-test-case-list.md` 取当前阶段第一条未勾选用例，读它的：前置 / 步骤 / 预期 / 证据要求 / 素材依赖。
2. **确认前置**：需要的素材在不在（缺 → 按 §5 的规则标 `未验证（缺 Mxx）`，登记后继续下一条）。
3. 把 App 恢复到该用例要求的前置状态（语言、页面、封面数据、系统语言、网络）。
4. 用 `adb` 执行步骤（截图看清每一步的界面再点，不要盲点坐标）。
5. **每个关键断言点截图**（不是只在结尾截一张）；异常/报错要连 `logcat` 一起抓。
6. **对照预期**：一致 → 通过；不一致 → 先按 §1.3 判定是不是「设计如此」（查 `04-data-baseline.md` §4.2）或**已知老问题**，再决定记缺陷还是记「非缺陷说明」。
7. 在 `03-test-case-list.md` 把该行 `- [ ]` 改成 `- [x]`，并在「实际结果」列写一句结论（通过 / 不通过 / 未验证 + 证据文件名）。
8. 发现缺陷 → 立刻写缺陷单（模板见 `06-defect-and-report-templates.md`），**不要攒到最后**（截图会丢、细节会忘）。

**阶段循环（每阶段收口）**：

1. 本阶段全部用例已勾选（或已登记未验证）。
2. `flutter analyze` 无问题。
3. `flutter test --timeout=30s` 全量通过。
4. `python "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual`（及 `--include-android`、`--include-android --fullwidth`）残留仍为 0。
5. 更新 `07-open-items-and-todo.md`（未验证项、阻塞、已修缺陷）。
6. 按 `06-defect-and-report-templates.md` 的**阶段报告模板**输出报告，然后**停下来等用户确认**，不要自动进入下一阶段。

---

## 3. 命令行手册（可直接复制）

`$adb = "C:\Users\root\AppData\Local\Android\Sdk\platform-tools\adb.exe"`，设备固定 `-s emulator-5554`。工作目录 = 工程根 `C:\Users\root\Desktop\moumou`（先 `pwd` 确认，不要假设）。

### 3.1 构建 / 安装 / 重启

```powershell
flutter analyze
flutter build apk --debug 2>&1 | Tee-Object -FilePath "docs\archive\i18n-regression-test-plan\tools\_build.log"
$adb uninstall com.azxcvn.moumou                     # ✅ 已授权（M19）：先卸载，否则版本降级会失败
$adb install "build\app\outputs\flutter-apk\app-debug.apk"
$adb shell am force-stop com.azxcvn.moumou          # 重启验证（持久化/首启流程）
$adb shell am start -n com.azxcvn.moumou/.MainActivity
$adb shell pm clear com.azxcvn.moumou               # 清数据=模拟全新安装（已授权，见 §1.2 第 8 条）
$adb shell pm path com.azxcvn.moumou                # 确认装的是哪个 apk
```

**判定装的是哪个包**：关于页徽标（`v1.3.6 / debug / 8227c21`）里的**短号必须等于当前 HEAD**，否则你测的是旧包。
> 实测（2026-10-04 16:11）：设备上**已装好修复后的包**（`versionCode 4`、徽标 `v1.3.6 / debug / 8227c21`、全新安装态）。**注**：现行基准已推进到 `3f90e50`（阶段 1/2/3/4 缺陷修复 + 新 libmpv 内核产物，见 `04-data-baseline.md` §1），重编后徽标短号应为 `3f90e50`。你改代码后重装时：先 `adb uninstall` 再 `adb install`（新包 versionCode 恒为 `4`，设备上若还残留 `4004` 的旧包就会撞版本降级）。仓库脚本 `tools/build_and_install.ps1 -Debug` 会自动注入 `GIT_HASH` 并安装，但它用的是 `install -r`，所以仍需你先手动卸载。

### 3.2 截图（唯一可靠的「看界面」手段）

```powershell
$adb shell screencap -p /data/local/tmp/s.png
$adb pull /data/local/tmp/s.png "docs\archive\i18n-regression-test-plan\_evidence\stageN_用例ID_说明.png"
$adb shell rm /data/local/tmp/s.png
```

- **务必用「设备侧落盘 + pull」**，不要用 `adb exec-out screencap -p > file.png`（PowerShell 会把二进制写坏）。
- Flutter 默认**不上报无障碍语义树** → `uiautomator dump` 拿不到控件文本，**只能靠截图看**。要「文本级」比对就截图 + 人工/多模态读图。
- 截图分辨率 1440×2560；**点击坐标以截图像素为准**（缩略图坐标 × 1.4985）。
- **`adb pull` 的目标路径请用正斜杠**（`"…/_evidence/stage0/x.png"`）：用反斜杠写到这个中文目录会报 `cannot create file/directory`（本机 2026-10-04 实测、可复现）。备用做法：先 pull 到 `$env:TEMP` 再 `Copy-Item` 落位。

### 3.3 点击 / 滑动 / 按键 / 输入

```powershell
$adb shell input tap 720 1030                       # 单击
$adb shell input swipe 720 2000 720 800 300         # 上滑（滚动）
$adb shell input swipe 720 1200 720 1200 1000       # 长按 1 秒
$adb shell input keyevent KEYCODE_BACK              # 返回
$adb shell input keyevent KEYCODE_HOME              # 回桌面
$adb shell input keyevent KEYCODE_POWER             # 锁屏（后台播放验证）
$adb shell input text "abc123"                      # ⚠️ 只能 ASCII；中文输入用 App 内已有数据，或改系统输入法
```

### 3.4 横竖屏

```powershell
$adb shell settings put system accelerometer_rotation 0
$adb shell settings put system user_rotation 1      # 0=竖屏 1=横屏90 2=倒竖 3=横屏270
# 还原：settings put system accelerometer_rotation 1
```

### 3.5 状态与界面事实（不靠猜）

```powershell
$adb shell dumpsys window | Select-String "mCurrentFocus"                  # 当前前台窗口
$adb shell dumpsys activity activities | Select-String "ResumedActivity"   # 当前页面（Flutter 单 Activity）
$adb shell dumpsys package com.azxcvn.moumou | Select-String "versionName|versionCode"
$adb shell dumpsys notification --noredact | Select-String "moumou_background_playback"
```

### 3.6 日志（判断崩溃/异常的唯一依据）

```powershell
$adb logcat -c                                                        # 先清，避免旧日志混入
$adb logcat -d -t 2000 | Select-String -Pattern "flutter|E/AndroidRuntime"   # 抓 Flutter 异常与 Java 崩溃
```

### 3.7 系统语言（多语言专项用）

```powershell
$adb shell getprop ro.product.locale                 # 当前系统语言（用这个；persist.sys.locale 本机为空）
# 切英文/中文：用模拟器「设置 → 系统 → 语言和输入法」界面操作（adb 改 locale 需 root，别折腾）
# 改完必须还原成 zh-Hans-CN，并在报告里写明改过
```

### 3.8 门禁脚本

```powershell
python "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual
python "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --include-android
python "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --include-android --fullwidth
flutter test --timeout=30s
# 本机若没有 python：C:\Users\root\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe
```

> `flutter` 会把 "Flutter assets will be downloaded…" 写进 stderr，PowerShell 可能报 `[exit code: 1]` **假失败** —— 以 flutter 自己打印的 `All tests passed!` / `No issues found!` 为准。

---

## 4. 门禁（什么算通过）

| 门禁 | 通过标准 |
|---|---|
| T1 基线 | 关于页短号 = 当前 HEAD；环境自检（`04-data-baseline.md` §7）全项相符 |
| T2 静态 | `flutter analyze` → `No issues found!` |
| T3 测试 | `flutter test --timeout=30s` → `All tests passed!`（skip 数浮动不算失败） |
| T4 残留 | 三种口径 `residual` 均为 0，白名单过期 0 |
| T5 用例 | 本阶段用例全部有勾选；**每个「未验证」都有原因与素材编号** |
| T6 证据 | 每个「不通过 / 存疑」都有截图或日志；证据文件名能对上用例 ID |
| T7 登记 | 缺陷进缺陷单、未验证进 `07-open-items-and-todo.md`，没有只存在于对话里的结论 |

任一门禁不过 → 不许进入下一阶段，也不许「先记下来以后修」而不登记。

---

## 5. 素材缺失的处理规则（用户已定）

1. 缺素材的用例：状态写 **`未验证（缺 Mxx）`**，**继续做下一条**，不要停下来等。
2. 每个阶段收口时，把该阶段的未验证项汇总进 `07-open-items-and-todo.md`；全部阶段结束后给用户一份**总缺口清单**（按素材 ID 归类，写清「补上 Mxx 后可以补测这些用例」）。
3. 素材**不完整但够用**时（例：只有 mp4、没有 mkv）：把能做的一半做掉，另一半记 `部分验证`，不要整条记未验证。

---

## 6. 必须停下来提问的情况（不许自行决定）

1. 实测与 `04-data-baseline.md` 不符（commit 不是 `3f90e50`、设备换了、系统语言不是 `zh-Hans-CN`、ARB 键数不是 1278…）。
2. 现象无法判断是「回归」还是「改造前就有」——你需要旧包（M18）或用户判断。
3. 需要**清数据 / 卸载重装 / 改系统语言 / 改模拟器设置**而 `05-material-requirements.md` 未授权。
4. 需要**改业务逻辑**才能继续测（例：某崩溃挡住了后续所有用例）。
5. 发现**安全问题**（凭据明文、越权、路径穿越）或**数据损坏风险**（下载合并覆盖原文件、删除操作不可恢复）。
6. 某个功能在两种语言下都表现异常（可能是改造前的老问题，也可能是环境问题）。
7. 素材里的账号/密钥**不可用或已失效**。
8. 你需要下载大文件、需要真机、或需要用户配合扫码/操作外部设备。

提问要求：**一次问清**，给出你的判断选项与依据（现象 + 证据 + 你的倾向），不要挤牙膏式反复问。

---

## 7. 缺陷分级（写进缺陷单）

| 级别 | 定义 | 例子 |
|---|---|---|
| **P0 阻断** | 崩溃 / 启动失败 / 数据损坏 / 无法继续测试 | 打开某页面必崩；文件删除删错文件 |
| **P1 严重** | 主要功能不可用或结果错误，无绕过 | 播放一直黑屏；下载完成但文件损坏；字幕错位 |
| **P2 一般** | 功能可用但行为不对/文案错/参数丢失 | 英文界面出现中文；提示里少了参数；复数写错 |
| **P3 轻微** | 观感问题，不影响使用 | 英文文案溢出 1px、间距不齐、标点不一致 |
| **非缺陷** | 属 `04-data-baseline.md` §4.2「设计如此」或改造前老问题 | 日志中文、截图文件名、第三方返回中文 |

---

## 8. 语言矩阵要求（本轮的测试重点）

**每个阶段至少覆盖一次双语言**：中英各走一遍该阶段的关键路径。具体：

| 层次 | 做法 |
|---|---|
| L-A 中文基线 | 「我的 → 语言设置」选**简体中文**，走查该阶段全部用例（这是原有功能的母语基线） |
| L-B 英文走查 | 切 **English** 后重走：① 界面无中文残留（除 §4.2 清单）② 关键按钮/标题不溢出、不截断 ③ 插值与复数正确 ④ 页面能正常进入/返回 |
| L-C 切换即时性 | 切换语言后**不重启**，当前页面应立刻变；跨页面返回后仍一致 |
| L-D 持久化 | 杀进程重开保持所选语言 |
| L-E 反向验证 | 每阶段末至少做一次「中文 → 英文 → 中文」往返，确认没有状态残留（尤其设置页与播放页） |

**判定基准**：中文界面必须与**改造前**逐字一致（`git show 7276793^:<file>` 可查原文）；英文界面要求「通顺、参数齐全、不溢出」，不要求逐字对照标准答案。

---

## 9. 汇报

- 模板见 `06-defect-and-report-templates.md`（缺陷单 / 未验证项 / 阶段报告）。
- **禁止**在报告里写「应该没问题」「看起来正常」这类没有证据支撑的结论。
- 报告只写在对话里 + `_evidence/` 目录里，**不要**写进提交信息（提交信息由用户决定）。

---

## 10. 进度与交接

- 进度唯一真源 = `03-test-case-list.md` 的勾选框 + 「实际结果」列。**做完一条就勾一条**，不要批量补勾。
- 未验证/阻塞唯一真源 = `07-open-items-and-todo.md`。
- 证据唯一真源 = `_evidence/` 目录（按阶段分子目录）。
- 交接给下一个会话/下一个 AI：让对方先读 §0 的九份文件，再看 `03-test-case-list.md` 的勾选状态继续做。
