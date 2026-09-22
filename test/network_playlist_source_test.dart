import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_playlist_source.dart';

/// 远端同目录视频补全（bug：网络存储播放时入口拿不到兄弟列表，播放页面板
/// 只显示「当前文件夹没有其他视频」）：按「连接 id + 当前视频远端路径」列
/// 所在远端目录；任何失败都不能抛（列表空着也不能打断播放）。
void main() {
  NetworkFile f(String path, {bool isDirectory = false, int size = -1}) =>
      NetworkFile(
        name: path.split('/').last,
        path: path,
        size: size,
        isDirectory: isDirectory,
      );

  test('按当前视频所在远端目录列目录，返回该目录的视频', () async {
    final source = _FakeSource([
      f('/动画', isDirectory: true),
      f('/动画/01.mkv', size: 1024),
      f('/动画/02.mkv', size: 2048),
      f('/动画/01.sc.ass'),
      // 其它目录的视频不得混入
      f('/其它/09.mkv'),
    ]);

    final videos = await source.siblingVideosOf(
      connectionId: 5,
      remotePath: '/动画/01.mkv',
    );

    expect(source.calls, [(connectionId: 5, dirPath: '/动画')]);
    expect(videos.map((v) => v.name), ['01.mkv', '02.mkv']);
    // 兄弟列表必须含当前视频：播放列表面板与「下一集」按它定位当前项
    expect(videos.any((v) => v.path == '/动画/01.mkv'), isTrue);
  });

  test('连接根下的视频：远端目录为空串（协议客户端的根语义）', () async {
    final source = _FakeSource([f('/01.mkv')]);

    await source.siblingVideosOf(connectionId: 5, remotePath: '/01.mkv');

    expect(source.calls, [(connectionId: 5, dirPath: '')]);
  });

  test('远端路径缺失 / 连接不存在 / 列目录失败 → 空表，不抛', () async {
    final missing = _FakeSource([f('/01.mkv')]);
    expect(
      await missing.siblingVideosOf(connectionId: 5, remotePath: ''),
      isEmpty,
    );
    expect(missing.calls, isEmpty, reason: '路径为空不该发请求');

    final failing = _FakeSource([], error: StateError('网络连接不存在'));
    expect(
      await failing.siblingVideosOf(connectionId: 9, remotePath: '/a/01.mkv'),
      isEmpty,
    );
  });
}

/// 假数据源：只覆写「列目录」，验证目录归属与失败兜底。
class _FakeSource extends NetworkPlaylistSource {
  _FakeSource(this.files, {this.error});

  final List<NetworkFile> files;
  final Object? error;
  final List<({int connectionId, String dirPath})> calls = [];

  @override
  Future<List<NetworkFile>> listFiles(int connectionId, String dirPath) async {
    calls.add((connectionId: connectionId, dirPath: dirPath));
    final failure = error;
    if (failure != null) throw failure;
    // 真实协议客户端只返回**该目录**的直接条目，假实现照做
    return files.where((f) => _dirOf(f.path) == dirPath).toList();
  }
}

/// 路径所在目录（连接根下的文件返回空串）——测试侧独立实现，不借用被测代码。
String _dirOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash <= 0 ? '' : path.substring(0, slash);
}
