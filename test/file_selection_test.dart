import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/utils/file_selection.dart';

/// 多选纯函数测试（目录树索引 / 视频索引 / 按点选顺序取值）
void main() {
  TreeNode folder(String name, {List<TreeNode> children = const []}) {
    return TreeNode(
      name: name,
      path: '/root/$name',
      type: TreeNodeType.folder,
      children: children,
    );
  }

  TreeNode video(String name) {
    return TreeNode(
      name: name,
      path: '/root/$name',
      type: TreeNodeType.video,
      video: VideoFile(path: '/root/$name', name: name),
    );
  }

  group('indexTreeSelection', () {
    test('递归收录每一层的文件夹与视频，类型判定正确', () {
      final tree = [
        folder('A', children: [
          folder('A1', children: [video('a1.mp4')]),
          video('a.mp4'),
        ]),
        video('top.mp4'),
      ];
      final index = indexTreeSelection(tree);

      expect(
        index.keys,
        containsAll([
          '/root/A',
          '/root/A1',
          '/root/a1.mp4',
          '/root/a.mp4',
          '/root/top.mp4',
        ]),
      );
      expect(index['/root/A']!.isDirectory, isTrue);
      expect(index['/root/A1']!.isDirectory, isTrue);
      expect(index['/root/a.mp4']!.isDirectory, isFalse);
      expect(index['/root/a1.mp4']!.name, 'a1.mp4');
    });

    test('空树 → 空索引', () {
      expect(indexTreeSelection(const []), isEmpty);
    });

    test('video 节点缺 video 字段时跳过（不崩）', () {
      final broken = [
        TreeNode(name: 'x', path: '/root/x', type: TreeNodeType.video),
      ];
      expect(indexTreeSelection(broken), isEmpty);
    });
  });

  group('indexVideoSelection', () {
    test('按路径索引视频，全部为非文件夹', () {
      final index = indexVideoSelection([
        VideoFile(path: '/root/a.mp4', name: 'a.mp4'),
        VideoFile(path: '/root/b.mp4', name: 'b.mp4'),
      ]);

      expect(index.length, 2);
      expect(index['/root/b.mp4']!.name, 'b.mp4');
      expect(index['/root/b.mp4']!.isDirectory, isFalse);
    });

    test('空列表 → 空索引', () {
      expect(indexVideoSelection(const []), isEmpty);
    });
  });

  group('pickSelection', () {
    test('按点选先后取值（不是列表顺序）', () {
      final index = indexVideoSelection([
        VideoFile(path: '/a', name: 'a'),
        VideoFile(path: '/b', name: 'b'),
      ]);

      expect(pickSelection(['/b', '/a'], index).map((e) => e.name), ['b', 'a']);
    });

    test('索引里查不到的路径被丢弃（外部已删除 / 改名）', () {
      final index = indexVideoSelection([VideoFile(path: '/a', name: 'a')]);

      expect(pickSelection(['/a', '/gone'], index).map((e) => e.path), ['/a']);
    });

    test('空选择 → 空结果', () {
      expect(pickSelection(const [], <String, FileSelectionItem>{}), isEmpty);
    });
  });
}
