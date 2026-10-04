# 多语言引入后 · 回归测试策划（给测试 AI 的执行包）

> 背景：本工程刚完成一轮「接入官方 Flutter l10n 多语言」的改造，共 **9 轮工作（阶段 0–8）**，
> 改动面 246 个文件（+30313 / −2727 行）。虽然 `flutter analyze` 与 190 个测试文件全绿，
> 但**改造动过的不只是文案**：数据结构、异常体系、方法签名、持久化字段、Android 原生都动过。
> 本目录就是「**验证原有功能有没有被这轮改造影响**」的完整执行包。
>
> 目标工程：`C:\Users\root\Desktop\moumou`（小喵 Player，Flutter / Android，分支 `English`）。
> 被测基线：commit `3f90e50`（详见 `04-data-baseline.md`）。
> 执行者：另一个具备**文件读写 + 终端 + 看截图**能力的 AI（也可以是你自己）。

---

## 1. 文件清单

| 文件 | 给谁看 | 内容 |
|---|---|---|
| `01-execution-protocol.md` | **测试 AI 必读（第一份）** | 红线（含本轮「允许编译/安装」的特批）、单用例闭环、adb 命令手册、门禁 T1–T7、素材缺失处理、必须提问的 8 种情况、缺陷分级、语言矩阵、进度维护 |
| `02-test-plan.md` | 测试 AI | 测试策略分层、阶段划分（阶段 0–7）、每阶段范围与重点、判定准则、不测项、风险与应对 |
| `03-test-case-list.md` | 测试 AI | **逐条用例**（含步骤/预期/证据要求/素材依赖/可自动化程度）+ 勾选进度；正文按 8 个阶段分组（219 条）+ **附录 A 补齐扫描缺口（116 条）** + **附录 B 定向核查 20 条** |
| `04-data-baseline.md` | 测试 AI + 用户 | 被测对象与环境实测基线、语言与文案基线、ARB 抽样对照、**「设计如此」清单**、门禁基线、已知限制、**开工前准备核查（§9）** |
| `05-material-requirements.md` | **用户**（准备）+ 测试 AI（核对） | M01–M20 素材需求（本地媒体/账号/网络存储/局域网设备/崩溃触发…），附状态表 |
| `06-defect-and-report-templates.md` | 测试 AI | 缺陷单、未验证项、阶段报告、最终总报告、「非缺陷说明」五套模板与编号规则 |
| `07-open-items-and-todo.md` | 测试 AI（维护）+ 用户（查看） | 开工前已知待验证项、缺陷/未验证/已修/阻塞登记、阶段进度、素材缺口汇总 |
| `08-final-report.md` | **用户（最终交付）** | **全轮总报告**：355 条用例总账、7 个缺陷总账、两个仓库的提交链、未验证/部分验证、收口门禁、结论与建议 |
| `tools/` | 工具/中间产物 | `_arb_sample.md`（ARB 抽样对照，脚本生成）、`_scan_features.md`（功能面全量扫描）、`_scan_regression.md`（迁移回归风险扫描）、构建日志等 |
| `_evidence/` | 证据 | 按阶段分目录的截图/日志（**执行时创建**） |

---

## 2. 怎么交给 AI 执行

### 2.1 启动提示词（可直接复制给任意具备文件读写、终端、看图能力的 AI）

```
你要在这个 Flutter 仓库（工程根：C:\Users\root\Desktop\moumou）里，对「接入官方 l10n 多语言」
之后的 App 做全量回归测试，判断原有功能有没有被这轮改造影响。严格按下面工作，不要跳步、不要合并阶段：

1. 先按顺序读这九份文件（读完再动手）：
   AGENTS.md（注意：其中「禁止编译/安装」被本轮测试特批覆盖）
   docs/archive/i18n-regression-test-plan/README.md
   docs/archive/i18n-regression-test-plan/01-execution-protocol.md
   docs/archive/i18n-regression-test-plan/02-test-plan.md
   docs/archive/i18n-regression-test-plan/04-data-baseline.md
   docs/archive/i18n-regression-test-plan/05-material-requirements.md
   docs/archive/i18n-regression-test-plan/03-test-case-list.md
   docs/archive/i18n-regression-test-plan/07-open-items-and-todo.md
   docs/PROJECT.md
2. 从「阶段 0」开始：先做环境自检（04-data-baseline.md §7）、编译安装当前 commit 的 debug 包
   （设备上现装的是修复前的旧包，**先 `adb uninstall` 再 `adb install`**，见 01 §3.1）、
   核对关于页短号 = 当前 HEAD，再往下做。
3. 一条用例一个闭环：看清界面再点 → 每个断言点截图 → 对照预期 → 勾选并写「实际结果」。
   证据一律 `screencap` 到 /data/local/tmp 再 pull 到 `_evidence/stageN/`，不要写 /sdcard 顶层。
4. 每个阶段收口：flutter analyze 无问题、全量 flutter test 通过、residual 三种口径为 0、
   用例全部有勾选、缺陷与未验证都登记，然后按 06 的模板输出阶段报告，停下来等我确认。
5. 遇到 01-execution-protocol.md §6 的八种情况（基线不符 / 判不了是不是回归 / 要清数据或改系统设置 /
   要改业务逻辑 / 安全问题 / 双语言都异常 / 素材失效 / 需要我配合），立刻停下来问我，一次问清。
6. 缺素材的用例：标「未验证（缺 Mxx）」继续往下做，最后汇总缺口清单给我，不要停在原地等。
7. 发现缺陷：先复现+留证据+判定是否回归（git show 7276793^:<文件> 看改造前原样），写缺陷单；
   你被允许直接修缺陷，但改完必须 flutter analyze + 相关测试通过，并且**不许提交**（提交要我说）。
8. 不许为了「让用例变绿」降级验证或改基线文档；没做的事如实写「未验证」。

已拍板的约束（见 01-execution-protocol.md §1、04-data-baseline.md §4，不要再问、不要自行更改）：
   - 本轮特批：允许 flutter build / adb install / adb uninstall / am start / force-stop，但只对模拟器 emulator-5554
   - 仍然禁止：改 version、git commit/push、dart format（清数据与卸载重装已授权，见素材清单 M19）
   - 判定「设计如此」以 04-data-baseline.md §4.2 为准（日志中文、截图文件名、第三方内容…不算缺陷）
   - 每个阶段结束停下来等确认
```

### 2.2 交给 AI 之前必须先做的两件事

1. ~~**准备素材**~~ → **已完成**：素材已拷入模拟器 `/sdcard/素材收集清单`（M01–M20，20 个目录 / 49 个文件），PC 侧源目录 `C:\Users\root\Desktop\素材收集清单`；核对结果与缺口见 `05-material-requirements.md` §5–§6 与 `04-data-baseline.md` §9。素材不全也能开工——缺的会记「未验证」。
2. **确认工作区干净**：`git status` 无未提交改动（这样 AI 造成的改动都能用 `git diff` 审出来）。

---

## 3. 执行顺序与停止点

```
阶段 0  基线与环境          ← 装包 + 核对关于页短号；不成立不许往下
阶段 1  启动链路与首启流程   ← 隐私门禁 / 语言弹窗 / 权限门禁 / 长文 / 崩溃日志 / 重启持久化
阶段 2  媒体库与首页        ← 扫描、两种视图、排序筛选搜索、多选、文件管理、缓存、打开链接
阶段 3  播放器与音频        ← 最大一块：横竖屏、手势、全部面板、解码/超分/章节、听视频、后台播放、截图
阶段 4  字幕与弹幕          ← 内嵌/外挂/同名自动加载、在线字幕源、本地与网络弹幕、全部设置
阶段 5  网络存储与投屏      ← WebDAV/FTP/SMB、远端同名字幕、DLNA 投屏、局域网媒体服务器
阶段 6  哔哩哔哩与下载      ← 登录、番剧索引/详情/选集、在线播放、弹幕与视频下载、下载管理、更新检查
阶段 7  多语言专项与原生侧   ← 双语全页面走查、溢出/复数/插值、Android 资源、切换与持久化、白名单项
```

每阶段结束都**停下来给你审**（写在协议里）。你的审阅重点：

| 阶段 | 你必须亲自看的 |
|---|---|
| 0 | 关于页徽标短号 = 当前 HEAD（证明测的是新包）；系统语言与基线一致 |
| 1 | 全新安装/升级两种首启行为；语言弹窗默认选中；中英长文都能滚动到底 |
| 2 | 界面框架文案（非用户数据）在英文下无中文；扫描结果与改造前一致（可对比旧包 M18） |
| 3 | 每个面板逐个打开（漏改与签名改动最容易在这里出事）；音轨回退提示、诊断面板长句 |
| 4 | 字幕/弹幕全部开关与设置；英文下画布内文字不出格；网络弹幕回执文案 |
| 5 | 三种协议各连一次；错误提示是否**完整**（错误码改造成「码+参数」，最容易丢参数） |
| 6 | 在线播放 + 下载到完成 + 合并文件可播；失败态提示；更新检查弹窗 |
| 7 | Android 侧四项（应用名/通知渠道/存储卷名/崩溃提示）+ 全文「设计如此」清单核对 |

---

## 4. 已拍板结论（2026-10，见 `04-data-baseline.md` 与 `01-execution-protocol.md`）

| # | 问题 | 结论 |
|---|---|---|
| 1 | 测试 AI 允许编译/安装吗 | **允许**（`flutter build/run`、`adb install`、`am start/force-stop`），**只对模拟器 `emulator-5554`**；覆盖仓库根 `AGENTS.md` 的禁令 |
| 2 | 素材缺失怎么办 | 标 **`未验证（缺 Mxx）`** 继续往下做，最后汇总缺口清单；素材提前由用户提供 TXT 汇总 |
| 3 | 发现缺陷能改代码吗 | **可以改并跑 analyze/test，但提交必须经用户允许**；改前必须先复现+判定是否回归 |
| 4 | 被测基线 | commit `3f90e50`（分支 `English`），debug 包；若后续有新提交需登记 |
| 5 | 判定「设计如此」 | 以 `04-data-baseline.md` §4.2 的 14 条为准，不算缺陷 |
| 6 | 阶段停止确认 | **每阶段结束停下来等确认** |

---

## 5. 目录与产物约定

| 路径 | 说明 |
|---|---|
| `_evidence/stageN/` | 证据：`<用例ID>_<序号>_<说明>.png` / `.txt`（logcat） |
| `tools/_scan_features.md` | 功能面全量扫描（本策划的输入之一） |
| `tools/_scan_regression.md` | 迁移回归风险扫描（本策划的输入之一） |
| `tools/_arb_sample.md` | ARB 中英抽样对照（脚本生成） |
| `tools/_build.log` | 构建日志（可选） |
| 本目录整体 | **已入库**：`docs/archive/i18n-regression-test-plan/`（原先在 `.gitignore` 的 `/杂项文件/` 下，2026-10-04 用户要求改成英文名并归档到 `docs/archive/`） |

---

## 6. 重要提醒

1. **本目录已进 Git**：原先在 `.gitignore` 的 `/杂项文件/` 下不进版本控制；2026-10-04 用户要求全部改成英文文件名并归档到 `docs/archive/i18n-regression-test-plan/`，**现已随仓库提交**（不再有「移出 gitignore」这道待办）。
2. **不要用 PowerShell 文本命令**（`Get-Content` / `Set-Content` / `-replace`）改 UTF-8 源码（`AGENTS.md` 规定），一律用编辑工具。
3. **凭据类素材**（B 站 Cookie、网盘密码、字幕源密钥）**一律不要写进本目录的任何文件**——本目录已入库，写进来就等于提交到仓库；确需临时记录时写在 `.gitignore` 覆盖的位置（如 `杂项文件/` 下的临时目录），用完删除。
4. `docs/archive/i18n-migration-plan/**` 是**上一轮迁移**的产物：只读参考，不要修改（其 `05-residual-chinese-report.md` 会被扫描脚本覆盖，属正常）。
5. 方案里的数字都是**实测**（口径见 `04-data-baseline.md`）；**若实测与文档不符，说明代码或环境已变，执行者必须停下来报告**。

---

## 7. 现状快照（本次策划时的实测值）

| 项 | 值 |
|---|---|
| 分支 / HEAD | `English` / `3f90e50` |
| 迁移改动面 | 246 文件（+30313 / −2727） |
| lib / test 文件数 | 306 / 190 |
| ARB 键 | **1278**（zh/en 对称、无空值；= 迁移成品的 1272 + 收口修复 4 键 + `playerPlaybackFailed` + `playerAudioEffectsUnsupported`）；占位符键 176；复数键 44；多行键 21 |
| 英文侧含汉字 | 仅 2 个（`languageNameZh`、`languagePickerTitle`，故意） |
| 未翻译清单 | `l10n_untranslated.json` = `{}` |
| 门禁 | `flutter analyze` 无问题；全量 `flutter test` **1834 通过 / 13 跳过**；`residual` 三种口径 = **0 / 0 / 0**；ARB zh/en 各 **1278** 键对称 |
| 设备 | MuMu 模拟器 `emulator-5554`，Android 15/API 35，1440×2560@640dpi，系统语言 `zh-Hans-CN` |
| **功能点总数** | **481 条**（12 个功能域；见 `tools/_scan_features.md`，含入口路径与 adb 可测性判定） |
| **用例总数** | **355 条**（正文 219 + 附录 A 116 + 附录 B 定向核查 20）—— **已全部执行完毕（355/355 勾选）**，结果见 `08-final-report.md` |
| 回归风险清单 | 见 `tools/_scan_regression.md`：29 条（高 2 / 中 6 / 低 21）+ 11 条结构性隐患 + **2 处确认的中文残留（已随 `8227c21` 修复，本轮改为复核）** + 4 条未确认项 |
