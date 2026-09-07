import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';

/// Wyzie 字幕 API 客户端测试（MockClient）：来源拉取、关键词→TMDB 解析→搜索、
/// 参数拼接、400 无字幕特判、非 2xx 抛异常、文件字节下载。
void main() {
  http.Response jsonResponse(Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );

  test('getSources：带 key 参数 + 解析 tiered/free/paid/key', () async {
    late Uri captured;
    final api = WyzieApi(
      client: MockClient((req) async {
        captured = req.url;
        return jsonResponse({
          'sources': ['bravo'],
          'free': ['bravo'],
          'paid': ['charlie'],
          'tiered': [
            {'key': 'bravo', 'name': 'OpenSubtitles', 'tier': 'free'},
            {'key': 'charlie', 'name': 'Subf2m', 'tier': 'paid'},
          ],
          'allFree': false,
          'key': {'valid': true, 'type': 'pro'},
        });
      }),
    );

    final resp = await api.getSources(apiKey: 'wyzie-test');
    expect(captured.path, '/sources');
    expect(captured.queryParameters['key'], 'wyzie-test');
    expect(resp.tiered.length, 2);
    expect(resp.tiered.first.name, 'OpenSubtitles');
    expect(resp.free, ['bravo']);
    expect(resp.paid, ['charlie']);
    expect(resp.key?.valid, isTrue);
  });

  test('search：关键词先 TMDB 解析再 /search，查询参数齐全', () async {
    final urls = <Uri>[];
    final api = WyzieApi(
      client: MockClient((req) async {
        urls.add(req.url);
        if (req.url.path == '/api/tmdb/search') {
          return jsonResponse({
            'results': [
              {'id': 123, 'mediaType': 'movie', 'title': 'Inception'},
            ],
          });
        }
        return jsonResponse([
          {
            'url': 'https://x/sub.srt',
            'format': 'srt',
            'language': 'en',
            'media': 'Inception',
            'source': 'opensubtitles',
          },
        ]);
      }),
    );

    final results = await api.search(
      query: 'Inception',
      apiKey: 'k',
      language: 'en,zh',
      format: 'srt,ass',
      encoding: 'utf-8',
      source: 'bravo',
    );

    expect(urls.length, 2);
    expect(urls[0].path, '/api/tmdb/search');
    expect(urls[0].queryParameters['q'], 'Inception');
    expect(urls[1].path, '/search');
    expect(urls[1].queryParameters['id'], '123');
    expect(urls[1].queryParameters['language'], 'en,zh');
    expect(urls[1].queryParameters['format'], 'srt,ass');
    expect(urls[1].queryParameters['encoding'], 'utf-8');
    expect(urls[1].queryParameters['source'], 'bravo');
    expect(urls[1].queryParameters['unzip'], 'true');
    expect(urls[1].queryParameters['key'], 'k');
    expect(results.single.media, 'Inception');
  });

  test('search：source=all 不带 source 参数，tt 号直用不请求 TMDB', () async {
    final paths = <String>[];
    final api = WyzieApi(
      client: MockClient((req) async {
        paths.add(req.url.path);
        return jsonResponse([]);
      }),
    );
    await api.search(query: 'tt1375666', source: 'all');
    expect(paths, ['/search']);
  });

  test('search：400 No subtitles found → 空列表', () async {
    final api = WyzieApi(
      client: MockClient((req) async {
        if (req.url.path == '/api/tmdb/search') {
          return jsonResponse({
            'results': [
              {'id': 1},
            ],
          });
        }
        return http.Response('No subtitles found', 400);
      }),
    );
    expect(await api.search(query: 'Inception'), isEmpty);
  });

  test('search：TMDB 无命中 → 抛 WyzieApiException', () async {
    final api = WyzieApi(
      client: MockClient((req) async => jsonResponse({'results': []})),
    );
    await expectLater(
      api.search(query: 'zzzz'),
      throwsA(isA<WyzieApiException>()),
    );
  });

  test('search：非 2xx → 抛 WyzieApiException', () async {
    final api = WyzieApi(
      client: MockClient((req) async {
        if (req.url.path == '/api/tmdb/search') {
          return jsonResponse({
            'results': [
              {'id': 1},
            ],
          });
        }
        return http.Response('server error', 500);
      }),
    );
    await expectLater(
      api.search(query: 'Inception'),
      throwsA(isA<WyzieApiException>()),
    );
  });

  test('fetchBytes：200 返回字节；非 2xx 抛异常', () async {
    final ok = WyzieApi(
      client: MockClient((req) async => http.Response.bytes([1, 2, 3], 200)),
    );
    expect(await ok.fetchBytes('https://x/sub.srt'), [1, 2, 3]);

    final bad = WyzieApi(
      client: MockClient((req) async => http.Response('no', 404)),
    );
    await expectLater(
      bad.fetchBytes('https://x/sub.srt'),
      throwsA(isA<WyzieApiException>()),
    );
  });
}
