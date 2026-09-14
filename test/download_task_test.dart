import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moumou/models/bili_dash.dart';
import 'package:moumou/services/bilibili/bili_video_service.dart';
import 'package:moumou/services/download/download_manager.dart';
import 'package:moumou/services/download/download_task.dart';
import 'package:path/path.dart' as p;

/// B12 下载链路：写盘失败安全（P2-30）、总量未知不谎报进度（P2-32）、
/// 合并中间产物与临时文件清理（P2-31）、合并中不可暂停（P2-33）。
///
/// 全部用注入的假视频服务 + 假 client + 假合并器，不碰真实网络与原生通道。
class _FakeVideo extends BiliVideoService {
  _FakeVideo(this.result);

  final BiliPlayUrlResult result;

  @override
  Future<BiliPlayUrlResult> fetchUgcPlayUrl({
    String? bvid,
    int? avid,
    required int cid,
    int qn = 80,
  }) async =>
      result;
}

/// 记录 `close()` 是否被调用的假 client（P2-30 的验证点）。
class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);

  @override
  void close() => closed = true;
}

BiliPlayUrlResult _playUrl({String? audioUrl}) => BiliPlayUrlResult(
      quality: 80,
      videos: const [BiliDashStream(id: 80, baseUrl: 'https://v/')],
      audios: [
        if (audioUrl != null) BiliDashStream(id: 30280, baseUrl: audioUrl),
      ],
    );

http.StreamedResponse _resp(
  Stream<List<int>> body, {
  int status = 200,
  int? contentLength,
  String? contentRange,
}) {
  final headers = <String, String>{};
  if (contentRange != null) headers['content-range'] = contentRange;
  return http.StreamedResponse(
    body,
    status,
    contentLength: contentLength,
    headers: headers,
  );
}

void main() {
  late Directory dir;

  setUp(() {
    DownloadManager.instance.resetForTest();
    dir = Directory.systemTemp.createTempSync('b12_dl_');
  });

  tearDown(() {
    DownloadManager.instance.resetForTest();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  DownloadTask videoTask({
    BiliPlayUrlResult? playUrl,
    http.Client Function()? clientFactory,
    Future<bool> Function(String, String, String)? merger,
    bool withDanmaku = false,
  }) =>
      DownloadTask(
        id: 'vd_1',
        title: '第1话',
        subtitle: '某番剧',
        coverUrl: '',
        isVideo: true,
        saveDir: dir.path,
        aid: 1,
        cid: 100,
        epId: 0,
        seasonId: 0,
        bvid: 'BV1xx',
        qn: 80,
        withDanmaku: withDanmaku,
        video: _FakeVideo(playUrl ?? _playUrl()),
        clientFactory: clientFactory,
        merger: merger,
      );

  group('downloadTotalBytes（P2-32 的总量来源）', () {
    test('有 Content-Length：加上续传已存在字节数', () {
      expect(downloadTotalBytes(_resp(const Stream.empty(), contentLength: 100), 0), 100);
      expect(downloadTotalBytes(_resp(const Stream.empty(), contentLength: 100), 50), 150);
    });

    test('无 Content-Length 但有 Content-Range：用 /total', () {
      expect(
        downloadTotalBytes(
          _resp(const Stream.empty(), contentRange: 'bytes 100-199/200'),
          100,
        ),
        200,
      );
      expect(
        downloadTotalBytes(
          _resp(const Stream.empty(), contentRange: 'bytes 0-9/*'),
          0,
        ),
        -1,
      );
    });

    test('两者都没有（或声明 0）→ -1（调用方不得按比例算）', () {
      expect(downloadTotalBytes(_resp(const Stream.empty()), 0), -1);
      expect(downloadTotalBytes(_resp(const Stream.empty(), contentLength: 0), 0), -1);
    });
  });

  group('P2-32 续传进度不跳变', () {
    test('只有 Content-Range 时按真实总量逐步推进（不跳到阶段末）', () async {
      // 已存在 100 字节，服务器续传剩余 100 字节且不给 Content-Length
      File(p.join(dir.path, 'vd_1.video.m4s'))
          .writeAsBytesSync(List<int>.filled(100, 0));
      final task = videoTask(
        clientFactory: () => _TrackingClient(
          (_) async => _resp(
            Stream.fromIterable([
              List<int>.filled(50, 1),
              List<int>.filled(50, 2),
            ]),
            status: 206,
            contentRange: 'bytes 100-199/200',
          ),
        ),
      );
      final seen = <double>[];
      task.addListener(() => seen.add(task.progress));

      await task.run();

      expect(task.status, DownloadStatus.completed);
      // 视频段占比 0→0.5：旧实现把「已存在 100 字节」当总量 → 第一块就到 0.75
      expect(
        seen.where((v) => v > 0.5 && v != 1.0),
        isEmpty,
        reason: '阶段内进度不得超过该阶段上限（旧实现会因总量取错而跳变）',
      );
      expect(seen, contains(0.5));
      expect(seen.last, 1.0);
      expect(task.outputPath, isNotNull);
      expect(File(task.outputPath!).readAsBytesSync().length, 200);
    });
  });

  group('P2-30 写盘失败', () {
    test('目录不可写 → 明确失败 + client 一定被关（不静默卡住）', () async {
      final tracking = _TrackingClient(
        (_) async => _resp(
          Stream.value(List<int>.filled(10, 7)),
          contentLength: 10,
        ),
      );
      final badDir = Directory(p.join(dir.path, '不存在的目录'));
      final task = DownloadTask(
        id: 'vd_bad',
        title: '第1话',
        subtitle: '',
        coverUrl: '',
        isVideo: true,
        saveDir: badDir.path,
        aid: 1,
        cid: 100,
        epId: 0,
        seasonId: 0,
        bvid: 'BV1xx',
        qn: 80,
        withDanmaku: false,
        video: _FakeVideo(_playUrl()),
        clientFactory: () => tracking,
      );

      await task.run();

      expect(task.status, DownloadStatus.failed);
      expect(task.error, contains('写入文件失败'));
      expect(tracking.closed, isTrue, reason: '旧实现 catch 里 sink.close() 抛错会跳过 client.close()');
    });
  });

  group('P2-31 合并与临时文件', () {
    test('合并失败：不截断已有同名成品、不留中间产物', () async {
      final existing = File(p.join(dir.path, '第1话.mp4'))..writeAsStringSync('OLD');
      final task = videoTask(
        playUrl: _playUrl(audioUrl: 'https://a/'),
        merger: (v, a, out) async => false,
        clientFactory: () => _TrackingClient(
          (_) async => _resp(
            Stream.value(List<int>.filled(10, 1)),
            contentLength: 10,
          ),
        ),
      );

      await task.run();

      expect(task.status, DownloadStatus.failed);
      expect(task.error, contains('音视频合并失败'));
      expect(existing.readAsStringSync(), 'OLD', reason: '原成品不能被半截 mp4 覆盖');
      expect(File(p.join(dir.path, 'vd_1.merge.mp4')).existsSync(), isFalse);
      // 两个 m4s 保留：重试可走 Range 续传，不必重下
      expect(File(p.join(dir.path, 'vd_1.video.m4s')).existsSync(), isTrue);
      expect(File(p.join(dir.path, 'vd_1.audio.m4s')).existsSync(), isTrue);
    });

    test('成品名与已有文件重名时自动避让，且不留临时文件', () async {
      final existing = File(p.join(dir.path, '第1话.mp4'))..writeAsStringSync('OLD');
      final task = videoTask(
        clientFactory: () => _TrackingClient(
          (_) async => _resp(
            Stream.value(List<int>.filled(10, 9)),
            contentLength: 10,
          ),
        ),
      );

      await task.run();

      expect(task.status, DownloadStatus.completed);
      expect(task.outputPath, p.join(dir.path, '第1话 (1).mp4'));
      expect(existing.readAsStringSync(), 'OLD');
      expect(File(task.outputPath!).lengthSync(), 10);
      final leftovers = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.m4s') || f.path.endsWith('.merge.mp4'));
      expect(leftovers, isEmpty, reason: '成功路径不该留任何临时文件');
    });

    test('deleteTempFiles 幂等清理 .m4s 与合并中间产物', () async {
      for (final name in ['vd_1.video.m4s', 'vd_1.audio.m4s', 'vd_1.merge.mp4']) {
        File(p.join(dir.path, name)).writeAsBytesSync([1]);
      }
      final task = videoTask();
      await task.deleteTempFiles();
      await task.deleteTempFiles(); // 幂等
      expect(dir.listSync().whereType<File>(), isEmpty);
    });

    test('删除任务：等在途下载停手后清掉临时文件（不留 .m4s 残留）', () async {
      final controller = StreamController<List<int>>();
      final task = videoTask(
        clientFactory: () => _TrackingClient(
          (_) async => _resp(controller.stream, contentLength: 1000),
        ),
      );
      DownloadManager.instance.enqueue(task);
      controller.add(List<int>.filled(10, 1));
      await _waitUntil(() => File(p.join(dir.path, 'vd_1.video.m4s')).existsSync());

      DownloadManager.instance.remove(task.id);
      controller.add(List<int>.filled(10, 2)); // 下一次到达时中止在途循环
      await controller.close();

      await _waitUntil(
        () => !File(p.join(dir.path, 'vd_1.video.m4s')).existsSync(),
      );
      expect(DownloadManager.instance.tasks, isEmpty);
    });
  });

  group('P2-33 合并中不可暂停', () {
    test('merging 状态：canPause=false 且 pause() 是空操作', () {
      final task = DownloadTask.fromJson({
        ...videoTask().toJson(),
        'status': 'merging',
      });
      expect(task.status, DownloadStatus.merging);
      expect(task.canPause, isFalse);
      task.pause();
      expect(task.status, DownloadStatus.merging, reason: '合并停不了，不能假装暂停');
      expect(task.isPaused, isFalse);
    });

    test('downloading 状态：可暂停', () {
      final task = DownloadTask.fromJson({
        ...videoTask().toJson(),
        'status': 'downloading',
      });
      expect(task.canPause, isTrue);
      task.pause();
      expect(task.status, DownloadStatus.paused);
    });

    test('等待中任务也可暂停（队列串行时的占位）', () {
      final task = videoTask();
      expect(task.canPause, isTrue);
      task.pause();
      expect(task.isPaused, isTrue);
    });
  });
}

/// 轮询等待条件成立（临时文件清理是后台异步的，不阻塞测试线程）。
Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('等待条件超时');
}
