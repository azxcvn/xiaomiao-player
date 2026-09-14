import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/services/cache_manager_service.dart';
import 'package:moumou/services/dandan_play_api.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_server_settings.dart';
import 'package:moumou/utils/danmaku_xml.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕网络服务测试：文件名清洗、搜索合并、下载落盘（持久化）。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DanmakuServerSettings.instance.resetForTest();
    DanmakuNetworkService.debugDirectoryOverride = null;
  });

  group('networkDanmakuFileName', () {
    test('保留中文/字母/数字/下划线，追加 .xml', () {
      expect(
        networkDanmakuFileName('紫罗兰永恒花园', '第01话', 42),
        '紫罗兰永恒花园_第01话_42.xml',
      );
    });

    test('非法字符（空格/中括号/短横等）替换为下划线', () {
      final name =
          networkDanmakuFileName('[B-Global] Violet Evergarden', 'EP 01 [1080p]', 7);
      final base = name.substring(0, name.length - 4); // 去掉 .xml
      expect(RegExp(r'[^a-zA-Z0-9_\u4e00-\u9fa5]').hasMatch(base), isFalse);
      expect(base.contains('Violet'), isTrue);
      expect(base.contains('1080p'), isTrue);
      expect(base.contains('_7'), isTrue);
    });
  });

  group('search 合并（MockClient）', () {
    test('默认+自建服务器结果合并，animeId 去重，记录来源服务器', () async {
      final api = DandanPlayApi(
        client: MockClient((request) async {
          if (request.url.host == 'api.dandanplay.net') {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'animes': [
                  _animeJson(1, '番剧A', [
                    _epJson(11, '第01话'),
                  ]),
                ],
              })),
              200,
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'animes': [
                _animeJson(1, '番剧A', [
                  _epJson(11, '第01话'),
                ]),
                _animeJson(2, '番剧B', [
                  _epJson(22, '第02话'),
                ]),
              ],
            })),
            200,
          );
        }),
      );
      final service = DanmakuNetworkService(api: api);
      await DanmakuServerSettings.instance.addServer('我的服务器', 'https://self.example.com');

      final result = await service.search('关键词');
      expect(result.items.length, 2);
      expect(result.items[0].anime.animeId, 1);
      expect(result.items[0].serverUrl, isNull); // 默认服务器先到先得
      expect(result.items[0].serverName, DanmakuServerSettings.instance.servers.first.name);
      expect(result.items[1].anime.animeId, 2);
      expect(result.items[1].serverUrl, 'https://self.example.com');
      expect(result.items[1].serverName, '我的服务器');
      expect(result.errors, isEmpty);
    });

    test('单服务器失败记录错误，不阻断其余服务器结果', () async {
      final api = DandanPlayApi(
        client: MockClient((request) async {
          if (request.url.host == 'api.dandanplay.net') {
            return http.Response('server error', 500);
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'animes': [
                _animeJson(2, '番剧B', [
                  _epJson(22, '第02话'),
                ]),
              ],
            })),
            200,
          );
        }),
      );
      final service = DanmakuNetworkService(api: api);
      await DanmakuServerSettings.instance.addServer('我的服务器', 'https://self.example.com');

      final result = await service.search('关键词');
      expect(result.items.length, 1);
      expect(result.items.single.anime.animeId, 2);
      expect(result.errors.length, 1);
      expect(result.errors.single, contains('弹弹Play'));
    });
  });

  group('downloadEpisode 落盘（持久化）', () {
    test('拉取 → 条目 + B站 XML 落盘 → 可回读解析', () async {
      final tmp = await Directory.systemTemp.createTemp('danmaku_net');
      DanmakuNetworkService.debugDirectoryOverride =
          () async => Directory(p.join(tmp.path, 'network'));

      final api = DandanPlayApi(
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'count': 2,
              'comments': [
                {'cid': 1, 'p': '1.500,1,16777215,u', 'm': '前方高能'},
                {'cid': 2, 'p': '60.000,5,65280,u', 'm': '顶部弹幕'},
              ],
            })),
            200,
          );
        }),
      );
      final service = DanmakuNetworkService(api: api);
      final download = await service.downloadEpisode(
        episodeId: 42,
        animeTitle: '紫罗兰永恒花园',
        episodeTitle: '第01话',
      );

      expect(download.entries.map((e) => e.text).toList(), ['前方高能', '顶部弹幕']);
      expect(download.filePathOrNull, isNotNull);
      final content = await File(download.filePathOrNull!).readAsString();
      expect(
        parseDanmakuXml(content).map((e) => e.text).toList(),
        ['前方高能', '顶部弹幕'],
      );

      await tmp.delete(recursive: true);
    });

    test('目录不可用（无 path_provider）仍返回条目，filePath 为 null', () async {
      // 不注入目录覆盖 → getApplicationSupportDirectory 在测试环境抛
      // MissingPluginException，落盘失败但不影响本次播放。
      final api = DandanPlayApi(
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'count': 1,
              'comments': [
                {'cid': 1, 'p': '1.0,1,255,u', 'm': '单条'},
              ],
            })),
            200,
          );
        }),
      );
      final service = DanmakuNetworkService(api: api);
      final download = await service.downloadEpisode(
        episodeId: 1,
        animeTitle: '番剧',
        episodeTitle: '第01话',
      );
      expect(download.entries.single.text, '单条');
      expect(download.filePathOrNull, isNull);
    });

    test('空弹幕不落盘', () async {
      final tmp = await Directory.systemTemp.createTemp('danmaku_net2');
      DanmakuNetworkService.debugDirectoryOverride =
          () async => Directory(p.join(tmp.path, 'network'));
      final api = DandanPlayApi(
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'count': 0, 'comments': []})),
            200,
          );
        }),
      );
      final service = DanmakuNetworkService(api: api);
      final download = await service.downloadEpisode(
        episodeId: 1,
        animeTitle: '番剧',
        episodeTitle: '第01话',
      );
      expect(download.entries, isEmpty);
      expect(download.filePathOrNull, isNull);

      await tmp.delete(recursive: true);
    });
  });

  group('客户端生命周期（P2-11）', () {
    test('close 幂等，isClosed 置位', () {
      final api = DandanPlayApi();
      expect(api.isClosed, isFalse);
      api.close();
      expect(api.isClosed, isTrue);
      api.close(); // 二次调用不抛
      expect(api.isClosed, isTrue);
    });

    test('注入的 client 由调用方负责：close 不关它', () {
      final client = _TrackingClient();
      final api = DandanPlayApi(client: client);
      api.close();
      expect(api.isClosed, isTrue);
      expect(client.closed, isFalse, reason: '别人的连接池不能替别人关');
    });

    test('DanmakuNetworkService.dispose 释放底层 API', () {
      final api = DandanPlayApi(client: _TrackingClient());
      final service = DanmakuNetworkService(api: api);
      expect(api.isClosed, isFalse);
      service.dispose();
      expect(api.isClosed, isTrue);
    });

    test('自建 client 的 API：close 关闭自己的连接池', () {
      final api = DandanPlayApi(client: _TrackingClient());
      // 注入路径已验证「不关注入的」；这里覆盖自建分支的可观测语义
      final owned = DandanPlayApi();
      owned.close();
      expect(owned.isClosed, isTrue);
      api.close();
    });
  });

  group('响应解码容错（§3-12）', () {
    test('畸形 UTF-8 不再让 FormatException 逃出类契约', () async {
      final api = DandanPlayApi(
        client: MockClient((_) async => http.Response.bytes(
              // 非法 UTF-8 序列 + 合法 JSON 片段
              [0xFF, 0xFE, 0x7B, 0x7D],
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      await expectLater(
        api.getComments(1),
        throwsA(isA<DandanApiException>()),
        reason: '必须是本类异常（调用方只 catch 它），不能是裸 FormatException',
      );
    });
  });

  group('网络弹幕缓存清理（§3-14）', () {
    test('cacheSizeBytes / clearCache 只删文件、保留目录', () async {
      final tmp = await Directory.systemTemp.createTemp('danmaku_cache_');
      DanmakuNetworkService.debugDirectoryOverride = () async => tmp;
      addTearDown(() async {
        DanmakuNetworkService.debugDirectoryOverride = null;
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      });

      expect(await DanmakuNetworkService.cacheSizeBytes(), 0);
      await File(p.join(tmp.path, 'a.xml')).writeAsString('<i/>');
      await File(p.join(tmp.path, 'b.xml')).writeAsString('<i/>');
      expect(await DanmakuNetworkService.cacheSizeBytes(), 8);

      await DanmakuNetworkService.clearCache();
      expect(await DanmakuNetworkService.cacheSizeBytes(), 0);
      expect(tmp.existsSync(), isTrue, reason: '只清文件，目录保留');
      // 幂等
      await DanmakuNetworkService.clearCache();
    });

    test('缓存管理类别包含网络弹幕，且清它走 Dart 侧', () async {
      final tmp = await Directory.systemTemp.createTemp('danmaku_cache_');
      DanmakuNetworkService.debugDirectoryOverride = () async => tmp;
      addTearDown(() async {
        DanmakuNetworkService.debugDirectoryOverride = null;
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      });
      await File(p.join(tmp.path, 'a.xml')).writeAsString('<i/>');

      expect(
        CacheManagerService.all.map((c) => c.key),
        contains(CacheManagerService.networkDanmaku.key),
      );
      expect(
        (await CacheManagerService.getCacheSizes())[
            CacheManagerService.networkDanmaku.key],
        4,
      );
      expect(
        await CacheManagerService.clearCategory(CacheManagerService.networkDanmaku),
        isTrue,
      );
      expect(await DanmakuNetworkService.cacheSizeBytes(), 0);
    });
  });
}

/// 记录 close 是否被调用（`MockClient` 的 close 是空实现，观测不到）
class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 200);

  @override
  void close() {
    closed = true;
    super.close();
  }
}

Map<String, dynamic> _animeJson(
        int id, String title, List<Map<String, dynamic>> episodes) =>
    {
      'animeId': id,
      'animeTitle': title,
      'type': 'tv',
      'typeDescription': 'TV',
      'episodes': episodes,
    };

Map<String, dynamic> _epJson(int id, String title) =>
    {'episodeId': id, 'episodeTitle': title};
