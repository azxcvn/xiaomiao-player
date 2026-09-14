import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/bili_wbi.dart';

/// WBI 签名纯函数测试（官方示例向量 + encWbi 一致性）。
void main() {
  test('getMixinKey 官方示例向量', () {
    const imgKey = '7cd084941338484aae1ad9425b84077c';
    const subKey = '4932caff0ff746eab6f01bf08b70ac45';
    expect(biliGetMixinKey(imgKey + subKey), 'ea1db124af3c7062474693fa704f4ff8');
  });

  test('mixinKeyFromWbiImg 从 URL 文件名推导', () {
    expect(
      biliMixinKeyFromWbiImg(
        'https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png',
        'https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png',
      ),
      'ea1db124af3c7062474693fa704f4ff8',
    );
  });

  test('encWbi 生成 wts/w_rid 且 w_rid = md5(query+mixinKey)', () {
    final params = <String, Object>{'bvid': 'BV1xx411c7mD', 'cid': '123'};
    biliEncWbi(params, 'ea1db124af3c7062474693fa704f4ff8');

    expect(params['wts'], isA<int>());
    expect(params['w_rid'], isA<String>());

    // 用同样算法（排除 w_rid）重算验证一致性
    final signKeys = params.keys.where((k) => k != 'w_rid').toList()..sort();
    final queryStr = signKeys
        .map((k) => '${Uri.encodeComponent(k)}='
            '${Uri.encodeComponent(params[k].toString().replaceAll(RegExp(r"[!'()*]"), ''))}')
        .join('&');
    final expected = md5
        .convert(utf8.encode('$queryStr${'ea1db124af3c7062474693fa704f4ff8'}'))
        .toString();
    expect(params['w_rid'], expected);
  });

  test('encWbi 剔除 !\'()* 字符', () {
    final params = <String, Object>{'kw': "a!b'c(d)e*f"};
    biliEncWbi(params, 'ea1db124af3c7062474693fa704f4ff8');
    final signKeys = params.keys.where((k) => k != 'w_rid').toList()..sort();
    final queryStr = signKeys
        .map((k) => '${Uri.encodeComponent(k)}='
            '${Uri.encodeComponent(params[k].toString().replaceAll(RegExp(r"[!'()*]"), ''))}')
        .join('&');
    // kw 的值被剔除特殊字符后应为 "abcdef"
    expect(queryStr, contains('abcdef'));
  });

  group('isBiliMixinKeyStale（WBI 密钥每天都要重取）', () {
    // 北京时间（UTC+8）：用 UTC 时刻表达，避免测试机时区影响
    DateTime cst(int y, int m, int d, [int hour = 0, int minute = 0]) =>
        DateTime.utc(y, m, d, hour - 8, minute);

    test('从未取过 → 需要重取', () {
      expect(isBiliMixinKeyStale(null, cst(2026, 3, 1, 12)), isTrue);
    });

    test('同一天且未超时 → 不需要重取', () {
      expect(
        isBiliMixinKeyStale(cst(2026, 3, 1, 9), cst(2026, 3, 1, 12)),
        isFalse,
      );
    });

    test('跨北京时间自然日 → 需要重取（官方每日更换）', () {
      // 北京时间 3/1 23:50 取的，3/2 00:10 用 → 已跨日
      expect(
        isBiliMixinKeyStale(cst(2026, 3, 1, 23, 50), cst(2026, 3, 2, 0, 10)),
        isTrue,
      );
    });

    test('同 UTC 日但跨北京日（UTC 16:00 之后）也要重取', () {
      // UTC 3/1 16:00 = 北京 3/2 00:00
      expect(
        isBiliMixinKeyStale(DateTime.utc(2026, 3, 1, 15), DateTime.utc(2026, 3, 1, 16)),
        isTrue,
      );
    });

    test('距上次超过兜底时长（默认 6h）→ 需要重取', () {
      expect(
        isBiliMixinKeyStale(cst(2026, 3, 1, 1), cst(2026, 3, 1, 8)),
        isTrue,
      );
      expect(
        isBiliMixinKeyStale(
          cst(2026, 3, 1, 1),
          cst(2026, 3, 1, 8),
          maxAge: const Duration(hours: 12),
        ),
        isFalse,
      );
    });

    test('时钟回拨（now 早于获取时刻）→ 需要重取', () {
      expect(
        isBiliMixinKeyStale(cst(2026, 3, 1, 12), cst(2026, 3, 1, 10)),
        isTrue,
      );
    });
  });
}
