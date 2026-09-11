import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/video_scanner.dart';
import 'package:moumou/utils/file_ops.dart';

/// 文件管理纯函数测试（路径细分 / 目标校验 / 重命名校验 / 重名避让 / 失效固定路径）
void main() {
  group('路径细分', () {
    test('baseName：常规路径 / 带尾斜杠 / 单段 / 根', () {
      expect(FileOps.baseName('/storage/emulated/0/Movies'), 'Movies');
      expect(FileOps.baseName('/storage/emulated/0/Movies/'), 'Movies');
      expect(FileOps.baseName('/Movies'), 'Movies');
      expect(FileOps.baseName('/'), '/');
    });

    test('parentOf：常规 / 一级 / 根下', () {
      expect(FileOps.parentOf('/a/b/c.mp4'), '/a/b');
      expect(FileOps.parentOf('/a'), '/');
      expect(FileOps.parentOf('/a/b/'), '/a');
    });

    test('stripTrailingSlash：根路径保留单斜杠', () {
      expect(FileOps.stripTrailingSlash('/a/b///'), '/a/b');
      expect(FileOps.stripTrailingSlash('/'), '/');
      expect(FileOps.stripTrailingSlash('///'), '/');
    });
  });

  group('directoryContains（防移动到自己内部）', () {
    test('自身 / 子孙 / 前缀相似但非子孙', () {
      expect(FileOps.directoryContains('/a/b', '/a/b'), isTrue);
      expect(FileOps.directoryContains('/a/b', '/a/b/c'), isTrue);
      expect(FileOps.directoryContains('/a/b', '/a/bc'), isFalse);
      expect(FileOps.directoryContains('/a/b', '/a'), isFalse);
    });

    test('尾斜杠归一化后仍能识别', () {
      expect(FileOps.directoryContains('/a/b/', '/a/b/c/'), isTrue);
    });

    test('空路径不误判', () {
      expect(FileOps.directoryContains('', '/a'), isFalse);
      expect(FileOps.directoryContains('/a', ''), isFalse);
    });
  });

  group('validateMoveTarget', () {
    // 用临时的真实目录做「目标存在」前置（纯函数里有一道「目标目录必须存在」校验）
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('moumou_file_ops_');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('目标目录不存在 → 返回原因', () {
      final reason = FileOps.validateMoveTarget(
        sourcePath: '${root.path}/source.mp4',
        sourceIsDirectory: false,
        destinationDir: '${root.path}/绝对不存在的目录_9f3a',
      );
      expect(reason, isNotNull);
      expect(reason, contains('不存在'));
    });

    test('目标与源同目录 → 提示无需操作（文件/文件夹文案区分）', () {
      expect(
        FileOps.validateMoveTarget(
          sourcePath: '${root.path}/a.mp4',
          sourceIsDirectory: false,
          destinationDir: root.path,
        ),
        contains('视频'),
      );
      expect(
        FileOps.validateMoveTarget(
          sourcePath: '${root.path}/sub',
          sourceIsDirectory: true,
          destinationDir: root.path,
        ),
        contains('文件夹'),
      );
    });

    test('文件夹移动到自己的子目录 → 拒绝', () {
      final child = Directory('${root.path}/child')..createSync();
      final reason = FileOps.validateMoveTarget(
        sourcePath: root.path,
        sourceIsDirectory: true,
        destinationDir: child.path,
      );
      expect(reason, contains('子目录'));
    });

    test('合法目标（同卷另一目录）→ 放行', () {
      final dest = Directory('${root.path}/dest')..createSync();
      expect(
        FileOps.validateMoveTarget(
          sourcePath: '${root.path}/a.mp4',
          sourceIsDirectory: false,
          destinationDir: dest.path,
        ),
        isNull,
      );
    });

    test('空目标 → 提示选择目标', () {
      expect(
        FileOps.validateMoveTarget(
          sourcePath: '/a/b.mp4',
          sourceIsDirectory: false,
          destinationDir: '',
        ),
        '请选择目标文件夹',
      );
    });
  });

  group('validateRenameName', () {
    test('合法名称通过（含中文/空格/点/括号）', () {
      for (final name in ['第二季', 'EP 01 (修正)', 'a.b.c', ' 前后空格 ']) {
        expect(FileOps.validateRenameName(name).ok, isTrue, reason: name);
      }
    });

    test('空 / 全空白 → 拒绝', () {
      expect(FileOps.validateRenameName('').ok, isFalse);
      expect(FileOps.validateRenameName('   ').ok, isFalse);
    });

    test('. 与 .. → 拒绝', () {
      expect(FileOps.validateRenameName('.').ok, isFalse);
      expect(FileOps.validateRenameName('..').ok, isFalse);
    });

    test('路径分隔符 → 拒绝', () {
      expect(FileOps.validateRenameName('a/b').ok, isFalse);
      expect(FileOps.validateRenameName(r'a\b').ok, isFalse);
    });

    test('非法字符 → 拒绝（含控制字符）', () {
      for (final name in ['a:b', 'a*b', 'a?b', 'a"b', 'a<b', 'a>b', 'a|b', 'a\u0001b']) {
        expect(FileOps.validateRenameName(name).ok, isFalse, reason: name);
      }
    });
  });

  group('扩展名锁定（视频重命名只能改扩展名之前的文本）', () {
    test('extensionOf：常规 / 无扩展名 / 隐藏文件 / 尾部点', () {
      expect(FileOps.extensionOf('123.mp4'), '.mp4');
      expect(FileOps.extensionOf('剧集.S01E01.MKV'), '.mkv');
      expect(FileOps.extensionOf('无扩展名'), '');
      expect(FileOps.extensionOf('.nomedia'), '');
      expect(FileOps.extensionOf('结尾点.'), '');
    });

    test('stemOf：去掉扩展名 / 无扩展名原样', () {
      expect(FileOps.stemOf('123.mp4'), '123');
      expect(FileOps.stemOf('剧集.S01E01.mkv'), '剧集.S01E01');
      expect(FileOps.stemOf('无扩展名'), '无扩展名');
      expect(FileOps.stemOf('.nomedia'), '.nomedia');
    });

    test('isVideoFileName：视频命中 / 大小写不敏感 / 非视频不命中', () {
      expect(FileOps.isVideoFileName('a.mp4'), isTrue);
      expect(FileOps.isVideoFileName('剧集.S01E01.MKV'), isTrue);
      expect(FileOps.isVideoFileName('a.webm'), isTrue);
      // 音频/字幕/弹幕/无扩展名一律不算视频（P0-1：只删视频不能删音频）
      for (final name in [
        'a.mp3', 'a.m4a', 'a.aac', 'a.flac', 'a.wav', 'a.ogg', 'a.opus',
        'a.ass', 'a.srt', 'a.xml', '无扩展名', '.nomedia',
      ]) {
        expect(FileOps.isVideoFileName(name), isFalse, reason: name);
      }
      // 扩展名必须精确匹配（不能靠整条路径 endsWith 命中）
      expect(FileOps.isVideoFileName('a.mp4.bak'), isFalse);
      expect(FileOps.isVideoFileName('a.mp'), isFalse);
    });

    test('videoExtensions：与扫描器共用同一份唯一真值、不含音频', () {
      expect(FileOps.videoExtensions, VideoScanner.videoExt);
      expect(FileOps.videoExtensions.contains('.mp4'), isTrue);
      for (final ext in [
        '.mp3', '.flac', '.wav', '.aac', '.m4a', '.ogg', '.opus',
      ]) {
        expect(FileOps.videoExtensions.contains(ext), isFalse, reason: ext);
      }
    });

    test('renameInitialInput：文件只给主体，文件夹给完整名字', () {
      expect(
        FileOps.renameInitialInput(currentName: '123.mp4', isDirectory: false),
        '123',
      );
      expect(
        FileOps.renameInitialInput(currentName: 'S01', isDirectory: true),
        'S01',
      );
      expect(
        FileOps.renameInitialInput(currentName: 'S01.合集', isDirectory: true),
        'S01.合集',
      );
    });

    test('renameTargetName：文件恒带原扩展名（用户只输主体）', () {
      expect(
        FileOps.renameTargetName(
          input: '456',
          originalName: '123.mp4',
          isDirectory: false,
        ),
        '456.mp4',
      );
    });

    test('renameTargetName：用户把扩展名也打进来时不重复', () {
      expect(
        FileOps.renameTargetName(
          input: '456.mp4',
          originalName: '123.mp4',
          isDirectory: false,
        ),
        '456.mp4',
      );
      expect(
        FileOps.renameTargetName(
          input: '456.MP4',
          originalName: '123.mp4',
          isDirectory: false,
        ),
        '456.mp4',
      );
    });

    test('renameTargetName：多点文件名仍拼在最后一个点之后', () {
      expect(
        FileOps.renameTargetName(
          input: '新名字.S02E03',
          originalName: '旧.S01E01.mkv',
          isDirectory: false,
        ),
        '新名字.S02E03.mkv',
      );
    });

    test('renameTargetName：原文件没有扩展名时不硬加', () {
      expect(
        FileOps.renameTargetName(
          input: '456',
          originalName: '123',
          isDirectory: false,
        ),
        '456',
      );
    });

    test('renameTargetName：文件夹不锁扩展名（输入即最终名字）', () {
      expect(
        FileOps.renameTargetName(
          input: '456',
          originalName: '123.mp4',
          isDirectory: true,
        ),
        '456',
      );
      expect(
        FileOps.renameTargetName(
          input: 'S01.合集',
          originalName: 'S01',
          isDirectory: true,
        ),
        'S01.合集',
      );
    });

    test('renameTargetName：去首尾空白', () {
      expect(
        FileOps.renameTargetName(
          input: '  456  ',
          originalName: '123.mp4',
          isDirectory: false,
        ),
        '456.mp4',
      );
    });

    test('validateRenameInput：锁定扩展名时只输扩展名 → 报错', () {
      final check = FileOps.validateRenameInput(
        '.mp4',
        originalExtension: '.mp4',
      );
      expect(check.ok, isFalse);
      expect(check.error, contains('扩展名之前'));
    });

    test('validateRenameInput：只输主体 → 通过', () {
      expect(
        FileOps.validateRenameInput('456', originalExtension: '.mp4').ok,
        isTrue,
      );
    });

    test('validateRenameInput：输完整名字（含扩展名）→ 通过', () {
      expect(
        FileOps.validateRenameInput('456.mp4', originalExtension: '.mp4').ok,
        isTrue,
      );
    });

    test('validateRenameInput：未锁扩展名（文件夹）时 `.` 之外都按常规校验', () {
      expect(FileOps.validateRenameInput('456').ok, isTrue);
      expect(FileOps.validateRenameInput('.mp4').ok, isTrue);
      expect(FileOps.validateRenameInput('').ok, isFalse);
    });
  });

  group('uniqueName（重名避让）', () {    test('无冲突时原样返回', () {
      expect(FileOps.uniqueName('a.mp4', (_) => false), 'a.mp4');
    });

    test('带扩展名：序号插在扩展名前', () {
      final taken = {'a.mp4', 'a (1).mp4'};
      expect(FileOps.uniqueName('a.mp4', taken.contains), 'a (2).mp4');
    });

    test('无扩展名：序号直接追加', () {
      final taken = {'S01'};
      expect(FileOps.uniqueName('S01', taken.contains), 'S01 (1)');
    });

    test('多点文件名：只在最后一个点前插序号', () {
      final taken = {'剧集.S01E01.mkv'};
      expect(FileOps.uniqueName('剧集.S01E01.mkv', taken.contains), '剧集.S01E01 (1).mkv');
    });

    test('隐藏文件（点开头）视为无扩展名', () {
      final taken = {'.nomedia'};
      expect(FileOps.uniqueName('.nomedia', taken.contains), '.nomedia (1)');
    });

    test('大量占用时仍能找到空位', () {
      final taken = <String>{'a.txt'};
      for (var i = 1; i <= 50; i++) {
        taken.add('a ($i).txt');
      }
      expect(FileOps.uniqueName('a.txt', taken.contains), 'a (51).txt');
    });
  });

  group('stalePinnedPaths（改名/移动后清理失效固定）', () {
    const pinned = {
      '/sdcard/A',
      '/sdcard/A/sub',
      '/sdcard/B',
      '/sdcard/AB',
    };

    test('重命名：只清理自身，不动子孙与相似前缀', () {
      final stale = FileOps.stalePinnedPaths(
        oldPath: '/sdcard/A',
        pinnedPaths: pinned,
        includeDescendants: false,
      );
      expect(stale, {'/sdcard/A'});
    });

    test('移动：清理自身与全部子孙，不误伤 AB', () {
      final stale = FileOps.stalePinnedPaths(
        oldPath: '/sdcard/A',
        pinnedPaths: pinned,
        includeDescendants: true,
      );
      expect(stale, {'/sdcard/A', '/sdcard/A/sub'});
      expect(stale.contains('/sdcard/AB'), isFalse);
    });

    test('尾斜杠归一化后仍能命中', () {
      final stale = FileOps.stalePinnedPaths(
        oldPath: '/sdcard/A/',
        pinnedPaths: pinned,
        includeDescendants: true,
      );
      expect(stale, contains('/sdcard/A'));
    });

    test('没有命中时返回空集合', () {
      final stale = FileOps.stalePinnedPaths(
        oldPath: '/sdcard/Z',
        pinnedPaths: pinned,
        includeDescendants: true,
      );
      expect(stale, isEmpty);
    });
  });
}
