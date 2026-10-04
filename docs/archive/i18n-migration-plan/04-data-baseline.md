# 04 · 数据基线（实测）

> 本文件回答"现状到底是什么"，所有数字都是对 `C:\Users\root\Desktop\moumou` 当前代码的**实测**，可用
> `python tools/i18n_scan.py baseline / enums / dupes` 复现（口径见文末）。
> 执行者（AI）**不要重新统计**，直接用这里的数字做工作量分配与验收判断；若扫描结果与本文不符，说明代码已变化，必须停下来报告。
>
> 实测环境：Flutter 3.44.9 stable / Dart 3.12.2 / Windows。

---

## 1. 总量

| 指标 | 数值 |
|---|---|
| lib 下 Dart 文件 | 296 |
| 含用户可见中文文案的文件 | **164** |
| 中文字面量出现次数 | **1855** |
| 去重后条数 | **1424** |
| 字符串字面量内中文字符总量 | **14256** |
| 注释/文档里的中文 | 不计入（与运行时无关） |

## 2. 分层分布（决定难度的关键）

| 层 | 出现次数 | 去重条数 | 文件数 |
|---|---|---|---|
| UI 层（`lib/pages`、`lib/widgets`、`lib/theme`） | 1389 | 1061 | 90 |
| **无 `BuildContext` 层（`lib/services`、`lib/models`、`lib/utils`）** | **459** | **396** | **73** |
| `lib/main.dart` | 7 | 6 | 1 |

## 3. 按目录分布

| 目录 | 出现次数 | 文件数 |
|---|---|---|
| `lib/pages/player`（含 `views/`） | 428 | 35 |
| `lib/pages/settings` | 408 | 15 |
| `lib/services`（含 bilibili / network / download / subtitle / cast） | 242 | 40 |
| `lib/pages/bilibili` | 129 | 10 |
| `lib/widgets` | 119 | 17 |
| `lib/models` | 111 | 17 |
| `lib/utils` | 106 | 16 |
| `lib/pages/subtitle` | 84 | 3 |
| `lib/pages/network` | 62 | 3 |
| `lib/theme` | 49 | 1 |
| `lib/pages/media_info` | 46 | 1 |
| `lib/pages/home` | 43 | 4 |
| `lib/pages/download` | 21 | 1 |
| `lib/main.dart` | 7 | 1 |

## 4. 集中度

| 指标 | 数值 |
|---|---|
| 前 20 个文件覆盖 | 845 处 = 45.6% |
| 前 45 个文件覆盖 | 1320 处 = 71.2% |
| 前 60 个文件覆盖 | 1477 处 = 79.6% |
| 每文件处数中位数 | 6 |
| 处数 ≤5 的文件 | 77 个（合计仅 194 处） |

## 5. 文案长度分布（布局溢出风险依据）

| 长度 | 出现次数 | 去重条数 |
|---|---|---|
| 1–2 字 | 507 | 288 |
| 3 字 | 158 | 135 |
| 4 字 | 437 | 335 |
| 5–8 字 | 407 | 342 |
| >8 字 | 346 | 324 |

**≤4 字的短文案占 1102 处（59.4%）、去重 758 条**，大量出现在胶囊、chip、网格、播放器面板标题里。

## 6. 「表」的精确规模

| 表 | 规模 | 备注 |
|---|---|---|
| 枚举携带中文标签 | **31 个枚举 / 128 项**（枚举项总数 147） | 明细见附录 C |
| 主题色名称表 `theme_controller.presetColors` | 23 项 | 代码注释要求「名称统一 3 字」 |
| 调色板风格名称表（`FlexSchemeVariant` → 中文） | 21 项 | 同上 |
| `'键': '中文值'` 映射表项 | 101 项 | 最多：`media_info_page.dart` 19 项 |
| `switch` 表达式直接返回中文 | 见 `media_scan_settings.dart:16–24` 等 | 属"无 context 层 396 条"的一部分 |

> 早期版本曾把「287 条」当枚举标签口径，那是错的（那个正则量的是"任意构造调用把中文当第一个参数"，含跨行 `Text(`）。
> 精确数字是 **31 枚举 / 128 项**。

## 7. ARB 语法冲突面

| 情况 | 处数 | ARB 处理 |
|---|---|---|
| `${变量}` 形式插值 | 136 | 转 ARB `placeholders` |
| `$变量` 形式插值 | 122 | 转 ARB `placeholders` |
| **真正的裸花括号**（无 `$`） | **2** | 在 `subtitle_settings_section.dart`，讲 `{name}` 占位符语法的帮助文案，必须转义或改写 |
| 含 `\n` | 37 | ARB 里写 `\n` |
| 含单引号 `'` | 3 | 注意转义 |
| 含 `%` / `|` | 各 1 | 无特殊处理 |

## 8. 跨文件重复文案（`common.*` 归并依据）

共 **189 条**去重文案出现在 ≥2 个文件里。头部：

| 文案 | 出现文件数 |
|---|---|
| `取消` | 20 |
| `小喵Player` | 8 |
| `确定` | 8 |
| `删除` | 8 |
| `重试` / `确认` / `关闭` 等 | 5–7 |

## 9. `const` 上下文风险

**381 处**中文字面量所在行含 `const`（近似统计，非语法级判定）。
换成 `AppLocalizations.of(context).xxx` 后这些 `const` 必须去掉；**逐个确认重建范围**，不允许整棵树去 `const`。

## 10. 测试耦合

| 指标 | 数值 |
|---|---|
| test 下 Dart 文件 | 186 |
| 含中文的测试文件 | 185 |
| `find.text/widgetWithText/textContaining('中文')` | **535 处 / 37 文件** |
| 访问 `.label/.title/.desc` | 53 处 / 24 文件 |
| `expect` 行含中文 | 882 行 |

**关键实测**（在本工程跑临时 `testWidgets` 探针，跑完即删、`git status` 干净）：

```
platformDispatcher.locale       = en_US
platformDispatcher.locales      = [en_US, zh_CN]
Localizations.localeOf(context) = en_US
```

→ 测试环境**默认解析到 `en_US`**。接入 l10n 且支持 `en` 之后，任何未钉 locale 的 widget 测试都会渲染英文，535 处断言立刻失败。
**所以阶段 0 必须先做测试夹具**（见 `02-实施方案.md` 阶段 0）。

## 11. Android 原生侧现状

| 项 | 现状 |
|---|---|
| `android/app/src/main/res/values/strings.xml` | **不存在**（`values/` 下只有 `styles.xml`） |
| 应用名 | `AndroidManifest.xml` 硬编码 `android:label="小喵Player"` |
| 通知渠道 | `BackgroundPlaybackService.kt:30` `CHANNEL_ID = "moumou_background_playback"`；渠道名 `"听视频后台播放"`、描述 `"在后台继续播放视频音频"`、默认标题 `"听视频"`、正文 `"正在后台播放"` |
| 崩溃日志表头 | `CrashHandler.kt` 18 条中文字面量 |
| 存储卷名 | `MainActivity.kt:1552` 回退名 `"内部存储"` / `"SD 卡"`（用户可见） |
| 其它 | `VideoFsWalker.kt` 9 条（日志）、`MainActivity.kt:916` `"读取日志失败：…"` |
| 语言资源目录 | 无 `values-en/`、无 `values-zh/` |

## 12. 零基建确认

| 项 | 现状 |
|---|---|
| `flutter_localizations` / `intl` | `pubspec.yaml`、`pubspec.lock` 均没有 |
| `localizationsDelegates` / `supportedLocales` / `Locale(` | lib 下 0 处 |
| `l10n.yaml` / ARB 文件 | 不存在 |
| `flutter gen-l10n` | 可用；`--synthetic-package` **已废弃**（help 原文 "DEPRECATED. This flag cannot be enabled"）→ 生成物必须落地到工程目录 |
| 系统语言读取 | 仅 1 处：`lib/services/subtitle_service.dart:707` 用 `PlatformDispatcher.instance.locales` 决定简/繁字幕优先 |

---

## 13. 不可翻译清单（**唯一**的"必须保持中文"内容）

以下中文**不是 UI 文案**，翻译即功能失效。白名单文件：`tools/whitelist.json`（`residual` 命令据此豁免）。

| # | 位置 | 为什么不能翻 |
|---|---|---|
| 1 | `lib/utils/subtitle_language.dart:25–28,31–37,47` | 判定视频**自带字幕轨**是否中文轨（认「中文/中字/简体/繁体/特效」与 `zh/chi/zho/cn/chs/cht/sc/tc`） |
| 2 | `lib/utils/subtitle_auto_match.dart:54,61` | 外挂字幕文件名含「简」「繁」时优先 |
| 3 | `lib/utils/danmaku_episode.dart:56` | `RegExp(r'第\s*(\d+)\s*[话集回話]')` 从文件名认集数 |
| 4 | `lib/utils/chapter_utils.dart:12–42` | 章节关键词表（片头/片尾/前情提要/制作人员…），已中/英/日/法/意并存，只追加不修改 |
| 5 | `lib/services/network/ftp_client.dart:287` | FTP 目录列表非 UTF-8 时按 GBK 解码（中文服务器兼容） |
| 6 | `lib/widgets/folder_actions.dart:260,380` | 中文当**哨兵值**（`== '取消'`），全 lib 唯一 2 处中文参与逻辑比较。**阶段 1 第一件事**是改成常量/枚举，改完删除白名单对应条目 |
| 7 | 弹幕屏蔽词（`lib/utils/danmaku_blocklist.dart`） | 纯用户数据，无内置中文词，无需处理 |
| 8 | 日志输出（实测 51 处中文） | 开发者可见。**用户已拍板：无论将来增加多少语言，日志永远保持中文**（永久规则，不算"残留中文"） |
| 9 | 截图文件名 `lib/utils/formatters.dart:24` 的 `小喵Player-yyyy-…` | 用户已定**不随语言变化**（避免用户按语言找文件、与相册里历史截图不一致） |
| 10 | 字幕简/繁优先判定 `lib/services/subtitle_service.dart:707`（读**系统语言**） | 与 App 界面语言无关，**保持用系统语言**，不许改成 `app_locale` |

另外：B 站 / 弹弹Play / 字幕站的接口**返回内容**是中文（番剧名、弹幕文本、字幕语言名），属数据不是 UI，不翻。

---

## 14. 持久化审计（结论：翻译不会破坏任何用户设置）

口径：全量检索 lib 下 `getString / setString / getStringList / setStringList / getInt / setBool / getDouble` 的 138 处调用点，逐个人工确认写入值的来源。

| 结论 | 证据 |
|---|---|
| **没有任何中文被写入持久化** | 写入值全部是 `.name`（枚举名）、`.id`（英文 id）、`index`（下标）、`mpvValue`（英文）、`#RRGGBB`、路径、`jsonEncode(...)` |
| 用 **index** 持久化的文件 | `lib/services/view_settings.dart`（`SortField.values[sf]`、`VideoField.values[int.tryParse(e)]`、`_keyVideoFieldsV2` 存 `e.index.toString()`） |
| 用 **英文 id** 持久化的文件 | `lib/services/player_controls_settings.dart:250`（`PlayerTopAction.byId`）、`super_resolution_service.dart`（`mode.id`）、`equalizer_settings.dart`（`preset.id`）、`decode_settings.dart`（`v.name`） |
| 语言偏好键（本阶段新增） | 必须用 ASCII 键名，值**只允许 `'zh'` / `'en'`**（**没有 `'system'`**，默认 `'zh'`），**不要**存中文、**不要**存枚举 index |

**推论（硬约束）**：表改造可以删掉枚举里的中文 `label` 字段，但**绝对不能调整枚举项顺序**；否则 `view_settings` 一类用 index 的旧存档会被读成别的选项（用户表现为"设置莫名重置"）。

---

## 15. 附录 A · 文案最多的 45 个文件（占 71.2%）

| 处数 | 去重 | 中文字 | 文件 |
|---|---|---|---|
| 94 | 87 | 835 | `lib/pages/settings/player_settings_page.dart` |
| 69 | 64 | 470 | `lib/pages/player/views/subtitle_panel.dart` |
| 60 | 54 | 315 | `lib/pages/player/player_page.dart` |
| 59 | 44 | 347 | `lib/pages/subtitle/views/subtitle_settings_section.dart` |
| 57 | 57 | 305 | `lib/pages/player/views/player_danmaku_settings_panel.dart` |
| 49 | 49 | 144 | `lib/theme/theme_controller.dart` |
| 46 | 40 | 144 | `lib/pages/media_info/media_info_page.dart` |
| 43 | 38 | 208 | `lib/pages/player/player_portrait_page.dart` |
| 37 | 33 | 314 | `lib/pages/settings/danmaku_server_page.dart` |
| 36 | 36 | 90 | `lib/utils/chapter_utils.dart`（不可翻译，见 §13） |
| 34 | 30 | 261 | `lib/pages/bilibili/bili_login_page.dart` |
| 34 | 34 | 309 | `lib/pages/settings/media_scan_settings_page.dart` |
| 32 | 32 | 171 | `lib/pages/settings/settings_page.dart` |
| 30 | 30 | 120 | `lib/pages/network/account_edit_page.dart` |
| 30 | 30 | 143 | `lib/pages/player/views/player_diagnostics_panel.dart` |
| 29 | 23 | 155 | `lib/pages/settings/error_log_page.dart` |
| 29 | 29 | 166 | `lib/pages/settings/font_page.dart` |
| 27 | 22 | 135 | `lib/widgets/file_operations_ui.dart` |
| 26 | 25 | 77 | `lib/models/player_action.dart`（表） |
| 24 | 24 | 151 | `lib/pages/settings/about_page.dart` |
| 24 | 23 | 145 | `lib/pages/subtitle/subtitle_download_page.dart` |
| 24 | 15 | 58 | `lib/services/view_settings.dart`（表） |
| 24 | 19 | 79 | `lib/widgets/folder_actions.dart`（含哨兵值） |
| 23 | 23 | 162 | `lib/pages/home/home_page.dart` |
| 23 | 23 | 130 | `lib/pages/settings/appearance_page.dart` |
| 23 | 23 | 84 | `lib/pages/settings/decoder_detail_page.dart` |
| 21 | 21 | 66 | `lib/pages/bilibili/bili_index_page.dart` |
| 21 | 17 | 84 | `lib/pages/download/download_manager_page.dart` |
| 21 | 20 | 90 | `lib/pages/network/network_browser_page.dart` |
| 21 | 20 | 75 | `lib/pages/player/views/audio_player_panels.dart`（表） |
| 21 | 20 | 147 | `lib/pages/settings/cache_management_page.dart` |
| 20 | 20 | 145 | `lib/models/super_resolution_mode.dart`（表） |
| 20 | 18 | 103 | `lib/pages/settings/device_info_page.dart` |
| 20 | 20 | 82 | `lib/services/decode_settings.dart`（表） |
| 19 | 17 | 46 | `lib/models/subtitle_track.dart`（表） |
| 19 | 16 | 44 | `lib/utils/subtitle_language.dart`（不可翻译） |
| 17 | 17 | 202 | `lib/pages/settings/playback_history_page.dart` |
| 16 | 16 | 36 | `lib/pages/bilibili/bili_season_page.dart` |
| 16 | 12 | 134 | `lib/services/file_operations_service.dart` |
| 16 | 15 | 147 | `lib/services/network/ftp_client.dart`（含不可翻译行） |
| 14 | 14 | 83 | `lib/pages/bilibili/bili_video_download_page.dart` |
| 14 | 14 | 95 | `lib/pages/player/views/audio_panel.dart` |
| 13 | 13 | 75 | `lib/pages/bilibili/bili_danmaku_download_page.dart` |
| 13 | 11 | 55 | `lib/widgets/update_dialog.dart` |
| 12 | 11 | 48 | `lib/pages/bilibili/bili_user_page.dart` |

其余 119 个文件每文件 ≤11 处（其中 77 个 ≤5 处）。完整逐文件清单见 `03-任务清单.md`。

## 16. 附录 B · 31 个携带中文标签的枚举（128 项）

| 中文项/总项 | 枚举 | 文件 |
|---|---|---|
| 13/16 | `PlayerTopAction` | `lib/models/player_action.dart` |
| 8/8 | `VideoField` | `lib/services/view_settings.dart` |
| 7/9 | `PlayerVideoFit` | `lib/models/player_action.dart` |
| 7/10 | `SuperResolutionMode` | `lib/models/super_resolution_mode.dart` |
| 6/6 | `ChapterSkipType` | `lib/models/chapter_info.dart` |
| 6/6 | `AudioSleepPreset` | `lib/pages/player/views/audio_player_panels.dart` |
| 6/6 | `DecodePreset` | `lib/services/decode_settings.dart` |
| 5/7 | `AudioChannels` | `lib/models/audio_track.dart` |
| 4/4 | `PlaylistSortMode` | `lib/models/playlist_sort.dart` |
| 4/4 | `DecodeMode` | `lib/services/decode_settings.dart` |
| 4/4 | `SortField` | `lib/services/view_settings.dart` |
| 4/4 | `FolderField` | `lib/services/view_settings.dart` |
| 4/4 | `VideoSortField` | `lib/services/view_settings.dart` |
| 4/4 | `AppThemeMode` | `lib/theme/theme_controller.dart` |
| 4/4 | `NetworkTimeoutTier` | `lib/utils/retry_policy.dart` |
| 3/4 | `DanmakuColorMode` | `lib/models/danmaku_color_mode.dart` |
| 3/3 | `DanmakuFontMode` | `lib/models/danmaku_font_mode.dart` |
| 3/3 | `DoubleTapMode` | `lib/models/player_action.dart` |
| 3/3 | `VideoOrientationMode` | `lib/models/player_action.dart` |
| 3/3 | `LoopMode` | `lib/models/player_loop.dart` |
| 3/3 | `SubtitleDirSort` | `lib/models/subtitle_dir.dart` |
| 3/3 | `SubtitleAlign` | `lib/models/subtitle_track.dart` |
| 3/3 | `SubtitleBorderStyle` | `lib/models/subtitle_track.dart` |
| 3/4 | `SuperResolutionQuality` | `lib/models/super_resolution_mode.dart` |
| 3/3 | `AudioRepeatMode` | `lib/pages/player/views/audio_player_panels.dart` |
| 2/2 | `SortOrder` | `lib/services/view_settings.dart` |
| 2/2 | `ViewMode` | `lib/services/view_settings.dart` |
| 2/2 | `WallpaperScaleMode` | `lib/services/wallpaper_settings.dart` |
| 2/4 | `SubtitleSourceKind` | `lib/services/subtitle/subtitle_source_settings.dart` |
| 2/2 | `NetworkSortField` | `lib/utils/network_sort.dart` |
| 2/2 | `NetworkSortOrder` | `lib/utils/network_sort.dart` |

**非枚举的表**：`theme_controller.presetColors`（23 条记录型）、`FlexSchemeVariant` 名称映射（21 条）、101 条 `'键': '中文值'` 映射项（最多 `media_info_page.dart` 19 条）。

## 17. 附录 C · 受影响的测试文件摘要

- **强耦合（含 `find.text('中文')`）37 个文件 / 535 处**，头部：`player_danmaku_network_panel_test`(64)、`player_danmaku_settings_panel_test`(61)、`subtitle_download_page_test`(61)、`danmaku_server_page_test`(41)、`file_operations_ui_test`(32)、`wallpaper_editor_page_test`(22)、`appearance_page_test`(19)、`player_settings_page_test`(19)、`device_info_page_test`(16)、`network_browser_page_test`(14)…
- **访问 `.label` 等 24 个文件 / 53 处**，头部：`equalizer_preset_test`(6)、`audio_track_test`(5)、`bili_bangumi_test`(4)、`network_sort_test`(4)…

完整清单（含每个文件的处数标注）见 `03-任务清单.md` 末节。

## 18. 附录 D · 无 `BuildContext` 层文案最多的文件（前 30）

| 处数 | 去重 | 文件 |
|---|---|---|
| 36 | 36 | `lib/utils/chapter_utils.dart`（不可翻译） |
| 26 | 25 | `lib/models/player_action.dart`（表） |
| 24 | 15 | `lib/services/view_settings.dart`（表） |
| 20 | 20 | `lib/models/super_resolution_mode.dart`（表） |
| 20 | 20 | `lib/services/decode_settings.dart`（表） |
| 19 | 17 | `lib/models/subtitle_track.dart`（表） |
| 19 | 16 | `lib/utils/subtitle_language.dart`（不可翻译） |
| 16 | 12 | `lib/services/file_operations_service.dart` |
| 16 | 15 | `lib/services/network/ftp_client.dart` |
| 11 | 5 | `lib/services/bilibili/bili_http.dart` |
| 11 | 10 | `lib/services/wyzie/wyzie_api.dart` |
| 10 | 10 | `lib/services/network/webdav_client.dart` |
| 10 | 10 | `lib/utils/file_ops.dart` |
| 9 | 8 | `lib/services/dandan_play_api.dart` |
| 9 | 9 | `lib/services/subtitle/custom_subtitle_api.dart` |
| 8 | 8 | `lib/services/bilibili/bili_video_service.dart` |
| 8 | 8 | `lib/services/download/download_task.dart` |
| 8 | 7 | `lib/services/network/smb_client.dart` |
| 8 | 8 | `lib/utils/network_path.dart` |
| 7 | 7 | `lib/models/audio_track.dart`（表） |
| 7 | 7 | `lib/services/bilibili/bili_account.dart` |
| 7 | 5 | `lib/services/bilibili/bili_danmaku_service.dart` |
| 6 | 6 | `lib/models/chapter_info.dart`（表） |
| 6 | 6 | `lib/models/equalizer_preset.dart`（表） |
| 6 | 6 | `lib/services/media_scan_settings.dart`（表） |
| 6 | 5 | `lib/services/bilibili/bili_download_service.dart` |
| 6 | 6 | `lib/utils/dolby_vision_hint.dart` |
| 6 | 6 | `lib/utils/player_diagnostics.dart` |
| 5 | 5 | `lib/services/wallpaper_settings.dart`（表） |
| 5 | 5 | `lib/services/bilibili/bili_auth_service.dart` |

---

## 19. 数据口径与复现

1. **字面量**＝单/双/三引号字符串字面量；**只在注释行内的中文不计入**（注释行判定：该行 `lstrip()` 后以 `//` 或 `*` 开头）。
2. **枚举中文标签**＝对每个 `enum X { … }` 做花括号配平取块，块内逐项做括号配平取整项，项内任一字符串字面量含中文即计入。
3. **分层**：`lib/pages`、`lib/widgets`、`lib/theme` = UI 层；`lib/services`、`lib/models`、`lib/utils` = 无 context 层。
4. **`const` 风险**＝中文字面量所在行含 `const` 关键字（近似，非语法级判定）。
5. **测试 locale**＝临时 `testWidgets` 探针打印 `platformDispatcher.locale/locales` 与 `Localizations.localeOf(context)`。
6. **Flutter 生成机制**＝检索本机 SDK（`D:\allexe\flutter`）源码中 `generateLocalizations()` 的调用点。

复现命令：

```powershell
python tools/i18n_scan.py baseline     # 总量 + 分层 + ARB 语法
python tools/i18n_scan.py enums        # 枚举表清单
python tools/i18n_scan.py dupes        # 跨文件重复文案
python tools/i18n_scan.py residual     # 残留中文（白名单外），有残留 exit 1
python tools/i18n_scan.py tasks        # 重新生成 03-任务清单.md（保留勾选）
```

## 20. 未验证项（执行者不要当结论用）

| 项 | 状态 |
|---|---|
| `flutter test` 是否触发 `gen_l10n` | 未验证（因此方案选择"生成物入库"规避） |
| `CrashHandler` 崩溃路径里能否安全取 Android 资源 | 未验证，需真机实测 |
| 通知渠道改名对**已安装旧版**用户是否生效 | 未验证，需真机实测 |
| 自定义 App 字体是否覆盖拉丁字形 | 未验证 |
| 英文文案在各固定宽度控件里的实际溢出情况 | 未验证，需人工目视 |
| 英文应用名 | **已定：`Meow Player`**（中文仍 `小喵Player`） |
| 长文（隐私政策/协议）落地方式 | **已定：按语言拆 Dart 文件**（`lib/l10n/legal_zh.dart` / `legal_en.dart`），英文 AI 翻译即可 |
| 日志是否翻译 | **已定：永保中文**（见 §13 第 8 条） |
| 生成物是否入库 | **已定：入库** |
| 截图文件名是否跟随语言 | **已定：不跟随**（见 §13 第 9 条） |
