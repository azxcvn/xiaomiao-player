/// 服务层错误码表（**纯 Dart，禁止 import Flutter / l10n**）。
///
/// 分层约定见 `杂项文件/多语言支持方案/02-实施方案.md` §1.8：`services` / `models` /
/// `utils` 只产出「码 + 参数」，文案一律由 UI 层翻译——见
/// `lib/l10n/error_texts.dart` 的各 `*ErrorText` 函数与统一入口 [serviceErrorText]。
///
/// 参数的键名与 ARB 的 placeholder 名一一对应（如 `code` / `status` / `error`），
/// UI 侧用 `'${e.args['code']}'` 取用，因此这里统一存 `Object?`。
library;

/// 网络客户端（FTP / WebDAV / SMB）错误码
enum NetworkErrorCode {
  /// 连接超时（FTP / WebDAV 共用「服务器无响应，请检查地址与端口」）
  connectTimeout,

  /// FTP 拒绝连接（code = 应答码）
  ftpRefusedConnection,

  /// FTP 不支持断点续传（REST）
  ftpResumeUnsupported,

  /// FTP 拒绝文件传输（code = 应答码）
  ftpTransferRejected,

  /// FTP 根目录不可用（code = 应答码）
  ftpRootUnavailable,

  /// FTP 登录失败
  ftpLoginFailed,

  /// FTP 拒绝二进制模式
  ftpBinaryModeRejected,

  /// FTP 目录列表失败（code = 应答码）
  ftpListFailed,

  /// FTP 连接被服务器关闭
  ftpConnectionClosed,

  /// FTP 服务器返回异常响应
  ftpUnexpectedResponse,

  /// FTP 连接中断
  ftpConnectionInterrupted,

  /// FTP 不支持被动模式
  ftpPassiveUnsupported,

  /// FTP 被动模式响应无法解析
  ftpPassiveParseFailed,

  /// WebDAV：目标不是文件
  webdavNotAFile,

  /// WebDAV：目标是目录
  webdavTargetIsDirectory,

  /// WebDAV：服务器忽略 Range 请求
  webdavRangeIgnored,

  /// WebDAV：Range 请求失败（status = HTTP 状态码）
  webdavRangeFailed,

  /// WebDAV：Range 起点与请求不一致
  webdavRangeStartMismatch,

  /// WebDAV：下载失败（status = HTTP 状态码；401 走 [webdavDownloadFailedAuth]）
  webdavDownloadFailed,

  /// WebDAV：下载 401（status = HTTP 状态码）
  webdavDownloadFailedAuth,

  /// WebDAV：目录响应超过上限（mb = 上限 MB）
  webdavDirectoryTooLarge,

  /// WebDAV：请求失败（status = HTTP 状态码）
  webdavRequestFailed,

  /// WebDAV：请求 401（status = HTTP 状态码）
  webdavRequestFailedAuth,

  /// SMB 尚未连接
  smbNotConnected,

  /// SMB 账号密码错误
  smbAuthFailed,

  /// SMB 拒绝访问
  smbAccessDenied,

  /// SMB 路径不存在
  smbPathNotFound,

  /// SMB 请求失败
  smbRequestFailed,

  /// SMB 第三方异常原文（**数据**，直接透传显示）
  smbServerMessage,

  /// 网络连接不存在（播放列表源 / 网络字幕流）
  connectionMissing,
}

/// 哔哩哔哩接口错误码（下载任务复用同一个异常，故下载文案也在这里）
enum BiliApiErrorCode {
  /// 网络请求异常（error = 异常文本）
  networkFailed,

  /// HTTP 非 2xx（status = 状态码）
  httpFailed,

  /// 响应不是 JSON 对象
  responseNotJson,

  /// 响应解析异常（error = 异常文本）
  responseParseFailed,

  /// 服务端返回业务失败（code = 业务 code）
  serverReturnedCode,

  /// 服务端自带 message（**数据**，直接透传显示）
  serverMessage,

  /// 未知错误（服务端未给 message 时的兜底）
  unknownError,

  /// 缺少 WBI 密钥（播放地址）
  wbiKeyMissingPlay,

  /// 缺少 WBI 密钥（搜索）
  wbiKeyMissingSearch,

  /// 触发风控验证
  riskControlTriggered,

  /// 视频不存在（code -404）
  videoNotFound,

  /// 无权访问（code -403）
  videoNoAccess,

  /// 需要大会员（code -10403）
  videoVipRequired,

  /// 风控验证失败（code -352）
  videoRiskControlFailed,

  /// 专属视频（code 87008）
  videoExclusive,

  /// 生成二维码失败（登录页只显示通用文案）
  loginQrFailed,

  /// 登录凭证解析失败（缺少 SESSDATA）
  loginCredentialParseFailed,

  /// Cookie 缺少 SESSDATA
  loginCookieMissing,

  /// Cookie 无效或已过期
  loginCookieInvalid,

  /// 下载：无法识别 B 站链接
  downloadLinkUnrecognized,

  /// 下载：未解析到视频分 P
  downloadNoVideoParts,

  /// 下载：番剧没有可下载集数
  downloadBangumiNoEpisodes,

  /// 下载：合集没有可下载视频
  downloadCollectionNoVideos,

  /// 下载：合集暂无内容
  downloadCollectionEmpty,

  /// 下载：该集没有弹幕
  downloadNoDanmaku,

  /// 下载：未获取到视频流
  downloadNoVideoStream,

  /// 下载：音视频合并失败
  downloadMergeFailed,

  /// 下载：网络请求失败（无详情）
  downloadNetworkFailed,

  /// 下载：写盘失败
  downloadWriteFailed,

  /// 下载：写盘失败（error = 异常文本）
  downloadWriteFailedDetail,
}

/// 弹弹Play 接口错误码
enum DandanApiErrorCode {
  /// 自建服务器地址无效（url = 用户填的地址）
  invalidServerUrl,

  /// 网络请求异常（error = 异常文本）
  networkFailed,

  /// 响应过大已放弃解析（received = 已读字节）
  responseTooLarge,

  /// 响应解码异常（error = 异常文本）
  decodeFailed,

  /// HTTP 非 2xx（status = 状态码）
  httpFailed,

  /// 服务端返回失败（无 message）
  serverError,

  /// 服务端自带 message（**数据**，直接透传显示）
  serverMessage,

  /// 响应解析异常（error = 异常文本）
  parseFailed,
}

/// Wyzie 在线字幕接口错误码
enum WyzieApiErrorCode {
  /// 网络请求异常（error = 异常文本）
  networkFailed,

  /// HTTP 400（接口判定为无结果）
  searchNoSubtitles,

  /// 搜索 HTTP 非 2xx（status = 状态码）
  searchHttpFailed,

  /// 下载异常（error = 异常文本）
  downloadFailed,

  /// 下载 HTTP 非 2xx（status = 状态码）
  downloadHttpFailed,

  /// 下载体积超上限（received = 已读字节）
  downloadTooLarge,

  /// 响应体积超上限（received / max）
  responseTooLarge,

  /// 没有匹配的影视
  noMatch,

  /// HTTP 非 2xx（status = 状态码）
  httpFailed,
}

/// 自定义字幕地址接口错误码
enum CustomSubtitleApiErrorCode {
  /// 接口地址无效
  urlInvalid,

  /// 网络请求异常（error = 异常文本）
  networkFailed,

  /// 搜索 HTTP 非 2xx（status = 状态码）
  searchHttpFailed,

  /// 响应体积超上限（received / max）
  responseTooLarge,

  /// 响应无法解析（reason = 内层解析错误码）
  responseUnparsable,

  /// 下载异常（error = 异常文本）
  downloadFailed,

  /// 下载 HTTP 非 2xx（status = 状态码）
  downloadHttpFailed,

  /// 下载体积超上限（received = 已读字节）
  downloadTooLarge,
}

/// 自定义字幕响应解析错误码（被 [CustomSubtitleApiErrorCode.responseUnparsable] 内嵌）
enum CustomSubtitleParseErrorCode {
  /// 不是合法 JSON
  notJson,

  /// 找不到字幕列表
  noList,
}

/// 文件操作错误码（校验 + 增删改）
enum FileOpErrorCode {
  /// 源文件不存在或已被移动
  sourceMissing,

  /// 写入失败（name = 文件名，error = 异常文本）
  writeFailed,

  /// 用户取消（UI 用 `cancelled` 判定，文案仅兜底）
  cancelled,

  /// 已复制但删除源文件失败
  copiedButDeleteFailed,

  /// 重命名临时文件失败（error = 异常文本）
  renameTempFailed,

  /// 目标已存在同名项
  targetExists,

  /// 重命名失败（error = 异常文本）
  renameFailed,

  /// 文件不存在或已被删除
  fileMissing,

  /// 删除失败（error = 异常文本）
  deleteFailed,

  /// 文件夹不存在或已被删除
  folderMissing,

  /// 文件夹内没有可删除的视频
  noVideosInFolder,

  /// 未选目标文件夹
  selectTargetFolder,

  /// 目标文件夹不存在或不可读
  targetUnreadable,

  /// 文件夹已在目标目录
  alreadyInFolder,

  /// 视频已在目标目录
  alreadyInFolderVideo,

  /// 不能移动到自己的子目录
  intoItself,

  /// 名称为空
  nameEmpty,

  /// 名称不合法
  nameInvalid,

  /// 名称含路径分隔符
  nameHasSeparator,

  /// 名称含非法字符
  nameIllegalChars,

  /// 补全扩展名前的名称为空
  nameEmptyBeforeExt,
}

/// 网络路径校验错误码（`NetworkPath.from` / `_validateSegment`）
enum NetworkPathErrorCode {
  /// 含 URI scheme
  scheme,

  /// 整体过长
  tooLong,

  /// 段数过多
  tooManySegments,

  /// 空段
  segmentEmpty,

  /// 单段过长
  segmentTooLong,

  /// `.` / `..` 段
  dotSegment,

  /// 段内含分隔符
  segmentSeparator,

  /// 段内含控制字符
  segmentControlChar,
}

/// 检查更新失败错误码（调用方目前一律显示通用文案，码供兜底与日志）
enum UpdateCheckErrorCode {
  /// 抓不到远端版本信息
  fetchRemoteFailed,
}

/// 投屏错误码
enum CastErrorCode {
  /// 设备已离线（DLNA 设备列表里已找不到）
  deviceOffline,
}

/// 局域网媒体服务器错误码
enum LanMediaServerErrorCode {
  /// 找不到局域网 IPv4 地址
  noLanIpv4,

  /// 待暴露的文件不存在（path = 文件路径）
  fileMissing,
}
