import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ViewSettings.sortTree / sortFolders / sortVideos 排序逻辑测试
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TreeNode folder(
    String name, {
    int count = 0,
    int size = 0,
    DateTime? date,
    List<TreeNode> children = const [],
  }) {
    return TreeNode(
      name: name,
      path: '/$name',
      type: TreeNodeType.folder,
      videoCount: count,
      totalSize: size,
      dateModified: date,
      children: children,
    );
  }

  TreeNode video(
    String name, {
    int size = 0,
    int duration = 0,
    DateTime? date,
  }) {
    return TreeNode(
      name: name,
      path: '/$name.mp4',
      type: TreeNodeType.video,
      video: VideoFile(
        path: '/$name.mp4',
        name: name,
        size: size,
        durationMs: duration,
        dateModified: date,
      ),
    );
  }

  group('sortTree', () {
    test('文件夹在前、视频在后', () {
      final settings = ViewSettings();
      final result = settings.sortTree([video('b'), folder('a'), video('a')]);
      expect(result.length, 3);
      expect(result[0].isFolder, isTrue);
      expect(result[1].isFolder, isFalse);
      expect(result[2].isFolder, isFalse);
      // 文件夹名 a 在最前，视频 a/b 在后
      expect(result.map((n) => n.name).toList(), ['a', 'a', 'b']);
    });

    test('文件夹按名称升序', () async {
      final settings = ViewSettings();
      await settings.setSortField(SortField.name);
      final result = settings.sortTree([folder('b'), folder('a')]);
      expect(result.map((n) => n.name).toList(), ['a', 'b']);
    });

    test('文件夹按名称自然序（数字感知）', () async {
      final settings = ViewSettings();
      await settings.setSortField(SortField.name);
      final result = settings.sortTree([
        folder('第112话'),
        folder('第12话'),
        folder('第2话'),
      ]);
      // 数字按数值排序：2 < 12 < 112（而不是逐字符的 112 < 12 < 2）
      expect(result.map((n) => n.name).toList(), [
        '第2话',
        '第12话',
        '第112话',
      ]);
    });

    test('文件夹按数量降序', () async {
      final settings = ViewSettings();
      await settings.setSortField(SortField.count);
      await settings.setSortOrder(SortOrder.desc);
      final result = settings.sortTree([
        folder('few', count: 1),
        folder('many', count: 5),
      ]);
      expect(result.map((n) => n.name).toList(), ['many', 'few']);
    });

    test('文件夹按大小升序', () async {
      final settings = ViewSettings();
      await settings.setSortField(SortField.size);
      final result = settings.sortTree([
        folder('big', size: 100),
        folder('small', size: 10),
      ]);
      expect(result.map((n) => n.name).toList(), ['small', 'big']);
    });

    test('视频按时长升序', () async {
      final settings = ViewSettings();
      await settings.setVideoSortField(VideoSortField.duration);
      final result = settings.sortTree([
        video('long', duration: 100),
        video('short', duration: 10),
      ]);
      expect(result.map((n) => n.name).toList(), ['short', 'long']);
    });

    test('视频按大小降序', () async {
      final settings = ViewSettings();
      await settings.setVideoSortField(VideoSortField.size);
      await settings.setVideoSortOrder(SortOrder.desc);
      final result = settings.sortTree([
        video('small', size: 10),
        video('big', size: 100),
      ]);
      expect(result.map((n) => n.name).toList(), ['big', 'small']);
    });

    test('递归排序子级', () {
      final settings = ViewSettings();
      final parent = folder('parent', children: [video('b'), video('a')]);
      final result = settings.sortTree([parent]);
      expect(result[0].children.map((c) => c.name).toList(), ['a', 'b']);
    });

    test('排序不修改原列表', () {
      final settings = ViewSettings();
      final input = [video('b'), video('a')];
      final result = settings.sortTree(input);
      expect(input.map((n) => n.name).toList(), ['b', 'a']); // 原列表不变
      expect(result.map((n) => n.name).toList(), ['a', 'b']);
    });
  });

  group('sortFolders / sortVideos', () {
    test('sortFolders 按名称排序', () async {
      final settings = ViewSettings();
      await settings.setSortField(SortField.name);
      final result = settings.sortFolders([folder('b'), folder('a')]);
      expect(result.map((n) => n.name).toList(), ['a', 'b']);
    });

    test('sortVideos 按日期排序', () async {
      final settings = ViewSettings();
      await settings.setVideoSortField(VideoSortField.date);
      final result = settings.sortVideos([
        VideoFile(
          path: '/old.mp4',
          name: 'old',
          dateModified: DateTime(2020),
        ),
        VideoFile(
          path: '/new.mp4',
          name: 'new',
          dateModified: DateTime(2024),
        ),
      ]);
      expect(result.map((v) => v.name).toList(), ['old', 'new']);
    });

    test('sortVideos 按名称自然序（数字感知）', () async {
      final settings = ViewSettings();
      await settings.setVideoSortField(VideoSortField.name);
      final result = settings.sortVideos([
        VideoFile(path: '/12.mp4', name: '12.mp4'),
        VideoFile(path: '/2.mp4', name: '2.mp4'),
        VideoFile(path: '/112.mp4', name: '112.mp4'),
      ]);
      // 修复：升序时 112 曾排在 12 前面（逐字符比较），现按数值排序
      expect(result.map((v) => v.name).toList(), ['2.mp4', '12.mp4', '112.mp4']);
    });
  });

  group('加载纪律（P1-31：setter 首行 await ensureLoaded）', () {
    test('setter 必须先 await 读盘再改内存（冷启动竞态）', () async {
      // 磁盘值 = 默认值 list，用户要改成 tree：这样才能区分「改内存」发生在
      // 读盘之前还是之后（修复前 setter 同步段就写内存 → 被 load 覆盖回 list）
      SharedPreferences.setMockInitialValues({
        'view_mode': ViewMode.list.index,
      });
      final c = ViewSettings();
      // 不 await：调用后 setter 应停在 ensureLoaded 的 await 上，尚未改内存
      final pending = c.setViewMode(ViewMode.tree);
      expect(
        c.viewMode,
        ViewMode.list,
        reason: 'setter 同步段不得改内存，否则读盘结果稍后会把用户选择覆盖回旧值',
      );
      await pending;
      expect(c.viewMode, ViewMode.tree);
    });

    test('ensureLoaded 复用同一 load Future（与 main.dart 共享）', () async {
      SharedPreferences.setMockInitialValues({
        'view_mode': ViewMode.tree.index,
      });
      final c = ViewSettings();
      final f1 = c.ensureLoaded();
      final f2 = c.ensureLoaded();
      expect(identical(f1, f2), isTrue, reason: '启动加载与 setter 必须共享同一 Future');
      await f1;
      expect(c.viewMode, ViewMode.tree);
    });

    test('读盘完成后再改设置：ensureLoaded 不二次回读、不回退', () async {
      SharedPreferences.setMockInitialValues({
        'view_mode': ViewMode.tree.index,
        'view_sort_field': SortField.date.index,
      });
      final c = ViewSettings();
      await c.ensureLoaded();
      expect(c.viewMode, ViewMode.tree);
      expect(c.sortField, SortField.date);

      await c.setViewMode(ViewMode.list);
      await c.setSortField(SortField.name);
      await c.ensureLoaded();

      expect(c.viewMode, ViewMode.list, reason: '一次性加载，用户选择优先');
      expect(c.sortField, SortField.name);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('view_mode'), ViewMode.list.index);
      expect(prefs.getInt('view_sort_field'), SortField.name.index);
    });
  });
}
