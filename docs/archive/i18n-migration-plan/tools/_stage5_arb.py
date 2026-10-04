# -*- coding: utf-8 -*-
"""阶段 5（其余业务页）新增 ARB 键：写入 app_zh.arb / app_en.arb。

- 只新增，不修改已有键；zh 侧带 description，en 侧不带元数据；
- 含占位符的键补 placeholders 元数据；计数文案按方案用 plural 语法；
- ARB 里要显示**字面** {name} 时用 ICU 转义 `'{name}'`（subtitle 两处）；
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


I2 = {'a': 'int', 'b': 'int'}

# ── 通用 ────────────────────────────────────────────────────
e('commonCopy', '复制', 'Copy', '通用按钮：复制（文件操作 / 媒体信息）')
e('commonPaste', '粘贴', 'Paste', '通用按钮：粘贴（打开链接弹窗）')
e('commonUnknown', '未知', 'Unknown', '通用：未知（值缺失时的兜底）')
e('commonSaved', '已保存', 'Saved', '通用：已保存（副标题状态）')
e('commonExpand', '展开', 'Expand', '通用按钮：展开')
e('commonCollapse', '收起', 'Collapse', '通用按钮：收起')
e('commonSelectAll', '全选', 'Select all', '通用：全选（勾选栏）')
e('commonDeselectAll', '取消全选', 'Deselect all', '通用：取消全选')
e('commonTest', '测试', 'Test', '通用按钮：测试')
e('commonTestConnection', '测试连接', 'Test connection', '通用按钮：测试连接（网络账户 / 字幕来源）')
e('commonTesting', '测试中…', 'Testing…', '通用：测试中')
e('commonSaving', '保存中…', 'Saving…', '通用：保存中')
e('commonMove', '移动', 'Move', '通用动作：移动（文件操作菜单）')
e('commonRename', '重命名', 'Rename', '通用动作：重命名')
e('commonResume', '继续', 'Resume', '通用动作：继续（下载任务）')
e('commonOrderAsc', '正序', 'Ascending', '通用：正序（选集顺序）')
e('commonOrderDesc', '倒序', 'Descending', '通用：倒序（选集顺序）')
e('commonSaveFailed', '保存失败', 'Save failed', '通用提示：保存失败')
e('commonSaveFailedWith', '保存失败：{error}', 'Save failed: {error}',
  '通用提示：保存失败（带原因）', {'error': 'String'})
e('commonConnectOk', '连接成功', 'Connected', '通用提示：连接成功')
e('commonConnectFailed', '连接失败：{error}', 'Connection failed: {error}',
  '通用提示：连接失败', {'error': 'String'})
e('commonCancelSearch', '取消搜索', 'Cancel search', '通用：取消搜索（首页 / 目录页 / 网络浏览）')
e('commonClearSearch', '清除搜索', 'Clear search', '通用：清除搜索')

# ── 哔哩哔哩：入口 / 索引 / 搜索 / 详情 / 账号 ────────────────
e('biliIndexTitle', '索引', 'Index', 'B 站页：索引 tab / 入口')
e('biliRecommend', '推荐', 'Recommended', 'B 站索引页：推荐 tab')
e('biliBangumi', '哔哩番剧', 'Bilibili anime', 'B 站入口名 / 首页入口')
e('biliParseLink', '解析链接', 'Parse link', 'B 站索引页：解析链接入口')
e('biliParse', '解析', 'Parse', 'B 站下载页：解析按钮')
e('biliNothingHere', '暂无内容', 'Nothing here yet', 'B 站番剧索引页：空态')
e('biliTimeline', '追番时间表', 'Anime schedule', 'B 站索引页：追番时间表')
e('biliToday', '今天', 'Today', 'B 站追番时间表：今天 tab')
e('biliWeekdayMon', '周一', 'Monday', 'B 站追番时间表：周一')
e('biliWeekdayTue', '周二', 'Tuesday', 'B 站追番时间表：周二')
e('biliWeekdayWed', '周三', 'Wednesday', 'B 站追番时间表：周三')
e('biliWeekdayThu', '周四', 'Thursday', 'B 站追番时间表：周四')
e('biliWeekdayFri', '周五', 'Friday', 'B 站追番时间表：周五')
e('biliWeekdaySat', '周六', 'Saturday', 'B 站追番时间表：周六')
e('biliWeekdaySun', '周日', 'Sunday', 'B 站追番时间表：周日')
e('biliFollowed', '已追番', 'Following', 'B 站剧集卡片角标：已追番')
e('biliLinkUnrecognized', '无法识别该链接（支持 ss/ep/BV/av 号与 b23.tv 短链）',
  'Unrecognized link (ss/ep/BV/av numbers and b23.tv short links are supported)',
  'B 站：链接无法识别')
e('biliParseBangumiLink', '解析番剧链接', 'Parse anime link', 'B 站：解析番剧链接弹窗标题')
e('biliPasteAnimeLinkHint', '粘贴番剧/视频链接或 b23.tv 短链',
  'Paste an anime/video link or a b23.tv short link', 'B 站：解析链接输入提示')
e('biliSearchAnime', '搜索番剧', 'Search anime', 'B 站搜索页标题')
e('biliSearchAnimeHint', '输入关键词搜索番剧', 'Enter keywords to search anime',
  'B 站搜索页输入提示')
e('biliNoAnimeFound', '没有找到相关番剧', 'No anime found', 'B 站搜索页空态')
e('biliSeasonDetail', '番剧详情', 'Anime details', 'B 站番剧详情页标题（兜底）')
e('biliNoEpisodeSelection', '暂无选集', 'No episodes yet', 'B 站番剧详情页：无选集')
e('biliViewAll', '查看全部', 'View all', 'B 站番剧详情页：查看全部')
e('biliSelectEpisode', '选集', 'Episodes', 'B 站：选集')
e('biliRating', '评分 {score}', 'Rating {score}', 'B 站番剧详情页：评分',
  {'score': 'String'})
e('biliCountHundredMillion', '{value}亿', '{value} hundred million',
  'B 站播放量：亿级（value 已按 1e8 折算）', {'value': 'String'})
e('biliCountTenThousand', '{value}万', '{value} ten thousand',
  'B 站播放量：万级（value 已按 1e4 折算）', {'value': 'String'})
e('biliIntro', '简介', 'Synopsis', 'B 站番剧详情页：简介')
e('biliMultiSeason', '多季', 'Seasons', 'B 站番剧详情页：多季')
e('biliEpisodeNo', '第 {number} 话', 'Episode {number}', 'B 站剧集卡片：第 N 话',
  {'number': 'int'})
e('biliVideoFallbackTitle', 'B 站视频', 'Bilibili video',
  'B 站 UGC：拿不到标题时的兜底标题')
e('biliPlayFailed', '播放失败：{error}', 'Playback failed: {error}',
  'B 站：播放失败提示', {'error': 'String'})
e('biliLevel', '等级', 'Level', 'B 站账号页：等级')
e('biliAssets', '资产', 'Assets', 'B 站账号页：资产分组')
e('biliCoins', '硬币', 'Coins', 'B 站账号页：硬币')
e('biliCoinsDesc', '用于投币等操作', 'Used for tipping coins', 'B 站账号页：硬币说明')
e('biliSignOut', '退出登录', 'Sign out', 'B 站账号页：退出登录')
e('biliMaxLevel', '已满级', 'Max level', 'B 站账号页：已满级')
e('biliExpValue', '经验值 {current} / {next}', 'EXP {current} / {next}',
  'B 站账号页：经验值', {'current': 'int', 'next': 'int'})
e('biliSignOutConfirm', '确定退出哔哩哔哩账号吗？', 'Sign out of your Bilibili account?',
  'B 站账号页：退出确认')
e('biliSignOutAction', '退出', 'Sign out', 'B 站账号页：退出确认按钮')
e('biliLoginQrLoading', '正在获取二维码...', 'Getting the QR code...',
  'B 站登录：二维码获取中')
e('biliLoginScanHint', '请使用哔哩哔哩客户端扫码', 'Scan with the Bilibili app',
  'B 站登录：扫码提示')
e('biliLoginQrFailed', '获取二维码失败，请重试', 'Failed to get the QR code. Try again',
  'B 站登录：二维码获取失败')
e('biliLoginQrRefreshing', '二维码已失效，正在刷新...', 'The QR code expired. Refreshing...',
  'B 站登录：二维码失效刷新中')
e('biliLoginScannedConfirm', '已扫码，请在手机上确认', 'Scanned. Please confirm on your phone',
  'B 站登录：已扫码待确认')
e('biliLoginCredentialFailed', '登录凭证获取失败，请重试',
  'Failed to get the sign-in credentials. Try again', 'B 站登录：凭证获取失败')
e('biliLoginSuccess', '登录成功：{nickname}', 'Signed in as {nickname}',
  'B 站登录：成功提示', {'nickname': 'String'})
e('biliLoginFailedRetry', '登录失败，请重试', 'Sign-in failed. Try again',
  'B 站登录：失败提示')
e('biliQrSavedToGallery', '二维码已保存到相册', 'QR code saved to the gallery',
  'B 站登录：二维码保存成功')
e('biliClientNotFound', '未检测到哔哩哔哩客户端', 'The Bilibili app was not found',
  'B 站登录：未装客户端')
e('biliPasteCookieFirst', '请先粘贴 Cookie', 'Paste a cookie first',
  'B 站登录：Cookie 为空提示')
e('biliCookieInvalid', '登录失败：Cookie 无效或已过期',
  'Sign-in failed: the cookie is invalid or has expired', 'B 站登录：Cookie 无效')
e('biliLoginTitle', '哔哩哔哩登录', 'Bilibili sign-in', 'B 站登录页标题')
e('biliLoginQrTab', '扫码登录', 'QR code', 'B 站登录：扫码 tab')
e('biliLoginCookieTab', 'Cookie 登录', 'Cookie', 'B 站登录：Cookie tab')
e('biliLoginRemaining', '剩余有效时间：{seconds} 秒', 'Valid for another {seconds}s',
  'B 站登录：二维码剩余时间', {'seconds': 'int'})
e('biliQrRefresh', '刷新二维码', 'Refresh QR code', 'B 站登录：刷新二维码按钮')
e('biliSaveToGallery', '保存到相册', 'Save to gallery', 'B 站登录：保存二维码按钮')
e('biliOpenApp', '打开哔哩哔哩', 'Open the Bilibili app', 'B 站登录：唤起 App 按钮')
e('biliOpenAppDesc', '「打开哔哩哔哩」会在已安装的哔哩哔哩客户端中自动唤起扫码确认。',
  'The "Open Bilibili" button launches the installed Bilibili app so you can confirm the scan there.',
  'B 站登录：唤起 App 说明')
e('biliCookieLoginDesc', '从浏览器复制 Cookie 粘贴登录（扫码异常时的备用方式）',
  'Copy a cookie from your browser and paste it here (a fallback when QR sign-in fails)',
  'B 站登录：Cookie 登录说明')
e('biliLoggingIn', '登录中...', 'Signing in...', 'B 站登录：登录中')
e('biliCookiePrivacy', 'Cookie 仅本地加密保存，不会上传或记录日志。',
  'The cookie is stored encrypted on this device only; it is never uploaded or logged.',
  'B 站登录：Cookie 隐私说明')
e('downloadSetDirFirst', '请先设置下载目录', 'Choose a download folder first',
  '下载：未设置目录（B 站视频/弹幕/字幕三处共用）')
e('downloadDirGone', '下载目录不存在，请重新选择',
  'The download folder no longer exists; choose it again', '下载：目录失效')
e('biliDanmakuTasksAdded', '{count, plural, other{已添加 {count} 个弹幕下载任务}}',
  '{count, plural, =1{Added 1 danmaku download task} other{Added {count} danmaku download tasks}}',
  'B 站弹幕下载：加入任务提示', {'count': 'int'})
e('biliVideoTasksAdded', '{count, plural, other{已添加 {count} 个视频下载任务}}',
  '{count, plural, =1{Added 1 video download task} other{Added {count} video download tasks}}',
  'B 站视频下载：加入任务提示', {'count': 'int'})
e('biliPasteVideoLinkHint', '粘贴 B 站视频/番剧链接（BV / av / ss / ep / b23.tv）',
  'Paste a Bilibili video/anime link (BV / av / ss / ep / b23.tv)',
  'B 站下载：链接输入提示')
e('biliPasteThenParse', '粘贴链接后点「解析」', 'Paste a link, then tap "Parse"',
  'B 站下载：空态提示')
e('downloadNoDir', '未设置下载目录', 'No download folder', '下载：目录未设置')
e('downloadSetDir', '设置目录', 'Set folder', '下载：设置目录按钮')
e('biliEpisodesSelected', '{count, plural, other{已选 {count} 集}}',
  '{count, plural, =1{1 episode selected} other{{count} episodes selected}}',
  'B 站弹幕下载：已选集数', {'count': 'int'})
e('biliEpisodesSelectedOfTotal', '已选 {selected} / 共 {total, plural, other{{total} 集}}',
  '{selected} of {total, plural, =1{1 episode} other{{total} episodes}} selected',
  'B 站视频下载：已选 / 总数', {'selected': 'int', 'total': 'int'})
e('biliDownloadDanmaku', '下载弹幕（{count}）', 'Download danmaku ({count})',
  'B 站弹幕下载：下载按钮', {'count': 'int'})
e('biliDownloadVideo', '下载视频（{count}）', 'Download video ({count})',
  'B 站视频下载：下载按钮', {'count': 'int'})
e('biliSyncDanmaku', '同步下载弹幕', 'Download danmaku too', 'B 站视频下载：同步弹幕开关')

# ── 字幕 ────────────────────────────────────────────────────
e('subtitleSourceSection', '字幕来源', 'Subtitle source', '字幕下载设置：字幕来源分组')
e('subtitleWyzieDesc', '经 sub.wyzie.io 搜索，需要 API 密钥',
  'Searches via sub.wyzie.io; an API key is required', '字幕来源：Wyzie 说明')
e('subtitleCustomDesc', '自填接口地址，片名会发送到该地址',
  'Use your own endpoint; titles are sent to that address', '字幕来源：自定义说明')
e('subtitleCustomParams', '自定义参数', 'Custom parameters', '字幕来源：自定义参数分组')
e('subtitleWyzieParams', 'Wyzie 参数', 'Wyzie parameters', '字幕来源：Wyzie 参数分组')
e('subtitleWyzieApiKey', 'WYZIE API 密钥', 'WYZIE API key', '字幕来源：密钥项')
e('subtitleWyzieSources', 'Wyzie 来源', 'Wyzie sources', '字幕来源：Wyzie 来源列表')
e('subtitleLanguage', '字幕语言', 'Subtitle language', '字幕下载：字幕语言')
e('subtitlePreferredFormat', '首选格式', 'Preferred format', '字幕下载：首选格式')
e('subtitlePreferredEncoding', '首选编码', 'Preferred encoding', '字幕下载：首选编码')
e('subtitleApiEndpoint', '接口地址', 'Endpoint', '字幕来源：自定义接口地址')
e('subtitleCustomTestHint', '用一个片名试搜一次，看能否解析出字幕',
  'Try one title to see whether subtitles can be found', '字幕来源：测试说明')
e('subtitleTesting', '正在测试…', 'Testing…', '字幕来源：测试中')
e('subtitleTestNoResult', '连接成功，但没解析出字幕', 'Connected, but no subtitles were found',
  '字幕来源：测试成功但无结果')
e('subtitleTestOk', '{count, plural, other{连接成功，解析出 {count} 条字幕}}',
  'Connected; {count, plural, =1{1 subtitle} other{{count} subtitles}} found',
  '字幕来源：测试成功', {'count': 'int'})
e('subtitleTestFailed', '测试失败：{error}', 'Test failed: {error}',
  '字幕来源：测试失败', {'error': 'String'})
e('subtitleAllSources', '全部来源', 'All sources', '字幕来源筛选：全部来源')
e('subtitleAllLanguages', '全部语言', 'All languages', '字幕语言筛选：全部语言')
e('subtitleAllFormats', '全部格式', 'All formats', '字幕格式筛选：全部格式')
e('subtitleAllEncodings', '全部编码', 'All encodings', '字幕编码筛选：全部编码')
e('subtitlePasteKeyHint', '粘贴密钥（wyzie-…）', 'Paste the key (wyzie-…)',
  '字幕来源：密钥输入提示')
e('subtitleHowToGetKey', '如何获取密钥', 'How to get a key', '字幕来源：获取密钥帮助')
e('subtitleKeyType', '密钥类型：{type}', 'Key type: {type}', '字幕来源：密钥类型',
  {'type': 'String'})
e('subtitleKeyInvalid', '密钥无效', 'Invalid key', '字幕来源：密钥无效')
e('subtitleFreeSource', '免费来源', 'Free sources', '字幕来源筛选：免费来源分组')
e('subtitlePaidSource', '付费来源', 'Paid sources', '字幕来源筛选：付费来源分组')
e('subtitleCustomSourceHelp',
  '地址里可用 {placeholder} 作为片名占位（不写占位符则把片名拼到末尾）。\n'
  '搜索时片名会发送到你填写的地址，请自行确认该服务的条款与可用性；'
  '本应用不内置、也不代理任何第三方字幕服务。',
  'You can use {placeholder} in the URL as a title placeholder (without a placeholder the title is '
  'appended to the end).\nTitles are sent to the address you enter, so check that service\'s terms '
  'and availability yourself; this app neither bundles nor proxies any third-party subtitle service.',
  '字幕来源：自定义地址说明。{placeholder} 是语法记号，调用点传字面量 {name}'
  '（ARB 里的裸花括号会被 gen_l10n 当成占位符，ICU 单引号转义不生效 —— 见 06 遗留）',
  {'placeholder': 'String'})
e('subtitlePlaceholderHelp', '用 {placeholder} 占位片名；没有占位符时片名会拼到末尾。',
  'Use {placeholder} as the title placeholder; without it the title is appended to the end.',
  '字幕来源：自定义地址输入说明。{placeholder} 是语法记号，调用点传字面量 {name}',
  {'placeholder': 'String'})
e('subtitleHowToCustomEndpoint', '如何自定义接口地址', 'How to use a custom endpoint',
  '字幕来源：自定义接口帮助')
e('subtitleTestNameHint', '填一个片名（如 你的名字）', 'Enter a title (e.g. Your Name)',
  '字幕来源：测试弹窗输入提示')
e('subtitleTestNameDesc', '用这个片名请求一次，看能否解析出字幕。',
  'Requests once with this title to see whether subtitles can be found.',
  '字幕来源：测试弹窗说明')
e('subtitleSetWyzieKeyFirst', '请先设置 WYZIE API 密钥', 'Set the WYZIE API key first',
  '字幕下载：未设密钥')
e('subtitleSetCustomUrlFirst', '请先设置自定义字幕地址', 'Set the custom subtitle endpoint first',
  '字幕下载：未设自定义地址')
e('subtitleDownloadedCount', '{count, plural, other{已下载 {count} 个字幕}}',
  'Downloaded {count, plural, =1{1 subtitle} other{{count} subtitles}}',
  '字幕下载：全部成功提示', {'count': 'int'})
e('subtitleDownloadResult', '下载完成：成功 {ok}，失败 {fail}',
  'Download finished: {ok} succeeded, {fail} failed', '字幕下载：部分失败提示',
  {'ok': 'int', 'fail': 'int'})
e('subtitleSearchHint', '输入影视名称或 IMDB / TMDB ID',
  'Enter a movie/TV title or an IMDB / TMDB ID', '字幕下载：搜索框提示')
e('subtitleBackToSettings', '返回设置', 'Back to settings', '字幕下载：返回设置')
e('subtitleNoResultHint', '未找到字幕，请换个关键词或调整字幕设置',
  'No subtitles found. Try another keyword or adjust the subtitle settings',
  '字幕下载：无结果提示')
e('subtitleDownloadSettings', '字幕下载设置', 'Subtitle download settings',
  '字幕下载：设置面板标题')
e('subtitleSearchHintShort', '输入关键词后点「确定」搜索字幕',
  'Enter keywords and tap "OK" to search', '字幕下载：空态提示')
e('subtitleResultHeader', '{query} · {count, plural, other{{count} 条}}',
  '{query} · {count, plural, =1{1 result} other{{count} results}}',
  '字幕下载：结果头（关键词 + 条数）', {'query': 'String', 'count': 'int'})
e('subtitleSearchAgain', '重新搜索', 'Search again', '字幕下载：重新搜索')
e('subtitleSelectedOfTotal', '已选 {selected} / {total, plural, other{{total} 条}}',
  '{selected} of {total, plural, =1{1 result} other{{total} results}} selected',
  '字幕下载：已选 / 总数', {'selected': 'int', 'total': 'int'})
e('subtitleUnknownSource', '未知来源', 'Unknown source', '字幕下载：来源未知')
e('subtitleDownloadingNow', '下载中…', 'Downloading…', '字幕下载：下载中')
e('subtitleDownloadButton', '下载字幕（{count}）', 'Download subtitles ({count})',
  '字幕下载：下载按钮', {'count': 'int'})

# ── 媒体信息 ────────────────────────────────────────────────
e('mediaInfoItem', '媒体信息', 'Media info', '视频卡片菜单：媒体信息')
e('mediaInfoCopied', '媒体信息已复制', 'Media info copied', '媒体信息页：复制成功')
e('mediaInfoTitleWithName', '媒体信息 - {title}', 'Media info - {title}',
  '媒体信息页标题（带文件名）', {'title': 'String'})
e('mediaInfoGeneralHeader', '【通用信息】', '[General]', '媒体信息页：通用信息大标题')
e('mediaInfoVideoStreams', '视频流', 'Video streams', '媒体信息页：视频流分组')
e('mediaInfoAudioStreams', '音频流', 'Audio streams', '媒体信息页：音频流分组')
e('mediaInfoSubtitleStreams', '字幕流', 'Subtitle streams', '媒体信息页：字幕流分组')
e('mediaInfoFetchFailed', '媒体信息获取失败', 'Failed to load media info',
  '媒体信息页：获取失败')
e('mediaInfoGeneral', '通用信息', 'General', '媒体信息页：通用信息分组')
e('mediaInfoFormat', '格式', 'Format', '媒体信息字段：格式')
e('mediaInfoFormatVersion', '格式版本', 'Format version', '媒体信息字段：格式版本')
e('mediaInfoFileSize', '文件大小', 'File size', '媒体信息字段：文件大小')
e('mediaInfoOverallBitrate', '总比特率', 'Overall bitrate', '媒体信息字段：总比特率')
e('mediaInfoEncodedDate', '编码日期', 'Encoded date', '媒体信息字段：编码日期')
e('mediaInfoWritingApp', '编码应用', 'Writing application', '媒体信息字段：编码应用')
e('mediaInfoWritingLibrary', '编码库', 'Writing library', '媒体信息字段：编码库')
e('mediaInfoVideoStreamNo', '视频流 #{index}', 'Video stream #{index}',
  '媒体信息字段：第 N 条视频流', {'index': 'int'})
e('mediaInfoAudioStreamNo', '音频流 #{index}', 'Audio stream #{index}',
  '媒体信息字段：第 N 条音频流', {'index': 'int'})
e('mediaInfoSubtitleStreamNo', '字幕流 #{index}', 'Subtitle stream #{index}',
  '媒体信息字段：第 N 条字幕流', {'index': 'int'})
e('mediaInfoNoInfo', '未获取到媒体信息', 'No media info available', '媒体信息页：空态')
e('mediaInfoCodec', '编码', 'Codec', '媒体信息字段：编码')
e('mediaInfoProfile', '配置', 'Profile', '媒体信息字段：配置')
e('mediaInfoCodecId', '编码ID', 'Codec ID', '媒体信息字段：编码 ID')
e('mediaInfoWidth', '宽', 'Width', '媒体信息字段：宽')
e('mediaInfoHeight', '高', 'Height', '媒体信息字段：高')
e('mediaInfoAspectRatio', '宽高比', 'Aspect ratio', '媒体信息字段：宽高比')
e('mediaInfoFrameRateMode', '帧率模式', 'Frame rate mode', '媒体信息字段：帧率模式')
e('mediaInfoBitrate', '比特率', 'Bitrate', '媒体信息字段：比特率')
e('mediaInfoBitDepth', '位深度', 'Bit depth', '媒体信息字段：位深度')
e('mediaInfoColorSpace', '色彩空间', 'Color space', '媒体信息字段：色彩空间')
e('mediaInfoChromaSubsampling', '色度子采样', 'Chroma subsampling',
  '媒体信息字段：色度子采样')
e('mediaInfoHdrFormat', 'HDR格式', 'HDR format', '媒体信息字段：HDR 格式')
e('mediaInfoChannels', '声道', 'Channels', '媒体信息字段：声道')
e('mediaInfoStreamSize', '流大小', 'Stream size', '媒体信息字段：流大小')
e('mediaInfoStream', '流', 'Stream', '媒体信息页：流选项卡')

# ── 网络存储 / 账户 ─────────────────────────────────────────
e('networkStorageTitle', '网络存储', 'Network storage', '网络存储页标题 / 首页入口')
e('networkHostInputRequired', '请先填写主机地址', 'Enter the host address first',
  '账户编辑：主机为空')
e('networkPortInvalid', '端口需为 1-65535', 'The port must be 1-65535',
  '账户编辑：端口非法')
e('networkDefaultPortWithSynology', '默认 {port}（群晖 5005/5006）',
  'Default {port} (Synology 5005/5006)', '账户编辑：默认端口提示（SMB）',
  {'port': 'String'})
e('networkDefaultPort', '默认 {port}', 'Default {port}', '账户编辑：默认端口提示',
  {'port': 'String'})
e('networkEditAccount', '编辑账户', 'Edit account', '账户编辑页：标题')
e('networkAddAccount', '添加账户', 'Add account', '账户编辑页 / 网络存储页：添加账户')
e('networkDisplayName', '显示名称', 'Display name', '账户编辑：显示名称')
e('networkDisplayNameHint', '例如：家庭 NAS', 'e.g. Home NAS', '账户编辑：名称提示')
e('networkNameRequired', '请输入名称', 'Enter a name', '账户编辑：名称为空')
e('networkProtocolLabel', '协议', 'Protocol', '账户编辑：协议')
e('networkHostLabel', '主机地址', 'Host', '账户编辑：主机地址')
e('networkHostHint', 'IP 或域名', 'IP or domain', '账户编辑：主机提示')
e('networkHostRequiredInput', '请输入主机地址', 'Enter the host address',
  '账户编辑：主机为空提示')
e('networkPortLabel', '端口', 'Port', '账户编辑：端口')
e('networkPathDefaultHint', '默认为 /', 'Defaults to /', '账户编辑：路径提示')
e('networkAnonymous', '匿名登录', 'Anonymous', '账户编辑：匿名登录')
e('networkAnonymousDesc', 'FTP / SMB 匿名访问时开启', 'Enable for anonymous FTP / SMB access',
  '账户编辑：匿名登录说明')
e('networkUseHttps', '使用 HTTPS', 'Use HTTPS', '账户编辑：使用 HTTPS')
e('networkUseHttpsDesc', '启用后使用加密连接（默认端口 443）',
  'Use an encrypted connection (default port 443)', '账户编辑：HTTPS 说明')
e('networkUsername', '账号', 'Username', '账户编辑：账号')
e('networkPassword', '密码', 'Password', '账户编辑：密码')
e('networkHidePassword', '隐藏密码', 'Hide password', '账户编辑：隐藏密码')
e('networkShowPassword', '显示密码', 'Show password', '账户编辑：显示密码')
e('networkSortByBoth', '按{field}{order}', '{field} {order}',
  '网络浏览：排序胶囊标题（字段 + 方向拼成一句，英文靠空格）',
  {'field': 'String', 'order': 'String'})
e('networkSearchCurrentDir', '搜索本目录', 'Search this folder', '网络浏览：搜索入口')
e('networkRefreshCurrentDir', '刷新本目录', 'Refresh this folder', '网络浏览：刷新')
e('networkBackToRoot', '回到共享根目录', 'Back to the share root', '网络浏览：回到根目录')
e('networkShowHiddenFiles', '显示隐藏文件', 'Show hidden files', '网络浏览：显示隐藏文件')
e('networkNoMatchingFiles', '没有匹配的文件', 'No matching files', '网络浏览：无匹配')
e('networkDirEmpty', '该目录为空', 'This folder is empty', '网络浏览：空目录')
e('networkOnlyHiddenFiles', '本目录只有隐藏文件', 'Only hidden files here',
  '网络浏览：只有隐藏文件')
e('networkBackUp', '返回上一级', 'Go up one level', '网络浏览：返回上一级')
e('networkModifiedTime', '修改时间', 'Modified', '网络浏览：修改时间')
e('networkServerNotProvided', '服务器未提供', 'Not provided by the server',
  '网络浏览：字段缺失')
e('networkLocation', '位置', 'Location', '网络浏览：位置')
e('networkConnectionLabel', '连接', 'Connection', '网络浏览：连接')
e('networkDeleteAccount', '删除账户', 'Delete account', '网络存储：删除账户')
e('networkNoAccounts', '还没有网络存储账户', 'No network storage accounts yet',
  '网络存储：空态')
e('networkNoAccountsHint', '点击右下角 + 添加 WebDAV / SMB / FTP 账户',
  'Tap + in the bottom right to add a WebDAV / SMB / FTP account', '网络存储：空态说明')

# ── 首页 / 目录页 ───────────────────────────────────────────
e('homeSearchVideos', '搜索视频', 'Search videos', '文件夹详情页：搜索视频')
e('homeSearchFoldersAndVideos', '搜索文件夹与视频', 'Search folders and videos',
  '首页 / 目录页：搜索提示')
e('homeSortAndFields', '排序与字段', 'Sort & fields', '排序与字段弹窗标题')
e('homeSortAndView', '排序与视图', 'Sort & view', '首页：排序与视图入口')
e('homeNoVideosInFolder', '该文件夹没有视频', 'No videos in this folder', '文件夹空态')
e('homeNoMatchingVideos', '没有匹配的视频', 'No matching videos', '文件夹详情：无匹配视频')
e('homeNoMatchingContent', '没有匹配的内容', 'No matching content', '首页 / 目录页：无匹配')
e('homeNoMatchingFolders', '没有匹配的文件夹', 'No matching folders', '首页：无匹配文件夹')
e('homeRecentPlayed', '最近播放', 'Recently played', '首页：最近播放入口')
e('homeOpenLink', '打开链接', 'Open link', '首页 / 弹窗：打开链接')
e('homeFileGone', '文件不存在或已被移动：{title}', 'The file no longer exists or was moved: {title}',
  '首页：文件缺失提示', {'title': 'String'})
e('homePermissionHintInSettings', '请在系统设置中手动开启存储权限',
  'Enable the storage permission in system settings', '首页：权限提示')
e('homePermissionDeniedDetail', '存储权限已被拒绝，需要到系统设置里手动开启',
  'Storage permission was denied. Enable it in system settings', '首页：权限被拒说明')
e('homePermissionNeeded', '需要授予存储权限才能扫描视频',
  'Storage permission is required to scan videos', '首页：权限说明')
e('homeOpenSettings', '去系统设置开启', 'Open settings', '首页：去设置按钮')
e('homeGrantPermission', '授予权限', 'Grant permission', '首页：授予权限按钮')
e('homeNoVideosFound', '没有找到视频', 'No videos found', '首页：无视频')
e('homeRescan', '重新扫描', 'Rescan', '首页：重新扫描')
e('homeRecheckPermission', '我已开启，重新检查', "I've enabled it — check again",
  '首页：重新检查权限')
e('openLinkClipboardEmpty', '剪贴板为空', 'The clipboard is empty', '打开链接：剪贴板空')
e('openLinkInvalid', '链接无效，支持 http/https/rtmp/rtsp 等流媒体协议',
  'Invalid link. http/https/rtmp/rtsp streaming URLs are supported', '打开链接：链接非法')
e('openLinkHint', '输入视频直链，将在线播放', 'Enter a direct video URL to play it online',
  '打开链接：输入提示')

# ── 下载管理 ────────────────────────────────────────────────
e('downloadClearFinished', '清除已完成', 'Clear finished', '下载管理：清除已完成')
e('downloadClearFinishedDesc', '只清除已完成和失败的下载记录，不会删除已下载的文件。',
  'Removes finished and failed records only; downloaded files are kept.',
  '下载管理：清除已完成说明')
e('downloadNoTasks', '暂无下载任务', 'No download tasks', '下载管理：空态')
e('downloadFailed', '下载失败', 'Download failed', '下载管理：失败兜底文案')
e('downloadStatusCompleted', '完成', 'Completed', '下载状态：完成')
e('downloadStatusFailed', '失败', 'Failed', '下载状态：失败')
e('downloadStatusMerging', '合并', 'Merging', '下载状态：合并中')
e('downloadStatusDownloading', '下载中', 'Downloading', '下载状态：下载中')
e('downloadStatusPending', '等待', 'Pending', '下载状态：等待')
e('downloadMergingCannotPause', '合并中，无法暂停', 'Merging — cannot pause',
  '下载管理：合并中不可暂停')

# ── 投屏 / 组件 ─────────────────────────────────────────────
e('castSearchStartFailed', '投屏搜索启动失败：{error}', 'Failed to start the cast search: {error}',
  '投屏：搜索启动失败', {'error': 'String'})
e('castConnected', '已投屏到 {device}', 'Casting to {device}', '投屏：已投屏',
  {'device': 'String'})
e('castFailed', '投屏失败：{error}', 'Casting failed: {error}', '投屏：失败',
  {'error': 'String'})
e('castSearching', '正在搜索投屏设备…', 'Searching for cast devices…', '投屏：搜索中')
e('castNoDevicesFound', '未发现可投屏设备，请确认手机与电视连接同一 WiFi 后重试。',
  'No cast devices found. Make sure your phone and TV are on the same Wi-Fi and try again.',
  '投屏：未发现设备')
e('colorEditorCustom', '自定义调色', 'Custom color', '调色组件：展开自定义调色')
e('colorEditorCollapseCustom', '收起自定义调色', 'Collapse custom color',
  '调色组件：收起自定义调色')
e('directoryPickerUnreadable', '目录不可读或不存在', 'The folder is unreadable or does not exist',
  '目录选择器：目录不可读')
e('directoryPickerTitle', '选择下载目录', 'Choose a download folder', '目录选择器：标题')
e('directoryPickerUp', '上级目录', 'Parent folder', '目录选择器：上级目录')
e('directoryPickerSelectThis', '选择此目录', 'Choose this folder', '目录选择器：确认按钮')
e('directoryPickerEmpty', '该目录下没有子目录', 'No subfolders here', '目录选择器：空态')
e('fileOpPin', '固定', 'Pin', '文件操作菜单：固定')
e('fileOpUnpin', '取消固定', 'Unpin', '文件操作菜单：取消固定')
e('fileOpMultiSelect', '多选', 'Select multiple', '文件操作菜单：多选')
e('fileOpNewName', '新名称', 'New name', '重命名弹窗：名称标签')
e('fileOpNameHint', '扩展名之前的名称', 'Name without the extension', '重命名弹窗：提示')
e('fileOpLockedExt', '扩展名固定为 {ext}，不可修改',
  'The extension is fixed to {ext} and cannot be changed', '重命名弹窗：扩展名锁定说明',
  {'ext': 'String'})
e('fileOpDeleteFolderVideosOnly', '仅删除该文件夹内的视频文件，其它文件不会被删除。',
  'Only video files inside this folder are deleted; other files are kept.',
  '删除确认：文件夹默认语义')
e('fileOpDeleteSelectedVideos',
  '{count, plural, other{确定删除选中的 {count} 个视频吗？}}',
  'Delete the {count, plural, =1{selected video} other{{count} selected videos}}?',
  '删除确认：多选纯视频', {'count': 'int'})
e('fileOpDeleteSelectedMixed',
  '{count, plural, other{将删除选中的 {count} 项：文件夹只删除里面的视频文件，其它文件不会被删除。}}',
  'This will delete {count, plural, =1{1 selected item} other{{count} selected items}}: for '
  'folders only the videos inside are removed, other files are kept.',
  '删除确认：多选含文件夹', {'count': 'int'})
e('fileOpDeleteAllFiles', '删除所有文件', 'Delete all files', '删除确认：删除所有文件勾选')
e('fileOpPreparing', '准备中…', 'Preparing…', '传输进度：准备中')
e('fileOpProgressItem', '第 {current}/{total} 项', 'Item {current}/{total}',
  '传输进度：整批第几项', {'current': 'int', 'total': 'int'})
e('fileOpProgressItems', '{done} / {total, plural, other{{total} 项}}',
  '{done} / {total, plural, =1{1 item} other{{total} items}}',
  '传输进度：单项计数', {'done': 'int', 'total': 'int'})
e('fileOpProcessing', '处理中…', 'Processing…', '传输进度：处理中')
e('fileOpBytesProgress', '{done} / {total}（{percent}%）', '{done} / {total} ({percent}%)',
  '传输进度：字节进度（含百分比）',
  {'done': 'String', 'total': 'String', 'percent': 'String'})
e('fileSelectionExit', '退出多选', 'Exit selection', '多选工具栏：退出多选')
e('fileSelectionSelected', '{count, plural, other{已选 {count} 项}}',
  '{count, plural, =1{1 selected} other{{count} selected}}',
  '多选工具栏：已选数量', {'count': 'int'})
e('fileSelectionOps', '文件操作', 'File actions', '多选工具栏：文件操作菜单')
e('folderTransferMoving', '正在移动…', 'Moving…', '文件操作进度：正在移动')
e('folderTransferCopying', '正在复制…', 'Copying…', '文件操作进度：正在复制')
e('folderActionCancelled', '已取消', 'Cancelled', '文件操作：已取消')
e('folderMovedTo', '已移动「{title}」到 {dest}', 'Moved "{title}" to {dest}',
  '文件操作：移动成功', {'title': 'String', 'dest': 'String'})
e('folderCopiedTo', '已复制「{title}」到 {dest}', 'Copied "{title}" to {dest}',
  '文件操作：复制成功', {'title': 'String', 'dest': 'String'})
e('folderActionMovedProgressFailed',
  '已移动 {done}/{total, plural, other{{total} 项}}，失败：{failures}',
  'Moved {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures}',
  '文件操作：批量移动（含失败项）', {'done': 'int', 'total': 'int', 'failures': 'String'})
e('folderActionCopiedProgressFailed',
  '已复制 {done}/{total, plural, other{{total} 项}}，失败：{failures}',
  'Copied {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures}',
  '文件操作：批量复制（含失败项）', {'done': 'int', 'total': 'int', 'failures': 'String'})
e('folderActionDeletedProgressFailed',
  '已删除 {done}/{total, plural, other{{total} 项}}，失败：{failures}',
  'Deleted {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures}',
  '文件操作：批量删除（含失败项）', {'done': 'int', 'total': 'int', 'failures': 'String'})
e('folderActionMovedProgressFailedMore',
  '已移动 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项',
  'Moved {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures} and {count} in total',
  '文件操作：批量移动（失败项过多只列前 3）',
  {'done': 'int', 'total': 'int', 'failures': 'String', 'count': 'int'})
e('folderActionCopiedProgressFailedMore',
  '已复制 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项',
  'Copied {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures} and {count} in total',
  '文件操作：批量复制（失败项过多只列前 3）',
  {'done': 'int', 'total': 'int', 'failures': 'String', 'count': 'int'})
e('folderActionDeletedProgressFailedMore',
  '已删除 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项',
  'Deleted {done}/{total, plural, =1{1 item} other{{total} items}}, failed: {failures} and {count} in total',
  '文件操作：批量删除（失败项过多只列前 3）',
  {'done': 'int', 'total': 'int', 'failures': 'String', 'count': 'int'})
e('folderActionCancelledThenMoved', '已取消（已移动 {done, plural, other{{done} 项}}）',
  'Cancelled (moved {done, plural, =1{1 item} other{{done} items}})',
  '文件操作：取消但已移动部分', {'done': 'int'})
e('folderActionCancelledThenCopied', '已取消（已复制 {done, plural, other{{done} 项}}）',
  'Cancelled (copied {done, plural, =1{1 item} other{{done} items}})',
  '文件操作：取消但已复制部分', {'done': 'int'})
e('folderActionMovedCount', '已移动 {done, plural, other{{done} 项}}到 {dest}',
  'Moved {done, plural, =1{1 item} other{{done} items}} to {dest}',
  '文件操作：批量移动完成', {'done': 'int', 'dest': 'String'})
e('folderActionCopiedCount', '已复制 {done, plural, other{{done} 项}}到 {dest}',
  'Copied {done, plural, =1{1 item} other{{done} items}} to {dest}',
  '文件操作：批量复制完成', {'done': 'int', 'dest': 'String'})
e('folderNameUnchanged', '名称没有变化', 'The name is unchanged', '文件操作：重命名无变化')
e('folderRenamedTo', '已重命名为 {newName}', 'Renamed to {newName}', '文件操作：重命名成功',
  {'newName': 'String'})
e('folderDeletedOne', '已删除「{title}」', 'Deleted "{title}"', '文件操作：删除单项',
  {'title': 'String'})
e('folderDeletedCount', '已删除 {done, plural, other{{done} 项}}',
  'Deleted {done, plural, =1{1 item} other{{done} items}}', '文件操作：批量删除完成',
  {'done': 'int'})
e('folderVideoCount', '{count, plural, other{{count} 个视频}}',
  '{count, plural, =1{1 video} other{{count} videos}}', '文件夹卡片：视频个数',
  {'count': 'int'})
e('optionsSheetFolderSort', '文件夹排序方式', 'Folder sort by', '排序与字段：文件夹排序方式')
e('optionsSheetFolderSortDir', '文件夹排序方向', 'Folder sort order', '排序与字段：文件夹排序方向')
e('optionsSheetFolderFields', '文件夹显示字段', 'Folder fields', '排序与字段：文件夹显示字段')
e('optionsSheetVideoSort', '视频排序方式', 'Video sort by', '排序与字段：视频排序方式')
e('optionsSheetVideoSortDir', '视频排序方向', 'Video sort order', '排序与字段：视频排序方向')
e('optionsSheetVideoFields', '视频显示字段', 'Video fields', '排序与字段：视频显示字段')
e('optionsSheetViewMode', '显示模式', 'View mode', '排序与字段：显示模式')
e('updatePrimarySource', '主下载站', 'Primary download site', '更新弹窗：主下载站')
e('updateBackupSource', '备用下载站', 'Backup download site', '更新弹窗：备用下载站')
e('updateLinkPending', '{label}链接待接入', 'The {label} link is not available yet',
  '更新弹窗：下载链接待接入', {'label': 'String'})
e('updateOpenLinkFailed', '无法打开{label}链接', 'Cannot open the {label} link',
  '更新弹窗：链接打不开', {'label': 'String'})
e('updateNewVersion', '发现新版本 {version}', 'New version {version} available',
  '更新弹窗：发现新版本', {'version': 'String'})
e('updateIgnore', '忽略', 'Ignore', '更新弹窗：忽略本版本')
e('updateLater', '稍后提醒', 'Remind me later', '更新弹窗：稍后提醒')
e('updateNow', '立即更新', 'Update now', '更新弹窗：立即更新')
e('updateChooseMethod', '选择下载方式', 'Choose a download method', '更新弹窗：选择下载方式')
e('updatePending', '待接入', 'Not available yet', '更新弹窗：下载方式待接入')
e('videoCardWatched', '已看完', 'Watched', '视频卡片：已看完')
e('videoCardUnwatched', '未观看', 'Unwatched', '视频卡片：未观看')
e('videoCardDetectingSubtitle', '字幕检测中…', 'Checking subtitles…', '视频卡片：字幕检测中')
e('videoCardHasSubtitle', '含字幕', 'Has subtitles', '视频卡片：含字幕')
e('videoCardSubtitleCodec', '字幕 · {codec}', 'Subtitle · {codec}', '视频卡片：字幕格式',
  {'codec': 'String'})
e('videoCardNoSubtitle', '无字幕', 'No subtitles', '视频卡片：无字幕')
e('biliCoverUnavailable', '哔哩封面不可用（缓存未命中且下载失败）',
  'Bilibili cover unavailable (cache miss and download failed)', 'B 站封面图兜底提示')


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
