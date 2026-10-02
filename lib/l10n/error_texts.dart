/// 服务层「码 + 参数」→ 文案 的 **UI 侧**翻译（`02-实施方案.md` §1.8）。
///
/// 为什么单独一个文件：`services` / `models` / `utils` 里不许 import l10n，
/// 所有面向界面的文案都在这里按错误码现取；表（枚举 / 映射表）的文案仍在
/// `lib/l10n/label_maps.dart`。
///
/// 用法：拿到任意服务层异常给 [serviceErrorText]（统一入口）；已知类型可直接
/// 调对应的 `*ErrorText`。
library;

import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/bilibili/bili_http.dart';
import 'package:moumou/services/cast/cast_service.dart';
import 'package:moumou/services/cast/lan_media_server.dart';
import 'package:moumou/services/dandan_play_api.dart';
import 'package:moumou/services/file_operations_service.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/subtitle/custom_subtitle_api.dart';
import 'package:moumou/services/update/update_service.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/utils/custom_subtitle_parser.dart';
import 'package:moumou/utils/error_codes.dart';
import 'package:moumou/utils/network_path.dart';

/// 统一入口：任意服务层异常 → 展示文案。
///
/// 已知异常按错误码翻译；未知类型回落到 `toString()`（与改造前的行为一致）。
String serviceErrorText(AppLocalizations l10n, Object error) => switch (error) {
      NetworkClientException e => networkErrorText(l10n, e),
      NetworkPathException e => networkPathErrorText(l10n, e),
      BiliApiException e => biliErrorText(l10n, e),
      DandanApiException e => dandanErrorText(l10n, e),
      WyzieApiException e => wyzieErrorText(l10n, e),
      CustomSubtitleApiException e => customSubtitleErrorText(l10n, e),
      CustomSubtitleParseException e => customSubtitleParseErrorText(l10n, e),
      FileOpException e => fileOpErrorText(l10n, e),
      UpdateCheckException e => updateCheckErrorText(l10n, e),
      CastException e => castErrorText(l10n, e),
      LanMediaServerException e => lanMediaServerErrorText(l10n, e),
      _ => '$error',
    };

/// 网络客户端（FTP / WebDAV / SMB）错误
String networkErrorText(AppLocalizations l10n, NetworkClientException e) =>
    switch (e.code) {
      NetworkErrorCode.connectTimeout => l10n.networkConnectTimeout,
      NetworkErrorCode.ftpRefusedConnection =>
        l10n.ftpRefusedConnection('${e.args['code']}'),
      NetworkErrorCode.ftpResumeUnsupported => l10n.ftpResumeUnsupported,
      NetworkErrorCode.ftpTransferRejected =>
        l10n.ftpTransferRejected('${e.args['code']}'),
      NetworkErrorCode.ftpRootUnavailable =>
        l10n.ftpRootUnavailable('${e.args['code']}'),
      NetworkErrorCode.ftpLoginFailed => l10n.ftpLoginFailed,
      NetworkErrorCode.ftpBinaryModeRejected => l10n.ftpBinaryModeRejected,
      NetworkErrorCode.ftpListFailed => l10n.ftpListFailed('${e.args['code']}'),
      NetworkErrorCode.ftpConnectionClosed => l10n.ftpConnectionClosed,
      NetworkErrorCode.ftpUnexpectedResponse => l10n.ftpUnexpectedResponse,
      NetworkErrorCode.ftpConnectionInterrupted =>
        l10n.ftpConnectionInterrupted,
      NetworkErrorCode.ftpPassiveUnsupported => l10n.ftpPassiveUnsupported,
      NetworkErrorCode.ftpPassiveParseFailed => l10n.ftpPassiveParseFailed,
      NetworkErrorCode.webdavNotAFile => l10n.webdavNotAFile,
      NetworkErrorCode.webdavTargetIsDirectory => l10n.webdavTargetIsDirectory,
      NetworkErrorCode.webdavRangeIgnored => l10n.webdavRangeIgnored,
      NetworkErrorCode.webdavRangeFailed =>
        l10n.webdavRangeFailed('${e.args['status']}'),
      NetworkErrorCode.webdavRangeStartMismatch =>
        l10n.webdavRangeStartMismatch,
      NetworkErrorCode.webdavDownloadFailed =>
        l10n.errorHttpDownloadFailed('${e.args['status']}'),
      NetworkErrorCode.webdavDownloadFailedAuth =>
        l10n.webdavDownloadFailedAuth('${e.args['status']}'),
      NetworkErrorCode.webdavDirectoryTooLarge =>
        l10n.webdavDirectoryTooLarge('${e.args['mb']}'),
      NetworkErrorCode.webdavRequestFailed =>
        l10n.webdavRequestFailed('${e.args['status']}'),
      NetworkErrorCode.webdavRequestFailedAuth =>
        l10n.webdavRequestFailedAuth('${e.args['status']}'),
      NetworkErrorCode.smbNotConnected => l10n.smbNotConnected,
      NetworkErrorCode.smbAuthFailed => l10n.smbAuthFailed,
      NetworkErrorCode.smbAccessDenied => l10n.smbAccessDenied,
      NetworkErrorCode.smbPathNotFound => l10n.smbPathNotFound,
      NetworkErrorCode.smbRequestFailed => l10n.smbRequestFailed,
      // 第三方异常原文（数据，不翻译）
      NetworkErrorCode.smbServerMessage => '${e.args['message']}',
      NetworkErrorCode.connectionMissing => l10n.errorNetworkConnectionMissing,
    };

/// 网络路径校验错误
String networkPathErrorText(AppLocalizations l10n, NetworkPathException e) =>
    switch (e.code) {
      NetworkPathErrorCode.scheme => l10n.netPathScheme,
      NetworkPathErrorCode.tooLong => l10n.netPathTooLong,
      NetworkPathErrorCode.tooManySegments => l10n.netPathTooManySegments,
      NetworkPathErrorCode.segmentEmpty => l10n.netPathSegmentEmpty,
      NetworkPathErrorCode.segmentTooLong => l10n.netPathSegmentTooLong,
      NetworkPathErrorCode.dotSegment => l10n.netPathDotSegment,
      NetworkPathErrorCode.segmentSeparator => l10n.netPathSegmentSeparator,
      NetworkPathErrorCode.segmentControlChar =>
        l10n.netPathSegmentControlChar,
    };

/// 哔哩哔哩接口 / 下载错误
String biliErrorText(AppLocalizations l10n, BiliApiException e) =>
    switch (e.code) {
      BiliApiErrorCode.networkFailed =>
        l10n.errorNetworkRequestFailed('${e.args['error']}'),
      BiliApiErrorCode.httpFailed =>
        l10n.errorHttpRequestFailed('${e.args['status']}'),
      BiliApiErrorCode.responseNotJson => l10n.errorResponseNotJson,
      BiliApiErrorCode.responseParseFailed =>
        l10n.errorResponseParseFailed('${e.args['error']}'),
      BiliApiErrorCode.serverReturnedCode =>
        l10n.errorServerReturnedCode('${e.args['code']}'),
      // 服务端自带 message（数据，不翻译）
      BiliApiErrorCode.serverMessage => '${e.args['message']}',
      BiliApiErrorCode.unknownError => l10n.errorUnknown,
      BiliApiErrorCode.wbiKeyMissingPlay => l10n.biliWbiKeyMissingPlay,
      BiliApiErrorCode.wbiKeyMissingSearch => l10n.biliWbiKeyMissingSearch,
      BiliApiErrorCode.riskControlTriggered => l10n.biliRiskControlTriggered,
      BiliApiErrorCode.videoNotFound => l10n.biliVideoNotFound,
      BiliApiErrorCode.videoNoAccess => l10n.biliVideoNoAccess,
      BiliApiErrorCode.videoVipRequired => l10n.biliVideoVipRequired,
      BiliApiErrorCode.videoRiskControlFailed =>
        l10n.biliVideoRiskControlFailed,
      BiliApiErrorCode.videoExclusive => l10n.biliVideoExclusive,
      // 登录链路的失败原因：登录页只显示通用文案，这里与登录页保持同一套说法
      BiliApiErrorCode.loginQrFailed => l10n.biliLoginQrFailed,
      BiliApiErrorCode.loginCredentialParseFailed => l10n.biliLoginFailedRetry,
      BiliApiErrorCode.loginCookieMissing => l10n.biliCookieInvalid,
      BiliApiErrorCode.loginCookieInvalid => l10n.biliCookieInvalid,
      BiliApiErrorCode.downloadLinkUnrecognized =>
        l10n.biliDownloadLinkUnrecognized,
      BiliApiErrorCode.downloadNoVideoParts => l10n.biliDownloadNoVideoParts,
      BiliApiErrorCode.downloadBangumiNoEpisodes =>
        l10n.biliDownloadBangumiNoEpisodes,
      BiliApiErrorCode.downloadCollectionNoVideos =>
        l10n.biliDownloadCollectionNoVideos,
      BiliApiErrorCode.downloadCollectionEmpty =>
        l10n.biliDownloadCollectionEmpty,
      BiliApiErrorCode.downloadNoDanmaku => l10n.biliDownloadNoDanmaku,
      BiliApiErrorCode.downloadNoVideoStream => l10n.biliDownloadNoVideoStream,
      BiliApiErrorCode.downloadMergeFailed => l10n.biliDownloadMergeFailed,
      BiliApiErrorCode.downloadNetworkFailed =>
        l10n.biliDownloadNetworkFailed,
      BiliApiErrorCode.downloadWriteFailed => l10n.biliDownloadWriteFailed,
      BiliApiErrorCode.downloadWriteFailedDetail =>
        l10n.biliDownloadWriteFailedDetail('${e.args['error']}'),
    };

/// 弹弹Play 接口错误
String dandanErrorText(AppLocalizations l10n, DandanApiException e) =>
    switch (e.code) {
      DandanApiErrorCode.invalidServerUrl =>
        l10n.dandanServerUrlInvalid('${e.args['url']}'),
      DandanApiErrorCode.networkFailed =>
        l10n.errorNetworkRequestFailed('${e.args['error']}'),
      DandanApiErrorCode.responseTooLarge =>
        l10n.errorResponseTooLargeAborted('${e.args['received']}'),
      DandanApiErrorCode.decodeFailed =>
        l10n.errorResponseDecodeFailed('${e.args['error']}'),
      DandanApiErrorCode.httpFailed =>
        l10n.errorHttpRequestFailed('${e.args['status']}'),
      DandanApiErrorCode.serverError => l10n.errorServerReturned,
      // 服务端自带 message（数据，不翻译）
      DandanApiErrorCode.serverMessage => '${e.args['message']}',
      DandanApiErrorCode.parseFailed =>
        l10n.errorResponseParseFailed('${e.args['error']}'),
    };

/// Wyzie 在线字幕接口错误
String wyzieErrorText(AppLocalizations l10n, WyzieApiException e) =>
    switch (e.code) {
      WyzieApiErrorCode.networkFailed =>
        l10n.errorNetworkRequestFailed('${e.args['error']}'),
      WyzieApiErrorCode.searchNoSubtitles => l10n.wyzieSearchNoSubtitles,
      WyzieApiErrorCode.searchHttpFailed =>
        l10n.errorHttpSearchFailed('${e.args['status']}'),
      WyzieApiErrorCode.downloadFailed =>
        l10n.errorDownloadFailed('${e.args['error']}'),
      WyzieApiErrorCode.downloadHttpFailed =>
        l10n.errorHttpDownloadFailed('${e.args['status']}'),
      WyzieApiErrorCode.downloadTooLarge =>
        l10n.errorDownloadTooLarge('${e.args['received']}'),
      WyzieApiErrorCode.responseTooLarge => l10n.errorResponseTooLarge(
          '${e.args['received']}',
          '${e.args['max']}',
        ),
      WyzieApiErrorCode.noMatch => l10n.wyzieNoMatch,
      WyzieApiErrorCode.httpFailed =>
        l10n.errorHttpRequestFailed('${e.args['status']}'),
    };

/// 自定义字幕地址接口错误
String customSubtitleErrorText(
  AppLocalizations l10n,
  CustomSubtitleApiException e,
) =>
    switch (e.code) {
      CustomSubtitleApiErrorCode.urlInvalid => l10n.customSubtitleUrlInvalid,
      CustomSubtitleApiErrorCode.networkFailed =>
        l10n.errorNetworkRequestFailed('${e.args['error']}'),
      CustomSubtitleApiErrorCode.searchHttpFailed =>
        l10n.errorHttpSearchFailed('${e.args['status']}'),
      CustomSubtitleApiErrorCode.responseTooLarge => l10n.errorResponseTooLarge(
          '${e.args['received']}',
          '${e.args['max']}',
        ),
      // 内层解析失败原因由 [customSubtitleParseErrorText] 翻译后拼进整句
      CustomSubtitleApiErrorCode.responseUnparsable =>
        l10n.customSubtitleResponseUnparsable(
          customSubtitleParseErrorText(
            l10n,
            CustomSubtitleParseException(e.args['reason'] as CustomSubtitleParseErrorCode),
          ),
        ),
      CustomSubtitleApiErrorCode.downloadFailed =>
        l10n.errorDownloadFailed('${e.args['error']}'),
      CustomSubtitleApiErrorCode.downloadHttpFailed =>
        l10n.errorHttpDownloadFailed('${e.args['status']}'),
      CustomSubtitleApiErrorCode.downloadTooLarge =>
        l10n.errorDownloadTooLarge('${e.args['received']}'),
    };

/// 自定义字幕响应解析错误（内嵌在 [customSubtitleErrorText] 的整句里）
String customSubtitleParseErrorText(
  AppLocalizations l10n,
  CustomSubtitleParseException e,
) =>
    switch (e.code) {
      CustomSubtitleParseErrorCode.notJson => l10n.customSubtitleResponseNotJson,
      CustomSubtitleParseErrorCode.noList => l10n.customSubtitleResponseNoList,
    };

/// 文件操作（校验 / 复制 / 移动 / 重命名 / 删除）错误
String fileOpErrorText(AppLocalizations l10n, FileOpException e) =>
    fileOpCodeText(l10n, e.code, args: e.args);

/// 文件操作错误码 → 文案。
///
/// 校验结果这类**只有码、没有异常对象**的落点直接用这个（不需要 [args]）；
/// 需要参数的码（写入/重命名/删除失败）由 [args] 传入，键名与抛出点一致。
String fileOpCodeText(
  AppLocalizations l10n,
  FileOpErrorCode code, {
  Map<String, Object?> args = const {},
}) =>
    switch (code) {
      FileOpErrorCode.sourceMissing => l10n.fileOpSourceMissing,
      FileOpErrorCode.writeFailed => l10n.fileOpWriteFailed(
          '${args['name']}',
          '${args['error']}',
        ),
      // 取消路径由 UI 按 `cancelled` 判定，这条只在兜底提示里出现
      FileOpErrorCode.cancelled => l10n.folderActionCancelled,
      FileOpErrorCode.copiedButDeleteFailed =>
        l10n.fileOpCopiedButDeleteFailed,
      FileOpErrorCode.renameTempFailed =>
        l10n.fileOpRenameTempFailed('${args['error']}'),
      FileOpErrorCode.targetExists => l10n.fileOpTargetExists,
      FileOpErrorCode.renameFailed =>
        l10n.fileOpRenameFailed('${args['error']}'),
      FileOpErrorCode.fileMissing => l10n.fileOpFileMissing,
      FileOpErrorCode.deleteFailed =>
        l10n.fileOpDeleteFailed('${args['error']}'),
      FileOpErrorCode.folderMissing => l10n.fileOpFolderMissing,
      FileOpErrorCode.noVideosInFolder => l10n.fileOpNoVideosInFolder,
      FileOpErrorCode.selectTargetFolder => l10n.fileOpSelectTargetFolder,
      FileOpErrorCode.targetUnreadable => l10n.fileOpTargetUnreadable,
      FileOpErrorCode.alreadyInFolder => l10n.fileOpAlreadyInFolder,
      FileOpErrorCode.alreadyInFolderVideo => l10n.fileOpAlreadyInFolderVideo,
      FileOpErrorCode.intoItself => l10n.fileOpIntoItself,
      FileOpErrorCode.nameEmpty => l10n.fileOpNameEmpty,
      FileOpErrorCode.nameInvalid => l10n.fileOpNameInvalid,
      FileOpErrorCode.nameHasSeparator => l10n.fileOpNameHasSeparator,
      FileOpErrorCode.nameIllegalChars => l10n.fileOpNameIllegalChars,
      FileOpErrorCode.nameEmptyBeforeExt => l10n.fileOpNameEmptyBeforeExt,
    };

/// 检查更新失败（调用方目前只显示这句通用文案）
String updateCheckErrorText(AppLocalizations l10n, UpdateCheckException e) =>
    switch (e.code) {
      UpdateCheckErrorCode.fetchRemoteFailed =>
        l10n.settingsAboutCheckUpdateFailed,
    };

/// 投屏失败
String castErrorText(AppLocalizations l10n, CastException e) =>
    switch (e.code) {
      CastErrorCode.deviceOffline => l10n.castDeviceOffline,
    };

/// 局域网媒体服务器失败
String lanMediaServerErrorText(
  AppLocalizations l10n,
  LanMediaServerException e,
) =>
    switch (e.code) {
      LanMediaServerErrorCode.noLanIpv4 => l10n.castNoLanIpv4,
      LanMediaServerErrorCode.fileMissing => l10n.castFileMissing,
    };
