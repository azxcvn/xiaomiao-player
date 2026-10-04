# -*- coding: utf-8 -*-
"""阶段 4（播放器群）新增 ARB 键：写入 app_zh.arb / app_en.arb。

- 只新增，不修改已有键；zh 侧带 description，en 侧不带元数据（与现状一致）；
- 含占位符的键补 placeholders 元数据；计数文案按方案用 plural 语法；
- 运行后必须 `flutter gen-l10n`。
"""
import json
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

ZH = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
EN = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'

E = []


def e(key, zh, en, desc, ph=None):
    E.append((key, zh, en, desc, ph))


# ── 通用（跨页面复用的短词）──────────────────────────────────
e('commonBack', '返回', 'Back', '通用按钮：返回（播放器顶栏 / 听视频页）')
e('commonMore', '更多', 'More', '通用按钮：更多（播放器顶栏「更多」面板入口）')
e('commonPlay', '播放', 'Play', '通用：播放（播放/暂停按钮、诊断面板分组名）')
e('commonPause', '暂停', 'Pause', '通用：暂停（播放/暂停按钮）')
e('commonPlaying', '播放中', 'Playing', '通用：播放中（列表当前项标记）')
e('commonSearch', '搜索', 'Search', '通用按钮：搜索')
e('commonClearAll', '清空', 'Clear', '通用按钮：清空（输入框 / 屏蔽词列表）')
e('commonNone', '无', 'None', '通用：无（数值为 0 时的读数）')
e('commonNotSet', '未设置', 'Not set', '通用：未设置（空态读数）')
e('commonCustom', '自定义', 'Custom', '通用：自定义（定时关闭预设）')
e('commonJump', '跳转', 'Go', '通用按钮：跳转（弹幕集数跳转）')
e('commonSortBy', '排序方式', 'Sort by', '通用：排序方式（字幕文件选择器）')
e('commonGoUp', '上级', 'Up', '通用按钮：上级目录（字幕文件选择器）')
e('commonRefresh', '刷新', 'Refresh', '通用按钮：刷新（字体目录）')
e('commonOneKeyReset', '一键重置', 'Reset all', '通用按钮：一键重置（均衡器 / 片头片尾）')
e('commonRestoreDefaults', '恢复默认设置', 'Restore defaults',
  '通用按钮：恢复默认设置（弹幕设置）')
e('commonLoadingDots', '正在加载...', 'Loading...', '通用：正在加载（字体目录读取中）')
e('commonTitle', '标题', 'Title', '通用字段名：标题（诊断面板）')
e('commonBlur', '模糊', 'Blur', '通用：模糊（字幕文字效果）')
e('commonEpisodeUnit', '集', 'ep', '通用：集（弹幕集数跳转输入框后缀）')

# ── 播放页（横屏 player_page / 竖屏 player_portrait_page）──────
e('playerAutoLoadedSubtitle', '已自动加载字幕：{fileName}', 'Subtitles auto-loaded: {fileName}',
  '播放页提示：自动匹配到并加载了外挂字幕', {'fileName': 'String'})
e('playerAutoLoadedDanmaku', '已自动加载弹幕：{fileName}', 'Danmaku auto-loaded: {fileName}',
  '播放页提示：自动匹配到并加载了弹幕文件', {'fileName': 'String'})
e('playerDanmakuLoaded', '已加载弹幕：{message}', 'Danmaku loaded: {message}',
  '播放页提示：加载弹幕成功（附加来源说明）', {'message': 'String'})
e('playerQualityUnavailableSwitched', '该清晰度不可用，已切换到 {name}',
  'That quality is unavailable; switched to {name}',
  '播放页提示：所选清晰度不可用后自动切换', {'name': 'String'})
e('playerQualitySwitchFailed', '切换画质失败：{error}', 'Failed to switch quality: {error}',
  '播放页提示：切换清晰度异常', {'error': 'String'})
e('playerQuality', '清晰度', 'Quality', '播放器「更多」面板 / 清晰度面板：清晰度')
e('playerScreenshotFailed', '截图失败：{error}', 'Screenshot failed: {error}',
  '播放页提示：截图异常', {'error': 'String'})
e('playerScreenshotNoImage', '截图失败：未获取到图像', 'Screenshot failed: no image captured',
  '播放页提示：截图拿到空数据')
e('playerSavedToGallery', '已保存到相册', 'Saved to gallery', '播放页提示：截图保存成功')
e('playerScreenshotSaveFailed', '截图保存失败：{error}', 'Failed to save screenshot: {error}',
  '播放页提示：截图保存到相册失败', {'error': 'String'})
e('playerDanmakuSettings', '弹幕设置', 'Danmaku settings', '播放器面板：弹幕设置入口 / 页标题')
e('playerSkippedIntro', '已跳过片头', 'Intro skipped', '播放页提示：已跳过片头')
e('playerSkippedOutro', '已跳过片尾', 'Outro skipped', '播放页提示：已跳过片尾')
e('playerNoNetworkCannotSwitch', '网络连接不存在，无法切换', 'No network connection; cannot switch',
  '播放页提示：离线时无法切集')
e('playerSwitchFailed', '切换失败：{error}', 'Switch failed: {error}',
  '播放页提示：切集/切换失败', {'error': 'String'})
e('playerResolveUrlFailed', '解析播放地址失败', 'Failed to resolve the playback URL',
  '播放页错误卡片：播放地址解析失败')
e('playerSwitchEpisodeFailed', '切集失败：{error}', 'Failed to switch episode: {error}',
  '播放页提示：B 站切集失败', {'error': 'String'})
e('playerPlaybackSpeed', '播放倍速', 'Playback speed', '播放器面板：倍速（横竖屏一致）')
e('playerSuperResolution', '超分辨率', 'Super resolution',
  '播放器：超分辨率（面板标题 / 底栏按钮 / 记忆项）')
e('playerAspectRatio', '画面比例', 'Aspect ratio', '播放器面板：画面比例')
e('playerCastUnsupportedSource', '暂不支持投屏该来源', 'Casting this source is not supported yet',
  '播放页提示：该来源不支持投屏')
e('playerFeatureNotPlaced', '未放置的功能', 'Not placed', '播放器「编辑控制栏」：未放置区标题')
e('playerFeatureComingSoon', '功能即将上线', 'Coming soon',
  '播放器「更多」面板：未实现动作的副标题')
e('playerEditControlBar', '编辑控制栏', 'Edit control bar', '播放器：编辑控制栏入口 / 页标题')
e('playerActionsEnabledHint', '已启用（长按拖拽排序）', 'Enabled (long-press to drag and reorder)',
  '播放器「编辑控制栏」：已启用区标题')
e('playerNoEnabledActions', '暂无已启用动作，从下方添加', 'No actions enabled yet; add one below',
  '播放器「编辑控制栏」：已启用区空态')
e('playerAddable', '可添加', 'Available', '播放器「编辑控制栏」：可添加区标题')
e('playerMaxActions', '{max, plural, other{最多允许放 {max} 个}}',
  '{max, plural, =1{Up to 1 action} other{Up to {max} actions}}',
  '播放器「编辑控制栏」：槽位已满提示', {'max': 'int'})
e('playerResetControlBar', '重置控制栏', 'Reset control bar',
  '播放器「编辑控制栏」：重置按钮')
e('playerDanmakuNetwork', '网络弹幕', 'Online danmaku',
  '播放器：网络弹幕（弹幕面板入口 / 面板标题）')
e('playerDanmakuLoadFailed', '弹幕加载失败', 'Failed to load danmaku',
  '播放器：弹幕加载失败（错误卡片标题）')
e('playerDanmakuMatching', '正在匹配弹幕，请稍候…', 'Matching danmaku, please wait…',
  '播放器：网络弹幕匹配中')
e('playerDanmakuNoMatch', '未找到匹配的弹幕', 'No matching danmaku found',
  '播放器：网络弹幕无匹配结果')
e('playerDanmakuPickMatch', '选择匹配结果', 'Choose a match', '播放器：选择弹幕匹配结果弹窗')
e('playerPipUnsupported', '当前设备不支持画中画', 'Picture-in-picture is not supported on this device',
  '播放页提示：设备不支持画中画')
e('playerPipFailed', '进入画中画失败', 'Failed to enter picture-in-picture',
  '播放页提示：进入画中画异常')
e('playerPlaylist', '播放列表', 'Playlist', '播放器：播放列表（面板标题 / 底栏按钮）')
e('playerLock', '锁定', 'Lock', '播放器：锁定控制层（按钮语义）')
e('playerUnlock', '解锁', 'Unlock', '播放器：解锁控制层（按钮语义）')
e('playerScreenshot', '截图', 'Screenshot', '播放器：截图按钮语义')
e('playerRestoreView', '还原画面', 'Restore view', '播放器：缩放后还原画面胶囊')

# ── 音轨面板（audio_panel）──────────────────────────────────
e('playerAudioTrack', '音轨', 'Audio track', '播放器音轨面板：音轨分组标题')
e('playerNoAudioTrackHint', '当前视频没有音轨，可在下方导入外部音轨',
  'This video has no audio track; you can import an external one below',
  '播放器音轨面板：无音轨空态')
e('playerExternalAudioTrack', '外部音轨', 'External audio track', '播放器音轨面板：外部音轨分组')
e('playerImportExternalAudioTrack', '导入外部音轨', 'Import external audio track',
  '播放器音轨面板：导入外部音轨入口')
e('playerTempEffectHint', '临时生效，退出播放后不保留', 'Temporary; not kept after you leave the player',
  '播放器音轨面板：外部音轨临时生效说明')
e('playerAudioChannel', '音频声道', 'Audio channel', '播放器音轨面板：音频声道')
e('playerAudioProcessing', '音频处理', 'Audio processing', '播放器音轨面板：音频处理分组')
e('playerVolumeNormalize', '音量标准化', 'Volume normalization',
  '播放器音轨面板：音量标准化开关')
e('playerDynamicRangeCompress', '动态范围压缩', 'Dynamic range compression',
  '播放器音轨面板：动态范围压缩开关')
e('playerPickAudioFile', '选择音频文件', 'Choose an audio file', '播放器音轨面板：选择音频文件')
e('playerExternalAudioImported', '已导入外部音轨', 'External audio track imported',
  '播放器音轨面板：导入成功提示')
e('playerImportFailedCheckFormat', '导入失败，请检查文件格式', 'Import failed; check the file format',
  '播放器：导入外挂音轨/字幕失败提示')
e('playerRemoveAudioTrack', '移除已导入的音轨', 'Remove the imported audio track',
  '播放器音轨面板：移除外部音轨按钮')

# ── 听视频（audio_player_page / audio_player_panels）──────────
e('audioPlaybackSpeed', '播放速度', 'Playback speed', '听视频：倍速面板标题')
e('audioRepeatOff', '循环关闭', 'Repeat off', '听视频：循环模式（关闭）')
e('audioRepeatSingle', '单曲循环', 'Repeat one',
  '听视频：循环模式（单曲循环）；列表循环复用 loopModeLoopAll')
e('audioSleepTimer', '定时关闭', 'Sleep timer', '听视频：定时关闭')
e('audioSleepEndOfTrack', '播完当前', 'After current track',
  '听视频：定时关闭（播完当前曲目）')
e('audioSleepEndOfTrackHint', '将在当前曲目播放结束后停止', 'Will stop after the current track ends',
  '听视频：定时关闭（播完当前）说明')
e('audioSleepRemaining', '剩余 {time}', '{time} left', '听视频：定时关闭剩余时间',
  {'time': 'String'})
e('audioSleepCustomTitle', '自定义定时关闭', 'Custom sleep timer', '听视频：自定义定时关闭弹窗')
e('audioSleepMinutes',
  '{minutes, plural, other{{minutes} 分钟}}',
  '{minutes, plural, =1{1 minute} other{{minutes} minutes}}',
  '听视频：定时关闭分钟档位（15 / 30 / 60 / 自定义输入）', {'minutes': 'int'})
e('audioShuffle', '随机播放', 'Shuffle', '听视频：随机播放')
e('playerPlaylistWithCount', '播放列表（{count}）', 'Playlist ({count})',
  '听视频：播放列表面板标题（带曲目数）', {'count': 'int'})

# ── 均衡器（equalizer_panel）───────────────────────────────
e('playerEqualizerEnable', '启用均衡器', 'Enable equalizer', '播放器均衡器面板：总开关')
e('playerEqualizerDesc', '调节频段增益、低音增强和虚拟环绕',
  'Adjust band gain, bass boost and virtual surround', '播放器均衡器面板：总开关说明')
e('playerPreset', '预设', 'Preset', '播放器：预设（均衡器 / 倍速面板分组标题）')
e('playerEqualizerBands', '频段调节', 'Band adjustment', '播放器均衡器面板：频段调节分组')
e('playerEqualizerBass', '低音增强', 'Bass boost', '播放器均衡器面板：低音增强')
e('playerEqualizerSurround', '虚拟环绕', 'Virtual surround', '播放器均衡器面板：虚拟环绕')

# ── B 站剧集列表（player_bili_playlist_panel）────────────────
e('playerBiliNoEpisodes', '没有获取到剧集列表', 'No episode list available',
  '播放器 B 站剧集面板：空态')
e('playerBiliTotalEpisodes', '{total, plural, other{共 {total} 集}}',
  '{total, plural, =1{1 episode} other{{total} episodes}}',
  '播放器 B 站剧集面板：总集数', {'total': 'int'})
e('playerBiliCurrentOfTotal', '第 {current} 集 / 共 {total, plural, other{{total} 集}}',
  '{total, plural, =1{Episode {current} of 1} other{Episode {current} of {total}}}',
  '播放器 B 站剧集面板：当前集 / 总集数', {'current': 'int', 'total': 'int'})
e('playerBiliFreeLimited', '限免', 'Free for a limited time',
  '播放器 B 站剧集面板：限免集标记')
e('playerBiliPreview', '预告', 'Preview', '播放器 B 站剧集面板：预告标记')

# ── 底栏 / 手势提示（bottom_bar / center_cluster）─────────────
e('playerNextEpisode', '下一集', 'Next episode', '播放器底栏：下一集按钮')
e('playerCastSelectScreen', '选择屏幕', 'Choose a screen', '播放器底栏：选择投屏设备')
e('playerSeekBackSeconds', '快退 {seconds} 秒', 'Rewind {seconds}s',
  '播放器手势提示：双击左侧快退', {'seconds': 'int'})
e('playerSeekForwardSeconds', '快进 {seconds} 秒', 'Forward {seconds}s',
  '播放器手势提示：双击右侧快进', {'seconds': 'int'})

# ── 章节 / 章节跳段（player_chapter_panel / player_chapter_skip_panel）──
e('playerChapterPanelTitle', '章节跳段', 'Chapter skip', '播放器章节面板：标题')
e('playerNoChapters', '当前视频无章节信息', 'This video has no chapter info',
  '播放器章节面板：空态')
e('playerChapterCount', '{count, plural, other{共 {count} 章}}',
  '{count, plural, =1{1 chapter} other{{count} chapters}}',
  '播放器章节面板：章节总数', {'count': 'int'})
e('playerChapterSkipAuto', '自动跳过', 'Auto skip', '播放器章节跳段面板：自动跳过开关')
e('playerChapterSkipAutoDesc', '进入对应片段时自动跳到片段结束；关闭则仅弹出跳过胶囊',
  'Jump to the end of the segment automatically; when off, only the skip chip appears',
  '播放器章节跳段面板：自动跳过说明')
e('playerChapterSkipCustomKeywords', '自定义关键词', 'Custom keywords',
  '播放器章节跳段面板：自定义关键词分组')
e('playerChapterSkipKeywordsHint', '按章节标题匹配，支持逗号 / 分号 / 换行分隔',
  'Matched against chapter titles; separate with commas, semicolons or new lines',
  '播放器章节跳段面板：关键词输入说明')
e('playerIntroKeywords', '片头关键词', 'Intro keywords', '播放器章节跳段面板：片头关键词')
e('playerIntroKeywordsHint', '如 ap、op、开场', 'e.g. ap, op, opening',
  '播放器章节跳段面板：片头关键词提示')
e('playerOutroKeywords', '片尾关键词', 'Outro keywords', '播放器章节跳段面板：片尾关键词')
e('playerOutroKeywordsHint', '如 ed、ending、结尾', 'e.g. ed, ending, credits',
  '播放器章节跳段面板：片尾关键词提示')
e('playerChapterSkipKeywordOwnerHint',
  '关键词归属由你填入的位置决定：填进「片头关键词」即判为片头、填进「片尾关键词」即判为片尾；'
  '同一标题命中多类时按固定优先级（前情提要 > 正片前段 > 制作人员 > 下集预告 > 片尾 > 片头）取一类。',
  'Which slot you type a keyword into decides its type: in "Intro keywords" it counts as an intro, '
  'in "Outro keywords" as an outro. When a title matches several types, a fixed priority decides '
  '(recap > cold open > credits > preview > outro > intro).',
  '播放器章节跳段面板：关键词归属说明（多行拼接）')

# ── 弹幕按钮 / 集数跳转 / 网络弹幕（buttons / episodes / network）───
e('playerDanmakuClose', '关闭弹幕', 'Turn off danmaku', '播放器弹幕按钮：关闭弹幕')
e('playerDanmakuOpen', '打开弹幕', 'Turn on danmaku', '播放器弹幕按钮：打开弹幕')
e('playerEpisodeInvalidInput', '请输入集数（数字）', 'Enter an episode number (digits)',
  '播放器弹幕集数跳转：非法输入提示')
e('playerEpisodeNotFound', '没有第 {number} 集', 'There is no episode {number}',
  '播放器弹幕集数跳转：集数不存在', {'number': 'int'})
e('playerEpisodeTotalFromServer', '{total, plural, other{共 {total} 集 · 来自 {server}}}',
  '{total, plural, =1{1 episode · from {server}} other{{total} episodes · from {server}}}',
  '播放器弹幕集数面板：某台服务器的集数', {'total': 'int', 'server': 'String'})
e('playerJumpToEpisode', '跳至第', 'Jump to', '播放器弹幕集数跳转：输入行前缀')
e('playerEpisodeNumber', '集数', 'Episode number', '播放器弹幕集数跳转：输入框标签')
e('playerDanmakuNetworkSearchHint', '输入番剧名称', 'Enter an anime title',
  '播放器网络弹幕面板：搜索框提示')
e('playerDanmakuStopSearch', '停止搜索', 'Stop search', '播放器网络弹幕面板：停止搜索')
e('playerDanmakuResultCountUnit', '{count, plural, other{{count} 部}}',
  '{count, plural, =1{1 title} other{{count} titles}}',
  '播放器网络弹幕面板：搜索结果数（部）', {'count': 'int'})
e('playerDanmakuSearchingWithCount', '正在搜索 · 已获得 {count, plural, other{{count} 部}}',
  'Searching · {count, plural, =1{1 title} other{{count} titles}} found',
  '播放器网络弹幕面板：搜索中状态', {'count': 'int'})
e('playerDanmakuSearchStoppedCount', '已停止搜索 · 共 {count, plural, other{{count} 部}}',
  'Search stopped · {count, plural, =1{1 title} other{{count} titles}} in total',
  '播放器网络弹幕面板：已停止搜索状态', {'count': 'int'})
e('playerDanmakuPartialServerFailed', '部分服务器搜索失败：{errors}',
  'Some servers failed to search: {errors}', '播放器网络弹幕面板：部分服务器失败',
  {'errors': 'String'})
e('playerDanmakuSearching', '搜索中…', 'Searching…', '播放器网络弹幕面板：搜索中')
e('playerDanmakuNetworkInputHint', '输入关键词搜索网络弹幕',
  'Enter keywords to search online danmaku', '播放器网络弹幕面板：空态提示')
e('playerEpisodeCountUnit', '{count, plural, other{{count} 集}}',
  '{count, plural, =1{1 episode} other{{count} episodes}}',
  '播放器网络弹幕面板：番剧集数（集）', {'count': 'int'})

# ── 弹幕面板 / 弹幕设置（player_danmaku_panel / settings_panel）──
e('playerDanmakuLocal', '本地弹幕', 'Local danmaku', '播放器弹幕面板：本地弹幕入口')
e('playerDanmakuNetworkComingSoon', '「网络弹幕」功能即将上线',
  '"Online danmaku" is coming soon', '播放器弹幕面板：网络弹幕未实现提示')
e('playerDanmakuAutoMatch', '自动匹配', 'Auto match', '播放器弹幕面板：自动匹配入口')
e('playerDanmakuAutoMatchComingSoon', '「自动匹配」功能即将上线',
  '"Auto match" is coming soon', '播放器弹幕面板：自动匹配未实现提示')
e('playerPickDanmakuFile', '选择弹幕文件', 'Choose a danmaku file', '播放器弹幕面板：选择文件')
e('playerLocalDanmakuLoaded', '已加载本地弹幕（{count, plural, other{{count} 条}}）',
  'Local danmaku loaded ({count, plural, =1{1 item} other{{count} items}})',
  '播放器弹幕面板：本地弹幕导入成功', {'count': 'int'})
e('playerDanmakuLoadFailedCheckFormat', '弹幕加载失败，请检查文件格式',
  'Failed to load danmaku; check the file format', '播放器弹幕面板：导入失败提示')
e('playerDanmakuStyle', '弹幕样式', 'Danmaku style', '播放器弹幕设置：弹幕样式分组')
e('playerDanmakuFontSize', '弹幕字号', 'Danmaku font size', '播放器弹幕设置：弹幕字号')
e('playerDanmakuSpeed', '弹幕速度', 'Danmaku speed', '播放器弹幕设置：弹幕速度')
e('playerDanmakuSpeedDesc', '数值越小弹幕越快', 'The smaller the value, the faster the danmaku',
  '播放器弹幕设置：弹幕速度说明')
e('playerStrokeWidth', '描边粗细', 'Stroke width', '播放器：描边粗细（弹幕设置 / 字幕样式）')
e('playerOpacity', '不透明度', 'Opacity', '播放器弹幕设置：不透明度')
e('playerDanmakuConfig', '弹幕配置', 'Danmaku config', '播放器弹幕设置：弹幕配置分组')
e('playerDanmakuDisplayArea', '显示区域', 'Display area', '播放器弹幕设置：显示区域')
e('playerDanmakuLineHeight', '弹幕行高', 'Danmaku line height', '播放器弹幕设置：弹幕行高')
e('playerDanmakuTop', '顶部弹幕', 'Top danmaku', '播放器弹幕设置：顶部弹幕')
e('playerDanmakuBottom', '底部弹幕', 'Bottom danmaku', '播放器弹幕设置：底部弹幕')
e('playerDanmakuScroll', '滚动弹幕', 'Scrolling danmaku', '播放器弹幕设置：滚动弹幕')
e('playerDanmakuMassive', '海量弹幕', 'Massive danmaku', '播放器弹幕设置：海量弹幕')
e('playerDanmakuMassiveDesc', '轨道占满时叠加绘制，弹幕过多不再丢弃',
  'Draw overlapping when tracks are full so excess danmaku is no longer dropped',
  '播放器弹幕设置：海量弹幕说明')
e('playerDanmakuDedupe', '弹幕去重', 'Deduplicate danmaku', '播放器弹幕设置：弹幕去重')
e('playerDanmakuDedupeDesc', '相同时间下相同弹幕合并为一条',
  'Identical danmaku at the same time merge into one', '播放器弹幕设置：弹幕去重说明')
e('playerDanmakuMerge', '弹幕合并', 'Merge danmaku', '播放器弹幕设置：弹幕合并')
e('playerDanmakuMergeDesc', '不同时间内相同弹幕合并且计数',
  'Merge identical danmaku at different times and count them',
  '播放器弹幕设置：弹幕合并说明')
e('playerDanmakuOffset', '弹幕偏移', 'Danmaku offset', '播放器弹幕设置：弹幕偏移分组')
e('playerDanmakuTimelineOffset', '时间轴偏移', 'Timeline offset',
  '播放器弹幕设置：时间轴偏移')
e('playerDanmakuAdvanceOneSecond', '提前 1 秒', '1 s earlier',
  '播放器弹幕设置：时间轴提前 1 秒')
e('playerDanmakuDelayOneSecond', '延后 1 秒', '1 s later', '播放器弹幕设置：时间轴延后 1 秒')
e('playerDanmakuResetOffset', '重置偏移', 'Reset offset', '播放器弹幕设置：重置偏移')
e('playerDanmakuFont', '弹幕字体', 'Danmaku font', '播放器弹幕设置：弹幕字体分组')
e('danmakuColorModeSourceDesc', '保留弹幕自带颜色（含会员渐变彩色）',
  "Keep each danmaku's own color (including VIP gradient colors)",
  '播放器弹幕设置：跟随弹幕颜色说明')
e('danmakuColorModeRandomDesc', '忽略文件颜色，按色轮逐条随机着色',
  'Ignore file colors; color each danmaku randomly from the color wheel',
  '播放器弹幕设置：随机渐变色说明')
e('danmakuColorModeFixedDesc', '弹幕从下面已选颜色里随机取色',
  'Pick randomly from the colors selected below', '播放器弹幕设置：指定颜色说明')
e('playerDanmakuPaletteMaxHint', '{max, plural, other{最多选 {max} 种颜色}}',
  '{max, plural, =1{Up to 1 color} other{Up to {max} colors}}',
  '播放器弹幕设置：调色板上限提示', {'max': 'int'})
e('playerDanmakuPaletteTitle', '弹幕颜色（可多选，随机使用）',
  'Danmaku colors (multi-select, used at random)', '播放器弹幕设置：调色板标题')
e('playerDanmakuColorExists', '该颜色已在调色板中', 'This color is already in the palette',
  '播放器弹幕设置：重复添加颜色提示')
e('playerDanmakuPaletteFull', '{max, plural, other{已选满 {max} 种}}',
  '{max, plural, =1{All 1 color selected} other{All {max} colors selected}}',
  '播放器弹幕设置：调色板已满提示', {'max': 'int'})
e('playerDanmakuAddToPalette', '添加到调色板', 'Add to palette',
  '播放器弹幕设置：添加到调色板按钮')
e('playerDanmakuPaletteSelected', '已选 {selected}/{max, plural, other{{max} 种}}',
  '{selected} of {max, plural, =1{1 color} other{{max} colors}} selected',
  '播放器弹幕设置：已选颜色数', {'selected': 'int', 'max': 'int'})
e('playerDanmakuBlockWords', '屏蔽词', 'Blocked words', '播放器弹幕设置：屏蔽词分组')
e('playerDanmakuBlockWordsHint', '输入要屏蔽的关键词', 'Enter keywords to block',
  '播放器弹幕设置：屏蔽词输入提示')
e('playerFontsImported', '已导入 {count} 个字体文件，共 {total, plural, other{{total} 种字体}}',
  'Imported {count} font files, {total, plural, =1{1 typeface} other{{total} typefaces}} in total',
  '播放器：字体目录导入成功提示', {'count': 'int', 'total': 'int'})
e('playerPickFontDir', '选择字体目录', 'Choose a font folder', '播放器：选择字体目录')
e('playerFontDirImportHint', '点击导入包含 .ttf/.otf 字体的目录',
  'Tap to import a folder containing .ttf/.otf fonts', '播放器：导入字体目录提示')
e('playerFontsLoaded', '已加载 {count, plural, other{{count} 种字体}}',
  '{count, plural, =1{1 typeface loaded} other{{count} typefaces loaded}}',
  '播放器：字体目录已加载数量', {'count': 'int'})
e('playerPickFont', '选择字体', 'Choose a font', '播放器弹幕设置：选择字体')

# ── 解码面板（player_decode_panel）──────────────────────────
e('playerRestartRequired', '需重启应用', 'Restart required', '播放器解码面板：重启提示标题')
e('playerDecodeRestartBody', '解码配置已修改，重启应用后生效。\n\n是否立即重启？',
  'Decode settings changed. They take effect after restarting the app.\n\nRestart now?',
  '播放器解码面板：重启提示正文')
e('playerRestartLater', '稍后重启', 'Restart later', '播放器解码面板：稍后重启')
e('playerRestartNow', '立即重启', 'Restart now', '播放器解码面板：立即重启')
e('playerDecodePreset', '解码预设', 'Decode preset', '播放器解码面板：解码预设分组')
e('playerDecodePresetDesc', '切换后需重启应用生效，可选立即重启',
  'Takes effect after restarting the app; you can restart now',
  '播放器解码面板：解码预设分组说明')
e('playerDecodeHwPlusDesc', '「硬解+」直通不可用时由内核依次回退硬解 / 软解',
  'When "HW+" passthrough is unavailable, the core falls back to HW decode, then SW decode',
  '播放器解码面板：硬解+ 档说明')

# ── 诊断面板（player_diagnostics_panel）──────────────────────
e('playerDiagnosticsContainer', '容器', 'Container', '播放器诊断面板：容器格式')
e('playerDiagnosticsAudioCodec', '音频编码', 'Audio codec', '播放器诊断面板：音频编码')
e('playerDiagnosticsVideoOutput', '视频输出', 'Video output', '播放器诊断面板：视频输出')
e('playerDiagnosticsSyncMode', '同步方式', 'Sync mode', '播放器诊断面板：同步方式')
e('playerDiagnosticsPixelFormat', '像素格式', 'Pixel format', '播放器诊断面板：像素格式')
e('playerDiagnosticsContainerFps', '容器帧率', 'Container frame rate',
  '播放器诊断面板：容器帧率')
e('playerDiagnosticsActualFps', '实际帧率', 'Actual frame rate', '播放器诊断面板：实际帧率')
e('playerDiagnosticsVideoBitrate', '视频码率', 'Video bitrate', '播放器诊断面板：视频码率')
e('playerDiagnosticsAudioParams', '音频参数', 'Audio parameters',
  '播放器诊断面板：音频参数')
e('playerDiagnosticsAudioBitrate', '音频码率', 'Audio bitrate', '播放器诊断面板：音频码率')
e('playerDiagnosticsAvSync', '音画同步', 'A/V sync', '播放器诊断面板：音画同步')
e('playerDiagnosticsCacheGroup', '缓存与丢帧', 'Cache & dropped frames',
  '播放器诊断面板：缓存与丢帧分组')
e('playerDiagnosticsBufferDuration', '缓冲时长', 'Buffer duration',
  '播放器诊断面板：缓冲时长')
e('playerDiagnosticsPlayableDuration', '可播时长', 'Playable duration',
  '播放器诊断面板：可播时长')
e('playerDiagnosticsCacheUsage', '缓存占用', 'Cache usage', '播放器诊断面板：缓存占用')
e('playerDiagnosticsDownlinkRate', '下行速率', 'Downlink rate', '播放器诊断面板：下行速率')
e('playerDiagnosticsDroppedFrames', '丢帧', 'Dropped frames', '播放器诊断面板：丢帧')
e('playerDiagnosticsDecodeDropped', '解码丢帧', 'Decode dropped frames',
  '播放器诊断面板：解码丢帧')
e('playerDiagnosticsDelayedFrames', '延迟帧', 'Delayed frames', '播放器诊断面板：延迟帧')
e('playerDiagnosticsAutoRefreshHint', '每秒自动刷新 · 数据来自 mpv 运行时属性',
  'Refreshes every second · data comes from mpv runtime properties',
  '播放器诊断面板：刷新说明')
e('playerDiagnosticsReadFailed', '无法读取播放器属性（播放器可能未就绪或已卡住）',
  'Cannot read player properties (the player may not be ready or may be stuck)',
  '播放器诊断面板：全部读取失败警告')
e('playerDiagnosticsFailedValue', '读取失败：{keys}（显示的是上一次成功值）',
  'Read failed: {keys} (showing the last successful value)',
  '播放器诊断面板：部分属性读取失败警告', {'keys': 'String'})
e('playerDiagnosticsFailedValueMore', '读取失败：{keys} 等 {count} 项（显示的是上一次成功值）',
  'Read failed: {keys} and {count} items in total (showing the last successful values)',
  '播放器诊断面板：部分属性读取失败警告（其余折成计数）',
  {'keys': 'String', 'count': 'int'})

# ── 片头片尾（player_intro_outro_panel）─────────────────────
e('playerIntroRange', '片头范围', 'Intro range', '播放器片头片尾面板：片头范围')
e('playerOutroRange', '片尾范围', 'Outro range', '播放器片头片尾面板：片尾范围')
e('playerRangeHint', '拖动或输入设置时间，可按需调整上方范围',
  'Drag or type to set the time; adjust the range above as needed',
  '播放器片头片尾面板：范围设置说明')
e('playerSetToCurrentTime', '设为当前时间', 'Set to current time',
  '播放器片头片尾面板：设为当前时间')
e('playerSetToRemainingTime', '设为当前剩余时间', 'Set to current remaining time',
  '播放器片头片尾面板：设为当前剩余时间')
e('playerEnableIntroOutroSkip', '启用跳过片头片尾', 'Enable intro/outro skipping',
  '播放器片头片尾面板：总开关')
e('playerIntroOutroSkipDesc', '通过手动设置秒数来跳过片头片尾',
  'Skip intro/outro by setting the seconds manually',
  '播放器片头片尾面板：总开关说明')

# ── 播放列表 / 播放暂停 / 画质 / 进度恢复 / 倍速（各面板）──────
e('playerNoOtherVideos', '当前文件夹没有其他视频', 'No other videos in this folder',
  '播放器播放列表面板：空态')
e('playerNoQuality', '暂无可用画质', 'No quality available', '播放器画质面板：空态')
e('playerQualitySwitchHint', '切换画质会重开播放并保持进度',
  'Switching quality restarts playback and keeps your progress',
  '播放器画质面板：切换说明')
e('playerResumeIndicator', '已恢复上次播放进度', 'Resumed from your last position',
  '播放器进度恢复胶囊：提示')
e('playerRestartFromBeginning', '重头开始', 'Start over', '播放器进度恢复胶囊：重头开始')
e('playerSpeedPlaying', '正在 {speed} 倍速播放', 'Playing at {speed}x',
  '播放器倍速指示器：当前倍速', {'speed': 'String'})
e('playerSpeedSwipeHint', '左右滑动可临时调节长按倍数',
  'Swipe left or right to adjust the temporary speed',
  '播放器倍速指示器：滑动调节说明')
e('playerSpeedAlreadyInPresets', '该倍速已在预设中', 'This speed is already a preset',
  '播放器倍速面板：重复添加提示')
e('playerSpeedPresetLimit', '{max, plural, other{自定义预设已达上限（{max} 个）}}',
  '{max, plural, =1{Custom presets are limited to 1} other{Custom presets are limited to {max}}}',
  '播放器倍速面板：自定义预设上限提示', {'max': 'int'})
e('playerMyPresets', '我的预设', 'My presets', '播放器倍速面板：我的预设分组')
e('playerPreciseSpeed', '精确调速', 'Precise speed', '播放器倍速面板：精确调速')
e('playerApplyTemporarily', '临时应用', 'Apply temporarily',
  '播放器倍速面板：临时应用按钮')
e('playerAddToPresets', '添加到预设', 'Add to presets', '播放器倍速面板：添加到预设')
e('playerSpeedReset', '归位', 'Reset', '播放器倍速面板：倍速归位（回到 1x）')
e('playerResetPresets', '重置预设', 'Reset presets', '播放器倍速面板：重置预设')
e('playerMode', '模式', 'Mode', '播放器超分面板：模式')
e('playerSuperResolutionQuality', '超分质量', 'Super resolution quality',
  '播放器超分面板：超分质量')
e('playerRememberSuperResolution', '记忆超分模式', 'Remember super resolution mode',
  '播放器超分面板：记忆超分模式开关')
e('playerRememberSuperResolutionDesc', '开启后自动应用上次的超分模式与质量',
  'Automatically apply the last super resolution mode and quality',
  '播放器超分面板：记忆超分模式说明')

# ── 字幕面板（subtitle_panel）───────────────────────────────
e('playerSubtitleTracks', '字幕轨道', 'Subtitle tracks', '播放器字幕面板：字幕轨道分组')
e('playerNoSubtitleHint', '当前视频没有字幕，可在下方导入外挂字幕',
  'This video has no subtitles; you can import an external one below',
  '播放器字幕面板：无字幕空态')
e('playerSubtitleOff', '关闭字幕', 'Turn off subtitles', '播放器字幕面板：关闭字幕')
e('playerExternalSubtitle', '外挂字幕', 'External subtitle', '播放器字幕面板：外挂字幕分组')
e('playerImportExternalSubtitle', '导入外部字幕', 'Import external subtitle',
  '播放器字幕面板：导入外部字幕入口')
e('playerSubtitleSettings', '字幕设置', 'Subtitle settings', '播放器字幕面板：字幕设置分组')
e('playerSubtitleDelay', '字幕延迟', 'Subtitle delay', '播放器字幕面板：字幕延迟入口 / 页标题')
e('playerSubtitleStyle', '字幕样式', 'Subtitle style', '播放器字幕面板：字幕样式入口 / 页标题')
e('playerSubtitleMisc', '字幕杂项', 'Subtitle misc', '播放器字幕面板：字幕杂项入口 / 页标题')
e('playerSubtitleFont', '字幕字体', 'Subtitle font', '播放器字幕面板：字幕字体入口 / 页标题')
e('playerPickSubtitleFile', '选择字幕文件', 'Choose a subtitle file',
  '播放器字幕面板：选择字幕文件')
e('playerExternalSubtitleImported', '已导入外挂字幕', 'External subtitle imported',
  '播放器字幕面板：导入成功提示')
e('playerRemoveSubtitle', '移除已导入的字幕', 'Remove the imported subtitle',
  '播放器字幕面板：移除外部字幕按钮')
e('playerQuickAdjust', '快捷调整', 'Quick adjust', '播放器字幕延迟面板：快捷调整分组')
e('playerResetToZeroSeconds', '重置为 0 秒', 'Reset to 0 s',
  '播放器字幕延迟面板：重置为 0 秒')
e('playerDelaySeconds', '{value} 秒', '{value} s',
  '播放器字幕延迟面板：带正负号的延迟读数', {'value': 'String'})
e('playerTextColor', '文字颜色', 'Text color', '播放器字幕样式面板：文字颜色')
e('playerStrokeColor', '描边颜色', 'Stroke color', '播放器字幕样式面板：描边颜色')
e('playerBackgroundColor', '背景颜色', 'Background color', '播放器字幕样式面板：背景颜色')
e('playerBackgroundBoxSize', '背景框大小', 'Background box size',
  '播放器字幕样式面板：背景框大小')
e('playerTextEffects', '文字效果', 'Text effects', '播放器字幕样式面板：文字效果分组')
e('playerBold', '粗体', 'Bold', '播放器字幕样式面板：粗体')
e('playerItalic', '斜体', 'Italic', '播放器字幕样式面板：斜体')
e('playerLetterSpacing', '字间距', 'Letter spacing', '播放器字幕样式面板：字间距')
e('playerPreferChineseSubtitle', '优先选中文字幕轨', 'Prefer Chinese subtitle tracks',
  '播放器字幕杂项面板：优先选中文字幕轨')
e('playerPreferChineseSubtitleDesc', '默认启用中文轨（含「特效/双语」优先）；手动选过的不改',
  'Enable Chinese tracks by default (signs/songs and bilingual ones take priority); manual picks are kept',
  '播放器字幕杂项面板：优先选中文字幕轨说明')
e('playerSubtitleTrackAutoDesc', '交给内核默认挑选（通常是文件里的第一条）',
  'Let the core pick (usually the first track in the file)',
  '播放器字幕杂项面板：不优先中文时的说明')
e('playerForceOverrideStyle', '强制覆盖内嵌样式', 'Force override embedded styles',
  '播放器字幕杂项面板：强制覆盖内嵌样式')
e('playerForceOverrideStyleDesc', '使用上方设置渲染字幕样式',
  'Render subtitles using the settings above', '播放器字幕杂项面板：覆盖开启说明')
e('playerStyleFromSubtitleDesc', '字幕使用自带的样式与字体',
  "Use the subtitle's own styles and fonts", '播放器字幕杂项面板：覆盖关闭说明')
e('playerResetAllStyles', '重置所有样式', 'Reset all styles',
  '播放器字幕样式面板：重置所有样式')
e('playerAssLimitTitle', 'ASS 内嵌字幕的限制', 'Limitations of embedded ASS subtitles',
  '播放器字幕样式面板：ASS 限制说明标题')
e('playerAssLimitBoldItalicBlur', '粗体 / 斜体 / 模糊', 'Bold / italic / blur',
  '播放器字幕样式面板：ASS 限制项（不生效）')
e('playerAssLimitNoEffect', '开启覆盖也不生效（mpv 渲染限制）',
  'No effect even with override on (mpv rendering limit)',
  '播放器字幕样式面板：ASS 限制项说明')
e('playerAssLimitStyleItems', '颜色 / 描边 / 背景 / 大小 / 位置 / 字间距',
  'Color / stroke / background / size / position / letter spacing',
  '播放器字幕样式面板：ASS 可覆盖项')
e('playerAssLimitTakesEffect', '开启覆盖后生效', 'Takes effect with override on',
  '播放器字幕样式面板：ASS 可覆盖项说明')
e('playerAssLimitTextFormats', 'SRT / VTT 等文本字幕', 'Text subtitles such as SRT / VTT',
  '播放器字幕样式面板：文本字幕')
e('playerAssLimitAllEffective', '所有样式都直接生效', 'All styles apply directly',
  '播放器字幕样式面板：文本字幕说明')
e('playerSubtitleScalePosition', '字幕缩放与位置', 'Subtitle scale & position',
  '播放器字幕样式面板：缩放与位置分组')
e('playerScaleRatio', '缩放比例', 'Scale', '播放器字幕样式面板：缩放比例')
e('playerVerticalPosition', '垂直位置', 'Vertical position',
  '播放器字幕样式面板：垂直位置')
e('playerVerticalPositionValue', '{value}（100=窗口底部）', '{value} (100 = bottom of the window)',
  '播放器字幕样式面板：垂直位置读数', {'value': 'int'})
e('playerResetScalePosition', '重置缩放与位置', 'Reset scale & position',
  '播放器字幕样式面板：重置缩放与位置')
e('playerFontsRefreshed', '已刷新，共 {count, plural, other{{count} 种字体}}',
  'Refreshed, {count, plural, =1{1 typeface} other{{count} typefaces}} in total',
  '播放器字幕字体面板：刷新字体目录提示', {'count': 'int'})
e('playerFontDirCleared', '已清除字体目录', 'Font folder cleared',
  '播放器字幕字体面板：清除字体目录提示')
e('playerFontChangeHint', '字体更改需退出播放器并重新进入后生效',
  'Font changes take effect after leaving and re-entering the player',
  '播放器字幕字体面板：字体更改说明')
e('playerFontDir', '字体目录', 'Font folder', '播放器字幕字体面板：字体目录')
e('playerFontDirPickHint', '点击选择包含 .ttf/.otf 字体的目录',
  'Tap to choose a folder containing .ttf/.otf fonts',
  '播放器字幕字体面板：选择字体目录提示')
e('playerFontDirClear', '清除目录', 'Clear folder', '播放器字幕字体面板：清除目录')
e('playerCurrentFont', '当前字体', 'Current font', '播放器字幕字体面板：当前字体')
e('playerDefaultFont', '默认字体', 'Default font', '播放器字幕字体面板：默认字体')
e('playerPickFontDirFirst', '请先选择字体目录', 'Choose a font folder first',
  '播放器字幕字体面板：未选目录提示')
e('playerFollowSystemFonts', '跟随系统字库', 'Follow system fonts',
  '播放器字幕字体面板：跟随系统字库')
e('playerFontChangeHintFull',
  '字体更改需退出播放器并重新进入后生效；内嵌 ASS 字幕需开启「强制覆盖内嵌样式」后字体设置才会生效。',
  'Font changes take effect after leaving and re-entering the player; for embedded ASS subtitles, '
  'font settings only take effect when "Force override embedded styles" is on.',
  '播放器字幕字体面板：字体更改完整说明')


def merge(path, is_template):
    data = json.loads(open(path, encoding='utf-8').read())
    added, skipped = 0, []
    for key, zh, en, desc, ph in E:
        if key in data:
            skipped.append(key)
            continue
        data[key] = zh if is_template else en
        if is_template:
            meta = {'description': desc}
            if ph:
                meta['placeholders'] = {k: {'type': v} for k, v in ph.items()}
            data['@' + key] = meta
        added += 1
    open(path, 'w', encoding='utf-8', newline='\n').write(
        json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f'{path}: +{added}  skip={skipped}')


keys = [k for k, *_ in E]
dupes = {k for k in keys if keys.count(k) > 1}
if dupes:
    raise SystemExit(f'表内有重复键：{sorted(dupes)}')
print('新增键数：', len(E))
merge(ZH, True)
merge(EN, False)
