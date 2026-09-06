import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/home/open_link_dialog.dart';

/// 「打开链接」弹窗测试（工作.md：链接播放功能）：
/// 有效链接回调规范化 URL 并关弹窗；无效链接行内提示不关弹窗；
/// 粘贴按钮读取剪贴板。
void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required void Function(String url) onPlay,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showOpenLinkDialog(context, onPlay: onPlay),
            child: const Text('open'),
          ),
        ),
      )),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('有效 http 链接：回调 URL 并关闭弹窗', (tester) async {
    String? played;
    await pumpDialog(tester, onPlay: (url) => played = url);
    await tester.enterText(find.byType(TextField), 'https://x.com/v.mp4');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(played, 'https://x.com/v.mp4');
    expect(find.text('打开链接'), findsNothing); // 弹窗已关闭
  });

  testWidgets('无协议输入自动补 https:// 后播放', (tester) async {
    String? played;
    await pumpDialog(tester, onPlay: (url) => played = url);
    await tester.enterText(find.byType(TextField), 'x.com/v.mp4');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(played, 'https://x.com/v.mp4');
  });

  testWidgets('rtmp 流媒体链接可播放', (tester) async {
    String? played;
    await pumpDialog(tester, onPlay: (url) => played = url);
    await tester.enterText(find.byType(TextField), 'rtmp://live.example.com/x');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(played, 'rtmp://live.example.com/x');
  });

  testWidgets('无效链接：行内提示且不关闭弹窗', (tester) async {
    var played = false;
    await pumpDialog(tester, onPlay: (_) => played = true);
    await tester.enterText(find.byType(TextField), 'not a url');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(played, isFalse);
    expect(find.text('打开链接'), findsOneWidget); // 弹窗仍在
    expect(find.text('链接无效，支持 http/https/rtmp/rtsp 等流媒体协议'),
        findsOneWidget);
  });

  testWidgets('不支持协议的链接同样提示无效', (tester) async {
    var played = false;
    await pumpDialog(tester, onPlay: (_) => played = true);
    await tester.enterText(find.byType(TextField), 'mailto:a@b.com');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    expect(played, isFalse);
    expect(find.text('链接无效，支持 http/https/rtmp/rtsp 等流媒体协议'),
        findsOneWidget);
  });

  testWidgets('取消关闭弹窗不回调', (tester) async {
    var played = false;
    await pumpDialog(tester, onPlay: (_) => played = true);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(played, isFalse);
    expect(find.text('打开链接'), findsNothing);
  });

  // 回归测试（历史 bug）：确认时先回调（push 播放页）后 pop 弹窗，
  // Navigator.pop() 弹掉的是栈顶（刚 push 的播放页）而非弹窗本身——
  // 表现为「点播放毫无反应」。必须先关弹窗再回调。
  testWidgets('确认后回调内的 push 不被弹掉（先关弹窗再进播放页）', (tester) async {
    late BuildContext homeContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            homeContext = context;
            return Center(
              child: TextButton(
                onPressed: () => showOpenLinkDialog(
                  context,
                  onPlay: (url) {
                    // 模拟首页：onPlay 里 push 播放页（同一 Navigator）
                    Navigator.of(homeContext).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const Scaffold(body: Center(child: Text('PLAYER'))),
                      ),
                    );
                  },
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://x.com/v.m3u8');
    await tester.tap(find.text('播放'));
    await tester.pumpAndSettle();

    // 播放页在栈顶可见 + 弹窗已关闭（旧 bug：PLAYER 被 pop、弹窗残留）
    expect(find.text('PLAYER'), findsOneWidget);
    expect(find.text('打开链接'), findsNothing);
  });
}
