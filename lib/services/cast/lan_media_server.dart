/// 局域网媒体服务器：把本地文件暴露为电视可达的 `http://<LAN_IP>:<port>/<token>`。
///
/// 对齐 mpvRx CastMediaServer.kt + moumou NetworkStreamingProxy 的 Range 实现：
/// 绑 `0.0.0.0` 随机端口 + token 路径 + GET/HEAD + Range 分段 + CORS 头；
/// 单文件单 token、expose 前 stop 旧的、播放页退出时释放端口（电视自己 GET 拉流）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:moumou/utils/http_byte_range.dart';
import 'package:moumou/utils/network_mime_types.dart';

/// 判断 IPv4 是否为站点本地地址（192.168/10./172.16-31），供 LAN IP 挑选。
bool isSiteLocalIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == null || b == null) return false;
  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}

/// 从网卡列表挑选站点本地 IPv4（排除回环）；找不到返回 null。
Future<String> discoverLanIp() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      if (isSiteLocalIpv4(addr.address)) return addr.address;
    }
  }
  throw StateError('未找到局域网 IPv4 地址');
}

class LanMediaServer {
  static final LanMediaServer instance = LanMediaServer();

  /// 绑定地址（默认 0.0.0.0；测试可注入 loopback）
  final InternetAddress bindAddress;

  /// 局域网 IPv4 解析器（默认 [discoverLanIp]；测试可注入固定值）
  final Future<String> Function() lanIpResolver;

  LanMediaServer({
    InternetAddress? bindAddress,
    Future<String> Function()? lanIpResolver,
  })  : bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        lanIpResolver = lanIpResolver ?? discoverLanIp;

  HttpServer? _server;
  String? _token;
  File? _file;
  final Random _random = Random.secure();

  bool get isRunning => _server != null;

  /// 暴露本地文件为 LAN URL；再次调用前会 stop 旧的（单文件单 token）。
  Future<String> expose(String filePath) async {
    await stop();
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }
    final ip = await lanIpResolver();
    final token = _generateToken();
    final server = await HttpServer.bind(bindAddress, 0);
    _file = file;
    _token = token;
    _server = server;
    server.listen(_handle);
    return 'http://$ip:${server.port}/$token';
  }

  /// 释放端口并清 token（幂等；播放页退出 / 重新 expose 时调用）。
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = null;
    _file = null;
    await server?.close(force: true);
  }

  String _generateToken() {
    String token;
    do {
      final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
      token = base64Url.encode(bytes).replaceAll('=', '');
    } while (token == _token);
    return token;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    _applyCors(response);
    // token 校验：path 必须 == /<token>（token 只进内存、不进 URL/日志）
    if (request.uri.path != '/$_token') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.headers.set('Allow', 'GET, HEAD, OPTIONS');
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    final file = _file;
    if (file == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    await _serve(request, file);
  }

  Future<void> _serve(HttpRequest request, File file) async {
    final response = request.response;
    final headOnly = request.method == 'HEAD';
    final size = await file.length();
    final mime = networkMimeTypeForFileName(file.path) ?? 'application/octet-stream';

    response.headers.set('Accept-Ranges', 'bytes');
    _contentType(response, mime);

    final rangeHeader = request.headers.value('range');
    int start = 0;
    int? end; // null = 到结尾
    if (rangeHeader != null) {
      final range = HttpByteRange.parse(rangeHeader, size);
      if (range == null) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set('Content-Range', 'bytes */$size');
        await response.close();
        return;
      }
      start = range.start;
      end = range.endInclusive + 1;
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(
        'Content-Range',
        'bytes ${range.start}-${range.endInclusive}/$size',
      );
      response.contentLength = range.length;
    } else {
      response.statusCode = HttpStatus.ok;
      response.contentLength = size;
    }

    if (headOnly) {
      await response.close();
      return;
    }

    try {
      await response.addStream(file.openRead(start, end));
      await response.close();
    } catch (_) {
      // 客户端中止（电视断开）时写入会抛，忽略。
      await response.close();
    }
  }

  void _applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Range, Content-Type');
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Content-Range, Accept-Ranges, Content-Length',
    );
  }

  void _contentType(HttpResponse response, String mime) {
    try {
      response.headers.contentType = ContentType.parse(mime);
    } catch (_) {
      response.headers.contentType = ContentType.binary;
    }
  }
}
