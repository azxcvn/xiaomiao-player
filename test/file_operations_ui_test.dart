import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/widgets/file_operations_ui.dart';
import 'package:moumou/widgets/file_selection_ui.dart';

/// 多选 / 文件管理 UI 测试：
/// 1. 选择工具栏（数量、全选 ↔ 取消全选、⋮ 在 0 项时置灰）；
/// 2. 长按菜单在多选态下的裁剪（撤重命名 + 撤多选 + 固定仅纯文件夹）；
/// 3. 删除确认弹窗的多选文案与「删除所有文件」勾选框显隐（涉及数据安全）。
void main() {
  // ───────────────────────── 选择工具栏 ─────────────────────────

  Future<void> pumpBar(
    WidgetTester tester, {
    required int count,
    required bool allSelected,
    VoidCallback? onExit,
    VoidCallback? onOpenMenu,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: buildFileSelectionAppBar(
            count: count,
            allSelected: allSelected,
            onExit: onExit ?? () {},
            onToggleAll: () {},
            onOpenMenu: onOpenMenu ?? () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
  }

  group('多选顶部工具栏', () {
    testWidgets('显示已选数量；未全选时是「全选」', (tester) async {
      await pumpBar(tester, count: 3, allSelected: false);

      expect(find.text('已选 3 项'), findsOneWidget);
      expect(find.byIcon(Icons.select_all), findsOneWidget);
      expect(find.byIcon(Icons.deselect), findsNothing);
    });

    testWidgets('已全选时图标切到「取消全选」', (tester) async {
      await pumpBar(tester, count: 2, allSelected: true);

      expect(find.byIcon(Icons.deselect), findsOneWidget);
      expect(find.byIcon(Icons.select_all), findsNothing);
    });

    testWidgets('0 项时 ⋮ 置灰（点了不回调）', (tester) async {
      var opened = 0;
      await pumpBar(
        tester,
        count: 0,
        allSelected: false,
        onOpenMenu: () => opened++,
      );

      await tester.tap(find.byIcon(Icons.more_vert), warnIfMissed: false);
      await tester.pump();
      expect(opened, 0);
    });

    testWidgets('有选中时点 ⋮ 回调呼出菜单', (tester) async {
      var opened = 0;
      await pumpBar(
        tester,
        count: 1,
        allSelected: false,
        onOpenMenu: () => opened++,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('点 × 回调退出多选', (tester) async {
      var exited = 0;
      await pumpBar(
        tester,
        count: 1,
        allSelected: false,
        onExit: () => exited++,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(exited, 1);
    });
  });

  // ───────────────────────── 长按菜单裁剪 ─────────────────────────

  Future<void> pumpMenu(
    WidgetTester tester, {
    required bool isDirectory,
    int selectionCount = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFileActionMenu(
                context,
                isDirectory: isDirectory,
                selectionCount: selectionCount,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('长按菜单', () {
    testWidgets('单选文件夹：固定/复制/移动/重命名/删除 + 多选', (tester) async {
      await pumpMenu(tester, isDirectory: true);

      expect(find.text('固定'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('多选'), findsOneWidget);
    });

    testWidgets('单选视频：没有「固定」，仍有「多选」', (tester) async {
      await pumpMenu(tester, isDirectory: false);

      expect(find.text('固定'), findsNothing);
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('多选'), findsOneWidget);
    });

    testWidgets('多选（全是文件夹）：撤掉重命名与多选，保留固定/复制/移动/删除', (tester) async {
      await pumpMenu(tester, isDirectory: true, selectionCount: 3);

      expect(find.text('重命名'), findsNothing);
      expect(find.text('多选'), findsNothing);
      expect(find.text('固定'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('多选（含视频的混选）：连「固定」也不出现', (tester) async {
      await pumpMenu(tester, isDirectory: false, selectionCount: 2);

      expect(find.text('固定'), findsNothing);
      expect(find.text('重命名'), findsNothing);
      expect(find.text('多选'), findsNothing);
      expect(find.text('删除'), findsOneWidget);
    });
  });

  // ───────────────────────── 删除确认弹窗 ─────────────────────────

  group('删除确认弹窗', () {
    DeleteConfirmResult? result;

    Future<void> pumpDelete(
      WidgetTester tester, {
      String title = '',
      bool isDirectory = false,
      int itemCount = 1,
      int folderCount = 0,
    }) async {
      result = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDeleteConfirmDialog(
                    context,
                    title: title,
                    isDirectory: isDirectory,
                    itemCount: itemCount,
                    folderCount: folderCount,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> tapConfirm(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
    }

    testWidgets('单选文件夹：默认只删视频，勾选框默认不勾', (tester) async {
      await pumpDelete(tester, title: 'A', isDirectory: true);

      expect(find.text('仅删除该文件夹内的视频文件，其它文件不会被删除。'), findsOneWidget);
      expect(find.text('删除所有文件'), findsOneWidget);

      await tapConfirm(tester);
      expect(result!.confirmed, isTrue);
      expect(result!.deleteAllFiles, isFalse);
    });

    testWidgets('单选文件夹：勾上「删除所有文件」→ deleteAllFiles=true', (tester) async {
      await pumpDelete(tester, title: 'A', isDirectory: true);

      await tester.tap(find.text('删除所有文件'));
      await tester.pump();
      await tapConfirm(tester);
      expect(result!.deleteAllFiles, isTrue);
    });

    testWidgets('单选视频：正文带名字，没有勾选框', (tester) async {
      await pumpDelete(tester, title: 'a.mp4');

      expect(find.text('确定删除「a.mp4」吗？'), findsOneWidget);
      expect(find.text('删除所有文件'), findsNothing);
    });

    testWidgets('多选纯视频：文案用数量，没有勾选框', (tester) async {
      await pumpDelete(tester, itemCount: 3, folderCount: 0);

      expect(find.text('确定删除选中的 3 个视频吗？'), findsOneWidget);
      expect(find.text('删除所有文件'), findsNothing);
    });

    testWidgets('多选含文件夹：文案带总数 + 勾选框，勾上对全部文件夹生效', (tester) async {
      await pumpDelete(tester, itemCount: 5, folderCount: 2);

      expect(find.textContaining('将删除选中的 5 项'), findsOneWidget);
      expect(find.text('删除所有文件'), findsOneWidget);

      await tester.tap(find.text('删除所有文件'));
      await tester.pump();
      await tapConfirm(tester);
      expect(result!.deleteAllFiles, isTrue);
    });

    testWidgets('取消：confirmed=false（不误删）', (tester) async {
      await pumpDelete(tester, title: 'A', isDirectory: true);

      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      expect(result!.confirmed, isFalse);
      expect(result!.deleteAllFiles, isFalse);
    });
  });
}
