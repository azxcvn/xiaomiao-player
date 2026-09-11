import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/file_operations_service.dart';

/// 文件管理服务（**真实文件系统**）测试，封闭体检报告的两个 P0：
/// 1. P0-2 空文件夹移动/复制——目标根目录必须被建出来（此前「移动」会删掉源
///    却不创建目标，文件夹凭空消失还提示成功，「复制」则什么都没发生）；
/// 2. P0-1 「只删文件夹内的视频文件」只删视频——音频/字幕/伪装扩展名/子目录
///    一律保留（此前删除集合含 7 个音频扩展名，用户读到「其它文件不会被删除」
///    后音频仍被永久删除）。
///
/// 路径约定：临时根目录由 `Directory.systemTemp` 给出（Windows 下自带反斜杠），
/// 其下各级一律用 `/` 拼接——`FileOps.baseName`/`parentOf` 只认 `/`。
void main() {
  late Directory root;

  /// 临时根目录下的路径（统一用 `/` 分隔）
  String p(String name) => '${root.path}/$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('moumou_file_ops_svc_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('空文件夹移动/复制（P0-2）', () {
    test('移动空文件夹：目标出现该文件夹、源消失', () async {
      final src = p('空目录');
      final dest = p('目标');
      Directory(src).createSync(recursive: true);
      Directory(dest).createSync(recursive: true);

      final result = await FileOperationsService.move(src, dest);

      expect(result, '$dest/空目录');
      expect(Directory(result).existsSync(), isTrue, reason: '目标根目录必须被创建');
      expect(Directory(src).existsSync(), isFalse, reason: '移动后源应消失');
    });

    test('复制空文件夹：目标出现该文件夹、源保留', () async {
      final src = p('空目录');
      final dest = p('目标');
      Directory(src).createSync(recursive: true);
      Directory(dest).createSync(recursive: true);

      final result = await FileOperationsService.copy(src, dest);

      expect(result, '$dest/空目录');
      expect(Directory(result).existsSync(), isTrue, reason: '目标根目录必须被创建');
      expect(Directory(src).existsSync(), isTrue, reason: '复制不动源');
    });

    test('非空文件夹移动：子目录与文件完整、源消失（回归）', () async {
      final src = p('剧集');
      final dest = p('目标');
      Directory('$src/子目录').createSync(recursive: true);
      Directory(dest).createSync(recursive: true);
      File('$src/顶.mp4').writeAsStringSync('A');
      File('$src/子目录/内.mp4').writeAsStringSync('BB');

      final result = await FileOperationsService.move(src, dest);

      expect(File('$result/顶.mp4').readAsStringSync(), 'A');
      expect(File('$result/子目录/内.mp4').readAsStringSync(), 'BB');
      expect(Directory(src).existsSync(), isFalse);
    });
  });

  group('只删文件夹内的视频文件（P0-1）', () {
    test('只删视频：音频/字幕/伪装扩展名/子目录一律保留', () async {
      final dir = p('混合');
      Directory('$dir/子目录').createSync(recursive: true);
      File('$dir/a.mp4').writeAsStringSync('v');
      File('$dir/b.flac').writeAsStringSync('a');
      File('$dir/c.ass').writeAsStringSync('s');
      File('$dir/伪装.mp4.bak').writeAsStringSync('x');
      File('$dir/子目录/内.mp4').writeAsStringSync('v');

      final deleted = await FileOperationsService.deleteFolder(
        dir,
        deleteWholeFolder: false,
      );

      expect(deleted, 1);
      expect(File('$dir/a.mp4').existsSync(), isFalse, reason: '视频应被删除');
      expect(File('$dir/b.flac').existsSync(), isTrue, reason: '音频绝不能被删');
      expect(File('$dir/c.ass').existsSync(), isTrue, reason: '字幕不能被删');
      expect(
        File('$dir/伪装.mp4.bak').existsSync(),
        isTrue,
        reason: '扩展名必须精确匹配，.mp4.bak 不是视频',
      );
      expect(
        File('$dir/子目录/内.mp4').existsSync(),
        isTrue,
        reason: '「只删视频」不递归子目录',
      );
      expect(Directory(dir).existsSync(), isTrue, reason: '目录本身保留');
    });

    test('文件夹里只有音频 → 报错，且音频一个都不能少', () async {
      final dir = p('只有音频');
      Directory(dir).createSync(recursive: true);
      File('$dir/b.flac').writeAsStringSync('a');
      File('$dir/c.mp3').writeAsStringSync('a');
      File('$dir/d.opus').writeAsStringSync('a');

      await expectLater(
        FileOperationsService.deleteFolder(dir, deleteWholeFolder: false),
        throwsA(isA<FileOpException>()),
      );

      expect(File('$dir/b.flac').existsSync(), isTrue);
      expect(File('$dir/c.mp3').existsSync(), isTrue);
      expect(File('$dir/d.opus').existsSync(), isTrue);
    });

    test('deleteWholeFolder: true → 整个目录递归删除（含音频）', () async {
      final dir = p('整体');
      Directory('$dir/子').createSync(recursive: true);
      File('$dir/a.mp4').writeAsStringSync('v');
      File('$dir/子/b.flac').writeAsStringSync('a');

      final deleted = await FileOperationsService.deleteFolder(
        dir,
        deleteWholeFolder: true,
      );

      expect(deleted, 1);
      expect(Directory(dir).existsSync(), isFalse);
    });
  });
}
