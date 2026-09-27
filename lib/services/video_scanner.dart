import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moumou/models/playlist_sort.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/media_scan_settings.dart';
import 'package:moumou/utils/file_ops.dart';

/// 视频扫描器：通过原生 MediaStore 查询视频，并构建完整目录树
class VideoScanner {
  static const MethodChannel _channel = MethodChannel('moumou/video_info');

  /// 内存缓存：避免首页和详情页重复查询 MediaStore（= [_baseVideos] ∪ 补扫那份）
  static List<VideoFile>? _cachedVideos;

  /// 原生**快速返回**里的 MediaStore 那份（每个扫描代次整体替换）
  static List<VideoFile> _baseVideos = const [];

  /// 整盘补扫那份（path → 视频），对齐 mpvRx 的 `indexedFolders` 独立于
  /// `mediaStoreFolders` 维护：
  /// - 原生快结果里带 `fs` 标记的条目、以及后台补扫的增量推送，都落在这里；
  /// - `onFsScanDone` 的**完整快照**整体替换它（清掉这一轮消失的条目）；
  /// - **刷新 / 再扫描不清它** —— 清了就会出现「下拉刷新时 `.nomedia`、隐藏文件夹、
  ///   外置卡的文件夹先消失再回来」的视觉跳跃（用户反馈）。
  static final Map<String, VideoFile> _fsVideos = <String, VideoFile>{};

  /// 补扫条件的指纹：开关 / 黑白名单一变，原生换索引，这份镜像也必须跟着清
  /// （否则「关掉 .nomedia 扫描」之后旧的隐藏条目还挂在列表上）
  static String _fsKey = '';

  /// 被文件操作改动过的路径：下次扫描下发给原生，只失效这些路径（含整棵子树），
  /// 让这一轮补扫优先重扫它们 —— 不整片清空，列表不会为了刷新跳一下
  static final Set<String> _dirtyPaths = <String>{};

  /// 本次扫描代次：原生在推送里原样回传，**旧代次的推送直接丢弃**
  static int _scanId = 0;

  /// 只有「默认设置」的扫描接收补扫推送（设置页那种临时自定义扫描不污染列表）
  static bool _acceptFsPush = false;

  /// 补扫结果有更新（页面监听它做**增量重建**，不重新查原生）。
  ///
  /// 对齐 mpvRx：MediaStore + 索引先上屏、隐藏目录的结果边扫边并入，
  /// 因此这个通知会在一次扫描里响若干次。
  static final ValueNotifier<int> fsRevision = ValueNotifier<int>(0);

  /// 当前合并后的视频列表（页面增量重建用；还没扫过时为 null）
  static List<VideoFile>? get cachedVideos => _cachedVideos;

  /// 测试用：清掉全部静态状态（这几份缓存是单例式的，跨用例会互相污染）
  @visibleForTesting
  static void resetForTest() {
    _cachedVideos = null;
    _baseVideos = const [];
    _fsVideos.clear();
    _fsKey = '';
    _dirtyPaths.clear();
    _scanId = 0;
    _acceptFsPush = false;
    _fsIndexDirty = false;
  }

  /// 视频扩展名：唯一真值是 [FileOps.videoExtensions]（「只删文件夹内的视频
  /// 文件」的删除集合与此处必须同源，否则会出现「扫描器不算视频、删除器却删」
  /// 的错位，见体检报告 P0-1）。
  static const List<String> videoExt = FileOps.videoExtensions;

  /// 整盘补扫索引失效标记（见 [markFsIndexDirty]）
  static bool _fsIndexDirty = false;

  /// 清除内存缓存（下拉刷新、页面重载时调用）。
  ///
  /// 只清 Dart 侧这次的内存结果；**原生侧的整盘补扫索引不受影响**（它自带续扫与
  /// 重扫间隔，见 `FsVideoWalker`），要重建得调 [markFsIndexDirty]。[_fsVideos]
  /// 也跟着留着：它是原生索引的镜像，下次扫描会与原生快结果重新合并。
  static void clearCache() {
    _cachedVideos = null;
  }

  /// 声明「整盘补扫要重新走一遍」（下拉刷新 / 一键清缓存）：下次扫描让原生**忽略
  /// 15 分钟重扫间隔**重新递归，但**索引与 Dart 镜像都原地保留** —— 这样刷新期间
  /// 列表不会少东西，扫完用完整快照替换（对齐 mpvRx `FolderListViewModel` 的
  /// 「先发布旧快照、扫完再 Replace」）。
  static void markFsIndexDirty() {
    _fsIndexDirty = true;
  }

  /// 声明「文件操作动过这些路径了」：只把改动过的路径（目录则连整棵子树）从补扫
  /// 那份里摘掉，并让下次扫描通知原生优先重扫它们 —— 不整片清空，只有真正改了
  /// 的地方会更新。
  static void invalidateFsPaths(Iterable<String> paths) {
    var changed = false;
    for (final path in paths) {
      if (path.isEmpty) continue;
      _dirtyPaths.add(path);
      // 目录整棵 / 文件自身：与原生 `FsVideoIndex.removeSubtree` 同一套规则
      final removed = _fsVideos.length;
      _fsVideos.removeWhere((p, _) => p == path || p.startsWith('$path/'));
      if (_fsVideos.length != removed) changed = true;
    }
    // 还没扫过（_cachedVideos == null）时不要凭空造一个空列表，否则页面会闪成空
    if (changed && _cachedVideos != null) _rebuildMerged(notify: true);
  }

  /// 原生 → Dart 推送入口（由 `DeviceServices` 的统一 MethodCallHandler 转发）：
  /// - `onFsVideoBatch`：整盘补扫的增量批次（边扫边推）；
  /// - `onFsScanDone`：整轮结束的完整快照 → **替换**增量累计，清掉已删除的条目。
  ///
  /// 代次不是最新的推送一律丢掉（原生那边线程还在跑，但条件已经换了）。
  static void handleNativeCall(MethodCall call) {
    if (call.method != 'onFsVideoBatch' && call.method != 'onFsScanDone') return;
    final args = call.arguments;
    if (args is! Map) return;
    final scanId = (args['scanId'] as num?)?.toInt();
    if (!_acceptFsPush || _cachedVideos == null) return;
    if (scanId == null || scanId != _scanId) return;

    final raw = args['videos'];
    if (raw is! List) return;
    final settings = MediaScanSettings.instance;
    final incoming = <VideoFile>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final video = _videoFromMap(item);
      // 推送的条目同样要过黑白名单（原生已按同一套规则剪过枝，这里兜底）
      if (video == null || !settings.isPathAllowed(video.path)) continue;
      incoming.add(video);
    }

    if (call.method == 'onFsScanDone') {
      _fsVideos.clear();
      for (final v in incoming) {
        _fsVideos[v.path] = v;
      }
    } else {
      for (final v in incoming) {
        _fsVideos[v.path] = v;
      }
    }
    _rebuildMerged(notify: true);
  }

  /// 查询所有本地视频（结合 MediaScanSettings 的 .nomedia、隐藏文件夹及黑白名单规则）
  static Future<List<VideoFile>> scanVideos({
    MediaScanSettings? scanSettings,
  }) async {
    final isCustomSettings = scanSettings != null;
    if (!isCustomSettings && _cachedVideos != null) return _cachedVideos!;

    final settings = scanSettings ?? MediaScanSettings.instance;
    await settings.ensureLoaded();

    // 一次性消费：本次请求带上 force / 失效路径，之后的请求不再重复
    final forceFsRescan = _fsIndexDirty;
    _fsIndexDirty = false;
    final invalidatePaths = _dirtyPaths.toList();
    _dirtyPaths.clear();

    // 新代次：上一代还在跑的补扫推送就此作废
    final scanId = ++_scanId;
    _acceptFsPush = !isCustomSettings;

    // 开关 / 名单变了才清补扫那份（原生会换索引）；刷新、换页、回前台一律不动它
    final fsKey = _fsConditionsKey(settings);
    if (fsKey != _fsKey) {
      _fsKey = fsKey;
      _fsVideos.clear();
    }

    final result = await _channel.invokeListMethod<dynamic>(
      'getVideos',
      {
        'includeNoMedia': settings.scanNoMedia,
        'includeHidden': settings.scanHiddenFolders,
        // 黑白名单**下推到原生剪枝**（白名单模式下只走白名单目录及其祖先，
        // 黑名单整棵跳过）；按当前模式发给原生，与 Dart 侧 isPathAllowed 同语义
        'whitelist': settings.filterMode == FolderFilterMode.whitelist
            ? settings.whitelistFolders
            : const <String>[],
        'blacklist': settings.filterMode == FolderFilterMode.blacklist
            ? settings.blacklistFolders
            : const <String>[],
        'forceFsRescan': forceFsRescan,
        'invalidatePaths': invalidatePaths,
        'scanId': scanId,
      },
    );
    if (result == null) return [];

    // 响应里带 `fs` 标记的条目来自整盘补扫索引 → 归到补扫那份（与推送同一归宿）；
    // 其余是 MediaStore 那份。两者分开维护，刷新时补扫那部分原地保留。
    final mediaStore = <VideoFile>[];
    final fromIndex = <String, VideoFile>{};
    for (final item in result) {
      if (item is! Map) continue;
      final video = _videoFromMap(item);
      if (video == null) continue;
      // 应用黑名单 / 白名单过滤规则
      if (!settings.isPathAllowed(video.path)) continue;
      if (item['fs'] == true) {
        fromIndex[video.path] = video;
      } else {
        mediaStore.add(video);
      }
    }

    if (isCustomSettings) {
      final videos = <VideoFile>[...mediaStore, ...fromIndex.values];
      videos.sort(_byName);
      return videos;
    }
    _baseVideos = mediaStore;
    // 合并而不是替换：后台这一轮已经推过来的新条目不能因为一次再扫描被抖掉，
    // 由 `onFsScanDone` 的完整快照负责收口（清掉已消失的）
    _fsVideos.addAll(fromIndex);
    _rebuildMerged();
    return _cachedVideos!;
  }

  /// 补扫条件的指纹：开关 / 黑白名单一变，原生换索引，Dart 侧镜像也必须跟着清
  static String _fsConditionsKey(MediaScanSettings s) => <String>[
        '${s.scanNoMedia}',
        '${s.scanHiddenFolders}',
        s.filterMode.name,
        s.whitelistFolders.join(','),
        s.blacklistFolders.join(','),
      ].join('|');

  /// 原生条目 → [VideoFile]（缺字段按 0 / null 兜底；没有 path 返回 null）
  static VideoFile? _videoFromMap(Map<dynamic, dynamic> map) {
    final path = map['path'] as String? ?? '';
    if (path.isEmpty) return null;
    final dateModifiedMs = (map['dateModifiedMs'] as num?)?.toInt();
    return VideoFile(
      path: path,
      name: map['name'] as String? ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      size: (map['size'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      dateModified: dateModifiedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dateModifiedMs)
          : null,
    );
  }

  static int _byName(VideoFile a, VideoFile b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  /// 重算合并结果 = 原生快结果 ∪ 补扫增量（同一路径以原生那份为准）。
  ///
  /// [notify] = true 时通知页面重建（增量推送走这条）。
  static void _rebuildMerged({bool notify = false}) {
    final seen = <String>{};
    final merged = <VideoFile>[];
    for (final v in _baseVideos) {
      if (seen.add(v.path)) merged.add(v);
    }
    for (final v in _fsVideos.values) {
      if (seen.add(v.path)) merged.add(v);
    }
    merged.sort(_byName);
    _cachedVideos = merged;
    if (notify) fsRevision.value++;
  }

  /// 某个本地视频所在文件夹的兄弟视频列表（播放页「下一集」/播放列表面板用）。
  ///
  /// 首页与文件夹页播放时会把「当前可见的排序列表」直接传给播放页，而
  /// 「最近播放」「历史记录」「外部打开」这三个入口手上没有列表——按视频
  /// 路径反查媒体库补全，避免播放列表面板空着（只显示「当前文件夹没有
  /// 其他视频」）。
  ///
  /// - [path] 不是本地绝对路径（在线直链 / B 站与网络存储的本机代理流）→ 空表；
  /// - 媒体库不可用（权限被拒 / 通道异常）→ 抛出，由调用方决定是否忽略；
  /// - 排序 = 名称自然序升序，与播放列表面板默认排序一致。
  static Future<List<VideoFile>> folderSiblingsOf(String path) async {
    if (!path.startsWith('/')) return const [];
    final folder = folderOfPath(path);
    if (folder.isEmpty) return const [];
    final videos = await scanVideos();
    return sortVideosForPlaylist(
      filterVideosInFolder(videos, folder),
      PlaylistSortMode.nameAsc,
    );
  }

  /// 构建完整目录树：从存储卷根开始，包含中间目录（只含子文件夹的目录
  /// 也会保留），并递归聚合每个文件夹的视频数量 / 总大小 / 最新修改时间。
  ///
  /// 顶层节点 = 各存储卷根下的直接子目录（folder）与直接视频（video）。
  static List<TreeNode> buildTree(List<VideoFile> videos) {
    if (videos.isEmpty) return [];

    final root = _TreeBuilder.root();
    for (final v in videos) {
      final dir = _dirOf(v.path);
      final segs = dir.split('/').where((s) => s.isNotEmpty).toList();
      final rootSegs = _rootSegCount(segs);

      if (rootSegs <= 0) {
        // 无法识别存储根：直接作为顶层视频
        root.videos.add(v);
        continue;
      }

      final rootPath = '/${segs.sublist(0, rootSegs).join('/')}';
      var node = root;
      var pathSoFar = rootPath;
      for (var i = rootSegs; i < segs.length; i++) {
        pathSoFar = '$pathSoFar/${segs[i]}';
        node = node.childFolder(segs[i], pathSoFar);
      }
      node.videos.add(v);
    }

    final nodes = <TreeNode>[];
    for (final f in root.folders.values) {
      nodes.add(f.toTreeNode());
    }
    for (final v in root.videos) {
      nodes.add(
        TreeNode(
          name: v.name,
          path: v.path,
          type: TreeNodeType.video,
          video: v,
        ),
      );
    }
    // 文件夹在前、视频在后，各按名称升序
    nodes.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return nodes;
  }

  /// 列表模式：按视频「直接父目录」分组，返回所有含直接视频的文件夹。
  /// 每个文件夹的 children 只含它的直接视频，videoCount 为直接视频数。
  static List<TreeNode> buildFolderList(List<VideoFile> videos) {
    final map = <String, List<VideoFile>>{};
    for (final v in videos) {
      map.putIfAbsent(_dirOf(v.path), () => []).add(v);
    }

    final folders = <TreeNode>[];
    for (final e in map.entries) {
      final path = e.key;
      final name = path.contains('/')
          ? path.substring(path.lastIndexOf('/') + 1)
          : path;

      var totalSize = 0;
      DateTime? modified;
      final videoChildren = <TreeNode>[];
      for (final v in e.value) {
        totalSize += v.size;
        if (modified == null ||
            (v.dateModified != null && v.dateModified!.isAfter(modified))) {
          modified = v.dateModified;
        }
        videoChildren.add(
          TreeNode(
            name: v.name,
            path: v.path,
            type: TreeNodeType.video,
            video: v,
          ),
        );
      }

      folders.add(
        TreeNode(
          name: name,
          path: path,
          type: TreeNodeType.folder,
          children: videoChildren,
          videoCount: e.value.length,
          totalSize: totalSize,
          dateModified: modified,
        ),
      );
    }

    folders.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return folders;
  }

  /// 从视频绝对路径取父目录
  static String _dirOf(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  /// 目录 [path] 所属的**存储卷根**：`/storage/emulated/0`、`/storage/XXXX-XXXX`、
  /// `/mnt/<x>/<y>`（模拟器共享目录、`/mnt/media_rw/<uuid>` 等）；识别不出返回 null。
  ///
  /// 与 [buildTree] 共用同一套「卷根段数」规则（[_rootSegCount]），避免两处各判一次
  /// 而漂移。传**目录**路径（树节点都是目录；卷根下的直接视频归属要靠 [_dirOf] 先取父目录）。
  static String? volumeRootOf(String path) {
    if (path.isEmpty || !path.startsWith('/')) return null;
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return null;
    final rootSegs = _rootSegCount(segs);
    if (rootSegs <= 0) return null;
    return '/${segs.take(rootSegs).join('/')}';
  }

  /// 识别存储卷根占用的段数：
  /// - /storage/emulated/0 → 3 段（内部存储）
  /// - /storage/XXXX-XXXX → 2 段（SD 卡 / U 盘）
  /// - `/mnt/<x>/<y>` → 3 段（模拟器共享目录、`/mnt/media_rw/<uuid>` 这类挂在 /mnt
  ///   下的卷；原生侧非主卷扫描给出的正是这种路径）；不足 3 段的（如 /mnt/odd）
  ///   按实际段数当卷根
  /// - 其他 → 0（无法识别，视频作为顶层节点兜底）
  static int _rootSegCount(List<String> segs) {
    if (segs.length >= 3 && segs[0] == 'storage' && segs[1] == 'emulated') {
      return 3;
    }
    if (segs.length >= 2 && segs[0] == 'storage') {
      return 2;
    }
    if (segs.isNotEmpty && segs[0] == 'mnt') {
      return segs.length >= 3 ? 3 : segs.length;
    }
    return 0;
  }
}

/// 构建树用的可变节点
class _TreeBuilder {
  final String name;
  final String path;
  final Map<String, _TreeBuilder> folders = {};
  final List<VideoFile> videos = [];

  _TreeBuilder({required this.name, required this.path});

  static _TreeBuilder root() => _TreeBuilder(name: '', path: '');

  _TreeBuilder childFolder(String name, String path) {
    return folders.putIfAbsent(
      path,
      () => _TreeBuilder(name: name, path: path),
    );
  }

  TreeNode toTreeNode() {
    final children = <TreeNode>[];

    for (final f in folders.values) {
      children.add(f.toTreeNode());
    }
    for (final v in videos) {
      children.add(
        TreeNode(
          name: v.name,
          path: v.path,
          type: TreeNodeType.video,
          video: v,
        ),
      );
    }
    // 文件夹在前、视频在后，各按名称升序
    children.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // 递归聚合：视频总数 / 总大小 / 最新修改时间
    var count = 0;
    var size = 0;
    DateTime? modified;
    for (final c in children) {
      if (c.type == TreeNodeType.video) {
        count++;
        size += c.video!.size;
        if (c.video!.dateModified != null &&
            (modified == null || c.video!.dateModified!.isAfter(modified))) {
          modified = c.video!.dateModified;
        }
      } else {
        count += c.videoCount;
        size += c.totalSize;
        if (c.dateModified != null &&
            (modified == null || c.dateModified!.isAfter(modified))) {
          modified = c.dateModified;
        }
      }
    }

    return TreeNode(
      name: name,
      path: path,
      type: TreeNodeType.folder,
      children: children,
      videoCount: count,
      totalSize: size,
      dateModified: modified,
    );
  }
}
