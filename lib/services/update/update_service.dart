import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:moumou/models/update_info.dart';
import 'package:moumou/utils/version_compare.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App 更新服务（工作.md：更新功能）。
///
/// 更新源策略（应对部分地区 GitHub 被墙）：
/// 1. 主通道：GitHub Releases API（拿 tag_name / Markdown body）；
/// 2. 兜底通道：CDN 上的 version.json（jsDelivr 等国内可达镜像，尚未配置）。
///
/// [checkForUpdate] 取本地版本（package_info_plus）与远端版本（GitHub API），
/// 用 [needUpdate] 逐段整数比较：远端 > 本地 → 返回 [UpdateInfo]（弹窗）；
/// 相等或更低 → 返回 null（已是最新）；网络/解析失败抛 [UpdateCheckException]
/// （由调用方决定手动 toast 或自动静默）。
class UpdateService {
  UpdateService._();

  /// 仓库主页（关于页 GitHub 图标跳转）
  static const String repoUrl = 'https://github.com/azxcvn/xiaomiao-player';

  /// GitHub Releases 页面（人工查看 / 后续「查看详情」兜底跳转）
  static const String releasePageUrl =
      'https://github.com/azxcvn/xiaomiao-player/releases';

  /// 主更新源：GitHub Releases API（latest，返回 tag_name / Markdown body / 下载资产）
  static const String githubLatestUrl =
      'https://api.github.com/repos/azxcvn/xiaomiao-player/releases/latest';

  /// 兜底更新源：CDN 上的 version.json（应对 GitHub 被墙；尚未配置，留空）
  static const String mirrorVersionUrl = '';

  /// 主下载站链接（飞书在线文档）
  static const String primaryDownloadUrl =
      'https://acnmwaofo249.feishu.cn/wiki/XQe0wo2cwi6qOPkldcycm58jnmg?from=from_copylink';

  /// 备用下载站链接（B 站专栏）
  static const String backupDownloadUrl =
      'https://www.bilibili.com/opus/1205631426341371928';

  /// 测试/开发样例：带长 Markdown 正文的「新版本」，供弹窗样式验收。
  static const UpdateInfo devUpdate = UpdateInfo(
    version: '1.1.0',
    body: _devBody,
    primaryDownloadUrl: primaryDownloadUrl,
    backupDownloadUrl: backupDownloadUrl,
  );

  /// 检查更新（手动 / 自动共用）。
  ///
  /// [client] 与 [localVersion] 仅测试注入用（生产走真实 http 与 package_info）。
  /// - 返回 [UpdateInfo]：有更新；
  /// - 返回 null：已是最新；
  /// - 抛 [UpdateCheckException]：网络失败 / 解析失败 / 更新源未配置。
  static Future<UpdateInfo?> checkForUpdate({
    http.Client? client,
    String? localVersion,
  }) async {
    final local = localVersion ?? (await PackageInfo.fromPlatform()).version;
    final remote = await _fetchLatestRelease(client);
    if (remote == null) {
      throw const UpdateCheckException('获取远端版本信息失败');
    }
    if (!needUpdate(local, remote.version)) return null;
    return UpdateInfo(
      version: remote.version,
      body: remote.body,
      primaryDownloadUrl: primaryDownloadUrl,
      backupDownloadUrl: backupDownloadUrl,
    );
  }

  /// 按「GitHub API → version.json」顺序抓取远端版本与正文，都失败返回 null。
  static Future<({String version, String body})?> _fetchLatestRelease(
    http.Client? client,
  ) async {
    final github = await _fetchGithubLatest(client);
    if (github != null) return github;
    if (mirrorVersionUrl.isNotEmpty) {
      final mirror = await _fetchMirrorVersion(client);
      if (mirror != null) return mirror;
    }
    return null;
  }

  /// 抓取 GitHub Releases API 的 latest，解析 tag_name（版本）与 body（Markdown）。
  static Future<({String version, String body})?> _fetchGithubLatest(
    http.Client? client,
  ) async {
    if (githubLatestUrl.isEmpty) return null;
    try {
      final response = await _get(Uri.parse(githubLatestUrl), client);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final tag = decoded['tag_name'];
      if (tag is! String || tag.trim().isEmpty) return null;
      final rawBody = decoded['body'];
      return (
        version: _normalizeVersion(tag),
        body: rawBody is String && rawBody.trim().isNotEmpty ? rawBody : '暂无更新说明',
      );
    } catch (_) {
      return null;
    }
  }

  /// 抓取 CDN 上的 version.json（结构：{ "version": "1.3.3", "body": "..." }）。
  static Future<({String version, String body})?> _fetchMirrorVersion(
    http.Client? client,
  ) async {
    try {
      final response = await _get(Uri.parse(mirrorVersionUrl), client);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final version = decoded['version'];
      if (version is! String || version.trim().isEmpty) return null;
      final rawBody = decoded['body'];
      return (
        version: _normalizeVersion(version),
        body: rawBody is String && rawBody.trim().isNotEmpty ? rawBody : '暂无更新说明',
      );
    } catch (_) {
      return null;
    }
  }

  static const Map<String, String> _headers = {
    'User-Agent': 'xiaomiao-player',
    'Accept': 'application/vnd.github+json',
  };

  /// GET 请求；client 未注入时自建并用完即关（测试注入 MockClient 则不关）。
  static Future<http.Response> _get(Uri uri, http.Client? client) async {
    final ownsClient = client == null;
    final c = client ?? http.Client();
    try {
      return await c
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
    } finally {
      if (ownsClient) c.close();
    }
  }

  /// 去掉版本号前导 v（v1.3.3 → 1.3.3），供展示与「忽略本版本」持久化用。
  static String _normalizeVersion(String tag) {
    var v = tag.trim();
    if (v.toLowerCase().startsWith('v')) v = v.substring(1);
    return v;
  }

  /// 测试/开发样例更新说明（Markdown，验收 Markdown 渲染与滚动样式用）
  static const String _devBody = '''
## 更新内容

- **新增**：首次启动隐私政策弹窗 + 关于页「用户协议」
- **新增**：应用内检查更新（手动 + 自动）
- **优化**：更新说明支持 Markdown 渲染
- **修复**：若干已知问题

### 新功能详情

本次新增首次启动隐私政策弹窗：用户需等待 5 秒倒计时、勾选同意后方可进入应用；
未同意则无法使用。同时在「我的 → 关于」新增「用户协议」入口，可随时预览
《用户服务协议与隐私政策》全文。

### 检查更新

「我的 → 关于 → 更新」提供手动检查更新与自动检查更新开关。开启后每次启动 2 秒
自动检查新版本；更新弹窗支持 Markdown 渲染、忽略本版本与稍后提醒。

### 下载说明

点击「立即更新」后选择下载方式（主下载站 / 备用下载站），将跳转至对应网盘分享页，
您可自由选择最适合自己的下载渠道。

### 已知问题

- 部分机型首次启动权限申请可能延迟，请耐心等待。

> 本应用开源免费，无广告、无收费。如遇收费或广告，请立即停止使用并甄别来源。
''';
}

/// 检查更新失败异常（网络失败 / 解析失败 / 更新源未配置）
class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);

  @override
  String toString() => 'UpdateCheckException: $message';
}
