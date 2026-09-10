# 小喵Player 项目架构指南

> 本文件是项目的**唯一架构契约**。任何 AI / 开发者在本仓库添加新功能前，必须先读完本文件。
> 遵循本文件的约定，项目可以健康扩展到 PiliPlus / mpvRx 同量级规模；违反约定堆代码，项目会退化为屎山。
> **完成重大功能新增 / 优化或 Bug 修复后，必须同步更新本文档（至少 §2 目录结构），禁止文档与代码脱节。**
> **本文档不设「参考项目」一节**：外部参考项目（mpvRx/PiliPlus/Kazumi/小喵 等）不随仓库分发（已 gitignore），
> 参考来源只在正文行内注明（如「对齐 mpvRx」）；禁止在文末新增独立的「参考项目」清单。

---

## 1. 项目简介

Flutter 本地视频播放器（Android），核心能力：
- 扫描本地视频（MediaStore + 「允许管理所有文件」权限）
- **列表模式**：含直接视频的文件夹 → 文件夹详情页（纯视频列表）
- **树状模式**：逐级目录导航（mpvRx 风格），一级界面显示独立文件夹卡片，点入下钻，带面包屑
- 两种模式共用同一套卡片组件（视觉一致）
- 播放器：media_kit，横屏沉浸式全屏，播放进度持久化；**听视频**（共享 Player 只播音频，
  封面模糊背景 + 1:1 圆角封面 + 胶囊式底部倍速/列表面板 + 定时关闭 + 后台播放（前台服务保活）+ 时间刻随机播放）
- **字幕**（阶段1 第 3 点）：内嵌轨道 + 外挂字幕导入（Android≤11 系统选择器 / >11 自建选择器带排序与文件夹记忆）
  + 同名字幕自动加载（同目录按视频名前缀匹配，简体系统优先 sc、繁体优先 tc）；
  单选模型，延迟/样式/杂项/字体四类设置，样式支持预设 + RGBA 滑杆调色与 ASS 强制覆盖开关，内嵌样式字幕默认尊重自带样式；
  自定义字体走 libass 原生渲染 + 运行时选择字体目录批量导入（§4.10）
- **音频**：内嵌音轨切换 + 外部音轨导入/移除（外部音轨临时，退出播放后不保留）；
  音频声道（自动/安全自动/单声道/立体声/反向立体声）+ 音频处理（音量标准化/动态范围压缩），
  对齐 mpvRx 的 `audio-channels` 与 `af` 滤镜链；声道/处理为会话级状态（每次进播放器重置）；
  **不可播放音轨自动回退**（如 TrueHD 8 声道在 Android opensles 上放不出来 → 退回 AC-3 并提示，§4.32）
- **音频均衡器**：5 频段（60/230/910/3.6k/14k Hz，±15dB，1dB 步进）+ 低音增强（0-100）
  + 虚拟环绕（0-100），内置 6 个影视向预设（平直/对白增强/电影/低音震撼/高音清晰/柔和夜间，
  关键频段 ±6~8dB）；入口在播放器「更多 → 音频均衡器」（可加至顶栏槽位）；对齐小喵 player
  的 mpv `af` 命名滤镜（`@eq`/`@bass`/`@virt` lavfi 链）；设置全局持久化（`EqualizerSettings`，
  区别于声道/处理的会话级）
- **进度条缩略图**：自建 libmpv 内核（含 `mk_thumbnail_*` 快速抓帧接口）+ FFmpeg/MediaCodec
  硬解独立解码实例（~85ms/帧），拖动实时预览、松手精确落帧、空闲预取邻近帧（§4.9）
- 超分辨率：Anime4K v4 着色器链（7 档模式：关闭 + A/B/C/A+/B+/C+，× 质量档 流畅/均衡/高清），底栏固定入口
- 片头片尾自动跳过：全局开关，按秒跳过片头 / 按剩余时间跳过片尾，播放中「设为当前时间」，一键重置
- **弹幕（阶段1）**：canvas_danmaku 渲染 + 本地弹幕加载（同名 9 种命名规则自动加载
  + 「更多→弹幕→本地弹幕」文件选择器手动导入，选择器规则对齐字幕）+ 弹幕二级界面
  （本地/网络/自动匹配/设置四入口）+ 播放界面开关/设置按钮（横屏左下角时间右侧 /
  竖屏右下角进度条上方）（§4.11）
- **弹幕设置（阶段2）**：弹幕样式（字号/字重/速度/描边/不透明度无极滑杆 + 随机渐变色
  忽略文件颜色）+ 弹幕配置（显示区域 10% 固定档位/行高/顶·底·滚动三类显隐/海量弹幕/
  弹幕去重/屏蔽词）+ 弹幕偏移（时间轴偏移 -180~+180 秒，正 = 延后、负 = 提前，对齐 Kazumi）；
  设置全量持久化（`DanmakuSettings`），三入口（横屏底栏设置按钮/竖屏进度条上方设置
  按钮/更多→弹幕→弹幕设置）进入同一面板（§4.11）
- **网络弹幕 / 自动匹配（阶段3）**：接入弹弹Play 开放弹幕网络（签名验证模式）——
  网络弹幕三级界面搜索（搜索历史胶囊 + 一键清除 + 上限淘汰最旧）、自动匹配
  （文件前 16MB MD5 匹配）、切集自动匹配（缓存番剧集列表按集数自动加载）、
  弹幕服务器管理（默认弹弹Play 不可删 + 自建服务器增删启停，搜索合并展示）；
  密钥存 gitignored 私有文件（§4.11）
- 外观设置：23 种主题色 + 21 种调色板风格（flex_seed_scheme）+ 动态色（壁纸取色，Android 12+）
  + 自定义主题色（色相/SV/hex 手输选色，§4.7）
- **全局自定义字体**：App 全局字体（设置→外观→App字体设置：预览 + 开关 + 系统选择器导入单字体 +
  字号/字重滑杆，关闭跟随系统）；**弹幕自定义字体**（弹幕设置→弹幕字体：跟随系统/跟随 App/自定义三选一，
  自定义复用字体目录批量导入 + 列表选择），两者走 Flutter 引擎 `loadFontFromList` 注册（§4.12）
- **哔哩哔哩账号登录**（哔哩生态阶段一）：我的→登录，TV 扫码（刷新/保存相册/打开哔哩哔哩自动扫码）
  + Cookie 导入兜底；凭证加密存储（flutter_secure_storage）+ 登录态自检（nav）+ WBI 签名 + buvid 预取（§4.13）
- **系统播放器接入**：注册为系统视频播放器（其他 App「打开方式」/浏览器直链可选本项目，
  content:// 三级解析）；**播放历史**（速拨「最近播放」直启 + 我的→历史记录管理，
  只记本地与直链）；**打开链接**（速拨输入直链在线播放，章节随容器原生读取）（§4.17）
- **隐私政策**：首次启动隐私门禁弹窗（5 秒倒计时 + 勾选同意才可确认，取消退出应用）
  + 关于页「用户协议」组（预览用户服务协议与隐私政策正文）（§4.19）
- **应用更新**：我的→关于→更新组（手动检查更新 + 自动检查更新开关）；更新弹窗（Markdown
  渲染更新说明 + 立即更新/稍后提醒/忽略 + 主·备下载站子菜单）；更新源（GitHub API）与
  主·备下载链接已就绪，`checkForUpdate` 仍开发写死（未接入真实抓取，§4.20）
- **音量增强 (Volume Boost)**：系统音量满 100% 后继续上滑接管 mpv 音量放大（`volume-max=100+cap`），
  上限 10%~100% 十档、默认 60%（最高 200%）；指示器增强段红色显示 110%/150%/200%（§4.23）
- **杜比视界偏色检测与引导**：本地视频 OpenMedia 检测杜比视界编码（MediaInfo），未开 gpu-next
  时弹引导弹窗（可知/不再提示，`DolbyVisionSettings` 记忆）（§4.23）
- **设备硬件与编解码能力检测**：我的→其他→「设备信息」页，展示屏幕 HDR 能力、关键编码器
  硬/软解、系统解码器清单（筛选/搜索，点条目进详情页看完整能力）（§4.24）
- **解码配置修改后一键重启**：解码面板切换解码方式/预设后弹「需重启应用」，立即整应用重启
  或稍后重启（原生 `restartApp`，§4.24）
- **播放性能与诊断**：Anime4K 着色器**安装期**优化（显式 mediump/FP16 精度注入 + C.R.E.L.U.
  采样合并，运行期零成本，§4.25）+ mpv 移动端缓存/网络调参模板（本地/在线两档，§4.26）
  + **播放诊断页**（缓存/丢帧/渲染延迟/硬解/音画同步实时采样，§4.27）
- **网络可靠性**：统一重试（只重试连接类失败、指数退避、响应中断不重试防重复提交）
  + 超时分级（API 12s / 文本 15s / 下载 30s / 媒体流 30min）+ 文本响应体积上限快速失败（§4.28）
- **番剧播放列表**：在线播放番剧时整季剧集列表随播放页带入，「下一集」/自动连播/
  列表循环/播放列表面板全部可用（对齐 PiliPlus 的「播放页持有剧集列表」，§4.15）
- **并发原语与通用分页**：`AsyncSession`（会话号失效）/ `AsyncSingleFlight`（在飞去重）/
  `AsyncSerialQueue`（串行队列）+ `LoadingState` 三态 + `CommonListController` 分页
  控制器（刷新失败保留旧列表）；散落的手写实现已收敛（§4.29）
- **App 内文件管理**：文件夹与视频长按弹出文件动作菜单（复制 / 移动 / 重命名 / 删除），
  文件夹多一项**固定/取消固定**（固定 = 始终稳定前置在列表最前）；对齐 mpvRx 的动作集，
  去掉其分享/播放/压缩/加入播放列表等；目标目录复用 App 内目录选择器，同卷 `rename` 秒移、
  跨卷自动退化为「复制 + 删源」并显示进度与取消；删除文件夹默认只删其中的视频文件
  （勾「删除所有文件」才递归整个文件夹）（§4.30）

技术栈：Flutter 3.44+ / Dart 3.12+，依赖见 `pubspec.yaml`。

---

## 2. 目录结构（lib/）

> 文档约定（工作.md 第 1 点）：**每个 dart 文件必须带 `#` 一行简短描述**，
> 只说明「这个文件负责什么」，不展开实现细节；新增文件必须同步更新本树。

```
lib/
├── main.dart                  # 入口：主题装配 + AppFrame + 路由观察者 + 崩溃日志钩子
├── models/                    # 纯数据模型（无逻辑、无依赖）
│   ├── tree_node.dart         # 目录树节点（folder/video）
│   ├── video_file.dart        # 视频文件信息 + 来源枚举（本地 / 网络连接）
│   ├── player_action.dart     # 播放器按钮动作 / 双击手势模式 / 视频方向模式
│   ├── player_loop.dart       # 循环播放模式枚举（off/列表循环/单集循环）
│   ├── playlist_sort.dart     # 播放列表排序 + 目录过滤纯函数
│   ├── chapter_info.dart      # 章节模型（ChapterInfo/SkipSegment/跳过类型枚举）
│   ├── playback_history_entry.dart # 播放历史条目模型（路径/标题/是否直链/时间/时长，toJson 容错）
│   ├── audio_track.dart       # 音轨模型 + 声道枚举（auto/auto-safe/mono/stereo/反向立体声）+ 格式过滤/af 滤镜链纯函数
│   ├── subtitle_track.dart    # 字幕轨道模型 + 展示名/格式过滤/对齐/颜色/RGBA 转换/字体过滤纯函数
│   ├── super_resolution_mode.dart  # 超分模式/质量枚举 + 着色器链构建纯函数
│   ├── equalizer_preset.dart  # 音频均衡器预设模型（14 预设 + 频段标签 + 反查/相等纯函数）
│   ├── danmaku_entry.dart     # 弹幕条目纯数据模型（时间/模式/颜色/文本 + 合并计数 + 会员彩色标记）
│   ├── danmaku_server.dart    # 弹幕服务器配置模型（默认弹弹Play + 自建服务器，toJson/fromJson）
│   ├── dandan_models.dart     # 弹弹Play API 数据模型（番剧/集/评论/匹配候选，fromJson 容错）
│   ├── network_connection.dart # 网络存储账户模型 + 协议枚举（WebDAV/SMB/FTP）+ 校验纯函数
│   ├── network_file.dart      # 远程目录/文件条目模型（供网络浏览 UI 展示）
│   ├── danmaku_auto_match_cache.dart # 弹幕自动匹配缓存模型（番剧 + 集列表，供切集自动匹配）
│   ├── danmaku_font_mode.dart # 弹幕字体三态枚举（跟随系统/跟随App/自定义）+ 解析纯函数
│   ├── cast_device.dart       # 投屏目标设备模型（DLNA MediaRenderer：id/设备名/设备类型，§4.18）
│   ├── bilibili_user.dart      # 哔哩哔哩用户信息模型（nav 接口，mid/昵称/头像/等级/经验/大会员状态/硬币）
│   ├── bili_bangumi.dart       # 哔哩番剧（PGC）模型：索引筛选/条目、搜索、季详情/选集/多季、时间表（fromJson 容错）
│   ├── bili_dash.dart          # playurl DASH 模型：流条目/清晰度档/OP-ED clip（baseUrl/baseUrls 双格式兼容，§4.15）
│   ├── bili_media.dart         # 在线播放值对象：DASH 流 + 弹幕/章节元数据 + 画质切换回调（§4.15）
│   ├── update_info.dart        # 更新信息值对象（新版本号/Markdown 更新说明/主·备下载站链接，§4.20）
│   ├── device_decoder.dart     # 设备解码器条目模型（名称/MIME/分辨率/声道/特性/色彩格式/采样率/profile，设备能力检测页 + 详情页）
│   ├── wyzie_models.dart       # Wyzie 字幕 API 数据模型（字幕条目/来源响应/密钥信息/TMDB 命中 + 语言/格式/编码/来源常量表，§4.21）
│   ├── player_diagnostics.dart # 播放诊断快照模型（mpv 属性 → 容错解析的运行时统计，§4.27）
│   └── subtitle_font_injection.dart # 字幕字体注入判定纯函数（`resolveSubtitleFontInjection` 永不返回 null：用户字体目录或 /system/fonts，§4.10/§4.32）
│   └── bili_playlist.dart      # 番剧播放列表模型（整季剧集 + 按 epId 定位当前集，§4.15）
├── services/                  # 业务逻辑 / 数据层（无 UI）
│   ├── view_settings.dart     # 排序/字段/视图模式设置（ChangeNotifier + 持久化）
│   ├── common_list_controller.dart # 通用分页列表控制器（三态 + 刷新失败保留旧数据 + 加载更多，§4.29）
│   ├── video_scanner.dart     # 扫描 + 建树 + 建文件夹列表
│   ├── video_info_service.dart# 列表封面缩略图（磁盘缓存）+ 基本元数据 + 完整媒体信息
│   ├── playback_progress_service.dart  # 播放进度（ChangeNotifier + 持久化 + 串行写盘）
│   ├── playback_history_service.dart # 播放历史（记录/去重置顶/上限淘汰/删除/清空/开关，ChangeNotifier + 持久化，§4.17）
│   ├── player_controls_settings.dart   # 播放器控制设置（槽位/手势/倍速/比例/长按/方向/顶部信息等）
│   ├── device_services.dart   # 设备能力：音量/亮度/画中画/电量/网络类型/后台服务启停/字幕·字体文件与目录操作（MethodChannel）+ 任意时刻抓帧（FFmpeg 引擎 + 秒桶内存 LRU）+ 设备能力检测 + 整应用重启 + 动态色壁纸取色
│   ├── dolby_vision_settings.dart # 杜比视界偏色提示「不再提示」记忆（ChangeNotifier + 持久化，§4.23）
│   ├── fast_thumbnails.dart   # FFmpeg 快速缩略图引擎（FFI 直连自建 libmpv.so 的 mk_thumbnail_*，单飞+顶旧调度）
│   ├── crash_log_service.dart # 崩溃日志：列表/读取/删除/清空/导出
│   ├── cache_manager_service.dart # 缓存管理：列表封面磁盘缓存查询/清除（进度条缩略图为纯内存，不占磁盘）
│   ├── super_resolution_service.dart   # 超分：模式持久化、着色器**安装期优化**后拷贝、mpv 应用（§4.25）
│   ├── chapter_tracker.dart   # 章节跟踪器（mpv chapter-list 读取 + 当前位置/片段/胶囊窗口状态 + 章节跳段自动跳过）
│   ├── chapter_skip_settings.dart # 章节跳段设置（六类片段自动跳过 + 自定义片头/片尾关键词，ChangeNotifier + 持久化）
│   ├── intro_outro_settings.dart # 片头片尾全局设置（开关/片头秒数/片尾秒数/各自范围，ChangeNotifier + 持久化）
│   ├── intro_outro_tracker.dart  # 片头片尾跟踪器（就绪/已处理状态 + 恢复点感知 + 动作决策）
│   ├── media_scan_settings.dart  # 媒体扫描与过滤设置（.nomedia/隐藏文件夹/黑白名单，ChangeNotifier + 持久化）
│   ├── pinned_folders_settings.dart # 固定文件夹设置（绝对路径集合/固定与取消/批量替换/失效清理，ChangeNotifier + 持久化，§4.30）
│   ├── file_operations_service.dart # 文件管理服务（复制/移动/重命名/删除 + 进度与协作式取消，dart:io 真实路径，§4.30）
│   ├── file_selection_controller.dart # 页面级多选状态（进入/退出/切换/全选/剔除失效项，**非单例**，§4.31）
│   ├── audio_service.dart     # 音频控制器（音轨列表/aid 单选/外部音轨导入·移除（临时）/声道/af 滤镜链应用；声道与处理为会话级，随播放器生命周期重置；不可播放音轨经 stream.log 判定后自动回退，§4.32）
│   ├── subtitle_settings.dart # 字幕设置（延迟/大小/位置/颜色/描边模式/内嵌样式覆盖/自定义字体/外挂字幕记忆/重置样式，ChangeNotifier + 持久化）
│   ├── subtitle_service.dart  # 字幕控制器（单选模型：track-list/sid 同步/sub-add/sub-remove + 同名字幕自动加载 + 设置应用（字体目录构造期注入，运行期只写 sub-font）+ 切集重应用 + 外挂字幕跨会话恢复，§4.32）
│   ├── app_font_settings.dart # App 全局字体设置（开关/族名/字号/字重 + loadFontFromList 注册，ChangeNotifier + 持久化，§4.12）
│   ├── equalizer_settings.dart # 音频均衡器设置（5 频段/低音增强/虚拟环绕/预设，ChangeNotifier + 持久化，AudioController 订阅重应用 af 链）
│   ├── danmaku_service.dart    # 弹幕控制器（业务层：本地同名/手动导入/网络弹幕装载 + 1s tick 秒桶发射 + canvas 渲染层显隐/暂停/倍速同步 + 设置订阅应用 + 切集自动匹配，横竖屏共享）
│   ├── danmaku_scheduler.dart  # 弹幕调度器（纯逻辑：秒桶 + 前向补发 + seek 跳变检测 + 代数失效）
│   ├── danmaku_memory.dart     # 弹幕手动导入记忆（视频路径→弹幕文件路径，SharedPreferences JSON 持久化）
│   ├── danmaku_settings.dart   # 弹幕设置（样式：字号/字重/速度/描边/不透明度/随机色 + 配置：区域(10%档位)/行高/三类显隐/海量/去重/屏蔽词 + 偏移：时间轴偏移 + 字体：三态/自定义族名·文件名，ChangeNotifier + 持久化）
│   ├── dandan_play_keys.dart   # 弹弹Play API 密钥（私有，gitignored，禁止上传 GitHub）
│   ├── dandan_play_api.dart    # 弹弹Play 开放弹幕网络 API 客户端（签名验证模式：搜索/拉取弹幕/文件匹配）
│   ├── danmaku_server_settings.dart # 弹幕服务器设置（默认+自建服务器增删启停 + 切集自动匹配开关及其与默认服务器的互斥裁决，ChangeNotifier + 持久化）
│   ├── danmaku_search_history.dart  # 网络弹幕搜索历史（关键词去重/上限淘汰最旧/一键清除，持久化）
│   ├── danmaku_auto_match_cache_store.dart # 弹幕自动匹配缓存存储（番剧+集列表，切集自动匹配用）
│   ├── danmaku_network_service.dart # 弹幕网络服务（搜索合并/文件匹配/下载落盘 filesDir/danmaku/network + 文件前16MB MD5，无 UI）
│   ├── privacy_policy_settings.dart # 隐私政策同意状态（首次启动门禁，ChangeNotifier + 持久化，§4.19）
│   ├── privacy_policy_content.dart # 用户隐私政策与用户服务协议正文（纯常量文本，唯一文案来源，§4.19）
│   ├── network/                    # 网络存储（WebDAV/SMB/FTP）抽象层
│   │   ├── network_client.dart     #   NetworkClient 抽象接口（connect/listFiles/getFileSize/openStream/disconnect）
│   │   ├── network_client_factory.dart # 按协议创建客户端（连接配置 → 具体客户端实例）
│   │   ├── network_connection_settings.dart # 账户增删改查 + 密码加密 + SharedPreferences 持久化（ChangeNotifier）
│   │   ├── network_repository.dart #   高层 API（浏览目录/解析播放流，统一异常）
│   │   ├── network_streaming_proxy.dart # 本地回环流代理（dart:io HttpServer，Range/HEAD，供 mpv 拉流播放 + 最近 1 秒滑动窗口网速统计）
│   │   ├── webdav_client.dart      #   WebDAV 客户端（纯 Dart http：PROPFIND Depth:1 列表 / Range 流式读取 + 自检）
│   │   ├── ftp_client.dart         #   FTP 客户端（纯 Dart Socket 双连接被动模式 / MLSD→LIST 回退 / REST 偏移）
│   │   └── smb_client.dart         #   SMB 客户端（纯 Dart smb_connect：4 路并发预读管线 + 管理共享过滤）
│   ├── bilibili/                  # 哔哩哔哩协议域（§4.13）
│   │   ├── bili_constants.dart    #   域名 / UA / Referer / TV appkey·appsec / 扫码状态码
│   │   ├── bili_api.dart          #   端点常量（集中式，对齐 PiliPlus api.dart）
│   │   ├── bili_credential_store.dart # 凭证加密存储（SESSDATA/bili_jct/DedeUserID + Cookie 解析纯函数）
│   │   ├── bili_http.dart         #   统一请求：Cookie/UA/Referer/指纹注入 + 错误语义化
│   │   ├── bili_auth_service.dart #   扫码生成/轮询/Cookie导入/nav自检/buvid预取/退出登录
│   │   ├── bili_account.dart      #   登录态/用户信息/WBI密钥/buvid（ChangeNotifier 单例）
│   │   ├── bili_fingerprint.dart  #   反爬指纹：uuid/b_lsid/buvid_fp/bili_ticket + ExClimbWuzhi 激活（§4.13）
│   │   ├── bili_bangumi_service.dart # 番剧索引条件/分页/搜索(WBI)/季详情/时间表（§4.14）
│   │   ├── bili_video_service.dart   # PGC/UGC playurl（DASH选流+清晰度+WBI签名，§4.15）
│   │   ├── bili_danmaku_service.dart # B站原声弹幕（seg.so protobuf 解码 + XML 缓存，§4.15）
│   │   ├── bili_stream_proxy.dart    # 本地 HTTP 代理（绕过 libmpv mbedTLS + 滑动窗口网速统计，§4.15）
│   │   ├── bili_download_service.dart # 下载解析：链接 → 可下载条目（番剧多集 / UGC BV·av·合集，§4.16）
│   │   └── pb/
│   │       └── pb_reader.dart        # 手写 protobuf wire 解码器（varint+length-delimited，§4.15）
│   ├── download/                 # 下载域（哔哩生态阶段四，B站是首个用户，§4.16）
│   │   ├── download_settings.dart # 下载目录设置（ChangeNotifier + 持久化）
│   │   ├── download_task.dart     # 下载任务状态机 + Range 流式下载 + 合并
│   │   └── download_manager.dart  # 任务队列 + 并发槽调度 + 跨重启持久化（ChangeNotifier）
│   ├── cast/                    # 投屏域（DLNA/UPnP，P0 仅本地文件推流，§4.18）
│   │   ├── cast_service.dart    #   投屏服务（SSDP 发现渲染器 + 源分流 + SetAVTransportURI/Play 推流）
│   │   └── lan_media_server.dart #  局域网媒体服务器（本地文件 → http://LAN:port/token，Range/CORS）
│   ├── update/                  # 更新域（工作.md：更新功能，§4.20）
│   │   ├── update_settings.dart #   更新设置（自动检查开关 + 忽略版本，ChangeNotifier + 持久化）
│   │   └── update_service.dart  #   更新服务（更新源/下载链接常量 + 检查更新，开发阶段写死新版本）
│   ├── wyzie/                   # 影视字幕下载域（Wyzie 字幕源，§4.21）
│   │   ├── wyzie_settings.dart  #   字幕下载设置（API 密钥/来源/语言/格式/编码，ChangeNotifier + 持久化）
│   │   └── wyzie_api.dart       #   Wyzie 字幕 API 客户端（来源/关键词搜索/文件下载，UTF-8 解码 + 错误语义化）
│   └── ...                    #   ⚠️ 不要在这里加全局 ValueNotifier hack（见 §4.1）
├── widgets/                   # 可复用 UI 组件（跨页面）
│   ├── app_frame.dart         #   ★ 全局框架：安全区 + 播放页全屏检测
│   ├── app_dialog.dart        #   showAppDialog（统一弹窗动画）
│   ├── player_panel.dart      #   ★ 右侧滑入面板壳 + showPlayerPanel（横屏二级界面外壳）
│   ├── player_bottom_panel.dart # ★ 竖屏底部弹出面板壳 + showPlayerBottomPanel
│   ├── player_option_chip.dart#   面板选项胶囊（倍速/超分共用）
│   ├── options_sheet.dart     #   统一排序弹窗（字段胶囊选择）
│   ├── folder_card.dart       #   文件夹卡片（列表/树状共用，含多选勾选态）
│   ├── video_card.dart        #   视频卡片（列表/树状/详情共用，含多选勾选态）
│   ├── settings_ui.dart       #   设置页公共组件（分组/卡片/设置项/滑杆主题 + 播放器暗色面板强调色派生 playerPanelAccent/playerPanelSliderTheme）
│   ├── raw_thumb_image.dart   #   RGBA 帧直渲组件（FastThumbFrame → ui.Image，帧切换保持上一帧无缝）
│   ├── capsule_nav_bar.dart   #   悬浮胶囊导航
│   ├── main_scaffold.dart     #   主壳（PageView + 悬浮胶囊）
│   ├── speed_dial_fab.dart    #   首页右下角悬浮快速拨号（最近播放/打开链接/哔哩番剧/网络存储）
│   ├── bili_cover_card.dart   #   番剧封面卡片（竖版封面 + 右上角标 + 左下角灰标 + 标题/副标题，索引/推荐/时间表共用）
│   ├── bili_episode_tile.dart #   番剧单集磁贴（集号 + 集名 + 胶囊角标，内联选集/全屏选集页共用）
│   ├── directory_picker_dialog.dart # 目录选择器弹窗（复用 listDirectory，返回真实路径）
│   ├── cast_device_dialog.dart # 投屏设备选择弹窗（SSDP 发现列表 + 点选推流，§4.18）
│   ├── privacy_policy_dialog.dart # 首次启动隐私门禁弹窗（5 秒倒计时 + 勾选同意 + 取消退出，§4.19）
│   ├── update_dialog.dart       # 更新弹窗（Markdown 更新内容 + 立即更新/稍后提醒/忽略 + 主·备下载站子菜单，§4.20）
│   ├── file_operations_ui.dart  # 文件管理 UI（长按动作菜单含「多选」/重命名弹窗/删除确认含整目录勾选/传输进度弹窗，§4.30）
│   ├── folder_actions.dart      # 文件管理动作编排（单选 showFileManagementFlow + 多选 showBatchFileManagementFlow，四页面共用，§4.30/§4.31）
│   ├── file_selection_ui.dart   # 多选顶部上下文工具栏 + 卡片勾选圆点（§4.31）
│   └── marquee_text.dart      #   无缝循环跑马灯
├── pages/                     # 页面（每页一个目录）
│   ├── bilibili/
│   │   ├── bili_login_page.dart # 哔哩哔哩登录页（TV 扫码登录 + Cookie 导入，§4.13）
│   │   ├── bili_user_page.dart  # 哔哩哔哩账号信息页（头像/等级/经验/硬币/会员 + 退出登录）
│   │   ├── bili_index_page.dart # 番剧首页（右上角搜索/链接解析 + 追番时间表 + 推荐网格，§4.14）
│   │   ├── bili_bangumi_index_page.dart # 番剧索引页（多行筛选胶囊 + 封面网格 + 分页 + 折叠/展开动画，§4.14）
│   │   ├── bili_season_page.dart # 番剧详情页（封面+信息+简介+多季切换+内联选集+查看全部，§4.14）
│   │   ├── bili_episode_picker_page.dart # 全屏选集页（30集分段 + 2列网格 + 正倒序，§4.14）
│   │   ├── bili_play_launcher.dart # 播放启动器（playurl → BiliMedia → PlayerPage，§4.15）
│   │   ├── bili_search_page.dart # 番剧搜索页（media_bangumi 搜索 + 分页，§4.14）
│   │   ├── bili_danmaku_download_page.dart # 弹幕下载页（链接解析 + 集数勾选，§4.16）
│   │   └── bili_video_download_page.dart # 视频下载页（清晰度选择 + 分P勾选，§4.16）
│   ├── download/
│   │   └── download_manager_page.dart # 下载管理页（任务列表 + 暂停/恢复/重试/删除，§4.16）
│   ├── home/
│   │   ├── home_page.dart     #   首页（权限门禁 + 视图分发 + 搜索入口 + 速拨：最近播放/打开链接）
│   │   ├── open_link_dialog.dart # 「打开链接」弹窗（输入直链 → 规范化校验 → 播放，§4.17）
│   │   ├── views/             #   首页专属视图组件
│   │   │   ├── folder_list_view.dart  # 列表视图
│   │   │   └── tree_list_view.dart    # 树状一级视图
│   │   ├── folder_detail_page.dart    # 列表模式详情页（纯视频）
│   │   └── tree_folder_page.dart      # 树状目录页（混合内容 + 面包屑）
│   ├── player/
│   │   ├── player_page.dart   #   播放页（横屏沉浸式；手势/恢复进度/切集/EOF/画中画/面板）
│   │   ├── player_metrics.dart #  人体工学对齐常量 kPlayerLeftInset（横竖屏共用）
│   │   ├── player_portrait_page.dart # 竖屏播放页（共享横屏 Player/VideoController，切换零中断）
│   │   ├── audio_player_page.dart    # 听视频页（共享 Player 只播音频；封面模糊背景；1:1 圆角封面；后台播放；循环三态）
│   │   └── views/             #   播放页专属控制组件
│   │       ├── player_top_bar.dart        # 顶栏：返回 + 标题 + 5 槽位 + 更多
│   │       ├── player_status_bar.dart     # 顶部信息行：时间/电量居中 + 网速胶囊/数据类型靠右（多选控制；网速=滑动窗口真实下行速率，在线常驻）
│   │       ├── player_center_cluster.dart # 中央簇：快退/播放暂停/快进
│   │       ├── player_danmaku_layer.dart  # 弹幕渲染层（canvas_danmaku DanmakuScreen 封装，视频层与手势层之间，挂载/卸载即 rebind）
│   │       ├── player_danmaku_buttons.dart# 弹幕开关/设置按钮组（Kazumi 图标：开=内联 SVG 主题色对勾，关/设置=资源 SVG）
│   │       ├── player_danmaku_panel.dart  # 弹幕二级界面（本地弹幕=复用字幕选择器面板导入 / 网络弹幕 / 自动匹配 / 弹幕设置；DanmakuFileService）
│   │       ├── player_danmaku_network_panel.dart # 网络弹幕搜索三级界面（40dp 胶囊搜索框 + 框下关键词历史胶囊 + 命中后折叠为关键词条 + 结果卡自持动画展开集列表，横竖屏共用）
│   │       ├── player_danmaku_settings_panel.dart # 弹幕设置面板（样式：字号/字重/速度/描边/不透明度滑杆+随机渐变色；配置：区域(10%档位)/行高/三类显隐/海量/去重/屏蔽词；偏移：时间轴偏移；字体：跟随系统/跟随App/自定义三选一+目录导入列表选择；横竖屏外壳共用）
│   │       ├── player_bili_playlist_panel.dart   # B 站番剧剧集列表面板（集号/集名/角标 + 当前集高亮，§4.15）
│   │       ├── player_bottom_bar.dart     # 底栏：进度条 + 下一集 + 时间 + 弹幕开关/设置 + 右下角按钮簇
│   │       ├── player_seek_bar.dart       # 自绘进度条（替代 Slider，起点对齐 kPlayerLeftInset；章节圆点 + 跳过色段）
│   │       ├── player_chapter_bar.dart    # 章节名行（可点击呼出列表）+ 跳过胶囊（5 秒自动消失/控制层可见时常驻）
│   │       ├── player_chapter_panel.dart  # 章节列表面板（顶部固定「章节跳段」入口 + 竖向滚动实时高亮 + 点击跳转）
│   │       ├── player_chapter_skip_panel.dart # 章节跳段设置面板（六类自动跳过开关 + 自定义片头/片尾关键词）
│   │       ├── player_intro_outro_panel.dart # 片头片尾设置面板内容（开关/滑杆/分秒换算/设为当前时间/一键重置）
│   │       ├── player_loop_panel.dart     # 循环播放面板内容（横竖屏共用）
│   │       ├── player_right_actions.dart  # 右侧竖排：截图 + 锁定
│   │       ├── player_fit_panel.dart      # 画面比例面板内容
│   │       ├── player_speed_panel.dart    # 倍速面板内容（预设/精确调速/临时应用）
│   │       ├── player_super_resolution_panel.dart  # 超分面板内容
│   │       ├── player_decode_panel.dart          # 解码面板（解码方式 2×2 胶囊 + 解码预设；改档后弹「需重启应用」确认，立即整应用重启/稍后，§4.24）
│   │       ├── player_diagnostics_panel.dart     # 播放诊断面板（每秒采样 mpv 属性：播放/视频/音频/缓存与丢帧四组 + 顶部健康告警，§4.27）
│   │       ├── player_play_pause_button.dart  # 播放/暂停图标形变动画
│   │       ├── player_gesture_layer.dart      # ★ 手势层（裸识别器方案，见 §4.8）
│   │       ├── player_gesture_indicator.dart  # 音量/亮度手势指示器
│   │       ├── player_speed_indicator.dart    # 长按倍速指示器（胶囊样式）
│   │       ├── player_playlist_panel.dart     # 播放列表面板内容
│   │       ├── audio_player_panels.dart       # 听视频倍速/列表面板（胶囊式 + 定时关闭预设 + 统一关闭按钮）
│   │       ├── audio_panel.dart               # 音频面板（音轨单选+外部音轨导入·移除+音频声道胶囊+音频处理开关）
│   │       ├── equalizer_panel.dart           # 音频均衡器面板（开关+预设胶囊+5 段竖向滑块+低音增强/虚拟环绕+一键重置）
│   │       ├── subtitle_panel.dart            # 字幕面板（轨道单选+外挂导入+移除；延迟输入合一/样式卡片化/杂项缩放位置/自定义字体目录导入+列表选择）
│   │       ├── subtitle_file_picker.dart      # 外挂字幕选择（≤11 系统选择器 / >11 自建选择器+文件夹记忆+文件过滤器+死路径向上回退；音频/弹幕选择器复用同一面板）
│   │       ├── player_resume_indicator.dart   # 恢复进度指示器（胶囊样式，2.5s 自动隐藏）
│   │       ├── player_swipe_seek_overlay.dart # 水平滑动 seek 预览浮层
│   │       ├── player_thumbnail_preview.dart  # 进度条拖动缩略图预览气泡（RGBA 直渲 + 淡入淡出）
│   │       ├── portrait_player_top_bar.dart   # 竖屏顶栏（两行：返回+标题 / 5 槽位+更多横向均分，与横屏一致支持 5 槽位）
│   │       ├── portrait_player_bottom_bar.dart # 竖屏底栏（章节名+弹幕开关/设置行 → 进度条 → 操作行：超分→列表→倍速→选择屏幕）
│   │       └── portrait_edit_panel.dart       # 竖屏「编辑控制栏」页
│   ├── media_info/
│   │   └── media_info_page.dart # 媒体信息页（MediaInfoLib 解析 + 一键复制）
│   ├── network/
│   │   ├── network_storage_page.dart  # 网络存储账户列表（增删改入口 + 空态提示）
│   │   ├── account_edit_page.dart     # 账户新增/编辑（协议切换 + 各协议字段表单）
│   │   └── network_browser_page.dart  # 网络目录/文件浏览（复用 FolderCard/VideoCard + 面包屑回退 + 系统返回键逐级返回）
│   ├── settings/
│       ├── settings_page.dart #   设置主页（分组结构）
│       ├── appearance_page.dart      # 外观设置子页（模式/主题色网格+动态色+自定义选色/调色板胶囊化）
│       ├── playback_history_page.dart # 历史记录页（VideoCard 仅进度字段 + 右侧垃圾桶删除 + 清空二次确认 + 记录开关，§4.17）
│       ├── font_page.dart            # App字体设置页（预览 + 开关 + 导入字体 + 字号/字重滑杆）
│       ├── player_settings_page.dart # 播放器设置子页（手势/视频方向/顶部信息/播放行为/阈值）
│       ├── media_scan_settings_page.dart # 媒体扫描与过滤设置子页（.nomedia/隐藏文件夹/黑白名单）
│       ├── danmaku_server_page.dart # 弹幕服务器设置子页（默认+自建服务器增删启停 + 切集自动匹配开关，互斥时变灰+原因文案+点击 toast）
│       ├── about_page.dart           # 关于页（软件信息/工具/信息/用户协议）
│       ├── license_page.dart         # 许可证书页（列表 + 二级详情页，非折叠式）
│       ├── privacy_policy_page.dart  # 用户协议页（预览用户服务协议与隐私政策正文，可选中复制，§4.19）
│       ├── device_info_page.dart     # 设备硬件与编解码能力检测页（屏幕 HDR/关键编码器/解码器清单 + 筛选搜索，§4.24）
│       ├── decoder_detail_page.dart  # 解码器详情页（点解码器清单项进入，展示完整能力信息，§4.24）
│       ├── error_log_page.dart       # 错误日志页
│       └── cache_management_page.dart# 缓存管理页
│   └── subtitle/
│       ├── subtitle_download_page.dart # 影视字幕下载页（字幕设置入口 + 关键词搜索 + 勾选批量下载，§4.21）
│       ├── subtitle_settings_page.dart # 字幕设置子页（承载五入口，§4.21）
│       └── views/
│           └── subtitle_settings_section.dart # 字幕设置区（API 密钥/来源/语言/格式/编码五入口 + 来源动态拉取）
├── theme/                     # 主题
│   ├── app_theme.dart         #   ThemeData 生成（light/dark/amoled）
│   └── theme_controller.dart  #   主题控制（模式/色/风格/自定义色/动态色标记 + 迁移）
└── utils/                     # 纯工具函数
    ├── app_dialog.dart        #   （见 widgets/app_dialog.dart 说明）
    ├── anime4k_patch.dart     #   Anime4K 着色器安装期优化纯函数（精度注入 + C.R.E.L.U. 采样合并，§4.25）
    ├── formatters.dart        #   大小/日期/时长/倍速/网速格式化 + 截图文件名 + 在线媒体判定
    ├── url_media.dart         #   在线直链纯函数（规范化补协议/流媒体协议白名单/URL 提取标题，§4.17）
    ├── natural_compare.dart   #   自然序（数字感知）比较
    ├── folder_pin.dart        #   固定文件夹排序纯函数（稳定前置 + 逐层递归，§4.30）
    ├── file_ops.dart          #   文件管理纯函数（路径细分/目标校验/重命名校验/重名避让/失效固定路径，§4.30）
    ├── file_selection.dart    #   多选纯函数（目录树/视频索引 + 按点选顺序取值，§4.31）
    ├── watch_state.dart       #   观看状态纯函数（未观看/观看中/已看完）
    ├── playback_completion.dart # EOF 动作解析纯函数（优先级链）
    ├── playback_restore.dart  #   恢复进度：openAndRestore（暂停加载→静音激活时间线→seek→确认）
    ├── pip_aspect.dart        #   画中画宽高比纯函数
    ├── player_gestures.dart   #   双击判定 + 滑动手势数学
    ├── player_diagnostics.dart #  播放诊断纯函数（属性清单 + 数值格式化 + 健康提示，§4.27）
    ├── retry_policy.dart      #   统一网络重试/超时分级/体积上限快速失败（§4.28）
    ├── async_session.dart     #   可替换异步任务的会话号令牌（§4.29 C1）
    ├── async_single_flight.dart # 在飞去重（同 key 共享 Future，失败不缓存，§4.29 C1）
    ├── async_serial_queue.dart #  串行异步队列（按序执行、异常不打断队列，§4.29 C1）
    ├── loading_state.dart     #   异步数据三态 sealed（Loading/Loaded/LoadError）+ PageResult（§4.29 C2）
    ├── chapter_utils.dart     #   章节纯函数（标题分类/片段派生/当前章节/跳过目标）
    ├── intro_outro_skip.dart  #   片头片尾动作决策纯函数（跳过片头/切下一集/无动作）
    ├── mpv_tuning.dart        #   mpv 移动端缓存/网络调参模板（本地/在线两档 + lavf-o 合并，§4.26）
    ├── audio_shuffle.dart     #   听视频随机播放算法（结合当前时间刻，纯函数）
    ├── subtitle_auto_match.dart # 同名字幕自动匹配纯函数（扩展名优先级 + 同名优先 + 简/繁语言后缀，对齐小喵）
    ├── subtitle_sort.dart     #   自建字幕选择器排序纯函数（目录恒在前）
    ├── danmaku_timeline.dart  #   弹幕时间轴纯函数（同秒多条 1 秒内错峰延迟 + 时间轴偏移）
    ├── danmaku_local_file.dart #  同名弹幕文件查找纯函数（9 种命名规则，只查同目录）
    ├── danmaku_random_color.dart # 随机渐变色纯函数（HSV 色轮黄金角步进推进器，忽略文件颜色）
    ├── danmaku_dedup.dart     #   弹幕去重纯函数（文本归一化判同 + 时间窗合并）
    ├── danmaku_merge.dart     #   弹幕合并纯函数（跨时间窗同内容聚合 + 计数，一次线性扫描，§4.11）
    ├── danmaku_blocklist.dart #  弹幕屏蔽词纯函数（子串命中过滤，忽略大小写/空白）
    ├── danmaku_episode.dart   #   弹幕集数提取/匹配纯函数（文件名→集数 + 缓存集列表定位，切集自动匹配）
    ├── dandan_signature.dart  #   弹弹Play 签名纯函数（base64(sha256(AppId+Timestamp+Path+AppSecret))）
    ├── dandan_comment.dart    #   弹弹Play 评论→弹幕条目/B站 XML 纯函数（p 字段解析 + 排序 + 落盘 XML 生成）
    ├── danmaku_xml.dart       #   B站 XML 弹幕解析/生成纯函数（解析供 compute 后台执行 + 实体反转义 + 文本转义）
    ├── webdav_xml.dart        #   WebDAV PROPFIND 多状态 XML 解析（命名空间剥离 + 百分号/UTF-8 解码 + HTTP 日期）
    ├── ftp_parser.dart        #   FTP 目录列表解析（RFC3659 MLSD + Unix LIST 回退）
    ├── http_byte_range.dart   #   HTTP Range 头解析（bytes=start-end / start- / -suffix）
    ├── network_path.dart      #   网络路径规范化/校验/子路径拼接
    ├── bili_wbi.dart          #   WBI 签名纯函数（getMixinKey/encWbi，混淆表 64 项）
    ├── bili_app_sign.dart     #   TV 端 appSign 纯函数（appkey/appsec MD5 签名）
    ├── bili_fingerprint_utils.dart # 反爬指纹纯函数（murmur3×64_128/uuid/b_lsid/bili_ticket hexsign/dm_img）
    ├── bili_bangumi_url.dart  #   番剧/视频链接解析纯函数（提取 ss/ep/BV/av 令牌 + 合集列表链接）
    ├── bili_short_link.dart   #   b23.tv 分享短链提取+展开（任意分享文本提取，302 命中令牌即停）
    ├── cast_source.dart       #   投屏源分类纯函数（本地/直链/loopback/content + file:// 去前缀，§4.18）
    ├── version_compare.dart   #   版本号比较纯函数（忽略 v 前缀/按 . 逐段整数比较，§4.20）
    ├── network_mime_types.dart # 文件名→MIME 类型映射
    ├── wyzie_query.dart        #   Wyzie 字幕查询纯函数（来源/逗号参数拼接 + 客户端语言过滤）
    └── wyzie_filename.dart     #   Wyzie 字幕落盘文件名纯函数（非法字符清洗 + 同批消重）
```

---

## 3. 分层职责（依赖方向：只允许上层依赖下层，禁止反向）

```
pages（页面）      → 组装 widgets / 调用 services
widgets（组件）    → 只依赖 models / services / theme / utils（不依赖 pages）
services（服务）   → 只依赖 models / utils（不依赖 UI）
models（模型）     → 无依赖（纯数据）
```

**规则**：
- `widgets/` 里的公共组件**禁止 import `pages/`**（否则页面组件耦合）
- 页面专属的小组件放 `pages/<页面>/` 下（如 `views/`），不要塞进 `widgets/`
- 单文件超过 ~400 行必须拆分（参考首页拆分出的 `views/`）

---

## 4. 关键架构决策（新增代码前必读）

### 4.1 状态管理

- **约定**：`ChangeNotifier` + `ListenableBuilder`（或 `Listenable.merge`），需要持久化的用 `shared_preferences`
- 现有控制器：`ViewSettings`（排序/字段/视图模式）、`ThemeController`（外观）、`PlaybackProgressService`（单例，进度）、`PlaybackHistoryService`（单例，播放历史：记录/删除/清空/开关，默认开启，§4.17）、`SuperResolutionService`（单例，超分模式+质量+记忆开关）、`SubtitleSettings`（单例，字幕延迟/大小/位置/对齐/颜色/字体/内嵌样式覆盖，默认关闭）、`EqualizerSettings`（单例，均衡器 5 频段/低音增强/虚拟环绕/预设，默认关闭，全局持久化）、`AppFontSettings`（单例，App 全局字体开关/族名/字号/字重，默认关闭，§4.12）；控制按钮背景（底栏倍速/列表图标/顶栏控制图标，默认关闭）、倍速记忆（默认关闭）、画面比例（默认自动）、**长按倍速（倍率 1–4 步进 0.5/指示器开关/首次提示标记，阶段1 第 4 点）**、音量亮度手势灵敏度（默认 1.0）、保存音量到系统（默认开启）、**音量增强（开关默认关 + 上限百分比 10%~100% 步进 10 默认 60，§4.23）**、双指缩小视频（默认开启）、进度条缩略图（默认开启，见 §4.9）、已观看进度阈值（5%–100% 步进 5%，默认 95%）、自动连播（默认开启）、播放完毕自动退出（默认开启）、循环播放模式（off/列表循环/单集循环，默认关闭）、视频方向（自动/锁定竖屏/锁定横屏，默认自动）、播放界面动画（默认开启）、**顶部信息多选（时间/电量/网速/数据类型四项，默认全选，阶段1 第 1 点；旧单选枚举一次性迁移）** 属 `PlayerControlsSettings`；杜比视界「不再提示」记忆属 `DolbyVisionSettings`（单例，默认未抑制，§4.23）
- 播放页音量/亮度属于**页面局部状态**（进入时从系统同步，退出时按设置写回/恢复，见 §4.8），禁止做成全局服务
- 音频声道/音频处理（音量标准化/动态范围压缩）为**会话级状态**（随 `AudioController` 生命周期，每次进播放器重置为默认：安全自动/关/关），不持久化
- 片头片尾跳过设置属 `IntroOutroSettings`（独立单例 ChangeNotifier）：启用开关（默认关闭）、片头/片尾跳过秒数（默认 0）、各自范围上限（10–600 秒，默认 180）；范围收窄时秒数联动收窄；一键重置只清秒数与范围、保留开关；跟踪器 `IntroOutroTracker` 为普通类（随播放页生命周期），就绪门控防 open 期间误触发
- 章节跳段设置属 `ChapterSkipSettings`（独立单例 ChangeNotifier，区别于按秒数的 `IntroOutroSettings`，专用于**有章节信息**的视频）：六类片段（片头/片尾/前情提要/制作人员/正片前段/下集预告）的自动跳过开关（默认全关）+ 自定义片头/片尾关键词；`ChapterTracker` 构造时订阅、`load`/位置流读取（§4.22）
- 弹幕服务器设置属 `DanmakuServerSettings`（独立单例 ChangeNotifier，阶段3）：服务器列表（默认弹弹Play 不可删 + 自建增删启停）+ 切集自动匹配开关（**与默认弹弹Play 服务器互斥**，互斥判定与提示文案统一由本服务提供，见 §4.11），启动 `ensureLoaded`（main.dart）
- 播放页位置/时长属于**页面局部 ValueNotifier + 局部订阅**（risk_audit #1）：位置流几十毫秒一次事件，若整页 `setState` 会重建整棵 Stack（视频层/手势层/控制层），实际只有进度条、时间文本、常驻进度线需要跟随。横竖屏播放页把 `_position`/`_duration`/`_dragPosition` 抽为页面级 `ValueNotifier`，底栏与常驻进度线用 `Listenable.merge` 局部订阅只重建自身；页面级 `setState` 只留给低频状态（播放/暂停、控制层显隐、锁定、切集）。**注意这是页面局部 ValueNotifier**（dispose 时销毁），不属于被禁的「全局 ValueNotifier hack」
- 超分记忆语义（`SuperResolutionService`，默认关闭）：无论开关状态都记录「最近一次设置的 模式/质量」；开启记忆后 `load()`/`enterPlayer()` 自动恢复该组合应用到所有视频；**未开启记忆时 `enterPlayer()`（播放页 initState）把本次会话重置为关闭/均衡**——退出播放或重启后都回到默认关闭（参考 mpv-android-anime4k）
- **文件管理多选状态**属 `FileSelectionController`（普通 `ChangeNotifier`，**页面 State 里 new 一个、dispose 释放，刻意不做单例、不持久化**）：多选只作用于当前页面的当前列表，做成全局单例会跨页污染（§4.31）
- **禁止**：新增全局 `ValueNotifier` hack / 全局可变单例来跨页面通信
  - 反例教训：曾经的 `fullscreen_state.dart` 全局 `playerActive`，靠页面手动置位影响全局布局，引发连锁补丁 → 已重构为 `AppFrameObserver`（§4.3）
- 跨页面状态先想清楚归属：全局设置 → services 里的 ChangeNotifier；页面局部 → 页面 State；路由相关 → 路由机制

### 4.2 安全区（三大金刚键 / 挖孔）—— 全局已处理，页面零负担

`lib/widgets/app_frame.dart` 的 `AppFrame` 包裹整个 Navigator（挂在 `main.dart` 的 `MaterialApp.builder`）：

- **普通页面**：底部自动避让系统导航键（`bottom: true`），背景 = 主题色
- **播放页**：自动全屏（`bottom: false`），背景 = 黑色
- `left/right` **恒为 false**：横屏时挖孔在物理左/右侧，若消费会导致整个界面被挖孔挤到一侧（历史白条 bug 的根因，勿改）

**新增页面的约定**：
- 普通列表页：`Scaffold(appBar: ..., body: ListView(...))`，**什么都不用做**
- 底部有悬浮胶囊的主 tab 页：列表底部留 `88` padding（如首页/设置页）

### 4.3 播放页全屏检测 —— 路由驱动，禁止手动标志

`AppFrameObserver`（`app_frame.dart`，全局单例，挂在 `MaterialApp.navigatorObservers`）自动监听栈顶路由：

- **push 播放页统一用 `playerPageRoute`**（`app_frame.dart`，**无进出场动画**、瞬时切换 + 自动带 `RouteSettings(name: playerRouteName)`）；勿用 `MaterialPageRoute` 手写 settings——用户明确要求去掉进出播放的动画（历史滑动转场暴露「一半播放页、一半 app 界面」的过渡帧），瞬时切换后播放页与列表页任何时刻不同框
- 播放页内部**不要**手动设置任何全局状态
- 现有三处 push 已改用 `playerPageRoute`（home_page / folder_detail_page / tree_folder_page 的 `_openVideo`/`_openPlayer`）

### 4.4 播放页全屏（系统栏）

`player_page.dart` 的 `_enterFullscreen()`：`immersiveSticky` + 透明系统栏（`_exitPlayer` / `dispose` 恢复竖屏 + edgeToEdge）。退出统一走 `PopScope` 拦截 + `_exitPlayer()`：**同一帧 `pause()` 冻结末帧**（mpv 零新帧，末帧随瞬时 pop 消失，不再「黑屏渐隐」）→ 发起竖屏方向 + 保存进度 + 恢复设备状态（均 `unawaited` 不阻塞）→ 恢复系统 UI → **立即 pop**（`playerPageRoute` 无动画，与系统旋转并行）；**播放器销毁交给 `dispose()` 幂等兜底**（pause 已停帧，flutter#188300 不复发）。竖屏页退出走 `_exitWithPortrait`：先置 `_exitBlackout` 把下层横屏页整体黑化 → `pause()` 冻结 → IO `unawaited` → 连续 pop 竖屏页 + 横屏页（下层纯黑，任何时刻两层不同框，「两个竖屏界面」在机制上不可能复现）。系统返回键与返回按钮行为一致。

### 4.5 弹窗 / 面板

- **所有弹窗统一用** `showAppDialog`（`lib/utils/app_dialog.dart`，缩放 + 淡入动画），**不要**直接 `showDialog`。`barrierDismissible` 参数（默认 true）控制是否可点遮罩关闭；门禁类弹窗传 false 并让内容包 `PopScope(canPop: false)`（§4.19）
- **播放器内右侧滑入面板统一用** `showPlayerPanel`（`lib/widgets/player_panel.dart`，滑入 + 淡入 + 面板内页面栈）。倍速 / 超分 / 画面比例 / 更多 / 编辑控制栏共用；面板内二级页面用 `PlayerPanelNavigator.of(context).push(...)` 就地切换，禁止叠加第二个面板。**新增类似右侧面板需求时直接复用，勿另写一套**。注意：`of` 必须用面板树内的 context（内容里先包一层 `Builder` 再取），不能用页面 State 的 context。`showPlayerPanel` / `showPlayerBottomPanel` 的 `animate` 参数（默认 null = 跟随「播放器设置 → 启用播放界面动画」开关）控制进出场与页内切换动画
- **播放界面二级界面硬性约定**：播放器内凡需弹出二级界面（倍速、超分、画面比例、字幕/音频等后续功能）的，**横屏一律使用 `showPlayerPanel` 右侧滑入外壳**（同款外壳必须保证）；**竖屏播放页（`player_portrait_page.dart`）一律使用 `showPlayerBottomPanel` 底部弹出外壳**（`lib/widgets/player_bottom_panel.dart`，底部上滑 + 淡入，Material 外壳，面板内页面栈 `PlayerBottomPanelNavigator`）。两种外壳的面板内容组件（倍速/超分/画面比例/编辑控制栏）共用同一份数据与交互逻辑，只换容器。面板内容可选用 `PlayerOptionChip` 胶囊选择（视功能而定），也可用列表等其他形式，但**不得另写一套弹窗/面板外壳**。**竖屏页高需求**：`PlayerPanelPage.bottomHeightFactor`（默认 null = 外壳 0.42）可按页覆写底部外壳最大高度占比，只影响该页、返回上一页自动收回（高度差 240ms easeOutCubic 过渡）；网络弹幕搜索页用 0.82。**禁止**为了页高另开一个外壳
- **「更多」面板交互**：横竖屏「更多」面板均只列出**未放入槽位的动作**（`PlayerTopAction.values` 中不在 `topActions` 的）；点面板类动作（字幕/音频/比例/循环/章节/片头片尾）→ 面板内 `push` 就地切换（外壳 header 自动显示返回按钮，可返回「更多」列表，勿再关面板重开）；点动作类（画中画/听视频）→ 先关「更多」面板再执行（防叠加第二面板）；未实现动作提示「即将上线」；「编辑控制栏」为固定入口。**一级菜单 ListView 带 `PageStorageKey('more_panel')` 记忆滚动位置**（进二级再返回不回顶部）
- **编辑控制栏交互**：横竖屏编辑控制栏的「已启用/可添加」列表项**无副标题**（图标与名字用 `titleAlignment: center` 对齐）；槽位已满（5/5）时点「添加」→ toast「最多允许放 5 个」（不再禁用按钮 + 副标题提示）；「重置控制栏」无副标题。竖屏与横屏一致最多 5 槽位（`PortraitPlayerTopBar.maxPortraitSlots = 5`），不再区分 4/5
- **排序/字段弹窗统一用** `showSortOptionsSheet(context, viewSettings, hasFolders:, hasVideos:, showViewMode:)`（`lib/widgets/options_sheet.dart`）
  - `hasFolders` / `hasVideos` 按页面内容动态传（纯文件夹页、纯视频页、混合页自动区分区块）
  - `showViewMode` 仅首页传 true
  - 视频字段共 7 个（时长/大小/日期/分辨率/进度/字幕指示器/帧率），弹窗按三行胶囊展示（第一行 时长/大小/日期，第二行 进度/帧率/分辨率，第三行 字幕指示器独占整行）
- 搜索入口：首页/目录页/详情页 AppBar 右上角「搜索」在「排序」左侧，点击切换为内嵌搜索框，按名称（不区分大小写）过滤当前列表
- 弹窗类命名为 `_XxxSheet`，放页面文件内或公共 `widgets/`（跨页共用时）

### 4.6 卡片复用（树状/列表视觉一致的根基）

- 文件夹 → `FolderCard`（`widgets/folder_card.dart`），参数：`node / fields / onTap / onLongPress / isPinned / selectionMode / selected`
- 视频 → `VideoCard`（`widgets/video_card.dart`），参数：`video / fields / onTap / onInfoTap / trailing / onLongPress / selectionMode / selected`（trailing 覆盖最右侧图标，历史记录页放垃圾桶）
- `selectionMode` 由调用方的多选态驱动：卡片左侧插入勾选圆点、选中项换底色 + 主题色描边（视频卡片「已看完置灰」被选中态覆盖）；`FolderCard` 在多选态隐藏尾部 chevron（此时点击是「选中」而不是「进入」，箭头会误导，§4.31）
- **任何新视图/新页面显示文件夹或视频时，必须复用这两个卡片**，禁止另写一套样式
- 字段由 `ViewSettings.fields`（FolderField）和 `viewSettings.videoFields`（VideoField）驱动
- VideoCard 字段布局：**时长** = 缩略图右下角标签、**大小** = 缩略图左下角标签（两者自动避让底部进度条，有进度条时上移）；其余字段（日期/分辨率/进度/帧率/字幕指示器）为名称下方标签行；最右侧「i」媒体信息入口（`onInfoTap`，点击打开 `MediaInfoPage`）
- 「排序与字段」弹窗的视频显示字段区为**三行胶囊**布局（7 字段 = 3 + 3 + 1，行内等宽均分）：第一行 **时长/大小/日期**、第二行 **进度/帧率/分辨率**、第三行 **字幕指示器独占整行**（长度与上方两行整体一致）——见 `options_sheet.dart` 的 `_videoFieldChips`（显式指定行序，不依赖枚举顺序）
- 观看状态：`classifyWatchState`（`utils/watch_state.dart`）按「已观看进度阈值」（`PlayerControlsSettings.watchThreshold`，默认 95%）判定 未观看/观看中/已看完，已看完的卡片置灰

### 4.7 主题

- 主题色/风格都在 `theme_controller.dart`（`presetColors` 23 色、`variantLabels` 21 风格）
- 新增主题色：往 `presetColors` 加 `(color: ..., label: 'XXX色')`（3 字命名，色相排列）
- 调色板风格来自 flex_seed_scheme 的 `FlexSchemeVariant`（21 种已全量），**勿**改枚举顺序（持久化 index）；
  外观页调色板为**显示层重排**（标准型独占首行 + 其余 20 个 4×5 胶囊化），枚举顺序与 index 不变
- `app_theme.dart` 统一 `appBarTheme`（`scrolledUnderElevation: 0` + 固定背景色，防止 AppBar 滚动变色）
- **主题色网格**（`appearance_page.dart`）：23 预设 + 1「动态色」= 4×6 网格 + 下方通栏「自定义」；
- **动态色（壁纸取色 / Material You）**：原生 `MainActivity.getWallpaperColors`（`WallpaperManager` +
  `WallpaperColors.fromDrawable`，后台线程）+ `device_services.getWallpaperPrimaryColor`；
  Android 12 以下点击 toast「安卓版本过低，不支持该功能」；`ThemeController.usingDynamicColor`
  标记当前是否动态色（选中态，切换预设/自定义时清除）
- **自定义主题色**：`ThemeController.customColor`（持久化，只存一个）+ `setCustomColor`；
  选色弹窗 `_CustomColorDialog`（`flutter_color_picker_plus`）：方块 SV 区（`ColorPickerArea` PaletteType.hsv）
  + 下方横向色相滑条（`ColorPickerSlider` TrackType.hue，需固定高度包装否则 CustomMultiChildLayout
  无限高度溢出）+ hex 手输框（`ColorPickerInput`）+ RGB/HSV/HSL 切换胶囊（自绘数值文本，
  不用 ColorPickerLabel 因其 DropdownButton 单值会断言崩溃）；确定用所选色作 seed 立即生效

### 4.8 播放页手势（新增功能前必读）

播放页手势统一由 `PlayerGestureLayer`（`pages/player/views/`）承载，**不要**在播放页再叠加
`GestureDetector` 手势（多识别器竞技场竞争会导致方向判定漂移，历史教训）。方案对齐
PiliPlus：裸 `RawGestureDetector` + 自定义识别器组 + `Listener` 兜底。

| 手势 | 行为 | 说明 |
|---|---|---|
| 单击 | 显隐控制层（锁定态切换解锁按钮） | Tap + DoubleTap 并存，单击有 ~300ms 双击判定延迟（与旧实现一致） |
| 双击 | 按 `doubleTapMode`：暂停 / 左退右进 / 混合 | 同旧逻辑 |
| 长按（500ms） | 临时倍速（设置值 1–4x），指示器常驻 | 长按期间 `Listener` 裸指针事件驱动左右滑动调速 |
| 长按 + 左右滑动 | 动态调速 1.5–4x（间隔 0.5，离散），出现倍速条 | 灵敏度（阶段1 第 4 点重设计）：滑动约 **1/6 屏宽**扫完整个动态区间（倍率 6.0，旧 3.5 需滑近一屏太不灵敏）；倍速条在指示器下方，停在某档 3 秒自动隐藏；首次完成该操作后提示不再出现（`speedHintShown` 持久化） |
| 单指垂直滑动 | 左半屏亮度、右半屏音量 | 顶部/底部 8% 死区（避系统手势）；音量 0–100、亮度 0–1，带浮点累加器；**方向确认延迟 80ms**（给第二根手指加入时间，防捏合误触滑动） |
| 单指水平滑动 | 实时 seek（满屏 = 90 秒，40ms 节流），居中浮层显示目标时间 | 右侧 8% 死区（避系统返回手势）；若滑动中途加入第二指，先撤销 seek（`onSwipeCancel`）再进缩放 |
| 双指 | 缩放（0.75–4x，设置可禁缩小）+ 平移 | 以双指焦点为锚缩放 + 焦点位移平移；缩放后「还原画面」胶囊出现在播放/暂停按钮下方（Alignment 0.34） |

音量/亮度与系统交互约定（原生在 `MainActivity.kt`，走 `DeviceServices`）：
- 进入播放：读系统音量作为播放音量起点（如 20%）；亮度读系统值并**应用到窗口**
  （kt/mpvEx 做法：屏幕显示与指示器一致，播放期间亮度不随自动亮度漂移），**不改系统设置**；
- 播放中：音量手势直控**系统**媒体音量（`DeviceServices.setSystemVolume` 0–100，mpv 音量固定
  100 满增益）；**音量增强开启时**（§4.23），系统音量满 100% 后继续上滑接管 mpv 音量
  （`player.setVolume` 100~100+cap，`volume-max=100+cap`），指示器红色显示 110%~200%；
  亮度只调窗口亮度（`WindowManager` 属性，无需权限）；
- 退出播放：**亮度恢复 -1（交还系统控制 = 进入前状态）**；mpv 增强音量复位 100；音量按设置
  「保存音量到系统」（默认开）→ 写回系统，关闭 → 恢复进入前系统音量。`dispose` 兜底恢复，防异常路径泄漏；
- 音量指示器在**屏幕左侧**、亮度指示器在**屏幕右侧**（对称）；kazumi 风格进出场
  （从屏幕边缘滑入滑出 + 淡入淡出 + 轻微缩放），2 秒无操作自动隐藏。

### 4.9 进度条缩略图 —— FFmpeg 快速引擎（自建 libmpv 内核）

> 2026-08 重构：进度条抓帧从「原生 MediaMetadataRetriever + 磁盘缓存 + video_thumbnail_plus 兜底」
> 三级链路，整体替换为**自建内核 + FFmpeg 独立解码实例**。旧链路、磁盘缓存与预生成服务已全部移除。

**内核来源**：`third_party/media_kit_libs_android_video/`（本地包，pubspec `dependency_overrides` 指向），
内含 4 个 ABI 的 jar（`android/jars/`，`fileTree` 直接引用，**不走官方下载任务**）。
jar 构建自 [azxcvn/libmpv-android-video-build](https://github.com/azxcvn/libmpv-android-video-build)
（fork，补丁 `mk_thumbnail.patch` 给 libmpv 增加 `mk_thumbnail_grab/free/clear_cache` 三个导出符号，
push 即 CI 出包）。升级内核：换 jar → 无需改任何 Dart 代码。

**调用链**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 内核 | libmpv.so `mk_thumbnail_grab` | 独立 FFmpeg 解码实例：MediaCodec 硬解优先/失败自动软解、硬解 ctx 全局复用、极速探测、**关键帧优先向后 seek + 逐帧解码到目标帧（帧级精确匹配）**；输出 RGBA |
| 引擎 | `services/fast_thumbnails.dart` | FFI 绑定 + 后台 isolate + **单飞调度**（最多 1 在跑 + 1 待跑，新请求顶掉旧待跑） |
| 缓存 | `services/device_services.dart` | `getVideoFrameAt`：秒桶 + **32MB 内存 LRU**（RGBA 字节计）+ 在飞去重 + **失败 10s 冷却**（被顶掉 `stale` 不计冷却）；`peekFrame`/`peekNearestFrame`（兜底半径 **±3s**） |
| UI | `views/player_thumbnail_preview.dart` + `widgets/raw_thumb_image.dart` | 气泡 + RGBA 直渲（`ImageDescriptor.raw`，无 PNG/JPEG 编码往返） |
| 调度 | `pages/player/player_page.dart` / `player_portrait_page.dart` | 横竖屏两页同款：拖动邻近帧秒显 + 精确帧异步补齐；松手淡出 150ms 后卸载 + **空闲 350ms 预取 ±1/±2/±3 秒桶**（再拖动立即终止，拖动请求绝对优先）；共用同一 FFmpeg 引擎与内存缓存，受同一 `showThumbnailPreview` 开关控制 |

**关键事实**：
- JavaVM 无需自行注册——media_kit 启动时已通过官方补丁 `mpv_lavc_set_java_vm` 完成，MediaCodec 硬解天然可用
- 精确落帧：播放器初始化设 mpv `hr-seek=absolute`（`_applyExactSeek`），松手 seek 帧级精确、与预览帧一致
- 缩略图**无磁盘缓存**（单帧 ~85ms 无落盘必要）；「缓存管理」页只管列表封面
- 性能基线（一加 PLR110，1080p H.264）：硬解 63–134ms/帧；logcat `MKThumb` 可查每帧 `hw=` 与耗时
- 精确匹配耗时随关键帧距离（GOP）增长：短 GOP 基本不变（~85ms）；长 GOP 高码率（4K、10s 一个关键帧）明显变慢（需逐帧桥接解码到目标）
- 听视频页封面（`audio_player_page`）复用同一引擎（`maxWidth: 480`）

### 4.10 自定义字幕字体 —— media_kit 本地 fork + mpv_initialize 前注入

**目标**：对齐小喵 player——用户**先选择一个字体目录**（SAF 目录选择器，强制不选不用），
把目录里所有 `.ttf/.otf/.ttc/.otc` 一次性拷贝到应用私有 `filesDir/fonts/`，再在字体列表里点击选择；
目录可 ✕ 清除重选、可刷新重新拷贝（新增字体后）。字体仍作为 libass 字幕字体。

**架构**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| media_kit 魔改 | `third_party/media_kit/`（本地 fork：`platform_player.dart`、`real.dart`、`pubspec.yaml`） | 新增 `libassAndroidFontsDir` 字段，在 `mpv_initialize()` 前把目录注入 `sub-fonts-dir`（绕过只支持 asset 的 `AndroidAssetLoader`）；注入前校验目录含字体文件、并 `assert` 要求同时给族名。**4 处补丁清单见 `third_party/media_kit/FORK.md`** |
| 原生层 | `MainActivity.kt` | `openFontDirectoryPicker`（`ACTION_OPEN_DOCUMENT_TREE` + `takePersistableUriPermission`）、`copyFontsFromDirectory`（`DocumentFile` 遍历顶层文件 + 批量拷贝 + 兜底字库）、`listFontEntries`（扫描私有目录 + truetypeparser 解析族名去重、隐藏兜底字库）、`clearFontsDirectory`；`ensureFallbackFont`/`getFontFamilyName` 沿用 |
| 服务层 | `subtitle_settings.dart` / `device_services.dart` | 字体族名 + 私有目录 + **源目录 tree uri** 三者持久化（`setFontSourceDir`）；`openFontDirectoryPicker`/`copyFontsFromDirectory`/`listFontEntries`/`clearFontsDirectory` 封装 |
| 播放器 | `player_page.dart` / `subtitle_service.dart` / `models/subtitle_font_injection.dart` | Player 构造经纯函数 `resolveSubtitleFontInjection()` 注入配置（**默认也注入 `/system/fonts`**）；**任何**运行时 `setProperty('sub-fonts-dir')` 都是回归（§4.32） |
| UI | `subtitle_panel.dart` | 「字幕字体」入口 + `SubtitleFontPanel`（目录选择/刷新/清除 + 字体列表单选 + 重启提示） |

**关键约束（勿违反）**：
- **`sub-fonts-dir` 必须在 `mpv_initialize()` 前注入**——libass 只在初始化时扫一次字体目录，运行时 `setProperty('sub-fonts-dir')` 会打坏字体缓存导致字幕整条消失（Gemini 历史教训）。
- **换字体需退出播放器重新进入**（重建 Player），与小喵一致。
- **不选目录不允许用自定义字体**（工作.md 第 1 点）：源目录未选时字体列表为空，只有「默认字体」。
- **目录授权需持久化**：`takePersistableUriPermission` + `FLAG_GRANT_PERSISTABLE_URI_PERMISSION`/`FLAG_GRANT_PREFIX_URI_PERMISSION`，否则重启后 tree uri 失效、无法刷新。
- **族名解析用 truetypeparser**（`TTFFile.open(...).families.values.firstOrNull()`），手写 sfnt name 表解析器有偏移 bug（曾把 table offset 读成 0x1700583C）。
- **兜底字库用复制、普通文件名**，不用 symlink + 隐藏文件名（fontconfig 跳过 `.` 开头文件且不 follow symlink）。
- **目录必须存在且含字体文件才注入**（fork 侧 `_hasFontFile()` 校验 `.ttf/.otf/.ttc/.otc`）——libass 拿到**空目录**会让字体解析全部失败，比不设置 `sub-fonts-dir` 更糟（中文字幕变方块）。该扩展名清单必须与 `models/subtitle_track.dart` 的 `kFontExtensions` **保持同步**。
- **`libassAndroidFontsDir` 必须与 `libassAndroidFontName` 同时提供**——libass 的 `sub-font` 按**族名**匹配，只给目录无法定位到具体字体；构造函数 `assert` 在 debug 拦截，release 走 `real.dart` 的告警分支。

**维护**：`third_party/media_kit` 是本地 fork（`pubspec.yaml` `dependency_overrides` 指向），当前基线 **1.2.6**、共 **4 处补丁**（3 处在 `lib/`，1 处在 `pubspec.yaml` 的 SDK 约束）——**补丁清单、升级步骤与验证方法统一记在 `third_party/media_kit/FORK.md`，升级前必读**，禁止直接 `pub upgrade` 覆盖。依赖 `io.github.yubyf:truetypeparser-light:2.1.4` 与 `androidx.documentfile:documentfile:1.0.1`（`android/app/build.gradle.kts`）。

### 4.11 弹幕 —— canvas_danmaku 渲染 + 本地同名加载 + 设置面板

> 弹幕移植方案（`杂项文件/弹幕移植方案/`）阶段1 + 阶段2：**阶段1** =
> 「显示/隐藏 + 本地同名弹幕加载」（开关为会话级，默认开启）；**阶段2** =
> 「弹幕设置面板」（样式 + 配置全量持久化，工作.md 弹幕第 4/6 点）。
> 渲染层用 pub `canvas_danmaku: ^0.3.3`（与参考项目 `canvas_danmaku-main` v0.3.3 同版本）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 数据模型 | `models/danmaku_entry.dart` | 单条弹幕（time/mode/color/text，纯数据可跨 isolate） |
| 纯函数 | `utils/danmaku_local_file.dart` / `danmaku_xml.dart` / `danmaku_timeline.dart` | 9 种同名命名规则查找 / B站 XML 解析（`compute` 后台 isolate）/ 同秒错峰延迟 + 时间轴偏移 |
| 调度 | `services/danmaku_scheduler.dart` | 秒桶索引 + 1s tick 前向补发 + seek 跳变检测（±阈值）+ 代数失效（纯逻辑可单测） |
| 业务 | `services/danmaku_service.dart` | `DanmakuController`：自订阅 `stream.position/playing/rate/buffering` + 1s Timer 发射（守卫链）+ 渲染层 registry + 倍速跟随 |
| 渲染 | `pages/player/views/player_danmaku_layer.dart` | `DanmakuScreen` 封装，挂载/卸载即 attach/detach 到业务控制器；初始 option 从设置单例构建 |
| UI | `pages/player/views/player_danmaku_buttons.dart` | 开关/设置按钮组（Kazumi 图标：开=内联 `kDanmakuOnSvg` 主题色对勾；关/设置=资源 SVG，`assets/icons/`） |
| 面板 | `pages/player/views/player_danmaku_panel.dart` | 弹幕二级界面（更多→弹幕/顶栏槽位共用）：本地弹幕=复用 `SubtitleFilePickerPanel`（只换过滤器/图标/记忆键，content:// 走原生 `copyDanmakuFromUri` → `filesDir/danmaku/`）；网络弹幕/自动匹配 toast 待上线；弹幕设置与底栏按钮同一回调 |
| 设置面板 | `pages/player/views/player_danmaku_settings_panel.dart` | 弹幕设置面板（横竖屏外壳共用）：三段式布局（样式 5 滑杆 + 随机渐变色 / 配置 2 滑杆 + 5 开关 + 屏蔽词 / 偏移 1 滑杆）+ 恢复默认；字号/字重/描边/偏移松手提交，其余实时写 `DanmakuSettings` |
| 设置 | `services/danmaku_settings.dart` | 弹幕设置单例（`ChangeNotifier` + SharedPreferences 持久化）：字号/字重/速度/描边/不透明度/随机色 + 区域/行高/三类显隐/海量/去重/屏蔽词 + 时间轴偏移；启动 `ensureLoaded`（main.dart） |
| 纯函数 | `utils/danmaku_random_color.dart` / `danmaku_dedup.dart` / `danmaku_blocklist.dart` | 随机渐变色（HSV 色轮黄金角步进 + 随机漂移，种子可复现）/ 去重（文本归一化判同 + 时间窗合并，对齐 Kazumi）/ 屏蔽词（子串命中过滤，忽略大小写/空白） |

**关键决策**：
- **渲染层 registry（横竖屏双挂）**：横竖屏两个页面各挂一个 `DanmakuScreen`，业务层
  `DanmakuController` 用 `List<DanmakuController<void>>` 同步驱动全部已挂载层——切换
  屏幕（push/pop 竖屏页）时无需清屏重启，返回横屏时弹幕无缝续播；`attachLayer` 时补
  应用当前倍速/暂停态，`detachLayer` 由渲染层 widget 的 `dispose` 触发。
- **发射模型**：Kazumi 现网「秒桶 + 1s Timer + stagger + generation」+ 两处增强——
  ① tick 间**前向补发** `(上一秒, 当前秒]` 全部桶（高倍速/计时抖动不丢弹幕）；
  ② **实时 seek 检测**（Kazumi 体验）：位置流事件上以「倍速 × 事件间隔墙钟时间」为
  期望位移（`isSeekJump` 纯函数），判定跳变**立即**代数失效 + 清屏 + 锚点对齐
  （`notifySeeked`，落点秒 - 1 下个 tick 补发落点秒弹幕），不再等下一个 1s tick；
  tick 上的跳变检测保留为兜底。均无需逐个挂钩 8+ seek 调用点。
- **倍速跟随**：`duration/staticDuration = 基准 / rate`（基准独立存储、每次现算，
  零累计误差）；canvas `updateOption` 全局平滑变速，在屏弹幕同帧变速。
- **加载会话号**：`loadForVideo` 进入即 `++_loadSession` + 重置调度器 + 清屏，
  异步读文件/解析完成后会话号已变则丢弃（旧集弹幕不灌入新集）。
- **样式映射**：B站 mode 4→底部、5→顶部、其余一律滚动（对齐 Kazumi；高级弹幕后续阶段）。

**手动导入**：`loadDanmakuFromFile(path)`（真实绝对路径，content:// 已由原生拷贝）；
成功自动开启弹幕显示并**记忆到当前视频**（`DanmakuManualMemory`，SharedPreferences
持久化，重启播放器/软件自动恢复）；`loadForVideo` 优先级 = **手动记忆 → 同名查找**
（用户显式选择不被自动查找覆盖），记忆的弹幕文件已失效（被删除/不可读/空弹幕）时
清除该条记忆并回落同名查找。手动导入为会话级生效，记忆跨会话。
自动加载（同名 / 记忆恢复）成功经 `onAutoLoadedDanmaku` 由播放页弹 toast
「已自动加载弹幕：文件名」（对齐字幕 `onAutoLoadedSubtitle` 模式）；**每个视频只在
第一次自动加载时提示**（`DanmakuManualMemory` 另存「已提示」路径集合持久化去重，
重启播放器/软件不再重复）。

**选择器死路径防护**（字幕/音频/弹幕共用面板）：`DeviceServices.listDirectory` 对
「目录不存在/不可读」返回 **null**（区别于真实空目录）；打开选择器时记忆文件夹失效
则**向上回退**到最近存活祖先；导航到失效目录维持原状不落死路径（小喵 player 停在
死路径卡死的教训）。

**设置应用（阶段2）**：控制器订阅 `DanmakuSettings`（构造时 addListener，dispose 退订）。
样式/配置（字号/字重/速度/描边/不透明度/区域/行高/三类显隐/海量）经 `updateOption`
热更新下发渲染层（速度 = 横穿耗时 `scrollSeconds / rate`，静置弹幕取其一半）；
**去重**开/关变化时按原始条目重灌秒桶（`_rawEntries` 保留原始数据）并锚定当前位置；
**随机渐变色**开启时重建色轮（新随机起点）并清屏，发射时逐条覆盖文件颜色。新挂载
渲染层的初始 `DanmakuOption` 由 `danmakuOptionFromSettings` 从设置单例构建（首帧即
用户样式）。设置全量持久化（重启视频/播放/软件均保留，工作.md 弹幕第 6 点）；
三入口（横屏左下角设置按钮/竖屏进度条上方设置按钮/更多→弹幕→弹幕设置）进入同一
面板，面板内容横竖屏共用、只换外壳（§4.5）。

**时间轴偏移（阶段2 补充）**：设置项 `DanmakuSettings.timeOffsetSeconds`
（-180~+180 秒，整数步进，正 = 延后、负 = 提前），纯函数 `sourceDanmakuPosition`
（`utils/danmaku_timeline.dart`，source = playback − offset）在发射/seek 锚定时把
播放位置映射到源时间（负秒桶视为空）；偏移变化时重锚定秒桶 + 清屏重新对齐
（对齐 Kazumi `DanmakuTimeline.resolveSourceSecond` + `danmakuTimeOffset`）。

**屏蔽词（阶段3 补，已实现）**：`DanmakuSettings` 维护屏蔽词列表（添加/移除/清空/持久化，
启动 load 归一化去重去空白）；纯函数 `utils/danmaku_blocklist.dart` 做子串命中判定
（忽略大小写/空白）；`DanmakuController._effectiveEntries` 在装载/重灌时先过滤屏蔽词再按
去重开关合并，屏蔽词变化重灌秒桶（`_refeedIfLoaded`）；面板「弹幕配置 → 屏蔽词」折叠行
输入添加/词条删除/一键清空。

**弹幕合并 + 彩色弹幕（本轮补，E4 的 4.2/4.3 两小项）**：

| 能力 | 实现 | 说明 |
|---|---|---|
| 弹幕合并 | `utils/danmaku_merge.dart` + `DanmakuSettings.merge` | **跨时间窗**（默认 10s，`kDanmakuMergeWindowSeconds`）把同内容弹幕聚成一条并计数；渲染为 `文本 ×N` |
| 普通彩色弹幕 | 既有能力 | `DanmakuEntry.color`（XML `p` 第 4 位 / protobuf 字段 5）→ 渲染原色 |
| 会员渐变彩色弹幕 | `DanmakuElem.colorful`（protobuf 字段 24 == 60001） | 透传到 `DanmakuContentItem.isColorful`，canvas 用粉蓝渐变描边绘制 |

- **与去重的分工（用户拍板语义，两者互斥）**：去重（窗 5s）= 同一时间窗内相同内容只留一条、
  不计数；合并（窗 10s）= 跨时间把一段内容里的相同弹幕聚成一条并计数。**语义冲突，故互斥**——
  `DanmakuSettings.setDeduplication(true)` 会自动关掉合并、`setMerge(true)` 会自动关掉去重，
  互斥裁决只在服务层一处（同 §4.11 弹幕服务器互斥的做法），UI 与运行时共用同一份生效值。
  两者判同共用 `normalizeDanmakuText`（小写/去空白/去标点/连续字符收敛），所以
  `666`/`6 6 6`/`66666` 同键。
- **流水线顺序：屏蔽词 → 合并 → 去重**。互斥后最多命中一条分支；代码仍按此顺序写，
  保证任何情况下合并都先于去重（先跑去重会把计数信息吃掉）。合并后条目文本保持原样
  （计数走 `DanmakuEntry.count`），因此去重/屏蔽词的判同不受影响。
- **算法 O(n) 一次线性扫描**：按时间排序后用「归一化文本 → 当前簇（首条时间 + 计数）」哈希表，
  同键在窗口内计数 +1，超窗则落盘旧簇并开新簇；**不需要「找最多/第二多」的排名步骤**
  （每个键各算各的计数，天然得到全部频次）。簇锚定**首条时间**，避免连续重复把窗口无限拖长。
- **渲染计数不用 canvas 的 `count`**：canvas 0.3.3 的 `(N)` 只在**描边段落**里绘制，
  描边宽度设 0 时计数不可见（设置允许 0）；因此把 `×N` 拼进显示文本
  （`DanmakuEntry.displayText`），文本本身保持原样供判同/复制用。
- **随机渐变色优先**：随机色开启时逐条改色，会员渐变让位（`isColorful && !randomColor`）。
- **XML 缓存不保留 colorful**：B站 XML 无该字段，`danmakuEntriesToBiliXml` 落盘后回读只剩普通颜色
  （`loadCachedDanmaku` 目前无调用方，不影响在线播放）。
- **入口**：播放界面 → 更多 → 弹幕 → 弹幕设置 → 弹幕配置，位于「弹幕去重」与「屏蔽词」之间。

**阶段2 未做**（后续阶段）：B站 gRPC；弹幕点选（E4 4.1）与高级弹幕 mode 7（E4 4.4）本轮明确不做。
顶栏「弹幕」槽位与「更多→弹幕」进入弹幕二级界面（`implemented=true`）。

**网络弹幕 / 自动匹配 / 弹幕服务器（阶段3）**：

| 层 | 文件 | 职责 |
|---|---|---|
| 数据模型 | `models/danmaku_server.dart` / `dandan_models.dart` / `danmaku_auto_match_cache.dart` | 服务器配置 / API DTO（番剧·集·评论·匹配）/ 切集自动匹配缓存 |
| 纯函数 | `utils/dandan_signature.dart` / `dandan_comment.dart` / `danmaku_episode.dart` | 签名 `base64(sha256(AppId+Timestamp+Path+AppSecret))` / 评论→条目 / 文件名集数提取+匹配 |
| API | `services/dandan_play_api.dart` | 签名验证模式：`/api/v2/search/episodes`、`/api/v2/comment/{id}?withRelated=true`、`/api/v2/match`（响应按 UTF-8 解码，非 200/业务错误抛 `DandanApiException`） |
| 网络业务 | `services/danmaku_network_service.dart` | 搜索合并（按 animeId 去重 + 记录来源服务器）、文件匹配合并、下载落盘 `filesDir/danmaku/network/`、文件前 16MB MD5 |
| 设置 | `services/danmaku_server_settings.dart` / `danmaku_search_history.dart` / `danmaku_auto_match_cache_store.dart` | 服务器增删启停 + 切集自动匹配开关（含与默认服务器的互斥裁决与提示文案）/ 搜索历史（上限淘汰最旧）/ 匹配缓存 |
| UI | `views/player_danmaku_network_panel.dart` | 网络弹幕三级界面：40dp 胶囊搜索框 + 框下关键词历史胶囊 + 命中后折叠搜索条 + 结果卡自持动画展开集列表 |
| 设置页 | `pages/settings/danmaku_server_page.dart` | 设置 → 弹幕 → 弹幕服务器（默认不可删 + 自建增删启停 + FAB 添加） |

**关键决策**：
- **密钥私有**：`AppId/AppSecret` 存 `services/dandan_play_keys.dart`（已 gitignore，禁止提交
  GitHub；工作.md 第 3 点，优先用 AppSecret2）。签名验证模式比凭证模式更安全（AppSecret
  不随每次请求外发）。
- **网络弹幕持久化（工作.md 第 2 点）**：无论本地导入 / 自动匹配 / 手动搜索下载，成功
  装载过一次即**落盘 + 记忆**——`DanmakuController.loadNetworkDanmaku`（及切集自动匹配）
  拉取评论后生成 B站 XML 落盘 `filesDir/danmaku/network/<番剧>_<集>_<episodeId>.xml`
  并写入 `DanmakuManualMemory`（视频路径 → 文件路径）。`loadForVideo` 第 1 步的记忆恢复
  **与切集自动匹配开关无关**；切集自动匹配开关只门控「新视频（无记忆）自动匹配下一集」。
- **toast 语义（工作.md 第 3 点）**：「已自动加载弹幕：文件名」只在**同名自动查找**路径
  触发（且每视频仅第一次，持久化去重）；记忆恢复一律**静默**（记忆里既有手动导入也有
  网络弹幕，恢复时不能误报「自动加载」）。网络弹幕显式加载经 `onNetworkDanmakuLoaded`
  弹「已加载弹幕：番剧 · 集」。
- **切集自动匹配（工作.md 第 7 点）**：`loadForVideo` 本地同名无匹配后，若
  `DanmakuServerSettings.autoMatchEnabled` 且存在 `DanmakuAutoMatchCache`，按
  `extractEpisodeNumber(文件名)` → `findMatchingEpisode(缓存集列表)` 定位对应集并下载；
  缓存由「自动匹配命中 / 网络搜索选中」写入（自动匹配命中后异步 `searchAnime` 取回
  完整集列表再存）；装载成功同样落盘记忆，该视频之后再进直接走记忆恢复。
- **自动匹配按钮**：`matchCurrentVideo` 算前 16MB MD5 + 文件名 + 大小 → 合并启用服务器
  候选；单候选直接加载，多候选 `showAppDialog` 弹「选择匹配结果」列表。
- **搜索 UI 设计规范（本轮重设计，工作.md 网络弹幕 4 点）**：
  - **紧凑搜索框**：自绘 40dp 定高胶囊 + `InputDecoration.collapsed` + 28dp 迷你按钮
    （清空/搜索）。**禁止**回到 `TextField` 默认 `OutlineInputBorder` + `IconButton` suffix
    ——后者的 48dp 最小点击区会把输入框顶到 60dp+（原「搜索框太高」的根因）。
  - **关键词历史**：胶囊 `Wrap` 直接贴在搜索框下方（末尾一枚「清除」胶囊），**不独占分组
    卡片、无分组标签**；搜索框折叠时历史一并隐藏。
  - **命中即折叠**：搜到结果后搜索区收成 34dp 的「关键词 · N 部」胶囊条（点击重新展开，
    结果保留），把竖向空间全部让给结果列表；无结果/出错保持展开便于改词。竖屏另经
    `PlayerPanelPage.bottomHeightFactor: 0.82` 抬高底部外壳（§4.5）。
  - **展开/收起动画**：每张结果卡自持 `AnimationController`（进 320ms easeOutCubic /
    退 250ms easeInCubic），`Align(heightFactor)` 高度与内容 `FadeTransition` **错峰**
    （展开先长高后显形 `Interval(0.30,1)`、收起先淡出后收高 `Interval(0.55,1)`），
    箭头 `RotationTransition` 共用同一曲线；完全收起时子树不构建、展开时卡头
    `Scrollable.ensureVisible` 顶到可视区；集数 > 6 时集列表落在 264dp 定高滚动容器
    （动画期间布局量恒定）。手风琴式，同时只展开一个。
- **切集自动匹配与默认服务器互斥（工作.md 第 7 点，收尾阶段已恢复）**：启用默认
  弹弹Play 服务器时**不允许**开启「切集自动匹配」。互斥**只在服务层裁决一处**
  （`DanmakuServerSettings`），防 UI 与运行时各判一次而漂移：
  - `autoMatchEnabled` = 唯一生效值（默认服务器启用时恒 false），设置页与
    `DanmakuController._tryAutoMatch` 共用，运行时无需二次判断；
  - `autoMatchPreference` = 用户原始偏好（**不含**互斥判定）：启用默认服务器只是
    「暂时不生效」，停用后自动恢复用户选择，不静默丢偏好；
  - `autoMatchAllowed` 判定是否可开；文案**两级**且都在服务层（页面内不写文案
    字面量）：`autoMatchBlockedReason` = 短指引「请先停用弹弹Play 服务器」（副标题用，
    窄屏单行不挤）、`autoMatchBlockedMessage` = 含服务器名与开关名的完整说明
    （toast 用）；
  - `setAutoMatchEnabled` 返回 `bool`：被互斥拒绝时返回 false 且不写偏好；**关闭
    动作永远允许**。
  - UI（`danmaku_server_page.dart` 的 `_AutoMatchTile`）：禁用时 `onChanged: null`
    使 Switch 与整行变灰 + 副标题换成 error 色**短**原因，并盖一层
    `kAutoMatchBlockedTapKey` 透明命中层吞掉点击、弹**完整说明** toast
    （**变灰必须配文本提示**，否则用户以为是 bug）。

---

### 4.12 全局与弹幕自定义字体 —— Flutter 引擎 `loadFontFromList` 注册

**目标**：对齐 Kazumi / PiliPlus——App 全局字体与弹幕字体均走 Flutter 引擎字体
注册（`dart:ui loadFontFromList(bytes, fontFamily:)`），与字幕字体（§4.10 libass）
是两套机制；「跟随系统」＝`fontFamily: null`（Skia 回落系统默认字体，ColorOS 上即
主题商店字体）。App/弹幕/字幕共享 `filesDir/fonts/` 同一字体池，一次导入三处可用。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/danmaku_font_mode.dart` | 弹幕字体三态枚举 + `resolveDanmakuFontFamily` 解析纯函数 |
| 服务 | `services/app_font_settings.dart` | App 全局字体（enabled/family/file/textScale/fontWeightIndex）+ 持久化 + `registerFontFile`（读字体字节注册，App/弹幕共用）+ `registerCurrentFont`（冷启动重注册） |
| 服务 | `services/danmaku_settings.dart` | 弹幕字体三态 + 自定义族名/文件名 |
| 服务 | `services/danmaku_service.dart` | `danmakuOptionFromSettings` 每次新建 DanmakuOption 并填 `fontFamily`（跟随系统=null）；`DanmakuController` 同时订阅 `AppFontSettings` |
| 主题 | `theme/app_theme.dart` | 三个工厂加 `fontFamily`/`fontWeight` 参数；`fontWeight` 全量覆盖 textTheme |
| 装配 | `main.dart` | `main()` 改 async：runApp 前 `ensureLoaded + registerCurrentFont` + 弹幕自定义字体注册；`ListenableBuilder` 合并监听 `AppFontSettings`；builder 里按 `effectiveTextScale` 包 `MediaQuery.textScaler` |
| UI | `pages/settings/font_page.dart` + `appearance_page.dart` | 设置→外观→App字体设置：预览（数字/大小写/符号/中文）+ 开关 + 系统选择器导入单字体 + 字号/字重滑杆 |
| UI | `player_danmaku_settings_panel.dart` | 弹幕字体段：三选一（跟随系统/跟随 App/自定义）+ 自定义时目录导入 + 列表选择 |

**关键约束（勿违反）**：
- **注册时机**：`loadFontFromList` 只对当前进程有效，冷启动必须重读文件重新注册，
  且必须在**首次渲染该 family 前**完成（`main()` 改 async、`runApp` 前 await）。
- **「跟随系统」＝ null**：App 的 `ThemeData.fontFamily` 与弹幕的
  `DanmakuOption.fontFamily` 均为 null 时落到系统默认字体，无需枚举/注册系统字体。
- **不能 `copyWith(fontFamily: null)` 清空**：canvas 0.3.3 的 copyWith 用
  `fontFamily ?? this.fontFamily`，切回跟随系统必须**重建 DanmakuOption**
  （本项目 `danmakuOptionFromSettings` 每次新建，天然满足）。
- **两套机制勿混**：App/弹幕字体走 `loadFontFromList`；字幕字体走 §4.10
  `sub-fonts-dir`（mpv_initialize 前注入）。两者共享目录、注册方式不同。
- **有效值只由 enabled + family 共同决定**：`AppFontSettings.effectiveFamily` =
  `enabled && family != null ? family : null`，字号/字重同此门控（关闭时回默认）。

---

### 4.13 哔哩哔哩账号登录（哔哩生态阶段一）

> 调研方案见 `杂项文件/bili-ecosystem-research/`；接入进度见 `docs/哔哩哔哩生态接入状况.md`。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/bili_wbi.dart` | WBI 签名（`biliGetMixinKey` / `biliEncWbi`），混淆表 64 项（bilibili-API-collect 规范） |
| 纯函数 | `utils/bili_app_sign.dart` | TV 端 appSign（appkey/appsec MD5，对齐 PiliPlus app_sign.dart） |
| 模型 | `models/bilibili_user.dart` | nav 接口用户信息（mid/昵称/头像/大会员状态） |
| 常量/端点 | `services/bilibili/bili_constants.dart` / `bili_api.dart` | 域名/UA/Referer/appkey·appsec/扫码状态码 + 端点常量 |
| 存储 | `services/bilibili/bili_credential_store.dart` | SESSDATA/bili_jct/DedeUserID/access_token/refresh_token 加密存储（flutter_secure_storage）+ Cookie 串解析 |
| 传输 | `services/bilibili/bili_http.dart` | 统一请求：Cookie/UA/Referer/buvid3 注入 + UTF-8 解码 + `BiliApiException` |
| 认证 | `services/bilibili/bili_auth_service.dart` | TV 扫码生成/轮询（android_hd appSign，JSON 返回 token_info+cookie_info）/nav 自检/buvid 预取/退出登录 |
| 状态 | `services/bilibili/bili_account.dart` | ChangeNotifier 单例：登录态/用户信息/WBI 密钥/buvid；启动 `ensureLoaded` |
| UI | `pages/bilibili/bili_login_page.dart` | 扫码登录（Web 码刷新/保存相册/打开哔哩哔哩）+ Cookie 导入 |
| 入口 | `pages/settings/settings_page.dart` + `main.dart` | 「我的」页账号卡片 + 启动 `ensureLoaded` |
| 原生 | `MainActivity.kt` / `AndroidManifest.xml` | `openBilibiliScan`（bilibili:// 深链直接 startActivity）+ `<queries>` 声明 |

**关键决策**：
- **扫码登录对齐 PiliPlus 的 TV 通道**（`mobi_app=android_hd` + appSign，`auth_code`/`poll` 两接口）：
  凭证直接 JSON 返回（`token_info.access_token/refresh_token` + `cookie_info.cookies` 的
  SESSDATA/bili_jct/DedeUserID），**不依赖 Set-Cookie**。access_token 供阶段三 tv playurl 取更高画质。
- **TV 扫码请求头对齐 PiliPlus `getHDcode`/`codePoll` 实际头**（`AnonymousAccount.headers` =
  `Constants.baseHeaders`）：`app-key: android64` + `x-bili-aurora-zone: sh001`，**无 Referer**、
  **非浏览器 UA**（dart:io 默认 `Dart/x (dart:io)`，等同 PiliPlus dio 默认），buvid3 走 Cookie；
  **不是** `app-key: android_hd` + BiliDroid UA + `x-bili-trace-id`/`buvid`（那是 PiliPlus
  短信/密码登录的 `LoginHttp.headers`，扫码不适用），也**不是浏览器 Chrome UA + Referer**
  （可能让 auth_code 返回 Web 式扫码 URL，导致国际版客户端无法确认）。
- **国际版扫码登录（已修复）**：此前国际版客户端扫 TV 码停在「未确认」，两处根因——
  ① TV 扫码请求发了 Chrome UA + Referer（PiliPlus 发非浏览器 UA + 无 Referer），改 `postFormTv`
  逐字节对齐后国际版可确认、poll 拿到 code=0；② 拿凭证后 nav 自检因 `BiliUser.fromJson` 对
  nav 数字字段用裸 `as num?` 强转（字段偶发为字符串）抛「String is not a subtype of num?」导致
  登录被回滚，已改为 `_asInt/_asDouble` 防崩（对齐 `bili_bangumi.dart` 约定）。
- **Web 扫码通道已试过并回滚（2026-09 真机结论）**：Web poll 成功返回的 `data.url` 已是
  ticket 换凭证的 crossDomain 链接（旧文档「SESSDATA 放 query」格式过时）；实测对非浏览器
  HTTP 客户端，crossDomain 302 跳转**响应头无 Set-Cookie**（逐跳手动跟随亦然，仅
  www.bilibili.com 下发 buvid3/b_nut），拿不到 SESSDATA。勿再按旧文档实现 Web 扫码；
  PiliPlus 同样走 TV 通道。
- **轮询防冻结护栏**：poll 到 code=0 但凭证缺失（cookie_info 空）时不静默 cancel 定时器，
  toast「登录凭证获取失败，请重试」并刷新二维码（否则页面冻结无反应）。
- **凭证加密存储**：SESSDATA/bili_jct/DedeUserID + refresh_token 走
  `flutter_secure_storage`（Android = EncryptedSharedPreferences/Keystore，对齐小喵 player），
  永不明文落盘、不打日志；buvid3（设备指纹，非敏感）存 `shared_preferences`。
- **登录态自检 + WBI 密钥**都来自 `GET /x/web-interface/nav` 一次请求；Cookie 过期时 nav
  返回 `isLogin=false`（不报错），据此**静默清凭证回游客态**。
- **扫码轮询**：1 秒轮询，180 秒倒计时自动刷新（服务端 86038 双保险）；
  「打开哔哩哔哩」用 `bilibili://browser?url=…` 深链直接 `startActivity`（未装/无处理者抛
  ActivityNotFoundException → 提示未安装）；「保存相册」用 RepaintBoundary 截图 + `saver_gallery`。
- **Cookie 导入为逃生门**：文本框粘贴解析 `SESSDATA=..; bili_jct=..; DedeUserID=..`，
  风控异常时保住可用性。
- **WBI 混淆表以 64 项为准**：PiliPlus 只保留前 32 项（结果等价）；⚠️ 调研报告 HTML 里的
  混淆表有误（第 28 位起与官方表不符），**以 bilibili-API-collect / Bili23 的 64 项表为准**。
- **反爬指纹完整版（已接入）**：`services/bilibili/bili_fingerprint.dart` 生成/持久化
  `_uuid`/`b_lsid`/`b_nut`/`buvid_fp`（murmur3×64_128，种子 31），拉 `bili_ticket`
  （GenWebTicket HMAC-SHA256），并激活 buvid3（ExClimbWuzhi）；`BiliHttp` 把指纹 Cookie
  片段合并进每个请求的 `Cookie` 头；playurl 额外带 `dm_img_*` 随机参数（对齐 PiliPlus）。
  全部 best-effort，失败不阻断业务（§4.15）。

---

### 4.14 哔哩番剧索引 / 搜索 / 详情（哔哩生态阶段二）

> 调研方案见 `杂项文件/bili-ecosystem-research/`；接入进度见 `docs/哔哩哔哩生态接入状况.md`。
> 阶段二只做「索引 / 搜索 / 详情 / 时间表」；播放、弹幕、OP/ED 章节与清晰度属阶段三（§4.15）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/bili_bangumi.dart` | 索引筛选（filter/value/order）、索引条目/结果、搜索条目/结果、季详情/选集/多季、时间表；`fromJson` 容错（数字字段兼容字符串） |
| 纯函数 | `utils/bili_bangumi_url.dart` | 链接解析：从粘贴文本提取 `ss(\d+)` / `ep(\d+)` / `BV[0-9A-Za-z]{10}` 令牌 |
| 组件 | `widgets/bili_cover_card.dart` | 番剧封面卡片（竖版封面 + 右上角标 + 左下角灰标 + 标题/副标题），索引/推荐/时间表共用 |
| 组件 | `widgets/bili_episode_tile.dart` | 番剧单集磁贴（集号 + 集名 + 胶囊角标），内联选集/全屏选集页共用 |
| 服务 | `services/bilibili/bili_bangumi_service.dart` | condition（type=0）→ 索引 result（type=0）/ 推荐（type=1, order=3）→ season 详情；搜索（WBI）；时间表（番剧+国创合并） |
| UI | `pages/bilibili/bili_index_page.dart` | 番剧首页（PiliPlus `PgcPage` 对齐）：右上角搜索/链接解析 + 追番时间表 + 推荐网格 |
| UI | `pages/bilibili/bili_bangumi_index_page.dart` | 番剧索引页（PiliPlus `PgcIndexPage` 对齐）：多行筛选胶囊 + 封面网格 + 分页 + 折叠/展开动画 |
| UI | `pages/bilibili/bili_season_page.dart` | 详情页：封面（评分角标）+ 信息面板 + 简介 + 多季切换 + 内联选集 + 查看全部 |
| UI | `pages/bilibili/bili_episode_picker_page.dart` | 全屏选集页：30 集分段 + 2 列网格 + 正序/倒序 |
| UI | `pages/bilibili/bili_search_page.dart` | 搜索页：顶部搜索框 + 结果分页，点击进详情 |
| 入口 | `pages/home/home_page.dart` | 速拨「哔哩番剧」→ `BiliIndexPage`（未登录 `BiliAccount.isLogin` 先 toast 提示需登录） |

**关键决策**：
- **页面结构对齐 PiliPlus**：番剧首页 = `追番时间表`（日期 Tab + 横向选集封面卡，番剧 types=1
  + 国创 types=4 两条时间线按日期合并）+ `推荐`（`order=3` 最常追番，封面网格，标题右侧
  「索引」进 `BiliBangumiIndexPage`）；筛选（排序 + 各维度胶囊）放在独立的索引页，多行
  横向滚动、>5 行折叠为「展开/收起」（`SizeTransition` 高度动画，`AnimationController` 250ms easeInOut，展开/收起两侧都平滑过渡），不用弹窗。
- **索引两接口 type 区分**：condition 与索引 result 用 `type=0`（+ `season_type` + 各筛选字段，
  排序值来自 condition 的 `order[]` 动态下发）；推荐网格用 `type=1` + 固定 `order=3` +
  全 `-1` 筛选 + `pagesize=20`（对齐 PiliPlus `pgc.dart` 的两条路径）。
- **封面卡片与网格**：竖版封面（`Expanded` + 网格 `childAspectRatio≈0.58` 得近似 3:4）+
  右上角标（`badge` 主题色）+ 左下角灰标（`order`/放送时间）+ 标题/副标题，索引/推荐/
  时间表三处复用 `BiliCoverCard`；**推荐/索引网格固定 3 列**（`FixedCrossAxisCount(3)`，
  与时间表卡片同尺寸）；追番时间表日期 Tab 与索引筛选胶囊选中态均为**胶囊式**（`borderRadius
  20` / Tab `indicator` 圆角背景）。
- **详情页信息面板**（对齐 `PgcIntroPage` 行结构）：封面 115×153 左下角「评分」角标；右侧
  逐行排：标题 → 播放·弹幕 → 连载状态·话数（`new_ep.desc`，缺失按选集数兜底「共 N 集」）→
  地区·发行时间 → 点赞·投币·收藏（读 `stat.likes`/`coins`/`favorite`）；不再重复展示季名/演员表。
  **简介独立成可展开/收起区**（`TextPainter.didExceedMaxLines` 判定 >3 行才显示「展开」）。
  选集统一用「内联前 12 集（2 列网格）+ 查看全部」：`BiliEpisodeTile` 显示集号 + 集名
  （`long_title` 去重前缀）+ 胶囊角标（会员→VIP 粉、限免→绿、预告→灰），不放封面图；
  「查看全部」进 `BiliEpisodePickerPage`（30 集一段分段 + 2 列网格 + 正序/倒序）。
- **搜索走 WBI 签名**：`search_type=media_bangumi`；mixinKey 复用 `BiliAccount.ensureMixinKey()`
  （游客态 nav 也返回 wbi_img）。签名查询串与 `biliEncWbi` 同一套编码，拼接后直接给 URL。
- **链接解析直达详情**：`ep_id`/`season_id` 都可喂 `/pgc/view/web/season`，`BiliSeasonPage`
  同时接受 `seasonId`/`epId`；BV 号（UGC）走阶段三 UGC 播放（§4.15）。
- **数字字段防崩**：B 站部分端点数字字段以字符串下发，`fromJson` 一律走 `_asInt`/`_asDouble`
  （兼容 num/String），不用裸 `as num?`（历史「type String is not a subtype of type num」崩溃）。
- **选集点击**：解析 playurl 进入播放页（阶段三在线播放，§4.15）。

---

### 4.15 哔哩在线播放 / 弹幕 / 章节（哔哩生态阶段三）

> 阶段三打通「番剧在线播放」：DASH 双流 + 清晰度切换 + B 站原声弹幕（实时 + 缓存）
> + OP/ED 章节跳段，并预防 libmpv 内置 mbedTLS 与 B 站 CDN 的 TLS 兼容问题。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/bili_dash.dart` | playurl DASH 结果：`BiliDashStream`（video/audio 流，兼容 `baseUrl`/`base_url`/`baseUrls[]` 双格式）、`BiliQualityOption`（accept_quality + 描述）、`BiliClipInfo`（OP/ED clip）、`BiliUgcVideo`（bvid→cid） |
| 模型 | `models/bili_media.dart` | 在线播放值对象：当前画质 DASH 流 + cid/aid（弹幕）+ clips（章节）+ `switchQuality(qn)` 回调 |
| 模型 | `models/bili_playlist.dart` | 番剧播放列表：整季剧集（`BiliPlaylistItem` = 原始 `BiliEpisode` + 集号）+ 按 `epId` 定位当前集 |
| 解码 | `services/bilibili/pb/pb_reader.dart` | 手写 protobuf wire 解码（varint + length-delimited，跳过未知字段），弹幕两条消息专用 |
| 服务 | `services/bilibili/bili_video_service.dart` | PGC `/pgc/player/web/v2/playurl`（`result.video_info`）+ UGC `/x/player/wbi/playurl`（`data`）；`fnval=4048/fourk=1` + WBI；bvid→cid；`resolvePgcMedia`（解析 + 构造值对象 + 清晰度回调，启动器与切集共用） |
| 服务 | `services/bilibili/bili_danmaku_service.dart` | 分段弹幕：`/x/v2/dm/web/view`（`dmSge.total` 分段数）→ `/x/v2/dm/web/seg.so`（`elems`）→ `DanmakuEntry`；失败降级 `comment.bilibili.com/{cid}.xml`；XML 缓存 |
| 服务 | `services/bilibili/bili_stream_proxy.dart` | 本地 HTTP 流代理：Dart `HttpClient`（BoringSSL）拉 B 站 CDN，mpv 从 127.0.0.1 明文播放，绕开 mbedTLS；转发 Range |
| UI | `pages/player/player_page.dart` | `PlayerPage` 新增 `biliMedia`/`biliPlaylist`：双流（video + `audio-add`）、更多面板「清晰度」入口、B 站弹幕装载、OP/ED 章节喂入、**「下一集」/列表循环/播放列表面板走剧集列表**（`_switchToBiliEpisode` 重新解析 playurl → 换 `BiliMedia` → 重开双流） |
| UI | `pages/player/views/player_quality_panel.dart` | 清晰度面板：列出 `accept_quality` 档、当前档高亮、点击切换（乐观更新 + 失败回退） |
| UI | `pages/player/views/player_bili_playlist_panel.dart` | 番剧剧集列表面板：集号 + 集名 + 角标（会员/限免/预告）+ 当前集高亮「播放中」+ 打开即滚动定位 |
| 入口 | `pages/bilibili/bili_play_launcher.dart` | 播放启动器：解析 playurl → 构造 `BiliMedia` → push `PlayerPage`（番剧/选集/BV 三处复用）；番剧另带整季剧集列表（详情页/选集页已有则直接传，只有单集信息时并行补拉一次季详情） |

**关键决策**：
- **双流播放（免合并秒开）**：DASH video 流作主媒体，audio 流经 mpv `audio-add` 外挂；
  复用 `openAndRestore` 新增的 `beforePlay` 钩子在 `play()` 前挂音轨，避免开头无声音。
- **mbedTLS 绕过（小喵 player 同源问题）**：本项目自编 `libmpv.so` 静态链接 mbedTLS，
  与部分 B 站 CDN 的 TLS 握手不兼容（小喵 commit 49537c3d 用 OkHttp 本地代理绕过）。
  纯 Dart 复刻为 `BiliStreamProxy`：`HttpClient`（BoringSSL）出站拉流 + `HttpServer`
  监听 127.0.0.1 明文喂 mpv；转发 `Range`/`content-range`/`accept-ranges` 支持拖动；
  播放结束 `dispose` 时 `stop()` 释放端口。**根治方案**见下方「内核重编」。
- **清晰度**：默认请求最高档（`qn=127`，服务端按账户权限回落），可选档来自
  `accept_quality` + `accept_description`；切换档位重新请求 playurl（换 URL 重开 +
  `seek` 保持进度），不做 DASH 动态自适应。
- **弹幕**：REST 分段 protobuf（无需 gRPC/WBI），`progress`(毫秒)→秒、`color`(十进制)→RGB、
  mode 4/5 映射底部/顶部其余滚动；跨分段按 id 去重、按时间升序；落盘 `filesDir/danmaku/
  bilibili/{cid}.xml`（标准 B 站 XML，复用 `parseDanmakuXml`，下载场景可进同名弹幕链路）。
  并发 ≤3 分批，失败降级旧 XML。
- **OP/ED 章节**：来自 playurl 响应的 `clip_info_list`（`{start,end,clipType}`，秒，
  `CLIP_TYPE_OP`/`CLIP_TYPE_ED`），映射 `ChapterInfo`（OP/ED）+ `SkipSegment`
  （intro/outro）喂入 `ChapterTracker.setExternalChapters`（精确起止，不走关键词派生）。
- **番剧播放列表（本轮补齐）**：在线播放此前只传单集，导致「下一集」按钮置灰、
  播放列表面板显示「当前文件夹没有视频」、EOF 不自动连播。对齐 PiliPlus
  `PgcIntroController.nextPlay/prevPlay`——**播放页持有整季剧集列表**，按 `epId`
  定位当前集再前后移动：
  - 列表来源：番剧详情页/选集页已有 `episodes` 时直接构造传入（零额外请求）；
    只有单集信息（链接解析/深链）时启动器与 playurl **并行**补拉一次季详情，
    失败退化为「无列表」（不阻断播放）；
  - 切集走 `_switchToBiliEpisode`：清旧集轨道/章节/跟踪状态 → `resolvePgcMedia`
    重解析 playurl → 换 `BiliMedia`/标题/路径 → `_openBiliMedia` 重开双流
    （代理重新注册 + 弹幕/章节重载）；与本地 `_switchTo` 分开（B 站无本地路径，
    进度恢复/外挂字幕/同名弹幕均不适用）；
  - 竖屏页通过 `biliPlaylist` + `onBiliEpisodeSelected` 回调复用横屏页的切集
    （横屏页持有 `BiliMedia`/流代理/弹幕控制器），回调返回新集 (path,title,epId)
    供竖屏页同步自身 UI；
  - 「列表循环」回第一集、「自动连播」按 `hasNext`、EOF 的 `hasPlaylist` 判定
    均已把剧集列表并入（`_hasAnyPlaylist`）。

**内核重编（OpenSSL 根治 mbedTLS，可选，需在构建机执行）**：
> 本地代理是运行时绕过；若想根治，在 `libmpv-android-video-build`（mk-thumbnail 分支）
> 把 libmpv/FFmpeg 的 TLS 后端从 mbedTLS 换成 OpenSSL 重编 `.so`，替换
> `third_party/media_kit_libs_android_video/android/jars/*.jar` 内的 `libmpv.so`。
> 重编后无需再走 `BiliStreamProxy`（`_registerBiliProxy` 代理失败已自动回退直连）。
> 具体改动点：构建脚本里 mpv 的 `--enable-mbedtls` → `--enable-openssl`（或 FFmpeg
> `--enable-openssl`），并确保 OpenSSL 交叉编译产物被链接；改完用
> `strings libmpv.so | grep -i mbedtls` 验证 mbedTLS 符号消失。

### 4.16 哔哩弹幕 / 视频下载（哔哩生态阶段四）

> 阶段四打通「弹幕下载 + 视频下载」：链接解析（番剧多集 / 视频多分 P）、弹幕批量
> 落盘、视频 DASH 下载 + 原生 MediaMuxer 合并。入口在「我的」页「下载」组。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/bili_dash.dart`（`BiliUgcPage`） | UGC 全部分 P（`pages[]`），老项目只取 `pages[0]`、多 P 视频只下到第一段 |
| 服务 | `services/bilibili/bili_download_service.dart` | 链接 → 可下载条目（番剧 `fetchSeasonDetail` 全集 / UGC `resolveUgcVideo` 全分 P）+ 画质档 |
| 服务 | `services/download/download_settings.dart` | 下载目录单例（ChangeNotifier + SharedPreferences） |
| 服务 | `services/download/download_task.dart` | 任务状态机 + Range 流式下载（进度/速度/续传）+ 弹幕/视频两类执行 |
| 服务 | `services/download/download_manager.dart` | 任务队列 + 并发上限 1（串行防风控）+ 暂停/恢复/重试/删除 + 跨重启持久化 |
| 原生 | `MainActivity.kt` `mergeM4s` + `services/device_services.dart` | MediaExtractor + MediaMuxer 流直拷合并 video.m4s + audio.m4s → mp4 |
| UI | `pages/bilibili/bili_danmaku_download_page.dart` | 弹幕下载：链接输入 + 解析 + 集数/分 P 勾选 + 全选 |
| UI | `pages/bilibili/bili_video_download_page.dart` | 视频下载：清晰度选择 + 同步弹幕开关 + 集数/分 P 勾选 |
| UI | `pages/download/download_manager_page.dart` | 下载管理页：任务列表（紧凑两行排版 + 进度/速度/暂停/恢复/重试/删除 + 清除二次确认） |
| 组件 | `widgets/directory_picker_dialog.dart` | 目录选择器（复用 `listDirectory`，返回真实路径，页面只显示文件夹名） |
| 入口 | `pages/settings/settings_page.dart` | 「我的」页「下载」组（弹幕下载 / 视频下载 / 下载管理） |

**关键决策**：
- **下载目录用真实路径**：App 持有 MANAGE_EXTERNAL_STORAGE，目录选择器返回真实路径、
  直接 `dart:io` 写盘，不走 SAF content:// 流转（弹幕/视频都适用）；页面目录栏只显示文件夹名。
- **视频合并用原生 MediaMuxer**（对齐老项目，不引入 ffmpeg_kit）：MediaExtractor 提流 +
  MediaMuxer 流直拷（`-c copy` 语义、秒级完成）；AV1/杜比视界受系统 MediaMuxer 支持限制。
- **弹幕复用 §4.15 的分段 protobuf 服务**：`fetchDanmaku` 已用 varint 读 tag，规避老项目
  「多字节 tag（field≥16）解析错位 → 时间戳集中到同一秒」的坑（老项目修复见
  mpv-android-anime4k commit `e3a913b7`）。
- **并发串行防风控**：下载管理器并发上限 1，全选时按集数顺序一集一集下（FIFO），避免并发视频下载触发风控。
- **清晰度选择为老项目缺失能力**：下载前按 `accept_quality` 选画质，**横向可滚动单行、默认「高清 1080P」**。
- **同步下载弹幕开关**：视频下载页让用户自选是否顺带抓同名 XML 弹幕（默认开）。
- **下载记录跨重启持久化（工作.md 第 2 点）**：`DownloadManager` 把任务列表（状态/进度/产物路径）
  序列化到 SharedPreferences，`ensureLoaded`（main.dart 启动调用）恢复；重启前 pending/downloading/
  merging 的任务归位为 paused（不自动续跑），completed/failed 记录保留。进度每 500ms 刷新但只在
  「状态变化」时落盘（避免高频全量序列化）。
- **下载前路径校验（工作.md 第 3 点）**：`DownloadSettings.directoryExists` 检查真实路径是否仍在
  磁盘；弹幕/视频下载页点「下载」时若目录被删，toast 提示并弹出目录选择器，避免「开始下载才失败」。
- **下载产物媒体扫描（工作.md 第 5 点）**：合并/改名落盘后调用原生 `scanMediaFile`
  （`MediaScannerConnection.scanFile`），让 MediaStore 立即抽取时长/分辨率；`getVideos` 另对
  duration==0 的文件用 `MediaMetadataRetriever` 兜底抽时长——否则下载视频在列表里显示「未观看」。
- **UGC 支持 BV / av / b23.tv 短链（工作.md 第 8 点）**：`parseBiliBangumiUrl` 识别
  `av(\d+)`，`resolveUgcVideo` 支持 aid 通道（`/x/web-interface/view?aid=`）；分享短链
  不含令牌，`utils/bili_short_link.dart` 从**任意分享文本**正则提取（App 复制出来是
  `【标题】 https://b23.tv/xxx`，不能按整串 startsWith 判定；裸短链自动补 https，
  对齐小喵）再手动跟随 302 展开（命中令牌即停、不下载整页），
  `BiliDownloadService.resolveRef` 与番剧首页解析弹窗共用；番剧与用户视频均可解析下载。
- **UP 主合集（ugc_season）接入**：`BiliUgcVideo` 解析 view 接口的 `ugc_season`
  （章节→集→分P 全集）；BV 属于合集时下载页展开**整部合集**（多章节标题带 `[章节]` 前缀、
  多分P集展开到每 P）；合集列表链接 `space.bilibili.com/{mid}/lists/{season_id}` 经
  `seasons_archives_list` 取任一成员 bvid 后再借 view 接口拿全量（对齐 Bili23）。
- **单连接流式 + Range 续传**：未做调研里的 4–8 路分块并发（吞吐受限）。
- **登录门禁**：「我的」页弹幕下载 / 视频下载入口先校验 `BiliAccount.isLogin`，
  未登录 toast「需要登录哔哩哔哩账号」不进入（与首页速拨「哔哩番剧」一致）。

---

### 4.17 播放历史 / 外部打开视频 / 打开链接（系统播放器接入）

> 三项能力：① 本项目注册为系统视频播放器（其他 App「打开方式」可选本项目）；
> ② 播放历史记录（首页速拨「最近播放」直启 + 「我的→播放→历史记录」管理）；
> ③ 首页速拨「打开链接」输入直链在线播放（对齐 mpvRx——直链直接交给 mpv，
> 章节信息由 mpv 解封装远程容器原生读取，无需网站接口）。

**播放历史**（`PlaybackHistoryService` 单例 ChangeNotifier + SharedPreferences 单键 JSON）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/playback_history_entry.dart` | 条目（path/title/isUrl/playedAtMs/durationMs）+ toJson/fromJson 容错 |
| 服务 | `services/playback_history_service.dart` | 记录（同 path 去重置顶）/上限 500 淘汰最旧/删除单条/清空/开关/时长回填，`ensureLoaded`（main.dart） |
| 记录点 | `pages/player/player_page.dart` | `_recordPlaybackHistory`（open 与切集时记录）+ `_saveProgress` 内时长回填 |
| UI | `pages/settings/playback_history_page.dart` | VideoCard 条目（**固定只显示进度字段**——历史读不到文件大小，不展示大小/时长）+ **右侧垃圾桶按钮删除单条** + 清空二次确认（showAppDialog）+ 记录开关 |
| 入口 | `widgets/speed_dial_fab.dart` + `home_page.dart` + `settings_page.dart` | 速拨「最近播放」直启最后一条（进度自动恢复）；「我的→播放→历史记录」 |

**关键决策**：
- **只记录可重放来源**（用户拍板）：本地真实路径 + 在线直链；loopback 代理 URL
  （网络存储 `127.0.0.1` 流，退出即失效）与哔哩哔哩在线播放（需登录态重新解析
  playurl）**不写入**——B 站走 `_biliMedia` 分支天然跳过，loopback 由
  `_recordPlaybackHistory` 前缀过滤。
- 关闭记录只停新写入，已存历史保留可查看/删除（开关不隐含清空）。
- 时长记录两段式：open 时能从播放列表 MediaStore 拿到就先记，否则退出时
  `_saveProgress` 回填（历史条目显示时长徽标与进度条的依据）。

**外部打开视频（注册系统播放器）**：

| 层 | 文件 | 职责 |
|---|---|---|
| 注册 | `AndroidManifest.xml` | MainActivity 加 VIEW intent-filter（对齐 mpvRx）：**①scheme(content/file/http/https)+视频 MIME 同一过滤器**（外部播放器以 `URL+video/*` 查询；⚠️ 只声明 MIME 不声明 scheme 的过滤器 scheme 默认仅 content/file，匹配不到 http 直链——「外部播放器列表没有本应用」的根因）、②仅 MIME（发现查询）、③rtmp/rtsp/mms 等流媒体 scheme、④http/https+视频扩展名 pathPattern |
| 原生 | `MainActivity.kt` | `handleViewIntent`（onCreate/onNewIntent 暂存 ACTION_VIEW 视频 uri；MIME 判定含注册的 application/* 容器类型——mkv/m3u8 的 MIME 不以 video/ 开头）+ `takeExternalVideo`/`resolveVideoUri` 通道方法；content:// 三级解析（MediaStore DATA 列 → DocumentsProvider documentId → 拷贝 cacheDir/external_open/） |
| 服务 | `services/device_services.dart` | `takeExternalVideo`/`resolveVideoUri` 封装 + `onExternalVideo` 回调（原生 onNewIntent 推送） |
| 装配 | `main.dart` | `navigatorKey` + App 顶层消费（首帧后取冷启动 intent；`onExternalVideo` 取热启动）→ push `PlayerPage`；widgets/ 层不 import pages/ 故挂在此 |

**打开链接**：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/url_media.dart` | `normalizeMediaUrl`（裸域名补 https；含空白拒绝；`scheme:` 形态不补——补了会把 scheme 错位成 userinfo）/ `isPlayableMediaUrl`（mpv 协议白名单 http/https/rtmp/rtmps/rtsp/rtsps/rtp/mms/mmst/mmsh/ftp）/ `mediaTitleFromUrl`（末段路径解码 → host 兜底） |
| UI | `pages/home/open_link_dialog.dart` | 速拨「打开链接」弹窗：输入 + 粘贴按钮 + 行内校验提示，确认**先关弹窗再回调**（见 §7 pop 顺序坑） |
| 网速 | `player_status_bar.dart` + 两播放页 | 直链播放不走本地代理，状态栏两个代理查询均 null → 兜底读 mpv `cache-speed`（`directNetSpeedReader` 闭包，横竖屏播放页各传一份；直链/HLS/DASH 通吃） |
| 播放 | `home_page.dart` | push `PlayerPage(path: url)`；章节由现有 `_chapterTracker.load()`（mpv chapter-list）对远程容器原生读取 |

### 4.18 投屏（DLNA/UPnP，P0 仅本地文件推流）

> 调研见 `杂项文件/参考项目/投屏功能调研文档.md`；P0 只做「DLNA 发现 + 本地文件
> 推流（仅推流）」，不做遥控/进度回传/Chromecast/转码/在线直链（留 P1+）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/cast_source.dart` | 源分类（本地/直链/loopback/content）+ `file://` 去前缀 + loopback 主机判定 |
| 服务 | `services/cast/lan_media_server.dart` | 本地文件 → `http://<LAN_IP>:<port>/<token>`（绑 0.0.0.0 + Range + CORS + token），复用 `HttpByteRange`/`networkMimeTypeForFileName`；`isSiteLocalIpv4` 挑站点本地 IPv4 |
| 服务 | `services/cast/cast_service.dart` | SSDP 发现（dlna_dart `DLNAManager`）+ 按 `deviceType` 过滤 MediaRenderer + `setUrl/play` 推流；`resolveUrl` 仅本地文件 |
| 模型 | `models/cast_device.dart` | 渲染器设备模型（id/设备名/设备类型） |
| UI | `widgets/cast_device_dialog.dart` | 设备选择弹窗（进入即发现，列表点选推流，关闭停发现） |
| 入口 | `models/player_action.dart` + `player_page.dart` / `player_portrait_page.dart` | `PlayerTopAction.cast`（投屏）：可加至顶栏槽位/「更多」，点击时仅本地文件可投、其余 toast 提示 |

**关键决策**：
- **选型**：dlna_dart（纯 Dart，Kazumi 同款）+ 自研 LanMediaServer（本地文件局域网暴露），
  对齐 mpvRx CastMediaServer 的「0.0.0.0 + token + Range + CORS」。
- **源分流**：P0 仅本地文件（绝对路径 / file://）；loopback 代理 URL（网络存储 / B 站）、
  content:// 与在线直链点击时 toast「暂不支持投屏该来源」，在线直链留 P1。
- **仅推流**：只 `SetAVTransportURI → Play`，投屏后不暂停手机、不回传进度/遥控（P0）。
- **服务器生命周期**：expose 前 stop 旧的；投屏成功后服务器保持运行供电视拉流，
  由横屏播放页 `dispose` 统一 `LanMediaServer.instance.stop()` 释放端口。
- **权限**：AndroidManifest 补 `ACCESS_WIFI_STATE` / `CHANGE_WIFI_MULTICAST_STATE`
  （SSDP 多播发现，normal 权限）。

---

### 4.19 隐私政策（首次启动门禁 + 关于页用户协议）

> 工作.md：首次安装打开弹出隐私弹窗（5 秒倒计时 + 勾选同意才可确认，取消退出）；
> 关于页「用户协议」并入「信息」组（预览用户服务协议与隐私政策正文，仅内容无同意交互）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 正文 | `services/privacy_policy_content.dart` | 两份纯常量文案：`kPrivacyPolicyBody`（隐私政策）、`kUserAgreementBody`（服务协议+隐私政策），唯一文案来源 |
| 状态 | `services/privacy_policy_settings.dart` | 同意状态 `accepted`（ChangeNotifier + SharedPreferences，默认 false） |
| 门禁弹窗 | `widgets/privacy_policy_dialog.dart` | 5 秒倒计时 + 勾选同意才可确认；不同意退出；不可点遮罩/返回键关闭 |
| 门禁装配 | `main.dart` | runApp 前 await `ensureLoaded`；首帧 `_onFirstFrame` 先确认隐私再消费外部视频；取消 `SystemNavigator.pop()` |
| 页面 | `pages/settings/privacy_policy_page.dart` | 用户协议页（仅正文可选中复制，无同意交互） |
| 入口 | `pages/settings/about_page.dart` | 关于页「信息」组内「用户协议」项（许可证书下方） |

**关键决策**：
- **同意状态在 runApp 前加载**：`main()` await `ensureLoaded`，否则首帧读到的默认 false
  会让已同意用户再次弹窗。
- **门禁弹窗不可关闭**：`showAppDialog(barrierDismissible: false)` + 内容包
  `PopScope(canPop: false)`；确认按钮 `enabled = 倒计时归零 && 勾选同意`。
- **倒计时文本防换行**：确认按钮文本包 `FittedBox(scaleDown)`，倒计时期间「同意并继续 (n 秒)」
  不换行、不把文本顶高。
- **取消退出**：`SystemNavigator.pop()`（Android 结束 Activity），再次启动仍会弹窗（未同意）。
- **两版文案**：首次弹窗用《用户隐私政策》；关于页用《用户服务协议与隐私政策》（含服务协议 + 隐私政策两部分）。
- **外部打开视频让位于门禁**：`_consumePendingExternalVideo` 未同意时直接返回，
  防外部拉起把播放页盖过隐私弹窗。

---

### 4.20 应用更新（入口 + 更新弹窗）

> 工作.md：我的→关于→「更新」组（手动检查更新 + 自动检查更新开关）；
> 更新弹窗用 flutter_markdown 渲染 GitHub Release 的 Markdown 正文，三个按钮
> （立即更新 / 稍后提醒 / 忽略），点「立即更新」出主 / 备用下载站子菜单。
> 更新源（GitHub API）与主·备下载链接已就绪，version.json 兜底未配置（留空）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/update_info.dart` | `UpdateInfo`（version / Markdown body / 主·备下载站链接） |
| 纯函数 | `utils/version_compare.dart` | `needUpdate(local, remote)`：忽略 v 前缀、按 `.` 逐段整数比较 |
| 设置 | `services/update/update_settings.dart` | `autoUpdateEnabled`（默认开）+ `ignoredVersion`，ChangeNotifier + 持久化 |
| 服务 | `services/update/update_service.dart` | 更新源/下载链接常量 + `checkForUpdate()`（抓 GitHub API → `needUpdate` 比较，失败抛 `UpdateCheckException`） |
| 弹窗 | `widgets/update_dialog.dart` | 固定尺寸 + 可滚动 Markdown + 三按钮 + 下载站子菜单 |
| 入口 | `pages/settings/about_page.dart` | 「更新」组（手动检查更新 / 自动检查更新开关） |
| 装配 | `main.dart` | runApp 前 await `ensureLoaded`；隐私同意后 2 秒自动检查（开关开启且未忽略才弹） |

**关键决策**：
- **版本比较对齐 Kazumi**：`needUpdate` 逐段整数比较，替换旧的「版本号后两位 ×10 + 位宽」算法；
  支持 `v` 前缀、缺段补 0、非数字段取数字前缀。
- **检查更新真实抓取**：`checkForUpdate` 取本地版本（`package_info_plus`）→ 抓 GitHub API
  `releases/latest` 的 `tag_name`/`body`（失败按需回落 version.json）→ `needUpdate` 比较：
  远端 > 本地返回 `UpdateInfo`、否则返回 null（已是最新）、网络/解析失败抛
  `UpdateCheckException`；手动检查失败 Toast、自动检查失败静默。`tag_name` 前导 `v` 归一化去掉。
- **Markdown 渲染**：`flutter_markdown`（`MarkdownBody`）+ `MarkdownStyleSheet.fromTheme`
  定制字号/引用块样式，消除原生 `##`/`**`/`-` 符号。
- **三按钮语义**：立即更新 → 子菜单（主/备用下载站，链接待接入时 Toast）；稍后提醒 → 仅关闭；
  忽略 → 写 `ignoredVersion`，自动检查不再弹该版本（手动检查不受影响，保证开发期可反复验收）。
  三按钮文本包 `FittedBox(scaleDown)`，防窄屏「立即更新」换行。
- **下载不内置**：不做应用内下载，走「跳转网盘分享页」；主 / 备用下载站链接空时 Toast「链接待接入」。
- **自动检查 2 秒**：`main.dart` 隐私同意后 `Future.delayed(2s)` 检查；开关关闭或已忽略则跳过。

---

### 4.21 影视字幕下载（Wyzie 字幕源）

> 工作.md：我的→下载组→「字幕下载」（副标题「影视字幕下载」）。关键词搜索影视
> 字幕并批量下载到目录，提供商 Wyzie（sub.wyzie.io，对齐 mpvRx `WyzieSearchRepository.kt`）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/wyzie_models.dart` | 字幕条目/来源响应/密钥信息/TMDB 命中（fromJson 容错）+ 语言/格式/编码/来源常量表 |
| 纯函数 | `utils/wyzie_query.dart` / `wyzie_filename.dart` | 来源/逗号参数拼接 + 客户端语言过滤 / 落盘文件名清洗 + 同批消重 |
| 设置 | `services/wyzie/wyzie_settings.dart` | API 密钥 + 来源/语言/格式/编码（ChangeNotifier + SharedPreferences，默认 en+zh / srt+ass / utf-8） |
| API | `services/wyzie/wyzie_api.dart` | `/sources`、`/api/tmdb/search`、`/search`、文件下载；UTF-8 解码 + 400 无字幕特判 + 错误语义化 |
| UI | `pages/subtitle/subtitle_download_page.dart` + `subtitle_settings_page.dart` + `views/subtitle_settings_section.dart` | 下载页（字幕设置入口 + 关键词「确定」搜索 + 结果勾选批量下载）+ 设置子页五入口；来源弹窗动态拉取（免费/付费分组） |

**关键决策**：
- **来源免费/付费分组**：`/sources?key=` 返回 `tiered[]`（`tier`=free/paid），弹窗按
  「全部 / 免费来源 / 付费来源」分组多选；拉取失败回退静态来源表（charlie/lima 免费，其余付费）。
- **关键词→媒体 ID**：tt 号 / 纯数字 id 直用，否则先 `/api/tmdb/search` 取首个命中再
  `/search`（对齐 mpvRx）；客户端再按所选语言过滤（接口常无视 language 参数返回全语言）。
- **下载独立直下**：字幕为通用文件直链且体积小，`fetchBytes` 一次读回内存落盘到下载
  目录，**不进 B 站 DownloadManager**（`DownloadTask` 为 B 站专用）；文件名
  「媒体名.语言.格式」+ 同批消重（`uniqueFileName`）。
- **密钥与获取链接**：密钥存 SharedPreferences（非敏感，明文）；「如何获取密钥」跳
  `_getKeyUrl`（飞书文档教程：获取 WYZIE API 密钥的步骤说明）。
- **复用下载目录**：目录沿用 `DownloadSettings`（与视频/弹幕下载共用同一文件夹设置）。
- **设置收敛到子页**：五项字幕设置从下载主页收敛为单个「字幕下载设置」入口，点击进
  `SubtitleSettingsPage` 子页；下载目录栏置于输入框下方（对齐视频/弹幕下载页，去掉
  分组标题），结果条目元数据（语言/来源/格式）以胶囊标签呈现。
- **密钥门禁**：搜索前校验 `WyzieSettings.apiKey` 非空，未设置则 toast
  「请先设置 WYZIE API 密钥」并中止（关键词输入后点「确定」即触发）。

---

### 4.22 章节跳段（有章节视频的自动跳过 + 自定义关键词）

> 与「片头片尾按秒跳过」（§4.1 `IntroOutroSettings`，给无章节视频用）是两套机制。
> 本机制针对**有章节信息**的视频：把章节标题按关键词分类成六类片段，在进度条上
> 标记色段并支持手动跳过（§4.6 章节圆点/色段/胶囊），本新增补上**自动跳过**与
> **用户自定义关键词**。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/chapter_info.dart` | `ChapterSkipType` 六类（intro/recap/outro/credits/coldOpen/preview）+ 片段 |
| 纯函数 | `utils/chapter_utils.dart` | `parseCustomKeywords` + `classifyChapterTitle`（内置+自定义关键词） + `resolveSkipSegments` |
| 设置 | `services/chapter_skip_settings.dart` | 六类自动跳过开关 + 自定义片头/片尾关键词（ChangeNotifier + SharedPreferences） |
| 跟踪 | `services/chapter_tracker.dart` | 订阅设置、`load`/设置变化时按自定义关键词重派生片段、位置流进入片段时自动 seek |
| UI | `views/player_chapter_panel.dart` + `player_chapter_skip_panel.dart` | 章节列表顶部固定「章节跳段」入口 → 二级面板（六类开关 + 两个关键词输入框） |

**关键决策**：
- **关键词归属由用户填写位置决定**（回答「AP 属于片头还是片尾」）：填进「片头关键词」
  即并入片头匹配、填进「片尾关键词」即并入片尾；同一标题命中多类时按固定优先级
  「前情提要 > 正片前段 > 制作人员 > 下集预告 > 片尾(且非片头) > 片头」取一类。
- **自动跳过每片段每会话只跳一次**：进入片段若其类型开启自动跳过且未在
  `_skippedSegments`，则 seek 到片段结束（EOF 保护沿用 `skipSeekTarget`）；回拖进
  同一片段不再重复跳，改为弹出手动胶囊（用户主动回看不被打断）。
- **入口不动「更多」**：复用现有「更多 → 章节」面板，在其顶部固定一行「章节跳段」，
  点入二级面板（面板内 `push` 就地切换，§4.5）。
- **设置变化即时生效**：`ChapterTracker` 构造订阅 `ChapterSkipSettings`，变化即重派生
  片段并清空已跳过记录（不改关键词到片段的热更新无需重开播放器）。

---

### 4.23 音量增强 (Volume Boost) + 杜比视界偏色检测

> 工作.md 迁移功能：两处从小喵老项目/mpvRx 补齐的能力。音量增强解决「低电平动漫声音小」
> 痛点；杜比视界检测解决「播放杜比视界未开 gpu-next 画面发绿发紫却不知所措」的痛点。

**音量增强（Volume Boost）**：

| 层 | 文件 | 职责 |
|---|---|---|
| 设置 | `services/player_controls_settings.dart` | `volumeBoostEnabled`（默认关）+ `volumeBoostCap`（百分比 10%~100% 步进 10 默认 60，§4.1）；`_roundVolumeBoostCap` 就近对齐 10% 档 |
| 纯函数 | `utils/player_gestures.dart` | `mpvVolumeMaxForBoost`（=100+cap）、`displayVolumePercent`（110%~200%）、`isVolumeBoosting` |
| 播放页 | `pages/player/player_page.dart` | `_initDeviceState` 设 `volume-max=100+cap` + `_mpvVolume=100`；`_onVerticalSwipe` 右半屏满 100% 后接管 mpv 音量（上滑续增/下滑回减/触底降系统）；退出复位 mpv 100 |
| 指示器 | `views/player_gesture_indicator.dart` | `boosting` 态：红色图标/文字 + `graphic_eq` 图标 +「音量增强」标签，显示 110%/150%/200% |
| 设置页 | `pages/settings/player_settings_page.dart` | 「播放行为」组最后一项（开关 + 可折叠上限滑杆，`AnimatedSize` 收起/展开） |

**杜比视界（Dolby Vision）偏色检测与引导**：

| 层 | 文件 | 职责 |
|---|---|---|
| 原生 | `MediaInfoHelper.detectDolbyVision` | MediaInfo 扫视频轨 HDR_Format/CodecID/Format 命中 dovi/dvhe/dvav/Dolby Vision |
| 服务 | `services/video_info_service.dart` `detectDolbyVision` | MethodChannel 封装，返回 (isDolbyVision, hdrFormat) |
| 设置 | `services/dolby_vision_settings.dart` | 「不再提示」`suppressed` 记忆（ChangeNotifier + 持久化，§4.1） |
| 播放页 | `pages/player/player_page.dart` `_checkDolbyVision` | 本地文件 open/切集后测一次：杜比视界且未开 gpu-next 且未抑制 → `showAppDialog` 引导（可知/不再提示），`_dolbyVisionChecked` 防重复 |

**关键决策**：
- **音量增强语义用百分比而非 dB**：mpv `volume` 属性本就是百分比刻度（`volume-max` 默认 130
  即最高 130%），mpvRx 把 `volumeBoostCap` 当「dB」是命名误导；本项目直接 `volume-max = 100 + cap`
  （cap 为百分比），上限 100%（最高 200%），语义与 mpv 刻度一致、对用户直观。
- **增强接管条件**：系统音量（`setSystemVolume`）到 100 且增强开启时才把超额位移转 mpv 音量；
  下滑先回退 mpv 增益、触底 100 再降系统音量；退出播放 mpv 音量复位 100 防泄漏（§4.8）。
- **上限滑杆折叠**：关闭开关时 `AnimatedSize` 收起滑杆，组内更整洁；开启时展开（§4.1 播放行为组）。
- **杜比视界仅本地文件检测**：MediaInfo 需真实路径，在线直链/B 站跳过；每集只测一次
  （`_dolbyVisionChecked` 随切集重置）。
- **引导时机**：已开 `gpuNext` 直接跳过（软解路径无偏色问题）；「不再提示」勾选后持久化，
  后续相同情况不再弹（除非清除偏好）。

---

### 4.24 设备硬件与编解码能力检测 + 解码一键重启

> 工作.md 迁移功能：设备能力检测页对齐 mpvRx（`CodecCapabilitiesScreen`）与老项目
> `DeviceInfoScreen`；解码配置修改后一键整应用重启对齐老项目 `PlaybackSettingsScreen`。

**设备能力检测**：

| 层 | 文件 | 职责 |
|---|---|---|
| 原生 | `DeviceCapabilities.kt` | `inspect()`：屏幕 HDR（`Display.getHdrCapabilities`）+ 关键编码器（H.264/H.265/AV1/VP9/杜比视界 硬/软解）+ 系统全量解码器清单（name/canonicalName/mimeType/formatName/isHardware/isAlias/媒体类型/最大·最小分辨率/最大声道/最大实例/对齐/码率/色彩格式/特性/采样率/profile(level)/HDR 支持） |
| 纯数据 | `models/device_decoder.dart` | `DeviceDecoderEntry`（fromMap 容错） |
| 服务 | `services/device_services.dart` `getDeviceCapabilities` | MethodChannel 封装，失败返回 null |
| 页面 | `pages/settings/device_info_page.dart` | 设备信息 + 屏幕 HDR 能力 + 关键编码器 + 解码器清单（筛选胶囊两行布局：第一行 音频/硬解/软解/视频 等宽均分，第二行「全部」独占整行对齐；搜索；点条目进详情） |
| 详情页 | `pages/settings/decoder_detail_page.dart` | 单解码器完整能力分卡片呈现（基本信息/分辨率与能力/音频能力/硬件特性/采样率/色彩格式/Profile Level） |
| 入口 | `pages/settings/settings_page.dart` | 「我的 → 其他 → 设备信息」 |

**解码一键重启**：

| 层 | 文件 | 职责 |
|---|---|---|
| 原生 | `MainActivity.kt` `restartApp` | 拉 `getLaunchIntentForPackage` + `FLAG_ACTIVITY_NEW_TASK|CLEAR_TASK` + `killProcess`（整应用重启） |
| 服务 | `services/device_services.dart` `restartApp` | MethodChannel 封装 |
| 解码面板 | `views/player_decode_panel.dart` | `_setMode`/`_setPreset` 改档后 `showAppDialog` 弹「需重启应用」，立即整应用重启 / 稍后重启（改动已持久化） |

**关键决策**：
- **筛选胶囊两行布局 + 无数字**：胶囊只显示「音频/硬解/软解/视频/全部」纯文本（不显示数量），
  「全部」用 `double.infinity` 撑满与上一行四个等宽胶囊总长对齐（`StadiumBorder` 胶囊样式）；
  数量统计保留在清单卡头「硬解 X · 软解 Y · 视频 Z · 音频 W」。
- **详情用「点进新页面」而非 mpvRx 的就地展开**：用户拍板跳转详情页（`DecoderDetailPage`），
  每行加 chevron 提示可点；accompanied 字段与 mpvRx `CodecDetailCard` 展开内容对齐（profile/level、
  色彩格式、特性、采样率、分辨率/位率/对齐/实例等）。
- **解码重启为整应用重启**：解码方式（hwdec）/预设（profile）在 mpv `open` 前注入、重开视频才生效，
  但用户要求「整应用重启」，故 `restartApp` 拉新 Task 清栈 + 杀进程；「稍后重启」仅关弹窗
  （改动已写盘，下次启动/重开视频生效）；`exitProcess` 需 `import kotlin.system.exitProcess`。
- **原生长时间能力扫描放后台线程**：`getDeviceCapabilities` 在 `Thread` 里跑 `MediaCodecList`
  遍历 + `getCapabilitiesForType`（厂商解码器可能较慢），结果 `runOnUiThread` 回传，不阻塞 UI。

---

### 4.25 Anime4K 着色器安装期优化（mediump 注入 + 采样合并）

> 借鉴 mpvRx `Anime4KManager.optimizeShaderContent`：**运行期零成本**，
> 只在首次把 `assets/shaders/*.glsl` 拷进沙盒时改写一次源码。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/anime4k_patch.dart` | `optimizeAnime4kShader(fileName, content)`：pass 切分 + 精度注入 + C.R.E.L.U. 采样合并（可单测） |
| 服务 | `services/super_resolution_service.dart` | `_ensureShadersCopied()` 改为「读 assets 文本 → 改写 → 写入」，并用 `.patch_version` 记录补丁版本 |

**关键决策**：
- **为什么要注入精度限定符**：Adreno 等移动驱动在检测到 `mat4` × float 字面量时会把默认
  mediump **静默提升回 FP32**，忽略文件里的 `precision mediump float;` 头——只有写在
  每个变量声明上的**显式**限定符拦得住。CNN 卷积/边缘滤镜在 FP16 下数值安全且明显更快。
- **FSR 类 pass 保持 highp**：依赖位运算（`floatBitsToUint`/`uintBitsToFloat`）与近似
  倒数/平方根（`APrxLoRcpF1` 等）的 pass 在 FP16 下产生垃圾值，按 `kAnime4kFp32Markers`
  白名单整块保持 `highp`（含 `precision highp int;`，整数位技巧不能降精度）。
- **C.R.E.L.U. 采样合并**：只在同一 pass 同时存在 `go_0`（`max(tex)`）与 `go_1`（`max(-tex)`）
  且引用**同一纹理**时，把 9 次重复采样合并成 3×3 预取；偏移超出 {-1,0,1} 时**整体退回原
  pass**（否则会引用未声明的 `t_unknown_*`，整个着色器编译失败被 mpv 丢弃）。
- **幂等 + 版本化**：算法改动必须 bump `kAnime4kPatchVersion`——服务层比对
  `.patch_version`，不一致才重新拷贝+重写（否则老用户沙盒里仍是旧着色器，改了等于没改）。
- **与参考实现的差异（有意）**：mpvRx 在 `//!` 头后遇到**空行**即放弃该 pass 的注入，而本
  项目全部着色器头与正文之间都留空行——照抄会导致一个 pass 都注入不上；这里把空行当作
  头部间隙继续找首个正文行。pass 边界用 `//!DESC`（缺失时回退 `//!HOOK`），避免把
  「头 + 正文」拆成两块。

---

### 4.26 mpv 移动端缓存/网络调参模板

> 借鉴 mpvRx `MPVView.initOptions` + Kazumi 的「在线加大缓存」：本地/在线两档，
> 在 **open 之前**写入（解封装缓存与重连参数只在打开文件时生效）。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/mpv_tuning.dart` | `buildMpvTuning(isOnline, existingDemuxerLavfO)` + `mergeDemuxerLavfOptions` + `splitLavfOptions`（顶层逗号切分） |
| 播放页 | `pages/player/player_page.dart` | `_applyPlaybackTuning(path)`：读旧 `demuxer-lavf-o` → 生成调参表 → 逐项 `setProperty`；三处调用（首开/切集/B 站） |

**写入项**（两档共同）：`video-sync=audio`（24fps@60Hz 不再周期性抖动）、`framedrop=vo`
（只丢已晚于显示窗口的帧，防抖动累积）。
**仅在线**：`cache=yes` / `cache-pause=yes` / `cache-pause-wait=2`、`network-timeout=15`
（media_kit 默认 5s 对弱网过于激进）、`demuxer-max-bytes=64MiB` /
`demuxer-max-back-bytes=32MiB`（本地为 32MiB/32MiB）、`http-allow-redirect=yes`、
`hls-bitrate=no`（HLS 自适应码率，不强制最高档）、`demuxer-lavf-o` 合并有界重连。

**关键决策**：
- **`demuxer-lavf-o` 必须合并而不是覆盖**：media_kit 初始化时已写入
  `protocol_whitelist=[udp,rtp,...]`（值内含逗号），整串覆盖会让 m3u8/自定义协议失效；
  读不到旧值时**宁可不写该键**（`mergeDemuxerLavfOptions` 返回 null）。
- **明确不用 `reconnect_at_eof`**：合法 VOD 的 EOF 必须正常结束，否则播完会一直重连、
  永远不触发「播放完毕」（mpvRx 同款决策）。其余重连参数有界（`reconnect_max_retries=5`、
  `reconnect_delay_total_max=20`）。
- **本地/在线分档**：复用 `isOnlineMedia(path)` 判定；切集时来源可能从本地切到在线，
  所以调参在**每次 open 前**重写，而不是只在 initState 写一次。

---

### 4.27 播放器诊断页（运行时统计）

> 借鉴 mpvRx `Actionable Player Diagnostics`：把「缓存/丢帧/渲染延迟/硬解/音画同步」
> 直接摆在面板里，排障不再靠猜。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 模型 | `models/player_diagnostics.dart` | `PlayerDiagnosticsSnapshot.fromProperties(Map<String,String?>)`（容错解析，数字兼容字符串） |
| 纯函数 | `utils/player_diagnostics.dart` | `kPlayerDiagnosticsProperties` 属性清单 + 格式化（字节/码率/网速/秒/毫秒/帧率/分辨率/avsync）+ `diagnosticsWarnings` 健康判定 |
| 面板 | `pages/player/views/player_diagnostics_panel.dart` | 每秒采样 + 四组卡片（播放/视频/音频/缓存与丢帧）+ 顶部告警卡；属性读取由页面注入（可测） |
| 入口 | `models/player_action.dart` + 横竖屏播放页 | `PlayerTopAction.diagnostics`（「更多」/顶栏槽位；横屏 `showPlayerPanel`、竖屏 `showPlayerBottomPanel`，§4.5） |

**关键决策**：
- **为什么不用 mpv 自带的 stats 页**（调研问题）：mpvRx 的「7 页统计」= mpv 内置
  `stats.lua` 的 1–5 页（`script-binding stats/display-page-N`）+ mpvRx 自己的第 6 页
  Compose 覆盖层 + 第 7 页 = mpv 内置 `console.lua`（控制台）。**本项目的自编 libmpv
  没有编译 Lua**（`libmpv.so` 里只有默认 input.conf 引用的 `stats.lua`/`console.lua`
  字符串，没有任何 Lua 运行时符号），所以 `script-binding stats/...` 会静默无反应。
  结论：**照搬 mpvRx 的做法不可行**，改为在 Dart 侧读 mpv 属性自建诊断页（这也是调研
  清单 A5 给出的落点）。若将来要 mpv 原生 stats 页，需在构建机给 libmpv 开
  `--enable-lua` 并随包分发脚本。
- **属性读取容错**：逐个属性 try/catch，单个属性不支持只置 null（面板显示 `—`），
  不影响其余字段；非 `NativePlayer` 平台返回空表。
- **健康提示只讲结论**：`diagnosticsWarnings` 把「丢帧 / 渲染延迟 >20ms / 软解 /
  音画不同步 >100ms / 时间戳异常」翻译成人话，顶部红卡直出（排障先看结论再看数字）。
- **每秒采样 + 防重入**：`Timer.periodic` + `_reading` 标志，避免慢查询叠加；
  面板 `dispose` 取消定时器。

---

### 4.28 统一网络重试 / 超时分级 / 内容嗅探快速失败

> 借鉴 PiliPlus `retry_interceptor.dart`（只重试连接类失败、流式不重试）+ Kazumi 的
> 超时分级与「文本响应超 2MB 主动取消」。

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯工具 | `utils/retry_policy.dart` | `NetworkTimeoutTier` 四档超时、`isRetryableNetworkError`、`retryDelayForAttempt`、`withRetry`、`readBodyCapped`/`drainStreamCapped`、`sendGet`/`fetchTextCapped`/`fetchBytesCapped` |
| 调用方 | `services/bilibili/bili_http.dart`、`services/dandan_play_api.dart`、`services/wyzie/wyzie_api.dart`、`utils/bili_short_link.dart` | 所有请求入口包一层重试；文本/JSON/下载各自设体积上限 |

**关键决策**：
- **只重试「连接类」失败**：连接失败（`SocketException`）、建立/发送超时
  （`TimeoutException`）——请求根本没到服务端，重发安全。**响应中途断开不重试**
  （`Connection closed before full header was received` 等），因为请求可能已被服务端
  处理，重发有重复提交风险（对齐 PiliPlus 排除 `TransportConnectionException`）。
  业务/解析异常一律不重试，`ResponseTooLargeException` 也不重试（重试只会再下载一遍）。
- **流式一律不重试**：`withRetry(streaming: true)` 直接单次执行；本项目流式路径
  （`openStream` / 下载 Range / `NetworkStreamingProxy` / `BiliStreamProxy` 转发）
  **不经过**本工具，也不得自行加重试。
- **超时分级**：常规 API 12s / 文本 15s / 下载 30s / 媒体流 30min（各调用方按用途选档，
  不再各客户端写死 30s）。
- **体积上限快速失败**：先看 `content-length`（声明超限**一个字节都不读**，直接取消
  订阅），再边读边计数；文本 2MB、JSON 16MB、下载 64MB。⚠️ 超限时**不能 drain**
  （那会把上游的巨量响应全部下载下来）。
- **重试必须新建 Request**：`http.Request` 的 body 流只能发送一次，复用同一对象重试会抛
  「Request has already been sent」——`sendGet` 与短链展开都在重试闭包内新建请求。

---

### 4.29 并发原语与通用分页（C1 / C2）

> 借鉴 Kazumi `async_session.dart` / `AsyncSingleFlight` / `AsyncSerialQueue` 与
> PiliPlus `CommonController`/`LoadingState`：把散落各处的「异步正确性」套路
> 抽成可单测的公共件（调研清单 C1/C2，P1）。

**C1 并发原语**（`lib/utils/`，纯 Dart + 单测）：

| 原语 | 语义 | 已收敛的落点 |
|---|---|---|
| `AsyncSession` | 会话号令牌：`start()` 开新会话、`isCurrent(token)` 判废、`invalidate()` 主动作废 | `DanmakuController._loadSession`（4 处加载路径）、`DanmakuScheduler._generation` |
| `AsyncSingleFlight<T>` | 同 key 并发只执行一次、共享 Future；**失败不缓存**、完成后记录清除 | `VideoInfoService`（视频信息 + 基本元数据两条链路） |
| `AsyncSerialQueue` | 按提交顺序串行执行；**任务异常不打断队列**（错误抛给各自调用方）；`idle` 等排空 | `PlaybackProgressService` 进度写盘串行链 |

**C2 通用分页**：

| 层 | 文件 | 职责 |
|---|---|---|
| 三态 | `utils/loading_state.dart` | `sealed LoadingState<T>`（Loading / Loaded / LoadError）+ `PageResult<T>`（一页数据 + hasMore） |
| 控制器 | `services/common_list_controller.dart` | `CommonListController<T>`（ChangeNotifier）：`refresh` / `loadMore` / `reset` / `state` / `error` / `hasMore` |

**关键决策**：
- **刷新失败保留旧列表**：已有数据时出错只记录 `error`（页面可 toast），`state` 仍是
  `Loaded`——用户不会因为一次网络抖动看到「列表清空 + 报错」；换关键词/筛选条件才
  `reset()`（先清空再 `refresh`）。
- **成功但结果为空 = Loaded([])**：用 `_hasLoadedOnce` 区分「还没加载」与「加载过但没
  数据」，否则空结果会永远停在加载中（实测踩到）。
- **并发防重入**：`refresh`/`loadMore` 相互排斥；出错后阻止 `loadMore`（先重试）。
- **页面只负责渲染**：控制器是 ChangeNotifier，页面用 `ListenableBuilder` 局部订阅
  （§4.1），不再手工维护 `_loading/_error/_page/_items` 四件套。
- **已落地页面**：番剧搜索页、番剧索引页（分页 + 三态 + 空态 + 重试）；番剧首页/历史
  等列表页后续按需迁移（不强制一次替换到位）。

---

### 4.30 App 内文件管理（复制/移动/重命名/删除）+ 固定文件夹（工作.md）

> 参考 mpvRx `ui/browser/**`（`BrowserBottomBar` + `dialogs/{CopyPasteDialog,RenameDialog,
> DeleteConfirmationDialog,FolderPickerDialog}` + `FolderListScreen` 的固定/排序）。
> **只借鉴四个动作与固定语义**，参考项目的分享/播放/黑名单/压缩/加入播放列表一律不要。

**定稿语义（用户拍板，勿擅自改）**：

| 项 | 定稿 |
|---|---|
| 长按菜单 | **固定与四个文件动作在同一个菜单里**：文件夹长按 = 固定/取消固定 + 复制/移动/重命名/删除（五项）；视频长按 = 复制/移动/重命名/删除（四项，视频无「固定」）。菜单最底部再用分隔线单列一项**「多选」**（它是模式切换、不是对本条目的操作）→ 进入批量操作（§4.31）。固定**只此一个入口**，不做卡片/AppBar 图钉按钮，也不做独立的「固定文件夹」设置页 |
| 重命名 | **视频/文件的扩展名锁死**：输入框只给「扩展名之前的主体」，右侧固定显示 `.mp4`，用户改不出别的格式；用户即便把扩展名一起打进来也不会变成 `456.mp4.mp4`。文件夹不锁（目录名允许带点） |
| 删除文件夹 | 弹窗**默认只删文件夹内的视频文件**（正文一句话说清），下方一个**默认不勾**的「删除所有文件」——勾上 = 连同其它文件递归删除整个文件夹；不写死偏好 |
| 复制/移动目标 | 复用 App 内自绘目录选择器 `showDirectoryPickerDialog`（真实路径 + `MANAGE_EXTERNAL_STORAGE`，无需 SAF），带进度弹窗与取消 |
| 固定排序 | **先按当前排序规则整体排，再把固定的文件夹稳定前置**（`partition` 语义）：固定项之间仍参与排序，未固定项之间也照常排 |

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/folder_pin.dart` | `pinnedFoldersFirst`（扁平列表稳定前置）+ `mapTreeWithPinnedFirst`（逐层递归，树状模式用）；分组无变化时**原样返回同一实例**，避免无谓重建 |
| 纯函数 | `utils/file_ops.dart` | 路径细分（`baseName`/`parentOf`/`stripTrailingSlash`）、目标校验（含「不能移动到自己子目录」）、重命名合法性、重名避让 `uniqueName`、失效固定路径推导 `stalePinnedPaths` |
| 设置 | `services/pinned_folders_settings.dart` | 固定集合（**绝对路径** `Set<String>`）单例 + 持久化；`toggle/setPinned/replaceAll/retainExisting(additionalStale:)`；启动 `ensureLoaded`（main.dart） |
| 服务 | `services/file_operations_service.dart` | `copy/move/rename/deleteFile/deleteFolder`；重名自动避让、同卷 `rename` 原子秒移、跨卷退化「复制+删源」、`FileOpCancelToken` 协作式取消、`FileOpProgress` 进度回调；失败抛 `FileOpException`（文案可直接进 SnackBar） |
| UI | `widgets/file_operations_ui.dart` | 长按动作菜单（固定/复制/移动/重命名/删除/多选）、重命名弹窗（实时校验）、删除弹窗（默认只删视频 + 默认不勾的「删除所有文件」，支持多选 `itemCount`/`folderCount`）、传输进度弹窗 |
| 编排 | `widgets/folder_actions.dart` | `showFileManagementFlow`：菜单 → 弹窗 → 服务 → `onMutated` 本地刷新 → SnackBar；**首页列表/树状一级/树状目录页/文件夹详情页四页面共用同一入口**，返回 bool 表示「当前页对象已改名或删除」；多选批量走 `showBatchFileManagementFlow`（§4.31） |
| 入口 | `widgets/folder_card.dart` / `video_card.dart` | 两卡片新增 `onLongPress` 与多选态 `selectionMode`/`selected`；`FolderCard` 另有 `isPinned`（已固定时名称左侧显示图钉，**纯指示不可点**） |

**关键决策**：
- **固定只有长按菜单一个入口**：卡片图钉、详情页/目录页 AppBar 图钉、设置页「固定文件夹」
  **全部不做**（用户明确要求）；卡片上的图钉仅是「已固定」的视觉指示。取消固定 = 再次长按 → 「取消固定」。
- **菜单不带标题行**：长按的卡片就在用户眼前，标题属冗余且会挤掉菜单高度；
  菜单内容用 `ListView` + `isScrollControlled`，矮屏/大字号下可滚动，不会 RenderFlex 溢出
  （曾因「标题行 + 五项」超出底部外壳可用高度而溢出 25px）。
- **排序真值只有一份**：各页面先 `viewSettings.sortFolders/sortTree`，再套 `folder_pin.dart`；
  固定函数**不做比较**，因此不会出现第二套排序逻辑（与 `ViewSettings` 冲突时以后者为准）。
- **固定按绝对路径存储**，文件夹改名/移动/删除后必须清理：成功路径统一调
  `retainExisting(additionalStale: stalePinnedPaths(...))`；**改名时若原来已固定则把新路径继续固定**
  （`wasPinned` 必须在清理前读取，否则会被 `retainExisting` 摘掉）。
- **文件操作后必须重扫**：`VideoScanner.clearCache()` + `scanVideos()` 再重建树/列表
  （首页 `_load`、详情页按 `folderPath` 过滤、树状页 `_locateByPath` 按绝对路径重新定位当前节点；
  当前文件夹路径已不存在 → `maybePop` 退出该页）。
- **重命名锁扩展名（用户报的真实 bug）**：早期版本输入框预填完整文件名，用户全选删掉
  输 `456` → 文件变成没有扩展名的 `456`，**播放器列表里直接消失**（MediaStore 不认）。
  现在 `renameInitialInput` 只预填主体、`renameTargetName` 恒拼回原扩展名、
  `validateRenameInput(originalExtension:)` 拦「只输 `.mp4`」，双保险，扩展开关不可能被改掉。
- **重命名不做静默避让**：同目录已有同名直接报错（显式意图不该被改成 `xxx (1)`）；
  复制/移动则自动避让 `名字 (1)`（隐式意图，冲突时保留两者）。
- **写盘前置**：所有操作直接走 `dart:io` 真实路径，依赖首页的
  `MANAGE_EXTERNAL_STORAGE` 门禁；不改用 SAF，避免「写入成功但 MediaStore 扫不到」。

---

### 4.31 文件管理多选（批量操作）

> 需求：文件夹与视频**都能多选**（原先只有单选）；「多选」放进长按菜单；
> 多选下禁用一部分操作（如重命名）；「选完之后怎么再呼出菜单」经方案评审拍板。

**定稿语义（用户四问四答，勿擅自改）**：

| 问题 | 定稿 |
|---|---|
| 多选态怎么再呼出菜单 | **顶部 AppBar 上下文工具栏** `[×] 已选 N 项 [全选] [⋮]`，点 ⋮ 弹出**和长按完全同一个**菜单（`showFileActionMenu(selectionCount: n)`） |
| 多选态下长按卡片 | 同样呼出该菜单；长按的那张若还没选就**先纳入选择**（否则会对着一个空选择弹出菜单） |
| 禁用哪些操作 | **撤掉「重命名」**（一次只能改一个名字）与「多选」自身；**「固定」仅在选中项全是文件夹时出现**（混选/纯视频没有固定语义） |
| 批量删除文件夹 | 沿用同一个确认弹窗：默认只删文件夹内的视频，勾「删除所有文件」对**全部**选中文件夹一次性生效 |

**分层**（自下而上）：

| 层 | 文件 | 职责 |
|---|---|---|
| 纯函数 | `utils/file_selection.dart` | `indexTreeSelection`（递归建 path→选中项 索引）/ `indexVideoSelection` / `pickSelection`（按点选先后取值，索引里查不到的自动丢弃）；选中项用记录类型 `FileSelectionItem`，与 `TreeNode`/`VideoFile` 解耦 |
| 状态 | `services/file_selection_controller.dart` | `selecting/count/paths/isSelected/containsAll/begin/exit/toggle/setAll/retainExisting`；**页面级、非单例、不持久化**（§4.1） |
| UI | `widgets/file_selection_ui.dart` | `buildFileSelectionAppBar`（顶部工具栏）+ `SelectionMark`（卡片勾选圆点）+ 选中卡片底色/描边派生 |
| UI | `widgets/file_operations_ui.dart` | 菜单新增 `FileAction.multiSelect`；`selectionCount > 0` 时撤重命名与多选；删除弹窗支持 `itemCount`/`folderCount` |
| 编排 | `widgets/folder_actions.dart` | `showBatchFileManagementFlow`：批量菜单 → 逐项预校验 → 串行执行 → 汇总提示 |
| 入口 | `home_page.dart` / `folder_detail_page.dart` / `tree_folder_page.dart` | 各自持有一个 `FileSelectionController`，把 `selectionMode`/`selected` 传给卡片，`PopScope` 拦系统返回 |

**关键决策**：
- **操作入口放顶部、不放底部**：主 tab 页底部有悬浮胶囊导航（`MainScaffold` 用 `Stack` 叠加在内容之上），底部再放一条操作栏会直接压住导航。多选态顺带收起首页右下角速拨 FAB（它会压住列表末尾几项）。
- **菜单只有一个真源**：多选态不另写菜单，继续用 `showFileActionMenu`，靠 `selectionCount` 裁剪；将来加操作只改一处。
- **全选范围 = 当前可见列表**：「可见」= 已排序 + 固定前置 + 搜索过滤后的结果，由各页面 `_visibleNodes` / `_visibleVideos` / `_visibleChildren` 一处裁决（顺带消掉「排序真值两套」的隐患）。
- **选择不跨页**：控制器由页面 `State` 持有并 `dispose`；树状目录页多选时**收起面包屑**（它是「跳去别的层级」的出口，一跳就连页面带选择一起丢）。
- **系统返回键先退多选**：三个页面都 `PopScope(canPop: !selecting, onPopInvokedWithResult: ...)`，而不是直接退出页面。
- **点选顺序即执行顺序**：`pickSelection` 按 `controller.paths`（点选先后）取值而非列表顺序，批量提示里的「第 i/N 项」才符合用户预期。
- **批量传输先全员预校验**：目标目录选一次，逐项跑 `validateMoveTarget`，**任一项不合法就整体中止**（避免「搬了一半才发现目标非法」）。
- **单项失败不中断整批**：收集失败原因最后汇总（`已$verb $done/$total 项，失败：…`，超过 3 条折叠）——一把文件里有一个被占用不该连累其它 19 个。
- **固定不退出多选**：固定只改展示顺序、不动磁盘，连续固定多个更顺手；其余操作执行完自动退出多选（`showBatchFileManagementFlow` 返回 true = 真的做了操作，只是关菜单/取消弹窗不算）。
- **重扫后剔除失效选中项**：每次 `onMutated` 后调 `retainExisting`，保证批量操作不会打到死路径。
- **进度弹窗句柄只 pop 一次**、`dismiss`/`dispose` 分离：见 §7 对应两行。

---

### 4.32 音轨不可播放自动回退 + 字幕字体目录构造期注入（真机 bug 修复）

> 来源：真机播放一部内置「Dolby TrueHD 英语轨 + AC-3 国语轨 + 4 条 PGS 中文字幕」的
> MKV 时发现的两个用户可感知缺陷：①切到 TrueHD 音轨后**完全无声**；②四条 PGS
> 字幕**一条都不显示**。两条都是「mpv 已经报错/已经按规矩办事，应用侧没接住」。

**为什么 TrueHD 轨会无声（真因：自编内核的 ffmpeg 解码器白名单漏了 TrueHD）**：
- 内核 `flavors/default.sh` 的白名单里有 `dca`（DTS）、`ac3`、`eac3`…，**没有 `mlp`/`truehd`**
  → TrueHD 轨没有任何解码器，音频链直接建不起来，mpv 只在错误日志里报 `ad`/`ao` 错误。
- 附带限制（即使解码器到位也要知道）：Android 上 media_kit 写死 `ao=opensles`
  （`real.dart` 按 `AndroidHelper.isPhysicalDevice`），而 **OpenSL ES 输出只支持双声道**
  （`ao_opensles.c`：`mp_chmap_from_channels(&ao->channels, 2)`），所以 TrueHD 会被
  mpv 下混成 stereo 播放——**能出声，但不是多声道**。要真多声道需换 AO（`audiotrack`/
  `aaudio`）并重编内核，属后续独立项（OpenSL ES 在 mpv 0.42 已被移除）。
- 应用侧此前**完全没有消费** `Player.stream.log`（`logLevel` 默认已是 `error`），
  于是表现为「点了切换、面板显示已选中、就是没声音、也没有任何提示」。

**修法（应用层能做到的全部）**：`AudioController` 在**用户显式换轨后的 4 秒窗口**内订阅
`Player.stream.log`（窗口限制避免播放中途的瞬时音频日志误触发换轨），命中纯函数
`isAudioPlaybackFailureLog(prefix, text)`（只认音频相关前缀 + 失败特征词）后，
延时 600ms 读 `audio-params` **复核**（`no`/空 = 音频链真的没建起来；读属性异常一律
判为「没失败」以免误切），确认失败则用 `pickFallbackAudioTrack` 选一条**不同编码**的
轨道（TrueHD → AC-3）自动切过去，并通过 `onAudioFallback` 让播放页 toast 说明原因；
无路可退时也只 toast，不再静默无声。`clear()`/`selectTrack()` 复位防重入与探测窗口。

**字幕为什么整条不显示（真因：自编内核的 ffmpeg 解码器白名单漏了 PGS）**：
- `libmpv-android-video-build-thumbnail`（内核仓库）的 `buildscripts/flavors/default.sh`
  用 `--disable-decoders` + 逐个白名单开解码器；**字幕段开了
  `dvbsub`/`dvdsub`/`ass`/`subrip`/`webvtt`…，唯独没有 `hdmv_pgs_subtitle`** →
  PGS 轨能列出、能选中，但没有任何解码器可解，**完全不渲染**（文本字幕不受影响）。
  同一份白名单也漏了 `mlp`/`truehd`（见上一条）。
- ⚠️ **不要用 `strings libmpv.so | grep truehd` 下结论**：`--enable-demuxer=truehd`
  只是**解封装器**的名字，解封装器在、解码器不在时照样完全无声；且 `--enable-small`
  会把 codec 的 `long_name` 编掉，用长名（`HDMV Presentation Graphic Stream subtitles`）
  检索同样会误判成"已编入"。正确判据是解码器**短名**各出现 1 次：
  `hdmv_pgs_subtitle` / `truehd` / `mlp`。
- **修法**：内核 `flavors/default.sh` 补
  `--enable-decoder=hdmv_pgs_subtitle` + `--enable-decoder=mlp` + `--enable-decoder=truehd`
  （`mlp` 是 `truehd` 的依赖，缺了 configure 会硬失败），push 触发 CI 重出 4 个 ABI 的
  jar，再替换 `third_party/media_kit_libs_android_video/android/jars/*.jar`
  （无需改任何 Dart 代码，§4.9）。

**运行期写 `sub-fonts-dir`（本节同批修掉的另一处真实缺陷）**：
- `applyAllSettings()` 的默认字体分支曾在**运行期**写
  `setProperty('sub-fonts-dir', '/system/fonts')` —— 直接违反 §4.10 与 §7 已写明的
  铁律（运行期写 `sub-fonts-dir` 会重载 libass 的 fontconfig 缓存，字幕整条消失）。
- 位图字幕（PGS/DVD/DVB）也走 libass（mpv 只对 ASS 原生直通，其余先由 ffmpeg 转成
  ASS 的 `DRAWING` 指令，见 `sub/sd_ass.c` 的 `lavc_conv` 分支），所以这条路径打坏的是
  **全部内嵌字幕**。真机上 PGS 仍然不显示说明**它当时不是（唯一）根因**——真因是上面
  那条内核缺解码器；但这处写入仍是必须收口的违规（否则修好内核后仍会被它打坏）。
- **修法**：字体目录一律**构造期注入**。`resolveSubtitleFontInjection()`
  （`lib/models/subtitle_font_injection.dart`，纯函数）**永不返回 null**：用户字体齐备 →
  注入用户目录；否则注入 `kSystemFontsDir='/system/fonts'` + `kSystemFontName`。
  运行期只允许写 `sub-font`（族名）与样式属性，**任何** `sub-fonts-dir` 写入都是回归。

| 位置 | 作用 |
|---|---|
| `lib/models/subtitle_font_injection.dart` | `resolveSubtitleFontInjection` / `shouldInjectCustomSubtitleFont` / `kSystemFontsDir` / `kSystemFontName`（纯函数，可单测） |
| `lib/pages/player/player_page.dart` | 构造 `PlayerConfiguration(libass: true, libassAndroidFontsDir: …, libassAndroidFontName: …)`；注册 `onAudioFallback` toast |
| `lib/services/subtitle_service.dart` | `applyAllSettings()` 只写 `sub-font`（不再写 `sub-fonts-dir`） |
| `lib/services/audio_service.dart` | `isAudioPlaybackFailureLog` / `pickFallbackAudioTrack` + 换轨后 4 秒窗口内的 `stream.log` 订阅 + `audio-params` 复核 + 回退防重入 |
| `test/audio_fallback_test.dart` / `test/subtitle_font_injection_test.dart` | 两条链路的回归锁（含「注入目录永不为空」） |
| **内核仓库** `azxcvn/libmpv-android-video-build-thumbnail`（本地：`桌面/jartest/libmpv-android-video-build-main`） | `buildscripts/flavors/default.sh` 的解码器白名单补 `hdmv_pgs_subtitle` / `mlp` / `truehd`；push 触发 CI 出 4 个 ABI 的 `default-*.jar`，替换 `third_party/media_kit_libs_android_video/android/jars/*.jar` 即可（§4.9）。**该白名单是本项目自有改动，同步上游时勿被覆盖**（README 已记录） |

---

## 5. 新增功能指南（按功能类型）

### 5.1 新增一个页面

1. 建目录 `lib/pages/<name>/`，页面文件 `xxx_page.dart`（StatefulWidget）
2. 页面用 `Scaffold` + `AppBar`，body 用 `ListView`（安全区自动处理，不用管）
3. 需要排序弹窗 → `showSortOptionsSheet`；需要弹窗 → `showAppDialog`
4. 跳转：`Navigator.push(MaterialPageRoute(builder: ...))`
   - 如果是播放页：用 `playerPageRoute(page)`（`app_frame.dart`，无进出场动画 + 自动带 `RouteSettings(name: playerRouteName)`）
   - 播放页可传 `playlist:`（当前可见的排序视频列表），用于「下一集」；不传则按钮置灰
5. 页面专属小组件放 `lib/pages/<name>/views/`，跨页复用的放 `lib/widgets/`
6. 底部有悬浮胶囊（主 tab 页）：ListView 底部 padding `88`

### 5.2 新增数据/业务服务

1. 放 `lib/services/<name>.dart`
2. 需要 UI 响应：`class XxxService extends ChangeNotifier`，页面用 `ListenableBuilder(listenable: Listenable.merge([...]))`
3. 需要持久化：`shared_preferences`，load 在启动时调用（参考 `main.dart` 的 initState）
4. 纯工具函数：放 `lib/utils/`（无状态、无 Flutter 依赖更佳）

### 5.3 新增设置项

1. 设置主页 `settings_page.dart` 已有分组结构：`SettingsGroupTitle(title: '分组名')` + `SettingsCard(child: SettingsTile(...))`
2. 新分组直接追加；新设置子页参考 `appearance_page.dart`（`AppBar` + 分组列表）
3. 设置项 UI 组件复用 `lib/widgets/settings_ui.dart`（`SettingsGroupTitle / SettingsCard / SettingsTile / SettingsRadioTile`）
4. 播放器设置分组约定（`player_settings_page.dart`）：**手势**组 = 双击手势 + 快进/快退时长 + 音量/亮度灵敏度 + 长按倍速滑杆（**全部归为一张卡片**，项间 `Divider(height:1, indent:16, endIndent:16)` 分隔）；**视频方向**组 = 自动/锁定竖屏/锁定横屏（RadioTile 三选一）；**顶部信息**组 = 时间/电量/网速/数据类型（CheckboxTile 四项多选，默认全选，阶段1 第 1 点）；**播放行为**组 = 常驻进度线/进度条缩略图/记住上次倍速/保存音量到系统/双指缩小视频/按钮背景/自动连播/播放完毕自动退出/循环播放模式（RadioTile 三选一：关闭/列表循环/单集循环）/倍速播放指示器/启用播放界面动画/音量增强（组内最后一项：开关 + 可折叠上限百分比滑杆，§4.23）（组内每项之间用 `Divider(height:1, indent:16, endIndent:16)` 分隔）；「已观看进度阈值」独立滑杆组（5% – 100%，步进 5%，默认 95%）
5. **播放器暗色面板里的强调色/滑杆必须跟随主题**：面板恒为暗色外壳，但强调色不得写死。
   统一用 `settings_ui.dart` 的 `playerPanelAccent(context)`（强调色）与
   `playerPanelSliderTheme(context)`（滑杆主题）——它们以当前 `ColorScheme.primary` 为 seed
   **派生暗色方案**再取 primary：浅色主题下直接用 `scheme.primary` 在暗底上偏暗、对比不足，
   派生后自动提亮到暗底可读色阶且保留用户色相；派生结果按 seed 缓存（`fromSeed` 每次都跑
   HCT 调色板计算，滑杆拖动时逐帧 build，无缓存会掉帧）。
   例外：语义色不跟随主题——字幕 RGBA 通道滑杆的 R/G/B/A 轨道色就是通道语义本身。

### 5.4 新增模型字段

- 改 `lib/models/` 下对应模型（纯数据），注意 `TreeNode` 是不可变类，重建时传完整参数

### 5.5 新增测试（必须有）

每个新逻辑都要配测试（见 §6），文件放 `test/`，命名 `<被测文件>_test.dart`。

### 5.6 文档维护（必须）

完成**重大功能新增 / 优化或 Bug 修复**后，必须在本文件（ARCHITECTURE.md）同步以下内容，再算收工：

1. **§2 目录结构**：新增/删除/移动的文件、目录必须反映到树形图（含一行注释说明职责）；
2. **受影响章节**：改到状态管理 → §4.1；新增弹窗 → §4.5；改播放页 → §5.1 / §4.3/4.4；缩略图/抓帧 → §4.9；新增设置 → §5.3；新增测试 → §6；
3. **§7 已知注意事项**：新踩的坑（环境 / 框架 / 设备）要补进表格，防止他人重蹈覆辙。

**文档写作约定（工作.md 第 1 点，必须遵守）**：
- **§7 注意事项必须精简**：每条只写「坑 + 防护」一句话，能用 30 字讲清不写 60 字；
  表格行数控制在必要范围内，禁止长篇展开论述；
- **§2 目录结构中每个 dart 文件都必须带 `# 一行简短描述`**：只说明「这个文件负责什么」
  （一句话），不写实现细节、不重复类名可推断的内容；
- 改完代码后，**文档中任何与代码不一致的路径、文件名、组件名都算违约**。小改动（如改文案、调样式）不强制，但涉及结构 / 接口 / 行为变化必须更新。

---

## 6. 测试约定

- 框架：`flutter_test`；权限 mock 用 `permission_handler_platform_interface` 的 `PermissionHandlerPlatform.instance` 替换（参考 `test/home_page_permission_test.dart`）
- 现有测试（`flutter test` 全绿）：
  - `test/widget_test.dart` — 胶囊导航渲染（**注意**：胶囊设计上所有标签都显示，勿改成 findsNothing）
  - `test/view_settings_test.dart` — sortTree / sortFolders / sortVideos 排序逻辑（含名称自然序：2 < 12 < 112）
  - `test/natural_compare_test.dart` — 自然序比较纯函数（数字段/字母段/前缀）
  - `test/super_resolution_mode_test.dart` — 超分模型（7 模式 + 质量枚举 + buildAnime4KChain 链构建纯函数 + 着色器文件完整性）
  - `test/super_resolution_service_test.dart` — 超分服务状态/持久化（模式、质量、记忆开关的开启/关闭/load 恢复）
  - `test/app_frame_test.dart` — AppFrame 安全区行为 + 播放页路由检测（**安全区/播放页回归测试，改 AppFrame 必须跑**）
  - `test/home_page_permission_test.dart` — 权限流程（未授权 → 授予权限 → 授权扫描）
  - `test/player_controls_settings_test.dart` — 播放器控制设置（槽位增删/排序/上限/时长档位/倍速预设/按钮背景/进度条样式/长按倍速/灵敏度/保存音量到系统/音量增强开关与上限百分比 10% 步进就近对齐/指示器开关/首次提示/双指缩放/自动连播/自动退出/循环模式/已观看阈值 5% 档位/视频方向/播放界面动画开关/旧数据迁移；倍速不在顶栏动作之列）
  - `test/player_gestures_test.dart` — 双击手势三模式判定（含边界）+ 滑动手势数学（seek 灵敏度/音量·亮度增量/音量增强 mpv volume-max 与展示百分比·增强段判定/动态倍速档位与索引/最近档位）
  - `test/player_panel_test.dart` — 右侧面板打开/面板内导航不崩溃（**改 PlayerPanel 必须跑**）
  - `test/player_bottom_panel_test.dart` — 竖屏底部面板打开/面板内二级导航/返回/关闭不崩溃（**改 PlayerBottomPanel 必须跑**）
  - `test/player_speed_panel_test.dart` — 倍速面板（「我的预设」✕ 删除 / 「添加到预设」随滑杆联动）
  - `test/playback_completion_test.dart` — 播放完成 EOF 动作解析纯函数（单集循环→自动连播→列表循环→自动退出→自动暂停优先级链，含边界）
  - `test/playback_restore_test.dart` — 恢复进度阈值判定纯函数（<5% / ≥已观看阈值不恢复，边界与自定义阈值）
  - `test/audio_shuffle_test.dart` — 听视频随机播放算法（时间刻种子：结果范围/不重复当前曲目/同刻可复现/不同刻不同）
  - `test/playlist_sort_test.dart` — 播放列表 4 排序纯函数（名称/日期 × 升/降序，自然序/无日期垫底）+ 目录过滤（folderOfPath/filterVideosInFolder）
  - `test/pip_aspect_test.dart` — 画中画宽高比纯函数（gcd 约分/0.5–2.39 钳制/未知尺寸回退 16:9）
  - `test/portrait_player_bottom_bar_test.dart` — 竖屏底栏右侧按钮簇顺序（超分辨率→列表→倍速→选择屏幕，左到右）+ 弹幕按钮（进度条上方右下角、与章节名同行、开关随 danmakuOn 切换）
  - `test/thumbnail_cache_test.dart` — FFmpeg 帧缓存查询（peekFrame 精确秒桶/peekNearestFrame 邻近匹配/跨视频隔离）+ 32MB LRU 超限淘汰
  - `test/watch_state_test.dart` — 观看状态纯函数（未观看/观看中/已看完判定 + 自定义阈值 + 百分比）
  - `test/chapter_utils_test.dart` — 章节纯函数（标题关键词分类/片段派生过滤/当前章节定位/跳过目标 EOF 保护 + 自定义关键词归属与优先级，§4.22）
  - `test/chapter_tracker_test.dart` — 章节跟踪器（位置流驱动的章节推进/胶囊 5 秒窗口/回拖重复触发/跳过与跳转 + 章节跳段自动跳过每片段一次/自定义关键词派生，§4.22）
  - `test/chapter_skip_settings_test.dart` — 章节跳段设置服务（默认值/自动跳过类型增删/自定义关键词/持久化恢复/损坏防御，§4.22）
  - `test/intro_outro_skip_test.dart` — 片头片尾动作决策纯函数（前置守卫/片头触发/片尾触发/整集保护/片头优先）
  - `test/intro_outro_settings_test.dart` — 片头片尾设置服务（默认值/钳制/范围收窄联动/一键重置/持久化恢复）
  - `test/intro_outro_tracker_test.dart` — 片头片尾跟踪器（就绪门控/每集一次/越过即标记/恢复点感知/切集重置）
  - `test/intro_outro_panel_test.dart` — 片头片尾面板（开关展开/输入换算 mm:ss/滑杆/设为当前时间与剩余时间/一键重置）
  - `test/formatters_network_test.dart` — 网速格式化（KB/MB 自动切换两位小数）与在线媒体判定纯函数（阶段1 第 1 点）
  - `test/formatters_test.dart` — 截图文件名纯函数（app名称 + 日期 + 到秒时间，避免同日覆盖）
  - `test/subtitle_track_test.dart` — 字幕轨道纯函数（展示名/ASS 样式判定/格式过滤/对齐/颜色 + RGBA↔mpv 颜色转换，阶段1 第 3 点）
  - `test/subtitle_settings_test.dart` — 字幕设置服务（默认值/延迟叠加与钳制/描边模式/外挂字幕记忆/字体源目录记忆/重置样式持久化）
  - `test/subtitle_auto_match_test.dart` — 同名字幕自动匹配纯函数（同名候选/扩展名优先级/完全同名优先/简繁语言后缀/短名优先/无匹配）
  - `test/subtitle_sort_test.dart` — 自建字幕选择器排序纯函数（目录恒在前/大小日期升降序）
  - `test/audio_track_test.dart` — 音轨纯函数（展示名/声道枚举/格式过滤/audio-channels 映射/af 滤镜链组装，工作.md 音频功能）
  - `test/audio_fallback_test.dart` — 音轨不可播放自动回退纯函数（mpv 日志判定只认音频前缀+失败特征、视频/网络错误不误触发；回退目标优先不同编码、内置优先于外部、无路可退返回 null，§4.32）
  - `test/danmaku_timeline_test.dart` — 弹幕时间轴错峰纯函数（同秒多条 1 秒内均分、<1000ms 上界）
  - `test/danmaku_local_file_test.dart` — 同名弹幕查找纯函数（9 种命名规则优先级/排除视频自身/无匹配）+ 选择器文件过滤
  - `test/danmaku_xml_test.dart` — B站 XML 弹幕解析（基础字段/实体反转义/坏条目跳过/排序）
  - `test/danmaku_scheduler_test.dart` — 弹幕调度器（秒桶前向补发/首 tick 锚定/seek 检测/代数失效/微幅回抖）
  - `test/player_danmaku_panel_test.dart` — 弹幕二级界面（四入口齐全/网络·自动匹配回调注入/设置回调注入/无平台通道不崩溃）
  - `test/danmaku_memory_test.dart` — 弹幕手动导入记忆（set/get/remove/持久化恢复/损坏数据防御）
  - `test/danmaku_settings_test.dart` — 弹幕设置服务（默认值/钳制/持久化恢复/越界收窄/恢复默认/通知 + 字体三态/自定义字体持久化 + 屏蔽词增删清/显示区域档位吸附 + **弹幕合并开关默认关与持久化**）
  - `test/danmaku_font_mode_test.dart` — 弹幕字体三态解析纯函数（跟随系统/跟随 App/自定义）
  - `test/app_font_settings_test.dart` — App 全局字体设置服务（默认值/开关·字体·缩放·字重持久化/钳制/effective 生效条件/通知）
  - `test/danmaku_random_color_test.dart` — 随机渐变色纯函数（HSV 转换/色相环绕/种子可复现/色轮均匀分布/高明度约束）
  - `test/danmaku_dedup_test.dart` — 弹幕去重纯函数（归一化判同/时间窗合并/链式推进/无序输入/原文保留）
  - `test/danmaku_merge_test.dart` — 弹幕合并纯函数（窗口内聚合计次/超窗分簇/簇锚定首条/归一化判同/输出升序/minCount 与 windowSeconds/展示文本 `×N`/isColorful 透传，§4.11）
  - `test/danmaku_blocklist_test.dart` — 弹幕屏蔽词纯函数（子串命中/忽略大小写·空白/列表过滤）
  - `test/danmaku_episode_test.dart` — 弹幕集数提取/匹配纯函数（文件名各规则 + 集列表定位，切集自动匹配）
  - `test/dandan_signature_test.dart` — 弹弹Play 签名纯函数（官方示例 + 三条真实路径的**合成密钥**已知向量；⚠️ 禁止写入真实 AppId/AppSecret）
  - `test/dandan_comment_test.dart` — 弹弹Play 评论→弹幕条目/B站 XML（p 字段解析/容错/排序/XML 往返转义）
  - `test/dandan_models_test.dart` — 弹弹Play API 数据模型 fromJson（字段映射/容错）
  - `test/danmaku_server_test.dart` — 弹幕服务器模型（默认服务器/toJson/fromJson/copyWith）
  - `test/danmaku_server_settings_test.dart` — 弹幕服务器设置服务（默认/增删启停/自动匹配开关/**与默认服务器互斥**：拒绝开启+偏好保留+停用后恢复+关闭永远允许/持久化/损坏防御）
  - `test/danmaku_server_page_test.dart` — 弹幕服务器设置页（默认服务器启用时自动匹配开关变灰+副标题短原因+点击弹完整说明 toast；副标题显著短于 toast；停用后恢复可用；启用默认服务器即回落变灰）
  - `test/danmaku_search_history_test.dart` — 搜索历史（去重/上限淘汰最旧/清除/持久化/损坏防御）
  - `test/danmaku_auto_match_cache_test.dart` — 自动匹配缓存存储（保存/读回/清空/持久化/损坏防御）
  - `test/danmaku_network_service_test.dart` — 弹幕网络服务（文件名清洗/搜索合并去重来源/下载落盘可回读/落盘失败降级）
  - `test/player_danmaku_network_panel_test.dart` — 网络弹幕搜索面板（40dp 搜索框定高/框下历史胶囊+清除/命中折叠与重新展开/结果卡收起态不构建子树+手风琴/选集回调+关闭面板）
  - `test/player_danmaku_settings_panel_test.dart` — 弹幕设置面板（两段式布局/开关滑杆实时写设置/恢复默认/读数联动/屏蔽词增删 + **「弹幕合并」开关位于去重与屏蔽词之间**）
  - `test/player_panel_theme_test.dart` — 播放器暗色面板强调色跟随主题（换主题色滑杆轨道/拇指随之改变且不等于旧写死蓝 0xFF4FC3F7；保留无气泡外观；浅色主题下派生色更亮；同 seed 复用缓存实例）
  - `test/subtitle_file_picker_panel_test.dart` — 自建选择器面板（记忆文件夹被删向上回退/空目录正常落地/导航失败维持原状/选择回调+文件夹记忆）
  - `test/bili_bangumi_test.dart` — 番剧模型 fromJson（索引/条件/搜索/季详情/选集/时间表 + 数字字段字符串兼容）+ 链接解析纯函数（ss/ep/BV）
  - `test/bili_bangumi_service_test.dart` — 番剧服务（MockClient：条件/索引分页/推荐/搜索 WBI 签名/季详情 season_id·ep_id/时间表合并 + 业务错误语义化）
  - `test/bili_dash_test.dart` — playurl DASH 模型（DASH 解析/baseUrl·baseUrls 双格式/清晰度档/clips/dolby·flac 合并/数字字符串兼容/默认选流优先 30280）
  - `test/bili_pb_test.dart` — protobuf wire 解码器（varint/length-delimited/未知字段跳过）+ 弹幕消息字段号解析（DmWebViewReply.dmSge.total / DanmakuElem）
  - `test/bili_danmaku_service_test.dart` — B 站弹幕服务（MockClient：分段 protobuf 抓取解码/跨分段去重/state==1 关闭/降级旧 XML deflate/XML 缓存回读往返）
  - `test/bili_video_service_test.dart` — 视频服务（MockClient：PGC result.video_info/UGC data/resolveUgcVideo/WBI 签名/错误码友好提示/密钥缺失）
  - `test/bili_stream_proxy_test.dart` — 本地流代理（转发字节/Range 与响应头透传/未注册 404/start·stop 生命周期/网速 recentSpeedBytesPerSec）
  - `test/bili_auth_service_test.dart` — Web 扫码登录服务（generate 解析 url+qrcode_key / poll 成功从 data.url query 解析 Cookie+refresh_token / 86101·86090 状态）
  - `test/download_manager_test.dart` — 下载记录持久化（DownloadTask toJson/fromJson 往返 / 重启恢复未完成归位暂停·已完成保留 / 损坏数据防御）
  - `test/playback_history_test.dart` — 播放历史服务（记录去重置顶/上限淘汰/删除单条/清空/关闭记录保留已存/时长回填/持久化恢复/损坏数据防御 + 条目模型往返，§4.17）
  - `test/playback_history_page_test.dart` — 历史记录页（空态/条目渲染/垃圾桶按钮删除单条落盘/清空二次确认取消与确认/无历史禁用清空/记录开关持久化）
  - `test/url_media_test.dart` — 在线直链纯函数（规范化补协议/内部空白拒绝/scheme 形态不补/协议白名单/标题提取解码与兜底，§4.17）
  - `test/open_link_dialog_test.dart` — 打开链接弹窗（有效链接回调并关弹窗/自动补协议/无效行内提示不关弹窗/取消不回调/**回调内 push 不被弹掉**：先关弹窗再进播放页的回归）
  - `test/device_services_external_video_test.dart` — 外部打开视频通道封装（takeExternalVideo/resolveVideoUri 返回解析/空值降级/通道异常静默，§4.17）
  - `test/player_status_bar_net_speed_test.dart` — 顶部信息行网速来源分流（直连播放走 directNetSpeedReader/B 站代理命中不走 reader/reader 返回 null 不崩/本地播放隐藏胶囊，§4.17）
  - `test/cast_source_test.dart` — 投屏源分类纯函数（本地/直链/loopback/content + file:// 去前缀 + loopback 判定，§4.18）
  - `test/lan_media_server_test.dart` — 局域网媒体服务器（LAN URL 格式/全量+Range 拉流/错误 token 404/stop 释放/文件不存在抛错 + isSiteLocalIpv4，§4.18）
  - `test/cast_service_test.dart` — 投屏服务（isMediaRenderer 过滤 + CastDevice.kind，§4.18）
  - `test/privacy_policy_settings_test.dart` — 隐私政策同意状态服务（默认未同意/同意持久化/load 恢复，§4.19）
  - `test/privacy_policy_dialog_test.dart` — 隐私弹窗（5 秒倒计时门禁/勾选同意才可确认/取消返回 false 同意返回 true，§4.19）
  - `test/version_compare_test.dart` — 版本号比较纯函数（v 前缀/逐段整数比较/缺段补 0/数字前缀，§4.20）
  - `test/update_settings_test.dart` — 更新设置服务（默认开启/开关持久化/忽略版本持久化，§4.20）
  - `test/update_dialog_test.dart` — 更新弹窗（三按钮齐全/Markdown 无原生符号/忽略落盘/立即更新弹子菜单与 Toast，§4.20）
  - `test/wyzie_models_test.dart` — Wyzie 字幕数据模型 fromJson（字段映射/容错/常量表，§4.21）
  - `test/wyzie_query_test.dart` — Wyzie 查询纯函数（来源/逗号参数拼接/语言代码归一化/客户端过滤，§4.21）
  - `test/wyzie_filename_test.dart` — Wyzie 落盘文件名纯函数（非法字符清洗/拼装/同批消重，§4.21）
  - `test/wyzie_settings_test.dart` — 字幕下载设置服务（默认值/密钥 trim/空集回退 all/持久化恢复/损坏防御，§4.21）
  - `test/wyzie_api_test.dart` — Wyzie API 客户端（MockClient：来源/关键词→TMDB→搜索参数/400 无字幕特判/非 2xx/文件字节，§4.21）
  - `test/subtitle_download_page_test.dart` — 影视字幕下载页（字幕设置入口/子页五入口/语言多选摘要联动/API 密钥弹窗取消·保存回归/未设密钥搜索 toast，§4.21）
  - `test/settings_page_bili_login_test.dart` — 「我的」页 B 站下载入口登录门禁（未登录点击弹幕/视频下载 toast 提示登录，§4.16）
  - `test/dolby_vision_settings_test.dart` — 杜比视界「不再提示」记忆（默认未抑制/勾选持久化/取消，§4.23）
  - `test/device_info_page_test.dart` — 设备信息页（设备信息/HDR 能力/关键编码器/解码器清单渲染 + 筛选胶囊（无数字文本/两行布局）+ 失败降级重试 + 点解码器进详情页显示完整能力，§4.24）
  - `test/theme_controller_test.dart` — 主题控制器（默认值/预设 23 色/调色板 21 标签/自定义色持久化与 seed 生效/动态色标记置位·持久化·切换清除，§4.7）
  - `test/appearance_page_test.dart` — 外观页（主题色网格 + 动态色 + 自定义入口渲染/调色板胶囊化与标准型独占/动态色 Android<12 toast/自定义选色弹窗，§4.7）
  - `test/anime4k_patch_test.dart` — Anime4K 着色器安装期优化（pass 切分/精度注入/FSR highp 白名单/函数签名与已限定符不动/空行不中断注入/C.R.E.L.U. 3×3 合并与越界退回/幂等/全部 assets 烟测，§4.25）
  - `test/mpv_tuning_test.dart` — mpv 调参模板（顶层逗号切分保留 protocol_whitelist/lavf-o 合并与缺失返回 null/本地与在线两档/不含 reconnect_at_eof，§4.26）
  - `test/player_diagnostics_test.dart` — 播放诊断纯函数（属性表→快照容错/格式化/健康告警优先级与阈值，§4.27）
  - `test/player_diagnostics_panel_test.dart` — 播放诊断面板（四组数值渲染/缺失占位/丢帧·软解告警卡/读取失败降级/定时刷新取新值，§4.27）
  - `test/retry_policy_test.dart` — 统一网络重试与快速失败（超时分级/可重试判定与响应中断排除/指数退避/withRetry 行为与流式不重试/体积上限 content-length 预判与边读边判/端到端 MockClient，§4.28）
  - `test/async_primitives_test.dart` — C1 并发原语（会话号递增与作废·旧请求丢弃/在飞去重共享与失败不缓存/串行队列顺序·无重叠·异常不打断·idle，§4.29）
  - `test/common_list_controller_test.dart` — C2 分页控制器（三态/刷新失败保留旧列表/空结果也是 Loaded/加载更多与 hasMore/并发防重入/reset/describeError/dispose，§4.29）
  - `test/bili_playlist_test.dart` — 番剧播放列表模型（季详情/剧集数组构造、集号 1 起、按 epId 定位、hasNextAt/itemAt 边界、标题回落与角标透传，§4.15）
  - `test/player_bili_playlist_panel_test.dart` — 番剧剧集列表面板（头部集数进度/条目集号集名角标/当前集播放中/点击回调并关闭/空态，§4.15）
  - `test/bili_search_page_test.dart` — 番剧搜索页（未搜索提示/搜索渲染/触底加载更多/失败重试/无结果空态，§4.29 C2）
  - `test/subtitle_font_injection_test.dart` — 字幕字体注入判定纯函数（`resolveSubtitleFontInjection` **永不返回 null**：默认/空目录回落 `/system/fonts`；族名+目录齐备才注入用户字体；空族名也回落，§4.10/§4.32）
  - `test/folder_pin_test.dart` — 固定文件夹排序纯函数（稳定前置/固定项之间仍保序/视频不受影响/分组无变化原样返回 + 树状逐层递归/重建保留聚合信息，§4.30）
  - `test/file_ops_test.dart` — 文件管理纯函数（路径细分/目标校验含自己子目录拦截/重命名合法性与非法字符/**扩展名锁定**：预填主体·恒拼原扩展名·重复后缀不叠加·只输扩展名报错/重名避让序号插入位置/失效固定路径推导，§4.30）
  - `test/pinned_folders_settings_test.dart` — 固定文件夹设置服务（默认空/toggle/setPinned 幂等/**setPinnedAll 批量只通知一次**/replaceAll 通知语义/只读快照/持久化冷启动读回/损坏数据防御，§4.30）
  - `test/file_selection_test.dart` — 多选纯函数（目录树递归索引 + 缺 video 字段防御/视频索引/按点选顺序取值/失效路径丢弃，§4.31）
  - `test/file_selection_controller_test.dart` — 多选状态控制器（begin 立刻选中长按项且清掉上次选择/非多选态 toggle 无效/取消到 0 项仍在多选态/exit 幂等不重复通知/全选/containsAll 空列表不算全选/retainExisting 无变化不通知/只读快照，§4.31）
  - `test/file_operations_ui_test.dart` — 多选 UI（选择工具栏：数量·全选↔取消全选·0 项时 ⋮ 置灰·× 退出；长按菜单多选态裁剪：撤重命名与多选、固定仅纯文件夹；删除弹窗：单选/多选文案 + 「删除所有文件」勾选框显隐与结果，§4.31）
- 改以下代码必须跑对应测试：`AppFrame`、`ViewSettings` 排序、权限流程、`CapsuleNavBar`

---

## 7. 已知注意事项（踩过的坑）

> 文档约定（工作.md 第 1 点）：**本表必须精简**——每条只写「坑 → 防护」一句话，
> 不展开论述；新坑补一行即可。

| 坑 | 防护 |
|---|---|
| 固定按绝对路径存储后路径变更失效 | 重命名/移动/删除后统一 `retainExisting(additionalStale: stalePinnedPaths(...))` 清理；改名时 `wasPinned` 必须在清理前读（§4.30） |
| 长按菜单 RenderFlex 溢出（标题行 + 五项超出外壳可用高度） | 菜单不带标题行 + `ListView(shrinkWrap)` + `isScrollControlled`，矮屏可滚动（§4.30） |
| 重命名把扩展名改掉 → 文件从播放列表消失 | 锁扩展名：预填主体 + 右侧固定后缀 + 恒拼回原扩展名（§4.30） |
| 挖孔屏横屏白条 / 系统栏露浅色背景 | AppFrame `left/right` 恒 false + 播放页豁免 bottom + ColoredBox 铺色（§4.2） |
| 播放页退出闪烁/黑屏（错向界面 ~1s 或退出黑一下） | 退出**同一帧 `pause()` 冻结末帧**（不再先 dispose 黑屏渐隐）+ IO `unawaited` + 无动画瞬时 pop；竖屏退出下层 `_exitBlackout` 黑化（§4.4） |
| 面板红底黄字崩溃（No Material） | PlayerPanel / PlayerBottomPanel 外壳必须用 `Material`，勿换 Container；拖拽 `proxyDecorator` 也用 `Material`（`ColoredBox` 非 Material，拖拽时 proxy 被放 overlay 脱离外壳会崩）（§4.5） |
| 面板内 `Navigator.of` 断言 scope==null | 内容先包 `Builder` 取面板树内 context 再调 `of`（§4.5） |
| 全局 ValueNotifier hack 引发连锁补丁 | 禁止；跨页面用 ChangeNotifier / 路由机制（§4.1） |
| DSH 沙箱卡住 flutter/dart 子进程 | `flutter analyze/test` 必须 danger-full-access 执行；勿用 `flutter --version` 探路 |
| `flutter analyze` 的 `--fatal-infos`/`--fatal-warnings` **默认均为 on** → 只剩 info 也 exit 1，CI 门禁误判失败 | 需要放行时两个 flag 都要加：`--no-fatal-infos --no-fatal-warnings`；否则先把问题清干净 |
| mpv 着色器要绝对路径 / 切集后失效 | 拷贝 assets 到应用目录拼绝对路径；open 后与切集后都 `apply(player)` |
| 均衡器与声道/处理共享同一 `af` 属性 | 均衡器命名滤镜（`@eq/@bass/@virt`）统一由 `buildAudioFilterChain` 拼进 `af` 属性串、由 `applyAudioOptions` 一次性 `setProperty('af')`，勿另用 `af add`（会被整体覆盖）；「启用均衡器」开关同时门控低音增强与虚拟环绕（关时传 0，但存储值保留） |
| EOF 防重入（切集瞬间残留事件） | `_isSwitchingVideo` + `_isHandlingEndOfFile` 双标志 + 位置到结尾校验 + 纯函数 `resolveEndOfFileAction` |
| `Media(start:)` 失效（media_kit 1.2.x on_load hook 读到 playlist-pos=-1 跳过 start） | 弃用；恢复统一走 `openAndRestore`（`utils/playback_restore.dart`）。⚠️ v5.2 曾试 `open` 前 `setProperty('start')` 加载期定位，实测恢复失效，已还原 v5.1 |
| 恢复进度"从头播"（暂停态 seek 只改 time-pos、不改解码器，指示器跳但视频从头） | `openAndRestore`：`open(play:false)` 暂停加载 → 等时长 → **静音 `play()` 激活时间线** → 等位置推进 ≥150ms → `seek` → 位置流确认（重试一次）→ 位置**越过恢复点一 tick**（目标帧已上屏）才揭开不透明封层 → 取消静音 |
| 恢复进度"跳到又跳回 / 读取竞态" | `PlaybackProgressService` ensureLoaded（读盘完成后再置 `_loaded`）+ `_writeChain` 串行写盘 + 退出/切集 `save(forcePersist:true)` |
| 恢复进度指示器残留/不显示 | 只有 `openAndRestore` 返回 true 才显示；2.5s 自隐藏；竖屏/锁定竖屏由 `initialResumeVisible` 接住 |
| 已看完视频恢复后立即 EOF 连播 | `_resumeStartFor` 阈值过滤（<5% 或 ≥已观看阈值 → 不恢复从头播） |
| 循环播放无限恢复已看完视频 | `shouldRestorePosition`：<5% 或 ≥已观看阈值不恢复 |
| 横竖屏切换卡顿/黑屏/音频断 | v3：共享同一 Player/VideoController，竖屏页只换布局不重开；EOF 由当前栈顶页处理 |
| 竖屏返回不能直接退出 / 退出露横屏页 | 竖屏返回走 `_backExit` → `_exitWithPortrait`（先 `_exitBlackout` 黑化下层 → `pause()` → IO unawaited → 连 pop 竖屏页 + 横屏页，下层纯黑防「两个竖屏界面」复现）；「选择屏幕」仍仅回横屏 |
| 竖屏锁定不生效 | 手势层传 `locked`，各手势回调补 `if (_locked) return` |
| 手机竖拍视频仍横屏播放（自动方向） | 竖屏判定结合 `VideoParams.rotate`（90/270 时宽高互换，参考 KT：`video-params/aspect` + rotate 修正）；⚠️ 用**原始 w/h**（`videoParams.w/h`）而非 `state.width/height`（后者已被 media_kit 按 rotate 交换成显示尺寸，再套 rotate 会双重交换误判） |
| 画面比例不实时生效 | Video 外包 `ListenableBuilder(listenable: 设置)`；⚠️ 4:3→自动失效根因：media_kit `VideoViewParameters.copyWith(aspectRatio: null)` 保留旧值 → Video 加 `key: ValueKey(fit.index)` 强制重建 |
| 音量手势被系统音量封顶 | v3：手势直控系统媒体音量，mpv 音量固定 100；退出按「保存到系统」写回/恢复 |
| 窗口亮度泄漏到列表页 | 退出双重恢复 `setWindowBrightness(null)`（原生 -1 交还系统） |
| Material Slider 轨道起点无法对齐 | 自绘进度条 `player_seek_bar.dart`，起点精确落 `kPlayerLeftInset`，勿改回 Slider |
| 播放页整页随位置流高频重建 | 位置/时长抽页面级 `ValueNotifier`，底栏/进度线 `Listenable.merge` 局部订阅（§4.1） |
| 快速退出→进入刷假崩溃日志 | `_disposed` 标志 + 每个 await 后查 disposed/mounted + `openAndRestore`/`_openAndSetRate` 等 `on AssertionError` 兜底静默返回 |
| 播放进度表每次全量序列化 | `save` 30s 节流 + `_writeChain` 串行化 |
| 设置单例 load 竞态 | `ensureLoaded()` + 全部 setter 首行 await（risk_audit #9） |
| 播放界面动画无法关闭 | 「启用播放界面动画」设置：动画控制器时长归零 / `animate=false` 零时长转场 |
| MethodChannel 小整数是 Integer 非 Long | 取整型参数一律 `call.argument<Number>()?.toLong()/toInt()` |
| MediaMetadataRetriever 取帧不可靠 | 仅剩列表封面用（`getVideoInfo`）：SYNC/CLOSEST 独立 try/catch；进度条抓帧已换 FFmpeg 引擎（§4.9） |
| 缩略图缓存无限增长 / 体积大 | 进度条缩略图=纯内存 LRU 32MB（RGBA 字节计，播放页退出清空，无磁盘）；列表封面 384×216+q70 磁盘缓存由缓存管理页清理 |
| libmpv hidden visibility 吞掉新增符号 | 内核新导出函数必须经 `client.h` 的 `MPV_EXPORT` 声明携带可见性（.c 里 include client.h） |
| `Isolate.run` 闭包捕获 Completer → unsendable 崩 | `Isolate.run` 放**独立静态函数**、只捕获原始值；同作用域兄弟闭包捕获的对象会被编译器合并进上下文一起发送 |
| Flutter 插件统一构建目录（build/<插件名>）残留旧 jar | 官方下载式 libs 包改本地分发时，`fileTree` 直接指向 `android/jars/` 源目录，勿用「下载→复制到 build/output」模式（assemble 钩子不保证执行 + Gradle 9 隐式依赖校验报错） |
| media_kit seek 落最近关键帧（与预览帧对不上） | 播放器初始化设 mpv `hr-seek=absolute`（对齐 mpvRx 的 `seek absolute+exact`） |
| 松手后缩略图气泡不消失（要点屏才走） | 改变挂载条件的状态必须 `setState`；现走显式 `visible` 标志 + 定时器淡出后卸载 |
| 列表首屏并发拉元数据 | `VideoInfoService` 在飞去重（同 path 共享 Future） |
| 听视频共享 Player 语义 | 听视频页不建播放器/不恢复进度；切歌从 0 开始、切走前保存进度；EOF 由听视频页处理（播放页 `_audioActive` 让位）；循环三态：关闭/单曲/列表（点击循环按钮切换） |
| 听视频退后台自动暂停 | 阶段1 第 2 点：进入听视频启动前台服务（`BackgroundPlaybackService`，mediaPlayback 类型）保活进程，mpv 音频在后台继续播放；退出听视频停服务；前台服务仅保活不带媒体控制 |
| 外挂字幕 content:// 无法直接给 libmpv | `sub-add` 前先由原生侧拷贝到 `filesDir/subtitles/`（`copySubtitleFromUri`）；自建选择器直接返回文件真实路径 |
| 字幕切集后消失/勾选丢失 | `SubtitleController.reapplyForMedia` 按媒体路径去重后重新 `sub-add` 全部外挂字幕，并按 `external-filename`（源路径）恢复主/次勾选（轨道 id 重开会变） |
| 内嵌 ASS 字幕被强制换样式 | 默认 `sub-ass-override=no`（尊重自带样式字体）；开启「强制覆盖内嵌样式」才 `force`；主字幕为文本格式时用户样式恒生效 |
| 字幕面板在横竖屏外壳下导航器类不同 | 面板二级页推页由页面注入回调（横屏传 `PlayerPanelNavigator`、竖屏传 `PlayerBottomPanelNavigator`），面板不直接依赖外壳（§4.5 Builder 约定） |
| 听视频随机播放 | 纯函数 `audioShuffleNextIndex`：当前时刻折叠种子 + 乘性散列，不重复当前曲目（可单测） |
| 播放页顶部信息行 | 原生 `getBatteryLevel`/`getNetworkType`；时间 30s/电量 60s/网络类型 5s 刷新；四样多选（时间/电量/网速/数据类型，默认全选）；勾了时间或电量 → 时间电量居中、网速+数据类型靠右，否则网速+数据类型居中；网速胶囊仅在线播放显示（本地一律隐藏，`isOnlineMedia`）；渐变由播放页统一包「信息行+顶栏」一个连续渐变（勿各画各的，防断层）；竖屏压缩高度 |
| 许可证书页 | 折叠式改为列表 + 二级详情页（可复制），不用 ExpansionTile |
| 画中画进出检测 / 宽高比 | 用 `didChangeAppLifecycleState` 判断进出 PiP；`pipAspectRatio` 约分 + 0.5–2.39 钳制 |
| 超分 UI 不刷新 / 看不出效果 | 面板用 `ValueNotifier` 实时刷新；720p 以下动漫 + 激进档位测试 |
| 截图保存 / 右侧按钮背景 | `Player.screenshot` + `saver_gallery`；右侧截图/锁定固定灰黑底，不受按钮背景设置控制 |
| 全面屏手势误触 / 双指捏合误触发滑动 | 手势层死区（垂直上下 8%、水平右 8%）+ 方向确认延迟 80ms + `onSwipeCancel` 撤销 |
| 滑杆刻度过密被跳过 | `DenseSliderTickMarkShape` 声明极小宽度通过密度检查 |
| 播放器面板滑杆/强调色写死 `Color(0xFF4FC3F7)`（模块级 `ColorScheme.fromSeed` 常量），换主题色不跟随 | 改用 `playerPanelSliderTheme(context)` / `playerPanelAccent(context)`；模块级 `final` 派生的方案在首次加载时即固化，**不会**随主题重建（§5.3 第 5 条） |
| 暗色面板直接用 `Theme.of(context).colorScheme.primary` 作强调色 | 浅色主题下该色在暗底上偏暗、对比不足；必须以它为 seed 派生 `Brightness.dark` 方案后再取 primary |
| 自动亮度读不到实时亮度 | 进入播放把系统值应用到窗口，退出恢复 -1 |
| 崩溃日志无限累积 | 上限 50 条 / 10MB，读写后裁剪 |
| 关于页跳转邮件/GitHub | AndroidManifest 声明 `mailto`/`https` `<queries>` |
| 播放进度恢复重启后失效 | 恢复前 ensureLoaded；`save` 前等待加载完成 |
| 排序字段胶囊 | 排序弹窗字段选择用胶囊样式（选中主题色填充），与倍速面板视觉一致 |
| 三大金刚键遮挡 / AppBar 滚动变色 | AppFrame 全局 bottom 安全区；`app_theme.dart` 统一 `scrolledUnderElevation: 0` |
| 类成员与导入纯函数同名被解析成成员（chapter 的 `currentChapterIndex`） | 纯函数 import 加 `as` 别名（`chapter_utils.currentChapterIndex`） |
| mpv 章节子属性返回字符串、平台可能为 null | `NativePlayer.getProperty('chapter-list/$i/title'…)` 自行 parse；非 NativePlayer 静默无章节 |
| 底栏/控制组件错位跑到屏幕顶部 | Stack 非 Positioned 子项默认 topLeft 摆放：底栏等固定定位组件必须包 `Positioned(left/right/bottom)` |
| Stack 条件子项插入/移出导致无 key 兄弟错位重建（指示器动画重播） | 条件渲染的 Stack 子项（如缩略图气泡）前的有状态组件加稳定 key（`ValueKey`），防按索引错位丢 State |
| media_kit 默认 `libass:false` → mpv `sub-visibility=no`，无 SubtitleView 时字幕完全不渲染 | 播放器 `PlayerConfiguration(libass: true)` 走原生 libass 字幕管线（`player_page.dart`）；默认 `sub-fonts-dir=/system/fonts` + `sub-font=Noto Sans CJK SC`，自定义字体走 §4.10 |
| Android libass 字体解析 | 默认 `sub-fonts-dir=/system/fonts` 直通系统字库；自定义字体在 mpv_initialize 前注入 + truetypeparser 解析族名 + 复制系统字库兜底（§4.10） |
| mpv 颜色 8 位为 `#AARRGGBB`（alpha 在前），6 位 = 不透明 | `rgbaToMpvColor`/`mpvColorToRgba`（`subtitle_track.dart`）统一转换，alpha==255 输出 6 位保兼容 |
| 打开视频后 ASS 内嵌字幕被强制覆盖样式（需切轨道才恢复原生样式） | 选中态与 mpv 实际 `sid` 同步（`reload`/`_syncActiveFromMpv`），样式策略按真实轨道判断，首帧即生效 |
| 主/次字幕功能乱且难维护 | 改单选模型（只设 `sid`）：轨道点击两态循环 选中↔关闭；移除 secondary-sid 全部逻辑 |
| 导入的外挂字幕退出播放后丢失 | `SubtitleSettings` 记忆路径列表（SharedPreferences），`SubtitleController` 构造时恢复、`reapply` 时以 `sub-add auto` 重挂（按视频独立隔离存储） |
| 重置延迟/样式不生效（apply 竞态） | 先 await 设置变更、后 await `applyAllSettings()`，禁止同一事件内不等待的并行修改 |
| 自定义字体运行时 `setProperty('sub-fonts-dir')` → libass 字体缓存打坏、字幕消失 | `sub-fonts-dir` 只在 mpv_initialize 前注入（media_kit 魔改字段）；运行时只允许改 `sub-font`/`sub-ass-override`（§4.10） |
| 手写 sfnt name 表解析器读到错误 offset（族名解析成文件名） | 族名解析用 `truetypeparser` 库，勿手写 name 表字节解析（§4.10） |
| 系统字库兜底用 symlink+隐藏文件名 → fontconfig 不识别 → 缺字空白 | 兜底字库直接复制成普通文件名（§4.10） |
| media_kit 本地 fork 被 `pub upgrade` 覆盖 | `third_party/media_kit` 共 4 处补丁需手动 merge；**升级前先读该目录 `FORK.md`**（基线/清单/步骤/验证，§4.10） |
| SAF 目录选择器重启后 tree uri 失效、无法刷新字体 | `takePersistableUriPermission` + `FLAG_GRANT_PERSISTABLE_URI_PERMISSION`/`FLAG_GRANT_PREFIX_URI_PERMISSION`（§4.10） |
| 注入**空**字体目录（或只含非字体文件）→ libass 字体解析全失败，中文字幕变**方块**（比不设置更糟） | fork 注入前用 `_hasFontFile()` 校验目录含 `.ttf/.otf/.ttc/.otc`，不合格则不注入并告警（§4.10） |
| 只设 `libassAndroidFontsDir` 不设 `libassAndroidFontName` → **静默不注入**，用户选的字体不生效 | `PlayerConfiguration` 构造函数 `assert`（debug 拦截）+ `real.dart` 告警分支（release 可见）（§4.10） |
| 字体扩展名清单两处漂移（应用层 `kFontExtensions` / fork `_hasFontFile`）→「字体已导入但被判不可用」静默失效 | 改任一处必须同步另一处（§4.10） |
| 反向立体声直接写 `audio-channels` 无效（mpv 无该布局值） | 反向立体声改走 `af` 滤镜 `pan=[stereo|c0=c1|c1=c0]`，并把 `audio-channels` 重置为 `auto-safe`（`buildAudioFilterChain`/`audioChannelsPropertyValue`） |
| 外部音轨/字幕 content:// 无法直接给 libmpv | `audio-add`/`sub-add` 前由原生侧拷贝到 `filesDir/audio|subtitles/`（`copyAudioFromUri`/`copySubtitleFromUri`）；自建选择器直接返回真实路径 |
| 横竖屏页各挂一个 DanmakuScreen，只保存单个渲染层引用会在返回横屏时失联（`createdController` 仅在挂载时回调一次，pop 不重触发） | 业务层用渲染层 registry 同步驱动全部已挂载层，挂载/卸载走 `attachLayer`/`detachLayer`（§4.11） |
| 横屏底栏 Expanded 内放固定尺寸按钮，分屏/自由窗口把横屏页压到 ~390dp 时 RenderFlex 溢出 | 弹幕按钮组包 `Flexible` + `FittedBox(scaleDown)`（常规宽度原尺寸，极窄等比缩小）；新增固定按钮一律照此兜底 |
| 选择器记忆文件夹在系统侧被删除后，打开停在死路径（列表空白、看似卡死，小喵 player 实际踩坑） | `listDirectory` 目录不可用返回 null（区别空目录）；打开时向上回退最近存活祖先；导航失败维持原状（§4.11） |
| 弹幕显示区域滑到 0 时 canvas 轨道数为 0（无弹幕可画） | 区域滑杆下限 0.1；「弹幕速度」语义 = 横穿屏幕耗时秒（越小越快），静置弹幕取其一半（canvas staticDuration 与 duration 无关联） |
| 弹弹Play `AppSecret` 硬编码进源码会被上传 GitHub 泄露 | 密钥存 `lib/services/dandan_play_keys.dart` 并加入 .gitignore（工作.md 第 3 点，私有禁止提交） |
| 真实密钥经**测试文件**绕过 .gitignore 泄露（签名测试写死 AppId/AppSecret 生成已知向量） | 测试一律用合成凭据（`dandan_signature_test.dart` 的 `_testAppId/_testAppSecret`）；提交前 `git diff --cached` 扫一遍 secret 字面量 |
| 互斥限制在 UI 与运行时各判一次 → 两处漂移（开关看着关着却仍在自动匹配） | 互斥只在 `DanmakuServerSettings` 裁决：`autoMatchEnabled` 为唯一生效值，UI 与 `_tryAutoMatch` 共用；偏好另存 `autoMatchPreference` 不被擦除（§4.11） |
| 开关变灰但不说明原因 → 用户当成 bug | 变灰必须同时把副标题换成 error 色原因 + 盖透明命中层点击弹 toast；文案两级都在服务层（副标题短句 `autoMatchBlockedReason` / toast 完整 `autoMatchBlockedMessage`），页面内不写字面量（§4.11） |
| 副标题写整句解释 → 窄屏挤成两行 | 副标题只放短指引（≤15 字），完整解释交给 toast；⚠️ 别用像素高度断言行数——测试字体 Ahem 每字形等宽方块，把中文行宽算得远大于真实 CJK 字体，应断言字符数等字体无关量 |
| Dart `http` 响应体缺 charset 时按 latin1 解码，中文乱码 | 统一 `utf8.decode(response.bodyBytes)`，不依赖 `Response.body`（§4.11 `dandan_play_api.dart`） |
| 网络弹幕/自动匹配只存内存，重启播放/软件即丢（切集自动匹配与装载逻辑混在一起） | 成功装载即生成 B站 XML 落盘 `filesDir/danmaku/network/` 并写入 `DanmakuManualMemory`；`loadForVideo` 记忆恢复与开关无关（§4.11） |
| 手动导入/网络弹幕重启后被当「自动加载」重复弹 toast | 「已自动加载」toast 只挂在同名自动查找路径（且每视频仅第一次）；记忆恢复一律静默（§4.11） |
| 面板内搜索框被撑到 60dp+（`IconButton` suffix 的 48dp 最小点击区 + `OutlineInputBorder` 内边距） | 自绘 40dp 定高胶囊 + `InputDecoration.collapsed` + 28dp 迷你按钮（§4.11 搜索 UI 规范） |
| `AnimatedAlign(heightFactor)` 展开动画生硬（内容被裁边挤压、长列表反复布局） | 卡片自持 `AnimationController`：高度与内容淡入淡出 `Interval` 错峰 + 收起态不构建子树 + 超 6 集用定高滚动容器（§4.11） |
| SMB smb_connect 全局互斥锁串行化读请求 → 吞吐被压到 ~1.5MB/s | fork 到 `third_party/smb_connect` 去掉全局锁、改 messageId 并发响应匹配；`smb_client` 用 4 个独立句柄并发预读（64KB 块）按块序号合并（补丁与升级步骤见该目录 `FORK.md`） |
| SMB 并发读去锁后写 socket 竞态（`StreamSink is bound to a stream`，流中断画面永远转圈） | `smb_transport` 加发送队列 `_sendQueue` 串行化「编码+写+flush」，响应等待仍走并发 sendrecv（吞吐不受影响） |
| SMB 根目录列出 ADMIN$/C$/D$/IPC$ 等管理/隐藏共享 | `smb_client.listFiles` 根路径过滤 `name.endsWith('$')`，只保留普通共享 |
| Windows 拒绝枚举共享列表却允许直连具体共享 | 路径字段留空/`/` 才 `listShares` 列共享；被拒时就填 `/共享名` 跳过枚举直连 |
| 网络浏览页按系统返回键直接退回首页而非上级目录 | `NetworkBrowserPage` 包 `PopScope(canPop:false)` 拦截系统返回，与左上角箭头一致逐级回退、到根才真正退出 |
| 播放页网速忽高忽低 / 比系统状态栏低估（周期性差分 + 突发下载采样错位） | 代理层记录每笔 chunk 时间戳，网速 = 最近 1 秒滑动窗口字节 ÷ 实际跨度，1s 刷新、不做平滑；网速胶囊在线播放常驻（本地隐藏） |
| **链接直连播放网速恒 0 KB/s**（mpv 直连远程 URL，不经 NetworkStreamingProxy/BiliStreamProxy 任何代理，两处查询均 null） | 状态栏第三来源兜底：`directNetSpeedReader` 读 mpv `cache-speed`（demuxer 吞吐估计）；⚠️ 不能给直链套本地代理——m3u8 相对分段会按代理地址解析成 `127.0.0.1/seg.ts` 而代理注册表无此 key → 404（§4.17） |
| 面板带背景色 `Container`（`_SettingsGroup`）内放 `ListTile` → 触发「ink 不可见」断言 | ListTile 外包 `Material(type: MaterialType.transparency)`（§4.12 弹幕字体段） |
| `loadFontFromList` 只对当前进程有效，首帧前未注册回落默认字体 | `main()` 改 async，`runApp` 前 await 注册 App/弹幕自定义字体（§4.12） |
| `AnimatedDefaultTextStyle` 用默认构造**不 merge** 父级 DefaultTextStyle，导致字体族名丢失（主题色/调色板/胶囊标签不跟随自定义字体） | 显式在 style 里带 `fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily`（§4.12） |
| 调研报告 HTML 里的 WBI 混淆表有误（第 28 位起与官方 64 项表不符），照抄会导致 playurl 签名集体失败 | WBI 混淆表以 bilibili-API-collect / Bili23 的 64 项表为准（§4.13）；PiliPlus 前 32 项结果等价 |
| 下载产物（dart:io/MediaMuxer 直写）MediaStore 未及时抽时长 → 列表 duration=0、进度恒「未观看」 | 落盘后 `scanMediaFile`（MediaScannerConnection.scanFile）+ `getVideos` 对 duration==0 用 MediaMetadataRetriever 兜底（§4.16） |
| B 站在线播放网速恒 0 KB/s | 状态栏拿到的 streamUrl 是 CDN 原始 URL（本地代理 URL 只在播放器内部），按 URL 匹配查不到；网络存储仍按 URL 查 `NetworkStreamingProxy`，B 站读 `BiliStreamProxy.recentTotalSpeedBytesPerSec()`（video+audio 聚合，§4.15/§4.16） |
| Web 扫码 `data.url` 已是 ticket 换凭证（旧文档 query 带 SESSDATA 的格式过时）；实测 crossDomain 302 对非浏览器客户端**不下发 Set-Cookie**（逐跳跟随亦然） | 登录走 TV 通道（凭证直接在 poll JSON，PiliPlus 同款）；勿再按旧文档实现 Web 扫码（§4.13） |
| 轮询到 code=0 但凭证缺失时静默 cancel 定时器 → 页面冻结无反应（倒计时卡死） | 成功但凭证为空时 toast+刷新重试，勿静默 cancel（§4.13） |
| 外部 content:// 视频直接喂 libmpv 打不开 | 原生三级解析：MediaStore DATA 列 → documentId → 拷贝 cacheDir/external_open/（§4.17） |
| **弹窗「确认→push 播放页→pop 弹窗」顺序错 → 点播放毫无反应**（`Navigator.pop()` 弹的是**栈顶**，先 push 再 pop 会把刚 push 的播放页弹掉、弹窗残留；对任何链接都中招，曾被误报为「不支持 m3u8」） | 弹窗确认必须**先 pop 自己再回调**（open_link_dialog.dart `_confirm`，§4.17） |
| **intent-filter 只声明 MIME 不声明 scheme → scheme 默认仅 content/file，外部播放器以 `http URL+video/*` 查询时匹配不到**（「调用外部播放」列表里没有本应用） | scheme(content/file/http/https) 与视频 MIME **声明在同一过滤器**（mpvRx 同款，§4.17） |
| mkv/m3u8 的 MIME 是 `application/x-matroska`/`vnd.apple.mpegurl`，**不以 video/ 开头**——原生按 video/* 前缀过滤会把这类外部拉起误拒（点了没反应） | `isVideoMimeType` 用与 manifest 同步的注册集合判定（§4.17） |
| 网络存储的 `127.0.0.1` loopback 代理 URL 退出即失效，写入播放历史成死链 | `_recordPlaybackHistory` 按 loopback 前缀过滤；B 站在线播放走 `_biliMedia` 分支天然不记录（§4.17） |
| Dart `Uri` 对含空格 host 宽松（`https://not a url` 能解析）；裸补 `https://` 会把 `mailto:` 错位成 userinfo | URL 校验先拒内部空白；`scheme:` 形态不补协议，交给白名单判定（`utils/url_media.dart`，§4.17） |
| 在线直链的章节信息无需网站接口 | mpv/FFmpeg 解封装远程容器原生读 chapter（MKV 内嵌章节），现有 `ChapterTracker`（mpv chapter-list）天然覆盖 URL 播放（§4.17） |
| 投屏 LAN 服务器绑 127.0.0.1 → 电视拉不到流 | 绑 `0.0.0.0` + URL 用手机局域网 IPv4（`isSiteLocalIpv4` 挑站点本地地址、排除回环）（§4.18） |
| 门禁弹窗被点遮罩/系统返回键关闭（用户未同意也能进入） | `showAppDialog(barrierDismissible: false)` + 内容包 `PopScope(canPop: false)`；确认按钮 `enabled = 倒计时归零 && 勾选同意`（§4.19） |
| 弹窗里 `TextEditingController` 在 `showAppDialog` 返回后立即 dispose → 退出动画期间 TextField 仍 rebuild 引用它 → 红屏崩溃 | 控制器由弹窗 `StatefulWidget` 自持（initState 建 / dispose 释放），随路由完全卸载才释放，勿在 `await` 后手动 dispose（§4.21） |
| saver_gallery 不传 `albumPath` 时按 MIME 落默认根目录（截图/二维码直落 `Pictures/`，无父级文件夹） | `saveImage` 传 `albumPath: '小喵Player'` → 落 `Pictures/小喵Player/`（§4.8 截图 / §4.13 保存相册） |
| 章节跳段设置变化 → `ChapterTracker` 用 `resolveSkipSegments` 重派生，把 B 站 `clip_info_list` 的精确 OP/ED 起止覆盖成「下一章起点」（OP 结束错扩到 ED 起点） | 外部精确片段（`setExternalChapters`）打 `_externalSegments` 标记；`_onSettingsChanged` 只在非外部时重派生，外部只清已跳过记录（§4.22） |
| 整应用重启 `exitProcess` 编译报 Unresolved reference | `exitProcess` 是 `kotlin.system.exitProcess`，需显式 import（§4.24） |
| 解码器筛选胶囊文字出现「…」省略号（等宽均分后窄胶囊放不下） | 胶囊文字去掉 `maxLines`/`TextOverflow.ellipsis`，改 `softWrap:false` 单行居中；胶囊只放纯文本「音频/硬解/软解/视频/全部」（不带数字）（§4.24） |
| 着色器优化改了算法但沙盒里还是旧文件（改了等于没改） | 用 `.patch_version` 记录补丁版本，算法改动必须 bump `kAnime4kPatchVersion` 才会重写已拷出的着色器（§4.25） |
| Anime4K 头与正文之间的空行让精度注入整体失效（mpvRx 原实现遇到空行即放弃该 pass） | 空行视为头部间隙继续找首个正文行；pass 边界用 `//!DESC` 切分（缺失回退 `//!HOOK`），勿按 `//!HOOK` 切（会把一个 pass 拆两块）（§4.25） |
| C.R.E.L.U. 采样合并遇到 >3×3 偏移会引用未声明的 `t_unknown_*` → 整个着色器编译失败被 mpv 丢弃 | 合并结果含 `_unknown` 时**整体退回原 pass**（正确性不依赖内核是 3×3）（§4.25） |
| 覆盖 `demuxer-lavf-o` 抹掉 media_kit 的 `protocol_whitelist=[udp,rtp,...]`（值内含逗号）→ m3u8/自定义协议失效 | 按**括号深度**切分后合并再写；读不到旧值就不写该键（§4.26） |
| 播放调参在 open 之后写入 → 对当前文件无效 | 解封装缓存/重连参数只在 open 前生效：调参放 `_applyPlaybackTuning(path)`，首开/切集/B 站三处 open 前各调一次（§4.26） |
| 重试时复用同一个 `http.Request` → 「Request has already been sent」 | 重试闭包内**新建** Request（`sendGet`、短链展开每跳都新建）（§4.28） |
| 响应超限时用 `drain()` 丢弃 → 把上游巨量响应全部下载下来 | 超限一律 `stream.listen(null).cancel()` 取消订阅（一个字节都不读）；错误响应的丢弃用 `drainStreamCapped`（带上限）（§4.28） |
| 想直接用 mpv 内置 stats/console 页（mpvRx 的 7 页统计） | 本项目自编 libmpv **未编译 Lua**，`script-binding stats/...` 静默无反应；改用 Dart 侧读 mpv 属性自建诊断页（§4.27） |
| 用 PowerShell `Set-Content`/`Get-Content -Raw` 改源码 → UTF-8 被写成 ANSI，中文全乱码 | 源码编辑一律用编辑工具（edit/write）；确需 PowerShell 写文件时用 `[System.IO.File]::WriteAllText` + `UTF8Encoding($false)`（§4.28 排查记录） |
| 分页控制器「加载成功但结果为空」被当成加载中 → 空列表永远转圈 | `CommonListController` 用 `_hasLoadedOnce` 区分「未加载」与「加载过但无数据」，空结果返回 `Loaded([])`（§4.29 C2） |
| 分页列表刷新失败直接把旧数据清空 + 报错 | 刷新失败只记 `error`（保留 `Loaded` 与旧数据）；换关键词/筛选条件才 `reset()`（§4.29 C2） |
| 在飞去重手写 Map + try/finally 分散多处、失败会把错误粘住 | 统一用 `AsyncSingleFlight`（失败不缓存、完成即清记录）；串行写盘用 `AsyncSerialQueue`（§4.29 C1） |
| 番剧在线播放「下一集」置灰、播放列表显示「当前文件夹没有视频」 | 播放页持有整季剧集列表（`biliPlaylist`）：`_hasNext`/`_playNext`/`_playFirst`/EOF `hasPlaylist`/列表面板全部按 `epId` 定位；启动器缺列表时与 playurl 并行补拉季详情（§4.15） |
| 弹幕合并与去重同时开启（语义冲突：一个丢重复、一个数重复） | 服务层互斥：`setDeduplication(true)` 关合并、`setMerge(true)` 关去重，互斥裁决只在 `DanmakuSettings` 一处（§4.11） |
| 弹幕合并放在去重之后 → 计数被去重吃掉（去重会丢弃窗口内重复条目） | 流水线固定「屏蔽词 → **合并** → 去重」；合并写 `DanmakuEntry.count`、文本保持原样（§4.11） |
| canvas_danmaku 的 `count` 只在描边段落里绘制 → 描边宽度设 0 时计数不可见 | 不用 canvas 的 `count`，改为把 `×N` 拼进显示文本 `DanmakuEntry.displayText`（§4.11） |
| 会员渐变彩色弹幕标记只在 protobuf（`DanmakuElem.colorful` 字段 24）里，XML 缓存不保留 | 在线播放走 protobuf 主路径可拿到；`danmakuEntriesToBiliXml` 落盘回读只剩普通颜色（当前 `loadCachedDanmaku` 无调用方，不影响播放）（§4.11） |
| 多选操作条放屏幕底部 → 压住主 tab 页的悬浮胶囊导航（`MainScaffold` 用 `Stack` 叠加在内容之上，列表已留 88 padding） | 多选入口放**顶部 AppBar 上下文工具栏**（`[×] 已选 N 项 [全选] [⋮]`），底部不新增任何常驻条（§4.31） |
| 传输进度弹窗「取消」里 `dialog.pop()`，`finally` 又 pop 一次 → 第二次弹掉的是**页面本身**（详情页被直接退出） | 进度弹窗用只 pop 一次的句柄 `_ProgressHandle`；`dismiss`（关弹窗）与 `dispose`（释放通知器）分离，避免在途进度回调写已释放的 `ValueNotifier`（§4.30） |
| 删除确认弹窗的「删除所有文件」勾选框只认多选参数 `folderCount` → 单删文件夹时勾选框消失，整目录删除能力静默丢失 | 判据同时认 `isDirectory`（单选入口）与 `folderCount`（多选入口），两条路径都不退化（§4.30/§4.31） |
| 多选状态做成全局单例 → 跨页 / 跨会话残留选择 | `FileSelectionController` 由页面 `State` 持有并 `dispose`，不单例不持久化（§4.1/§4.31） |
| 运行期写 `sub-fonts-dir`（含「默认字体」分支写 `/system/fonts`）→ 重载 libass fontconfig 缓存，**位图字幕（PGS/DVD/DVB）与文本字幕一起不渲染**（真机：四条 PGS 选哪条都不显示） | 字体目录只在 `PlayerConfiguration` 构造期注入，且**默认也必须注入**（`resolveSubtitleFontInjection` 永不返回 null，注入 `/system/fonts`）；运行期只写 `sub-font`（§4.10/§4.32） |
| 切到 Dolby TrueHD（MLP FBA / `A_TRUEHD` / 8 channels）音轨后完全无声且无任何提示 | 真因是自编内核 ffmpeg 白名单漏了 `mlp`/`truehd` 解码器（`--enable-demuxer=truehd` 只是解封装器！）；内核已补该两条并重出 jar。应用侧同时兜底：换轨后 4 秒窗口内消费 `Player.stream.log`，`isAudioPlaybackFailureLog` 命中后读 `audio-params` 复核，再自动回退到不同编码的音轨并 toast（§4.32） |
| 内嵌 PGS（蓝光位图）字幕能列出、选中却不显示 | 真因是自编内核 ffmpeg 白名单漏了 `hdmv_pgs_subtitle` 解码器（同段已开 `dvbsub`/`dvdsub`/`ass`，唯独漏 PGS）；已在内核补齐。排查时**勿用长名字符串**判断解码器是否存在（`--enable-small` 会把 `long_name` 编掉），用解码器短名 `strings libmpv.so \| grep -c '^hdmv_pgs_subtitle$'`（§4.9/§4.32） |
| mpv 报错只进 `Player.stream.log`，应用侧不消费 → 用户看到「点了没反应」的静默失效 | 需要感知播放故障时订阅 `stream.log`（`logLevel` 默认已是 `error`，`PlayerLog.prefix` 区分 `ad`/`ao`/`vd`/`stream`）并**先复核再动作**，且尽量限定在「刚发生的操作」窗口内，不要仅凭一条日志改状态（§4.32） |
