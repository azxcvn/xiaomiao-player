import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/pages/subtitle/subtitle_download_page.dart';
import 'package:moumou/services/download/download_settings.dart';
import 'package:moumou/services/wyzie/wyzie_api.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假 Wyzie API：按关键词回结果，可挂起（验证搜索会话号与下载快照）。
class _FakeWyzieApi extends WyzieApi {
  _FakeWyzieApi()
      : super(client: MockClient((_) async => http.Response('[]', 200)));

  final List<String> queries = [];
  final Map<String, List<WyzieSubtitle>> results = {};
  final Map<String, Completer<List<WyzieSubtitle>>> pending = {};

  /// 挂起 `fetchBytes`（下载中途改关键词用）。
  Completer<void>? fetchGate;
  int fetchCalls = 0;

  @override
  Future<List<WyzieSubtitle>> search({
    required String query,
    String apiKey = '',
    String? language,
    String? format,
    String? encoding,
    String source = 'all',
  }) {
    queries.add(query);
    final gate = pending[query];
    if (gate != null) return gate.future;
    return Future.value(results[query] ?? const []);
  }

  @override
  Future<Uint8List> fetchBytes(String url) async {
    fetchCalls++;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    return Uint8List.fromList([1, 2, 3]);
  }
}

WyzieSubtitle _sub(String fileName, String display) => WyzieSubtitle(
      url: 'https://sub.wyzie.io/f/$fileName',
      fileName: fileName,
      display: display,
      language: 'en',
      source: 'opensubtitles',
      format: 'srt',
    );

/// 影视字幕下载页 UI 测试：初始态（字幕设置入口 + 关键词输入 + 目录栏）、
/// 字幕设置子页五入口、语言多选摘要联动、API 密钥弹窗取消/保存回归，
/// 外加 B12 的两条并发纪律（搜索会话号 P2-35 / 下载对选中项快照 P2-36）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WyzieSettings.instance.resetForTest();
  });

  Future<void> pumpPage(WidgetTester tester, {WyzieApi? api, List<String>? written}) async {
    await tester.pumpWidget(MaterialApp(
      home: SubtitleDownloadPage(
        api: api,
        writeBytes: written == null
            ? null
            : (path, bytes) async {
                written.add(path);
              },
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 搜索/下载类用例的公共准备：设好密钥与一个真实存在的下载目录。
  Future<Directory> prepareForSearch(
    WidgetTester tester,
    WyzieApi api, {
    List<String>? written,
  }) async {
    final tmp = Directory.systemTemp.createTempSync('b12_sub_');
    addTearDown(() {
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } catch (_) {
        // 在途写盘可能仍持有句柄：临时目录留给系统清理
      }
    });
    await WyzieSettings.instance.setApiKey('test-key');
    await DownloadSettings.instance.setDirectory(tmp.path);
    await pumpPage(tester, api: api, written: written);
    return tmp;
  }

  /// 输入关键词并回车（触发 onSubmitted → _search）。
  Future<void> submit(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 点主页「字幕下载设置」入口进入设置子页。
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('字幕下载设置'));
    await tester.pumpAndSettle();
  }

  testWidgets('初始态：字幕下载设置入口 + 关键词输入 + 确定按钮 + 目录栏', (tester) async {
    await pumpPage(tester);

    expect(find.text('字幕下载设置'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('未设置下载目录'), findsOneWidget);
    // 五个设置项已收敛到子页，主页不再平铺
    expect(find.text('WYZIE API 密钥'), findsNothing);
  });

  testWidgets('字幕设置子页：五个设置项齐全', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    expect(find.text('WYZIE API 密钥'), findsOneWidget);
    expect(find.text('字幕来源'), findsOneWidget);
    expect(find.text('字幕语言'), findsOneWidget);
    expect(find.text('首选格式'), findsOneWidget);
    expect(find.text('首选编码'), findsOneWidget);
  });

  testWidgets('字幕语言弹窗勾选「全部」后摘要更新为全部语言', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    // 默认摘要 English、Chinese
    expect(find.text('English、Chinese'), findsOneWidget);

    await tester.tap(find.text('字幕语言'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);

    await tester.tap(
      find.descendant(of: dialog, matching: find.text('全部')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('确定')),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部语言'), findsOneWidget);
    expect(WyzieSettings.instance.languages, {'all'});
  });

  testWidgets('API 密钥弹窗：取消关闭不崩溃（回归：控制器不得提前 dispose）', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);

    await tester.tap(find.text('WYZIE API 密钥'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('如何获取密钥'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('未设置 API 密钥点确定 → toast 请先设置密钥', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Inception');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('请先设置 WYZIE API 密钥'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('API 密钥弹窗：输入密钥确定后保存并显示已保存', (tester) async {
    await pumpPage(tester);
    await openSettings(tester);
    expect(find.text('未设置'), findsOneWidget);

    await tester.tap(find.text('WYZIE API 密钥'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '  wyzie-abc  ',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('确定'),
      ),
    );
    await tester.pumpAndSettle();

    expect(WyzieSettings.instance.apiKey, 'wyzie-abc', reason: '去掉首尾空白');
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('连按两次回车：结果属于最后一次关键词（P2-35）', (tester) async {
    final api = _FakeWyzieApi();
    final slow = Completer<List<WyzieSubtitle>>();
    api.pending['aaa'] = slow;
    api.results['bbb'] = [_sub('b.srt', 'B 字幕')];
    await prepareForSearch(tester, api);

    await submit(tester, 'aaa');
    // 第二次回车：不得被 `_busy` 挡住（旧实现 Enter 绕过守卫 + 无会话号 → 旧响应覆盖新结果）
    await submit(tester, 'bbb');
    expect(api.queries, ['aaa', 'bbb']);
    expect(find.text('bbb · 1 条'), findsOneWidget);

    // 旧响应后到 → 不得覆盖新结果
    slow.complete([_sub('a.srt', 'A 字幕')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('bbb · 1 条'), findsOneWidget);
    expect(find.text('B 字幕'), findsOneWidget);
    expect(find.text('A 字幕'), findsNothing);
  });

  testWidgets('字幕下载中改关键词重新搜索 → 不卡死、按钮恢复（P2-36）', (tester) async {
    final api = _FakeWyzieApi();
    api.results['kw'] = [_sub('a.srt', 'A 字幕'), _sub('b.srt', 'B 字幕')];
    api.results['kw2'] = [_sub('c.srt', 'C 字幕')];
    final written = <String>[];
    final dir = await prepareForSearch(tester, api, written: written);

    await submit(tester, 'kw');
    expect(find.text('kw · 2 条'), findsOneWidget);
    // 勾选两条结果（点整行即可切换 CheckboxListTile）
    await tester.tap(find.text('A 字幕'));
    await tester.tap(find.text('B 字幕'));
    await tester.pump();
    expect(find.text('下载字幕（2）'), findsOneWidget);

    // 开始下载：第一次 fetchBytes 挂住，模拟「下载中」
    api.fetchGate = Completer<void>();
    await tester.tap(find.text('下载字幕（2）'));
    await tester.pump();
    expect(find.text('下载中…'), findsOneWidget);

    // 下载中改关键词重新搜索：结果列表被整表替换（旧的 2 条 → 新的 1 条）
    await submit(tester, 'kw2');
    expect(find.text('kw2 · 1 条'), findsOneWidget);

    // 放行下载：选中项是下载开始时的快照，两条都要走完
    // （旧实现按索引取会在第 2 条越界 RangeError，且「下载中」永久卡死）
    api.fetchGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(api.fetchCalls, 2, reason: '下载对选中项做快照，不受结果列表被替换影响');
    expect(written.length, 2);
    expect(written.every((path) => path.startsWith(dir.path)), isTrue);
    expect(find.text('下载中…'), findsNothing, reason: '按钮必须恢复，不能永久卡死');
  });

  testWidgets('搜索中按钮内转圈用显式前景色（回归：默认色与按钮底色同色看不见）', (tester) async {
    final api = _FakeWyzieApi();
    final slow = Completer<List<WyzieSubtitle>>();
    api.pending['aaa'] = slow;
    await prepareForSearch(tester, api);

    await submit(tester, 'aaa');
    final button = find.byType(FilledButton);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(of: button, matching: find.byType(CircularProgressIndicator)),
    );
    final scheme = Theme.of(tester.element(button)).colorScheme;
    expect(spinner.color, scheme.onPrimary, reason: '不能用默认色（= primary，与底色同色）');
    expect(spinner.color, isNot(scheme.primary));

    slow.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('旧搜索后到：既不写结果也不提前关掉转圈（P2-35 配套）', (tester) async {
    final api = _FakeWyzieApi();
    final slowA = Completer<List<WyzieSubtitle>>();
    final slowB = Completer<List<WyzieSubtitle>>();
    api.pending['aaa'] = slowA;
    api.pending['bbb'] = slowB;
    await prepareForSearch(tester, api);

    await submit(tester, 'aaa');
    await submit(tester, 'bbb');

    // 旧会话（aaa）先回来：结果不得写回，转圈也不得提前结束（bbb 还在跑）
    slowA.complete([_sub('a.srt', 'A 字幕')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('A 字幕'), findsNothing);
    expect(find.text('确定'), findsNothing, reason: '最新搜索还在跑，按钮应仍是转圈');

    // 最新会话回来：结果与转圈都归它
    slowB.complete([_sub('b.srt', 'B 字幕')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('bbb · 1 条'), findsOneWidget);
    expect(find.text('B 字幕'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });
}
