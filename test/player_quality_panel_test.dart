import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/bili_dash.dart';
import 'package:moumou/pages/player/views/player_quality_panel.dart';
import 'package:moumou/widgets/player_option_chip.dart';

/// 清晰度面板高亮仲裁（§4.15/§7）：
/// - 成功 → 高亮钉到父级返回的**真实**档位（服务端可能因权限回落）；
/// - 失败 → 回到**切换前**那一档，而不是「开面板时」那一档；
/// - 切换在途 → 重复点击无效。
void main() {
  const qualities = [
    BiliQualityOption(qn: 120, description: '4K 超清'),
    BiliQualityOption(qn: 80, description: '1080P 高清'),
    BiliQualityOption(qn: 64, description: '720P 高清'),
  ];

  Future<void> pumpPanel(
    WidgetTester tester, {
    required int currentQn,
    required Future<int?> Function(int qn) onSelect,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerQualityPanel(
          qualities: qualities,
          currentQn: currentQn,
          onSelect: onSelect,
        ),
      ),
    ));
  }

  bool selected(WidgetTester tester, String label) {
    final chip = tester.widget<PlayerOptionChip>(
      find.byWidgetPredicate(
        (w) => w is PlayerOptionChip && w.label == label,
      ),
    );
    return chip.selected;
  }

  testWidgets('打开时高亮当前档', (tester) async {
    await pumpPanel(tester, currentQn: 80, onSelect: (_) async => 80);
    expect(selected(tester, '1080P 高清'), isTrue);
    expect(selected(tester, '4K 超清'), isFalse);
  });

  testWidgets('切换成功 → 高亮钉到父级返回的真实档位（回落场景）', (tester) async {
    // 请求 4K，服务端因权限只给了 1080P
    await pumpPanel(tester, currentQn: 80, onSelect: (qn) async => 80);
    await tester.tap(find.text('4K 超清'));
    await tester.pumpAndSettle();
    expect(selected(tester, '1080P 高清'), isTrue, reason: '真实档位是 1080P');
    expect(selected(tester, '4K 超清'), isFalse, reason: '不能停在乐观高亮上');
  });

  testWidgets('A→B 成功、B→C 失败 → 高亮回到 B（不是开面板时的 A）', (tester) async {
    var calls = 0;
    await pumpPanel(
      tester,
      currentQn: 80, // A = 1080P
      onSelect: (qn) async {
        calls++;
        if (qn == 64) return null; // C = 720P 切换失败
        return qn; // B = 4K 成功
      },
    );

    await tester.tap(find.text('4K 超清')); // A → B
    await tester.pumpAndSettle();
    expect(selected(tester, '4K 超清'), isTrue);

    await tester.tap(find.text('720P 高清')); // B → C 失败
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(selected(tester, '4K 超清'), isTrue, reason: '失败要回到切换前的 B');
    expect(selected(tester, '720P 高清'), isFalse);
  });

  testWidgets('切换在途时连点无效（只发一次请求）', (tester) async {
    final completer = Completer<int?>();
    var calls = 0;
    await pumpPanel(
      tester,
      currentQn: 80,
      onSelect: (qn) {
        calls++;
        return completer.future;
      },
    );

    await tester.tap(find.text('4K 超清'));
    await tester.pump();
    await tester.tap(find.text('720P 高清'));
    await tester.pump();
    expect(calls, 1);
    completer.complete(120);
    await tester.pumpAndSettle();
    expect(selected(tester, '4K 超清'), isTrue);
  });

  testWidgets('空画质列表显示占位', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerQualityPanel(
          qualities: const [],
          currentQn: 0,
          onSelect: (_) async => null,
        ),
      ),
    ));
    expect(find.text('暂无可用画质'), findsOneWidget);
  });
}
