import 'package:flutter/material.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/network/network_connection_settings.dart';
import 'package:moumou/services/network/network_directory_cache.dart';
import 'package:moumou/services/network/network_repository.dart';
import 'package:moumou/services/network/network_view_settings.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/async_session.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/utils/network_entry_filter.dart';
import 'package:moumou/utils/network_mime_types.dart';
import 'package:moumou/utils/network_sort.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/folder_card.dart';
import 'package:moumou/widgets/video_card.dart';

/// 在线目录浏览页：复用主页的 FolderCard / VideoCard 呈现远端文件夹与视频列表。
///
/// ⚠️ **能显示的字段以「远端列目录真的给得出」为上限**（改这里前先读）：
/// 名称、是否目录、修改时间（服务器可能不给 → 0）是三个协议（SMB/WebDAV/FTP）
/// 都可靠的字段。**大小**只有部分服务器给（WebDAV 不给 `getcontentlength`、
/// FTP 无 MLSD、SMB 某些实现都会是 0/-1），**时长/分辨率/帧率/字幕/进度**在
/// 列目录时一律拿不到（要解容器或整目录扫描）。因此本页：
/// - 文件夹卡片只显示**日期**；视频卡片显示**日期 + 完整名称**，外加
///   **时长**（唯一例外：播过一次的视频由播放页回报真实时长并记住，没播过的
///   就不显示——不猜、不造假）；
/// - 排序只有**名称 / 日期**（各升降序），自带一套偏好，不用本地那套
///   「名称/日期/大小/数量 + 字段开关」——那些在远端排不动、显示了也是假的；
/// - 不显示大小、不显示子目录视频数。
///
/// 其余能力：搜索（本目录）、下拉刷新、回到共享根、默认隐藏 NAS 元数据项
/// （`.`/`@eaDir` 等，可开）、目录列表走 [NetworkDirectoryCache]（返回上级瞬时）。
class NetworkBrowserPage extends StatefulWidget {
  final NetworkConnection connection;

  /// 视图设置（仅用于读用户对「完整名称」的偏好；排序走网络页自带的那套）。
  /// 不传时本页自建一份。
  final ViewSettings? viewSettings;

  /// 浏览回调（默认走 [NetworkRepository.instance.browse]；测试注入用）。
  final Future<List<NetworkFile>> Function(NetworkConnection, String)? browse;

  /// 目录缓存（默认本页自建一份；测试可注入独立实例避免互相污染）。
  final NetworkDirectoryCache? cache;

  const NetworkBrowserPage({
    super.key,
    required this.connection,
    this.viewSettings,
    this.browse,
    this.cache,
  });

  @override
  State<NetworkBrowserPage> createState() => _NetworkBrowserPageState();
}

class _NetworkBrowserPageState extends State<NetworkBrowserPage> {
  late final List<String> _stack;
  List<NetworkFile> _entries = [];
  bool _loading = true;
  String? _error;

  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// 加载会话号：快速连点进目录 / 点返回时，旧请求的响应回来不能再覆盖新列表
  /// （否则会出现「父目录标题 + 子目录内容」的错位，P2-22）。
  final AsyncSession _loadSession = AsyncSession();

  final NetworkViewSettings _netSettings = NetworkViewSettings.instance;
  late final ViewSettings _viewSettings = widget.viewSettings ?? ViewSettings();
  late final NetworkDirectoryCache _cache =
      widget.cache ?? NetworkDirectoryCache();

  String get _path => _stack.last;

  @override
  void initState() {
    super.initState();
    // 路径字段语义因协议而异，必须区分，否则会拼出双份路径（如 /dav/dav/ → 404）：
    // - SMB：connection.path 是「初始目录/共享名」（SMB 客户端不把它当基前缀），
    //   填 `/共享名` 时跳过列共享、直接进入该共享（部分 Windows 拒绝列共享、只能直连共享）；
    // - FTP/WebDAV：connection.path 是「根路径基前缀」（客户端请求时会再拼一层），
    //   浏览必须从 `/` 开始，才能拼成 connection.path + /xxx。
    final p = widget.connection.path;
    final initial = widget.connection.protocol == NetworkProtocol.smb
        ? ((p.isEmpty || p == '/') ? '/' : p)
        : '/';
    _stack = [initial];
    _viewSettings.ensureLoaded();
    _netSettings.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadSession.invalidate();
    super.dispose();
  }

  // ── 加载 ────────────────────────────────────────────────

  /// 缓存键：同一条连接同一个远端目录。连接 id 为 0（未入库）时补齐
  /// host/protocol/port，避免不同账户互相命中。
  String _cacheKey(String dir) {
    final c = widget.connection;
    final conn = c.id > 0
        ? '${c.id}'
        : '${c.protocol.name}:${c.host}:${c.port}${c.path}';
    return '$conn::$dir';
  }

  /// 实际列目录：先查缓存，没有再走协议客户端。
  Future<List<NetworkFile>> _listDirectory(String dir, {bool useCache = true}) async {
    final key = _cacheKey(dir);
    if (useCache) {
      final cached = _cache.get(key);
      if (cached != null) return cached;
    }
    final files = await (widget.browse ?? NetworkRepository.instance.browse)(
      widget.connection,
      dir,
    );
    _cache.put(key, files);
    return files;
  }

  Future<void> _load({bool force = false}) async {
    final dir = _path;
    final session = _loadSession.start();
    setState(() {
      _loading = true;
      _error = null;
    });
    if (force) _cache.invalidate(_cacheKey(dir));
    try {
      final entries = await _listDirectory(dir, useCache: !force);
      if (!mounted || !_loadSession.isCurrent(session)) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || !_loadSession.isCurrent(session)) return;
      setState(() {
        _error = e is NetworkClientException ? e.message : '连接失败：$e';
        _loading = false;
      });
    }
  }

  void _openFolder(NetworkFile folder) {
    setState(() {
      _stack.add(folder.path);
      _entries = [];
      _query = '';
      _searchController.clear();
    });
    _load();
  }

  void _popLevel() {
    if (_stack.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stack.removeLast();
      _entries = [];
      _query = '';
      _searchController.clear();
    });
    _load();
  }

  Future<void> _popToRoot() async {
    if (_stack.length <= 1) return;
    setState(() {
      _stack.removeRange(1, _stack.length);
      _entries = [];
      _query = '';
      _searchController.clear();
    });
    await _load();
  }

  // ── 播放 ────────────────────────────────────────────────

  /// 当前有效的连接配置：账户在浏览期间被编辑过时以最新配置为准
  /// （旧对象里的密码可能已经变了，用它建流会认证失败）。
  NetworkConnection get _connection {
    final id = widget.connection.id;
    if (id <= 0) return widget.connection;
    return NetworkConnectionSettings.instance.byId(id) ?? widget.connection;
  }

  Future<void> _openVideo(VideoFile video) async {
    final url = await NetworkRepository.instance.playbackUrl(
      _connection,
      video.remotePath!,
      fileSize: video.size > 0 ? video.size : -1,
      mimeType: networkMimeTypeForFileName(video.name) ?? 'video/mp4',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      playerPageRoute(
        PlayerPage(
          path: url,
          title: video.name,
          // 带上网络来源：字幕侧据此扫描远端同目录的同名字幕
          // （本地 `File` 链路对 loopback URL 不成立）
          networkSource: video,
          // 退出时把真实时长回写到列表（远端不做探测，靠「播过一次就记住」）；
          // 远端路径由播放页带上——播放页内切集后回报的是新一集的时长，
          // 不能记到打开时那一条上
          onDurationKnown: _rememberDuration,
        ),
      ),
    );
    await NetworkRepository.instance.releasePlayback(url);
    if (mounted) setState(() {});
  }

  /// 记住某个远端视频的真实时长（播放页回报；键 = 连接 id + 远端路径，
  /// 与回环播放 URL 无关——那条 URL 每次播放都换 token）。
  Future<void> _rememberDuration(String remotePath, int durationMs) async {
    if (durationMs <= 0 || remotePath.isEmpty) return;
    await _netSettings.rememberDuration(
      '${_connection.id}|$remotePath',
      durationMs,
    );
    if (mounted) setState(() {});
  }

  // ── 视图数据 ────────────────────────────────────────────

  /// 当前目录可见条目（隐藏项过滤 + 搜索 + 排序）。
  List<NetworkFile> _visibleEntries() {
    final shown = visibleNetworkEntries(
      _entries,
      showHidden: _netSettings.showHidden,
    );
    return searchNetworkEntries(shown, _query);
  }

  /// 文件夹与视频各自排序（列表里文件夹恒在视频前，两类之间不混排）。
  ({List<NetworkFile> folders, List<NetworkFile> videos, List<NetworkFile> others})
      _sections() {
    final sort = _netSettings.sort;
    final visible = _visibleEntries();
    final folders = sortNetworkEntries(
      visible.where((e) => e.isDirectory).toList(),
      sort,
    );
    final videos = sortNetworkEntries(
      visible.where((e) => !e.isDirectory && isNetworkVideoFile(e.name)).toList(),
      sort,
    );
    // 非视频文件（字幕 / 图片 / 文本等）同样列出，只是不可点击——避免目录
    // 只含非视频文件时出现「点进去一片空白」的问题。
    final others = sortNetworkEntries(
      visible.where((e) => !e.isDirectory && !isNetworkVideoFile(e.name)).toList(),
      sort,
    );
    return (folders: folders, videos: videos, others: others);
  }

  VideoFile _toVideoFile(NetworkFile f) => VideoFile(
        path: f.path,
        name: f.name,
        // 时长只有「播过一次」才知道（远端不做探测）；size 不显示，不用填
        durationMs: _netSettings.durationFor('${_connection.id}|${f.path}'),
        dateModified: f.lastModified > 0
            ? DateTime.fromMillisecondsSinceEpoch(f.lastModified)
            : null,
        source: VideoSource.network,
        remotePath: f.path,
        connectionId: _connection.id,
      );

  /// 文件夹卡片节点：**只有日期**（大小/数量在远端不可靠或拿不到）。
  TreeNode _folderNode(NetworkFile f) => TreeNode(
        name: f.name,
        path: f.path,
        type: TreeNodeType.folder,
        dateModified: f.lastModified > 0
            ? DateTime.fromMillisecondsSinceEpoch(f.lastModified)
            : null,
      );

  // ── 界面 ────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  /// 排序选择：只有名称 / 日期两项（都是远端真拿得到的）。
  ///
  /// 点选即生效并关闭（不走 RadioListTile——它的 groupValue 在 Flutter 3.32+
  /// 已废弃）。
  Future<void> _showSortSheet() async {
    final current = _netSettings.sort;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '排序方式',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            for (final field in NetworkSortField.values)
              for (final order in NetworkSortOrder.values)
                ListTile(
                  dense: true,
                  title: Text('按${field.label}${order.label}'),
                  trailing: current.field == field && current.order == order
                      ? Icon(Icons.check, color: Theme.of(sheetContext).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _applySort(NetworkSort(field: field, order: order));
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _applySort(NetworkSort sort) async {
    await _netSettings.setSort(sort);
    if (mounted) setState(() {});
  }

  Future<void> _toggleShowHidden() async {
    await _netSettings.setShowHidden(!_netSettings.showHidden);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 拦截系统返回键/手势，与左上角返回一致：逐级回上一级目录，
      // 到根（_stack 只剩一层）时才真正退出本页。
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popLevel();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: BackButton(onPressed: _popLevel),
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索本目录',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            )
          : Text(_title()),
      actions: [
        IconButton(
          icon: Icon(_searching ? Icons.close : Icons.search),
          tooltip: _searching ? '取消搜索' : '搜索',
          onPressed: _toggleSearch,
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: '排序方式',
          onPressed: _showSortSheet,
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                _load(force: true);
              case 'root':
                _popToRoot();
              case 'hidden':
                _toggleShowHidden();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'refresh', child: Text('刷新本目录')),
            if (_stack.length > 1)
              const PopupMenuItem(value: 'root', child: Text('回到共享根目录')),
            CheckedPopupMenuItem(
              value: 'hidden',
              checked: _netSettings.showHidden,
              child: const Text('显示隐藏文件'),
            ),
          ],
        ),
      ],
    );
  }

  String _title() {
    if (_path == '/') return widget.connection.name;
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? widget.connection.name : segments.last;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(
        icon: Icons.error_outline,
        message: _error!,
        buttonText: '重试',
        onPressed: () => _load(force: true),
      );
    }
    final sections = _sections();
    final total = sections.folders.length +
        sections.videos.length +
        sections.others.length;
    if (total == 0) {
      return _message(
        icon: Icons.folder_off_outlined,
        message: _query.isNotEmpty
            ? '没有匹配的文件'
            : (_entries.isEmpty ? '该目录为空' : '本目录只有隐藏文件'),
        buttonText: _query.isNotEmpty ? '清除搜索' : '返回上一级',
        onPressed: _query.isNotEmpty ? _toggleSearch : _popLevel,
      );
    }

    final foldersEnd = sections.folders.length;
    final videosEnd = foldersEnd + sections.videos.length;

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        // 始终可滚动：空列表/短列表也要能下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: total,
        itemBuilder: (context, index) {
          if (index < foldersEnd) {
            final folder = sections.folders[index];
            final node = _folderNode(folder);
            return FolderCard(
              key: ValueKey('dir:${folder.path}'),
              node: node,
              // 只有日期：远端拿不到大小/数量，这两项一个都不显示
              fields: {if (node.dateModified != null) FolderField.date},
              onTap: () => _openFolder(folder),
            );
          }
          if (index < videosEnd) {
            final video = sections.videos[index - foldersEnd];
            final file = _toVideoFile(video);
            return VideoCard(
              key: ValueKey('file:${video.path}'),
              video: file,
              // 远端列目录给不出大小/进度/帧率/字幕，一律不放。唯一的例外是
              // **时长**：播过一次后由播放页回报并记住
              // （[NetworkViewSettings.rememberDuration]）；没播过的没有值，
              // 这时不请求该字段，卡片也就不会显出一个假的时长。
              fields: {
                VideoField.date,
                if (file.durationMs > 0) VideoField.duration,
                if (_viewSettings.videoFields.contains(VideoField.fullName))
                  VideoField.fullName,
              },
              onTap: () => _openVideo(file),
              onLongPress: () => _showFileDetails(video),
            );
          }
          return _OtherFileTile(file: sections.others[index - videosEnd]);
        },
      ),
    );
  }

  /// 长按远端视频：只读详情（名称/修改时间/远端路径/连接）。
  ///
  /// 端点信息（协议 + host:port）不敏感（账户列表卡片本来就在显示），
  /// 远端路径是排查「放哪了 / 字幕该放哪」的关键，两者都保留。
  /// 大小不列——服务器常给 0/-1，显示「未知」没有意义。
  void _showFileDetails(NetworkFile file) {
    final c = _connection;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow(
                '修改时间',
                file.lastModified > 0
                    ? formatDate(
                        DateTime.fromMillisecondsSinceEpoch(file.lastModified),
                      )
                    : '服务器未提供',
              ),
              _detailRow('位置', file.path),
              _detailRow('连接', '${c.protocol.displayName} · ${c.host}:${c.port}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: scheme.outline),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

/// 非视频文件条目：只读展示（不可点击播放），保证目录不因过滤而空白。
class _OtherFileTile extends StatelessWidget {
  final NetworkFile file;

  const _OtherFileTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 字幕类文件给个专用图标：远端目录里字幕往往和视频同目录，一眼可辨
    final mime = networkMimeTypeForFileName(file.name);
    final isSubtitle = mime == 'text/plain' || mime == 'text/vtt';
    final date = file.lastModified > 0
        ? formatDate(DateTime.fromMillisecondsSinceEpoch(file.lastModified))
        : '';
    return ListTile(
      dense: true,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isSubtitle ? Icons.subtitles_outlined : Icons.insert_drive_file_outlined,
          size: 20,
          color: scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // 大小同样不显示（部分服务器给 0/-1）；只有服务器给了时间才显示日期
      subtitle: date.isEmpty
          ? null
          : Text(
              date,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
    );
  }
}
