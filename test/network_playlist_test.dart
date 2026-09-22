import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/utils/network_playlist.dart';

/// 网络存储播放列表构建（bug：网络存储播放时播放列表面板看不到同目录视频）：
/// - 远端列目录结果 → 播放列表用的 VideoFile 表（只留视频、名称自然序）；
/// - 列表身份是**远端路径**（媒体路径是回环代理 URL，token 每次都换）。
void main() {
  NetworkFile f(
    String path, {
    String? name,
    int size = -1,
    int lastModified = 0,
    bool isDirectory = false,
  }) =>
      NetworkFile(
        name: name ?? path.split('/').last,
        path: path,
        size: size,
        lastModified: lastModified,
        isDirectory: isDirectory,
      );

  group('networkPlaylistFrom', () {
    test('只留视频：目录、字幕、图片都不进播放列表', () {
      final videos = networkPlaylistFrom(
        [
          f('/动画', isDirectory: true),
          f('/动画/01.mkv', size: 2048),
          f('/动画/01.sc.ass'),
          f('/动画/cover.jpg'),
          f('/动画/02.mp4', size: 4096),
        ],
        connectionId: 7,
      );

      expect(videos.map((v) => v.name), ['01.mkv', '02.mp4']);
    });

    test('列表身份是远端路径：path 与 remotePath 同源，来源与连接 id 落上', () {
      final videos = networkPlaylistFrom(
        [f('/动画/01.mkv', size: 2048)],
        connectionId: 7,
      );

      final video = videos.single;
      expect(video.path, '/动画/01.mkv');
      expect(video.remotePath, '/动画/01.mkv');
      expect(video.source, VideoSource.network);
      expect(video.connectionId, 7);
      expect(video.size, 2048);
    });

    test('名称自然序升序（数字感知），与播放列表面板默认排序一致', () {
      final videos = networkPlaylistFrom(
        [f('/EP10.mkv'), f('/EP2.mkv'), f('/EP1.mkv')],
        connectionId: 1,
      );

      expect(videos.map((v) => v.name), ['EP1.mkv', 'EP2.mkv', 'EP10.mkv']);
    });

    test('修改时间：服务器未提供（0）→ 无日期；提供了按毫秒映射', () {
      final ms = DateTime(2026, 2, 2).millisecondsSinceEpoch;
      final videos = networkPlaylistFrom(
        [f('/a.mkv', lastModified: ms), f('/b.mkv')],
        connectionId: 1,
      );

      final withDate = videos.firstWhere((v) => v.name == 'a.mkv');
      final withoutDate = videos.firstWhere((v) => v.name == 'b.mkv');
      expect(withDate.dateModifiedMs, ms);
      expect(withoutDate.dateModified, isNull);
      expect(withoutDate.dateModifiedMs, isNull);
    });

    test('空目录 / 全非视频 → 空表', () {
      expect(networkPlaylistFrom(const [], connectionId: 1), isEmpty);
      expect(
        networkPlaylistFrom([f('/01.sc.ass'), f('/02.nfo')], connectionId: 1),
        isEmpty,
      );
    });
  });

  group('playlistKeyOf', () {
    test('网络来源取远端路径（回环 URL 每次注册都换 token，不能当身份）', () {
      const source = VideoFile(
        path: '/动画/01.mkv',
        name: '01.mkv',
        source: VideoSource.network,
        remotePath: '/动画/01.mkv',
        connectionId: 3,
      );

      expect(
        playlistKeyOf('http://127.0.0.1:9000/tok/动画/01.mkv', source),
        '/动画/01.mkv',
      );
    });

    test('本地来源（无远端路径）取媒体路径', () {
      expect(
        playlistKeyOf('/storage/emulated/0/Movies/01.mp4', null),
        '/storage/emulated/0/Movies/01.mp4',
      );
      const local = VideoFile(path: '/Movies/01.mp4', name: '01.mp4');
      expect(playlistKeyOf('/Movies/01.mp4', local), '/Movies/01.mp4');
    });

    test('远端路径缺失/为空时退回媒体路径（不产生空键）', () {
      const source = VideoFile(
        path: '/Movies/01.mp4',
        name: '01.mp4',
        source: VideoSource.network,
        remotePath: '',
      );

      expect(playlistKeyOf('/Movies/01.mp4', source), '/Movies/01.mp4');
    });
  });
}
