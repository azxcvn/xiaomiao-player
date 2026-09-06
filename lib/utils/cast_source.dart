/// 投屏源分类纯函数：判定当前播放来源能否投屏、属于哪一类。
///
/// P0 仅支持「本地文件」（绝对路径 / file://）；在线直链（P1）、loopback
/// 代理 URL（网络存储 / B 站代理，127.0.0.1 电视不可达）与 content://
/// 首期均不支持。无 Flutter 依赖，可单测。
library;

/// 投屏来源分类。
enum CastSource {
  /// 本地文件（绝对路径 / file://）：P0 唯一支持，经 LanMediaServer 暴露为 LAN URL
  localFile,

  /// 在线直链（http/https 非 loopback）：P1 支持，直接推 URL
  remoteUrl,

  /// loopback 代理 URL（127.0.0.1/localhost：网络存储 / B 站代理）：电视不可达
  loopback,

  /// content:// 等需平台通道解析的来源：首期不支持
  unsupported,
}

/// 是否为 loopback 主机（电视不可达）：127.0.0.1 / localhost / ::1 / 0.0.0.0。
bool isLoopbackHost(String host) {
  final h = host.toLowerCase();
  return h == '127.0.0.1' ||
      h == 'localhost' ||
      h == '::1' ||
      h == '0.0.0.0';
}

/// 是否为 loopback URL。
bool isLoopbackUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return isLoopbackHost(uri.host);
}

/// 按播放来源路径分类（本地文件 / 在线直链 / loopback / 不支持）。
CastSource classifyCastSource(String path) {
  final trimmed = path.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return isLoopbackUrl(trimmed) ? CastSource.loopback : CastSource.remoteUrl;
  }
  if (lower.startsWith('content://')) return CastSource.unsupported;
  // 其余（绝对路径 / file:// / 相对路径）视为本地文件
  return CastSource.localFile;
}

/// 把本地来源转成可直接交给 dart:io File 的路径（file:// 去掉前缀）。
/// 非本地来源返回 null（调用方应先经 [classifyCastSource] 判定）。
String? localFilePath(String path) {
  if (classifyCastSource(path) != CastSource.localFile) return null;
  if (path.toLowerCase().startsWith('file://')) {
    return path.substring('file://'.length);
  }
  return path;
}
