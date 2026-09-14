我先看看这个新项目的结构，再同样派出调研 agent。

这是 **Kazumi** —— 用 Flutter 开发的“基于自定义规则的番剧采集与在线观看程序”，320 个 Dart 文件、约 6.6 万行。特色包括 XPath 规则引擎、WebView 嗅探视频流、弹幕、Anime4K 超分、WebDAV 同步。我先看下依赖和关键入口，然后派调研 agent。

依赖信息很关键：状态管理用 **flutter_modular + MobX**，网络用 **dio**，播放器用 **media_kit**（作者 fork 锁定版本），规则引擎基于 **XPath + json_path**，还内嵌 **ANTLR4 生成的 BBCode 解析器**、弹幕引擎、DLNA 投屏、Anime4K 着色器服务。我现在分两批派出共 5 个调研 agent（并发限制原因）。

前 3 份调研（规则引擎、播放器/弹幕、网络层）完成。现在派出剩余 2 个：数据与下载工程、架构与平台适配。

5 份调研全部完成。以下是完整报告。

---

# Kazumi 调研报告：值得学习与参考的地方

**代码基目录**：`杂项文件\参考项目\Kazumi-main\Kazumi-main`（下文路径省略此前缀，行号来自当前源码）

**一句话总结**：Kazumi 是一个用 Flutter 做的“基于自定义规则的番剧采集与在线观看”应用，五端发布（Android/Windows/macOS/Linux/iOS 侧载），320 个 Dart 文件、约 6.6 万行。它和 mpvRx 是绝佳的对照组：**mpvRx 教你“如何在一个平台上把播放器做到极致”，Kazumi 教你“如何做跨端架构 + 爬虫型应用工程 + 无服务端的多设备同步”**。它最有价值的不是某个单点技术，而是三个自研的 ~25 行并发原语贯穿全项目，以及在 WebDAV 这种“哑存储”上实现的事件溯源同步协议。

---

## 一、规则引擎与视频源解析（Kazumi 的灵魂）

### 1. 声明式规则 + 双策略引擎
规则是纯 JSON（`lib/plugins/plugins.dart`），核心就五条 XPath（searchURL/searchList/searchName/searchResult/chapterRoads/chapterResult），外加 API 模式（`lib/plugins/api_rule_config.dart`）——XPath 与 JSONPath 两种模式可按“搜索/章节”独立选择。执行引擎在 `lib/services/plugin/rule_engine.dart:20-291`，策略注入、四段式管道（准备请求→执行→解析→诊断）。亮点：
- **结构化错误**：字段枚举 → 异常带 kind/field/expression/cause，XPath 写错时报“哪个字段的哪条表达式”精确到点。
- **手写 JSONPath 子集白名单校验器**（`api_rule_strategy.dart:19-98`），避免把含脚本的任意 JSONPath 交给规则作者。
- **Trace 调试管道**：引擎输出 rawResponse/matchedFragments/diagnostics 三元组，测试页（`lib/pages/plugin_editor/plugin_test_page.dart`）能展开看“每条结果命中的原始 HTML 片段 + 被跳过节点的诊断”——规则类应用调试器的黄金配置。
- **编辑器与运行时共用同一套校验函数**（`plugin_editor_page.dart:960-1017` 直接调生产引擎的 validate），彻底消灭“编辑器能存、运行时炸了”。

### 2. 五端 WebView 视频嗅探（本项目最核心的差异化技术）
统一抽象在 `lib/webview/video/video_webview_controller.dart`（4 条 Stream 事件 + 工厂按平台分发），平台实现：Android（inappwebview，按 `DOCUMENT_START_SCRIPT` 能力探测二选一）、Apple（WKWebView + ContentBlocker）、Windows/Linux（fork 的库，在 C++/WebKitGTK **原生层**直接发 m3u8 事件）。

四条互补嗅探通道（`video_webview_impl.dart`）：
1. **原生请求拦截** `shouldInterceptRequest`：`.m3u8` 后缀或“带 `Range: bytes=` 头且非静态资源扩展名”的启发式判据（L450-468 的排除表）——这个“Range 请求 ≈ 媒体流”判据可移植；
2. **JS hook**：monkey-patch `Response.prototype.text` 和 `XMLHttpRequest.open`，响应体以 `#EXTM3U` 开头即上报，并用 MutationObserver 对动态 iframe **递归注入**；
3. **video 标签观察**：MutationObserver 监听 `<video>/<source>` src；
4. **1s 轮询 DOM 兜底**（防注入被站点反制）。

命中即 `unloadPage()` 释放页面但保留 WebView 实例复用。下载场景还有 WebView worker 池（`video_source_resolver_pool.dart`，1-5 个租约按需扩缩）。Apple 端用 ContentBlocker 拦 `devtools-detector.js` 防站点反调试、禁图片加载省流量提速——细节意识很强。

### 3. 验证码三类型可配置（`lib/webview/captcha`）
把“人机验证”抽象成三种类型：①XPath 找验证码图 → **Canvas 抓像素转 base64**（绕防盗链直链）展示给用户 → MutationObserver 等图消失；②XPath 找按钮自动 click；③规则作者写自定义脚本，注入 `window.KazumiCaptcha` 受控沙箱 API。验证通过后**收割 Cookie + UA 成对保存**（`plugin_cookie_manager.dart`），后续 dio 请求用同一 UA——风控 clearance cookie 与签发 UA 绑定，UA 不一致会再吃挑战页（`rule_engine.dart:240-254` 注释）。这是“爬虫型 App 打通 WebView/dio 双网络栈”的标准范式。

### 4. 规则仓库工程化
GitHub `KazumiRules` 仓库 + gitcode 镜像（拦截器换域名，业务层无感）；apiLevel 版本门禁（客户端太旧拒绝装新规则）、更新校验“下载的规则名 == 目录名”防错包、**绝不降级**；`kazumi://<base64(json)>` 深链分享规则；批量更新用 4 worker 并发池。

---

## 二、视频播放与弹幕

### 1. AsyncSession 所有权模型（全项目最重要的模式）
`lib/utils/async_session.dart`（~50 行，带单测）：版本号令牌式“可替换异步任务”——任何新 `begin()` 使旧 session 失效，异步流程在每个 await 后检查 `isActive`，过期即放弃副作用。播放器初始化（`player_controller.dart:286-288`）把它与 `identical(player)` 双重校验组合，彻底解决“快速切集时旧 player 的事件回写新状态”。配套的 `AsyncSerialQueue`（写串行）和 `AsyncSingleFlight`（合并并发请求）共 ~100 行，**覆盖了 UI 应用 90% 的并发正确性问题**，在存储、同步、下载、搜索、验证码 6+ 个子系统反复复用。

### 2. media_kit 集成要点（`player_playback_controller.dart`）
- Android SDK≥34 自动用 Vulkan + `gpu-next`（着色器性能更好），否则回退 `gpu` 防黑屏（L343-365）；
- 代理从 Dart 侧透传给 mpv（L314-334）；`demuxer-cache-dir` 显式指向 `getTemporaryDirectory()`（mpv 默认 Linux 路径在其他平台损坏，L283-287 附中文注释）；
- `af=scaletempo2=max-speed=8` 保证 3 倍速音调正确；
- Anime4K 三步法：assets 复制到沙盒目录 → 拼绝对路径串（Windows 用 `;` 其他平台 `:`）→ `change-list glsl-shaders set` 播放中热切换；`mediacodec_embed` 渲染器不支持 shader 时自动禁用超分并提示（这是 Flutter 用 libmpv 着色器的标准解法）；
- 截图走 fork 的 `safeScreenshot()` 返回原始 BGRA 帧 → 按 `rawLength % height == 0` 自推断几何 → `TransferableTypedData` 零拷贝进 `Isolate.run` 后台 PNG 编码（`player_screenshot_service.dart`）。

### 3. 弹幕系统（`player_danmaku_controller.dart` + canvas_danmaku）
数据源是**弹弹play API**（Bangumi ID → 番剧匹配 → 分集弹幕，用字符串相似度选最佳匹配）。同步方案简单高效：**秒级分桶**（`Map<int, List<DanmakuEntry>>`，查询 O(1)）+ 每秒发射时同秒多条弹幕在 1 秒内**错峰 stagger** + **代数失效**（seek/切档时递增 generation 使所有未发射延迟弹幕一次性作废，比逐个 cancel Timer 简洁）。还有实用的弹幕归一化去重算法（`lib/utils/danmaku.dart:11-98`）：全半角统一、连续重复字符压到 3 个、5 秒窗口聚合成“内容 xN”。

### 4. SyncPlay 客户端（仓库里工程质量最高的模块）
`lib/services/player/syncplay_client.dart`（951 行纯 Dart）：RawSocket 手写 JSON 行协议（括号配对扫描切包，正确处理粘包/半包）、**STARTTLS 原地升级** `RawSecureSocket.secure(plainSocket, subscription:, host:)`、RTT 指数移动平均 + 前向延迟补偿（`avrRtt/2 + (clientRtt - serverRtt)`）、`ignoringOnTheFly` 确认防回声、背压写队列、单次连接语义（重连必须新建实例）。可作 Flutter 实现 TCP 协议客户端的范本。有趣的是它和 mpvRx 的 Syncplay 实现收敛到了同一套时间补偿策略，可互相印证。

### 5. 系统媒体控制与 PiP
`audio_controller.dart` 用 audio_service（Android/iOS）+ fork 的 audio_service_mpris（Linux D-Bus）+ audio_service_win（Windows SMTC）三包统一五端锁屏/通知/媒体键；**MediaItem 按 cacheKey 去重防通知栏闪烁**；来电/拔耳机中断自动恢复。PiP 的宽高比用 **gcd 约分成最简分数**避免 `Rational` 精度问题，Android 12 `setAutoEnterEnabled` 手势自动进 PiP；桌面端用 `window_manager` 仿制桌面 PiP 小窗。

---

## 三、网络层

1. **DioFactory 多语义单例**（`lib/request/core/dio_factory.dart`）：api/rules/plugin/download 四个 Dio 各带语义配置（下载超时放宽到 15s/30s），镜像切换做成**拦截器**（onRequest 按 host 重写域名），代理热切换只需 `DioFactory.reset()` 重建，client 代码零改动。
2. **四网络栈统一代理注入**：Flutter 应用里有 4 个独立网络栈——dio、图片缓存（替换 `CachedNetworkImageProvider.defaultCacheManager` 的 FileService）、各平台 WebView（Android setProxyOverride / Windows `--proxy-server=` 启动参数）、mpv——`ProxyManager` 统一触发刷新。**Windows 系统代理监听是教科书级 FFI**（`system_proxy_service.dart`）：win32 读注册表 `Internet Settings`，`RegNotifyChangeKeyValue` + OS 线程池等待 + `NativeCallable.listener` 回调（注释解释了为什么不能阻塞 isolate——会卡热重载），300ms 去抖。
3. **计量网络 → 播放缓存动态降级**（`metered_network_service.dart` + `playback_cache_policy.dart`）：移动网络下 mpv `demuxer-max-bytes` 从 1500MB 压到 2MB，省流量实现为“动态调参”而非禁用功能；不可判定时保持上一个值不误放。
4. **超时三级分级 + 内容嗅探防护**：常规 API 12s → 下载 Dio 15s/30s → 单请求覆盖（m3u8 文本 15s、直链视频流 30 分钟）；`_fetchM3u8` 下载超过 2MB 就主动 cancel——“这显然不是 m3u8 文本”的快速失败，成本几乎为零（`download_manager.dart:826-867`）。
5. **Bangumi API 礼貌访问**：收藏分页拉取每页间 250ms 限速 + onProgress 回调；自建镜像的防滥用签名（method+path+body摘要+时间戳的 SHA-256，12 行实现）；官方/镜像/鉴权镜像三域名矩阵。
6. 错误映射带网络上下文：unknown 错误时实时查 connectivity_plus，把“正在使用移动流量/wifi/未连接”拼进用户提示。

---

## 四、存储、下载与同步

1. **Hive 多 box + 双层容错**（`lib/services/storage/storage.dart`）：8 个业务域独立 box（损坏只丢一个域），box 打开失败自动删 `.hive`/`.lock` 重建；读取层逐条 try-catch 跳过坏记录。**类型化设置注册表** `SettingKey<T>`（728 行）带默认值/分组/按设备形态的默认值解析器，比裸字符串 key 安全得多。备份/恢复直接复制 `.hive` 文件、“用 Hive 读 Hive”（内存中 openBox bytes）合并，无需自研序列化格式。
2. **事件溯源历史同步协议**（`lib/modules/history/history_sync.dart`，933 行——全项目最值得学的算法设计）：在没有服务端的 WebDAV 上实现多设备 last-write-wins 合并。快照 + 逐槽版本号 + **墓碑删除**（防旧设备复活已删记录）+ `clearVersion` 清空水位 + checkpoint（本地日志超 1MB 滚动成 pending 文件，同步失败不丢数据）+ 流式合并器（O(活跃槽) 内存）。**版本号字符串** `updatedAt 补零 16 位 + '|' + eventId` 直接字典序比较，同毫秒确定性 tie-break，很巧妙。容错策略不对称：远端文件解析失败整个**隔离**为 `.invalid.*`，本地日志容忍脏行跳过（且上传前预清洗，避免一行脏数据让本设备日志被所有对端隔离）。
3. **m3u8 下载器**（`lib/services/download/download_manager.dart`）：分片 `.tmp`+rename 原子落盘、按序号扫描已存在分片断点续传、嵌套 m3u8 展开（深度上限 3）、**AES-128 不解密**——加密分片原样保存 + 重写本地 playlist 指向本地 key 文件，解密交给播放器的 ffmpeg（零转码离线化 HLS）；直链下载 Range 续传 + **416 自愈**；分片重试退避 1s/3s/9s；广告过滤模拟 ffmpeg hls_ad_filter 的时长启发式。进度 tick 只进内存、状态变化才落盘（防 Hive 写放大）；通知更新用 trailing-edge 合并防通知风暴。启动时把 downloading/pending 诚实重置为 paused（内存队列不持久化就不假装续跑）。
4. **Android 后台下载的务实架构**：前台服务只做保活+通知交互，下载逻辑留在主 isolate，跨 isolate 只传控制消息——避免把整套下载状态搬进 TaskHandler isolate。
5. 大 blob（视频/弹幕）出 Hive 进文件系统，防止 Hive compact 内存尖峰（有明确的踩坑迁移注释）。

---

## 五、架构与工程实践

1. **modular 三级作用域约定**（`core_module.dart:17-21` 注释成文）：无 path 模块=应用级单例、有 path 模块=Tab 级、route 内 provide=每实例——文档化的 DI 作用域规则值得任何 modular 项目照抄。MobX 侧 `PlayerController` 组合 6 个子控制器，子控制器通过**闭包 getter** 互相连接而非持有引用，避免千行巨型 Store；UI 用窄 Observer 让 1 秒进度 tick 只重建进度条。
2. **初始化三层兜底**：Hive 失败 → 独立 StorageErrorPage（提示删除目录自救）；子系统失败 → 功能降级（Bangumi 同步失败自动关闭该功能）；桌面端 `waitUntilReadyToShow` + 原生改窗口先隐藏防白屏闪烁（Windows/macOS runner 都有配合改动）。
3. **fork 依赖管理**：5 个上游不可控的重依赖（media_kit、两个 webview、两个 audio_service 平台包）fork + 40 位 commit 锁定，并用 `dependency_overrides` 把 8 个 `media_kit_libs_*` 全钉到同一 commit 防子包漂移——fork 的都是“无法绕开的组件”，数量克制，是依赖治理的合理样本。
4. **CI 五端矩阵**（`release.yaml` 595 行）：`flutter-version-file: pubspec.yaml` 让 Flutter 版本随 pubspec 走（单一事实源）；Windows 产物 zip → SignPath 签名 → MSIX → 再签；iOS 无证书构建后 Frameworks 逐个 ad-hoc 重签；linux arm64 优先自托管 runner；`flutter analyze --fatal-warnings` 做门禁。
5. **更新机制**：自建镜像 API 绕过 GitHub 直连限制、按安装类型（msix/zip/deb/dmg/apk）匹配 assets、sha256 校验且“已下载且哈希命中即跳过”（断点续传的廉价替代）、Android onboarding 专设“更新源选择”步骤。
6. 其它值得记的细节：日志 forceLog 用 `Zone.current[#_forceLog]` 符号传递（info 不落盘但需要时强制留痕）；`dynamic_color` 的 legacy CorePalette 路径导致 surfaceContainer 角色为空的**上游缺陷规避**（用 `ColorScheme.fromSeed` 重派生）；macOS 沙盒下载目录用 security-scoped bookmark 跨重启恢复；深拷贝快照隔离 MobX observable 与仓库数据。

---

## 六、反面参考（不足）

- **无集中重试机制**：API 层多数“吞错返回空列表”，调用方无法区分“无数据”与“网络失败”；重试只在下载层手工实现。
- **计量网络是近似判断**：connectivity_plus 只能判断 wifi/mobile，不是真正的 `NET_CAPABILITY_NOT_METERED`（计费 WiFi 会漏判），要做准需 MethodChannel 补原生。
- DLNA 投屏无进度/暂停回控，且 Referer 无法转发（防盗链源投屏必失败）；外部播放器发射后即脱手，无进度追踪。
- 规则 Cookie jar 是内存态不持久化（有意为之，重启重验），需要长期登录态的产品应换 PersistCookieJar。
- 刻意不做 i18n（locale 锁死中文），只适合国内目标用户的场景。
- `upgrader` 在 pubspec 声明但零引用，属遗留依赖——依赖清单卫生的小反例。

---

## 七、与 mpvRx 的对比（既然两个都在研究）

| 维度 | mpvRx（Kotlin 原生） | Kazumi（Flutter） |
|---|---|---|
| 播放核心 | 直接 JNI 绑 libmpv，进程级单例 + generation 世代号 | 经 media_kit（fork 锁 commit），AsyncSession 所有权令牌 |
| 异步竞态解法 | generation + `commandForGeneration` | AsyncSession + `identical` 双重校验——**两者是同一问题的不同表述，值得对照理解** |
| 弹幕 | 无 | dandanplay API + 秒级分桶 + 代数失效 |
| 网络供流 | 本地 HTTP 代理 + capability token（mpv 只见 localhost URL） | WebView 嗅探出真实 URL 直供 mpv（+代理透传） |
| 同步 | Syncplay 客户端 | Syncplay 客户端 + **事件溯源 WebDAV 多端同步**（后者是 Kazumi 独有亮点） |
| 视频源获取 | 用户给 URL/文件/Jellyfin/torrent | 爬虫式：XPath/API 规则 + WebView 四通道嗅探 + 验证码 |
| 着色器 | 安装期 GLSL 二次优化（FP16 注入、采样合并） | 三步法加载 + 档位 + 能力降级 |
| 平台 | Android 深度优化 | 五端一致性 + 原生 MethodChannel 分流 |

两项目互补性很强：做播放器内核与 Android 深度优化看 mpvRx；做跨端架构、爬虫工程、无服务端同步协议、Flutter 并发模式看 Kazumi。

---

## 八、建议的学习切入顺序

1. `lib/utils/async_session.dart` + `async_serial_queue.dart` + `async_single_flight.dart`——三个 ~25 行的原语，先看测试再 grep 它们的使用点
2. `lib/modules/history/history_sync.dart`——事件溯源同步协议，读版本号/墓碑/checkpoint 设计与注释
3. `lib/webview/video/impl/video_webview_impl.dart`——四通道嗅探 + 广告黑名单 + Range 启发式
4. `lib/services/download/download_manager.dart`——m3u8 离线化的可靠性清单
5. `lib/services/player/syncplay_client.dart`——手写 TCP 协议栈范本
6. `lib/services/network/system_proxy_service.dart`——Windows FFI 注册表监听
7. `lib/services/plugin/rule_engine.dart` + `plugin_test_page.dart`——声明式规则引擎与可调试性设计

Kazumi 的代码风格与 mpvRx 相反但同样有价值：mpvRx 靠注释记录决策（ADR 式），Kazumi 靠**小而可测的原语 + 明确的职责边界注释**（如 foreground service 只保活、ProxyManager 只发重建指令）。两者合起来基本覆盖了“视频类应用”从内核到业务的全部工程问题域。