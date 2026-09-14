我先看看这个目录里有什么项目。

目录下有一个 `mpvRx-master`（已更新至 2.4.0），我来探索它的结构。

这是 **mpvRx** —— 一个基于 libmpv 的 Android 视频播放器。我先摸清源码结构，然后并行深入调研各个模块。

444 个 Kotlin 文件，模块划分相当细（data/network、domain/torrent、domain/thumbnail、cpp JNI 层等）。我先补全结构信息，然后并行派出多个调研 agent 深入各模块。

近 17 万行 Kotlin 代码，涵盖播放器、网络、种子流式播放、数据库、Compose UI 等。我现在并行派出 5 个调研 agent，分别深入：播放核心、性能优化、网络层、架构工程、UI/UX。

已完成 3 份调研（性能优化、网络层、架构工程）。还有两个主题（播放核心、UI 交互）因并发限制失败，我现在重新派出。

5 个方向的深度调研全部完成。这个项目是 **mpvRx**（GitHub 上 Riteshp2001/mpvRx 的 master 分支）——一个基于 libmpv 的 Android 视频播放器，Kotlin + Jetpack Compose，约 17 万行代码、444 个 Kotlin 文件。下面是完整的调研报告。

---

# mpvRx 调研报告：值得学习与参考的地方

**代码基目录**：`杂项文件\参考项目\mpvRx-master\mpvRx-master\app\src\main\java\app\gyrolet\mpvrx`（下文简写 `…`，行号来自当前源码）

> **本次更新说明**：参考项目已更新为 **mpvRx 2.4.0**（"Playlists, Playback Reliability & Expressive Navigation"），
> 与上一份报告所依据的旧版 mpvRx-master-kt 项目不同——缩略图、播放可靠性、导航等多处已大幅重构。
> 本次重点补调研：**2.4.0 的 "Reliable Seek Thumbnails"（进度条缩略图硬化）**，并与本项目（小牛Player/moumou，
> 见 `docs/archive/ARCHITECTURE.md` §4.9）的同款实现逐点对比（见文末「进度条缩略图：mpvRx vs 本项目」）。所有行号、文件路径均以 `杂项文件\参考项目` 下的当前源码为准。

**一句话总结**：这个项目最大的学习价值不是“功能多”，而是它在**原生播放引擎（libmpv）↔ Android 生命周期 ↔ Compose UI** 三个世界的接缝处做了大量教科书级的工程处理——几乎所有非默认决策都带注释解释“为什么”，等于一边读代码一边读踩坑笔记。

---

## 一、视频播放核心（本项目最精华的部分）

### 1. 进程级单例播放核心 + 观察者分发
`…/ui/player/PlaybackSession.kt`（1415 行）是一个 Kotlin `object`，全进程唯一持有 libmpv 实例。Activity、Service、通知栏重入全部退化为“Surface 重新绑定”，而不是销毁重建播放器——旋转、PiP、后台播放、从通知栏点回 App，播放状态从不中断。这是所有绑定 native 引擎 App 的通用架构答案。

### 2. `PlaybackProperty<T>`：native 属性 → Compose 状态的桥梁
`PlaybackSession.kt:47-77`。`PlaybackSession.propFloat["speed"].collectAsState()` 一行代码把任意 mpv 属性变成可收集的 StateFlow，懒注册观察、核心重建后自动 reobserve。UI 层完全不用手写 observer，是“命令式 native ↔ 声明式 Compose”最优雅的接缝。

### 3. generation 世代号防串台
每次 load 自增世代号（`PlaybackSession.kt:650-660`），所有异步操作（字幕加载、进度恢复）执行前校验世代——“快速切台时上一步的异步操作跑完了”这类 bug 的标准解法。

### 4. Surface 失联前先挂起视频轨
`PlaybackSession.kt:1268-1295`：换绑 Surface 前先 `vid=no`，防止 MediaCodec 硬解器与正在销毁的 ANativeWindow 竞争崩溃；后台播放时 `vo=null` 实现零 GPU 占用的纯音频模式。配合 `coreConfigurationKey` 指纹（`MPVView.kt:70-97`），只有渲染后端真变才重建 native core。

### 5. 双音频 guard（防 seek 爆音）
`PlaybackSession.kt:1084-1158`：seek 时 60ms 瞬态静音、换文件全程静音，消除解码器 flush 间隙的音频碎片。极小众但极专业的细节。

### 6. JNI 层两个黑科技（`app/src/main/cpp`）
- `android_compat.c`：mpv 0.41 的裸 `clone()` 子进程触发 Android 16 的 fdsan 误报 abort，它在 `JNI_OnLoad` 里运行时关闭 fdsan——**“上游 native 库与新系统不兼容时打运行时补丁”的范例**。
- `ytdl_wrapper.c`：把可执行文件伪装成 `libytdl.so` 部署到 nativeLibraryDir，绕过 Android 10+ 禁止从 data 目录 exec 的限制，宿主嵌入式 Python 跑 yt-dlp。

### 7. 生命周期决策纯函数化
`…/ui/player/PlayerLifecyclePolicy.kt`（仅 76 行）把“Home 键是否进 PiP、onDestroy 是否保活后台播放、PiP 被划掉算什么”等 6 个决策全部抽成可单测的纯函数，Activity 只传参。

---

## 二、性能与功耗优化

### 1. Thermal-aware 双层降级（README 的招牌卖点，确实做得好）
- `…/ui/player/ThermalMonitor.kt:47-84`：用 Android 11+ 的 `PowerManager.getThermalHeadroom()` 预测热余量，映射为着色器采样预算。
- `…/ui/player/anime4k/Anime4KPlayback.kt:58-101`：**第一层** proactive——丢帧是滞后指标（等丢 45 帧时 SoC 已经在节流），所以热余量 < 0.40 先降档；**第二层**兜底——监听 mpv 的 `drop-frame-count`/`vo-delayed-frame-average-ms` 等运行时指标再降。4K 源直接禁用 Anime4K（升频无收益纯发热）。

### 2. Anime4K 着色器安装期二次加工（最独特的优化）
`…/domain/anime4k/Anime4KManager.kt:180-382`：首次从 assets 复制 GLSL 时在 Kotlin 侧改写源码——①注入显式 `mediump` 限定符，对抗 Adreno 驱动静默把 FP16 提升回 FP32（注释解释了只有显式限定符无法被驱动覆盖）；②FSR 等用位操作的 pass 通过白名单保持 highp；③把 C.R.E.L.U 卷积的重复纹理采样合并为 3×3 预取。**运行期零成本，安装期一次完成**。

### 3. 渲染后端决策矩阵
`…/ui/player/RendererBackendPolicy.kt` 纯函数决策 gpu-next/gpu × Vulkan/OpenGL 四象限；hwdec 值写成 `"mediacodec,mediacodec-copy,no"` 有序回退链，把“硬解失败降级”交给 mpv 成熟机制。`MPVView.kt:183-298` 的 `initOptions` 是 **mpv 移动端调参模板**：每条非默认选项都注释了原因（`framedrop=vo` 防抖动累积、`video-sync=audio` 解决 24fps@60Hz、ffmpeg 级有界重连且明确不用 `reconnect_at_eof` 因为合法 VOD EOF 必须正常结束……）。

### 4. 进度条 seek 预览缩略图（2.4.0「Reliable Seek Thumbnails」重点硬化）

**第二解码引擎**：`is.xyz.mpv.FastThumbnails`（来自 mpv-android 的 `mpvlib.aar`，原生 FFmpeg 缩略图器）。
拖动进度条时**播放器本体完全不 seek**（画面停在旧位置，`PlayerControls.kt:1573-1582` 只调 `updateSeekThumbnailPreview`），
预览帧全部由这个独立引擎直接解出显示——「ThumbFast 风格」的名字由此而来（对齐 mpv 的 ThumbFast 脚本思路：第二实例只出图、不碰播放内核）。
初始化在 `App.kt:217-231` 延迟 warmup（`scheduleFastThumbnailWarmupOnce`，`compareAndSet` 单飞、失败重置可重试），不阻塞冷启动。

**调度与缓存**（`PlayerViewModel.kt:4011-4399`，常量见 2439-2450）：
- 位置量化到**秒级 bucket**（`SEEK_THUMBNAIL_CACHE_BUCKETS_PER_SECOND = 1f`），内存 LruCache 32MB（`SEEK_THUMBNAIL_CACHE_KB`）、最大边 320px（`SEEK_THUMBNAIL_MAX_SIZE`）；
- 未命中先 `findNearestSeekThumbnail` 展示 ±2 bucket 邻近图，再异步补精确帧；
- **单 worker latest-wins**：`limitedParallelism(1)` 协程 + `pendingSeekThumbnailRequest` 只留最新请求 + `requestId` 单调递增判 stale；
- 失败 10s 冷却（`SEEK_THUMBNAIL_FAILURE_COOLDOWN_MS`，失败表上限 128 条防内存泄漏）；
- 预取：成功解码后、无更新请求且非网络源时，补 ±2 bucket（`prefetchSeekThumbnails`）。

**2.4.0 的硬化点（本次更新的核心，逐条都是「防旧帧覆盖新帧」）**：
1. **解码超时不取消、完成后 late-publish**（`loadSeekThumbnail` + `maybePublishLateSeekThumbnail`）：
   `withTimeoutOrNull(2500ms)` 只是让 worker 不阻塞继续响应拖动，**解码本身不被取消**；慢解码（尤其网络源 open 就超窗口）
   完成后通过 `maybePublishLateSeekThumbnail` 仅在「精确桶命中」或「邻近且当前为空」时回填——慢帧不会覆盖已显示的新帧，但也不会凭空丢失。
2. **源 pinning**（`resolveSeekThumbnailSource` + `pinnedSeekThumbnailSource`）：一个媒体项只解析一次源，
   按 `stream-open-filename` → `path` → `host.currentThumbnailSource()` 取首个可解码者，跳过 `fd://`/`edl://` 等 mpv 伪协议
   （`MPV_ONLY_PSEUDO_PROTOCOLS`）。否则 mpv 属性在 seek 中途短暂抖动会让缓存 key 漂移、整条缓存失效。
3. **capacity-blocked 重排队**（`ensureSeekThumbnailWorker` + `awaitSeekThumbnailDecodeSlot`）：最多 3 个在飞解码
   （`SEEK_THUMBNAIL_MAX_INFLIGHT_DECODES = 3`），满了就把请求重新排回 pending 并 `select` 等任一解码完成，而不是直接丢弃——**既不无限并发、也不丢请求**。
4. **content:// 源走 `/proc/self/fd/`**（`generateSeekThumbnail:4240-4249`）：`openFileDescriptor` 后把 fd 伪装成文件路径喂 FFmpeg，SAF 授权源也能出图。

> **解码方式修正**：`FastThumbnails.generateAsync(...)` 在所有调用点都传 `useHwDec = false`——seek 预览
> （`PlayerViewModel.kt:4247/4255`）与列表缩略图（`ThumbnailRepository.kt:450/1178`）**统一软解**，
> 与旧版报告「seek 预览开硬解、列表用软解」的说法不同。mpvRx 的取舍是：缩略图用**独立 FFmpeg 软解实例**，
> 不抢播放内核的 MediaCodec 硬解器，宁可慢一点也不与正在播放的硬解链路争抢。这正是与本项目（硬解优先）的核心分歧，见文末对比。

### 5. 缩略图三级缓存体系（媒体库列表缩略图，与 seek 预览共用同一 FastThumbnails 引擎）
`…/domain/thumbnail/ThumbnailRepository.kt`：内存 LruCache（maxMemory/6）→ 磁盘缓存（key 带 `video-thumb-v2` 版本前缀 + mode/quality 后缀防旧缓存错配，JPEG 落盘）→ 生成管线（内嵌封面 → FastThumbnails → MediaMetadataRetriever 兜底）；`ongoingOperations` 用 `putIfAbsent` 做同 key 并发去重；网络图失败记忆（30s 冷却）防列表滚动时无限重试；并行度按 CPU 核数（≤2 核→1 … 8 核→4）和 `isLowRamDevice` 缩放；Smart 模式用 `isMostlySolidThumbnail` 跳过纯色/黑帧首帧、回退到 33%/10s/20s/30s 多个候选位置。

### 6. 其它小而精的做法
- **自适应轮询频率**（`PlayerViewModel.kt:1420-1428`）：进度轮询按状态在 100/500/1000ms 间切换，比固定 50ms 减半 JNI 读取。
- **空闲 core 延迟回收**（`App.kt:191-221`）：`collectLatest` 自取消的空闲计时器，既快速重入又不永久 pin 解码器内存。
- **电池联动**：拔充电线自动降环境光着色器档位、插上精确还原八参数快照（`PlayerViewModel.kt:5726-5764`）。

### 7. 2.4.0 新增的播放 / 启动优化
- **Faster Video Startup**（CHANGELOG 2.4.0）：把启动路径上的「阻塞式外部资源同步」移除——内部 mpv assets 校验通过后立即复用、外部资源同步推迟到播放开始后异步执行，缩短冷启动到首帧的等待。思路可复用：**「能用就先用、不能用的后台补」**，别让资源校验阻塞首屏。
- **Actionable Player Diagnostics**（stats Page 6）：把进程内存 / Java 与 native 堆 / mpv 缓存 / 缓冲时长 / packet-file cache / torrent / 播放健康数据全挂进播放器诊断页——排障时不用再猜「是缓存、堆还是解码」。

---

## 三、网络与流媒体（第二个精华区）

### 1. 本地 HTTP 代理 + capability token（所有嵌入式播放器 App 通用的架构）
`…/data/network/proxy/NetworkStreamingProxy.kt`：SMB/FTP/WebDAV 文件经 NanoHTTPD 绑定 `127.0.0.1` 随机端口的代理喂给 mpv。关键设计：
- `registerStream` 返回带 24 字节随机 token 的 URL，**凭据与真实路径永不出现在 URL/Intent/日志里**；
- 完整的 Range/206/HEAD 支持（`HttpByteRange.kt` 是防御性 Range 解析器，明确拒绝 multi-range）；
- 文件 size 探测缓存，否则每次 Range 前都串行探测拖慢 seek；
- `awaitProxyIo`（283-311 行）刻意不用 `runBlocking` 而用有界 IO scope + latch 桥接同步服务器与 suspend 上游——**“同步 HTTP 服务器包装 suspend 客户端”的教科书实现**。

### 2. HLS 代理的 manifest 递归重写
`HlsStreamingProxy.kt:363-479`：拉上游 m3u8 后把所有 STREAM-INF/分片/密钥 URL 重写为本地路由，专治“WebView 登录态 + ffmpeg 原生 HLS 不兼容”；`credentialsFor`（492-506 行）只向同源转发 Authorization/Cookie，防 manifest 注入 URL 劫持会话头。

### 3. Torrent 边下边播调度算法（可直接抄）
`…/domain/torrent/TorrentStreamingEngine.kt:626-652` + `TorrentProxyServer.kt:117-139`，基于 libtorrent4j：
- 顺序下载 + 选中文件 TOP_PRIORITY，**头部 16 个 piece 立即高优 + 逐个 100ms 递增 deadline（快速开播），尾部 8 个 piece 也预取（MP4 的 moov 索引常在尾部）**；
- 按播放位置滚动 16MiB read-ahead 调整 piece 优先级，且刻意不移动全局 sequential range（注释解释了 mpv 的头尾探测会饿死真正的播放读）；
- prepare/start 两段式：先只抓元数据弹选集 UI，凭 preparationId 复用会话开播，避免二次抓 metadata。

### 4. 凭据安全
`…/data/network/credentials/NetworkCredentialCipher.kt`：不用 EncryptedSharedPreferences，自己封装 Keystore + AES-GCM，**把格式前缀作为 AAD 绑定**（密文换容器即失效）、密文带版本号、旧明文惰性迁移、UI 层永远只拿脱敏模型。

### 5. yt-dlp 工程链
`…/ui/player/ytdlp/YtdlpManager.kt`：嵌入式 Python 3.13 + native 桥 + 环境变量注入 + 独立 CA 证书。两个踩坑经验值千金：**exclude 列表**让 .m3u8/.mp4 直链跳过 ytdl_hook 走原生 demuxer（否则 generic extractor 处理不了带 token 的 CDN 链接）；`all_formats=yes` 保持 mpv 延迟选择（split 音视频站点依赖此路径）。`YtdlpOptionsBuilder` 把用户偏好（编码/容器/分辨率/HDR）编译成 yt-dlp 多级回退 format 表达式。

### 6. Cookie 桥
`…/network/AndroidCookieJar.kt:76-115`：把 OkHttp/WebView 双向同步的 cookie 用 AtomicFile 原子导出为 Netscape cookie 文件（含 `#HttpOnly_` 处理）供 libmpv 读取——“App 内登录过的网站视频直接在 mpv 里播”的胶水方案。

---

## 四、架构与工程实践

1. **响应式偏好层**（`…/preferences/preference/`）：SharedPreferences 之上封装 `Preference<T>`（get/set/`changes(): Flow`），listener 包成 callbackFlow 再 `shareIn(WhileSubscribed(5s))`——注释量化了动机：浏览器每张卡观察十几个偏好，不共享会写放大。
2. **`MpvConfigOverridePolicy`**（`preferences/MpvConfigOverride.kt:281-302`）：定义 15 组“选项所有权”，用户 mpv.conf 接管某组选项时 App 端对应功能自动禁用、命令层拦截——解决了 mpv 前端经典难题“App 设置与用户配置双写冲突”。
3. **修复型 Room 迁移**（`di/DatabaseModule.kt:377-529` 的 MIGRATION_8_9）：用 `PRAGMA table_info()` 探测线上库的**真实**表结构再决定迁移路径，应对“用户库版本号与实际 schema 不一致”的线上脏状态。16 个版本全部手工迁移 + schema 快照入库。
4. **能自愈的崩溃页**（`presentation/crash/CrashActivity.kt`）：用关键词识别“数据库类崩溃”，展示一键删除 db 修复按钮——崩溃页从“展示堆栈”升级为“用户自救”。
5. **构建矩阵**（`app/build.gradle.kts`）：3 flavor × ABI splits，`versionCode*10+abiCode` 编码、按 flavor 换 AAR、git 元数据注入 BuildConfig；CI 校验产物矩阵甚至断言“noVulkan flavor 不该出现分 ABI 包”。
6. **AI 辅助开发基建**（`AGENTS.md` + `.claude/`）：用 graft 工具把仓库索引成带精确 file:line 的知识节点，Claude hooks 在每次编辑后增量重建索引——"给 AI 的 README”如何不随代码过时的成熟实践。
7. **安全文件夹的事务性搬移**（`database/repository/SecureFolderRepository.kt:94-182`）：缓冲复制→字节数校验→写库→删源，每步失败逐级回滚——文件操作事务化的范本。

---

## 五、UI 与交互

1. **手势系统**（`…/ui/player/controls/GestureHandler.kt`，1403 行）：4 层 `pointerInput` 串联（多击 / 垂直+长按 / 捏合 / 水平 seek），全部基于 `awaitEachGesture` 原语手写状态机。值得学的细节：单击延迟 250ms 执行、双击到来即取消的手势消歧；>20px 后用 1.5 倍倾斜比锁定方向；跨层互斥变量；系统手势死区；长按倍速 5 步渐进 ramp 防爆音；字幕 `sub-pos` 百分比 ↔ 屏幕像素的坐标反算（正确处理 ASS 字幕渲染在视频帧内）。
2. **动画体系**（`ui/player/AnimationStyles.kt` + `ui/theme/Motion.kt`）：动画风格 = 枚举 + 转换工厂，控件只声明“从哪来”，全局换肤；弹簧参数集中为 `AppMotion` 令牌；读系统 `areAnimatorsEnabled()` 做 reduce-motion 全局降级（常被忽略的无障碍细节）。
3. **主题系统**（`ui/theme/AppTheme.kt`）：33 个主题每个只存 8 个种子色，全套 M3 ColorScheme 用 `compositeOver/darken` 程序化派生——新增主题成本极低；主题切换用“截屏冻结旧界面 + 径向揭示新主题”的 Telegram 式动画。
4. **`PlayerSheet`**（`presentation/components/PlayerSheet.kt:260-313`）：基于 AnchoredDraggable 的底部弹层，`preUpPostDownNestedScrollConnection` 实现 sheet 内容滚动与拖拽关闭的无缝嵌套滚动交接——播放器复杂弹层的成熟模板。
5. **Compose 包裹复杂 View 的范式**（`ui/editor/MpvScriptEditor.kt`）：内嵌 Sora 编辑器 + TextMate 语法高亮给 mpv conf/Lua，用 Kotlin **类委托只覆写一个方法**注入 mpv 专属自动补全，Compose 主题逐项映射到 View 体系的 EditorColorScheme。
6. **投屏**（`ui/cast/CastMediaServer.kt`）：本地内容投 Chromecast = 手机起临时带 token 的 HTTP Range 服务器，221 行的最小可行方案，可整体移植。

---

## 六、反面参考（同样值得看的不足）

- **无全局网络感知**：没有 ConnectivityManager.NetworkCallback、无计费网络提示、无弱网自适应——弱网处理全靠 IO 层有界重试。做播放器网络体验时要自己补这块。
- **Syncplay 密码明文存储**（SharedPreferences），与网络凭据的 Keystore 方案形成项目内不一致。
- HLS 代理的错误日志会输出 URI 与异常消息，与 NetworkStreamingProxy 的脱敏纪律不统一。

---

## 七、进度条缩略图：mpvRx vs 本项目（moumou）逐点对比

> 本项目（小牛Player/moumou）的进度条缩略图实现见 `docs/archive/ARCHITECTURE.md` §4.9：
> 自建 libmpv 内核（`mk_thumbnail_*`）+ FFmpeg/MediaCodec 独立解码实例。
> 该功能是本项目「抄 mpvRx + 自打补丁」的成果，下文逐点对齐两版实现，标注哪些是抄来的、哪些是自打补丁。

| 维度 | mpvRx 2.4.0 | 本项目（moumou） |
|---|---|---|
| 第二解码引擎 | `is.xyz.mpv.FastThumbnails`（mpv-android `mpvlib.aar` 内原生 FFmpeg） | 自建 libmpv.so 导出 `mk_thumbnail_grab/free/clear_cache`（fork azxcvn/libmpv-android-video-build + `mk_thumbnail.patch`） |
| **解码方式** | `useHwDec=false` **纯软解** | `useHwdec=true` **MediaCodec 硬解优先、失败自动软解** |
| 性能 | 软解（慢，但零抢硬解器） | 硬解 ~85ms/帧（快，但抢占播放内核的硬解器） |
| 并发模型 | 单 worker + **最多 3 在飞** + capacity-blocked 重排队 | 引擎级**单飞：最多 1 运行 + 1 待跑**，新请求顶掉待跑（`stale=true`） |
| 慢解码处理 | 2500ms 有界等待**但不取消**，完成后 late-publish 回填 | 运行中的解码不取消，但回调里 `_lastThumbBucketMs` 判过期直接丢弃 |
| 源解析 | `pinnedSeekThumbnailSource` + mpv 属性解析 + 伪协议跳过（支持网络/torrent/SAF） | 直接本地绝对路径（纯本地播放器） |
| 分桶 | 1 秒/桶 | 1 秒/桶 |
| 缓存 | 32MB LruCache，key=`source\|bucket\|maxSize` | 32MB LinkedHashMap LRU，key=`path\|bucketMs\|maxWidth` |
| 邻近帧 | ±2 桶（`findNearestSeekThumbnail`） | ±3s（`peekNearestFrame`，maxGapMs=3000） |
| 失败冷却 | 10s（失败表上限 128） | 10s（**`stale` 不计入冷却**，只记真实解码失败） |
| 预取 | 解码成功后立即 ±2 桶（非网络源） | 松手停 350ms 后 ±1/±2/±3s（6 帧串行） |
| 渲染 | Bitmap → Compose `ImageBitmap` | RGBA bytes → `ui.Image`（`ImageDescriptor.raw` 无编码往返）+ **上一帧无缝保持** |
| 精确落帧 | `usePreciseSeeking` 可选（`absolute+exact`），拖动预览恒用 keyframes | `hr-seek=absolute` **恒开**，松手帧级精确 |
| 拖动时是否 seek 播放器 | 否（画面停旧位置，只出预览气泡） | 否（同样不 seek，只出预览气泡） |

**「抄的」部分**（与 mpvRx 同源、本项目沿用）：独立于播放 core 的第二解码引擎、秒级分桶、32MB 内存 LRU、
邻近帧先显示再补精确帧、失败 10s 冷却、松手前不 seek 播放器、`hr-seek=absolute` 精确落帧——这套骨架原样对齐 mpvRx。

**「自打补丁」部分**（本项目与 mpvRx 的分歧，也是用户自己改的）：
1. **硬解优先**：mpvRx 缩略图统一 `useHwDec=false` 软解（避免抢播放内核硬解器）；本项目改成 MediaCodec 硬解优先 +
   软解兜底，换取 ~85ms/帧的低延迟——代价是可能与正在播放的硬解链路争抢硬解器（依赖 `mk_thumbnail_*` 内核里
   「硬解 ctx 全局复用」来缓解）。
2. **单飞调度 + stale 语义**：mpvRx 允许 3 个在飞解码 + capacity-blocked 重排队；本项目收紧为「1 运行 + 1 待跑」，
   并给被顶掉的请求打 `stale=true` 标记，把「被抢占」与「真实失败」区分开——被顶掉不计入失败冷却（mpvRx 无此区分，
   靠 `requestId` 判 stale + late-publish 收口）。
3. **RGBA 直渲 + 上一帧保持**：mpvRx 把 Bitmap 直接给 Compose；本项目在 Flutter 侧用 `ImageDescriptor.raw`
   免 PNG/JPEG 编码往返，且 `RawThumbImage` 解码新帧期间保留上一帧（拖动时预览不闪烁、不出现空白帧）。
4. **预取时机**：mpvRx 解码成功后立即预取 ±2 桶；本项目改为松手停 350ms 后才预取 ±3s——避免拖动中途浪费解码。

**可借鉴的差距**（本项目未来若支持网络源/在线视频时需要补）：
- mpvRx 的**「解码超时不取消 + late-publish」**对慢解码（尤其网络源 open 就超 2.5s 窗口）更稳健；本项目单飞 +
  过期丢弃对本地文件够用，但网络源场景需要补 late-publish 语义，否则慢流永远出不了预览。
- mpvRx 的**「源 pinning」**是为「缓存 key 不随 mpv 属性抖动而漂移」设计的；本项目本地路径天然稳定，但一旦接网络
  URL/代理 URL，同样需要 pin 一次解析结果。
- mpvRx 的 **content:// → `/proc/self/fd/`** 技巧，可让 SAF 授权源也出预览；本项目目前只有本地绝对路径。

---

## 八、建议的学习切入顺序

如果时间有限，按性价比排序读这几个文件：

1. `ui/player/PlaybackSession.kt` —— 整个项目的骨架，单例核心 + 事件循环 + 属性系统
2. `ui/player/MPVView.kt` 的 `initOptions` —— mpv 移动端调参模板（注释即文档）
3. `data/network/proxy/NetworkStreamingProxy.kt` —— 本地代理 + token 架构
4. `domain/torrent/TorrentStreamingEngine.kt` —— 边下边播调度算法
5. `ui/player/ThermalMonitor.kt` + `anime4k/Anime4KPlayback.kt` —— 热感知双层降级
6. `ui/player/controls/GestureHandler.kt` —— Compose 低级指针 API 实战
7. `preferences/MpvConfigOverride.kt` —— 配置所有权协商机制

这个项目特别适合当作“**注释驱动学习**”的材料：几乎所有非默认的技术决策（从 `vd-lavc-queue=no` 修复 HEVC 丢帧回归，到不用 `reconnect_at_eof` 的原因）都在注释里记录了完整推理过程，读起来像一份带完整代码的 ADR（架构决策记录）集合。