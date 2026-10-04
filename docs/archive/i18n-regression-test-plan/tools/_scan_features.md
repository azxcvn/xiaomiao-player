# 多语言引入后 · 全量功能点扫描（只读产出）

> 本文件由**只读扫描**生成：没有修改任何源码、没有跑 `flutter` 命令、没有 git 操作。
> 用途：给「多语言引入后回归测试」提供**用户可用功能点**的穷尽清单，供后续用例拆分使用。
> 采集方式：`read` / `grep` / `glob` 逐文件读源码 + 中文文案基线（`lib/l10n/app_localizations_zh.dart` 全量键值对）。
> 扫描范围：`lib/pages/**`、`lib/widgets/**`、`lib/services/**`、`lib/models/**`、`lib/utils/**`、`lib/l10n/**`、`android/app/src/main/**`、`test/**`。

## 0. 扫描口径与统计

| 项 | 值 |
|---|---|
| 仓库根 | `C:\Users\root\Desktop\moumou` |
| 分支（基线文档记载） | `English` |
| `lib/**` dart 文件数 | 306 |
| `test/**` dart 文件数 | 190（其中 `l10n_test_helper.dart`、`pb_test_helper.dart` 为夹具，非测试用例） |
| 本地化键总数（zh 侧） | 1272（普通 getter 1097 + 带占位符方法 175）—— 这是**扫描时**（`629389e`）的快照；收口后为 **1276**，以 `04-data-baseline.md` §4 为准 |
| 已接入 l10n 的 page/widget 文件 | 86 个（`lib/pages/**` + `lib/widgets/**` 中调用 `l10n.xxx` 的文件） |
| 可选语言 | **只有 简体中文 / English**，**没有「跟随系统」**（`AppLocaleSettings._normalize` 非法值恒回落 `zh`） |
| 语言持久化键 | `app_locale`（值 `'zh'` / `'en'`） |
| 功能点条目总数 | **481 条**（见文末 §16 按域汇总；全表连续编号 1.1–12.17） |

### 0.1 全局导航基线（写入口路径时的公共前缀）

只有**两项**底部胶囊导航：

```
底部胶囊：首页(navHome) ｜ 我的(navMine)
```

- **首页**：右上角 `搜索`(commonSearch) 与 `排序与视图`(homeSortAndView) 两个图标；右下角速拨 FAB 四个动作 → `最近播放`(homeRecentPlayed) / `打开链接`(homeOpenLink) / `哔哩番剧`(biliBangumi) / `网络存储`(networkStorageTitle)。
- **我的**（`SettingsPage`）自上而下：
  1. 账号入口：未登录 → `登录`（副标题「哔哩哔哩账号」）；已登录 → 头像+昵称+`等级 · 会员标签`，点击进账号信息页。
  2. `外观` 组 → `外观与字体`(settingsAppearanceAndFont)
  3. `播放` 组 → `播放设置`(settingsPlayerSettings) ｜ `历史记录`(settingsPlaybackHistory)
  4. `媒体库` 组 → `媒体扫描与过滤`(settingsMediaScan)
  5. `弹幕` 组 → `弹幕服务器`(settingsDanmakuServer)
  6. `语言` 组 → `语言设置`(settingsLanguage)
  7. `下载` 组 → `哔哩弹幕下载`子页(settingsDanmakuDownloadDesc) ｜ `哔哩视频下载`子页(settingsVideoDownloadDesc) ｜ `字幕下载`(biliSubtitleDownloadTitle) ｜ `下载管理`(downloadManagerTitle)
  8. `其他` 组 → `设备信息`(settingsDeviceInfo) ｜ `关于`(settingsAbout)

> 下文表格里的「入口」列一律从 `首页` 或 `我的` 起算；`播放页` 指由首页/文件夹/链接/外部打开进入的播放界面（横屏 `PlayerPage`，竖屏 `PlayerPortraitPage`，两者顶栏/底栏结构一致）。

### 0.2 adb 黑盒可测性判据

| 判定 | 含义 |
|---|---|
| `可` | 只要已安装的 debug/release 包 + 本机素材，就能靠 `adb exec-out screencap` + `input tap/swipe/text/keyevent` + `logcat` 完成端到端验证 |
| `部分` | 能触发并看到结果，但**判定需要外部条件**：真实网络、B站账号/大会员、局域网设备、特殊素材、杀进程重启、卸载重装等 |
| `不可` | 靠 adb 黑盒**无法**完成：需要主动注入崩溃、需要真实硬件能力（HDR/硬解档位真值）、需要第二台设备协同、需要系统级弹窗交互（如系统「所有文件访问权限」页部分 ROM 行为）等 |

---

## 1. 媒体库与文件夹

### 1.1 首页 / 权限门禁 / 扫描

| 功能点 | 入口（从首页/我的开始的点击路径） | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.1 首页视频库加载（列表/树状共用一棵目录树） | 冷启动 → `首页` | `lib/pages/home/home_page.dart`、`lib/services/video_scanner.dart` | 系统权限（MANAGE_EXTERNAL_STORAGE） | 部分 | 首次启动必然走权限门禁；模拟器需在系统页授权 |
| 1.2 存储权限门禁 · 未授权提示 | `首页`（未授权时整页提示） | `lib/pages/home/home_page.dart` | 系统权限 | 可 | 文案 `需要授予存储权限才能扫描视频` |
| 1.3 授予权限按钮 | `首页` → `授予权限`(homeGrantPermission) | `lib/pages/home/home_page.dart` | 系统权限 | 部分 | 会拉起系统「所有文件访问」页，`input tap` 可点但页面结构随 ROM 变 |
| 1.4 权限被永久拒绝 → `去系统设置开启` | `首页` → `去系统设置开启`(homeOpenSettings) | 同上 | 系统权限 | 部分 | 少数 ROM 无该入口时静默降级为 toast |
| 1.5 权限被永久拒绝 → `我已开启，重新检查` | `首页` → `我已开启，重新检查`(homeRecheckPermission) | 同上 | 系统权限 | 可 | 仅在 `_permissionBlocked` 时出现 |
| 1.6 空库状态 → `重新扫描` | `首页` → `没有找到视频` → `重新扫描`(homeRescan) | 同上 | 本地素材 | 可 | |
| 1.7 下拉刷新（强制重扫，连原生整盘补扫索引一起重建） | `首页` 下拉 | `lib/pages/home/home_page.dart`、`android/.../VideoFsWalker.kt` | 本地素材 | 可 | 与普通刷新的差别：`VideoScanner.markFsIndexDirty()` |
| 1.8 回前台自动刷新（感知外部增删改） | 切到别的 App → 切回 `首页` | `lib/pages/home/home_page.dart`（`didChangeAppLifecycleState`） | 本地素材 | 可 | |
| 1.9 原生整盘补扫的**增量上屏**（不闪、不转圈） | `首页` 停留等待补扫推送 | `lib/pages/home/home_page.dart`、`android/.../VideoFsWalker.kt` | 本地素材 | 部分 | 依赖 `.nomedia`/非主卷目录才有补扫条目 |

### 1.2 首页搜索 / 排序 / 视图

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.10 搜索（文件夹 + 视频名过滤，树状模式递归匹配） | `首页` → 右上角 `搜索` → 输入「搜索文件夹与视频」 | `lib/pages/home/home_page.dart` | 无 | 可 | 不区分大小写 |
| 1.11 取消搜索 / 清除搜索 | `首页` → 搜索态 → 右上角 `×`(commonCancelSearch) | 同上 | 无 | 可 | |
| 1.12 无匹配结果空态 | `首页` → 搜索无命中 | 同上 | 无 | 可 | 树状=`没有匹配的内容`，列表=`没有匹配的文件夹` |
| 1.13 排序与视图面板（入口图标） | `首页` → 右上角 `排序与视图`(homeSortAndView) | `lib/widgets/options_sheet.dart` | 无 | 可 | |
| 1.14 显示模式切换：`树状模式`/`列表模式` | → `排序与视图` → `显示模式`(optionsSheetViewMode) | `lib/widgets/options_sheet.dart`、`lib/services/view_settings.dart` | 无 | 可 | 切换后首页整体结构变化，是最显眼的 l10n 回归点之一 |
| 1.15 文件夹排序方式 | → `排序与视图` → `文件夹排序方式`(optionsSheetFolderSort) | 同上 | 无 | 可 | |
| 1.16 文件夹排序方向（升序/降序 / 正序/倒序） | → `排序与视图` → `文件夹排序方向` | 同上 | 无 | 可 | |
| 1.17 文件夹显示字段（名称/路径/数量/大小/日期/…） | → `排序与视图` → `文件夹显示字段`(optionsSheetFolderFields) | 同上、`lib/l10n/label_maps.dart` | 无 | 可 | 字段名走 `folderFieldLabel` |
| 1.18 视频排序方式 | → `排序与视图`（视频模式） → `视频排序方式`(optionsSheetVideoSort) | 同上 | 无 | 可 | |
| 1.19 视频排序方向 | → `排序与视图` → `视频排序方向` | 同上 | 无 | 可 | |
| 1.20 视频显示字段（含 `完整名称` commonFullName、`分辨率`、`帧率`、`时长`、`大小`、`日期`、`进度`、`字幕指示器`） | → `排序与视图` → `视频显示字段`(optionsSheetVideoFields) | 同上 | 无 | 可 | `commonSubtitleIndicator` 是较易漏的字段 |

### 1.3 浏览层级（树状 / 列表）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.21 树状模式进入子目录（可逐级下钻） | `首页`（树状）→ 点文件夹卡片 | `lib/pages/home/tree_folder_page.dart` | 本地素材（≥3 层目录） | 可 | |
| 1.22 树状目录页内搜索文件夹与视频 | `首页` → 进入目录 → 右上角 `搜索` | `lib/pages/home/tree_folder_page.dart` | 本地素材 | 可 | |
| 1.23 树状目录页内排序与字段 | `首页` → 进入目录 → 右上角 `排序与字段`(homeSortAndFields) | 同上 | 本地素材 | 可 | |
| 1.24 列表模式进入文件夹详情 | `首页`（列表）→ 点文件夹卡片 | `lib/pages/home/folder_detail_page.dart` | 本地素材 | 可 | |
| 1.25 文件夹详情内搜索视频 | 文件夹详情 → 右上角 `搜索` | `lib/pages/home/folder_detail_page.dart` | 本地素材 | 可 | |
| 1.26 空文件夹提示 | 文件夹详情（无视频） | 同上 | 本地素材（空目录） | 可 | `该文件夹没有视频` |
| 1.27 文件夹卡片显示视频数量 | `首页` 列表/树状 | `lib/widgets/folder_card.dart` | 本地素材 | 可 | `folderVideoCount` |

### 1.4 文件管理（长按菜单 / 多选）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.28 文件夹长按菜单（固定/复制/移动/重命名/删除/多选） | `首页` → 长按文件夹 | `lib/widgets/folder_actions.dart`、`lib/widgets/file_operations_ui.dart` | 本地素材 | 可 | 菜单项按能力动态出现 |
| 1.29 文件夹 `固定` | `首页` → 长按文件夹 → `固定`(fileOpPin) | `lib/utils/folder_pin.dart`、`lib/services/pinned_folders_settings.dart` | 本地素材 | 可 | 固定后置顶 |
| 1.30 文件夹 `取消固定` | 同上 → `取消固定`(fileOpUnpin) | 同上 | 本地素材 | 可 | |
| 1.31 文件夹重命名（含非法名/分隔符/空名校验提示） | → 长按 → `重命名`(commonRename) | `lib/widgets/file_operations_ui.dart`、`lib/utils/file_ops.dart` | 本地素材 | 可 | `名称不能包含 \ / : * ? " < > |` 等提示均走 l10n |
| 1.32 文件夹复制 / 移动（含进度 正在复制…/正在移动…） | → 长按 → `复制`/`移动` | `lib/widgets/folder_actions.dart` | 本地素材 | 可 | 进度文案 `folderTransferCopying`/`folderTransferMoving` |
| 1.33 文件夹删除（`仅删除该文件夹内的视频文件` / `删除所有文件` 两种语义） | → 长按 → `删除` | `lib/widgets/file_operations_ui.dart` | 本地素材 | 可 | 两个不同确认文案，容易只测一个 |
| 1.34 视频长按菜单（复制/移动/重命名/删除/多选，**无固定项**） | `首页`（树状）→ 长按视频 | 同上 | 本地素材 | 可 | |
| 1.35 进入多选态 | → 长按 → `多选`(fileOpMultiSelect) | `lib/services/file_selection_controller.dart`、`lib/widgets/file_selection_ui.dart` | 本地素材 | 可 | 多选态顶部工具栏替换 AppBar，速拨 FAB 收起 |
| 1.36 多选态 `全选` / `取消全选` | 多选态 → 顶部 `全选`(commonSelectAll) | `lib/widgets/file_selection_ui.dart` | 本地素材 | 可 | 全选范围 = **当前可见（已排序已过滤）**列表 |
| 1.37 多选态批量操作菜单（⋮） | 多选态 → 顶部 `⋮`(fileSelectionOps) | `lib/pages/home/home_page.dart` | 本地素材 | 可 | 有 `已选 N 项` 计数文案 |
| 1.38 多选态长按卡片 = 先纳入选择再弹批量菜单 | 多选态 → 长按卡片 | 同上 | 本地素材 | 可 | |
| 1.39 退出多选（× / 系统返回键） | 多选态 → `×`(fileSelectionExit) / 返回键 | 同上 | 无 | 可 | `PopScope` 拦截返回 |
| 1.40 批量操作结果汇总提示（成功/失败/取消/部分失败） | 批量操作后 | `lib/widgets/folder_actions.dart` | 本地素材 | 可 | 文案含占位符（`folderActionMovedCount` 等），l10n 复数/占位符回归重点 |
| 1.41 文件夹/视频操作失败提示（源不存在/目标同名/目标不可读/复制成功但删除失败） | 操作异常时 | `lib/utils/file_ops.dart`、`lib/l10n/error_texts.dart` | 本地素材 | 部分 | 需要构造失败素材（同名文件、只读目录） |

### 1.5 视频卡片与播放入口

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.42 视频卡片显示 `已看完`/`未观看` | `首页` 视频卡片 | `lib/widgets/video_card.dart`、`lib/utils/watch_state.dart` | 本地素材 + 「已观看进度阈值」设置 | 部分 | 需先把进度推过阈值；阈值可调 |
| 1.43 视频卡片字幕指示：`含字幕`/`无字幕`/`字幕检测中…` | `首页` 视频卡片右侧 | `lib/widgets/video_card.dart` | 本地素材（含/不含内嵌字幕的视频） | 部分 | 需 M02 类多轨素材；检测期间自动切换文案 |
| 1.44 视频卡片进度条（续播进度） | `首页` 视频卡片 | 同上、`lib/services/playback_progress_service.dart` | 本地素材 | 部分 | 需先播放过 |
| 1.45 点视频卡片播放 | `首页` → 点视频 | `lib/pages/home/home_page.dart` | 本地素材 | 可 | 树状模式会把根层视频列表当「下一集」兄弟列表 |
| 1.46 点击卡片最右「i」进媒体信息页 | `首页` → 视频卡片 `i` → `媒体信息`(mediaInfoItem) | `lib/pages/media_info/media_info_page.dart` | 本地素材 | 可 | |
| 1.47 媒体信息页 · 通用信息（格式/格式版本/文件大小/总比特率/编码日期/编码应用/编码库） | 媒体信息页 | 同上 | 本地素材 | 可 | 多行文案含 `\n` 拼接，l10n 回归点 |
| 1.48 媒体信息页 · 视频流 / 音频流 / 字幕流分节（编码/配置/宽高/宽高比/帧率/比特率/位深/色彩空间/HDR格式/声道/采样率/语言/流大小） | 媒体信息页 | 同上、`android/.../MediaInfoHelper.kt` | 本地素材 | 可 | 字幕流文案 `mediaInfoSubtitleStreamNo` 仅在有多字幕时出现 |
| 1.49 媒体信息一键复制 + `媒体信息已复制` | 媒体信息页 → 右上角 `复制`(commonCopy) | 同上 | 无 | 可 | |
| 1.50 媒体信息获取失败提示 | 媒体信息页（坏文件） | 同上 | 本地素材（损坏文件） | 部分 | |

### 1.6 首页速拨入口

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.51 `最近播放`（直启最后一条历史） | `首页` → 右下角速拨 → `最近播放` | `lib/pages/home/home_page.dart`、`lib/services/playback_history_service.dart` | 本地素材 + 已有历史 | 可 | 无历史时 toast `暂无播放历史` |
| 1.52 `最近播放` · 文件已删除提示 | 同上（历史文件被删） | 同上 | 本地素材 | 部分 | `homeFileGone(title)` 含占位符 |
| 1.53 `打开链接`（输入直链播放） | `首页` → 速拨 → `打开链接` → 输入框 | `lib/pages/home/open_link_dialog.dart` | 网络（直链） | 部分 | 需可用 http(s)/rtmp/rtsp 直链 |
| 1.54 `打开链接` · 从剪贴板 `粘贴` | → `打开链接` → `粘贴`(commonPaste) | 同上 | 无（需先 `adb shell input` 或 `cmd clipboard` 设置剪贴板） | 部分 | `剪贴板为空` 分支容易漏 |
| 1.55 `打开链接` · 非法链接提示 | → `打开链接` → 非法输入 → `播放` | 同上 | 无 | 可 | `支持 http/https/rtmp/rtsp 等流媒体协议` |
| 1.56 `哔哩番剧` 入口（未登录拦截） | `首页` → 速拨 → `哔哩番剧` | `lib/pages/home/home_page.dart` | 账号 | 可 | 未登录 toast `需要登录哔哩哔哩账号`，不跳页 |
| 1.57 `网络存储` 入口 | `首页` → 速拨 → `网络存储` | `lib/pages/network/network_storage_page.dart` | 无 | 可 | 进入账户列表页 |
| 1.58 速拨 FAB 展开/收起/标签显示 | `首页` → 右下角 FAB | `lib/widgets/speed_dial_fab.dart` | 无 | 可 | 展开后四个动作标签是 l10n 密集区 |

### 1.7 媒体扫描与过滤设置

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 1.59 进入 `媒体扫描与过滤` | `我的` → `媒体库` 组 → `媒体扫描与过滤` | `lib/pages/settings/media_scan_settings_page.dart` | 无 | 可 | |
| 1.60 `扫描包含 .nomedia 的文件夹` 开关（含首次开启确认弹窗） | → `媒体扫描与过滤` → 该开关 | 同上、`lib/services/media_scan_settings.dart` | 本地素材（`.nomedia` 目录） | 部分 | 首次开启弹 `开启提示` 确认；需重启/重扫才见效 |
| 1.61 `扫描以 . 开头的隐藏文件夹` 开关 | → 同上 | 同上 | 本地素材（隐藏目录） | 部分 | |
| 1.62 文件夹过滤模式：`全部扫描` / `黑名单模式` / `仅白名单模式` | → `文件夹过滤模式`(mediaScanGroupFilterMode) | 同上 | 本地素材 | 可 | 三选一单选 |
| 1.63 黑名单文件夹列表 · `添加文件夹` | → `黑名单文件夹列表` → `添加文件夹` | 同上、`lib/widgets/directory_picker_dialog.dart` | 本地素材 | 可 | 空态 `暂无黑名单文件夹（未排除任何目录）` |
| 1.64 白名单文件夹列表 · `添加文件夹` | → `白名单文件夹列表` → `添加文件夹` | 同上 | 本地素材 | 可 | 空态 `暂无白名单文件夹（未添加时默认显示全部）` |
| 1.65 文件夹选择器：`上一级` / `浏览设备其他目录...` / `当前目录下无子文件夹` / `未发现更多媒体文件夹` | → `添加文件夹` 弹窗 | `lib/widgets/directory_picker_dialog.dart` | 本地素材 | 可 | 目录选择器也是「字幕/下载」目录选择的共用组件 |
| 1.66 媒体扫描设置持久化（重启后保持） | → 改任一项 → 杀进程重启 | `lib/services/media_scan_settings.dart` | 无 | 可 | `am force-stop` + 重启即可验 |
| 1.67 存储卷选择（`内部存储`/`SD 卡` 回退名与系统卷描述） | `我的` → `媒体库` → 相关入口（存储卷选择器） | `lib/widgets/storage_root_selector.dart`、`lib/models/storage_root.dart`、`android/.../MainActivity.kt`（`getStorageRoots`） | 系统权限 + 第二存储卷 | 部分 | 卷名走 Android 资源 `storage_internal`/`storage_sd_card`，是**原生侧 l10n 验证点** |

---

## 2. 播放器

> `播放页` = 由首页点视频 / 文件夹详情点视频 / 最近播放 / 打开链接 / 哔哩番剧 / 系统「打开方式」进入。横屏 `PlayerPage`、竖屏 `PlayerPortraitPage` 顶栏与底栏等价。

### 2.1 播放控制与进度

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.1 播放 / 暂停（单击画面 / 中央按钮） | `播放页` → 单击画面 或 中央 `播放/暂停`(commonPlay/commonPause) | `lib/pages/player/player_page.dart`、`lib/pages/player/views/player_play_pause_button.dart` | 本地素材 | 可 | |
| 2.2 进度条拖动 seek | `播放页` → 底栏进度条拖动 | `lib/pages/player/views/player_seek_bar.dart` | 本地素材 | 可 | |
| 2.3 拖动进度条时缩略图预览 | `播放页` → 拖动进度条 | `lib/pages/player/views/player_thumbnail_preview.dart`、`lib/services/fast_thumbnails.dart` | 本地素材 | 部分 | 依赖缩略图生成；开关在 `播放设置 → 进度条缩略图` |
| 2.4 时间文本（点击切换 `已播/总时长` ⇄ `已播/剩余时长`） | `播放页` → 底栏时间文本 | `lib/pages/player/views/player_bottom_bar.dart` | 本地素材 | 可 | |
| 2.5 `下一集`（无兄弟视频时置灰） | `播放页` → 底栏左侧 `下一集`(playerNextEpisode) | 同上 | 本地素材（同目录多视频） | 可 | |
| 2.6 `播放列表` 面板（当前播放项高亮、无其他视频提示） | `播放页` → 底栏 `列表` 图标 或 顶栏 `更多` | `lib/pages/player/views/player_playlist_panel.dart` | 本地素材 | 可 | `playerNoOtherVideos` |
| 2.7 自动连播（播完自动下一集） | `我的` → `播放设置` → `自动连播` | `lib/pages/settings/player_settings_page.dart` | 本地素材 | 部分 | 需等视频自然播完，或挑极短视频 |
| 2.8 播放完毕自动退出 | `我的` → `播放设置` → `播放完毕自动退出` | 同上 | 本地素材 | 部分 | 需最后一个播完 |
| 2.9 恢复上次播放进度（提示 + 一键 `重头开始`） | `播放页` 进入时 | `lib/pages/player/views/player_resume_indicator.dart`、`lib/services/playback_progress_service.dart` | 本地素材 + 已有进度 | 部分 | 需先播放一段时间再退出重进 |
| 2.10 `还原画面`（缩放后浮出的还原 chip） | `播放页` 双指缩放后 → `还原画面`(playerRestoreView) | `lib/pages/player/views/player_zoom_restore_chip.dart` | 本地素材 | 可 | |
| 2.11 循环播放面板（`关闭`/`列表循环`/`单集循环`） | `播放页` → 顶栏槽位/`更多` → `循环播放`(playerActionLoop) | `lib/pages/player/views/player_loop_panel.dart`、`lib/models/player_loop.dart` | 本地素材 | 可 | |
| 2.12 章节跳段面板（章节列表、点击跳转、`当前视频无章节信息`） | `播放页` → 顶栏 `章节`(playerActionChapter) | `lib/pages/player/views/player_chapter_panel.dart`、`lib/services/chapter_tracker.dart` | 本地素材（含章节视频） | 部分 | 无章节素材只能测空态 |
| 2.13 章节自动跳过 + 跳过胶囊（`已跳过片头`/`已跳过片尾`） | `播放页` → 章节跳段 → `自动跳过`(playerChapterSkipAuto) | `lib/pages/player/views/player_chapter_skip_panel.dart`、`lib/services/chapter_skip_settings.dart` | 本地素材（含章节） | 部分 | 关闭时仅弹跳过胶囊 |
| 2.14 自定义跳过关键词（片头/片尾关键词、按标题匹配、逗号/分号/换行分隔） | → 章节跳段 → `自定义关键词` | 同上 | 本地素材（含章节） | 部分 | 关键词输入用 `input text` 可测 |
| 2.15 片头片尾面板（`启用跳过片头片尾`、`片头范围`、`片尾范围`、`设为当前时间`、`设为当前剩余时间`、`一键重置`） | `播放页` → 顶栏 `片头片尾`(playerActionIntroOutro) | `lib/pages/player/views/player_intro_outro_panel.dart`、`lib/services/intro_outro_settings.dart` | 本地素材 | 可 | 手动秒数设置，不依赖章节 |
| 2.16 片头片尾自动跳过触发（`已跳过片头`/`已跳过片尾` toast） | 播放到设定区间 | `lib/utils/intro_outro_skip.dart`、`lib/services/intro_outro_tracker.dart` | 本地素材 | 部分 | 需等时间轴到位 |
| 2.17 底栏固定按钮：`超分辨率` 胶囊 | `播放页` → 底栏最左胶囊 | `lib/pages/player/views/player_bottom_bar.dart`、`player_super_resolution_panel.dart` | 本地素材 | 可 | 标签随档位变化，是 l10n 动态文案回归点 |
| 2.18 底栏固定按钮：`列表` 图标 | 同上 | 同上 | 本地素材 | 可 | |
| 2.19 底栏固定按钮：`倍速` 图标 | `播放页` → 底栏 `倍速` | `lib/pages/player/views/player_speed_panel.dart` | 本地素材 | 可 | 倍速**不在**顶栏可自定义动作里 |
| 2.20 底栏固定按钮：`选择屏幕`（横竖屏切换） | `播放页` → 底栏最右 `选择屏幕`(playerCastSelectScreen) | `lib/pages/player/views/player_bottom_bar.dart`、`player_portrait_page.dart` | 本地素材 | 可 | 横屏 ↔ 竖屏播放页切换 |
| 2.21 弹幕开关 + 弹幕设置按钮（底栏） | `播放页` → 底栏时间右侧 | `lib/pages/player/views/player_danmaku_buttons.dart` | 本地素材 | 可 | 开关图标 `打开弹幕`/`关闭弹幕` 带 tooltip |
| 2.22 顶部信息：`时间` 显示 | `我的` → `播放设置` → `顶部信息` → `时间` | `lib/pages/settings/player_settings_page.dart`、`player_status_bar.dart` | 无 | 可 | |
| 2.23 顶部信息：`电量` 显示 | → `顶部信息` → `电量` | 同上 | 无 | 可 | |
| 2.24 顶部信息：`网速` 显示（实时下行速率） | → `顶部信息` → `网速` | 同上 | 本地素材 | 可 | 本地播放网速可能为 0，建议用网络播放验 |
| 2.25 顶部信息：`数据类型` 显示（WiFi / 移动数据） | → `顶部信息` → `数据类型` | 同上 | 无 | 可 | 需 `ACCESS_NETWORK_STATE`（安装即授予） |
| 2.26 `常驻进度线`（隐藏控制层后底部细线） | `我的` → `播放设置` → `播放行为` → `常驻进度线` | 同上 | 本地素材 | 可 | |
| 2.27 `显示章节进度条`（进度条标章节 + 显示章节名） | → `播放设置` → `显示章节进度条` | 同上 | 本地素材（含章节） | 部分 | 无章节素材时看不到效果 |
| 2.28 `进度条缩略图` 开关 | → `播放设置` → `进度条缩略图` | 同上 | 本地素材 | 可 | |
| 2.29 `记住上次倍速` | → `播放设置` → `记住上次倍速` | 同上 | 本地素材 | 部分 | 需退出重进播放页 |
| 2.30 `保存音量到系统` | → `播放设置` → `保存音量到系统` | 同上、`lib/services/device_services.dart` | 无 | 部分 | 需读系统音量验证（`adb shell media volume --get`） |
| 2.31 `按钮背景`（控制按钮加半透明底） | → `播放设置` → `按钮背景` | 同上 | 无 | 可 | |
| 2.32 `启用播放界面动画` | → `播放设置` → `启用播放界面动画` | 同上 | 无 | 可 | 关闭后动画消失，截图对比序列帧 |
| 2.33 `已观看`进度阈值（含点击数值自定义比例） | → `播放设置` → `已观看进度阈值` | 同上、`lib/utils/watch_state.dart` | 无 | 可 | |

### 2.2 手势与交互

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.34 双击手势模式三选一：`双击暂停/播放` / `双击左退右进` / `混合模式` | `我的` → `播放设置` → `手势` → 双击模式 | `lib/utils/player_gestures.dart`、`lib/pages/settings/player_settings_page.dart` | 本地素材 | 可 | `混合模式` = 中央 40% 暂停、左右各 30% 快退/快进 |
| 2.35 双击快退 / 双击快进（在左半屏/右半屏或左右 30% 区域） | `播放页` → 双击左/右侧 | 同上 | 本地素材 | 可 | 双指点按可用 `input tap` 连点两次模拟，但 `input tap` 无坐标抖动，需确认被识别为 double tap |
| 2.36 `快进/快退时长`（默认 10 秒，点击数值可自定义秒数） | `我的` → `播放设置` → `快进/快退时长` | `lib/pages/settings/player_settings_page.dart` | 无 | 可 | 自定义值输入框 |
| 2.37 水平滑动 seek（`swipeSeekSecondsPerFullWidth = 90` 秒/满屏宽） | `播放页` → 画面水平 `swipe` | `lib/utils/player_gestures.dart`、`lib/pages/player/views/player_gesture_layer.dart`、`player_swipe_seek_overlay.dart` | 本地素材 | 部分 | `input swipe` 可发；判定要看 overlay 显示的目标时间 |
| 2.38 左侧垂直滑动调亮度（含 `亮度灵敏度`） | `播放页` → 左半屏上下 `swipe` | 同上、`lib/services/device_services.dart` | 无 | 部分 | `setWindowBrightness` 只能目视 |
| 2.39 右侧垂直滑动调音量（含 `音量灵敏度`） | `播放页` → 右半屏上下 `swipe` | 同上 | 无 | 部分 | 可用 `adb shell media volume --get` 辅助判定（走系统音量段） |
| 2.40 音量增强（系统音量满后继续放大到 100%+cap） | `我的` → `播放设置` → `播放行为` → `音量增强` + `增强上限` | `lib/utils/player_gestures.dart`、`lib/services/player_controls_settings.dart` | 无 | 不可 | 需系统音量先到 100%；模拟器无真实音频输出，`>100%` 只能看 UI 数字 |
| 2.41 长按临时倍速（长按画面） | `播放页` → 长按画面 | `lib/pages/player/views/player_speed_indicator.dart` | 本地素材 | 部分 | 需 `input swipe` 同点起止模拟长按；倍速提示在顶部 |
| 2.42 长按期间左右滑动动态调速（1.5–4.0，步进 0.5，6 档） | `播放页` → 长按后不松手水平滑动 | `lib/utils/player_gestures.dart`（`dynamicSpeedIndex`、`dynamicSpeedStepsPerScreenWidth = 6.0`） | 本地素材 | 部分 | 档位离散，`input swipe` 时长/距离映射到哪一档不可预先预期，**最难测的手势** |
| 2.43 长按倍速开关 + 倍速指示器开关 | `我的` → `播放设置` → `长按倍速` / `倍速播放指示器` | `lib/pages/settings/player_settings_page.dart` | 无 | 可 | 关闭后长按不再生效/不再显示提示 |
| 2.44 双指缩放画面（含 `双指缩小视频` 开关） | `播放页` → 双指捏合 / `播放设置 → 双指缩小视频` | `lib/pages/player/views/player_gesture_layer.dart` | 本地素材 | 不可 | adb `input` **不支持多点触控**手势（需 `sendevent` 脚本，超出常规黑盒口径） |
| 2.45 画面锁定 / 解锁 | `播放页` → 右侧 `锁定`(playerLock) / 点画面后 `解锁`(playerUnlock) | `lib/pages/player/views/player_right_actions.dart` | 本地素材 | 可 | |
| 2.46 锁定态双击豁免（锁定下双击仍可播放/暂停） | `我的` → `播放设置` → `锁定状态豁免双击`（含确认弹窗） | `lib/utils/player_gestures.dart`、`lib/pages/settings/player_settings_page.dart` | 本地素材 | 可 | 开启前后双击行为不同，可对比验证 |
| 2.47 截图（保存到相册，`已保存到相册` / 失败提示） | `播放页` → 右侧 `截图`(playerScreenshot) | `lib/pages/player/views/player_right_actions.dart` | 系统权限（相册写入） | 部分 | 需 `adb pull` 相册目录核对；文件名/相册名固定中文（设计如此，不算残留） |
| 2.48 界面跟随重力旋转（含确认弹窗） | `我的` → `播放设置` → `视频方向` → `界面跟随重力旋转` | `lib/pages/settings/player_settings_page.dart`、`lib/utils/player_orientation.dart` | 无 | 部分 | 需 `adb shell settings put system user_rotation` 改方向验证 |
| 2.49 视频方向模式：`跟随视频方向` / `始终竖屏` / `始终横屏` | `我的` → `播放设置` → `视频方向` | 同上 | 本地素材（横屏/竖屏各一） | 可 | 竖屏视频需 M01 第三支 |

### 2.3 倍速 / 播放速度

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.50 倍速面板打开（底栏 `倍速` 图标） | `播放页` → 底栏倍速 | `lib/pages/player/views/player_speed_panel.dart` | 本地素材 | 可 | |
| 2.51 `我的预设` 倍速列表 + 选择 | → 倍速面板 | 同上 | 本地素材 | 可 | |
| 2.52 `精确调速`（滑杆/数值） | → 倍速面板 | 同上 | 本地素材 | 可 | |
| 2.53 `临时应用`（不写入预设） | → 倍速面板 → `临时应用`(playerApplyTemporarily) | 同上 | 本地素材 | 可 | |
| 2.54 `添加到预设`（含 `该倍速已在预设中` / 预设上限提示） | → 倍速面板 | 同上 | 无 | 可 | 占位符文案 `playerSpeedPresetLimit` |
| 2.55 `归位`（恢复 1.0x） | → 倍速面板 → `归位`(playerSpeedReset) | 同上 | 本地素材 | 可 | |
| 2.56 `重置预设` | → 倍速面板 → `重置预设`(playerResetPresets) | 同上 | 无 | 可 | |
| 2.57 倍速左滑提示文案（`左右滑动可临时调节长按倍数`） | 长按倍速时 | `lib/pages/player/views/player_speed_indicator.dart` | 本地素材 | 部分 | |

### 2.4 画面 / 渲染 / 解码 / 超分

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.58 画面比例面板（`拉伸`/`裁剪`/`等宽`/`等高`/`原始`/`限制`/`4:3`/`16:9`） | `播放页` → 顶栏 `比例`(playerActionAspect) | `lib/pages/player/views/player_fit_panel.dart`、`lib/models/player_action.dart` | 本地素材 | 可 | 8 项全覆盖是 l10n 回归重点（`playerVideoFitLabel`） |
| 2.59 超分辨率面板 · 模式（`关闭`/`模式A`/`模式B`/`模式C`/`模式A+`/`模式B+`/`模式C+`，各带说明） | `播放页` → 底栏超分胶囊 | `lib/pages/player/views/player_super_resolution_panel.dart`、`lib/services/super_resolution_service.dart` | 本地素材 | 部分 | 效果（画质）无法黑盒判定，只能验「选中态 + 说明文案」 |
| 2.60 超分质量（`流畅`/`均衡`/`高清`，各带说明） | → 超分面板 → `超分质量`(playerSuperResolutionQuality) | 同上 | 本地素材 | 可 | |
| 2.61 `记忆超分模式`（下次自动应用上次档位） | → 超分面板 → `记忆超分模式` | 同上 | 本地素材 | 部分 | 需退出重进验证 |
| 2.62 解码面板 · 解码预设（`快速`/`标准配置`/`高质量`/`GPU 高质量`/`低延迟`/`软解快速`） | `播放页` → 顶栏 `解码`(playerActionDecode) | `lib/pages/player/views/player_decode_panel.dart`、`lib/services/decode_settings.dart` | 本地素材 | 部分 | 切换后弹 `需重启应用` 对话框（`立即重启`/`稍后重启`） |
| 2.63 解码模式（`自动（安全硬解）`/`硬解`/`硬解+`/`软解`）+ 各档说明 | `我的` → `播放设置` → `解码` / `设备信息` 内 | 同上、`lib/services/decode_settings.dart` | 本地素材 | 部分 | 真值需真机；模拟器上硬解/软解可达性不同 |
| 2.64 `启用 GPU-next`（libplacebo 新渲染器） | `我的` → `播放设置` → `启用 GPU-next` | `lib/services/decode_settings.dart`、`lib/main.dart` | 设备 GPU | 部分 | `切换后需重启播放器（重开视频）生效`；有「不黑屏」提示 |
| 2.65 `启用 Vulkan`（依赖 GPU-next 开启） | `我的` → `播放设置` → `启用 Vulkan` | 同上 | 设备 GPU | 部分 | 关闭 GPU-next 时 Vulkan 被禁用（`settingsPlayerVulkanNeedsGpuNext`） |
| 2.66 杜比视界偏色提示弹窗（+ `不再提示`） | 播放杜比视界视频时自动弹 | `lib/widgets/dolby_vision_hint.dart`、`lib/services/dolby_vision_settings.dart` | 本地素材（DV 视频） | 不可 | 需要真实杜比视界素材 + 设备检测通道返回 true |
| 2.67 解码器详情页（基本信息/MIME/规范名/类型/加速方式/别名/码率范围/分辨率能力/对齐/最大实例数/音频能力/最大声道数/硬件特性/色彩格式/Profile） | `我的` → `设备信息` → 某解码器 | `lib/pages/settings/decoder_detail_page.dart` | 无 | 可 | 纯展示，l10n 键极密集 |

### 2.5 音轨 / 音频 / 均衡器 / 听视频

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.68 音轨面板 · 音轨切换（内嵌多音轨） | `播放页` → 顶栏 `音频`(playerActionAudio) | `lib/pages/player/views/audio_panel.dart`、`lib/services/audio_service.dart` | 本地素材（≥2 音轨） | 部分 | 需 M02 |
| 2.69 音轨面板 · 无音轨提示（`当前视频没有音轨，可在下方导入外部音轨`） | 同上 | 同上 | 本地素材（无音轨视频） | 部分 | 需 M05 |
| 2.70 `导入外部音轨`（选文件 → `已导入外部音轨` / `导入失败，请检查文件格式`） | → 音频面板 → `导入外部音轨` | 同上、`android/.../MainActivity.kt`（`openAudioPicker`/`copyAudioFromUri`） | 本地素材（m4a/aac/mp3）+ 系统权限 | 部分 | 需经系统文件选择器，adb 交互受限 |
| 2.71 `外部音轨` 标记 + `移除已导入的音轨` | → 音频面板 | 同上 | 本地素材 | 可 | `临时生效，退出播放后不保留` |
| 2.72 音频声道（`安全自动`/`单声道`/`立体声`/`反向立体声`） | → 音频面板 → `音频声道`(playerAudioChannel) | 同上 | 本地素材 | 可 | |
| 2.73 音频处理：`音量标准化` 开关 | → 音频面板 → `音频处理` | 同上 | 本地素材 | 部分 | 听感无法黑盒判定，只能验开关态持久化 |
| 2.74 音频处理：`动态范围压缩` 开关 | → 音频面板 | 同上 | 本地素材 | 部分 | 同上 |
| 2.75 音频均衡器面板（`启用均衡器` / `预设` / `频段调节` / `低音增强` / `虚拟环绕` / `一键重置`） | `播放页` → 顶栏 `音频均衡器`(playerActionEqualizer) | `lib/pages/player/views/equalizer_panel.dart`、`lib/services/equalizer_settings.dart` | 本地素材 | 部分 | 频段滑杆数值可截图判定；听感不可 |
| 2.76 均衡器预设六档（`平直`/`对白增强`/`电影`/`低音震撼`/`高音清晰`/`柔和夜间`） | → 均衡器面板 → `预设` | `lib/models/equalizer_preset.dart`、`lib/l10n/label_maps.dart` | 本地素材 | 可 | |
| 2.77 `听视频` 界面进入（竖屏全屏，封面模糊背景） | `播放页` → 顶栏 `听视频`(playerActionListen) | `lib/pages/player/audio_player_page.dart` | 本地素材 | 可 | |
| 2.78 听视频 · 播放/暂停、上一集、下一集、进度拖动 | 听视频界面 | 同上 | 本地素材 | 可 | 与播放页共享同一 Player、不恢复进度 |
| 2.79 听视频 · 倍速（0.5–4.0 步进 0.5） | 听视频 → 倍速 | `lib/pages/player/views/audio_player_panels.dart` | 本地素材 | 可 | `audioPlaybackSpeed` |
| 2.80 听视频 · 播放列表 + `随机播放` + 循环（`循环关闭`/`单曲循环`/`列表循环`） | 听视频 → 列表 | 同上、`lib/utils/audio_shuffle.dart` | 本地素材 | 可 | |
| 2.81 听视频 · `定时关闭`（15/30/60 分钟 / `播完当前` / 自定义） | 听视频 → `定时关闭`(audioSleepTimer) | 同上 | 本地素材 | 部分 | 到点自动暂停，需等待（自定义分钟可缩短验证） |
| 2.82 听视频 · 后台播放（前台服务保活，通知常驻） | 听视频 → 按 Home 退后台 | `android/.../BackgroundPlaybackService.kt`、`lib/services/device_services.dart` | 系统权限（POST_NOTIFICATIONS 可选） | 部分 | 需 `adb shell dumpsys activity services com.azxcvn.moumou` + 通知栏截图 |
| 2.83 后台播放通知点击回 App | 下拉通知栏 → 点通知 | 同上 | 无 | 可 | `singleTop`，不新建实例 |
| 2.84 后台播放通知渠道名/描述（`听视频后台播放` / `在后台继续播放视频音频`） | 系统设置 → 应用 → 通知 | `android/app/src/main/res/values/strings.xml`、`values-en/strings.xml` | 无 | 部分 | **渠道名只在全新安装生效**；验 en 必须卸载重装 |

### 2.6 播放页顶栏动作与控制栏自定义

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.85 顶栏动作槽位点击（字幕/弹幕/音频/比例/解码/章节/投屏/画中画/听视频/循环/片头片尾/播放诊断/音频均衡器） | `播放页` → 顶栏图标 | `lib/pages/player/player_page.dart`（`_handleSlotAction`）、`lib/models/player_action.dart` | 本地素材 | 可 | 13 个动作全部 `implemented = true` |
| 2.86 `更多` 面板（未放置动作列表 + `可添加` 区） | `播放页` → 顶栏 `更多`(commonMore) | `lib/pages/player/views/player_top_bar.dart`、`lib/pages/player/player_page.dart` | 本地素材 | 可 | `未放置的功能` / `暂无已启用动作，从下方添加` |
| 2.87 `编辑控制栏`（长按拖拽排序、增删、最多 5 个） | `播放页` → 顶栏 `更多` → `编辑控制栏`(playerEditControlBar) | `lib/pages/player/views/portrait_edit_panel.dart` | 本地素材 | 部分 | 拖拽排序 adb 可勉强用 `input swipe` 模拟，稳定性一般；`已启用（长按拖拽排序）` |
| 2.88 `重置控制栏` | → 编辑控制栏 → `重置控制栏`(playerResetControlBar) | 同上 | 无 | 可 | |
| 2.89 顶栏动作达上限提示（`playerMaxActions`） | 编辑控制栏加第 6 个 | 同上 | 无 | 可 | |
| 2.90 长按拖拽排序持久化 | 编辑后杀进程重启 | `lib/services/player_controls_settings.dart` | 无 | 可 | |
| 2.91 顶栏 `返回` | `播放页` → 左上角 `返回`(commonBack) | `lib/pages/player/views/player_top_bar.dart` | 无 | 可 | |

### 2.7 播放页内的字幕（详见 §4 的字幕域）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.92 字幕轨道列表 + 选择某轨 | `播放页` → 顶栏 `字幕`(playerActionSubtitle) | `lib/pages/player/views/subtitle_panel.dart` | 本地素材（内嵌字幕轨） | 部分 | |
| 2.93 `关闭字幕` / `自动`（内核默认挑选） | → 字幕面板 | 同上 | 本地素材 | 可 | `playerSubtitleTrackAutoDesc` |
| 2.94 `优先选中文字幕轨`（含「特效/双语」优先；手动选过的不改） | → 字幕面板 → `字幕杂项` | 同上、`lib/utils/subtitle_language.dart` | 本地素材（中/英双轨） | 部分 | 隐式规则，界面上无标记，**只能播后目视** |
| 2.95 `导入外部字幕`（pick 文件 → `已导入外挂字幕` / `导入失败`） | → 字幕面板 → `导入外部字幕` | 同上、`android/.../MainActivity.kt`（`openDocumentPicker`/`copySubtitleFromUri`） | 本地素材（srt/ass/vtt） | 部分 | 经系统文件选择器 |
| 2.96 字幕文件选择器（`排序方式`/`升序`/`降序`/`上级`） | → `导入外部字幕` 弹窗 | `lib/pages/player/views/subtitle_file_picker.dart` | 本地素材 | 可 | 排序切换可测 |
| 2.97 `移除已导入的字幕` | → 字幕面板 | `lib/pages/player/views/subtitle_panel.dart` | 本地素材 | 可 | |
| 2.98 字幕延迟（快捷调整、`重置为 0 秒`、`设为当前时间`、`{value} 秒` 动态文案） | → 字幕面板 → `字幕延迟` | 同上 | 本地素材 | 可 | 占位符 `playerDelaySeconds` |
| 2.99 字幕样式：字体 / 字号 / 字重 / `文字颜色` / `描边颜色` / `描边粗细` / `背景颜色` / `背景框大小` | → 字幕面板 → `字幕样式` | 同上、`lib/utils/subtitle_style_properties.dart` | 本地素材 | 可 | 颜色选择器（`lib/widgets/color_editor_row.dart`）含 `自定义调色`/`收起自定义调色` |
| 2.100 字幕文字效果：`粗体` / `斜体` / `字间距` / `模糊` | → 字幕面板 → `文字效果` | 同上 | 本地素材 | 部分 | 模糊仅文本字幕生效（见 ASS 限制） |
| 2.101 `字幕缩放与位置`：`缩放比例` / `垂直位置` / `重置缩放与位置` | → 字幕面板 | 同上 | 本地素材 | 可 | 动态数值文案 `playerVerticalPositionValue` |
| 2.102 `强制覆盖内嵌样式`（使用上方设置渲染） | → 字幕面板 | 同上 | 本地素材（ASS 特效字幕） | 部分 | 与 `字幕使用自带的样式与字体` 互斥 |
| 2.103 ASS 内嵌字幕限制说明面板（哪些样式不生效/生效） | → 字幕面板 → `ASS 内嵌字幕的限制` | 同上 | 无 | 可 | 纯文案，l10n 长句回归点 |
| 2.104 `字幕字体`：`字体目录` 导入 / `清除目录` / `当前字体` / `默认字体` / `跟随系统字库` | → 字幕面板 → `字幕字体` | 同上、`android/.../MainActivity.kt`（`openFontDirectoryPicker`/`copyFontsFromDirectory`） | 本地素材（.ttf/.otf 目录）+ 系统权限 | 部分 | `字体更改需退出播放器并重新进入后生效` |
| 2.105 `重置所有样式` | → 字幕面板 | 同上 | 无 | 可 | |
| 2.106 字幕自动加载（同名外挂字幕，`playerAutoLoadedSubtitle` 提示） | `播放页` 打开同名视频 | `lib/utils/subtitle_auto_match.dart` | 本地素材（同名 srt/ass） | 部分 | 严格同名才命中 |
| 2.107 字幕记忆（下次进入记住上次选的轨） | 退出重进播放页 | `lib/utils/subtitle_memory.dart` | 本地素材 | 可 | |

### 2.8 播放页内的弹幕（详见 §3）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.108 弹幕二级界面（`本地弹幕` / `网络弹幕` / `自动匹配` / `弹幕设置`） | `播放页` → 顶栏 `弹幕`(playerActionDanmaku) | `lib/pages/player/views/player_danmaku_panel.dart` | 无 | 可 | |
| 2.109 `本地弹幕` · `选择弹幕文件`（XML/弹弹Play 文件） | → 弹幕面板 → `本地弹幕` | 同上、`lib/utils/danmaku_local_file.dart`、`lib/utils/danmaku_xml.dart` | 本地素材（弹幕 XML） | 部分 | 经系统文件选择器 |
| 2.110 弹幕加载失败提示（`弹幕加载失败，请检查文件格式`） | 选到坏文件 | 同上 | 本地素材（坏文件） | 可 | |
| 2.111 `网络弹幕` 搜索（关键词输入、`搜索`、`停止搜索`、`搜索中…`、结果计数） | → 弹幕面板 → `网络弹幕` | `lib/pages/player/views/player_danmaku_network_panel.dart`、`lib/services/danmaku_network_service.dart` | 网络（弹弹Play API） | 部分 | 需 M15；多服务器并发有 `playerDanmakuPartialServerFailed` 部分失败提示 |
| 2.112 `选择匹配结果`（结果列表选择并加载） | → 网络弹幕 → 点结果 | 同上 | 网络 | 部分 | |
| 2.113 `未找到匹配的弹幕` / `未找到相关番剧，请尝试其他关键词` | 搜索无结果 | 同上 | 网络 | 部分 | 两个不同文案，易只测一个 |
| 2.114 `自动匹配`（按文件名/集数自动匹配并加载） | → 弹幕面板 → `自动匹配` | `lib/services/danmaku_auto_match_cache_store.dart`、`lib/utils/danmaku_episode.dart` | 网络 + 命名规范的素材 | 部分 | |
| 2.115 剧集选择面板（`跳至第 [N] 集`、`集数` 输入、`请输入集数（数字）`、`未能从文件名识别集数`） | → 网络弹幕 → 剧集跳转 | `lib/pages/player/views/player_danmaku_episodes_panel.dart` | 网络 | 部分 | 占位符密集（`playerEpisodeTotalFromServer` 等） |
| 2.116 弹幕设置面板 · 基本样式（`弹幕字号` / `弹幕速度`（数值越小越快）/ `描边粗细` / `不透明度` / `弹幕行高`） | → 弹幕面板 → `弹幕设置` | `lib/pages/player/views/player_danmaku_settings_panel.dart` | 本地弹幕素材 | 可 | |
| 2.117 弹幕显示区域（`顶部弹幕` / `底部弹幕` / `滚动弹幕` 三个开关） | → 弹幕设置 → `显示区域` | 同上 | 本地弹幕素材 | 可 | |
| 2.118 `海量弹幕`（轨道占满时叠加绘制，不丢弃） | → 弹幕设置 → `弹幕配置` | 同上、`lib/services/danmaku_scheduler.dart` | 本地弹幕素材（超大量） | 部分 | 需 M06 里「海量弹幕」素材 |
| 2.119 `弹幕去重`（相同时间相同内容合并） | → 弹幕设置 | `lib/utils/danmaku_dedup.dart` | 本地弹幕素材 | 部分 | 需含重复弹幕的素材 |
| 2.120 `弹幕合并`（不同时间相同内容合并且计数） | → 弹幕设置 | `lib/utils/danmaku_merge.dart` | 本地弹幕素材 | 部分 | |
| 2.121 弹幕字体：`跟随系统字体` / `跟随App字体` / `自定义字体`（+ 字体目录导入、`需要重启应用`） | → 弹幕设置 → `弹幕字体` | 同上、`lib/services/danmaku_settings.dart` | 本地字体素材 | 部分 | 字体模式三选一（`danmakuFontMode*`） |
| 2.122 弹幕颜色模式（`跟随弹幕颜色` / `随机渐变色` / `指定颜色` + 各自说明） | → 弹幕设置 → 颜色模式 | `lib/utils/danmaku_random_color.dart`、`lib/utils/danmaku_palette_color.dart` | 本地弹幕素材 | 可 | 三项说明文案差异大 |
| 2.123 弹幕调色板（多选、`添加到调色板`、`该颜色已在调色板中`、`调色板已满`、`已选 N 色`） | → 弹幕设置 → `弹幕颜色（可多选，随机使用）` | 同上 | 无 | 可 | 占位符 `playerDanmakuPaletteSelected`/`playerDanmakuPaletteFull` |
| 2.124 `屏蔽词`（输入关键词屏蔽，多条） | → 弹幕设置 → `屏蔽词` | `lib/utils/danmaku_blocklist.dart` | 本地弹幕素材（含屏蔽词） | 部分 | 需 M06 第三支 |
| 2.125 `弹幕偏移` / `时间轴偏移`（`提前 1 秒` / `延后 1 秒` / `重置偏移` / `无偏移` / `提前 {n} 秒`） | → 弹幕设置 → `弹幕偏移` | `lib/utils/danmaku_timeline.dart`、`lib/l10n/label_maps.dart`（`danmakuOffsetText`） | 本地弹幕素材 | 可 | 动态文案 `danmakuOffsetAdvance`/`danmakuOffsetDelay` |
| 2.126 `恢复默认设置`（弹幕设置一键重置） | → 弹幕设置 → `恢复默认设置` | 同上 | 无 | 可 | |
| 2.127 弹幕图层渲染（滚动/顶部/底部轨道，含大量弹幕性能） | `播放页` 播放中 | `lib/pages/player/views/player_danmaku_layer.dart` | 本地弹幕素材 | 部分 | 只能看截图是否有弹幕；轨道/性能需序列截图 |

### 2.9 哔哩哔哩相关播放（播放页内）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.128 画质面板（清晰度列表、`暂无可用画质`、`切换画质会重开播放并保持进度`） | `播放页`（B站源） → 顶栏 `更多` → 画质 | `lib/pages/player/views/player_quality_panel.dart` | 账号 + 网络 | 部分 | 需 M08/M09 |
| 2.129 画质切换失败/自动降级提示（`playerQualitySwitchFailed` / `playerQualityUnavailableSwitched`） | 同上 | 同上 | 账号 + 网络 | 部分 | 占位符文案 |
| 2.130 B站播放列表面板（剧集列表、`限免`/`预告` 角标、`当前播放`、`没有获取到剧集列表`） | `播放页`（B站源） → 顶栏 `更多` → 播放列表 | `lib/pages/player/views/player_bili_playlist_panel.dart` | 账号 + 网络 | 部分 | `playerBiliTotalEpisodes`/`playerBiliCurrentOfTotal` 占位符 |
| 2.131 B站弹幕自动加载（`playerNetworkDanmakuLoadedAuto` / `...Manual` 提示） | `播放页`（B站源） 打开 | `lib/services/bilibili/bili_danmaku_service.dart` | 账号 + 网络 | 部分 | |
| 2.132 B站字幕自动加载（`playerAutoLoadedSubtitle`） | `播放页`（B站源） 打开 | `lib/services/subtitle_service.dart` | 账号 + 网络 | 部分 | |
| 2.133 播放地址解析失败提示（`解析播放地址失败` / WBI 密钥缺失 / 风控 / 需要大会员 / 无权限） | B站源播放失败时 | `lib/pages/bilibili/bili_play_launcher.dart`、`lib/l10n/error_texts.dart` | 账号 + 网络 | 部分 | `biliRiskControlTriggered` 等分支极难稳定复现 |
| 2.134 无网络时切换剧集提示（`网络连接不存在，无法切换`） | B站播放中切集（断网） | `lib/pages/player/player_page.dart` | 网络 | 部分 | 需断网操作 |

### 2.10 投屏 / 画中画 / 诊断

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 2.135 `画中画` 进入 + 失败提示（`当前设备不支持画中画` / `进入画中画失败`） | `播放页` → 顶栏 `画中画`(playerActionPip) | `lib/pages/player/player_page.dart`、`android/.../MainActivity.kt`（`isPipSupported`/`enterPip`） | 本地素材 + 系统支持 PiP | 部分 | 模拟器 Android 15 一般支持 |
| 2.136 PiP 宽高比（`lib/utils/pip_aspect.dart`） | 进入 PiP 后 | `lib/utils/pip_aspect.dart` | 本地素材 | 部分 | 只能截图对比宽高比 |
| 2.137 自动进入 PiP（`setAutoPipEnabled`） | 播放中按 Home | `android/.../MainActivity.kt` | 本地素材 | 部分 | |
| 2.138 `投屏` 设备选择对话框（`正在搜索投屏设备…`、`未发现可投屏设备…`、`连接成功`/`投屏失败`/`设备已离线`） | `播放页` → 顶栏 `投屏`(playerActionCast) | `lib/widgets/cast_device_dialog.dart`、`lib/services/cast/cast_service.dart` | 局域网设备（DLNA 渲染器） | 部分 | 无设备时只能测「未发现」分支（该分支是 `可`） |
| 2.139 投屏不支持该来源提示（仅本地文件可投） | 网络源视频 → 投屏 | `lib/services/cast/cast_service.dart`、`lib/utils/cast_source.dart` | 网络 | 部分 | `暂不支持投屏该来源` |
| 2.140 播放诊断面板（容器/视频编码/音频编码/视频输出/同步方式/像素格式/容器帧率/实际帧率/视频码率/音频参数/音频码率/音画同步/缓冲时长/可播时长/缓存占用/下行速率/丢帧/解码丢帧/延迟帧 + 自动刷新提示 + 读取失败提示） | `播放页` → 顶栏 `播放诊断`(playerActionDiagnostics) | `lib/pages/player/views/player_diagnostics_panel.dart`、`lib/utils/player_diagnostics.dart` | 本地素材 | 部分 | 数值随播放变化；`每秒自动刷新 · 数据来自 mpv 运行时属性`；占位符 `playerDiagnosticsFailedValue` 等 |
| 2.141 播放页退出释放资源（释放 LAN 端口、停止后台服务） | `播放页` → 返回 | `lib/services/cast/lan_media_server.dart`、`android/.../BackgroundPlaybackService.kt` | 无 | 部分 | 需 `dumpsys` 查服务是否停止 |

---

## 3. 弹幕

### 3.1 弹幕服务器管理

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 3.1 进入 `弹幕服务器` | `我的` → `弹幕` 组 → `弹幕服务器` | `lib/pages/settings/danmaku_server_page.dart` | 无 | 可 | |
| 3.2 服务器列表 + 每台启用开关 | → `弹幕服务器` → `服务器` 组 | 同上、`lib/services/danmaku_server_settings.dart` | 无 | 可 | |
| 3.3 内置服务器 `弹弹Play（默认）`（不可编辑/删除） | → `弹幕服务器` | 同上、`lib/models/danmaku_server.dart` | 无 | 可 | 持久化名固定中文（设计如此），界面显示走 `danmakuServerDisplayName` |
| 3.4 `添加服务器`（名称 + 地址，含 `名称`/`地址` 必填校验） | → `弹幕服务器` → `添加服务器` | 同上 | 网络（可用弹幕服务器地址） | 部分 | 弹窗表单可测；真实可用性需服务端 |
| 3.5 `编辑服务器` | → 长按/点服务器 → `编辑服务器` | 同上 | 无 | 可 | |
| 3.6 `删除服务器` | → 同上 → `删除服务器` | 同上 | 无 | 可 | |
| 3.7 `如何获取服务器地址`（帮助链接，`未找到可用的浏览器` 分支） | → `弹幕服务器` → 帮助项 | 同上 | 网络/浏览器 | 部分 | |
| 3.8 `搜索结果自动去重` 开关 + 开启确认弹窗（`重复番剧合并为一条，保留集数最全的` / `每台服务器的结果各自展示`） | → `弹幕服务器` → `搜索结果自动去重` | 同上 | 网络（多服务器） | 部分 | 关闭态说明文案只在关闭时出现，易漏 |
| 3.9 `切集自动匹配弹幕` 开关（+ `请先停用弹弹Play 服务器` 冲突提示） | → `弹幕服务器` → `切集自动匹配弹幕` | 同上 | 网络 | 部分 | 冲突提示带细节文案，易漏 |
| 3.10 服务器配置持久化（重启保持） | 改动 → 杀进程重启 | `lib/services/danmaku_server_settings.dart` | 无 | 可 | |

### 3.2 弹幕来源与解析

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 3.11 本地弹幕 XML 解析（B 站格式） | `播放页` → 弹幕 → `本地弹幕` | `lib/utils/danmaku_xml.dart`、`lib/services/danmaku_service.dart` | 本地素材（弹幕 XML） | 部分 | 经文件选择器 |
| 3.12 弹弹Play 弹幕格式解析 | 同上 | `lib/utils/dandan_comment.dart`、`lib/models/dandan_models.dart` | 本地素材 | 部分 | |
| 3.13 弹幕同名自动加载（与视频同名 `.xml`） | `播放页` 打开同名视频 | `lib/utils/danmaku_local_file.dart` | 本地素材（同名弹幕） | 部分 | 同名匹配名固定 `弹幕.xml`（设计如此，不翻译） |
| 3.14 网络弹幕搜索与结果呈现（多服务器顺序呈现） | `播放页` → 弹幕 → `网络弹幕` | `lib/services/danmaku_network_service.dart`、`lib/services/danmaku_search_store.dart` | 网络 + 账号（B站源） | 部分 | |
| 3.15 弹幕搜索历史（保存/清空） | → 网络弹幕 → `清空`(commonClearAll) | `lib/services/danmaku_search_history.dart` | 网络 | 部分 | |
| 3.16 弹弹Play 播放键/签名（`playKey`、`dandan_signature`、`dandan_play_keys`） | 自动（网络弹幕加载时） | `lib/services/dandan_play_api.dart`、`lib/services/dandan_play_keys.dart`、`lib/utils/dandan_signature.dart` | 网络 | 部分 | 无独立 UI 入口，异常时只体现为加载失败 |
| 3.17 自动匹配缓存（命中缓存不重复请求） | 二次进入同一视频 | `lib/services/danmaku_auto_match_cache_store.dart`、`lib/models/danmaku_auto_match_cache.dart` | 网络 | 部分 | 无独立 UI 入口 |
| 3.18 弹幕内存/去重/管线（同一弹幕不重复入轨） | 播放中 | `lib/services/danmaku_memory.dart`、`lib/utils/danmaku_pipeline.dart` | 本地弹幕素材 | 部分 | 内部行为，界面无直接反馈 |
| 3.19 弹幕时间轴（`danmaku_timeline`）调度与轨道分配 | 播放中 | `lib/services/danmaku_scheduler.dart`、`lib/utils/danmaku_timeline.dart` | 本地弹幕素材 | 部分 | 只能看截图 |
| 3.20 弹幕网络服务错误文案（`danmakuSearchFailed` 等） | 网络弹幕异常时 | `lib/l10n/error_texts.dart` | 网络 | 部分 | 需构造失败（如关闭网络） |

---

## 4. 字幕

### 4.1 字幕下载页

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 4.1 进入 `字幕下载` | `我的` → `下载` 组 → `字幕下载` | `lib/pages/subtitle/subtitle_download_page.dart` | 网络 | 部分 | |
| 4.2 关键词搜索（`输入关键词后点「确定」搜索字幕` / `输入影视名称或 IMDB / TMDB ID`） | → `字幕下载` → 输入框 + `确定` | 同上、`lib/services/wyzie/wyzie_api.dart` | 网络 + Wyzie 密钥 | 部分 | |
| 4.3 未配置来源时的前置提示（`请先设置 WYZIE API 密钥` / `请先设置自定义字幕地址`） | → `字幕下载` 搜索 | 同上 | 无 | 可 | 两个分支都能在未配置状态复现 |
| 4.4 搜索结果列表（名称/语言/格式/来源标签、`免费来源`/`付费来源`/`未知来源`） | → 搜索结果 | 同上、`lib/models/wyzie_models.dart` | 网络 | 部分 | |
| 4.5 单条/多条选择与下载（`下载中…`、`已下载 N 条`、`字幕下载结果`） | → 结果列表 → `下载` | 同上 | 网络 + 系统权限（写盘） | 部分 | 占位符 `subtitleDownloadedCount`/`subtitleDownloadResult` |
| 4.6 无结果提示（`未找到字幕，请换个关键词或调整字幕设置` / `搜索失败（HTTP 400）` / `未找到匹配的影视，请换个关键词`） | → 搜索无结果 | 同上、`lib/l10n/error_texts.dart` | 网络 | 部分 | 三条文案来源不同，易漏 |
| 4.7 `重新搜索` / `返回设置` | → 字幕下载 顶栏/底部 | 同上 | 无 | 可 | |
| 4.8 下载目录设置与校验（`请先设置下载目录` / `下载目录不存在，请重新选择`） | → `字幕下载` → `设置目录`(downloadSetDir) | `lib/widgets/directory_picker_dialog.dart`、`lib/services/download/download_settings.dart` | 系统权限 | 部分 | 目录被删除的分支需构造 |

### 4.2 字幕来源设置

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 4.9 `字幕来源` 单选：`Wyzie 字幕服务` / `自定义字幕地址`（互斥单选） | `我的` → `下载` → `字幕下载` → 设置区 | `lib/pages/subtitle/views/subtitle_settings_section.dart`、`lib/services/subtitle/subtitle_source_settings.dart` | 无 | 可 | 默认 Wyzie |
| 4.10 Wyzie `WYZIE API 密钥`（粘贴 `wyzie-…`、`如何获取密钥`、`密钥无效`） | → `字幕来源` → Wyzie | 同上、`lib/services/wyzie/wyzie_settings.dart` | 网络 + 密钥 | 部分 | 需 M10 |
| 4.11 Wyzie `来源` / `字幕语言` / `首选格式` / `首选编码` 四个筛选（各含 `全部来源`/`全部语言`/`全部格式`/`全部编码`） | → Wyzie 参数 | 同上 | 网络 | 部分 | 选项下拉的可选项来自服务端，无网时只能测 `全部 xx` |
| 4.12 `自定义参数` / `自定义字幕地址` 接口地址（`{name}` 占位说明、`如何自定义接口地址`） | → `字幕来源` → 自定义 | 同上、`lib/utils/custom_subtitle_parser.dart` | 网络（自建接口） | 部分 | `自定义字幕地址无效（需要 http/https 地址）` 校验可无网复现 |
| 4.13 `测试连接` / 测试片名（`连接成功` / `连接成功，但没解析出字幕` / `正在测试…`） | → 来源设置 → `测试`(commonTest) | 同上 | 网络 | 部分 | 失败分支可无网复现 |
| 4.14 自定义源响应错误提示（`响应不是合法 JSON` / `响应里找不到字幕列表` / `自定义字幕地址无效`） | → 自定义源搜索/测试 | `lib/l10n/error_texts.dart`、`lib/utils/custom_subtitle_parser.dart` | 网络 | 部分 | |
| 4.15 来源设置持久化 + `保存`/`已保存`/`保存失败` | → 改设置 → `保存` | `lib/services/wyzie/wyzie_settings.dart` | 无 | 可 | |

### 4.3 字幕解析 / 自动匹配 / 记忆

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 4.16 影视字幕结果名/语言/来源展示（`subtitleEntryDisplayName`/`DisplayLanguage`/`SourceLabel`，`未知字幕`/`未知语言`） | 字幕下载结果列表 | `lib/l10n/label_maps.dart`、`lib/models/subtitle_entry.dart` | 网络 | 部分 | 兜底文案 `未知字幕`/`未知语言` 需构造缺字段结果 |
| 4.17 本地同名外挂字幕自动匹配 | `播放页` 打开同名视频 | `lib/utils/subtitle_auto_match.dart` | 本地素材（同名字幕） | 部分 | |
| 4.18 简繁/语言优先级（`优先选中文字幕轨`） | 播放页字幕面板 | `lib/utils/subtitle_language.dart` | 本地素材（chs/cht 同名两份） | 部分 | 隐式规则，界面上不标注 |
| 4.19 网络存储远端同名字幕匹配 | 网络存储播放 | `lib/services/network_subtitle_match.dart`、`lib/services/network/network_subtitle_stream.dart` | 局域网设备 | 部分 | |
| 4.20 字幕字体注入（自定义字体进 mpv） | 播放页 → 字幕样式 → 字体 | `lib/models/subtitle_font_injection.dart`、`lib/utils/subtitle_style_properties.dart` | 本地字体素材 | 部分 | |
| 4.21 字幕记忆（记住上次选中的字幕轨） | 退出重进播放页 | `lib/utils/subtitle_memory.dart` | 本地素材 | 可 | |
| 4.22 字幕流识别与轨道列表（内嵌多字幕轨） | `播放页` → 字幕面板 | `lib/models/subtitle_track.dart`、`lib/services/subtitle_service.dart` | 本地素材（≥2 字幕轨） | 部分 | |

---

## 5. 下载

### 5.1 下载管理器

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 5.1 进入 `下载管理` | `我的` → `下载` 组 → `下载管理` | `lib/pages/download/download_manager_page.dart` | 无 | 可 | 未登录也能进 |
| 5.2 任务列表 + 状态文案（`等待`/`下载中`/`合并`/`完成`/`失败`） | → `下载管理` | 同上、`lib/services/download/download_task.dart` | 网络 + 账号（真实任务） | 部分 | 五种状态需不同阶段截图 |
| 5.3 任务进度显示（百分比/字节进度 `{done} / {total}（{percent}%）`） | → `下载管理` | 同上、`lib/l10n/label_maps.dart` | 网络 | 部分 | 占位符/全角括号回归点 |
| 5.4 `暂停` / `继续` | → 任务条目 | 同上 | 网络 | 部分 | |
| 5.5 `合并中，无法暂停` 提示 | 合并阶段点暂停 | 同上 | 网络（大文件音视频分离流） | 部分 | 窗口很短，难抓 |
| 5.6 `重试`（失败任务） | → 失败任务 → `重试` | 同上 | 网络 | 部分 | |
| 5.7 `删除` 任务 | → 任务条目 → `删除` | 同上 | 无 | 部分 | 需先有任务 |
| 5.8 `清除已完成`（+ 说明 `只清除已完成和失败的下载记录，不会删除已下载的文件。`） | → `下载管理` → `清除`(commonClear) | 同上 | 无 | 部分 | 需先有完成任务 |
| 5.9 `暂无下载任务` 空态 | → `下载管理`（无任务） | 同上 | 无 | 可 | |
| 5.10 下载任务持久化（重启恢复，不再「重启即清空」） | 建任务 → `am force-stop` → 重启 → `下载管理` | `lib/services/download/download_manager.dart` | 网络 | 部分 | 关键回归项，必须杀进程 |
| 5.11 `下载失败` 总提示 | 任务失败 | 同上 | 网络 | 部分 | |

### 5.2 哔哩哔哩视频下载

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 5.12 未登录拦截（`需要登录哔哩哔哩账号`，不进页面） | `我的` → `下载` → `哔哩视频下载` | `lib/pages/settings/settings_page.dart` | 无 | 可 | 与番剧入口同一门禁口径，容易只测一个 |
| 5.13 `哔哩视频下载` 页打开（粘贴链接输入框 + `解析`） | 登录后 → `我的` → `下载` → `哔哩视频下载` | `lib/pages/bilibili/bili_video_download_page.dart` | 账号 + 网络 | 部分 | `粘贴链接后点「解析」` 提示 |
| 5.14 解析结果：分 P / 合集 / 剧集列表 + `全选` + 已选计数（`已选 {n}/{total} 集`） | → 粘贴链接 → `解析` | 同上 | 账号 + 网络 | 部分 | 占位符 `biliEpisodesSelectedOfTotal` |
| 5.15 清晰度选择（`清晰度`(commonQuality)） | → 解析结果 → 清晰度 | 同上、`lib/services/bilibili/bili_download_service.dart` | 账号 + 网络（会员画质需大会员） | 部分 | |
| 5.16 `同步下载弹幕` 开关 | → 下载页 → `同步下载弹幕`(biliSyncDanmaku) | 同上 | 账号 + 网络 | 部分 | |
| 5.17 开始下载 + 入队提示（`已添加 {n} 个视频任务`） | → 下载页 → `下载` | 同上 | 账号 + 网络 | 部分 | |
| 5.18 解析失败分类提示（`未解析到视频分 P` / `该合集没有可下载的视频` / `该合集暂无内容` / `未获取到视频流`） | → 解析异常 | `lib/l10n/error_texts.dart` | 账号 + 网络 | 部分 | 多条分支文案 |
| 5.19 下载目录设置（`未设置下载目录` / `请先设置下载目录` / 目录被删） | → 下载页 → `设置目录` | `lib/services/download/download_settings.dart` | 系统权限 | 部分 | |

### 5.3 哔哩哔哩弹幕下载

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 5.20 未登录拦截 | `我的` → `下载` → `哔哩弹幕下载` | `lib/pages/settings/settings_page.dart` | 无 | 可 | |
| 5.21 `哔哩弹幕下载` 页打开（链接解析 + 剧集） | 登录后 → `哔哩弹幕下载` | `lib/pages/bilibili/bili_danmaku_download_page.dart` | 账号 + 网络 | 部分 | |
| 5.22 弹幕任务入队提示（`已添加 {n} 个弹幕任务`） | → 下载页 → `下载` | 同上 | 账号 + 网络 | 部分 | |
| 5.23 失败/边界提示（`该集没有弹幕` / `该番剧没有可下载的集数` / `该合集暂无内容`） | → 下载异常 | `lib/l10n/error_texts.dart` | 账号 + 网络 | 部分 | |
| 5.24 下载写入失败提示（`写入文件失败（磁盘空间或权限）` + 细节文案） | 磁盘满/无权限 | 同上 | 账号 + 网络 + 系统权限 | 不可 | 需构造磁盘满，成本高 |

### 5.4 缓存管理

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 5.25 进入 `缓存管理` | `我的` → `关于` → `工具` → `缓存管理` | `lib/pages/settings/cache_management_page.dart` | 无 | 可 | |
| 5.26 缓存分类与占用展示：`视频列表封面缩略图` / `网络弹幕缓存` / `哔哩封面缓存` / `其他缓存` | → `缓存管理` | 同上、`lib/services/cache_manager_service.dart`、`lib/l10n/label_maps.dart` | 无（需先产生缓存） | 部分 | 分类名为 l10n 枚举映射（`cacheCategoryLabel`） |
| 5.27 单项清除（`清除` 某一类，`已清除` / `清除失败`） | → `缓存管理` → 某类 `清除` | 同上 | 无 | 部分 | |
| 5.28 `清除所有缓存` + 二次确认（`再次确认` / `确定要清除所有缓存吗？` / `已清除全部缓存`） | → `缓存管理` → 清除全部 | 同上 | 无 | 可 | 二次确认是易漏点 |
| 5.29 `读取中…` / `刷新` 状态 | → `缓存管理` 打开/刷新 | 同上 | 无 | 可 | |

---

## 6. 哔哩哔哩

### 6.1 账号与登录

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 6.1 未登录账号入口（`登录` + 副标题 `哔哩哔哩账号`） | `我的` → 顶部账号卡片 | `lib/pages/settings/settings_page.dart` | 无 | 可 | |
| 6.2 进入 `哔哩哔哩登录` 页 | `我的` → `登录` | `lib/pages/bilibili/bili_login_page.dart` | 网络 | 部分 | |
| 6.3 `扫码登录` Tab（`正在获取二维码...` / `获取二维码失败，请重试` / `请使用哔哩哔哩客户端扫码`） | → 登录页 → `扫码登录` | 同上、`lib/services/bilibili/bili_auth_service.dart` | 网络 + 账号 | 部分 | 需真机扫码配合 |
| 6.4 二维码失效自动刷新（`二维码已失效，正在刷新...`） | → 登录页等二维码过期 | 同上 | 网络 + 账号 | 部分 | 需等待过期（约 3 分钟） |
| 6.5 已扫码待确认（`已扫码，请在手机上确认`） | → 登录页扫码后 | 同上 | 账号 + 手机 | 部分 | |
| 6.6 `刷新二维码` | → 登录页 → `刷新二维码`(biliQrRefresh) | 同上 | 网络 | 部分 | |
| 6.7 `保存到相册`（`二维码已保存到相册`） | → 登录页 → `保存到相册` | 同上 | 系统权限（相册） | 部分 | |
| 6.8 `打开哔哩哔哩`（拉起客户端扫码确认；`未检测到哔哩哔哩客户端`） | → 登录页 → `打开哔哩哔哩` | `android/.../MainActivity.kt`（`openBilibiliScan`）、`AndroidManifest.xml`（`bilibili://` queries） | 已装 B站客户端 | 部分 | 需真机装客户端 |
| 6.9 `Cookie 登录` Tab（`Cookie 仅本地加密保存，不会上传或记录日志。` / `从浏览器复制 Cookie 粘贴登录（扫码异常时的备用方式）`） | → 登录页 → `Cookie 登录` | `lib/pages/bilibili/bili_login_page.dart` | 网络 + Cookie | 部分 | |
| 6.10 Cookie 粘贴校验（`请先粘贴 Cookie` / `登录失败：Cookie 无效或已过期`） | → Cookie 登录 → 提交 | 同上 | 网络 | 部分 | 空值分支可 `可` |
| 6.11 登录中状态（`登录中...`）、登录成功提示（`登录成功` + 剩余提示 `biliLoginRemaining`） | → 登录页 提交 | 同上 | 网络 + 账号 | 部分 | |
| 6.12 凭证本地加密持久化（重启后仍登录） | 登录后 → 杀进程重启 | `lib/services/bilibili/bili_credential_store.dart` | 账号 | 部分 | |
| 6.13 设备指纹 / buvid 预取 | 启动时自动 | `lib/services/bilibili/bili_fingerprint.dart`、`lib/utils/bili_fingerprint_utils.dart`、`lib/utils/bili_app_sign.dart` | 网络 | 部分 | 无 UI 入口 |
| 6.14 已登录账号卡片（头像/昵称/`等级 · 会员标签`） | `我的` → 顶部账号卡片 | `lib/pages/settings/settings_page.dart`、`lib/l10n/label_maps.dart`（`biliUserVipLabel`） | 账号 | 部分 | 会员标签三态：`普通会员`/`大会员`/`年度大会员` |

### 6.2 账号信息页

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 6.15 账号信息展示（等级 / `已满级` / 经验 `biliExpValue` / `资产` / `硬币` + `用于投币等操作`） | `我的` → 账号卡片 | `lib/pages/bilibili/bili_user_page.dart` | 账号 | 部分 | 占位符 `biliExpValue` |
| 6.16 `退出登录` + 确认弹窗（`确定退出哔哩哔哩账号吗？` / `退出`） | 账号信息页 → `退出登录` | 同上 | 账号 | 部分 | |

### 6.3 番剧 / 索引 / 搜索 / 链接解析

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 6.17 进入 `哔哩番剧` 首页 | `首页` → 速拨 `哔哩番剧` | `lib/pages/bilibili/bili_index_page.dart` | 账号 + 网络 | 部分 | |
| 6.18 `追番时间表`（`今天` + `周一`…`周日` 7 个 Tab，番剧+国创两线合并） | → `哔哩番剧` 顶部 | 同上 | 账号 + 网络 | 部分 | 8 个日期文案全量回归点 |
| 6.19 `推荐` 网格 + 触底加载更多 + 封面卡片 | → `哔哩番剧` → `推荐` 区 | 同上、`lib/widgets/bili_cover_card.dart`、`lib/widgets/bili_cover_image.dart` | 账号 + 网络 | 部分 | `哔哩封面不可用（缓存未命中且下载失败）` 兜底文案 |
| 6.20 `索引` 入口 | → `哔哩番剧` → `推荐` 标题右侧 `索引` | `lib/pages/bilibili/bili_bangumi_index_page.dart` | 账号 + 网络 | 部分 | |
| 6.21 索引页筛选（分类/排序等）与 `展开`/`收起`、`重试`、`暂无内容` | → `索引` 页 | 同上 | 账号 + 网络 | 部分 | |
| 6.22 `解析链接` 弹窗（输入番剧/视频链接或 b23.tv 短链） | → `哔哩番剧` 右上角 `解析链接` | `lib/pages/bilibili/bili_index_page.dart`、`lib/utils/bili_short_link.dart`、`lib/utils/bili_bangumi_url.dart` | 网络 | 部分 | |
| 6.23 链接无法识别提示（`无法识别该链接（支持 ss/ep/BV/av 号与 b23.tv 短链）`） | → 解析非法链接 | 同上 | 无 | 可 | 纯本地校验，**可**无网测 |
| 6.24 `搜索番剧` 页（关键词搜索、`没有找到相关番剧`、`重试`） | → `哔哩番剧` 右上角 `搜索` | `lib/pages/bilibili/bili_search_page.dart` | 账号 + 网络 | 部分 | |
| 6.25 `番剧详情` 页（评分 `biliRating`、播放/弹幕/收藏统计、`多季`切换、`简介`展开/收起、`选集`内联前 12 集、`查看全部`、`暂无选集`） | → 点番剧封面卡片 | `lib/pages/bilibili/bili_season_page.dart` | 账号 + 网络 | 部分 | 统计数字单位文案 `biliCountHundredMillion`/`biliCountTenThousand` |
| 6.26 `选集` 页（集数列表、`正序`/`倒序`） | → 详情页 → `查看全部` | `lib/pages/bilibili/bili_episode_picker_page.dart` | 账号 + 网络 | 部分 | |
| 6.27 剧集条目角标（`限免` / `预告` / `第 N 集`） | 详情页/选集页 | `lib/widgets/bili_episode_tile.dart` | 账号 + 网络 | 部分 | 角标匹配用接口原值（设计如此） |
| 6.28 `已追番` 标记 | → 番剧卡片 | `lib/pages/bilibili/bili_index_page.dart` | 账号 + 网络 | 部分 | 只读展示，无「追番/取消追番」操作 |

### 6.4 在线播放与画质

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 6.29 点番剧剧集直接播放（进播放页） | 详情/选集页 → 点剧集 | `lib/pages/bilibili/bili_play_launcher.dart` | 账号 + 网络 | 部分 | |
| 6.30 点 UGC 视频/解析出的视频链接播放 | 解析链接 → 合法视频链接 | 同上 | 账号 + 网络 | 部分 | |
| 6.31 播放失败提示（`biliPlayFailed` / `解析播放地址失败` / `B 站视频` 兜底标题） | 播放失败时 | 同上 | 账号 + 网络 | 部分 | |
| 6.32 清晰度/VIP 门槛（`需要大会员权限` / `无权访问，可能需要登录或大会员` / `专属视频，需开通相应权限` / `视频不存在或无权访问`） | 播放/解析失败 | `lib/l10n/error_texts.dart` | 账号（大会员）+ 网络 | 部分 | 部分分支需非会员账号才能复现 |
| 6.33 WBI 签名（搜索/播放地址解析） | 自动 | `lib/utils/bili_wbi.dart`、`lib/services/bilibili/bili_http.dart` | 网络 | 部分 | 失败文案 `未获取到 WBI 密钥，无法解析播放地址` / `…无法搜索` |
| 6.34 B站流代理（回环代理 + Range，供 mpv 播放） | 播放 B站视频时 | `lib/services/bilibili/bili_stream_proxy.dart` | 账号 + 网络 | 部分 | 无独立 UI 入口 |

---

## 7. 网络存储（FTP / WebDAV / SMB）

### 7.1 账户管理

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 7.1 进入 `网络存储` 页 | `首页` → 速拨 `网络存储`（或 `我的` → 相关入口） | `lib/pages/network/network_storage_page.dart` | 无 | 可 | |
| 7.2 空态（`还没有网络存储账户` + `点击右下角 + 添加 WebDAV / SMB / FTP 账户`） | → `网络存储`（无账户） | 同上 | 无 | 可 | |
| 7.3 右下角 `+` 进入 `添加账户` | → `网络存储` → `+` | `lib/pages/network/account_edit_page.dart` | 无 | 可 | |
| 7.4 协议选择（`SMB` 445 / `FTP` 21 / `WebDAV` 80 或 443） | → `添加账户` → `协议`(networkProtocolLabel) | 同上、`lib/models/network_connection.dart` | 无 | 可 | 切协议自动跟随默认端口 |
| 7.5 `显示名称`（必填校验 `请输入名称`，示例文案 `例如：家庭 NAS`） | → `添加账户` | 同上 | 无 | 可 | |
| 7.6 `主机地址`（`IP 或域名`，必填 `请输入主机地址` / `请先填写主机地址`） | → `添加账户` | 同上 | 无 | 可 | 两处不同文案，易漏 |
| 7.7 `端口`（校验 `端口需为 1-65535`） | → `添加账户` | 同上 | 无 | 可 | |
| 7.8 默认路径（`默认为 /`） | → `添加账户` → 路径 | 同上 | 无 | 可 | |
| 7.9 `使用 HTTPS` 开关（`启用后使用加密连接（默认端口 443）`） | → `添加账户`（WebDAV） | 同上 | 无 | 可 | 仅 WebDAV 有意义 |
| 7.10 `匿名登录` 开关（`FTP / SMB 匿名访问时开启`） | → `添加账户` | 同上 | 无 | 可 | |
| 7.11 `账号` / `密码` + `显示密码`/`隐藏密码` | → `添加账户` | 同上 | 无 | 可 | |
| 7.12 `测试连接`（`测试中…` / `连接成功` / `连接失败：{原因}`） | → `添加账户` → `测试连接` | 同上、`lib/services/network/network_client_factory.dart` | 局域网设备（FTP/WebDAV/SMB 服务端） | 部分 | 无服务端只能测失败分支 |
| 7.13 保存账户（`保存` / `保存中…` / `保存失败`） | → `添加账户` → `保存` | 同上、`lib/services/network/network_connection_settings.dart` | 无 | 可 | |
| 7.14 账户卡片展示（协议/主机/`位置`/`连接`(networkConnectionLabel)） | → `网络存储` 列表 | `lib/pages/network/network_storage_page.dart` | 无 | 可 | |
| 7.15 `编辑` 账户（标题变 `编辑账户`） | → 账户卡片 `更多操作` → `编辑` | `lib/pages/network/account_edit_page.dart` | 无 | 可 | |
| 7.16 `删除账户` + 二次确认（`commonDeleteConfirmIrreversible`：`确定删除「{name}」吗？此操作不可撤销。`） | → 账户卡片 `更多操作` → `删除账户` | 同上 | 无 | 可 | 占位符 + 中文引号「」回归点 |
| 7.17 账户列表持久化（重启保持） | 增删改 → 杀进程重启 | `lib/services/network/network_connection_settings.dart` | 无 | 可 | |
| 7.18 网络连接超时档位文案（`常见 API` / `文本响应` / `文件下载` / `媒体流`） | 网络操作超时时 | `lib/utils/retry_policy.dart`、`lib/l10n/label_maps.dart` | 局域网设备 | 部分 | |
| 7.19 连接错误文案族（`连接超时：服务器无响应，请检查地址与端口`、FTP 各组错误、WebDAV 各组错误、SMB 各组错误） | 浏览/播放异常时 | `lib/l10n/error_texts.dart`、`lib/services/network/ftp_client.dart`/`webdav_client.dart`/`smb_client.dart` | 局域网设备 | 部分 | **错误分支最多、最易漏**（FTP 约 8 条、WebDAV 约 7 条、SMB 约 5 条） |

### 7.2 网络浏览

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 7.20 进入网络浏览器（目录列表） | `网络存储` → 点账户 | `lib/pages/network/network_browser_page.dart` | 局域网设备 | 部分 | |
| 7.21 `返回上一级` / `回到共享根目录` | → 浏览器 顶栏 | 同上 | 局域网设备 | 部分 | 两个不同入口，易只测一个 |
| 7.22 `刷新本目录` / `搜索本目录`（`没有匹配的文件`） | → 浏览器 | 同上 | 局域网设备 | 部分 | |
| 7.23 `显示隐藏文件` 开关（`本目录只有隐藏文件` 空态） | → 浏览器 → `更多` | 同上、`lib/utils/network_entry_filter.dart` | 局域网设备 | 部分 | 需含隐藏文件的远端目录 |
| 7.24 `排序方式`（网络排序字段/方向，`networkSortByBoth` 组合文案） | → 浏览器 → `排序方式`(commonSortBy) | 同上、`lib/utils/network_sort.dart` | 局域网设备 | 部分 | |
| 7.25 目录/文件条目信息（`修改时间`、大小、`服务器未提供` 兜底、`位置`） | → 浏览器 列表 | 同上、`lib/models/network_file.dart` | 局域网设备 | 部分 | |
| 7.26 空目录提示（`该目录为空`） | → 浏览器 | 同上 | 局域网设备 | 部分 | |
| 7.27 多选与批量下载/操作（网络侧） | → 浏览器 长按条目 | 同上 | 局域网设备 | 部分 | `未确认`（是否支持批量下载需实测） |
| 7.28 `未确认`：网络浏览页的目录缓存（`network_directory_cache`）行为 | 返回上级再进入 | `lib/services/network/network_directory_cache.dart` | 局域网设备 | 部分 | 无 UI 反馈，只能看是否立即出列表 |
| 7.29 网络视图设置持久化（`network_view_settings`） | 改排序/显示隐藏 → 重启 | `lib/services/network/network_view_settings.dart` | 无 | 部分 | |

### 7.3 网络播放

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 7.30 点远端视频播放（经回环流式代理） | `网络存储` → 账户 → 点视频文件 | `lib/services/network/network_streaming_proxy.dart`、`lib/services/network/network_repository.dart` | 局域网设备 | 部分 | |
| 7.31 网络播放 seek / Range 分段（`服务器忽略了分段请求，无法精确跳转`、`服务器返回的分段起点与请求不一致`） | 网络播放中拖动进度条 | 同上、`lib/utils/http_byte_range.dart` | 局域网设备 | 部分 | 个别服务端不支持 Range 才会命中 |
| 7.32 网络播放列表（`network_playlist` / `network_playlist_source`） | 网络播放中「下一集」/列表 | `lib/utils/network_playlist.dart`、`lib/services/network/network_playlist_source.dart` | 局域网设备 | 部分 | |
| 7.33 SMB 管道与错误（`SMB 尚未连接` / `用户名或密码错误` / `拒绝访问（权限不足）` / `路径不存在` / `SMB 请求失败`） | SMB 播放/浏览异常 | `lib/services/network/smb_pipeline.dart`、`lib/services/network/smb_client.dart` | 局域网设备 | 部分 | |
| 7.34 FTP 被动模式/二进制/断点续传相关错误（`FTP 服务器不支持被动模式`、`FTP 服务器不支持断点续传（REST）` 等） | FTP 播放/下载异常 | `lib/services/network/ftp_client.dart`、`lib/utils/ftp_parser.dart` | 局域网设备 | 部分 | |
| 7.35 网络路径校验文案（`网络路径不能包含 URI scheme` / `过长` / `段数过多` / `路径段不能为空` / `不能包含 . 或 ..` / `不能包含分隔符` / `不能包含控制字符`） | 构造异常远端路径 | `lib/utils/network_path.dart` | 局域网设备 | 部分 | **7 条校验文案，全量回归成本高、最易漏** |
| 7.36 网络 MIME 类型识别/网络文件分类 | 浏览远端目录 | `lib/utils/network_mime_types.dart` | 局域网设备 | 部分 | |

---

## 8. 投屏 / DLNA / 局域网媒体服务

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 8.1 投屏设备发现（`正在搜索投屏设备…`） | `播放页` → 顶栏 `投屏` | `lib/widgets/cast_device_dialog.dart`、`lib/services/cast/cast_service.dart` | 局域网设备（DLNA 渲染器）+ WiFi 多播 | 部分 | 触屏可测；结果依赖局域网 |
| 8.2 无设备提示（`未发现可投屏设备，请确认手机与电视连接同一 WiFi 后重试。`） | → `投屏`（无设备） | 同上 | 无（本机无接收端即可复现） | 可 | **无 DLNA 设备时唯一可黑盒验的分支** |
| 8.3 搜索失败提示（`castSearchStartFailed`） | → `投屏` 启动发现失败 | 同上 | 局域网设备 | 部分 | |
| 8.4 设备列表 + 选择设备推流（`连接成功` / `投屏失败` / `设备已离线`） | → `投屏` → 选设备 | 同上、`lib/models/cast_device.dart` | 局域网设备 | 部分 | |
| 8.5 仅 MediaRenderer 出现在列表（过滤 MediaServer/网关） | → `投屏` 列表 | `lib/services/cast/cast_service.dart`（`isMediaRenderer`） | 局域网设备（含非渲染器设备） | 不可 | 需要局域网里同时有 MediaServer 与 MediaRenderer 才能验过滤 |
| 8.6 投屏来源限制（仅本地文件可投；`暂不支持投屏该来源`） | 网络源/直链 → 投屏 | `lib/utils/cast_source.dart` | 网络 | 部分 | |
| 8.7 局域网媒体服务器（把本地文件暴露为 `http://<LAN_IP>:<port>/<token>`，GET/HEAD + Range + CORS） | 投屏本地文件时自动 | `lib/services/cast/lan_media_server.dart` | 局域网设备 | 部分 | |
| 8.8 局域网 IP 挑选（排除 VPN / 点对点网卡，Wi-Fi 优先；`未找到局域网 IPv4 地址`、`castNoLanIpv4`） | 投屏时自动 | 同上（`lanInterfaceScore`、`discoverLanIp`） | 局域网设备 | 不可 | 需构造 VPN/热点等网卡组合才能验优先级 |
| 8.9 投屏文件不存在（`文件不存在` / `castFileMissing`） | 投屏已被删除的文件 | 同上 | 本地素材 | 部分 | 需在投屏前后删文件 |
| 8.10 `选择屏幕` 按钮 = 横竖屏播放页切换（文案复用 `playerCastSelectScreen`） | `播放页` → 底栏最右 | `lib/pages/player/views/player_bottom_bar.dart` | 无 | 可 | 文案名与功能不一致，**易被误判为投屏功能而漏测横竖屏切换** |
| 8.11 退出播放释放 LAN 端口 | `播放页` → 返回 → 再次投屏 | `lib/services/cast/lan_media_server.dart` | 本地素材 | 部分 | 需观察端口是否被占用（`dumpsys`/日志） |

---

## 9. 设置

### 9.1 外观与字体

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.1 进入 `外观与字体` | `我的` → `外观` 组 → `外观与字体` | `lib/pages/settings/appearance_page.dart` | 无 | 可 | |
| 9.2 `外观模式`：`跟随系统` / `浅色` / `深色` / `AMOLED 纯黑` | → `外观与字体` → `外观模式` | 同上、`lib/theme/theme_controller.dart` | 无 | 可 | 4 项全量回归 |
| 9.3 `主题色` 23 个预设（`天蓝色`/`蓝色`/`浅蓝色`/`靛蓝色`/`蓝绿色`/`薄荷绿`/`浅绿色`/`酸橙色`/`琥珀色`/`橙色`/`橙红色`/`红色`/`粉红色`/`亮粉色`/`紫罗兰`/`紫色`/`深紫色`/`蓝灰色`/`棕色`/`灰色`…） | → `外观与字体` → `主题色` 网格 | 同上、`lib/l10n/label_maps.dart`（`themeColorLabel`） | 无 | 可 | 23 项集中在一页，**l10n 回归高密度区** |
| 9.4 `自定义主题色`（调色板选色） | → `主题色` → `自定义` 通栏 | 同上、`lib/widgets/color_editor_row.dart` | 无 | 可 | 弹窗标题 `自定义主题色` |
| 9.5 `动态色`（取壁纸主色；Android 12 以下 `安卓版本过低，不支持该功能`；失败 `无法读取壁纸颜色`） | → `主题色` 第 24 格 `动态色` | 同上、`android/.../MainActivity.kt`（`getWallpaperColors`） | 无（需 Android 12+） | 部分 | 低版本分支需低版本设备/模拟器 |
| 9.6 `调色板风格` 21 项（`标准型`/`保真型`/`单色型`/`中性型`/`鲜艳型`/`鲜明型`/`柔和型`/`彩虹型`/`果味型`/`糖果型`/`饱和型`/`对比型`/`欢快型`/`经典型`/`旧版型`/`单色相`/`淡雅型`/`超对比`/`生动型`/`亮背景`/`亮表面`） | → `外观与字体` → `调色板风格` | 同上 | 无 | 可 | 21 项，**l10n 回归第二高密度区** |
| 9.7 `App字体设置` 入口（副标题 `自定义全局字体`） | → `外观与字体` → `字体` 组 | `lib/pages/settings/appearance_page.dart` | 无 | 可 | |
| 9.8 `启用自定义字体` 开关（`已开启：使用下方导入的字体` / `已关闭：跟随系统字体`） | → `App字体设置` | `lib/pages/settings/font_page.dart`、`lib/services/app_font_settings.dart` | 无 | 可 | |
| 9.9 `导入字体`（`点击选择 .ttf/.otf 字体文件` / `正在导入...` / `字体解析失败，请更换字体文件`） | → `App字体设置` → 导入 | 同上、`android/.../MainActivity.kt`（`openFontPicker`/`copyFontFromUri`） | 本地字体素材 + 系统权限 | 部分 | 经系统文件选择器；坏字体分支需构造 |
| 9.10 `重新选择` / `当前字体`（`settingsFontCurrent`） | → `App字体设置` | 同上 | 本地字体素材 | 部分 | |
| 9.11 `字体字号` 滑杆 + `重置字号与字重` | → `App字体设置` | 同上 | 无 | 可 | 全局字号缩放（`textScaler`）影响所有页面 |
| 9.12 `字体字重` 9 档（`极细`/`很细`/`细`/`常规`/`中等`/`较粗`/`粗`/`很粗`/`极粗`） | → `App字体设置` → `字体字重` | 同上、`lib/l10n/label_maps.dart`（`appFontWeightLabel`） | 无 | 可 | 9 项集中，易漏 |
| 9.13 字体预览样例（`0123456789，。！？；：“”（）【】…·` vs 英文半角版） | → `App字体设置` | 同上（`settingsFontPreviewSample`） | 无 | 可 | **中英标点差异的显式回归点** |

### 9.2 自定义壁纸

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.14 `自定义壁纸` 卡片（`选一张图片，铺在页面内容与顶部栏之后` / 已启用时 `壁纸显示在页面内容与顶部栏之后`） | `我的` → `外观与字体` → `壁纸` 组 | `lib/pages/settings/appearance_page.dart` | 本地图片素材 | 部分 | 需 `adb push` 图片；经系统图片选择器 |
| 9.15 `选择壁纸` / `替换壁纸` | → 壁纸卡片 | 同上、`android/.../MainActivity.kt`（`pickWallpaperImage`） | 本地图片素材 | 部分 | `这台设备没有可用的系统图片选择器` 分支 |
| 9.16 壁纸编辑器：`拖动以调整位置，双指捏合以缩放。` | → 选图后进 `调整壁纸` | `lib/pages/settings/wallpaper_editor_page.dart` | 本地图片素材 | 部分 | 捏合缩放 adb 不支持多点触控 → 该子项 `不可`；滑杆可测 |
| 9.17 壁纸编辑器 · `缩放` 滑杆 | → `调整壁纸` | 同上 | 本地图片素材 | 可 | |
| 9.18 壁纸编辑器 · `水平位置` 滑杆 | → `调整壁纸` | 同上 | 本地图片素材 | 可 | |
| 9.19 壁纸编辑器 · `透明度` 滑杆 | → `调整壁纸` | 同上 | 本地图片素材 | 可 | |
| 9.20 壁纸编辑器 · `模糊` 滑杆 | → `调整壁纸` | 同上 | 本地图片素材 | 可 | |
| 9.21 壁纸 `适应` / `填充` 缩放模式 | → `调整壁纸` | 同上、`lib/l10n/label_maps.dart`（`wallpaperScaleModeLabel`） | 本地图片素材 | 可 | |
| 9.22 `保存壁纸`（`无法保存壁纸，请重新选择图片` / `图片已不可用，请重新选择`） | → `调整壁纸` → 保存 | 同上 | 本地图片素材 | 部分 | 失败分支需先把图删掉 |
| 9.23 `重置`（恢复默认壁纸） | → `调整壁纸` → `重置` | 同上 | 无 | 可 | |
| 9.24 壁纸生效渲染（`WallpaperLayer` 铺在内容与顶部栏之后） | 设置壁纸后浏览各页 | `lib/widgets/wallpaper_layer.dart`、`lib/widgets/wallpaper_surface.dart` | 本地图片素材 | 可 | 各页面截图对比 |

### 9.3 播放设置页（全量选项）

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.25 进入 `播放设置` | `我的` → `播放` 组 → `播放设置` | `lib/pages/settings/player_settings_page.dart` | 无 | 可 | 单页含约 30 个条目，**l10n 回归最密集的单页之一** |
| 9.26 `手势` 组：双击模式（3 项） | → `播放设置` → `手势` | 同上 | 无 | 可 | 见 2.34 |
| 9.27 `手势` 组：`音量灵敏度` 滑杆 | → 同上 | 同上 | 无 | 可 | |
| 9.28 `手势` 组：`亮度灵敏度` 滑杆 | → 同上 | 同上 | 无 | 可 | |
| 9.29 `视频方向` 组：3 模式 + `界面跟随重力旋转`（含确认弹窗） | → 同上 | 同上 | 本地素材（横/竖屏） | 部分 | 见 2.48/2.49 |
| 9.30 `顶部信息` 组：`时间` / `电量` / `网速` / `数据类型` 4 开关 | → 同上 | 同上 | 无 | 可 | 见 2.22–2.25 |
| 9.31 `播放行为` 组：`常驻进度线` / `显示章节进度条` / `进度条缩略图` / `记住上次倍速` / `保存音量到系统` / `双指缩小视频` / `按钮背景` / `自动连播` / `播放完毕自动退出` / `倍速播放指示器` / `启用播放界面动画` / `锁定状态豁免双击`（含确认弹窗）/ `音量增强`+`增强上限` / `已观看进度阈值` | → 同上 | 同上 | 无 | 可 | 14 项，逐项 l10n 回归 |
| 9.32 `长按倍速` 开关 + 说明（`长按临时倍速，可左右滑动调速`） | → 同上 | 同上 | 无 | 可 | |
| 9.33 `快进/快退时长` + `点击数值可自定义秒数` | → 同上 | 同上 | 无 | 可 | 见 2.36 |
| 9.34 `解码` 相关（`启用 GPU-next` / `启用 Vulkan` / `切换后需重启播放器（重开视频）生效；` / `设备或驱动不支持时会自动回落 OpenGL，不会黑屏`） | → 同上 | 同上 | 设备 GPU | 部分 | 见 2.64/2.65 |
| 9.35 播放设置持久化（重启保持） | 逐项改动 → 杀进程重启 | `lib/services/player_controls_settings.dart` | 无 | 可 | **必须杀进程**，是最容易漏的一类验证 |

### 9.4 播放历史

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.36 进入 `历史记录` | `我的` → `播放` 组 → `历史记录` | `lib/pages/settings/playback_history_page.dart` | 本地素材（有历史） | 可 | |
| 9.37 历史列表展示（标题/路径/时间/进度） | → `历史记录` | 同上、`lib/utils/playback_history.dart` | 本地素材 | 可 | |
| 9.38 点历史条目继续播放 | → `历史记录` → 点条目 | 同上 | 本地素材 | 可 | |
| 9.39 `播放历史记录` 开关（`关闭后不再记录新的播放`） | → `历史记录` 顶部 | 同上、`lib/services/playback_history_service.dart` | 无 | 可 | |
| 9.40 `删除历史时清除进度` 开关（`开启后，删除历史记录会同时清除该视频的播放进度` / `关闭时两套数据互相独立`） | → `历史记录` | 同上 | 本地素材 | 可 | 两套数据解耦，**关/开都要测** |
| 9.41 单条删除（`删除该条记录` / `删除该条记录（同时清除播放进度）`） | → 历史条目滑动/长按 | 同上 | 本地素材 | 可 | 文案随开关变化 |
| 9.42 `清除全部历史` + 确认弹窗（`清除历史记录` / `确定要清除全部播放历史吗？此操作不可恢复。` / `清除历史记录` 被进度保护时的拦截文案 `settingsHistoryClearProgressBlocked`） | → `历史记录` 右上角 `清除全部历史` | 同上 | 本地素材 | 可 | 拦截分支易漏 |
| 9.43 空态（`暂无播放历史` / `暂无播放历史（记录已关闭）`） | → `历史记录` | 同上 | 无 | 可 | 两条文案 |

### 9.5 语言

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.44 语言入口（副标题显示当前语言：`简体中文` / `English`） | `我的` → `语言` 组 → `语言设置` | `lib/pages/settings/settings_page.dart` | 无 | 可 | 副标题随当前语言变化 |
| 9.45 语言选择弹窗（标题 `选择语言 / Choose Language`，两项 `简体中文` / `English`，`取消` / `确定`） | → `语言设置` | `lib/widgets/language_picker_dialog.dart` | 无 | 可 | 标题故意双语 |
| 9.46 切换为 English 立即生效（不重启） | → 语言弹窗 → `English` → 确定 | `lib/services/app_locale_settings.dart`、`lib/main.dart` | 无 | 可 | 立即刷新，无需重启 |
| 9.47 语言持久化（`app_locale`，重启后保持） | 切 en → `am force-stop` → 重启 | 同上 | 无 | 可 | **必须杀进程** |
| 9.48 非法 `app_locale` 回落中文 | 手改 prefs（需 root/`run-as`） | 同上 | 调试能力 | 不可 | debug 包可尝试 `run-as`；非 root 模拟器受限 |
| 9.49 应用名跟随语言（zh `小喵Player` / en `Meow Player`） | 系统「最近任务」/桌面图标 | `lib/l10n/app_localizations*.dart`（`appTitle`）、`android/.../res/values*/strings.xml` | 无 | 部分 | 原生侧 `@string/app_name` 跟随**系统语言**，与 App 内语言可能不一致 → 必须分别验证 |
| 9.50 英文界面的全量走查（所有页面 × 两语言） | 全 App | 全量 `lib/**` | 无 | 部分 | 185 个 widget 测试锁定中文，真机英文需要人工走查；建议按域抽样 |

### 9.6 设备信息

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.51 进入 `设备信息` | `我的` → `其他` 组 → `设备信息` | `lib/pages/settings/device_info_page.dart` | 无 | 可 | |
| 9.52 设备型号/系统版本等基础信息（`未知设备` / `不支持` 兜底） | → `设备信息` | 同上、`android/.../DeviceCapabilities.kt` | 无 | 可 | |
| 9.53 `屏幕 HDR 能力`（`当前屏幕不支持 HDR（或系统未报告 HDR 能力）` 兜底） | → `设备信息` | 同上 | 真实 HDR 硬件 | 部分 | 支持态需真机 HDR 屏 |
| 9.54 `关键视频编码器` 列表 | → `设备信息` | 同上 | 无 | 可 | 模拟器与真机结果不同 |
| 9.55 `解码器清单` + `搜索解码器（名称 / MIME / 格式 / Profile）` + `无匹配的解码器` | → `设备信息` | 同上、`lib/models/device_decoder.dart` | 无 | 可 | |
| 9.56 解码器详情页全字段 | → `设备信息` → 点解码器 | `lib/pages/settings/decoder_detail_page.dart` | 无 | 可 | 见 2.67 |
| 9.57 设备能力读取失败提示（`无法读取设备能力（可能为不支持的原生通道）`） | → `设备信息`（通道异常） | `lib/pages/settings/device_info_page.dart` | 无 | 不可 | 需构造原生通道失败 |

### 9.7 关于 / 更新 / 日志 / 许可 / 缓存 / 隐私入口

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 9.58 进入 `关于` | `我的` → `其他` 组 → `关于` | `lib/pages/settings/about_page.dart` | 无 | 可 | |
| 9.59 关于页顶部信息卡（应用名 + 版本胶囊 + 构建类型胶囊 + 提交哈希胶囊） | → `关于` | 同上、`lib/services/build_info_service.dart` | 无 | 可 | 版本/构建类型/短号是**判定「装的是哪个包」的依据** |
| 9.60 点击哈希胶囊复制（`buildInfoCopied` / `buildInfoCopiedDirty` / `本次构建未注入提交哈希（需用 tools/ 里的构建脚本编译）`） | → `关于` → 点哈希胶囊 | 同上 | 无 | 可 | 未注入哈希的分支 |
| 9.61 `发送使用反馈`（邮件，`未找到可用的邮件应用`） | → `关于` → 邮箱图标 | 同上、`AndroidManifest.xml`（`mailto` queries） | 已装邮件应用 | 部分 | |
| 9.62 GitHub 图标（`GitHub 主页地址待接入` / `无法打开链接`） | → `关于` → GitHub 图标 | 同上、`lib/services/update/update_service.dart` | 网络 | 部分 | 依赖 `repoUrl` 是否为空 |
| 9.63 `信息` 组：`许可证书` | → `关于` → `许可证书` | `lib/pages/settings/license_page.dart` | 无 | 可 | |
| 9.64 许可页（`开源许可` / `暂无许可信息` / `复制许可文本` / `许可文本已复制` / `许可信息加载失败` / `版本读取中` + `{n} 个许可 / {n} 段`） | → `许可证书` | 同上 | 无 | 可 | 占位符 `settingsLicenseCount`/`settingsLicenseParagraphCount` |
| 9.65 `信息` 组：`用户协议` | → `关于` → `用户协议` | `lib/pages/settings/privacy_policy_page.dart`、`lib/l10n/legal*.dart` | 无 | 可 | 长文，中英两套 |
| 9.66 `工具` 组：`缓存管理` | → `关于` → `缓存管理` | 见 §5.4 | 无 | 可 | |
| 9.67 `工具` 组：`错误日志` | → `关于` → `错误日志` | 见 §11 | 无 | 可 | |
| 9.68 `更新` 组：`手动检查更新` | → `关于` → `手动检查更新` | `lib/services/update/update_service.dart` | 网络（GitHub） | 部分 | `已是最新版本` / `检查更新失败，请稍后重试` |
| 9.69 `更新` 组：`自动检查更新` 开关（`启动后自动检查新版本`） | → `关于` → `自动检查更新` | `lib/services/update/update_settings.dart` | 网络 | 部分 | 需重启后等 2 秒触发 |
| 9.70 更新弹窗（`发现新版本 {version}` / `暂无更新说明` / `立即更新` / `稍后提醒` / `忽略` / `选择下载方式`） | 检查到新版本时 | `lib/widgets/update_dialog.dart` | 网络 | 部分 | `忽略` 写入忽略版本 |
| 9.71 更新下载方式（`主下载站` / `备用下载站` / 各站 `待接入` `updateLinkPending`） | → 更新弹窗 → 选择下载方式 | 同上 | 网络 | 部分 | |
| 9.72 打开更新链接失败提示（`updateOpenLinkFailed`） | → 更新弹窗 点下载 | 同上 | 网络 | 部分 | |

---

## 10. 隐私政策与用户协议 / 首启流程

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 10.1 首启隐私弹窗（10 秒倒计时 + 勾选同意） | 全新安装 → 冷启动 | `lib/widgets/privacy_policy_dialog.dart`、`lib/main.dart`（`_ensurePrivacyAccepted`） | 无（需清数据/重装） | 部分 | **必须清 App 数据或重装**才复现 |
| 10.2 倒计时按钮文案（`同意并继续 ({seconds} 秒)`） | → 隐私弹窗 | 同上（`legalAgreeWithCountdown`） | 无 | 部分 | 占位符 + 中文全角括号 |
| 10.3 `我已阅读并同意以上隐私政策` 勾选 | → 隐私弹窗 | 同上 | 无 | 部分 | |
| 10.4 `同意并继续` | → 隐私弹窗 | 同上 | 无 | 部分 | |
| 10.5 `不同意并退出` | → 隐私弹窗 | 同上 | 无 | 部分 | 调 `SystemNavigator.pop()` 结束 Activity |
| 10.6 首启语言选择弹窗（仅「刚同意隐私政策的全新安装」弹一次，默认简体中文，可取消） | 同意隐私后立即弹 | `lib/widgets/language_picker_dialog.dart`、`lib/main.dart` | 无（需全新安装） | 部分 | 老用户/已同意过不弹 → **必须全新安装验证** |
| 10.7 隐私政策同意状态持久化（重启不再弹） | 同意后 → 杀进程重启 | `lib/services/privacy_policy_settings.dart` | 无 | 可 | |
| 10.8 隐私政策 / 用户协议长文（中英各一套，标题/正文完整） | `我的` → `关于` → `用户协议` | `lib/l10n/legal.dart`、`legal_zh.dart`、`legal_en.dart` | 无 | 可 | 切语言后长文应整体切换；`legal_texts_test.dart` 已覆盖部分 |
| 10.9 首启自动检查更新（同意隐私后 2 秒触发） | 首启后等 2 秒 | `lib/main.dart`（`_scheduleAutoUpdateCheck`） | 网络 | 部分 | 仅开关开启且未忽略该版本时弹窗 |
| 10.10 首启后消费冷启动外部视频（`onCreate` intent 暂存） | 用系统「打开方式」冷启动 | `lib/main.dart`、`android/.../MainActivity.kt`（`takeExternalVideo`） | 外部调用方 | 部分 | 隐私未同意前不处理 |
| 10.11 热启动外部视频（`onNewIntent` 推送） | App 在后台 → 系统「打开方式」打开视频 | 同上 | 外部调用方 | 部分 | |
| 10.12 外部视频解析（`content://` → 真实路径 / 缓存拷贝；`file://` / 直链） | 外部打开 | `android/.../MainActivity.kt`（`resolveVideoUri`）、`lib/services/device_services.dart` | 外部调用方 | 部分 | |
| 10.13 外部视频打开失败提示（`无法打开该视频`） | 外部打开异常 | `lib/main.dart`（`mainVideoOpenFailed`） | 外部调用方 | 部分 | |

---

## 11. 错误日志 / 崩溃处理 / 更新检查 / 关于页

| 功能点 | 入口 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 11.1 进入 `错误日志` | `我的` → `关于` → `工具` → `错误日志` | `lib/pages/settings/error_log_page.dart` | 无 | 可 | |
| 11.2 日志列表（文件分组 + `{n} 条` 计数） | → `错误日志` | 同上、`android/.../MainActivity.kt`（`listCrashLogs`） | 无（需已有日志） | 部分 | 需先产生日志 |
| 11.3 日志详情查看 | → `错误日志` → 点某条 | 同上（`readCrashLog`、`_LogDetailPage`） | 无 | 部分 | |
| 11.4 `刷新（实时查看）` | → `错误日志` → `刷新`(commonRefresh) | 同上 | 无 | 可 | |
| 11.5 `一键复制`（`日志内容已复制到剪贴板`） | → `错误日志` → `一键复制` | 同上 | 无 | 部分 | 剪贴板读取需 `adb` 支持（`cmd clipboard` 在部分版本不可用） |
| 11.6 `导出`（`settingsErrorLogExportedTo` 含保存路径 + `导出失败`） | → `错误日志` → `导出` | 同上（`exportCrashLog`） | 系统权限 | 部分 | 需 `adb pull` 核对导出文件 |
| 11.7 单条 `删除日志` + 确认（`已删除` / `删除失败`） | → 日志条目 → 删除 | 同上（`deleteCrashLog`） | 无 | 部分 | |
| 11.8 `清空全部日志` + 确认（`已清空全部日志` / `清空失败`） | → `错误日志` | 同上（`clearCrashLogs`） | 无 | 可 | |
| 11.9 空态（`暂无错误日志` / `应用崩溃时日志会自动记录到这里`） | → `错误日志`（无日志） | 同上 | 无 | 可 | |
| 11.10 Dart 侧未捕获异常写入崩溃日志（`FlutterError.onError` / Zone 兜底） | 触发 Dart 异常 | `lib/main.dart`、`lib/services/crash_log_service.dart` | 无 | 不可 | 需主动注入异常（M17） |
| 11.11 Kotlin 侧未捕获异常写入崩溃日志 | 触发原生崩溃 | `android/.../CrashHandler.kt` | 无 | 不可 | 需主动注入崩溃（M17） |
| 11.12 崩溃提示 Toast（`应用遇到错误已停止运行\n日志已保存，可在「关于 → 错误日志」查看`） | 崩溃时 | `android/.../CrashHandler.kt`、`values/strings.xml`、`values-en/strings.xml` | 无 | 不可 | 原生侧唯一走资源的用户可见文案；**原生 l10n 验证点** |
| 11.13 崩溃日志自动裁剪（≤50 个文件、≤10MB） | 累积日志后 | `CrashHandler.kt`（`trimLogs`）、`lib/services/crash_log_service.dart` | 无 | 不可 | 需手工造 51 个文件 |
| 11.14 崩溃日志内容保持中文（表头 `【时间】`/`【设备型号】` 等） | 崩溃后看日志文件 | `CrashHandler.kt` | 无 | 部分 | **设计如此：不翻译**（红线 13），不要报 bug |
| 11.15 读取日志失败提示（`读取日志失败：{原因}`） | 日志目录不可读 | `android/.../MainActivity.kt`、`values*/strings.xml` | 无 | 不可 | 需构造 IO 失败 |
| 11.16 手动检查更新（详见 9.68） | `关于` → `手动检查更新` | `lib/services/update/update_service.dart` | 网络 | 部分 | |
| 11.17 自动检查更新（详见 9.69 / 10.9） | 启动后 2 秒 | `lib/main.dart` | 网络 | 部分 | |
| 11.18 忽略版本（`忽略` 后不再提示该版本） | 更新弹窗 → `忽略` | `lib/services/update/update_settings.dart` | 网络 | 部分 | 需重启复验 |
| 11.19 版本比较逻辑（`version_compare`，如 `1.3.6+4`） | 更新检查时 | `lib/utils/version_compare.dart` | 网络 | 部分 | 单测已覆盖 |

---

## 12. Android 原生侧

| 功能点 | 入口/触发 | 主要文件 | 依赖 | adb 黑盒可测性 | 备注 |
|---|---|---|---|---|---|
| 12.1 应用名（zh `小喵Player` / en `Meow Player`，跟随**系统语言**） | 桌面/最近任务/系统设置应用信息 | `android/app/src/main/res/values/strings.xml`、`values-en/strings.xml` | 无 | 部分 | 跟随系统 locale，非 App 内语言；改系统语言即可验 |
| 12.2 前台服务通知渠道名/描述（`听视频后台播放` / `在后台继续播放视频音频`） | 系统设置 → 通知 → 本应用 | `BackgroundPlaybackService.kt`（渠道 ID 固定 `moumou_background_playback`） | 无 | 部分 | **渠道名只在全新安装生效**；验 en 必须卸载重装 |
| 12.3 通知标题/正文（`听视频`（无标题时兜底）/ `正在后台播放`） | 后台播放通知 | `values*/strings.xml` | 无 | 部分 | 有媒体标题时显示媒体标题 |
| 12.4 存储卷回退名（`内部存储` / `SD 卡`，系统描述取不到时用） | `媒体扫描与过滤` / 存储卷选择器 | `MainActivity.kt`（`getStorageRoots`、`volume.getDescription`）、`values*/strings.xml` | 第二存储卷 | 部分 | 取到系统描述时不走回退名，**回退分支难命中** |
| 12.5 崩溃提示 Toast 文案（见 11.12） | 崩溃 | `CrashHandler.kt` | 无 | 不可 | |
| 12.6 读取日志失败文案（见 11.15） | 日志读取失败 | `MainActivity.kt` | 无 | 不可 | |
| 12.7 启动过程：`LaunchTheme` 启动主题（浅色/深色/API27 变体） | 冷启动首帧 | `res/values/styles.xml`、`values-night/styles.xml`、`values-v27/styles.xml`、`values-night-v27/styles.xml`、`res/drawable*/launch_background.xml` | 无 | 部分 | 启动瞬间截图（`am start` 后立即 `screencap`） |
| 12.8 注册为系统视频播放器（`content/file/http/https` + video MIME + rtmp/rtsp/mms + 扩展名 pathPattern） | 文件管理器/浏览器「打开方式」 | `AndroidManifest.xml` | 外部调用方 | 部分 | 可用 `adb shell am start -a android.intent.action.VIEW -d <url> -t video/mp4` 模拟 |
| 12.9 其他播放器「调用外部播放」选择器里能看到本应用 | 第三方播放器 → 外部播放 | `AndroidManifest.xml`（scheme + MIME 同过滤器） | 第三方 App | 部分 | 需第三方 App 验证 |
| 12.10 画中画支持声明（`supportsPictureInPicture` / `resizeableActivity`） | 播放页 → 画中画 | `AndroidManifest.xml` | 无 | 可 | |
| 12.11 权限声明与运行时请求：`MANAGE_EXTERNAL_STORAGE`、`READ_MEDIA_VIDEO`、`POST_NOTIFICATIONS`、`ACCESS_LOCAL_NETWORK`(Android 16+)、`FOREGROUND_SERVICE_MEDIA_PLAYBACK` | 首次使用相关功能 | `AndroidManifest.xml`、`MainActivity.kt`（`requestLocalNetworkPermission`） | 系统权限 | 部分 | 系统权限页交互受 ROM 影响 |
| 12.12 网络明文/证书安全配置 | 网络请求 | `res/xml/network_security_config.xml` | 网络 | 部分 | 影响 http 直链/局域网 http |
| 12.13 原生能力方法通道（61 个方法：媒体信息/设备能力/亮度/音量/电池/网络类型/自动旋转/后台播放/目录列举/存储卷/字体/文件选择/壁纸/缓存/崩溃日志/画中画/媒体扫描/外部视频解析…） | 各功能触发时 | `MainActivity.kt`（`MethodChannel`，channel name 见 L151） | 视具体方法 | 部分 | 失败时只体现为对应功能的错误提示 |
| 12.14 MediaStore 视频查询 + 时长兜底抽取（`scanMediaFile`） | `首页` 扫描 | `MainActivity.kt`（`getVideos`、`scanMediaFile`） | 系统权限 + 本地素材 | 部分 | 下载产物 `duration=0` 的兜底是回归点 |
| 12.15 整盘补扫索引（`.nomedia` 目录 / 非主卷 / 隐藏目录；15 分钟重扫间隔、续扫、`cancelFsScan`） | `首页` 扫描/下拉刷新/离开首页 | `VideoFsWalker.kt`、`MainActivity.kt` | 系统权限 + 特殊目录素材 | 部分 | 无 UI 直接反馈，需靠列表条目出现时机判断 |
| 12.16 崩溃日志目录 `Android/data/com.azxcvn.moumou/files/crash_logs/` | 崩溃后 | `CrashHandler.kt` | 无 | 部分 | 可 `adb shell ls` 核对 |
| 12.17 壁纸主色读取（`getWallpaperColors`，失败回落） | 外观 → 动态色 | `MainActivity.kt` | Android 12+ | 部分 | |

---

## 13. 已确认**不存在 / 未接入**的功能（避免误列用例）

> 以下是我在扫描中**明确没找到**入口的功能。写用例时不要凭空造这些项；若用户认为应有，请先确认。

| 项 | 依据 |
|---|---|
| 弹幕**发送** / 发布弹幕 | 全仓库无 `发送弹幕` 相关键与实现（`grep` 无命中） |
| B 站**收藏夹**页 / **历史**页 / **关注**列表页 | `lib/pages/bilibili/` 下只有索引/番剧详情/选集/搜索/用户页，无收藏/历史/关注页面 |
| B 站**投币** / **点赞** 操作 | 仅有统计数字展示（`bili_season_page` 的点赞·投币·收藏为只读文本） |
| **追番 / 取消追番** 写操作 | 只有 `已追番` 只读角标（`biliFollowed`），无操作入口 |
| 媒体库**批量重命名** | 文件操作只有单条重命名 + 批量复制/移动/删除 |
| 「跟随系统语言」选项 | `AppLocaleSettings` 只有 `zh`/`en` 两个取值，无 `system` |
| 通知栏**媒体控制按钮**（播放/暂停/上一集） | `BackgroundPlaybackService` 注释明确「不带任何媒体控制功能」 |
| 更新包的**站内下载 / 应用内安装** | 更新弹窗只提供下载站链接（部分标注 `待接入`） |
| `lib/pages/player/views/` 下**音频均衡器以外**的未接入占位 | `PlayerTopAction` 全部 `implemented = true`，无占位动作 |

---

## 14. 已有测试覆盖现状（`test/**`）

### 14.1 总体情况

| 项 | 值 |
|---|---|
| 测试文件总数 | 190 个 `.dart`（含 2 个夹具：`l10n_test_helper.dart`、`pb_test_helper.dart`） |
| widget 测试文件 | 45 个（含 `testWidgets` 的文件，实测） |
| 纯 unit 测试文件 | 143 个（实测：190 − 45 − 2 个夹具） |
| 引用 l10n 夹具/`AppLocalizations`/`kTestLocaleZh` 的测试文件 | 51 个（实测去重；其中直接 import `l10n_test_helper.dart` 的 38 个） |
| l10n 测试夹具 | `test/l10n_test_helper.dart`：`kTestLocaleZh` / `kTestLocalizationDelegates` / `kTestSupportedLocales` / `pinPlatformLocaleZh()` / `pumpAppZh()` |
| 夹具存在的原因 | widget 测试环境的平台 locale 实测是 `en_US`；接入 l10n 后不钉 locale 的测试会渲染英文，导致大量 `find.text('中文')` 断言失败 |
| 测试默认 locale | `en_US`（**真机测试不受影响，组件测试必须走夹具**） |

### 14.2 与多语言直接相关的测试文件

| 测试文件 | 覆盖内容 |
|---|---|
| `test/l10n_test_helper.dart` | 语言夹具本体（非用例） |
| `test/language_picker_test.dart` | 语言入口弹窗 + 切换为 `en` 后 `settings.locale == Locale('en')`（5 个 widget 用法） |
| `test/legal_texts_test.dart` | 隐私政策/用户协议中英长文齐全（`legalTextsFor(Locale('en'))`） |
| `test/privacy_policy_dialog_test.dart` | 隐私弹窗（含 `Locale('en')` 下文案切换、倒计时按钮） |
| `test/app_smoke_test.dart` | 真实 `MoumouApp` 启动链路冒烟（MaterialApp 之下取 `AppLocalizations`） |
| `test/settings_page_bili_login_test.dart` | 「我的」页账号入口（登录/未登录两态文案） |
| `test/about_page_card_test.dart` | 关于页信息卡（版本/构建类型/哈希胶囊） |
| `test/device_info_page_test.dart` | 设备信息页 |
| `test/danmaku_server_page_test.dart` | 弹幕服务器页（11 个 widget 用法，页面内 l10n 密集） |
| `test/player_settings_page_test.dart` | 播放设置页 |
| `test/appearance_page_test.dart` | 外观与字体页 |
| `test/wallpaper_editor_page_test.dart` | 壁纸编辑器 |
| `test/playback_history_page_test.dart` | 历史记录页 |
| `test/subtitle_download_page_test.dart` | 字幕下载页（14 个 widget 用法） |
| `test/network_browser_page_test.dart` | 网络浏览页 |
| `test/update_dialog_test.dart` | 更新弹窗 |
| `test/file_operations_ui_test.dart` | 文件操作 UI（15 个 widget 用法） |
| `test/home_page_permission_test.dart` | 首页权限门禁三态 |
| `test/speed_dial_fab_test.dart` | 首页速拨 FAB |
| `test/open_link_dialog_test.dart` | 打开链接弹窗 |
| `test/options_sheet_video_fields_test.dart` | 排序与视图面板的视频字段 |
| `test/player_bottom_bar_test.dart` / `portrait_player_bottom_bar_test.dart` | 横/竖屏播放页底栏 |
| `test/player_panel_test.dart` / `player_panel_theme_test.dart` / `player_bottom_panel_test.dart` | 播放器面板框架与主题 |
| `test/player_danmaku_panel_test.dart` / `player_danmaku_settings_panel_test.dart` / `player_danmaku_network_panel_test.dart` / `player_danmaku_episodes_panel_test.dart` | 弹幕二级界面 / 设置面板 / 网络弹幕 / 剧集选择（合计 52 个 widget 用法） |
| `test/player_decode_panel_test.dart` / `player_diagnostics_panel_test.dart` / `player_quality_panel_test.dart` / `player_speed_panel_test.dart` / `player_bili_playlist_panel_test.dart` / `player_zoom_restore_chip_test.dart` / `intro_outro_panel_test.dart` / `subtitle_file_picker_panel_test.dart` | 其余播放器面板 |
| `test/video_card_full_name_test.dart` / `video_card_duration_fallback_test.dart` | 视频卡片字段 |

### 14.3 按功能域划分的覆盖情况

| 功能域 | 覆盖程度 | 代表性测试文件 | 明显缺口 |
|---|---|---|---|
| 1 媒体库与文件夹 | 中 | `video_scanner_test.dart`、`video_scanner_payload_test.dart`、`view_settings_test.dart`、`folder_pin_test.dart`、`file_ops_test.dart`、`file_selection*`、`pinned_folders_settings_test.dart`、`home_page_permission_test.dart`、`options_sheet_video_fields_test.dart`、`video_card_*` | 树状/列表两级下钻页（`tree_folder_page`/`folder_detail_page`）无 widget 测试；`home_page` 本体无（仅权限分支）；搜索过滤无独立用例 |
| 2 播放器 | 中高（面板层） | `player_*_panel_test.dart` 系列、`player_gestures_test.dart`、`player_orientation_test.dart`、`player_session_state_test.dart`、`player_diagnostics_test.dart`、`playback_restore_test.dart`、`playback_completion_test.dart`、`watch_state_test.dart`、`audio_track_test.dart`、`subtitle_track_test.dart`、`equalizer_*`、`super_resolution_*`、`decode_policy_test.dart`、`mpv_tuning_test.dart`、`anime4k_patch_test.dart`、`pip_aspect_test.dart`、`thumbnail_*`、`fast_thumbnails_test.dart` | **`player_page.dart` / `player_portrait_page.dart` 本体无 widget 测试**（只有面板与纯函数）；`audio_player_page.dart`（听视频）无 widget 测试（仅有 `audio_shuffle_test.dart` 纯函数）；投屏无 widget 测试；长按倍速、音量增强、PiP 均无端到端用例 |
| 3 弹幕 | 高（纯逻辑） | `danmaku_xml_test.dart`、`danmaku_local_file_test.dart`、`danmaku_dedup_test.dart`、`danmaku_merge_test.dart`、`danmaku_scheduler_test.dart`、`danmaku_pipeline_test.dart`、`danmaku_blocklist_test.dart`、`danmaku_timeline_test.dart`、`danmaku_memory_test.dart`、`danmaku_search_*`、`danmaku_auto_match_cache_test.dart`、`danmaku_server*`、`dandan_*`、`danmaku_settings_test.dart` | 无真实网络弹幕的集成用例；弹幕**渲染层**（`player_danmaku_layer`）无 widget 测试；自动匹配的成功路径无集成用例 |
| 4 字幕 | 高（纯逻辑 + 部分页面） | `subtitle_auto_match_test.dart`、`subtitle_language_test.dart`、`subtitle_settings_test.dart`、`subtitle_style_properties_test.dart`、`subtitle_memory_test.dart`、`subtitle_sort_test.dart`、`subtitle_source_settings_test.dart`、`custom_subtitle_parser_test.dart`、`wyzie_*`（4 个）、`network_subtitle_match_test.dart`、`subtitle_font_injection_test.dart`、`subtitle_download_page_test.dart`、`subtitle_file_picker_panel_test.dart` | 网络存储同名字幕的集成链路无用例；字幕下载真实下载无集成用例 |
| 5 下载 | 中 | `download_manager_test.dart`、`download_task_test.dart`、`thumbnail_cache_test.dart`、`thumbnail_bucket_test.dart`（缓存相关） | `download_manager_page.dart` 无 widget 测试；**下载任务持久化（重启恢复）无集成用例**；`bili_video_download_page` / `bili_danmaku_download_page` 无 widget 测试；`cache_management_page` 无 widget 测试 |
| 6 哔哩哔哩 | 中高（服务层） | `bili_auth_service_test.dart`、`bili_credential_test.dart`、`bili_fingerprint_test.dart`、`bili_app_sign_test.dart`、`bili_http_test.dart`、`bili_wbi_test.dart`、`bili_dash_test.dart`、`bili_stream_proxy_test.dart`、`bili_bangumi_service_test.dart`、`bili_bangumi_test.dart`、`bili_video_service_test.dart`、`bili_danmaku_service_test.dart`、`bili_playlist_test.dart`、`bili_short_link_test.dart`、`bili_image_url_test.dart`、`bili_image_cache_service_test.dart`、`bilibili_user_test.dart`、`bili_pb_test.dart`、`bili_episode_picker_page_test.dart`、`bili_search_page_test.dart` | `bili_index_page` / `bili_season_page` / `bili_login_page` / `bili_user_page` **无 widget 测试**；`bili_play_launcher` 无测试；画质/VIP 门槛分支无测试 |
| 7 网络存储 | 中高（客户端层） | `ftp_client_test.dart`、`ftp_parser_test.dart`、`webdav_client_test.dart`、`webdav_xml_test.dart`、`smb_pipeline_test.dart`、`network_path_test.dart`、`network_sort_test.dart`、`network_entry_filter_test.dart`、`network_mime_types_test.dart`、`network_directory_cache_test.dart`、`network_connection_test.dart`、`network_connection_settings_test.dart`、`network_playlist*`、`network_streaming_proxy_test.dart`、`retry_policy_test.dart`、`network_browser_page_test.dart` | **无真实协议集成用例**（全部是纯函数/客户端单测）；`network_storage_page.dart` 无 widget 测试；`account_edit_page.dart` 无 widget 测试 |
| 8 投屏 / DLNA / 局域网媒体服务 | 低 | `cast_service_test.dart`（2 个用例）、`cast_source_test.dart`（3 个）、`lan_media_server_test.dart`（4 个） | **设备发现、推流、局域网 IP 挑选、媒体服务器 HTTP 行为均为轻量单测**；无 widget 测试、无端到端用例；`cast_device_dialog.dart` 无 widget 测试 |
| 9 设置 | 中 | `theme_controller_test.dart`、`app_font_settings_test.dart`、`wallpaper_settings_test.dart`、`appearance_page_test.dart`、`wallpaper_editor_page_test.dart`、`media_scan_settings_test.dart`、`player_settings_page_test.dart`、`player_controls_settings_test.dart`、`playback_history_page_test.dart`、`playback_history_test.dart`、`device_info_page_test.dart`、`build_info_service_test.dart`、`about_page_card_test.dart` | **`settings_page.dart` 本体无完整 widget 测试**（仅 `settings_page_bili_login_test.dart` 覆盖账号入口）；`license_page.dart`、`font_page.dart`、`decoder_detail_page.dart`、`cache_management_page.dart`、`error_log_page.dart`、`privacy_policy_page.dart` 均**无对应测试文件**（隐私弹窗有测）；`language_picker_test.dart` 未覆盖「首启只弹一次」的时序 |
| 10 隐私政策 / 首启流程 | 中 | `privacy_policy_dialog_test.dart`、`privacy_policy_settings_test.dart`、`legal_texts_test.dart`、`app_smoke_test.dart` | **首启完整时序（隐私 → 语言 → 自动更新 → 外部视频）无集成用例**；`SystemNavigator.pop()` 退出行为无测试；外部打开视频（`device_services_external_video_test.dart` 仅测解析）冷/热启动时序无集成用例 |
| 11 错误日志 / 崩溃 / 更新 / 关于 | 中低 | `update_service_test.dart`、`update_settings_test.dart`、`version_compare_test.dart`、`update_dialog_test.dart`、`about_page_card_test.dart`、`build_info_service_test.dart` | **`error_log_page.dart` 无测试**；崩溃日志写入（`crash_log_service`）无测试；Kotlin 侧 `CrashHandler` / `VideoFsWalker` / `MediaInfoHelper` / `DeviceCapabilities` **完全没有测试**（无 Android 单元测试目录） |
| 12 Android 原生侧 | 极低 | 无（`android/` 下无 `test`/`androidTest` 源集） | **整个原生侧零测试**：应用名资源、通知渠道名/描述、存储卷回退名、崩溃提示文案、MediaStore 查询、整盘补扫、61 个 MethodChannel 方法全部只能靠真机手工/adb 验证 |

### 14.4 明显没有测试覆盖的功能域（汇总）

1. **Android 原生侧全部**（资源本地化、通知渠道、崩溃、MediaStore/补扫、MethodChannel）。
2. **播放页与竖屏播放页本体**（`player_page.dart` / `player_portrait_page.dart` 的集成行为：手势层、面板调度、画质切换、投屏、PiP、截图、后台播放）。
3. **听视频页**（`audio_player_page.dart`：倍速、随机、定时关闭、后台服务联动）。
4. **投屏 / DLNA / 局域网媒体服务器的端到端链路**。
5. **网络存储真实协议链路**（FTP/WebDAV/SMB 的浏览与播放）。
6. **B 站页面层**（番剧首页/详情/登录/账号页的 widget 与端到端）。
7. **下载链路**：任务持久化、合并阶段、下载页 widget、缓存管理页。
8. **首启完整时序**与**外部打开视频**的冷/热启动。
9. **错误日志页**与**崩溃日志写入**。
10. **设置主页（`settings_page.dart` 全分组）**本身。

---

## 15. 最难测 / 最容易漏测的 5 个功能点

> 排序依据：① adb 黑盒能否给出确定判定；② 是否需要外部条件或时间窗口；③ 界面反馈是否隐式（无标记、只有 toast、只在长文里）。

| 排名 | 功能点 | 为什么最难测 / 最容易漏 | 建议的验证手段 |
|---|---|---|---|
| 1 | **长按倍速 + 长按期间左右滑动动态调速（1.5–4.0，步进 0.5，6 档）**（2.41 / 2.42） | 需要「按住不放再横向滑动」的复合手势；`dynamicSpeedIndex` 把滑动距离按 `6.0 × 满屏宽` 映射到离散档位，`adb input swipe` 的时长/距离到哪一档完全不可预判；倍速提示只在长按期间顶部短暂显示，截图时机极难对准 | 用 `adb shell sendevent` 或多段 `input swipe` 拼「长按+滑动」；同时用 `logcat` 过滤播放器日志核对实际倍速值；对同一距离重复 3 次确认档位稳定 |
| 2 | **音量增强（系统音量满 100% 后 mpv volume 继续放大，上限 100%+cap）**（2.40） | 前置条件是**系统媒体音量必须先到 100%**，然后才能进入增强段；显示值是「系统音量 + mpv 增益」的组合换算，模拟器无真实音频输出，**响度无法验证**，只能看 UI 百分比数字；`>100%` 的显示还依赖 `boostEnabled` 开关 | `adb shell media volume --stream 3 --set 100` 先顶满，再滑动提升；用 `adb shell dumpsys media.audio_flinger` 或日志核对 mpv `volume` 属性；明确记录「听感未验证」 |
| 3 | **Android 原生侧本地化三条：应用名（跟随系统语言）/ 通知渠道名与描述（只在全新安装生效）/ 崩溃提示 Toast**（12.1 / 12.2 / 11.12） | 三者都**不在 Flutter 侧渲染**，adb 截图只能看到结果，且：应用名跟随**系统 locale** 而非 App 内语言（两套语言容易混淆）；通知渠道名被 Android 缓存，**改语言必须卸载重装**（清数据）；崩溃提示需要**主动注入崩溃**（通常不允许改业务代码） | 分三步：① 改 `adb shell setprop persist.sys.locale en-US` + `am force-stop` 后看桌面/最近任务名；② 记录当前设置项 → 卸载 → 重装 → 切 en → 拉通知栏截图 + `dumpsys notification` 查渠道名；③ 崩溃用例按 M17 约定执行，拿不到就记「未验证」 |
| 4 | **投屏 / DLNA 全链路（设备发现 → LanMediaServer 暴露 URL → 推流 → 释放端口）**（8.1 / 8.4 / 8.7 / 8.8 / 8.11） | 依赖**同网段真实 DLNA 渲染器**；SSDP 走多播，模拟器 NAT 网络经常收不到；`discoverLanIp` 有网卡优先级评分（排除 tun/tap/ppp/p2p，wlan 优先），**模拟器上根本没有 wlan 网卡**，命中优先级逻辑的条件构造不出来；端口释放无 UI 反馈 | 无接收端时只验「未发现可投屏设备」分支；有 PC 端时可装 DLNA 接收端（如 VLC/通用 DLNA renderer）并把模拟器改桥接；`dumpsys` + `netstat` 核对端口占用与释放；网卡优先级结论标注「模拟器环境不代表真机」 |
| 5 | **隐式字幕/弹幕自动匹配规则：「同名外挂字幕自动加载」+「优先选中文字幕轨（含‘特效/双语’优先，手动选过的不改）」+「切集自动匹配弹幕」**（4.17 / 4.18 / 2.106 / 2.114） | 三条都是**没有界面开关、没有状态标记**的隐式规则：命中时只闪一条 toast，失败时行为与「没有字幕/弹幕」完全一样，**无法从界面区分「没匹配上」与「匹配上了但没渲染」**；而且强依赖素材命名（同名文件、chs/cht 双语、集数可识别）与网络 | 素材侧严格按 M04/M06 命名（`xxx.srt`、`xxx.chs.ass`/`xxx.cht.ass`、`弹幕.xml`）；用 `logcat` 抓自动加载日志；逐条构造「有匹配 / 无匹配 / 手动选过」三种前置状态对比；弹幕侧同时验 `切集自动匹配` 开关的开与关 |

> 补充（第 6–10 名，同样容易漏，写用例时建议一并覆盖）：
> ① `选择屏幕`（底栏最右）其实是**横竖屏切换**而文案名像投屏（8.10）；② 语言切到 English 后**应用名与系统通知渠道**不会跟着变（12.1/12.2）；③ `删除历史时清除进度`开关的两套数据解耦（9.40/9.41/9.42）；④ 网络存储的 **7 条网络路径校验文案 + 20 余条协议错误文案**（7.19/7.35）；⑤ 设置类功能的**杀进程持久化**（9.35/9.47/6.12/5.10/3.10/7.17）。

---

## 16. 统计

### 16.1 各功能域条目数

| # | 功能域 | 条目数 |
|---|---|---|
| 1 | 媒体库与文件夹 | 67 |
| 2 | 播放器 | 141 |
| 3 | 弹幕 | 20 |
| 4 | 字幕 | 22 |
| 5 | 下载 | 29 |
| 6 | 哔哩哔哩 | 34 |
| 7 | 网络存储 | 36 |
| 8 | 投屏 / DLNA / 局域网媒体服务 | 11 |
| 9 | 设置 | 72 |
| 10 | 隐私政策与用户协议 / 首启流程 | 13 |
| 11 | 错误日志 / 崩溃处理 / 更新检查 / 关于页 | 19 |
| 12 | Android 原生侧 | 17 |
| | **合计** | **481** |

> 说明：编号是**连续全表编号**（1.1–12.17），上表按域聚合；「播放器」域条目最多是因为它把播放控制、手势、倍速、音轨/均衡器/听视频、顶栏控制栏、渲染解码超分、播放页内的字幕/弹幕/画质/投屏/PiP/诊断全部计入。
