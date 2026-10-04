import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// https 播放所需的 CA 证书库（把 assets 里的证书库拷到沙盒，供 mpv 使用）。
///
/// **为什么必须这么做**（2026-10 实测定位）：
/// 本项目的自编 `libmpv.so` 静态链接的是 **mbedTLS**，而 ffmpeg 的 mbedTLS 后端
/// **没有默认证书库路径**——OpenSSL 会去读系统证书库，mbedTLS 不会，必须由调用方
/// 显式给 `ca_file`。实测 `libmpv.so` 里 `mbedtls_x509_crt_parse_file` 与
/// `ca_file` / `tls-ca-file` 都在，但 `/etc/ssl/certs/ca-certificates.crt`、
/// `cacert.pem` 这类默认路径**一个都没有**。
///
/// 后果：**所有 https 源都在证书校验阶段失败**，而 http 完全正常。表现为
/// 「在线直链打开后 0 字节、无限转圈」（本地文件不受影响）。B 站与网络存储
/// 之所以没暴露这个问题，是因为它们各自走本地回环代理（`bili_stream_proxy` /
/// `network_streaming_proxy`），由 Dart 的 BoringSSL 去完成 TLS；**只有
/// 「打开链接 / 外部直链」这条路把 URL 直接交给 mpv**。
///
/// 兜底做法：`assets/certs/cacert.pem`（Mozilla 根证书库）拷到
/// `getApplicationSupportDirectory()`，再由 [applyPlaybackTuning] 在 `open` 之前
/// 写 mpv 属性 `tls-ca-file`（mpv 会把它转成 ffmpeg 的 `ca_file`）。
///
/// 拷贝失败一律返回 null（调用方不写该属性）：**宁可维持现状，也不能让调参
/// 阻断起播**。证书校验保持开启，不为了让 https 通而关掉校验。
class TlsCaBundle {
  /// 随包分发的证书库：Mozilla CA bundle，取自 `https://curl.se/ca/cacert.pem`
  /// （2026-10 下载，121 张根证书）。需要更新时重新下载覆盖即可。
  static const String assetPath = 'assets/certs/cacert.pem';

  /// 落盘文件名
  static const String fileName = 'cacert.pem';

  static String? _cachedPath;
  static Future<String?>? _inFlight;

  /// 返回沙盒内证书库的绝对路径；不可用（无平台实现 / 资源缺失 / 写盘失败）返回 null。
  ///
  /// 结果缓存：只会从 assets 拷一次；文件大小与资源一致时也不重复写。
  static Future<String?> ensurePath() {
    final cached = _cachedPath;
    if (cached != null) return Future.value(cached);
    final running = _inFlight;
    if (running != null) return running;
    final future = _copyToSandbox();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  static Future<String?> _copyToSandbox() async {
    try {
      final support = await getApplicationSupportDirectory();
      final file = File(p.join(support.path, fileName));
      final data = await rootBundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      var needWrite = true;
      try {
        needWrite = !await file.exists() || await file.length() != bytes.length;
      } catch (_) {
        needWrite = true;
      }
      if (needWrite) {
        await file.writeAsBytes(bytes, flush: true);
      }
      _cachedPath = file.path;
      return file.path;
    } catch (e) {
      debugPrint('TlsCaBundle: 准备 CA 证书库失败（https 直链将失败）: $e');
      return null;
    }
  }

  /// 测试用：清掉缓存，重新走一遍解析
  @visibleForTesting
  static void resetForTest() {
    _cachedPath = null;
    _inFlight = null;
  }
}
