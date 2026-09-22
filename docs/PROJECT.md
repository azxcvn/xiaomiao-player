# 小喵Player 技术文档

> 面向开发者的项目技术说明：项目能力、技术栈、代码结构、分层约定与各模块职责。
> 架构决策的详细理由、踩坑记录与历史演进见 `docs/archive/ARCHITECTURE.md`。

---

## 1. 项目简介

小喵Player 是一个 **Flutter 本地视频播放器（Android）**，以本地媒体库播放为核心，向上叠加字幕、弹幕、音频处理、网络存储、哔哩哔哩生态、下载、投屏等能力。

主要能力：

| 分类 | 能力 |
|---|---|
| **媒体库** | 扫描本地视频（MediaStore + 「允许管理所有文件」权限）；**列表模式**（含视频的文件夹 → 详情页）与**树状模式**（逐级目录导航 + 面包屑），两种模式共用同一套卡片组件 |
| **播放器** | media_kit（自建 libmpv 内核）横屏沉浸式全屏；播放进度持久化；进度条缩略图实时预览（拖动所见即落点 + 章节名胶囊）；超分辨率（Anime4K v4，7 档模式 × 3 质量档）；片头片尾自动跳过 |
| **音频** | 内嵌音轨切换 + 外部音轨导入/移除；音频声道（自动/安全自动/单声道/立体声/反向立体声）；音频处理（音量标准化 / 动态范围压缩）；不可播放音轨自动回退；**均衡器**（5 频段 + 低音增强 + 虚拟环绕 + 6 预设） |
| **字幕** | 内嵌轨道 + 外挂导入（Android ≤11 系统选择器 / >11 自建选择器带排序与文件夹记忆）+ 同名字幕自动加载；延迟/样式/杂项/字体四类设置（RGBA 调色、ASS 强制覆盖、自定义字体走 libass） |
| **弹幕** | canvas_danmaku 渲染；本地弹幕（9 种同名规则 + 手动导入）；网络弹幕接入弹弹Play（搜索 / 自动匹配 / 服务器管理）；完整样式与配置设置（字号/字重/速度/描边/不透明度/区域/行高/三类显隐/去重/屏蔽词/时间轴偏移/自定义字体） |
| **听视频** | 共享 Player 只播音频，封面模糊背景 + 1:1 圆角封面 + 胶囊式倍速/列表面板 + 定时关闭 + 后台播放（前台服务保活）+ 时间刻随机播放 |
| **网络存储** | WebDAV / SMB / FTP 三协议；本地回环流代理供 mpv 拉流；密码只进加密存储 |
| **哔哩哔哩** | TV 扫码登录（WBI 签名 + 反爬指纹 + 凭证加密）；番剧索引/搜索/详情/时间表；在线播放（DASH 双流 + 清晰度切换 + 原声弹幕 + OP/ED 章节 + 整季播放列表）；弹幕/视频下载 |
| **下载** | 任务队列 + Range 流式续传 + 原生 MediaMuxer 合并（video.m4s + audio.m4s → mp4）+ 跨重启持久化 |
| **投屏** | DLNA/UPnP SSDP 发现渲染器 + 局域网媒体服务器推流 |
| **文件管理** | 文件夹与视频长按动作菜单（复制 / 移动 / 重命名 / 删除）+ 文件夹固定 + 页面级多选批量操作 |
| **外观** | 23 种主题色 + 21 种调色板风格（flex_seed_scheme）+ 动态色（Android 12+ 壁纸取色）+ 自定义选色；App 全局字体与弹幕字体 |
| **其它** | 系统播放器注册（外部「打开方式」/ 浏览器直链，content:// 三级解析）、播放历史、打开链接直连播放、设备硬件与编解码能力检测、播放诊断页、隐私政策门禁、应用更新检查、崩溃日志 |

---

## 2. 技术栈

| 项 | 说明 |
|---|---|
| 框架 | Flutter 3.44+ / Dart 3.12+ |
| 播放内核 | media_kit + 自建 libmpv（`third_party/media_kit` 本地 fork，含 4 处补丁；内核含 `mk_thumbnail_*` 抓帧接口） |
| 状态管理 | `ChangeNotifier` + `ListenableBuilder`（`Listenable.merge`）；持久化用 `shared_preferences`，密钥类用 `flutter_secure_storage` |
| 弹幕渲染 | `canvas_danmaku` |
| 主题 | `flex_seed_scheme`（Material 3 色板派生） |
| 网络 | `http`（纯 Dart）+ `smb_connect`（本地 fork） |
| 原生 | Kotlin（`android/app/src/main/kotlin/com/azxcvn/moumou/`）：MethodChannel `moumou/video_info` + 前台服务 + 崩溃处理 |
| 依赖清单 | 见 `pubspec.yaml` |
| **项目许可** | **GNU General Public License v3.0（copyleft）** —— 全文见仓库根目录 `LICENSE`；衍生分发须以同一许可开源并提供对应源码。第三方组件清单见 `THIRD_PARTY_NOTICES.md` |

---

## 3. 代码结构（`lib/`）

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
│   ├── audio_track.dart       # 音轨模型 + 声道枚举 + 格式过滤 / af 滤镜链纯函数
│   ├── subtitle_track.dart    # 字幕轨道模型 + 展示名/格式过滤/对齐/颜色/RGBA 转换/字体过滤纯函数
│   ├── super_resolution_mode.dart  # 超分模式 / 质量枚举 + 着色器链构建纯函数
│   ├── equalizer_preset.dart  # 均衡器预设模型（14 预设 + 频段标签 + 反查/相等纯函数）
│   ├── danmaku_entry.dart     # 弹幕条目纯数据模型（时间/模式/颜色/文本 + 合并计数 + 会员彩色标记）
│   ├── danmaku_server.dart    # 弹幕服务器配置模型（默认弹弹Play + 自建服务器）
│   ├── dandan_models.dart     # 弹弹Play API 数据模型（番剧/集/评论/匹配候选）
│   ├── network_connection.dart # 网络存储账户模型 + 协议枚举（WebDAV/SMB/FTP）+ 校验纯函数
│   ├── network_file.dart      # 远程目录/文件条目模型
│   ├── danmaku_auto_match_cache.dart # 弹幕自动匹配缓存模型（番剧 + 集列表）
│   ├── danmaku_font_mode.dart # 弹幕字体三态枚举（跟随系统/跟随 App/自定义）
│   ├── cast_device.dart       # 投屏目标设备模型（DLNA MediaRenderer）
│   ├── bilibili_user.dart     # 哔哩哔哩用户信息模型（nav 接口）
│   ├── bili_bangumi.dart      # 番剧（PGC）模型：索引/搜索/季详情/选集/多季/时间表
│   ├── bili_dash.dart         # playurl DASH 模型：流条目 / 清晰度档 / OP-ED clip
│   ├── bili_media.dart        # 在线播放值对象：DASH 流 + 弹幕/章节元数据 + 画质切换回调
│   ├── update_info.dart       # 更新信息值对象（版本号 / 更新说明 / 下载站链接）
│   ├── device_decoder.dart    # 设备解码器条目模型（能力详情页用）
│   ├── wyzie_models.dart      # Wyzie 字幕 API 数据模型
│   ├── player_diagnostics.dart # 播放诊断快照模型
│   ├── bili_playlist.dart     # 番剧播放列表模型（整季剧集 + 按 epId 定位当前集）
│   ├── subtitle_dir.dart      # 字幕目录条目 + 排序纯函数（目录恒在前）
│   ├── storage_root.dart      # 存储卷根模型 + 路径归属判定（选择器卷跳转与高亮）
│   └── subtitle_font_injection.dart # 字幕字体注入判定纯函数
├── services/                  # 业务逻辑 / 数据层（无 UI）
│   ├── view_settings.dart     # 排序/字段/视图模式设置（ChangeNotifier + 持久化）
│   ├── common_list_controller.dart # 通用分页列表控制器（三态 + 刷新失败保留旧数据 + 加载更多）
│   ├── video_scanner.dart     # 扫描 + 建树 + 建文件夹列表
│   ├── video_info_service.dart# 列表封面缩略图（磁盘缓存）+ 基本元数据 + 完整媒体信息
│   ├── playback_progress_service.dart  # 播放进度（ChangeNotifier + 持久化 + 串行写盘）
│   ├── playback_history_service.dart # 播放历史（记录/去重置顶/上限淘汰/删除/清空/开关）
│   ├── playback_tuning.dart   # 每次 open 前的 mpv 缓存/网络调参（本地/在线两档）
│   ├── player_controls_settings.dart   # 播放器控制设置（槽位/手势/倍速/比例/长按/方向/顶部信息等）
│   ├── decode_settings.dart   # 解码设置（硬解/软解档位 + 解码预设）
│   ├── device_services.dart   # 设备能力（MethodChannel）：音量/亮度/画中画/电量/网络类型/后台服务/文件与目录操作 + 抓帧 + 设备能力检测 + 整应用重启 + 壁纸取色
│   ├── dolby_vision_settings.dart # 杜比视界偏色提示「不再提示」记忆
│   ├── fast_thumbnails.dart   # 快速缩略图引擎（FFI 直连自建 libmpv.so 的 mk_thumbnail_*，长驻 worker + 单飞顶旧调度）
│   ├── crash_log_service.dart # 崩溃日志：列表/读取/删除/清空/导出
│   ├── cache_manager_service.dart # 缓存管理：列表封面磁盘缓存 + 网络弹幕缓存的查询与清除
│   ├── super_resolution_service.dart   # 超分：模式持久化、着色器安装期优化后拷贝、mpv 应用
│   ├── chapter_tracker.dart   # 章节跟踪器（mpv chapter-list + 当前位置/片段/胶囊窗口 + 跳段）
│   ├── chapter_skip_settings.dart # 章节跳段设置（六类片段自动跳过 + 自定义关键词）
│   ├── intro_outro_settings.dart # 片头片尾全局设置（开关/秒数/范围）
│   ├── intro_outro_tracker.dart  # 片头片尾跟踪器（就绪/已处理状态 + 恢复点感知 + 动作决策）
│   ├── media_scan_settings.dart  # 媒体扫描与过滤设置（.nomedia/隐藏文件夹/黑白名单）
│   ├── pinned_folders_settings.dart # 固定文件夹设置
│   ├── file_operations_service.dart # 文件管理服务（复制/移动/重命名/删除 + 进度与取消）
│   ├── file_selection_controller.dart # 页面级多选状态（非单例）
│   ├── audio_service.dart     # 音频控制器（音轨列表/单选/外部音轨/声道/af 滤镜链 + 不可播放音轨回退）
│   ├── subtitle_settings.dart # 字幕设置（延迟/大小/位置/颜色/描边/背景框/内嵌样式覆盖/自定义字体/外挂记忆）
│   ├── subtitle_service.dart  # 字幕控制器（单选模型 + 同名自动加载 + 按字段样式写入 + 等待式轨道刷新 + 切轨钉回）
│   ├── app_font_settings.dart # App 全局字体设置
│   ├── equalizer_settings.dart # 音频均衡器设置（5 频段/低音增强/虚拟环绕/预设）
│   ├── danmaku_service.dart    # 弹幕控制器（本地/手动/网络弹幕装载 + 生效集重算 + 秒桶发射 + 渲染层联动 + 切集自动匹配）
│   ├── danmaku_scheduler.dart  # 弹幕调度器（纯逻辑：秒桶 + 前向补发 + seek 跳变 + 代数失效 + 整体替换）
│   ├── danmaku_memory.dart     # 弹幕手动导入记忆
│   ├── danmaku_settings.dart   # 弹幕设置（样式/配置/偏移/字体）
│   ├── dandan_play_keys.dart   # 弹弹Play API 密钥（私有，gitignored）
│   ├── dandan_play_api.dart    # 弹弹Play 开放弹幕网络 API 客户端
│   ├── danmaku_server_settings.dart # 弹幕服务器设置（默认 + 自建增删启停 + 切集自动匹配开关）
│   ├── danmaku_search_history.dart  # 网络弹幕搜索历史（去重/上限淘汰/一键清除）
│   ├── danmaku_auto_match_cache_store.dart # 弹幕自动匹配缓存存储
│   ├── danmaku_network_service.dart # 弹幕网络服务（搜索合并/文件匹配/下载落盘 + 文件前 16MB MD5）
│   ├── privacy_policy_settings.dart # 隐私政策同意状态
│   ├── privacy_policy_content.dart # 隐私政策与用户服务协议正文
│   ├── network/                    # 网络存储（WebDAV / SMB / FTP）抽象层
│   │   ├── network_client.dart     # NetworkClient 抽象接口（connect/listFiles/getFileSize/openStream/disconnect）
│   │   ├── network_client_factory.dart # 按协议创建客户端
│   │   ├── network_connection_settings.dart # 账户增删改查 + 密码只进加密存储（含老明文迁移）
│   │   ├── network_repository.dart # 高层 API（浏览目录 / 解析播放流）
│   │   ├── network_streaming_proxy.dart # 本地回环流代理（Range/HEAD + 1 秒滑动窗口网速统计）
│   │   ├── smb_pipeline.dart       # SMB 并发预读管线（多句柄 + 取消/背压/出错即停）
│   │   ├── network_subtitle_stream.dart # 远端同名字幕：一次性连接列目录 + 注册回环字幕流
│   │   ├── network_directory_cache.dart # 网络目录列表短时缓存（LRU + TTL，返回上级瞬时打开）
│   │   ├── network_view_settings.dart   # 网络浏览设置（排序偏好 + 显示隐藏项 + 已播放时长记忆）
│   │   ├── webdav_client.dart      # WebDAV 客户端（PROPFIND 列表 / Range 流式读取）
│   │   ├── ftp_client.dart         # FTP 客户端（被动模式双连接 / MLSD→LIST 回退 / REST 偏移）
│   │   └── smb_client.dart         # SMB 客户端（smb_connect + 交给 smb_pipeline 预读）
│   ├── bilibili/                  # 哔哩哔哩协议域
│   │   ├── bili_constants.dart    # 域名 / UA / Referer / TV appkey·appsec / 扫码状态码
│   │   ├── bili_api.dart          # 端点常量（集中式）
│   │   ├── bili_credential_store.dart # 凭证加密存储 + Cookie 解析纯函数
│   │   ├── bili_http.dart         # 统一请求（Cookie/UA/Referer/指纹注入 + 错误语义化 + close）
│   │   ├── bili_auth_service.dart # 扫码生成/轮询 / Cookie 导入 / nav 自检 / buvid 预取 / 退出登录
│   │   ├── bili_account.dart      # 登录态 / 用户信息 / WBI 密钥 / buvid（ChangeNotifier 单例）
│   │   ├── bili_fingerprint.dart  # 反爬指纹（uuid / b_lsid / buvid_fp / bili_ticket + 激活）
│   │   ├── bili_bangumi_service.dart # 番剧索引条件 / 分页 / 搜索(WBI) / 季详情 / 时间表
│   │   ├── bili_video_service.dart   # PGC / UGC playurl（DASH 选流 + 清晰度 + WBI 签名）
│   │   ├── bili_danmaku_service.dart # B 站原声弹幕（seg.so protobuf 解码 + XML 缓存）
│   │   ├── bili_stream_proxy.dart    # 本地 HTTP 代理（绕开 libmpv mbedTLS + 网速统计）
│   │   ├── bili_download_service.dart # 下载解析：链接 → 可下载条目
│   │   └── pb/
│   │       └── pb_reader.dart        # 手写 protobuf wire 解码器
│   ├── download/                 # 下载域
│   │   ├── download_settings.dart # 下载目录设置
│   │   ├── download_task.dart     # 任务状态机 + Range 流式下载 + 合并到临时文件再改名
│   │   └── download_manager.dart  # 任务队列 + 并发槽调度 + 跨重启持久化 + 临时文件清理
│   ├── cast/                    # 投屏域
│   │   ├── cast_service.dart    # SSDP 发现渲染器 + 源分流 + SetAVTransportURI/Play 推流
│   │   └── lan_media_server.dart # 局域网媒体服务器（本地文件 → http://LAN:port/token）
│   ├── update/                  # 更新域
│   │   ├── update_settings.dart # 更新设置（自动检查开关 + 忽略版本）
│   │   └── update_service.dart  # 更新服务（更新源常量 + checkForUpdate 抓 GitHub Releases API）
│   ├── wyzie/                   # 影视字幕下载域
│   │   ├── wyzie_settings.dart  # 字幕下载设置（密钥/来源/语言/格式/编码）
│   │   └── wyzie_api.dart       # Wyzie 字幕 API 客户端（搜索 / 下载）
│   └── ...                    # 其余服务模块
├── widgets/                   # 可复用 UI 组件（跨页面）
│   ├── app_frame.dart         # ★ 全局框架：安全区 + 播放页全屏检测
│   ├── app_dialog.dart        # showAppDialog（统一弹窗动画）
│   ├── player_panel.dart      # ★ 右侧滑入面板壳 + showPlayerPanel（横屏二级界面外壳）
│   ├── player_bottom_panel.dart # ★ 竖屏底部弹出面板壳 + showPlayerBottomPanel
│   ├── player_option_chip.dart# 面板选项胶囊（倍速 / 超分共用）
│   ├── options_sheet.dart     # 统一排序弹窗（字段胶囊选择）
│   ├── folder_card.dart       # 文件夹卡片（列表/树状共用，含多选勾选态）
│   ├── video_card.dart        # 视频卡片（列表/树状/详情共用，含多选勾选态）
│   ├── settings_ui.dart       # 设置页公共组件 + 播放器暗色面板强调色派生
│   ├── raw_thumb_image.dart   # RGBA 帧直渲组件（帧切换保持上一帧无缝）
│   ├── capsule_nav_bar.dart   # 悬浮胶囊导航
│   ├── main_scaffold.dart     # 主壳（PageView + 悬浮胶囊）
│   ├── speed_dial_fab.dart    # 首页速拨（最近播放/打开链接/哔哩番剧/网络存储）
│   ├── bili_cover_card.dart   # 番剧封面卡片（索引/推荐/时间表共用）
│   ├── bili_episode_tile.dart # 番剧单集磁贴（内联选集/全屏选集页共用）
│   ├── directory_picker_dialog.dart # 目录选择器弹窗（返回真实路径 + 存储卷跳转）
│   ├── storage_root_selector.dart # 存储卷跳转胶囊行（内部存储 / SD 卡 / U 盘）
│   ├── cast_device_dialog.dart # 投屏设备选择弹窗
│   ├── privacy_policy_dialog.dart # 首次启动隐私门禁弹窗
│   ├── update_dialog.dart       # 更新弹窗
│   ├── file_operations_ui.dart  # 文件管理 UI（动作菜单/重命名/删除确认/传输进度）
│   ├── folder_actions.dart      # 文件管理动作编排（单选 + 多选，四页面共用）
│   ├── file_selection_ui.dart   # 多选顶部工具栏 + 卡片勾选圆点
│   └── marquee_text.dart      # 无缝循环跑马灯
├── pages/                     # 页面（每页一个目录）
│   ├── bilibili/
│   │   ├── bili_login_page.dart # 哔哩哔哩登录页（TV 扫码 + Cookie 导入）
│   │   ├── bili_user_page.dart  # 哔哩哔哩账号信息页
│   │   ├── bili_index_page.dart # 番剧首页（搜索/链接解析 + 时间表 + 推荐）
│   │   ├── bili_bangumi_index_page.dart # 番剧索引页（筛选胶囊 + 分页）
│   │   ├── bili_season_page.dart # 番剧详情页（多季切换 + 内联选集）
│   │   ├── bili_episode_picker_page.dart # 全屏选集页
│   │   ├── bili_play_launcher.dart # 播放启动器（playurl → BiliMedia → PlayerPage）
│   │   ├── bili_search_page.dart # 番剧搜索页
│   │   ├── bili_danmaku_download_page.dart # 弹幕下载页
│   │   └── bili_video_download_page.dart # 视频下载页
│   ├── download/
│   │   └── download_manager_page.dart # 下载管理页
│   ├── home/
│   │   ├── home_page.dart     # 首页（权限门禁 + 视图分发 + 搜索入口 + 速拨）
│   │   ├── open_link_dialog.dart # 「打开链接」弹窗
│   │   ├── views/             # 首页专属视图组件
│   │   │   ├── folder_list_view.dart  # 列表视图
│   │   │   └── tree_list_view.dart    # 树状一级视图
│   │   ├── folder_detail_page.dart    # 列表模式详情页（纯视频）
│   │   └── tree_folder_page.dart      # 树状目录页（混合内容 + 面包屑）
│   ├── player/
│   │   ├── player_page.dart   # 播放页（横屏沉浸式；手势/恢复进度/切集/EOF/画中画/面板）
│   │   ├── player_metrics.dart # 对齐常量（触摸行 / 轨道 / 章节名 / 下一集图标同一 x）
│   │   ├── player_portrait_page.dart # 竖屏播放页（共享横屏 Player/VideoController）
│   │   ├── player_session_state.dart # ★ 横竖屏共享会话状态（音量/增强/亮度/倍速/滑动 seek/缩放）
│   │   ├── audio_player_page.dart    # 听视频页（共享 Player 只播音频 + 后台播放 + 循环三态）
│   │   └── views/             # 播放页专属控制组件
│   │       ├── player_top_bar.dart        # 顶栏：返回 + 标题 + 5 槽位 + 更多
│   │       ├── player_status_bar.dart     # 顶部信息行：时间/电量 + 网速胶囊/数据类型
│   │       ├── player_center_cluster.dart # 中央簇：快退/播放暂停/快进
│   │       ├── player_danmaku_layer.dart  # 弹幕渲染层（canvas_danmaku 封装）
│   │       ├── player_danmaku_buttons.dart# 弹幕开关/设置按钮组
│   │       ├── player_danmaku_panel.dart  # 弹幕二级界面（本地/网络/自动匹配/设置）
│   │       ├── player_danmaku_network_panel.dart # 网络弹幕搜索三级界面
│   │       ├── player_danmaku_settings_panel.dart # 弹幕设置面板（样式/配置/偏移/字体）
│   │       ├── player_bili_playlist_panel.dart   # 番剧剧集列表面板
│   │       ├── player_bottom_bar.dart     # 底栏：进度条 + 下一集 + 时间 + 弹幕按钮 + 按钮簇
│   │       ├── player_quality_panel.dart  # 清晰度面板
│   │       ├── player_pressable.dart      # 播放页按压反馈壳
│   │       ├── player_seek_bar.dart       # 自绘进度条（章节圆点 + 跳过色段）
│   │       ├── player_chapter_bar.dart    # 章节名行 + 跳过胶囊
│   │       ├── player_chapter_panel.dart  # 章节列表面板
│   │       ├── player_chapter_skip_panel.dart # 章节跳段设置面板
│   │       ├── player_intro_outro_panel.dart # 片头片尾设置面板
│   │       ├── player_loop_panel.dart     # 循环播放面板
│   │       ├── player_right_actions.dart  # 右侧竖排：截图 + 锁定
│   │       ├── player_fit_panel.dart      # 画面比例面板
│   │       ├── player_speed_panel.dart    # 倍速面板
│   │       ├── player_super_resolution_panel.dart  # 超分面板
│   │       ├── player_decode_panel.dart          # 解码面板
│   │       ├── player_diagnostics_panel.dart     # 播放诊断面板
│   │       ├── player_play_pause_button.dart  # 播放/暂停图标形变动画
│   │       ├── player_gesture_layer.dart      # ★ 手势层（裸识别器方案）
│   │       ├── player_gesture_indicator.dart  # 音量/亮度手势指示器
│   │       ├── player_zoom_restore_chip.dart  # 双指缩放后的「还原画面」胶囊
│   │       ├── player_speed_indicator.dart    # 长按倍速指示器
│   │       ├── player_playlist_panel.dart     # 播放列表面板
│   │       ├── audio_player_panels.dart       # 听视频倍速/列表面板
│   │       ├── audio_panel.dart               # 音频面板（音轨/外部音轨/声道/音频处理）
│   │       ├── equalizer_panel.dart           # 均衡器面板
│   │       ├── subtitle_panel.dart            # 字幕面板（轨道/导入/样式/杂项/字体）
│   │       ├── subtitle_file_picker.dart      # 外挂字幕选择（系统/自建选择器）
│   │       ├── player_resume_indicator.dart   # 恢复进度指示器
│   │       ├── player_swipe_seek_overlay.dart # 水平滑动 seek 预览浮层
│   │       ├── player_thumbnail_preview.dart  # 缩略图预览气泡
│   │       ├── portrait_player_top_bar.dart   # 竖屏顶栏
│   │       ├── portrait_player_bottom_bar.dart # 竖屏底栏
│   │       └── portrait_edit_panel.dart       # 竖屏「编辑控制栏」页
│   ├── media_info/
│   │   └── media_info_page.dart # 媒体信息页（MediaInfoLib 解析 + 一键复制）
│   ├── network/
│   │   ├── network_storage_page.dart  # 网络存储账户列表
│   │   ├── account_edit_page.dart     # 账户新增/编辑（协议切换 + 字段表单）
│   │   └── network_browser_page.dart  # 网络目录/文件浏览（面包屑 + 逐级返回）
│   ├── settings/
│   │   ├── settings_page.dart # 设置主页（分组结构）
│   │   ├── appearance_page.dart      # 外观设置子页（模式/主题色/动态色/自定义选色/调色板）
│   │   ├── playback_history_page.dart # 历史记录页
│   │   ├── font_page.dart            # App 字体设置页
│   │   ├── player_settings_page.dart # 播放器设置子页
│   │   ├── media_scan_settings_page.dart # 媒体扫描与过滤设置子页
│   │   ├── danmaku_server_page.dart # 弹幕服务器设置子页
│   │   ├── about_page.dart           # 关于页
│   │   ├── license_page.dart         # 许可证书页
│   │   ├── privacy_policy_page.dart  # 用户协议页
│   │   ├── device_info_page.dart     # 设备硬件与编解码能力检测页
│   │   ├── decoder_detail_page.dart  # 解码器详情页
│   │   ├── error_log_page.dart       # 错误日志页
│   │   └── cache_management_page.dart# 缓存管理页
│   └── subtitle/
│       ├── subtitle_download_page.dart # 影视字幕下载页
│       ├── subtitle_settings_page.dart # 字幕设置子页
│       └── views/
│           └── subtitle_settings_section.dart # 字幕设置区（密钥/来源/语言/格式/编码）
├── theme/                     # 主题
│   ├── app_theme.dart         # ThemeData 生成（light/dark/amoled）
│   └── theme_controller.dart  # 主题控制（模式/色/风格/自定义色/动态色标记 + 迁移）
└── utils/                     # 纯工具函数
    ├── app_dialog.dart        # showAppDialog（统一弹窗动画）
    ├── anime4k_patch.dart     # Anime4K 着色器安装期优化纯函数
    ├── formatters.dart        # 大小/日期/时长/倍速/网速格式化 + 截图文件名 + 底栏时间文本
    ├── url_media.dart         # 在线直链纯函数（规范化补协议 / 协议白名单 / 标题提取）
    ├── natural_compare.dart   # 自然序（数字感知）比较
    ├── folder_pin.dart        # 固定文件夹排序纯函数
    ├── file_ops.dart          # 文件管理纯函数（路径细分/目标校验/重名避让/视频扩展名真值）
    ├── file_selection.dart    # 多选纯函数
    ├── watch_state.dart       # 观看状态纯函数（未观看/观看中/已看完）
    ├── playback_completion.dart # EOF 动作解析纯函数（优先级链）
    ├── playback_restore.dart  # 恢复进度：openAndRestore（暂停加载 → 静音激活时间线 → seek → 确认）
    ├── playback_history.dart  # 播放历史写入唯一入口
    ├── dolby_vision_hint.dart # 杜比视界偏色检测 + 引导弹窗
    ├── pip_aspect.dart        # 画中画宽高比纯函数
    ├── player_gestures.dart   # 双击判定 + 滑动手势数学
    ├── player_diagnostics.dart # 播放诊断纯函数
    ├── retry_policy.dart      # 统一网络重试 / 超时分级 / 体积上限快速失败
    ├── async_session.dart     # 会话号令牌
    ├── async_single_flight.dart # 在飞去重
    ├── async_serial_queue.dart # 串行异步队列
    ├── async_coalesced_reload.dart # 串行合并的等待式重跑器
    ├── loading_state.dart     # 异步三态 sealed（Loading/Loaded/LoadError）+ PageResult
    ├── chapter_utils.dart     # 章节纯函数（标题分类/片段派生/当前章节/跳过目标）
    ├── intro_outro_skip.dart  # 片头片尾动作决策纯函数
    ├── mpv_tuning.dart        # mpv 移动端缓存/网络调参模板
    ├── audio_shuffle.dart     # 听视频随机播放算法
    ├── subtitle_auto_match.dart # 同名字幕自动匹配纯函数
    ├── network_subtitle_match.dart # 远端同名字幕匹配纯函数（远端路径取目录/文件名 + 挑最佳字幕）
    ├── network_entry_filter.dart # 网络目录隐藏项过滤 + 本目录搜索（纯函数）
    ├── network_sort.dart      # 网络目录排序（只有名称/日期；时间缺失恒排末尾）
    ├── subtitle_memory.dart   # 外挂字幕记忆路径失效分流
    ├── subtitle_style_properties.dart # 字幕样式「字段 → mpv 属性」写入表
    ├── danmaku_timeline.dart  # 弹幕时间轴纯函数（同秒错峰 + 时间轴偏移）
    ├── danmaku_local_file.dart # 同名弹幕文件查找（9 种命名规则）
    ├── danmaku_random_color.dart # 随机渐变色纯函数
    ├── danmaku_dedup.dart     # 弹幕去重纯函数
    ├── danmaku_merge.dart     # 弹幕合并纯函数
    ├── danmaku_blocklist.dart # 弹幕屏蔽词纯函数
    ├── danmaku_pipeline.dart  # 弹幕生效集流水线纯函数（屏蔽 → 合并 → 去重）
    ├── danmaku_episode.dart   # 弹幕集数提取/匹配纯函数
    ├── dandan_signature.dart  # 弹弹Play 签名纯函数
    ├── dandan_comment.dart    # 弹弹Play 评论 → 弹幕条目 / B 站 XML 纯函数
    ├── danmaku_xml.dart       # B 站 XML 弹幕解析/生成纯函数
    ├── webdav_xml.dart        # WebDAV PROPFIND XML 解析
    ├── ftp_parser.dart        # FTP 目录列表解析（MLSD + Unix LIST）
    ├── http_byte_range.dart   # HTTP Range 头解析
    ├── network_path.dart      # 网络路径规范化 / 校验 / 子路径拼接
    ├── bili_wbi.dart          # WBI 签名纯函数
    ├── bili_app_sign.dart     # TV 端 appSign 纯函数
    ├── bili_fingerprint_utils.dart # 反爬指纹纯函数
    ├── bili_bangumi_url.dart  # 番剧/视频链接解析纯函数
    ├── bili_short_link.dart   # b23.tv 分享短链提取 + 展开
    ├── cast_source.dart       # 投屏源分类纯函数
    ├── version_compare.dart   # 版本号比较纯函数
    ├── network_mime_types.dart # 文件名 → MIME 类型映射
    ├── wyzie_query.dart       # Wyzie 字幕查询纯函数
    └── wyzie_filename.dart    # Wyzie 字幕落盘文件名纯函数
```

---

## 4. 分层架构

依赖方向**只允许上层依赖下层，禁止反向**：

```
pages（页面）      → 组装 widgets / 调用 services
widgets（组件）    → 只依赖 models / services / theme / utils
services（服务）   → 只依赖 models / utils
models（模型）     → 无依赖（纯数据）
utils（纯工具）    → 只依赖 models
```

约定：

- `widgets/` 里的公共组件**禁止 import `pages/`**；页面专属小组件放 `pages/<页面>/views/`；
- `services/` 不含 UI（不 import Flutter widget 层）；
- 单文件超过 ~400 行应当考虑拆分；播放页主体与其 `views/` 面板组件为共享会话状态而保留较大体量。

---

## 5. 模块说明

### 5.1 媒体库与首页

- **扫描**：`VideoScanner` 走原生 `getVideos`（MediaStore 全表查询 + 逐条校验 + `.nomedia` 祖先链判断），可配置包含隐藏目录 / `.nomedia` 目录；结果缓存于内存，文件操作后清缓存重扫。
- **两种视图**：列表模式（`buildFolderList`：含直接视频的文件夹）与树状模式（`buildTree`：完整目录树），共用 `FolderCard` / `VideoCard`；建树与聚合在后台 isolate（`compute`）执行。
- **首页**：`HomePage` 负责权限门禁（「允许管理所有文件」）、视图分发、搜索、多选与速拨入口。
- **存储卷跳转**：自建目录选择器（媒体扫描黑白名单 / 下载目录 / 字幕与音频导入）顶部列出已挂载存储卷胶囊（`StorageRootSelector` + `StorageRoot`），点击即跳到该卷根。**外置卷只能由原生 `getStorageRoots` 枚举得到**——`/storage` 目录本身在 Android 11+ 上即使持有「所有文件访问」也列不出来（授权只到各卷根，不含 `/storage` 这个挂载点容器），此前选择器起点写死 `/storage/emulated/0` 导致 SD 卡/TF 卡完全无法进入。
- **播放历史**：`PlaybackHistoryService` 记录可重放来源（本地路径 / 在线直链），去重置顶、上限淘汰，首页速拨「最近播放」直启。
- **进度**：`PlaybackProgressService` 单例，`path → 毫秒` 映射，串行写盘 + 节流；播放页恢复进度走 `openAndRestore`（暂停加载 → 静音激活时间线 → seek → 位置确认）。

### 5.2 播放器

- **页面**：`PlayerPage`（横屏沉浸式）与 `PlayerPortraitPage`（竖屏）共享同一个 media_kit `Player` 与 `VideoController`，切换零中断；横竖屏共享的会话状态（音量 / 音量增强 / 亮度 / 倍速 / 滑动 seek / 缩放）收敛在 `PlayerSessionState`，横屏创建并注入竖屏。
- **控制层**：顶栏（5 槽位可配置 + 更多）、状态栏（时间/电量/网速/数据类型）、中央簇、底栏（进度条 + 下一集 + 时间 + 弹幕按钮）、右侧竖排（截图 / 锁定）；二级界面横屏用 `showPlayerPanel`（右侧滑入）、竖屏用 `showPlayerBottomPanel`（底部弹出），面板内容组件共用。
- **手势**：`PlayerGestureLayer` 裸识别器方案，支持双击（播放暂停 / 快进快退 / 无）、水平滑动 seek（带预览浮层）、垂直滑动音量与亮度、长按倍速、双指缩放（带「还原画面」胶囊）。
- **进度条**：`PlayerSeekBar` 自绘（章节圆点 + 跳过色段 + 触摸行对齐常量）；拖动实时预览缩略图，松手落在所见帧的精确时刻。
- **缩略图**：`FastThumbnails` 通过 FFI 直连自建 libmpv.so 的 `mk_thumbnail_*`（长驻 worker isolate + 单飞顶旧调度，秒桶内存 LRU），`RawThumbImage` 把 RGBA 帧直渲为 `ui.Image`。
- **超分**：`SuperResolutionService` 管理 Anime4K 着色器链（安装期做精度注入与采样合并优化后再拷贝），7 档模式 × 3 质量档。
- **章节与跳过**：`ChapterTracker` 读 mpv `chapter-list` 并跟踪当前位置与片段窗口；`ChapterSkipSettings`（六类片段）与 `IntroOutroSettings`（片头片尾秒数）分别驱动自动跳过。
- **诊断**：`player_diagnostics` 纯函数 + 诊断面板按秒采样 mpv 属性（缓存/丢帧/渲染延迟/硬解/音画同步）。

### 5.3 字幕

- **来源**：内嵌轨道（mpv `track-list`）、外挂导入（Android ≤11 用系统选择器；>11 用自建选择器，带排序与文件夹记忆）、同名字幕自动加载（简/繁后缀优先，只由 App 负责挂载；本地与**网络存储远端**走同一套匹配规则）。
- **控制器**：`SubtitleService` 单选模型，同步 `track-list` / `sid`，支持增删轨道、按字段写入样式、等待式轨道刷新、切轨后按用户意图钉回、记忆路径失效清理。
- **样式**：`SubtitleSettings` 管理延迟 / 大小 / 位置 / 颜色 / 描边 / 背景框 / 内嵌样式覆盖 / 自定义字体；字段到 mpv 属性的映射集中在 `subtitle_style_properties.dart`。
- **字体**：自定义字体走 libass 原生渲染；字体目录在播放器构造期注入（运行期不改 `sub-fonts-dir`）。
- **影视字幕下载**：`WyzieApi` + 字幕下载页（关键词搜索、勾选批量下载）。

### 5.4 弹幕

- **来源**：本地同名文件（9 种命名规则）、手动导入、网络弹幕（弹弹Play：搜索 / 库匹配 / 自动匹配）、B 站原声弹幕（`seg.so` protobuf）。
- **流水线**：`danmaku_pipeline` 纯函数对**全量原始条目**执行「屏蔽词 → 合并 → 去重」（跨时间窗算法，走后台 isolate）；结果交给 `DanmakuScheduler`（秒桶 + 前向补发 + seek 跳变检测 + 代数失效）按 1s tick 发射。
- **渲染**：`player_danmaku_layer` 封装 `canvas_danmaku`，横竖屏共享同一控制器；只有可见层接收弹幕。
- **设置**：`DanmakuSettings` 覆盖样式（字号/字重/速度/描边/不透明度/随机色）、配置（显示区域/行高/顶底滚动显隐/海量/去重/屏蔽词）、偏移（时间轴 ±180s）、字体（跟随系统/跟随 App/自定义）。

### 5.5 音频与听视频

- **控制器**：`AudioService` 管理音轨列表与单选、外部音轨导入/移除（临时）、音频声道、音频处理（音量标准化 / 动态范围压缩）与 `af` 滤镜链；声道与处理为会话级，随播放器生命周期重置。
- **均衡器**：`EqualizerSettings` 全局持久化 5 频段 + 低音增强 + 虚拟环绕 + 预设，由 `AudioService` 订阅后重应用滤镜链。
- **音轨回退**：换轨后在短窗口内消费 mpv 日志，命中音频失败特征时复核 `audio-params` 并自动回退到可用音轨。
- **听视频**：`AudioPlayerPage` 复用共享 Player 只播音频，提供封面模糊背景、1:1 圆角封面、胶囊式倍速/列表、定时关闭、后台播放（前台服务）与时间刻随机播放。

### 5.6 网络存储

- **抽象层**：`NetworkClient` 接口 + `network_client_factory` 按协议构造；`NetworkRepository` 提供浏览目录与解析播放流的高层 API。
- **协议实现**：WebDAV（纯 Dart `http`，PROPFIND 列表 + Range 流式读取）、SMB（`smb_connect` + `smb_pipeline` 并发预读）、FTP（被动模式双连接、`MLSD`→`LIST` 回退、REST 偏移续传）。
- **播放**：`NetworkStreamingProxy` 把远端文件转成 `127.0.0.1` 的无凭据回环 URL 供 mpv 拉流，处理 Range/HEAD 并提供滑动窗口网速统计。
- **远端同名字幕**：`network_subtitle_match`（纯函数）按本地同规则在远端目录里挑最佳同名字幕，`network_subtitle_stream` 用一次性连接列目录、把命中的字幕文件注册成同形状回环 URL 交给 mpv `sub-add`；远端记忆存「连接 id + 远端路径」（会话 URL 里的 token 跨会话必变，不入库），全链路失败静默、不影响播放（对齐 mpvRx `SubtitleOps`）。
- **浏览**：`NetworkBrowserPage` 复用 `FolderCard` / `VideoCard`，但**只展示远端列目录真的给得出的信息**——文件夹与视频都显示**日期**，视频另加**完整名称**；不显示大小（部分服务器给 0/-1），列目录时也拿不到时长/帧率/分辨率/字幕/进度。唯一例外是**时长**：播过一次的视频由播放页回报真实时长并按稳定键（连接 id + 远端路径）记住，没播过的不显示。排序自带一套 `NetworkSort`（**只有名称 / 日期**，各升降序，日期缺失恒排末尾），不复用本地那套「名称/日期/大小/数量 + 字段开关」——那些在远端排不动。另支持搜索（本目录）、下拉刷新、回到共享根、默认隐藏 `.`/`@eaDir` 等隐藏项（可开）；目录列表走 `NetworkDirectoryCache`（TTL + LRU），返回上级与重进已看过的目录即时打开。
- **凭据**：账户清单存 SharedPreferences，密码只进加密存储（含老明文迁移）；WebDAV 的默认端口按 scheme 区分（HTTP 80 / HTTPS 443），切换 HTTPS 或协议时端口自动跟随、手改过的端口保留。

### 5.7 哔哩哔哩

- **协议层**：`bili_http` 统一注入 Cookie / UA / Referer / 反爬指纹并语义化错误；`bili_api` 集中端点；WBI 签名与 TV appSign 为纯函数。
- **登录**：`BiliAuthService` 走 TV 扫码（生成 / 轮询 / Cookie 导入），凭证进加密存储；`BiliAccount` 维护登录态、用户信息与 buvid。
- **内容**：番剧索引 / 搜索 / 季详情 / 选集 / 时间表（`bili_bangumi_service`）。
- **播放**：`bili_video_service` 解析 PGC/UGC playurl（DASH 选流 + 清晰度 + WBI），`BiliMedia` 作为在线播放值对象；`BiliStreamProxy` 本地代理绕开 libmpv 的 mbedTLS 并统计网速；原声弹幕经 `bili_danmaku_service` 解码。
- **下载**：`bili_download_service` 把链接解析为可下载条目（番剧多集 / UGC BV·av·合集），交给下载域执行。

### 5.8 下载

- **任务**：`DownloadTask` 状态机（pending / downloading / paused / merging / completed / failed）+ Range 流式续传 + 进度与速度节流；合并先写中间文件、成功后再改名，落盘后触发媒体库扫描。
- **队列**：`DownloadManager` 调度并发槽、跨重启持久化任务列表、删除/清除时按语义清理临时文件。

### 5.9 文件管理

- **服务**：`FileOperationsService` 提供复制 / 移动 / 重命名 / 删除（`dart:io` 真实路径），同卷 `rename` 秒移、跨卷退化为「复制 + 删源」，带进度回调与协作式取消。
- **固定文件夹**：`PinnedFoldersSettings` 维护固定集合，排序时稳定前置（`folder_pin` 纯函数）。
- **多选**：`FileSelectionController` 为页面级状态（非单例），配合多选工具栏执行批量操作。

### 5.10 投屏 / 更新 / 隐私 / 设备能力

- **投屏**：`CastService` 通过 SSDP 发现 DLNA 渲染器并推送播放地址；`LanMediaServer` 提供局域网媒体服务（本地文件 → HTTP，支持 Range/CORS）。
- **更新**：`UpdateService.checkForUpdate` 取本地版本与 GitHub Releases 最新版本比较（带网络重试与响应体积上限），`UpdateSettings` 记录自动检查开关与忽略版本。
- **隐私**：`PrivacyPolicySettings` 首次启动门禁（倒计时 + 勾选同意），正文集中在 `privacy_policy_content`。
- **设备能力**：`DeviceCapabilities`（原生）探测屏幕 HDR、关键编解码器与系统解码器清单，配合设备信息页与解码器详情页；`decode_settings` 持久化解码方式与预设。

---

## 6. 原生层（Android）

| 文件 | 职责 |
|---|---|
| `MainActivity.kt` | MethodChannel `moumou/video_info` 的宿主：媒体库查询、视频信息与缩略图、媒体信息、杜比视界检测、设备能力、系统音量/亮度、画中画、外部 `content://` 三级解析、B 站双流合并（`mergeM4s`）、整应用重启、壁纸取色、目录列举、存储卷枚举（`getStorageRoots`） |
| `MediaInfoHelper.kt` | MediaInfoLib 封装：快速元数据（帧率 / 内嵌字幕）、完整媒体信息、杜比视界检测（统一走 `withMediaInfo` 托管文件描述符） |
| `DeviceCapabilities.kt` | 屏幕 HDR 能力、关键编码器、系统解码器清单 |
| `BackgroundPlaybackService.kt` | 听视频后台播放的前台服务 |
| `CrashHandler.kt` | 未捕获异常写入 `files/crash_logs/` |

原生与 Dart 的通道方法名、参数键保持一一对应，新增能力时两端同步。
