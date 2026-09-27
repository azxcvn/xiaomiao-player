import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/file_operations_service.dart';
import 'package:moumou/services/media_scan_settings.dart';
import 'package:moumou/services/video_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 扫描器 → 原生的**请求负载**回归测试（issue #4）：
///
/// 开了「扫描 .nomedia / 隐藏文件夹」后进 App 转圈十几秒，根因是原生每次都从零
/// 深度 6 整盘递归、且黑白名单只在 Dart 侧过滤结果（一个目录都没少走）。这里锁住
/// 三件约定，防止回退：
/// 1. 黑白名单**按当前模式下推**给原生剪枝（白名单模式只发白名单，反之亦然；
///    「全部扫描」模式名单有残留也一律不发，否则会误剪枝）；
/// 2. 补扫索引重建（`forceFsRescan`）只在用户主动刷新 / 文件操作后**一次性**下发，
///    不是每次进 App 都带；
/// 3. 原生补扫条目映射为 VideoFile，且 Dart 侧黑白名单过滤仍然兜底生效。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');
  Map<Object?, Object?>? lastArgs;

  setUp(() async {
    lastArgs = null;
    SharedPreferences.setMockInitialValues({});
    MediaScanSettings.instance.reset();
    VideoScanner.resetForTest();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getVideos') return null;
      lastArgs = call.arguments as Map<Object?, Object?>?;
      return <dynamic>[];
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoScanner.resetForTest();
  });

  group('getVideos 请求负载', () {
    test('默认设置：开关关、名单空、不强制重建补扫索引', () async {
      await VideoScanner.scanVideos();

      expect(lastArgs!['includeNoMedia'], isFalse);
      expect(lastArgs!['includeHidden'], isFalse);
      expect(lastArgs!['whitelist'], isEmpty);
      expect(lastArgs!['blacklist'], isEmpty);
      expect(lastArgs!['forceFsRescan'], isFalse);
    });

    test('两个开关都开时如实下发', () async {
      final s = MediaScanSettings.instance;
      await s.setScanNoMedia(true);
      await s.setScanHiddenFolders(true);

      await VideoScanner.scanVideos();

      expect(lastArgs!['includeNoMedia'], isTrue);
      expect(lastArgs!['includeHidden'], isTrue);
    });

    test('白名单模式：只下推白名单，黑名单不下推', () async {
      final s = MediaScanSettings.instance;
      await s.addWhitelistFolder('/storage/emulated/0/Movies');
      await s.addBlacklistFolder('/storage/emulated/0/Download');
      await s.setFilterMode(FolderFilterMode.whitelist);

      await VideoScanner.scanVideos();

      expect(lastArgs!['whitelist'], ['/storage/emulated/0/Movies']);
      expect(lastArgs!['blacklist'], isEmpty);
    });

    test('黑名单模式：只下推黑名单，白名单不下推', () async {
      final s = MediaScanSettings.instance;
      await s.addWhitelistFolder('/storage/emulated/0/Movies');
      await s.addBlacklistFolder('/storage/emulated/0/Download');
      await s.setFilterMode(FolderFilterMode.blacklist);

      await VideoScanner.scanVideos();

      expect(lastArgs!['blacklist'], ['/storage/emulated/0/Download']);
      expect(lastArgs!['whitelist'], isEmpty);
    });

    test('全部扫描模式：名单里有残留也一律不下推（否则原生会误剪枝）', () async {
      final s = MediaScanSettings.instance;
      await s.addWhitelistFolder('/storage/emulated/0/Movies');
      await s.addBlacklistFolder('/storage/emulated/0/Download');
      await s.setFilterMode(FolderFilterMode.whitelist);
      await s.setFilterMode(FolderFilterMode.none);

      await VideoScanner.scanVideos();

      expect(lastArgs!['whitelist'], isEmpty);
      expect(lastArgs!['blacklist'], isEmpty);
    });

    test('markFsIndexDirty 只作用于紧接着的一次扫描', () async {
      VideoScanner.markFsIndexDirty();
      VideoScanner.clearCache();
      await VideoScanner.scanVideos();
      expect(lastArgs!['forceFsRescan'], isTrue);

      // 第二次：标记已被消费，不该再强制重建
      VideoScanner.clearCache();
      await VideoScanner.scanVideos();
      expect(lastArgs!['forceFsRescan'], isFalse);
    });

    test('文件操作成功后按路径失效：改名 → 下发 invalidatePaths，不整片重建', () async {
      final dir = Directory.systemTemp.createTempSync('moumou_scan_payload_');
      try {
        final file = File('${dir.path}/a.mp4')..writeAsStringSync('x');
        await FileOperationsService.rename(file.path, 'b.mp4');

        await VideoScanner.scanVideos();

        final invalidated =
            (lastArgs!['invalidatePaths'] as List?)?.cast<String>() ?? const [];
        expect(invalidated, contains(file.path), reason: '被改动的路径要精确失效');
        expect(
          lastArgs!['forceFsRescan'],
          isFalse,
          reason: '文件操作只失效改动处，不该整片重建（会抖掉别的补扫条目）',
        );
      } finally {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });

  group('补扫条目映射与过滤', () {
    test('字段映射为 VideoFile，且黑白名单在 Dart 侧仍然兜底生效', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getVideos') return null;
        lastArgs = call.arguments as Map<Object?, Object?>?;
        return <dynamic>[
          <String, Object?>{
            'path': '/storage/emulated/0/Movies/a.mp4',
            'name': 'a.mp4',
            'durationMs': 1000,
            'size': 2048,
            'width': 1920,
            'height': 1080,
            'dateModifiedMs': 1700000000000,
          },
          // 黑名单目录里的条目：Dart 侧必须继续过滤掉
          <String, Object?>{'path': '/storage/emulated/0/Download/b.mp4'},
        ];
      });

      final s = MediaScanSettings.instance;
      await s.addBlacklistFolder('/storage/emulated/0/Download');
      await s.setFilterMode(FolderFilterMode.blacklist);

      final videos = await VideoScanner.scanVideos();

      expect(videos.map((v) => v.path), ['/storage/emulated/0/Movies/a.mp4']);
      final v = videos.single;
      expect(v.name, 'a.mp4');
      expect(v.durationMs, 1000);
      expect(v.size, 2048);
      expect(v.width, 1920);
      expect(v.height, 1080);
      expect(v.dateModified, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('缺字段的条目按 0 / null 兜底，不抛异常', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getVideos') return null;
        return <dynamic>[
          <String, Object?>{'path': '/storage/emulated/0/Movies/c.mp4'},
          <String, Object?>{'name': 'no_path.mp4'},
        ];
      });

      final videos = await VideoScanner.scanVideos();

      expect(videos.length, 1, reason: '没有 path 的条目必须丢弃');
      expect(videos.single.name, '');
      expect(videos.single.durationMs, 0);
      expect(videos.single.dateModified, isNull);
    });
  });

  group('补扫增量推送（mpvRx 式增量上屏）', () {
    Map<String, Object?> fsVideo(String path, {int size = 1}) => <String, Object?>{
          'path': path,
          'name': path.split('/').last,
          'durationMs': 0,
          'size': size,
          'width': 0,
          'height': 0,
          'dateModifiedMs': 1700000000000,
        };

    Future<int> scanAndGetId() async {
      await VideoScanner.scanVideos();
      return lastArgs!['scanId'] as int;
    }

    test('增量批次并入当前列表并通知页面增量重建', () async {
      final before = VideoScanner.fsRevision.value;
      final scanId = await scanAndGetId();
      expect(VideoScanner.cachedVideos, isEmpty);

      VideoScanner.handleNativeCall(MethodCall('onFsVideoBatch', <String, Object?>{
        'scanId': scanId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/a.mp4')],
      }));

      expect(VideoScanner.fsRevision.value, greaterThan(before));
      expect(
        VideoScanner.cachedVideos!.map((v) => v.path),
        ['/storage/emulated/0/.hidden/a.mp4'],
      );
    });

    test('完整快照覆盖增量累计：这一轮消失的条目被清掉', () async {
      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsVideoBatch', <String, Object?>{
        'scanId': scanId,
        'videos': [
          fsVideo('/storage/emulated/0/.hidden/a.mp4'),
          fsVideo('/storage/emulated/0/.hidden/b.mp4'),
        ],
      }));
      expect(VideoScanner.cachedVideos!.length, 2);

      VideoScanner.handleNativeCall(MethodCall('onFsScanDone', <String, Object?>{
        'scanId': scanId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/a.mp4')],
      }));

      expect(
        VideoScanner.cachedVideos!.map((v) => v.path),
        ['/storage/emulated/0/.hidden/a.mp4'],
        reason: '快照是权威值，b.mp4 这一轮没有了就必须消失',
      );
    });

    test('旧代次的推送直接丢弃', () async {
      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsVideoBatch', <String, Object?>{
        'scanId': scanId - 1,
        'videos': [fsVideo('/storage/emulated/0/.hidden/old.mp4')],
      }));

      expect(VideoScanner.cachedVideos, isEmpty);
    });

    test('自定义设置的临时扫描不接收推送', () async {
      await scanAndGetId();
      // 设置页「添加白名单文件夹」用的无过滤扫描：不是当前列表的那一代
      await VideoScanner.scanVideos(scanSettings: MediaScanSettings.unfiltered);
      final customId = lastArgs!['scanId'] as int;

      VideoScanner.handleNativeCall(MethodCall('onFsVideoBatch', <String, Object?>{
        'scanId': customId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/x.mp4')],
      }));

      expect(VideoScanner.cachedVideos, isEmpty);
    });

    test('强制刷新不抖掉补扫条目：刷新期间隐藏文件夹原地保留', () async {
      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsScanDone', <String, Object?>{
        'scanId': scanId,
        'videos': [
          fsVideo('/storage/emulated/0/.hidden/a.mp4'),
          fsVideo('/storage/emulated/0/DCIM/.nomedia/b.mp4'),
        ],
      }));
      expect(VideoScanner.cachedVideos!.length, 2);

      // 下拉刷新：强制重扫 + 清 Dart 内存缓存（原生此刻只回 MediaStore 那份）
      VideoScanner.markFsIndexDirty();
      VideoScanner.clearCache();
      final videos = await VideoScanner.scanVideos();

      expect(lastArgs!['forceFsRescan'], isTrue);
      expect(
        videos.map((v) => v.path),
        [
          '/storage/emulated/0/.hidden/a.mp4',
          '/storage/emulated/0/DCIM/.nomedia/b.mp4',
        ],
        reason: '补扫那份不能因为刷新被清空（否则列表会先少两个文件夹再回来）',
      );
    });

    test('开关 / 名单变了才清补扫镜像（避免端出旧的隐藏条目）', () async {
      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsScanDone', <String, Object?>{
        'scanId': scanId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/a.mp4')],
      }));
      expect(VideoScanner.cachedVideos!.length, 1);

      // 条件变了（开关打开 → 原生换索引）→ 镜像必须跟着清
      final s = MediaScanSettings.instance;
      await s.setScanNoMedia(true);
      await s.setScanHiddenFolders(true);
      VideoScanner.clearCache();
      await VideoScanner.scanVideos();

      expect(VideoScanner.cachedVideos, isEmpty);
    });

    test('原生响应里带 fs 标记的条目与 MediaStore 那份分开，快照只替换补扫那份', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getVideos') return null;
        lastArgs = call.arguments as Map<Object?, Object?>?;
        return <dynamic>[
          <String, Object?>{
            'path': '/storage/emulated/0/Movies/plain.mp4',
            'name': 'plain.mp4',
          },
          <String, Object?>{
            'path': '/storage/emulated/0/.hidden/fs.mp4',
            'name': 'fs.mp4',
            'fs': true,
          },
        ];
      });

      final scanId = await scanAndGetId();
      expect(VideoScanner.cachedVideos!.length, 2);

      // 补扫快照里没有 fs.mp4 了：只该换掉补扫那份，MediaStore 的条目不受影响
      VideoScanner.handleNativeCall(MethodCall('onFsScanDone', <String, Object?>{
        'scanId': scanId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/other.mp4')],
      }));

      final paths = VideoScanner.cachedVideos!.map((v) => v.path).toList();
      expect(paths, hasLength(2), reason: '合并结果按名称排序，这里只校验内容');
      expect(paths, contains('/storage/emulated/0/Movies/plain.mp4'));
      expect(paths, contains('/storage/emulated/0/.hidden/other.mp4'));
      expect(
        paths,
        isNot(contains('/storage/emulated/0/.hidden/fs.mp4')),
        reason: '旧的补扫条目要被快照换掉，MediaStore 那份不受影响',
      );
    });

    test('invalidateFsPaths：改动处立刻摘掉，别的目录不受影响，并随下次扫描下发', () async {
      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsScanDone', <String, Object?>{
        'scanId': scanId,
        'videos': [
          fsVideo('/storage/emulated/0/.hidden/a.mp4'),
          fsVideo('/storage/emulated/0/other/b.mp4'),
        ],
      }));
      expect(VideoScanner.cachedVideos!.length, 2);

      VideoScanner.invalidateFsPaths(['/storage/emulated/0/.hidden/a.mp4']);

      expect(
        VideoScanner.cachedVideos!.map((v) => v.path),
        ['/storage/emulated/0/other/b.mp4'],
        reason: '改动过的条目立刻消失，别的目录不动',
      );

      VideoScanner.clearCache();
      await VideoScanner.scanVideos();
      expect(
        (lastArgs!['invalidatePaths'] as List?)?.cast<String>(),
        ['/storage/emulated/0/.hidden/a.mp4'],
      );
    });

    test('同一路径以原生快结果为准（补扫那份不覆盖 MediaStore 的时长 / 尺寸）', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getVideos') return null;
        lastArgs = call.arguments as Map<Object?, Object?>?;
        return <dynamic>[
          <String, Object?>{
            'path': '/storage/emulated/0/.hidden/a.mp4',
            'name': 'a.mp4',
            'durationMs': 60000,
            'size': 100,
          },
        ];
      });

      final scanId = await scanAndGetId();
      VideoScanner.handleNativeCall(MethodCall('onFsVideoBatch', <String, Object?>{
        'scanId': scanId,
        'videos': [fsVideo('/storage/emulated/0/.hidden/a.mp4', size: 999)],
      }));

      expect(VideoScanner.cachedVideos!.length, 1, reason: '不能出现重复条目');
      expect(VideoScanner.cachedVideos!.single.durationMs, 60000);
      expect(VideoScanner.cachedVideos!.single.size, 100);
    });

    test('经 DeviceServices 的通道 handler 也能收到推送（真实分发链路）', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        lastArgs = call.arguments as Map<Object?, Object?>?;
        // takeExternalVideo 用来装 handler
        if (call.method == 'takeExternalVideo') return null;
        if (call.method == 'getVideos') return <dynamic>[];
        return null;
      });
      await DeviceServices.takeExternalVideo(); // 安装 moumou/video_info 的推送 handler

      await VideoScanner.scanVideos();
      final scanId = lastArgs!['scanId'] as int;

      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('onFsVideoBatch', <String, Object?>{
          'scanId': scanId,
          'videos': [fsVideo('/storage/emulated/0/.hidden/a.mp4')],
        }),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(channel.name, data, (_) {});

      expect(
        VideoScanner.cachedVideos!.map((v) => v.path),
        ['/storage/emulated/0/.hidden/a.mp4'],
      );
    });
  });
}
