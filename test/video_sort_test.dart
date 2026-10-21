import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/view_settings.dart';

VideoFile _v(
  String name, {
  DateTime? date,
  int size = 0,
  int durationMs = 0,
}) => VideoFile(
      path: '/videos/$name',
      name: name,
      dateModified: date,
      size: size,
      durationMs: durationMs,
    );

/// 视频排序纯函数测试：主界面（视频页）与播放列表「自定义排序」共用同一套
/// 字段（名称/日期/大小/时长）× 方向（升/降序）规则。
void main() {
  group('sortVideosBy', () {
    test('名称升序：自然序（2 < 12 < 112），大小写不敏感', () {
      final videos = [_v('第112话.mp4'), _v('b.mp4'), _v('A.mp4'), _v('第2话.mp4')];
      expect(
        sortVideosBy(videos, VideoSortField.name, SortOrder.asc)
            .map((v) => v.name)
            .toList(),
        ['A.mp4', 'b.mp4', '第2话.mp4', '第112话.mp4'],
      );
    });

    test('名称降序：自然序反转', () {
      final videos = [_v('第2话.mp4'), _v('第12话.mp4'), _v('第1话.mp4')];
      expect(
        sortVideosBy(videos, VideoSortField.name, SortOrder.desc)
            .map((v) => v.name)
            .toList(),
        ['第12话.mp4', '第2话.mp4', '第1话.mp4'],
      );
    });

    test('日期升序：旧的在前；无日期按 0 处理（最前）', () {
      final videos = [
        _v('new.mp4', date: DateTime(2025, 3, 10)),
        _v('none.mp4'),
        _v('old.mp4', date: DateTime(2024, 1, 1)),
      ];
      expect(
        sortVideosBy(videos, VideoSortField.date, SortOrder.asc)
            .map((v) => v.name)
            .toList(),
        ['none.mp4', 'old.mp4', 'new.mp4'],
      );
    });

    test('日期降序：新的在前；无日期最后', () {
      final videos = [
        _v('new.mp4', date: DateTime(2025, 3, 10)),
        _v('none.mp4'),
        _v('old.mp4', date: DateTime(2024, 1, 1)),
      ];
      expect(
        sortVideosBy(videos, VideoSortField.date, SortOrder.desc)
            .map((v) => v.name)
            .toList(),
        ['new.mp4', 'old.mp4', 'none.mp4'],
      );
    });

    test('大小升/降序', () {
      final videos = [_v('a.mp4', size: 3), _v('b.mp4', size: 1), _v('c.mp4', size: 2)];
      expect(
        sortVideosBy(videos, VideoSortField.size, SortOrder.asc)
            .map((v) => v.name)
            .toList(),
        ['b.mp4', 'c.mp4', 'a.mp4'],
      );
      expect(
        sortVideosBy(videos, VideoSortField.size, SortOrder.desc)
            .map((v) => v.name)
            .toList(),
        ['a.mp4', 'c.mp4', 'b.mp4'],
      );
    });

    test('时长升/降序', () {
      final videos = [
        _v('a.mp4', durationMs: 3000),
        _v('b.mp4', durationMs: 1000),
        _v('c.mp4', durationMs: 2000),
      ];
      expect(
        sortVideosBy(videos, VideoSortField.duration, SortOrder.asc)
            .map((v) => v.name)
            .toList(),
        ['b.mp4', 'c.mp4', 'a.mp4'],
      );
      expect(
        sortVideosBy(videos, VideoSortField.duration, SortOrder.desc)
            .map((v) => v.name)
            .toList(),
        ['a.mp4', 'c.mp4', 'b.mp4'],
      );
    });

    test('纯函数：返回新列表、不改动入参', () {
      final videos = [_v('b.mp4'), _v('a.mp4')];
      final original = [...videos];
      sortVideosBy(videos, VideoSortField.name, SortOrder.asc);
      sortVideosBy(videos, VideoSortField.name, SortOrder.desc);
      expect(videos, original);
    });

    test('空列表与单元素', () {
      expect(
        sortVideosBy(const [], VideoSortField.name, SortOrder.asc),
        isEmpty,
      );
      final one = [_v('only.mp4')];
      expect(
        sortVideosBy(one, VideoSortField.name, SortOrder.desc),
        one,
      );
    });
  });

  group('compareVideosByField', () {
    test('只比较指定字段（升序语义）', () {
      final a = _v('a.mp4', size: 1, durationMs: 9);
      final b = _v('b.mp4', size: 2, durationMs: 5);
      expect(compareVideosByField(a, b, VideoSortField.name), lessThan(0));
      expect(compareVideosByField(a, b, VideoSortField.size), lessThan(0));
      expect(compareVideosByField(a, b, VideoSortField.duration), greaterThan(0));
      expect(compareVideosByField(a, a, VideoSortField.size), 0);
    });
  });
}
