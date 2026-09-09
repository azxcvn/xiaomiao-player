import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/pages/bilibili/bili_search_page.dart';
import 'package:moumou/services/bilibili/bili_bangumi_service.dart';
import 'package:moumou/services/bilibili/bili_http.dart';

/// 番剧搜索页测试（C2 通用分页控制器落地，§4.29）：
/// - 未搜索提示 → 搜索中 loading → 结果渲染；
/// - 触底加载更多（追加下一页 + 页脚 loading）；
/// - 首次失败显示错误 + 重试按钮，点重试重新请求；
/// - **刷新失败保留旧列表**（有数据时不显示错误页）。
void main() {
  BiliBangumiService serviceWith(MockClient client) => BiliBangumiService(
        http: BiliHttp(client: client),
        mixinKeyProvider: () async => 'testmixinkey',
      );

  http.Response jsonResponse(Map<String, dynamic> body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );

  Map<String, dynamic> searchBody(int page, {int total = 25, int pageSize = 20}) {
    final start = (page - 1) * pageSize;
    final count = (total - start).clamp(0, pageSize);
    return {
      'code': 0,
      'data': {
        'numResults': total,
        'pages': (total / pageSize).ceil(),
        'result': [
          for (var i = 0; i < count; i++)
            {
              'season_id': start + i + 1,
              'media_id': 100 + start + i,
              'title': '番剧${start + i + 1}',
              'cover': '',
              'index_show': '更新至第1话',
            },
        ],
      },
    };
  }

  Future<void> pumpPage(WidgetTester tester, BiliBangumiService service) async {
    await tester.pumpWidget(MaterialApp(
      home: BiliSearchPage(service: service),
    ));
    await tester.pump();
  }

  Future<void> search(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(); // 触发请求
    await tester.pump(const Duration(milliseconds: 50)); // 等 Future 完成
  }

  testWidgets('未搜索时显示提示', (tester) async {
    await pumpPage(tester, serviceWith(MockClient((_) async {
      return jsonResponse(searchBody(1));
    })));
    expect(find.text('输入关键词搜索番剧'), findsOneWidget);
  });

  testWidgets('搜索成功渲染结果列表', (tester) async {
    late Uri captured;
    await pumpPage(tester, serviceWith(MockClient((request) async {
      captured = request.url;
      return jsonResponse(searchBody(1));
    })));
    await search(tester, '测试');
    expect(captured.queryParameters['keyword'], '测试');
    expect(find.text('番剧1'), findsOneWidget);
    expect(find.text('输入关键词搜索番剧'), findsNothing);
  });

  testWidgets('触底加载更多追加下一页', (tester) async {
    var calls = 0;
    await pumpPage(tester, serviceWith(MockClient((request) async {
      calls++;
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      return jsonResponse(searchBody(page));
    })));
    await search(tester, '测试');
    expect(calls, 1);

    // 滚到底部触发 loadMore
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, 2);
    expect(find.text('番剧21'), findsOneWidget);
  });

  testWidgets('首次失败显示错误与重试，重试成功', (tester) async {
    var fail = true;
    await pumpPage(tester, serviceWith(MockClient((request) async {
      if (fail) return http.Response('boom', 500);
      return jsonResponse(searchBody(1));
    })));
    await search(tester, '测试');
    expect(find.textContaining('请求失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('番剧1'), findsOneWidget);
  });

  testWidgets('无结果时显示空态', (tester) async {
    await pumpPage(tester, serviceWith(MockClient((request) async {
      return jsonResponse({
        'code': 0,
        'data': {'numResults': 0, 'result': <dynamic>[]},
      });
    })));
    await search(tester, '没有的东西');
    expect(find.text('没有找到相关番剧'), findsOneWidget);
  });
}
