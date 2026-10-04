import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/bili_image_cache_service.dart';

/// 哔哩封面磁盘缓存测试。
///
/// 用**真实本地 HTTP 服务**当图床（不用 mock）：这样能一并验证「下载 → 写临时
/// 文件 → 改名」这条真实落盘路径，以及「同一 URL 并发只发一次请求」的去重。
///
/// **不要在这里 `TestWidgetsFlutterBinding.ensureInitialized()`**：该 binding 初始化
/// 时会装 `_MockHttpOverrides`（`flutter_test/src/_binding_io.dart`），此后所有 HTTP
/// 请求一律返回 400、真实网络请求根本不发 —— 本文件的本地图床就永远连不上
/// （曾表现为 6 个用例全挂：`Expected: not null / Actual: <null>`、`requests` 恒为 0）。
/// 本文件只用普通 `test()`，不需要 widget binding。
void main() {
  late Directory tempDir;
  late HttpServer server;
  late String baseUrl;
  var requests = 0;

  /// 1×1 的合法 PNG 字节（内容不重要，只要非空且能落盘）
  final pngBytes = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  setUp(() async {
    requests = 0;
    tempDir = await Directory.systemTemp.createTemp('bili_covers_test_');
    BiliImageCacheService.debugDirectoryOverride = () async => tempDir;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    unawaited(() async {
      await for (final request in server) {
        requests++;
        try {
          if (request.uri.path.contains('missing')) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            continue;
          }
          request.response.headers.contentType = ContentType('image', 'webp');
          request.response.add(pngBytes);
          await request.response.close();
        } catch (_) {
          // 客户端提前断开（下载被取消）不影响测试断言
        }
      }
    }());
  });

  tearDown(() async {
    BiliImageCacheService.debugDirectoryOverride = null;
    await server.close(force: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('首次下载落盘，第二次直接命中磁盘（不再发请求）', () async {
    final url = '$baseUrl/cover.jpg@320w_400h_1c.webp';

    final first = await BiliImageCacheService.download(url, width: 320, height: 400);
    expect(first, isNotNull);
    expect(await first!.exists(), isTrue);
    expect(await first.readAsBytes(), pngBytes);
    expect(requests, 1);

    final second = await BiliImageCacheService.download(url, width: 320, height: 400);
    expect(second, isNotNull);
    expect(second!.path, first.path);
    // 关键断言：命中磁盘后不再发第二次请求（真机「退出再进不重下」的依据）
    expect(requests, 1);
  });

  test('同一 URL 并发请求只发一次（在飞去重）', () async {
    final url = '$baseUrl/same.jpg@320w_400h_1c.webp';
    final results = await Future.wait([
      BiliImageCacheService.download(url, width: 320, height: 400),
      BiliImageCacheService.download(url, width: 320, height: 400),
      BiliImageCacheService.download(url, width: 320, height: 400),
      BiliImageCacheService.download(url, width: 320, height: 400),
    ]);
    expect(results.whereType<File>().length, 4);
    expect(results.map((f) => f!.path).toSet().length, 1);
    expect(requests, 1);
  });

  test('同一张图不同尺寸是两份缓存（小图不能糊大屏）', () async {
    final small = '$baseUrl/a.jpg@240w_320h_1c.webp';
    final large = '$baseUrl/a.jpg@320w_400h_1c.webp';
    final f1 = await BiliImageCacheService.download(small, width: 240, height: 320);
    final f2 = await BiliImageCacheService.download(large, width: 320, height: 400);
    expect(f1!.path, isNot(f2!.path));
    // 两个不同 URL 各发一次
    expect(requests, 2);
  });

  test('HTTP 非 200 不落盘，返回 null（不抛异常）', () async {
    final url = '$baseUrl/missing.jpg@320w_400h_1c.webp';
    final file = await BiliImageCacheService.download(url, width: 320, height: 400);
    expect(file, isNull);
    expect(requests, 1);
    // 目录里不该留下垃圾文件（临时 .part 也要清干净）
    final names = await tempDir.list().map((e) => e.path).toList();
    expect(names, isEmpty);
  });

  test('0 字节残留文件按未命中处理并清掉', () async {
    final url = '$baseUrl/corrupt.jpg@320w_400h_1c.webp';
    final good = await BiliImageCacheService.download(url, width: 320, height: 400);
    expect(good, isNotNull);

    // 模拟「上轮写盘中途被杀」：把文件截成 0 字节
    await good!.writeAsBytes(const []);
    final again = await BiliImageCacheService.download(url, width: 320, height: 400);
    expect(again, isNotNull);
    expect(await again!.length(), greaterThan(0));
    // 需要重新下载一次才能修复
    expect(requests, 2);
  });

  test('体积统计与清理', () async {
    final url = '$baseUrl/size.jpg@320w_400h_1c.webp';
    await BiliImageCacheService.download(url, width: 320, height: 400);
    final size = await BiliImageCacheService.cacheSizeBytes();
    expect(size, pngBytes.length);

    await BiliImageCacheService.clearCache();
    expect(await BiliImageCacheService.cacheSizeBytes(), 0);
    // 目录本身保留（下次写入不必重建）
    expect(await tempDir.exists(), isTrue);
  });

  test('目录不存在时统计为 0，不抛异常', () async {
    final gone = Directory('${tempDir.path}_not_exists');
    BiliImageCacheService.debugDirectoryOverride = () async => gone;
    // tearDown 依赖 tempDir 真实存在，这里用完立刻还原覆盖
    addTearDown(() {
      BiliImageCacheService.debugDirectoryOverride = () async => tempDir;
    });
    expect(await BiliImageCacheService.cacheSizeBytes(), 0);
    expect(await BiliImageCacheService.cachedFile('$baseUrl/x.jpg'), isNull);
  });
}
