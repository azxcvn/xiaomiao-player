import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/player_exit.dart';

/// 播放页退出的路由收尾（[popRouteAndAbove]）回归测试：
///
/// 自动退出时若有面板/弹窗压在播放页上，只 pop 一次会被最上层吃掉，
/// 播放页留在栈里且退出标志已置位（返回键、左上角返回全部失效）。
/// 这里验证「上方路由全部关掉 + 播放页本身关掉」，且与上方层数无关。
void main() {
  testWidgets('面板打开时退出：面板与播放页一起关掉，回到首页', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();

    // 播放页上弹出面板（等价 showPlayerPanel / showPlayerBottomPanel）
    await tester.tap(find.text('打开面板'));
    await tester.pumpAndSettle();
    expect(find.text('面板'), findsOneWidget);

    popRouteAndAbove(player.context);
    await tester.pumpAndSettle();

    expect(find.text('面板'), findsNothing);
    expect(find.text('打开面板'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('两层面板叠在播放页上：一起关掉，播放页不会留在栈里', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开面板'));
    await tester.pumpAndSettle();
    // 面板上再叠一个弹窗（与「更多」面板内再弹设备选择弹窗同构）
    showDialog<void>(
      context: player.context,
      builder: (_) => const AlertDialog(content: Text('设备选择')),
    );
    await tester.pumpAndSettle();
    expect(find.text('设备选择'), findsOneWidget);

    popRouteAndAbove(player.context);
    await tester.pumpAndSettle();

    expect(find.text('设备选择'), findsNothing);
    expect(find.text('面板'), findsNothing);
    expect(find.text('打开面板'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('没有面板时退出：只关播放页，首页保留', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();

    popRouteAndAbove(player.context);
    await tester.pumpAndSettle();

    expect(find.text('打开面板'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('popOverlaysAbove：只关弹层，播放页保留', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开面板'));
    await tester.pumpAndSettle();

    expect(popOverlaysAbove(player.context), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('面板'), findsNothing);
    expect(find.text('打开面板'), findsOneWidget); // 播放页还在
  });

  testWidgets('popOverlaysAbove：不关播放页之上的普通页面（竖屏页）', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();
    // 播放页之上 push 普通页面（等价竖屏播放页），其上再弹面板
    _pushPage(player.context, '竖屏页');
    await tester.pumpAndSettle();
    showDialog<void>(
      context: player.context,
      builder: (_) => const AlertDialog(content: Text('面板')),
    );
    await tester.pumpAndSettle();

    expect(popOverlaysAbove(player.context), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('面板'), findsNothing);
    expect(find.text('竖屏页'), findsOneWidget); // 普通页面不能被提前关掉
  });

  testWidgets('popOverlaysAbove：没有弹层时返回 false，不动路由', (tester) async {
    final player = await _openPlayer(tester);
    await tester.tap(find.text('打开播放页'));
    await tester.pumpAndSettle();

    expect(popOverlaysAbove(player.context), isFalse);
    await tester.pumpAndSettle();

    expect(find.text('打开面板'), findsOneWidget);
    expect(find.text('首页'), findsNothing);
  });
}

void _pushPage(BuildContext context, String label) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Center(child: Text(label))),
    ),
  );
}

/// 首页 + 「打开播放页」按钮；点击后 push 一个可弹面板的模拟播放页，
/// 并把该路由的 context 记下来供 [popRouteAndAbove] 使用。
Future<PlayerHost> _openPlayer(WidgetTester tester) async {
  final host = PlayerHost();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (homeContext) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('首页'),
                TextButton(
                  onPressed: () {
                    Navigator.of(homeContext).push(
                      MaterialPageRoute<void>(
                        builder: (routeContext) {
                          host.context = routeContext;
                          return Scaffold(
                            body: Center(
                              child: TextButton(
                                onPressed: () => showDialog<void>(
                                  context: routeContext,
                                  builder: (_) => const AlertDialog(
                                    content: Text('面板'),
                                  ),
                                ),
                                child: const Text('打开面板'),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('打开播放页'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return host;
}

class PlayerHost {
  late BuildContext context;
}
