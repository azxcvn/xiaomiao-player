import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moumou/models/bili_dash.dart';
import 'package:moumou/services/bilibili/bili_account.dart';
import 'package:moumou/services/bilibili/bili_constants.dart';
import 'package:moumou/services/bilibili/bili_danmaku_service.dart';
import 'package:moumou/services/bilibili/bili_http.dart';
import 'package:moumou/services/bilibili/bili_video_service.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/utils/file_ops.dart';
import 'package:path/path.dart' as p;

/// 下载任务状态。
enum DownloadStatus { pending, downloading, merging, paused, completed, failed }

/// 单个 B 站下载任务（视频 / 弹幕二选一）。
///
/// 视频任务：解析 playurl → 下载 video.m4s + audio.m4s → 原生 MediaMuxer 合并为
/// mp4（可选同步下载弹幕 XML）。弹幕任务：拉取分段弹幕 → 序列化 XML 落盘。
/// 复用 [BiliVideoService] / [BiliDanmakuService]（后者已用 varint 读 tag，规避
/// 老项目「多字节 tag 导致时间戳错乱」的坑）。
class DownloadTask extends ChangeNotifier {
  DownloadTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.isVideo,
    required this.saveDir,
    required this.aid,
    required this.cid,
    required this.epId,
    required this.seasonId,
    required this.bvid,
    required this.qn,
    required this.withDanmaku,
    @visibleForTesting BiliVideoService? video,
    @visibleForTesting BiliDanmakuService? danmaku,
    @visibleForTesting http.Client Function()? clientFactory,
    @visibleForTesting
    Future<bool> Function(String videoPath, String audioPath, String outputPath)?
        merger,
  })  : _video = video ?? BiliVideoService(),
        _danmaku = danmaku ?? BiliDanmakuService(),
        _clientFactory = clientFactory ?? http.Client.new,
        _merger = merger ?? DeviceServices.mergeM4s;

  final String id;
  final String title;
  final String subtitle;
  final String coverUrl;

  /// true = 视频下载；false = 弹幕下载。
  final bool isVideo;
  final String saveDir;

  // B 站定位信息（视频：bvid/aid/cid 或 epId/seasonId；弹幕：aid/cid）。
  final int aid;
  final int cid;
  final int epId;
  final int seasonId;
  final String bvid;
  final int qn;
  final bool withDanmaku;

  DownloadStatus _status = DownloadStatus.pending;
  double _progress = 0; // 0~1
  double _speedBps = 0;
  String? _error;
  String? _outputPath;

  DownloadStatus get status => _status;
  double get progress => _progress;
  double get speedBps => _speedBps;
  String? get error => _error;

  /// 最终产物路径（mp4 / xml）。
  String? get outputPath => _outputPath;

  final BiliVideoService _video;
  final BiliDanmakuService _danmaku;

  /// 每次下载新建一个 `http.Client`（下载流是流式的，与账号共享 client 会互相拖累）。
  final http.Client Function() _clientFactory;

  /// 音视频合并（原生 MediaMuxer 通道；测试注入假实现）。
  final Future<bool> Function(String videoPath, String audioPath, String outputPath)
      _merger;

  bool _cancelled = false;
  bool _paused = false;

  /// 当前这次 [run] 的完成信号（删除任务时等它停手再清临时文件）。
  Completer<void>? _activeRun;

  int _lastBytes = 0;
  DateTime _lastSpeedAt = DateTime.now();

  /// 落盘文件名（去除路径非法字符后的标题）。
  String get _safeTitle => _sanitizeFileName(title);

  /// 序列化（供 [DownloadManager] 跨重启持久化下载记录，工作.md 第 2 点）。
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'coverUrl': coverUrl,
        'isVideo': isVideo,
        'saveDir': saveDir,
        'aid': aid,
        'cid': cid,
        'epId': epId,
        'seasonId': seasonId,
        'bvid': bvid,
        'qn': qn,
        'withDanmaku': withDanmaku,
        'status': _status.name,
        'progress': _progress,
        'error': _error,
        'outputPath': _outputPath,
      };

  /// 从持久化 JSON 恢复任务（未完成的任务由 [DownloadManager] 归位为暂停，
  /// 不会在重启后自动续跑）。
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final task = DownloadTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      isVideo: json['isVideo'] as bool? ?? true,
      saveDir: json['saveDir'] as String? ?? '',
      aid: (json['aid'] as num?)?.toInt() ?? 0,
      cid: (json['cid'] as num?)?.toInt() ?? 0,
      epId: (json['epId'] as num?)?.toInt() ?? 0,
      seasonId: (json['seasonId'] as num?)?.toInt() ?? 0,
      bvid: json['bvid'] as String? ?? '',
      qn: (json['qn'] as num?)?.toInt() ?? 0,
      withDanmaku: json['withDanmaku'] as bool? ?? false,
    );
    task._status = _statusFromName(json['status'] as String?);
    task._progress = ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
    task._error = json['error'] as String?;
    task._outputPath = json['outputPath'] as String?;
    return task;
  }

  static DownloadStatus _statusFromName(String? name) {
    return DownloadStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => DownloadStatus.pending,
    );
  }

  /// 下载是否被暂停（区别于取消/失败）。
  bool get isPaused => _status == DownloadStatus.paused;

  /// 请求取消（暂停 / 删除共用）；正在进行的流下载会在下一块到达时中止。
  void cancel() {
    _cancelled = true;
  }

  /// 是否允许暂停：**只有下载中/等待中的任务能暂停**。
  ///
  /// 「合并中」是一次原生 `mergeMediaMuxer` 调用，中途停不了——旧实现在 merging
  /// 时也置成 paused，随后合并完成又自己变「完成」，用户看到的是「按了没反应」（P2-33）。
  bool get canPause =>
      _status == DownloadStatus.pending || _status == DownloadStatus.downloading;

  /// 暂停：标记并取消当前流下载，保留已写部分供 Range 续传。
  ///
  /// 合并中调用是无操作（见 [canPause]）；UI 也据此把按钮置灰。
  /// 等待中的任务同样置为 paused——否则队列 `_pump` 仍会把它启动起来。
  void pause() {
    if (!canPause) return;
    _paused = true;
    _cancelled = true;
    _setStatus(DownloadStatus.paused);
  }

  /// 恢复（由 [DownloadManager] 重新入队执行）。
  void resume() {
    _paused = false;
    _cancelled = false;
    _setStatus(DownloadStatus.pending);
  }

  /// 重启恢复持久化任务时调用：把「未完成」的任务标记为暂停，
  /// 之后仍可由用户手动 `resume` 继续（不自动续跑）。
  void markPausedForRestore() {
    _paused = true;
    _cancelled = false;
    _setStatus(DownloadStatus.paused);
  }

  /// 执行下载（幂等：已完成直接返回）。
  Future<void> run() async {
    if (_status == DownloadStatus.completed) return;
    _cancelled = false;
    _paused = false;
    final done = Completer<void>();
    _activeRun = done;
    try {
      if (isVideo) {
        await _runVideo();
      } else {
        await _runDanmaku();
      }
    } on _Cancelled {
      if (_paused) {
        _setStatus(DownloadStatus.paused);
      }
    } catch (e) {
      _setStatus(DownloadStatus.failed);
      _error = e is BiliApiException ? e.message : e.toString();
    } finally {
      if (identical(_activeRun, done)) _activeRun = null;
      if (!done.isCompleted) done.complete();
    }
  }

  /// 等本任务**当前这次** [run] 结束（没在跑就立刻返回）。
  ///
  /// 删除任务时用：临时文件必须在下载真正停手之后再删——在途循环还持有 sink，
  /// 先删会被 unlink 后继续写，也可能撞上正在合并的文件（P2-31）。
  Future<void> awaitStopped() => _activeRun?.future ?? Future<void>.value();

  /// 删除本任务留下的临时 / 半成品文件（幂等；暂停时不调用，保留部分文件供续传）。
  Future<void> deleteTempFiles() async {
    for (final f in _tempFiles()) {
      await _deleteQuietly(f);
    }
  }

  /// 本任务会写到磁盘的临时/中间产物。
  Iterable<File> _tempFiles() sync* {
    yield File(p.join(saveDir, '$id.video.m4s'));
    yield File(p.join(saveDir, '$id.audio.m4s'));
    yield File(p.join(saveDir, '$id.merge.mp4'));
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // 文件被占用 / 已删除：忽略（用户可手动清理，或下次同 id 下载覆盖）
    }
  }

  // ── 弹幕下载 ──────────────────────────────────────────────

  Future<void> _runDanmaku() async {
    _setStatus(DownloadStatus.downloading);
    _setProgress(0);
    final entries = await _danmaku.fetchDanmaku(cid: cid, aid: aid);
    _ensureActive();
    if (entries.isEmpty) {
      throw const BiliApiException('该集没有弹幕');
    }
    final xml = danmakuEntriesToBiliXml(entries);
    final file = await _writeText('$_safeTitle.xml', xml);
    _outputPath = file.path;
    _setProgress(1);
    _setStatus(DownloadStatus.completed);
  }

  // ── 视频下载 ──────────────────────────────────────────────

  Future<void> _runVideo() async {
    _setStatus(DownloadStatus.downloading);
    _setProgress(0);

    final result = await _resolvePlayUrl();
    _ensureActive();
    final videoStream = result.defaultVideo;
    final audioStream = result.defaultAudio;
    if (videoStream == null) {
      throw const BiliApiException('未获取到视频流');
    }

    // 1) 可选：同步下载弹幕（先下，避免视频失败白下弹幕）
    if (withDanmaku) {
      await _downloadDanmakuSide();
    }

    // 2) 下载 video.m4s + audio.m4s
    final tmpVideo = File(p.join(saveDir, '$id.video.m4s'));
    final tmpAudio = File(p.join(saveDir, '$id.audio.m4s'));

    await _downloadToFile(videoStream.baseUrl, tmpVideo, start: 0.0, end: 0.5);
    if (audioStream != null && audioStream.baseUrl.isNotEmpty) {
      await _downloadToFile(audioStream.baseUrl, tmpAudio, start: 0.5, end: 1.0);
    }

    // 3) 合并：**先合并到中间文件，成功后再改名到成品名**。
    //    旧实现让原生侧直接往 `$title.mp4` 写：合并失败（不支持的编码等）会把
    //    已存在的同名成品截断成半截 mp4，且中间产物与临时 m4s 全留在目录里（P2-31）。
    _setStatus(DownloadStatus.merging);
    final mergeTmp = File(p.join(saveDir, '$id.merge.mp4'));
    final hasAudio = audioStream != null && audioStream.baseUrl.isNotEmpty;
    final merged = hasAudio
        ? await _merger(tmpVideo.path, tmpAudio.path, mergeTmp.path)
        : await tmpVideo.rename(mergeTmp.path).then((_) => true);
    if (!merged) {
      await _deleteQuietly(mergeTmp); // 半截中间产物不留；原成品没被碰过
      throw const BiliApiException('音视频合并失败');
    }
    // 成品名不与已有文件冲突：同名标题的其它集 / 重复下载各自留一份，不互相覆盖
    final output = _uniqueOutputFile();
    await mergeTmp.rename(output.path);
    _outputPath = output.path;
    // 原生侧合并成功会删两个 m4s；无音轨路径是 rename 掉的——这里统一兜底清一次
    unawaited(deleteTempFiles());
    // 通知系统媒体库扫描产物，让 MediaStore 立即抽取时长/分辨率
    // （工作.md 第 5 点：否则列表里 duration=0，进度条/百分比显示「未观看」）。
    unawaited(DeviceServices.scanMediaFile(output.path));
    _setProgress(1);
    _setStatus(DownloadStatus.completed);
  }

  /// 成品文件：与目录里已有文件重名时自动避让（`X (1).mp4`）。
  ///
  /// 复用文件管理那套 [FileOps.uniqueName]（同一个「不覆盖用户已有文件」语义）。
  File _uniqueOutputFile() {
    final name = FileOps.uniqueName(
      '$_safeTitle.mp4',
      (candidate) => File(p.join(saveDir, candidate)).existsSync(),
    );
    return File(p.join(saveDir, name));
  }

  Future<void> _downloadDanmakuSide() async {
    try {
      final entries = await _danmaku.fetchDanmaku(cid: cid, aid: aid);
      if (entries.isNotEmpty) {
        await _writeText('$_safeTitle.xml', danmakuEntriesToBiliXml(entries));
      }
    } catch (_) {
      // 弹幕失败不影响视频下载
    }
  }

  Future<BiliPlayUrlResult> _resolvePlayUrl() async {
    if (epId > 0 || seasonId > 0) {
      return _video.fetchPgcPlayUrl(
        epId: epId > 0 ? epId : null,
        seasonId: seasonId > 0 ? seasonId : null,
        cid: cid > 0 ? cid : null,
        qn: qn,
      );
    }
    return _video.fetchUgcPlayUrl(
      bvid: bvid.isEmpty ? null : bvid,
      avid: aid > 0 ? aid : null,
      cid: cid,
      qn: qn,
    );
  }

  /// 流式下载 [url] 到 [file]；[start]/[end] 为本阶段在总进度中的占比。
  ///
  /// 三条纪律（B12）：
  /// 1. **client 一定被关**：关闭放进 `finally`——旧实现把 `client.close()` 写在
  ///    catch 里，一旦 catch 中的 `await sink.close()` 因二次关闭/写盘异常抛出，
  ///    client 就被永久跳过（HttpClient + keep-alive socket 泄漏，P2-30）；
  /// 2. **写盘错误立刻暴露**：监听 `sink.done`，磁盘满/目录不可写时不再把整段
  ///    响应读完才失败（P2-30）；
  /// 3. **总量未知就不按比例算进度**：旧实现拿「已存在字节数（常为 0）」当总量，
  ///    于是新下载恒 0%、续传一上来就跳到阶段末（P2-32）。
  Future<void> _downloadToFile(
    String url,
    File file, {
    required double start,
    required double end,
  }) async {
    final client = _clientFactory();
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers.addAll(_downloadHeaders());
      final existing = file.existsSync() ? file.lengthSync() : 0;
      final append = existing > 0;
      if (append) req.headers['Range'] = 'bytes=$existing-';

      final http.StreamedResponse resp;
      try {
        resp = await client.send(req);
      } catch (_) {
        throw const BiliApiException('网络请求失败');
      }
      // 416：Range 超出（文件已完整，可能是合并失败后的重试），直接跳过。
      if (resp.statusCode == 416) return;
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw BiliApiException('下载失败（HTTP ${resp.statusCode}）');
      }

      // 服务器忽略 Range（返回 200 而非 206）时不能续传，需从头重下。
      final resumeOk = append && resp.statusCode == 206;
      final startBytes = resumeOk ? existing : 0;
      final total = downloadTotalBytes(resp, startBytes);
      if (total <= 0) {
        // 总量未知：进度停在阶段起点（UI 显示为不确定进度条），
        // 绝不用「已存在字节数」当总量去算（那会跳到阶段末）
        _setProgress(start);
      }
      var received = startBytes;

      sink = file.openWrite(mode: resumeOk ? FileMode.append : FileMode.write);
      // 写盘错误（磁盘满 / 目录不可写）是**异步**落在 sink.done 上的：
      // 不监听就只能等 close 才暴露，期间会把整段响应白白下载完
      var writeFailed = false;
      unawaited(sink.done.catchError((Object _) {
        writeFailed = true;
      }));
      await for (final chunk in resp.stream) {
        if (_cancelled) throw _Cancelled();
        if (writeFailed) {
          throw const BiliApiException('写入文件失败（磁盘空间或权限）');
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _setProgress(start + (end - start) * (received / total));
        }
        final now = DateTime.now();
        final dt = now.difference(_lastSpeedAt).inMilliseconds;
        if (dt >= 500) {
          _speedBps = (received - _lastBytes) * 1000.0 / dt;
          _lastBytes = received;
          _lastSpeedAt = now;
          notifyListeners();
        }
      }
      try {
        await sink.flush();
      } catch (e) {
        throw BiliApiException('写入文件失败（磁盘空间或权限）：$e');
      }
    } finally {
      // 先关 sink（吞掉二次关闭/写盘异常，**不覆盖**真正的失败原因），再关 client
      final opened = sink;
      if (opened != null) {
        try {
          await opened.close();
        } catch (_) {
          // 写盘失败已由上面的 flush / writeFailed 体现
        }
      }
      client.close();
    }
  }

  Map<String, String> _downloadHeaders() => {
        'User-Agent': BiliConstants.webUserAgent,
        'Referer': BiliConstants.referer,
        if (BiliAccount.instance.cookieString.isNotEmpty)
          'Cookie': BiliAccount.instance.cookieString,
      };

  Future<File> _writeText(String name, String content) async {
    final file = File(p.join(saveDir, name));
    await file.writeAsString(content, flush: true);
    return file;
  }

  void _ensureActive() {
    if (_cancelled) throw _Cancelled();
  }

  void _setStatus(DownloadStatus s) {
    _status = s;
    notifyListeners();
  }

  void _setProgress(double v) {
    _progress = v.clamp(0.0, 1.0);
    notifyListeners();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// 本次响应代表的**总字节数**（含续传时已存在的部分）；无法确定返回 -1。
///
/// 优先级：`Content-Length`（206 时它是"剩余长度"，要加上已存在字节数）→
/// `Content-Range` 的 `/total`（上游不给 Content-Length 时续传的唯一来源）→ -1。
///
/// ⚠️ 返回 -1（或 ≤0）时调用方**不得**按比例算进度：旧实现用
/// `startBytes + max(0, contentLength)` 当总量，于是新下载恒 0%（total=0 不更新）、
/// 续传一上来 `received/total == 1` 直接跳到阶段末（P2-32）。
@visibleForTesting
int downloadTotalBytes(http.StreamedResponse resp, int startBytes) {
  final len = resp.contentLength;
  if (len != null && len > 0) return startBytes + len;
  final contentRange = resp.headers['content-range'];
  if (contentRange != null) {
    final slash = contentRange.lastIndexOf('/');
    if (slash >= 0) {
      final total = int.tryParse(contentRange.substring(slash + 1).trim());
      if (total != null && total > 0) return total;
    }
  }
  return -1;
}

final RegExp _illegalFileChars = RegExp(r'[\\/:*?"<>|]');

/// 去除文件路径非法字符（B 站标题可能含 `/`、`:` 等），防止写盘失败。
String _sanitizeFileName(String name) {
  final trimmed = name.replaceAll(_illegalFileChars, '_').trim();
  if (trimmed.isEmpty) return '未命名';
  return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
}
