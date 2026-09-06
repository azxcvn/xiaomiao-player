import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/models/update_info.dart';
import 'package:moumou/services/update/update_service.dart';

/// 更新服务测试（工作.md：更新功能）：更新源/下载链接常量 + 真实检查更新逻辑。
void main() {
  test('更新源与下载链接常量已填入真实地址', () {
    expect(
      UpdateService.repoUrl,
      'https://github.com/azxcvn/xiaomiao-player',
    );
    expect(
      UpdateService.releasePageUrl,
      'https://github.com/azxcvn/xiaomiao-player/releases',
    );
    expect(
      UpdateService.githubLatestUrl,
      'https://api.github.com/repos/azxcvn/xiaomiao-player/releases/latest',
    );
    expect(
      UpdateService.primaryDownloadUrl,
      startsWith('https://acnmwaofo249.feishu.cn/'),
    );
    expect(
      UpdateService.backupDownloadUrl,
      startsWith('https://www.bilibili.com/'),
    );
    // version.json 兜底通道尚未配置
    expect(UpdateService.mirrorVersionUrl, isEmpty);
  });

  test('devUpdate 携带真实主 / 备用下载链接', () {
    expect(
      UpdateService.devUpdate.primaryDownloadUrl,
      UpdateService.primaryDownloadUrl,
    );
    expect(
      UpdateService.devUpdate.backupDownloadUrl,
      UpdateService.backupDownloadUrl,
    );
  });

  group('checkForUpdate', () {
    test('远端版本更高 → 返回 UpdateInfo（解析版本/正文 + 真实下载链接）', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), UpdateService.githubLatestUrl);
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.4.0',
            'body': '## 更新内容\n- 新增 xxx',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final UpdateInfo? info = await UpdateService.checkForUpdate(
        client: client,
        localVersion: '1.3.3',
      );

      expect(info, isNotNull);
      expect(info!.version, '1.4.0'); // v 前缀被去掉
      expect(info.body, '## 更新内容\n- 新增 xxx');
      expect(info.primaryDownloadUrl, UpdateService.primaryDownloadUrl);
      expect(info.backupDownloadUrl, UpdateService.backupDownloadUrl);
    });

    test('远端版本更低或相等 → 返回 null（已是最新）', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'tag_name': '1.3.3'}), 200),
      );

      final info = await UpdateService.checkForUpdate(
        client: client,
        localVersion: '1.3.3',
      );

      expect(info, isNull);
    });

    test('body 为空 → 回退「暂无更新说明」', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'tag_name': '1.4.0'}), 200),
      );

      final info = await UpdateService.checkForUpdate(
        client: client,
        localVersion: '1.3.3',
      );

      expect(info!.body, '暂无更新说明');
    });

    test('网络失败 → 抛 UpdateCheckException', () async {
      final client = MockClient((_) async => throw Exception('network down'));

      await expectLater(
        UpdateService.checkForUpdate(client: client, localVersion: '1.3.3'),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('响应非 200 → 抛 UpdateCheckException', () async {
      final client = MockClient(
        (_) async => http.Response('rate limited', 403),
      );

      await expectLater(
        UpdateService.checkForUpdate(client: client, localVersion: '1.3.3'),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });
}
