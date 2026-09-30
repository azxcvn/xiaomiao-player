import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 哔哩哔哩封面图磁盘缓存。
///
/// 为什么需要：列表封面此前只用 `Image.network`（仅内存缓存），退出再加返回
/// 上级页、或下拉刷新重建列表时，整屏封面会**重新下载一遍**（真机表现为瞬时
/// 大流量）。本服务把图片按 URL 落盘到 `filesDir/bili_covers/`，二次进入直接
/// 命中磁盘。
///
/// 与图床裁剪的分工：URL 侧的 `@<w>w_<h>h_1c.webp` 后缀负责「下小图」
/// （见 `utils/bili_image_url.dart`），本服务负责「下过就不再下」。
///
/// 命名：`<url 的 sha1 前 20 位>-<w>x<h>.<ext>` —— 同一张图的不同尺寸是两份
/// 文件（尺寸变了要重新取，不能拿小图糊大屏）；URL 里含会话 token 时靠哈希
/// 归一，避免文件名非法字符。
class BiliImageCacheService {
  BiliImageCacheService._();

  /// 同时写入的最大并发（多余请求排队，避免退出页面瞬间几十个写盘）
  static const int _maxWrites = 4;

  /// 单张图上限：小于等于 0 字节视为坏文件；超过该值不落盘（防异常大图）
  static const int _maxBytes = 4 * 1024 * 1024;

  /// 测试用：覆盖落盘目录解析
  static Future<Directory?> Function()? debugDirectoryOverride;

  static int _inFlightWrites = 0;
  static final Queue<Completer<void>> _writeQueue = Queue<Completer<void>>();

  /// 落盘目录：`filesDir/bili_covers/`（getApplicationSupportDirectory 在
  /// Android 上即 filesDir，与 danmaku/ 目录同级）。
  static Future<Directory?> directory() async {
    final override = debugDirectoryOverride;
    if (override != null) return override();
    try {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'bili_covers'));
    } catch (_) {
      return null;
    }
  }

  /// 缓存占用字节数（目录不存在/不可读返回 0；供缓存管理页展示）
  static Future<int> cacheSizeBytes() async {
    try {
      final dir = await directory();
      if (dir == null || !await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // 单个文件读不到不影响统计
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 清空封面缓存（只删目录内文件，保留目录本身）。
  /// 这些图是「看过就有、丢了会重新下载」的派生数据。
  static Future<void> clearCache() async {
    try {
      final dir = await directory();
      if (dir == null || !await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // 单个文件删不掉不影响整体清理
          }
        }
      }
    } catch (_) {
      // 清理失败静默：缓存是派生数据
    }
  }

  /// 读取缓存文件；未命中返回 null。
  static Future<File?> cachedFile(String url, {int? width, int? height}) async {
    try {
      final dir = await directory();
      if (dir == null) return null;
      final file = _fileFor(dir, url, width, height);
      if (!await file.exists()) return null;
      // 上一轮写盘中途被杀会留下 0 字节残file：按未命中处理并顺手删掉
      final len = await file.length();
      if (len == 0) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  /// 下载并落盘（已存在则直接返回），返回文件；失败返回 null（不抛异常）。
  ///
  /// 同一 URL 的并发请求共享同一次下载（在飞去重）：一屏二十张卡同时构建时
  /// 不会对同一张图发多次请求。
  static Future<File?> download(
    String url, {
    int? width,
    int? height,
    HttpClient? client,
  }) async {
    final existing = await cachedFile(url, width: width, height: height);
    if (existing != null) return existing;

    return _singleFlight('$url|$width|$height', () async {
      // 双检：等待期间别的请求可能已经写完
      final again = await cachedFile(url, width: width, height: height);
      if (again != null) return again;

      final dir = await directory();
      if (dir == null) return null;
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
      } catch (_) {
        return null;
      }

      // 写盘/下载并发闸门：一屏二十张卡同时构建时不让二十个请求一起打出去
      final lease = await _acquireWriteSlot();
      final http = client ?? (HttpClient()..autoUncompress = false);
      final ownsClient = client == null;
      try {
        final request = await http.getUrl(Uri.parse(url));
        request.headers.set(
            HttpHeaders.refererHeader, 'https://www.bilibili.com');
        request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) return null;

        // 先写临时文件、成功后再改名：避免写一半被杀留下半个 JPEG
        final target = _fileFor(dir, url, width, height);
        final temp = File('${target.path}.part');
        final sink = temp.openWrite();
        var written = 0;
        var tooBig = false;
        try {
          await for (final chunk in response) {
            written += chunk.length;
            if (written > _maxBytes) {
              tooBig = true;
              break;
            }
            sink.add(chunk);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (tooBig || written == 0) {
          await _deleteQuietly(temp);
          return null;
        }
        await temp.rename(target.path);
        return target;
      } catch (_) {
        return null;
      } finally {
        if (ownsClient) http.close(force: true);
        lease.release();
      }
    });
  }

  /// 在飞去重（key = url + 尺寸）。
  ///
  /// 必须在**创建下载前**同步登记：若等 `body()` 返回 Future 后再登记，同批
  /// 并发的第二个调用会在 await 恢复时看到 `_inFlight` 已被清空，从而重复下载
  /// （一屏二十张卡同时构建时去重就失效了）。
  static final Map<String, Future<File?>> _inFlight = {};

  static Future<File?> _singleFlight(
    String key,
    Future<File?> Function() body,
  ) {
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final completer = Completer<File?>();
    _inFlight[key] = completer.future;
    () async {
      try {
        completer.complete(await body());
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _inFlight.remove(key);
      }
    }();
    return completer.future;
  }

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// 缓存文件名：`<sha1 前 20 位>[-<w>x<h>].<ext>`
  static File _fileFor(Directory dir, String url, int? width, int? height) {
    final digest = sha1.convert(utf8.encode(url)).toString().substring(0, 20);
    final size = (width != null && height != null) ? '-${width}x$height' : '';
    final ext = _extensionOf(url);
    return File(p.join(dir.path, '$digest$size.$ext'));
  }

  /// 从 URL 推断扩展名（图床后缀里的 `.webp` 优先，否则按路径末段）
  static String _extensionOf(String url) {
    final m = RegExp(r'\.(webp|jpg|jpeg|png|gif|avif)(?:$|[?#])',
            caseSensitive: false)
        .firstMatch(url);
    if (m != null) {
      final e = m.group(1)!.toLowerCase();
      return e == 'jpeg' ? 'jpg' : e;
    }
    return 'img';
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 写盘并发闸门（超过 [_maxWrites] 的请求排队）
  static Future<_CacheLease> _acquireWriteSlot() async {
    if (_inFlightWrites < _maxWrites) {
      _inFlightWrites++;
      return _CacheLease._();
    }
    final completer = Completer<void>();
    _writeQueue.add(completer);
    await completer.future;
    _inFlightWrites++;
    return _CacheLease._();
  }

  static void _releaseWriteSlot() {
    _inFlightWrites--;
    if (_writeQueue.isNotEmpty) {
      final next = _writeQueue.removeFirst();
      if (!next.isCompleted) next.complete();
    }
  }
}

/// 写盘槽位租约（用 try/finally 保证释放）
class _CacheLease {
  bool _released = false;

  _CacheLease._();

  void release() {
    if (_released) return;
    _released = true;
    BiliImageCacheService._releaseWriteSlot();
  }
}
