import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/utils/folder_pin.dart';

/// 固定文件夹排序纯函数测试（对齐 mpvRx `FolderListScreen` 的稳定前置语义）
void main() {
  TreeNode folder(String name, {String? path, List<TreeNode> children = const []}) {
    return TreeNode(
      name: name,
      path: path ?? '/storage/emulated/0/$name',
      type: TreeNodeType.folder,
      children: children,
    );
  }

  TreeNode video(String name, {String? path}) {
    return TreeNode(
      name: name,
      path: path ?? '/storage/emulated/0/$name',
      type: TreeNodeType.video,
    );
  }

  group('pinnedFoldersFirst', () {
    test('固定项稳定前置，未固定项顺序不变', () {
      final list = [folder('A'), folder('B'), folder('C'), folder('D')];
      final pinned = {'/storage/emulated/0/C'};
      final result = pinnedFoldersFirst(list, pinned);
      expect(result.map((e) => e.name), ['C', 'A', 'B', 'D']);
    });

    test('固定项之间仍保持传入顺序（仍参与排序，不是固定顺序）', () {
      // 传入顺序代表「已按用户排序规则排好」：A < B < C
      final list = [folder('A'), folder('B'), folder('C'), folder('D')];
      final pinned = {
        '/storage/emulated/0/A',
        '/storage/emulated/0/C',
      };
      final result = pinnedFoldersFirst(list, pinned);
      // 固定组内部 A、C 仍是排序后的相对顺序（不反转、不重排）
      expect(result.map((e) => e.name), ['A', 'C', 'B', 'D']);
    });

    test('多个固定项 + 多个未固定项：两组各自保序', () {
      final list = [
        folder('1'),
        folder('2'),
        folder('3'),
        folder('4'),
        folder('5'),
      ];
      final pinned = {
        '/storage/emulated/0/2',
        '/storage/emulated/0/4',
      };
      final result = pinnedFoldersFirst(list, pinned);
      expect(result.map((e) => e.name), ['2', '4', '1', '3', '5']);
    });

    test('视频节点不受固定影响（即使路径命中也不前置）', () {
      final list = [folder('A'), video('B'), folder('C')];
      final pinned = {'/storage/emulated/0/B'};
      final result = pinnedFoldersFirst(list, pinned);
      expect(result.map((e) => e.name), ['A', 'B', 'C']);
      expect(result[1].isFolder, isFalse);
    });

    test('空固定集合 / 单项列表：原样返回（同一实例，不额外分配）', () {
      final list = [folder('A'), folder('B')];
      expect(identical(pinnedFoldersFirst(list, const {}), list), isTrue);

      final single = [folder('A')];
      expect(
        identical(pinnedFoldersFirst(single, {'/storage/emulated/0/A'}), single),
        isTrue,
      );

      // 全部固定（分组前后顺序不变）→ 同样原样返回
      final all = [folder('A'), folder('B')];
      final allPinned = {'/storage/emulated/0/A', '/storage/emulated/0/B'};
      expect(identical(pinnedFoldersFirst(all, allPinned), all), isTrue);
    });

    test('固定集合里的路径都不在列表中：原样返回', () {
      final list = [folder('A'), folder('B')];
      final result = pinnedFoldersFirst(list, {'/storage/emulated/0/Z'});
      expect(identical(result, list), isTrue);
    });

    test('固定项与未固定项数量相等时仍正确分组', () {
      final list = [folder('A'), folder('B'), folder('C'), folder('D')];
      final pinned = {
        '/storage/emulated/0/A',
        '/storage/emulated/0/B',
      };
      expect(
        pinnedFoldersFirst(list, pinned).map((e) => e.name),
        ['A', 'B', 'C', 'D'],
      );
    });
  });

  group('mapTreeWithPinnedFirst', () {
    test('每一层都应用稳定前置（递归下钻）', () {
      final tree = [
        folder('X', children: [folder('x1'), folder('x2')]),
        folder('Y', children: [folder('y1'), folder('y2')]),
      ];
      // 路径由 folder() 默认规则生成：/storage/emulated/0/<name>（不带父级前缀）
      final pinned = {
        '/storage/emulated/0/Y',
        '/storage/emulated/0/x2',
      };
      final result = mapTreeWithPinnedFirst(tree, pinned);
      // 顶层：Y（固定）在 X 之前
      expect(result.map((e) => e.name), ['Y', 'X']);
      // 子层：X 内部 x2（固定）在 x1 之前；Y 内部无固定项，顺序不变
      expect(result[1].children.map((e) => e.name), ['x2', 'x1']);
      expect(result[0].children.map((e) => e.name), ['y1', 'y2']);
    });

    test('空固定集合原样返回（同一实例）', () {
      final tree = [folder('A', children: [folder('B')])];
      expect(identical(mapTreeWithPinnedFirst(tree, const {}), tree), isTrue);
    });

    test('重建节点时保留聚合信息（数量/大小/日期）', () {
      final stamp = DateTime(2026, 9, 10);
      final tree = [
        TreeNode(
          name: 'A',
          path: '/storage/emulated/0/A',
          type: TreeNodeType.folder,
          children: [
            folder('inner', path: '/storage/emulated/0/A/inner'),
          ],
          videoCount: 7,
          totalSize: 1024,
          dateModified: stamp,
        ),
      ];
      final result = mapTreeWithPinnedFirst(
        tree,
        {'/storage/emulated/0/A/inner'},
      );
      expect(result.single.videoCount, 7);
      expect(result.single.totalSize, 1024);
      expect(result.single.dateModified, stamp);
      expect(result.single.path, '/storage/emulated/0/A');
    });

    test('视频子节点的相对顺序不被改变', () {
      // 传入顺序即「已按用户排序规则排好」；这里刻意让视频排在文件夹之前，
      // 只验证本函数不重排视频的相对顺序
      final tree = [
        folder('A', children: [video('v1'), folder('f'), video('v2')]),
      ];
      final pinned = {'/storage/emulated/0/f'};
      final result = mapTreeWithPinnedFirst(tree, pinned);
      // 固定文件夹前置后：f、v1、v2（视频间相对顺序不变）
      expect(result.single.children.map((e) => e.name), ['f', 'v1', 'v2']);
    });
  });
}
