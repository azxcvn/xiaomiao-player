import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/video_scanner.dart';

/// 扫描器纯函数（建树 / 建文件夹列表）回归测试。
///
/// 重点覆盖**外置存储卷**（SD 卡 / U 盘挂载在 `/storage/XXXX-XXXX`，issue #3）与
/// **/mnt 下的挂载**（模拟器共享目录 `/mnt/shared/MuMuShared` 等非主卷）：
/// 这是长期盲区——原有用例与真机环境全是 `/storage/emulated/0`，
/// 「卷根段数识别」写错也不会有任何测试报警。
void main() {
  VideoFile video(String path, {int size = 0}) {
    return VideoFile(
      path: path,
      name: path.split('/').last,
      size: size,
    );
  }

  group('buildTree 存储卷根识别', () {
    test('内部存储根 = 3 段：卡在 /storage/emulated/0 之下', () {
      final tree = VideoScanner.buildTree([
        video('/storage/emulated/0/Movies/Show/01.mp4'),
        video('/storage/emulated/0/Movies/Show/02.mp4'),
      ]);

      expect(tree.map((n) => n.name), ['Movies']);
      final movies = tree.single;
      expect(movies.path, '/storage/emulated/0/Movies');
      expect(movies.children.map((n) => n.name), ['Show']);
      expect(movies.videoCount, 2);
    });

    test('外置卷根 = 2 段：卡本身是顶层节点，不拆出 emulated 那层', () {
      final tree = VideoScanner.buildTree([
        video('/storage/ABCD-1234/Movies/01.mp4'),
      ]);

      expect(tree.map((n) => n.name), ['Movies']);
      expect(tree.single.path, '/storage/ABCD-1234/Movies');
      expect(tree.single.videoCount, 1);
    });

    test('内部存储与外置卡各自成一级节点，互不混卷', () {
      final tree = VideoScanner.buildTree([
        video('/storage/emulated/0/Movies/a.mp4', size: 100),
        video('/storage/ABCD-1234/Anime/b.mp4', size: 400),
      ]);

      // 文件夹在前、按名称升序
      expect(tree.map((n) => n.name), ['Anime', 'Movies']);
      expect(tree.map((n) => n.path), [
        '/storage/ABCD-1234/Anime',
        '/storage/emulated/0/Movies',
      ]);
      expect(tree.map((n) => n.videoCount), [1, 1]);
      expect(tree.map((n) => n.totalSize), [400, 100]);
    });

    test('卷根下的直接视频成为顶层视频节点（不造空文件夹）', () {
      final tree = VideoScanner.buildTree([
        video('/storage/ABCD-1234/root.mp4'),
      ]);

      expect(tree.single.type, TreeNodeType.video);
      expect(tree.single.name, 'root.mp4');
      expect(tree.single.path, '/storage/ABCD-1234/root.mp4');
    });

    test('无法识别存储根（既非 /storage 也非 /mnt）的视频作为顶层视频兜底', () {
      final tree = VideoScanner.buildTree([video('/srv/odd/loose.mp4')]);

      expect(tree.single.type, TreeNodeType.video);
      expect(tree.single.name, 'loose.mp4');
    });

    // /mnt 下挂的卷（模拟器共享目录 `/mnt/shared/MuMuShared`、`/mnt/media_rw/<uuid>`）：
    // 原生侧非主卷扫描给出的就是这种路径，识别不出卷根的话视频会被当成顶层视频散在根上
    test('/mnt/<x>/<y> = 3 段：共享目录里的文件夹成为顶层节点', () {
      final tree = VideoScanner.buildTree([
        video('/mnt/shared/MuMuShared/我是外置存储卡测试/1.mkv'),
        video('/mnt/shared/MuMuShared/我是外置存储卡测试/2.mkv'),
      ]);

      expect(tree.map((n) => n.name), ['我是外置存储卡测试']);
      expect(tree.single.path, '/mnt/shared/MuMuShared/我是外置存储卡测试');
      expect(tree.single.videoCount, 2);
    });

    test('/mnt/media_rw/<uuid> 同样是 3 段卷根', () {
      final tree = VideoScanner.buildTree([
        video('/mnt/media_rw/ABCD-1234/Movies/01.mp4'),
      ]);

      expect(tree.map((n) => n.name), ['Movies']);
      expect(tree.single.path, '/mnt/media_rw/ABCD-1234/Movies');
    });

    test('/mnt 下不足 3 段（/mnt/odd）按实际段数当卷根', () {
      final tree = VideoScanner.buildTree([video('/mnt/odd/loose.mp4')]);

      expect(tree.single.type, TreeNodeType.video);
      expect(tree.single.name, 'loose.mp4');
    });
  });

  group('buildFolderList 外置卷', () {
    test('按直接父目录分组，SD 卡目录单独成项', () {
      final folders = VideoScanner.buildFolderList([
        video('/storage/ABCD-1234/Movies/a.mp4', size: 10),
        video('/storage/ABCD-1234/Movies/b.mp4', size: 20),
        video('/storage/emulated/0/Download/c.mp4', size: 1),
      ]);

      expect(folders.map((f) => f.name), ['Download', 'Movies']);
      final sd = folders.firstWhere((f) => f.name == 'Movies');
      expect(sd.path, '/storage/ABCD-1234/Movies');
      expect(sd.videoCount, 2);
      expect(sd.totalSize, 30);
      expect(sd.children.map((c) => c.name), ['a.mp4', 'b.mp4']);
    });

    test('/mnt 共享目录：同样按直接父目录单独成项', () {
      final folders = VideoScanner.buildFolderList([
        video('/mnt/shared/MuMuShared/外置卡测试/1.mkv', size: 5),
        video('/storage/emulated/0/Download/2.mp4', size: 1),
      ]);

      final shared = folders.firstWhere((f) => f.name == '外置卡测试');
      expect(shared.path, '/mnt/shared/MuMuShared/外置卡测试');
      expect(shared.videoCount, 1);
      expect(shared.totalSize, 5);
    });
  });

  // 面包屑第一级要显示「真实存储卷」，靠它反查路径属于哪个卷
  group('volumeRootOf 卷根反查', () {
    test('内部存储 = /storage/emulated/0', () {
      expect(
        VideoScanner.volumeRootOf('/storage/emulated/0/测试路径/系列集'),
        '/storage/emulated/0',
      );
      expect(
        VideoScanner.volumeRootOf('/storage/emulated/0'),
        '/storage/emulated/0',
      );
    });

    test('外置卡 / U 盘 = /storage/<uuid>', () {
      expect(
        VideoScanner.volumeRootOf('/storage/ABCD-1234/Movies'),
        '/storage/ABCD-1234',
      );
    });

    test('/mnt 下的挂载（模拟器共享目录 / media_rw）', () {
      expect(
        VideoScanner.volumeRootOf('/mnt/shared/MuMuShared/我是外置存储卡测试'),
        '/mnt/shared/MuMuShared',
      );
      expect(
        VideoScanner.volumeRootOf('/mnt/media_rw/ABCD-1234/Movies'),
        '/mnt/media_rw/ABCD-1234',
      );
    });

    test('识别不出返回 null（不硬凑一个卷出来）', () {
      expect(VideoScanner.volumeRootOf('/srv/odd'), isNull);
      expect(VideoScanner.volumeRootOf(''), isNull);
      expect(VideoScanner.volumeRootOf('relative/path'), isNull);
    });
  });
}
