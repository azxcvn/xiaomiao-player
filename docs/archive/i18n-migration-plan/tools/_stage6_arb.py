# -*- coding: utf-8 -*-
"""阶段 6（服务/模型/工具层）新增 ARB 键：写入 app_zh.arb / app_en.arb。

- 只新增（另 patch 一个既有键 settingsCacheClearAllBody），不删除既有键；
- zh 侧带 description，en 侧不带元数据；
- 含占位符的键补 placeholders 元数据；
- zh 文案**逐字**取自原代码字面量（唯一例外：bili_http「响应解析失败」的
  ASCII 冒号统一成全角，见 06-遗留）；
- 运行后必须 `flutter gen-l10n`。

配套：阶段 6 的「码 + 参数 → ARB 键」对照见 tools/_stage6_codes.md。
"""
import json
import io
import sys

ZH = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
EN = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'

E = []


def e(key, zh, en, desc, ph=None):
    E.append((key, zh, en, desc, ph))


# ── 通用错误（多模块共用） ──────────────────────────────────
e('errorNetworkRequestFailed', '网络请求失败: {error}', 'Network request failed: {error}',
  '错误：网络请求异常（bili / 弹弹Play / Wyzie / 自定义字幕共用）', {'error': 'String'})
e('errorHttpRequestFailed', '请求失败（HTTP {status}）', 'Request failed (HTTP {status})',
  '错误：HTTP 非 2xx（bili / 弹弹Play / Wyzie / 下载共用）', {'status': 'String'})
e('errorHttpSearchFailed', '搜索失败（HTTP {status}）', 'Search failed (HTTP {status})',
  '错误：搜索接口 HTTP 非 2xx（Wyzie / 自定义字幕）', {'status': 'String'})
e('errorHttpDownloadFailed', '下载失败（HTTP {status}）', 'Download failed (HTTP {status})',
  '错误：下载 HTTP 非 2xx（Wyzie / 自定义字幕 / WebDAV / 下载任务）', {'status': 'String'})
e('errorResponseNotJson', '响应不是 JSON 对象', 'The response is not a JSON object',
  '错误：响应不是 JSON 对象')
e('errorResponseParseFailed', '响应解析失败：{error}', 'Failed to parse the response: {error}',
  '错误：响应解析异常（bili / 弹弹Play）', {'error': 'String'})
e('errorResponseDecodeFailed', '响应解码失败：{error}', 'Failed to decode the response: {error}',
  '错误：响应解码异常（弹弹Play）', {'error': 'String'})
e('errorDownloadFailed', '下载失败: {error}', 'Download failed: {error}',
  '错误：下载异常（Wyzie / 自定义字幕）', {'error': 'String'})
e('errorDownloadTooLarge', '下载失败：文件过大（{received} 字节）',
  'Download failed: the file is too large ({received} bytes)',
  '错误：下载体积超上限（Wyzie / 自定义字幕）', {'received': 'String'})
e('errorResponseTooLarge', '响应异常（已读 {received} 字节，超过 {max} 上限）',
  'Unexpected response (read {received} bytes, exceeding the {max} limit)',
  '错误：响应体积超上限（Wyzie / 自定义字幕）', {'received': 'String', 'max': 'String'})
e('errorResponseTooLargeAborted', '响应过大（{received} 字节），已放弃解析',
  'The response is too large ({received} bytes); parsing aborted',
  '错误：响应过大已放弃解析（弹弹Play / Wyzie）', {'received': 'String'})
e('errorServerReturned', '服务器返回错误', 'The server returned an error',
  '错误：服务端返回失败（弹弹Play / bili）')
e('errorServerReturnedCode', '服务器返回错误（code={code}）',
  'The server returned an error (code={code})',
  '错误：服务端返回失败（带业务 code；bili / 弹弹Play）', {'code': 'String'})
e('errorUnknown', '未知错误', 'Unknown error', '错误：兜底未知错误')
e('errorNetworkConnectionMissing', '网络连接不存在', 'The network connection does not exist',
  '错误：网络连接缺失（播放列表源 / 网络字幕流）')

# ── 哔哩哔哩 ────────────────────────────────────────────────
e('biliWbiKeyMissingPlay', '未获取到 WBI 密钥，无法解析播放地址',
  'Could not obtain the WBI key; unable to resolve the playback URL',
  'B 站错误：缺少 WBI 密钥（播放地址）')
e('biliWbiKeyMissingSearch', '未获取到 WBI 密钥，无法搜索',
  'Could not obtain the WBI key; unable to search',
  'B 站错误：缺少 WBI 密钥（搜索）')
e('biliRiskControlTriggered', '触发风控验证（v_voucher），请稍后重试或切换网络',
  'Risk-control verification triggered (v_voucher); try again later or switch networks',
  'B 站错误：触发风控验证')
e('biliVideoNotFound', '视频不存在或无权访问', 'The video does not exist or access is denied',
  'B 站错误：视频不存在（code -404）')
e('biliVideoNoAccess', '无权访问，可能需要登录或大会员',
  'Access denied; signing in or a premium membership may be required',
  'B 站错误：无权访问（code -403）')
e('biliVideoVipRequired', '需要大会员权限', 'A premium membership is required',
  'B 站错误：需要大会员（code -10403）')
e('biliVideoRiskControlFailed', '风控验证失败，请稍后重试',
  'Risk-control verification failed; try again later',
  'B 站错误：风控验证失败（code -352）')
e('biliVideoExclusive', '专属视频，需开通相应权限',
  'This is an exclusive video; the corresponding access is required',
  'B 站错误：专属视频（code 87008）')
e('biliDownloadLinkUnrecognized', '无法识别 B 站链接（支持 BV / av / ss / ep / 合集链接 / b23.tv 短链）',
  'Unrecognized Bilibili link (BV / av / ss / ep / collection links and b23.tv short links are supported)',
  'B 站下载：链接无法识别')
e('biliDownloadNoVideoParts', '未解析到视频分 P', 'No video parts were resolved',
  'B 站下载：没有分 P')
e('biliDownloadBangumiNoEpisodes', '该番剧没有可下载的集数',
  'This anime has no downloadable episodes', 'B 站下载：番剧无集数')
e('biliDownloadCollectionNoVideos', '该合集没有可下载的视频',
  'This collection has no downloadable videos', 'B 站下载：合集无可下载视频')
e('biliDownloadCollectionEmpty', '该合集暂无内容', 'This collection is empty',
  'B 站下载：合集暂无内容')
e('biliDownloadNoDanmaku', '该集没有弹幕', 'This episode has no danmaku',
  'B 站下载：该集无弹幕')
e('biliDownloadNoVideoStream', '未获取到视频流', 'No video stream was obtained',
  'B 站下载：未取到视频流')
e('biliDownloadMergeFailed', '音视频合并失败', 'Failed to merge audio and video',
  'B 站下载：音视频合并失败')
e('biliDownloadNetworkFailed', '网络请求失败', 'Network request failed',
  'B 站下载：网络请求失败（无详情）')
e('biliDownloadWriteFailed', '写入文件失败（磁盘空间或权限）',
  'Failed to write the file (disk space or permissions)',
  'B 站下载：写盘失败')
e('biliDownloadWriteFailedDetail', '写入文件失败（磁盘空间或权限）：{error}',
  'Failed to write the file (disk space or permissions): {error}',
  'B 站下载：写盘失败（带异常详情）', {'error': 'String'})

# ── 在线字幕（Wyzie / 自定义地址） ──────────────────────────
e('wyzieSearchNoSubtitles', '搜索失败（HTTP 400）', 'Search failed (HTTP 400)',
  'Wyzie：HTTP 400（接口判定为无结果）')
e('wyzieNoMatch', '未找到匹配的影视，请换个关键词',
  'No matching title found; try another keyword', 'Wyzie：没有匹配的影视')
e('customSubtitleUrlInvalid', '自定义字幕地址无效（需要 http/https 地址）',
  'Invalid custom subtitle address (an http/https address is required)',
  '自定义字幕：接口地址无效')
e('customSubtitleResponseUnparsable', '无法解析该地址的响应：{message}',
  'Could not parse the response from this address: {message}',
  '自定义字幕：响应无法解析（内嵌解析失败原因）', {'message': 'String'})
e('customSubtitleResponseNotJson', '响应不是合法 JSON', 'The response is not valid JSON',
  '自定义字幕解析：不是合法 JSON')
e('customSubtitleResponseNoList', '响应里找不到字幕列表',
  'No subtitle list was found in the response', '自定义字幕解析：没有字幕列表')

# ── 弹弹Play ────────────────────────────────────────────────
e('dandanServerUrlInvalid', '服务器地址无效（需以 http/https 开头）: {url}',
  'Invalid server address (must start with http/https): {url}',
  '弹弹Play：自建服务器地址无效', {'url': 'String'})

# ── 网络客户端（FTP / WebDAV / SMB） ────────────────────────
e('networkConnectTimeout', '连接超时：服务器无响应，请检查地址与端口',
  'Connection timed out: the server did not respond; check the address and port',
  '网络错误：连接超时（FTP / WebDAV 共用）')
e('ftpRefusedConnection', 'FTP 服务器拒绝连接（代码 {code}）',
  'The FTP server refused the connection (code {code})',
  'FTP 错误：拒绝连接', {'code': 'String'})
e('ftpResumeUnsupported', 'FTP 服务器不支持断点续传（REST）',
  'The FTP server does not support resuming downloads (REST)',
  'FTP 错误：不支持断点续传')
e('ftpTransferRejected', 'FTP 服务器拒绝文件传输（代码 {code}）',
  'The FTP server rejected the file transfer (code {code})',
  'FTP 错误：拒绝文件传输', {'code': 'String'})
e('ftpRootUnavailable', 'FTP 根目录不可用（代码 {code}）',
  'The FTP root directory is unavailable (code {code})',
  'FTP 错误：根目录不可用', {'code': 'String'})
e('ftpLoginFailed', 'FTP 登录失败，请检查账号密码',
  'FTP sign-in failed; check the account and password', 'FTP 错误：登录失败')
e('ftpBinaryModeRejected', 'FTP 服务器拒绝二进制模式',
  'The FTP server rejected binary mode', 'FTP 错误：拒绝二进制模式')
e('ftpListFailed', 'FTP 目录列表失败（代码 {code}）',
  'Failed to list the FTP directory (code {code})',
  'FTP 错误：目录列表失败', {'code': 'String'})
e('ftpConnectionClosed', 'FTP 连接被服务器关闭',
  'The FTP connection was closed by the server', 'FTP 错误：连接被关闭')
e('ftpUnexpectedResponse', 'FTP 服务器返回异常响应',
  'The FTP server returned an unexpected response', 'FTP 错误：异常响应')
e('ftpConnectionInterrupted', 'FTP 连接中断', 'The FTP connection was interrupted',
  'FTP 错误：连接中断')
e('ftpPassiveUnsupported', 'FTP 服务器不支持被动模式',
  'The FTP server does not support passive mode', 'FTP 错误：不支持被动模式')
e('ftpPassiveParseFailed', 'FTP 被动模式响应无法解析',
  'Could not parse the FTP passive-mode response', 'FTP 错误：被动模式响应无法解析')
e('webdavNotAFile', '文件不存在或不是文件', 'The file does not exist or is not a file',
  'WebDAV 错误：目标不是文件')
e('webdavTargetIsDirectory', '目标是一个目录', 'The target is a directory',
  'WebDAV 错误：目标是目录')
e('webdavRangeIgnored', '服务器忽略了分段请求，无法精确跳转',
  'The server ignored the range request; precise seeking is unavailable',
  'WebDAV 错误：忽略 Range 请求')
e('webdavRangeFailed', '分段请求失败（HTTP {status}）',
  'The range request failed (HTTP {status})', 'WebDAV 错误：Range 请求失败', {'status': 'String'})
e('webdavRangeStartMismatch', '服务器返回的分段起点与请求不一致',
  'The range start returned by the server does not match the request',
  'WebDAV 错误：Range 起点不一致')
e('webdavDownloadFailedAuth', '下载失败（HTTP {status}，认证失败）',
  'Download failed (HTTP {status}, authentication failed)',
  'WebDAV 错误：下载 401', {'status': 'String'})
e('webdavDirectoryTooLarge', '目录过大：响应超过 {mb}MB',
  'The directory is too large: the response exceeded {mb}MB',
  'WebDAV 错误：目录响应超上限', {'mb': 'String'})
e('webdavRequestFailed', 'WebDAV 请求失败（HTTP {status}）',
  'The WebDAV request failed (HTTP {status})', 'WebDAV 错误：请求失败', {'status': 'String'})
e('webdavRequestFailedAuth', 'WebDAV 请求失败（HTTP {status}，认证失败）',
  'The WebDAV request failed (HTTP {status}, authentication failed)',
  'WebDAV 错误：请求 401', {'status': 'String'})
e('smbNotConnected', 'SMB 尚未连接', 'SMB is not connected', 'SMB 错误：尚未连接')
e('smbAuthFailed', '用户名或密码错误', 'Incorrect user name or password',
  'SMB 错误：账号密码错误')
e('smbAccessDenied', '拒绝访问（权限不足）', 'Access denied (insufficient permissions)',
  'SMB 错误：拒绝访问')
e('smbPathNotFound', '路径不存在', 'The path does not exist', 'SMB 错误：路径不存在')
e('smbRequestFailed', 'SMB 请求失败', 'The SMB request failed', 'SMB 错误：请求失败')

# ── 网络路径校验 ────────────────────────────────────────────
e('netPathScheme', '网络路径不能包含 URI scheme',
  'The network path must not contain a URI scheme', '网络路径校验：含 scheme')
e('netPathTooLong', '网络路径过长', 'The network path is too long', '网络路径校验：整体过长')
e('netPathTooManySegments', '网络路径段数过多', 'The network path has too many segments',
  '网络路径校验：段数过多')
e('netPathSegmentEmpty', '路径段不能为空', 'A path segment must not be empty',
  '网络路径校验：空段')
e('netPathSegmentTooLong', '路径段过长', 'A path segment is too long',
  '网络路径校验：单段过长')
e('netPathDotSegment', '网络路径不能包含 . 或 ..',
  'The network path must not contain "." or ".."', '网络路径校验：. / .. 段')
e('netPathSegmentSeparator', '路径段不能包含分隔符',
  'A path segment must not contain a separator', '网络路径校验：段内含分隔符')
e('netPathSegmentControlChar', '路径段不能包含控制字符',
  'A path segment must not contain control characters', '网络路径校验：段内含控制字符')

# ── 文件操作 ────────────────────────────────────────────────
e('fileOpSourceMissing', '源文件不存在或已被移动',
  'The source file does not exist or has been moved', '文件操作：源文件缺失')
e('fileOpWriteFailed', '写入失败：{name}（{error}）', 'Failed to write: {name} ({error})',
  '文件操作：写入失败（文件名 + 异常）', {'name': 'String', 'error': 'String'})
e('fileOpCopiedButDeleteFailed', '已复制到目标位置，但删除原文件失败，请手动清理',
  'Copied to the destination, but the original file could not be deleted; please clean up manually',
  '文件操作：复制成功但删除源失败')
e('fileOpRenameTempFailed', '重命名临时文件失败：{error}',
  'Failed to rename the temporary file: {error}',
  '文件操作：临时文件重命名失败', {'error': 'String'})
e('fileOpTargetExists', '同目录下已存在同名文件或文件夹',
  'A file or folder with the same name already exists in this folder',
  '文件操作：目标已存在同名项')
e('fileOpRenameFailed', '重命名失败：{error}', 'Rename failed: {error}',
  '文件操作：重命名失败', {'error': 'String'})
e('fileOpFileMissing', '文件不存在或已被删除',
  'The file does not exist or has been deleted', '文件操作：文件缺失')
e('fileOpDeleteFailed', '删除失败：{error}', 'Delete failed: {error}',
  '文件操作：删除失败', {'error': 'String'})
e('fileOpFolderMissing', '文件夹不存在或已被删除',
  'The folder does not exist or has been deleted', '文件操作：文件夹缺失')
e('fileOpNoVideosInFolder', '该文件夹内没有可删除的视频文件',
  'This folder has no video files to delete', '文件操作：文件夹内无视频')
e('fileOpSelectTargetFolder', '请选择目标文件夹', 'Choose a destination folder',
  '文件操作校验：未选目标文件夹')
e('fileOpTargetUnreadable', '目标文件夹不存在或不可读',
  'The destination folder does not exist or is unreadable',
  '文件操作校验：目标文件夹不可用')
e('fileOpAlreadyInFolder', '该文件夹已经在这个目录里了',
  'This folder is already in that directory', '文件操作校验：文件夹已在目标目录')
e('fileOpAlreadyInFolderVideo', '该视频已经在这个目录里了',
  'This video is already in that directory', '文件操作校验：视频已在目标目录')
e('fileOpIntoItself', '不能把文件夹复制或移动到它自己的子目录里',
  'A folder cannot be copied or moved into its own subfolder',
  '文件操作校验：不能移到自己的子目录')
e('fileOpNameEmpty', '名称不能为空', 'The name must not be empty', '文件名校验：空')
e('fileOpNameInvalid', '名称不合法', 'The name is not valid', '文件名校验：不合法')
e('fileOpNameHasSeparator', '名称不能包含路径分隔符',
  'The name must not contain a path separator', '文件名校验：含路径分隔符')
e('fileOpNameIllegalChars', '名称不能包含 \\ / : * ? " < > | 等字符',
  'The name must not contain characters such as \\ / : * ? " < > |',
  '文件名校验：含非法字符')
e('fileOpNameEmptyBeforeExt', '请输入扩展名之前的名称',
  'Enter the name before the extension', '重命名输入校验：扩展名前为空')

# ── 模型 / 工具层显示名 ─────────────────────────────────────
e('commonGotIt', '知道了', 'Got it', '通用按钮：知道了（杜比视界提示）')
e('commonErrorsSeparator', '；', '; ',
  '通用：多条错误拼接用的分隔符（弹幕搜索失败原因）')
e('playerEqualizerPresetFlat', '平直', 'Flat', '均衡器预设：平直')
e('playerEqualizerPresetDialogue', '对白增强', 'Dialogue boost', '均衡器预设：对白增强')
e('playerEqualizerPresetCinema', '电影', 'Cinema', '均衡器预设：电影')
e('playerEqualizerPresetBass', '低音震撼', 'Bass boost', '均衡器预设：低音震撼')
e('playerEqualizerPresetTreble', '高音清晰', 'Treble boost', '均衡器预设：高音清晰')
e('playerEqualizerPresetNight', '柔和夜间', 'Night mode', '均衡器预设：柔和夜间')
e('biliVipNormal', '普通会员', 'Regular member', 'B 站账号：普通会员')
e('biliVipAnnual', '年度大会员', 'Annual premium member', 'B 站账号：年度大会员')
e('biliVipMember', '大会员', 'Premium member', 'B 站账号：大会员')
e('biliPlaylistEpisode', '第 {index} 集', 'Episode {index}',
  'B 站播放列表：无标题时的集名', {'index': 'String'})
e('subtitleUnknownName', '未知字幕', 'Unknown subtitle', '字幕条目：无展示名时的占位')
e('subtitleUnknownLanguage', '未知语言', 'Unknown language', '字幕条目：无语言时的占位')
e('danmakuServerDefaultName', '弹弹Play（默认）', 'Dandanplay (default)',
  '弹幕：内置默认服务器的显示名（仅显示，持久化值不变）')
e('danmakuServerAutoMatchBlocked', '请先停用弹弹Play 服务器',
  'Disable the Dandanplay server first', '弹幕设置：禁止开启自动匹配的短原因')
e('danmakuServerAutoMatchBlockedDetail',
  '已启用「{name}」服务器时不可开启「切集自动匹配弹幕」，如需使用请先停用该服务器',
  'Cannot enable "Auto-match danmaku on episode change" while the "{name}" server is enabled; disable that server first',
  '弹幕设置：禁止开启自动匹配的完整说明', {'name': 'String'})
e('danmakuSearchNoResult', '未找到相关番剧，请尝试其他关键词',
  'No matching anime found; try other keywords', '弹幕搜索：无结果')
e('danmakuSearchFailed', '搜索失败：{errors}', 'Search failed: {errors}',
  '弹幕搜索：各服务器错误汇总', {'errors': 'String'})
e('danmakuOffsetNone', '无偏移', 'No offset', '弹幕时间轴偏移：0')
e('danmakuOffsetDelay', '延后 {time}', 'Delayed {time}', '弹幕时间轴偏移：正',
  {'time': 'String'})
e('danmakuOffsetAdvance', '提前 {time}', 'Advanced {time}', '弹幕时间轴偏移：负',
  {'time': 'String'})
e('playerAudioFallbackNoTrack', '当前音轨无法播放，且没有其它可切换的音轨',
  'The current audio track cannot be played and there is no other track to switch to',
  '播放器：音轨回退失败提示')
e('playerAudioFallbackSwitched', '当前音轨无法播放，已自动切换到「{name}」',
  'The current audio track cannot be played; switched to "{name}" automatically',
  '播放器：音轨自动回退提示', {'name': 'String'})
e('playerDiagnosticsDuration', '{minutes} 分 {seconds} 秒', '{minutes} min {seconds} s',
  '播放器诊断：≥60 秒的时长文本', {'minutes': 'String', 'seconds': 'String'})
e('playerDiagnosticsAvsyncAudioAhead', '{value} 音频超前', '{value} audio ahead',
  '播放器诊断：音画同步（音频超前）', {'value': 'String'})
e('playerDiagnosticsAvsyncVideoAhead', '{value} 视频超前', '{value} video ahead',
  '播放器诊断：音画同步（视频超前）', {'value': 'String'})
e('playerDiagnosticsWarnDroppedFrames',
  '已丢帧 {dropped} 帧：渲染跟不上，可尝试降超分档位或改硬解',
  'Dropped {dropped} frames: rendering cannot keep up; try a lower super-resolution level or switch to hardware decoding',
  '播放器诊断：丢帧告警', {'dropped': 'int'})
e('playerDiagnosticsWarnSoftwareDecode',
  '当前为软解（CPU 解码）：高码率/高分辨率可能掉帧发热',
  'Currently using software decoding (CPU): high bitrate or high resolution may cause dropped frames and heat',
  '播放器诊断：软解告警')
e('playerDiagnosticsWarnAvsync', '音画不同步：{value}',
  'Audio and video are out of sync: {value}',
  '播放器诊断：音画不同步告警', {'value': 'String'})
e('cacheCategoryListThumbs', '视频列表封面缩略图', 'Video list cover thumbnails',
  '缓存类别：视频列表封面缩略图')
e('cacheCategoryNetworkDanmaku', '网络弹幕缓存', 'Online danmaku cache',
  '缓存类别：网络弹幕缓存')
e('cacheCategoryBiliCovers', '哔哩封面缓存', 'Bilibili cover cache',
  '缓存类别：哔哩封面缓存')
e('cacheCategoryOther', '其他缓存', 'Other caches', '缓存类别：其他缓存')
e('updateNoNotes', '暂无更新说明', 'No release notes available',
  '检查更新：Release 正文为空时的占位')
e('buildInfoNoRevision', '本次构建未注入提交哈希（需用 tools/ 里的构建脚本编译）',
  'This build has no commit hash injected (build it with the script in tools/)',
  '关于页：构建信息没有提交哈希')
e('buildInfoCopied', '已复制 {revision}', 'Copied {revision}',
  '关于页：复制提交哈希提示', {'revision': 'String'})
e('buildInfoCopiedDirty', '已复制 {revision}（工作区有未提交改动）',
  'Copied {revision} (uncommitted changes in the working tree)',
  '关于页：复制提交哈希提示（工作区有改动）', {'revision': 'String'})
e('castDeviceOffline', '设备已离线', 'The device is offline', '投屏：设备离线')
e('castNoLanIpv4', '未找到局域网 IPv4 地址', 'No LAN IPv4 address was found',
  '投屏：本机没有局域网 IPv4')
e('castFileMissing', '文件不存在', 'The file does not exist', '投屏：待投屏文件不存在')
e('dolbyVisionHintTitle', '杜比视界视频', 'Dolby Vision video',
  '播放器：杜比视界引导弹窗标题')
e('dolbyVisionHintBody',
  '该视频为杜比视界（Dolby Vision）编码。\n若画面发绿/发紫，请在「播放设置 → 解码」启用 GPU-next 渲染并切换软解；\n若仍无法解决，则该设备可能不支持杜比视界播放。',
  'This video is encoded in Dolby Vision.\nIf the picture looks green or purple, enable GPU-next rendering and switch to software decoding in "Playback settings → Decoding".\nIf that does not help, this device may not support Dolby Vision playback.',
  '播放器：杜比视界引导弹窗正文')


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))

    added = 0
    for key, zh_v, en_v, desc, ph in E:
        if key in zh:
            raise SystemExit(f'FAIL: 键已存在 {key}')
        zh[key] = zh_v
        meta = {'description': desc}
        if ph:
            meta['placeholders'] = {k: {'type': v} for k, v in ph.items()}
        zh['@' + key] = meta
        en[key] = en_v
        added += 1

    # 既有键 patch：一键清除全部缓存的正文里，两条类别名改为由 UI 传入（与
    # 服务层 CacheCategory 的 ARB 键同源，见 06-遗留 §2.2）。
    patch = 'settingsCacheClearAllBody'
    zh[patch] = '将删除全部缓存（当前共 {size}）：\n{items}\n\n此操作不可恢复。'
    zh['@' + patch]['placeholders']['items'] = {'type': 'String'}
    en[patch] = 'This deletes all caches ({size} in total):\n{items}\n\nThis cannot be undone.'

    json.dump(zh, open(ZH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(ZH, 'a', encoding='utf-8').write('\n')
    json.dump(en, open(EN, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(EN, 'a', encoding='utf-8').write('\n')
    print(f'OK: 新增 {added} 键，patch {patch}；zh={len([k for k in zh if not k.startswith("@")])} '
          f'en={len([k for k in en if not k.startswith("@")])}')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
