/// 更新信息值对象（工作.md：更新功能）。
///
/// 纯数据模型：新版本号、Markdown 更新说明、主/备用下载站链接。
class UpdateInfo {
  /// 新版本号（如 `1.1.0`）
  final String version;

  /// 更新说明正文（Markdown 格式，弹窗用 flutter_markdown 渲染）
  final String body;

  /// 主下载站链接（待接入时为空字符串）
  final String primaryDownloadUrl;

  /// 备用下载站链接（待接入时为空字符串）
  final String backupDownloadUrl;

  const UpdateInfo({
    required this.version,
    required this.body,
    this.primaryDownloadUrl = '',
    this.backupDownloadUrl = '',
  });
}
