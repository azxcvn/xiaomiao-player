import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/home/folder_detail_page.dart';
import 'package:moumou/pages/home/open_link_dialog.dart';
import 'package:moumou/pages/home/tree_folder_page.dart';
import 'package:moumou/pages/home/views/folder_list_view.dart';
import 'package:moumou/pages/home/views/tree_list_view.dart';
import 'package:moumou/pages/bilibili/bili_index_page.dart';
import 'package:moumou/services/bilibili/bili_account.dart';
import 'package:moumou/pages/media_info/media_info_page.dart';
import 'package:moumou/pages/network/network_storage_page.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/services/file_selection_controller.dart';
import 'package:moumou/services/playback_history_service.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/pinned_folders_settings.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/video_scanner.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/file_selection.dart';
import 'package:moumou/utils/folder_pin.dart';
import 'package:moumou/utils/url_media.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/file_selection_ui.dart';
import 'package:moumou/widgets/folder_actions.dart';
import 'package:moumou/widgets/options_sheet.dart';
import 'package:moumou/widgets/speed_dial_fab.dart';
import 'package:permission_handler/permission_handler.dart';

/// 首页速拨 FAB 相对 Scaffold 默认 endFloat 位置的额外右移避让量：
/// 让按钮离屏幕右缘更远一点（仅首页生效，不影响其他页面）。
const double kHomeFabInsetRight = 12;

/// 首页：展示视频库（列表视图 / 树状视图，两种视图共用同一棵目录树）。
///
/// 右上角从左到右：**搜索**（文件夹 + 视频文件名过滤）→ 排序与字段。
class HomePage extends StatefulWidget {
  final ViewSettings viewSettings;

  const HomePage({super.key, required this.viewSettings});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<TreeNode> _roots = []; // 树状模式：完整目录树
  List<TreeNode> _folders = []; // 列表模式：含直接视频的文件夹
  bool _loading = true;
  bool _permissionDenied = false;

  /// 搜索状态：false = 正常标题栏；true = 显示搜索输入框
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  /// 多选状态（页面级：不跨页、不持久化，退出页面即丢弃）
  final FileSelectionController _selection = FileSelectionController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统文件管理器或其他应用切回时，自动刷新视频列表（感知外部重命名/移动/删除）
    if (state == AppLifecycleState.resumed && mounted && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    // 只检查权限状态，不主动弹权限请求（首次进入由用户点击「授予权限」触发）
    final granted = await _hasStoragePermission();
    if (!granted) {
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      return;
    }

    // 刷新时清缓存，重新查询 MediaStore（否则新增/删除的视频不生效）
    VideoScanner.clearCache();
    final videos = await VideoScanner.scanVideos();
    // 建树 / 建文件夹列表移到后台 isolate（compute）执行：排序、建树、聚合
    // 是同步纯函数，视频量几千条时在 UI 线程跑会有几十毫秒级卡顿
    // （risk_audit #6）。TreeNode/VideoFile 均为纯数据（String/int/DateTime/
    // List），可跨 isolate 传输；两条计算并行发起的独立 isolate。
    final rootsFuture = compute(VideoScanner.buildTree, videos); // 树状模式：完整目录树
    final foldersFuture =
        compute(VideoScanner.buildFolderList, videos); // 列表模式：含直接视频的文件夹
    final roots = await rootsFuture;
    final folders = await foldersFuture;
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _folders = folders;
      _loading = false;
    });
  }

  /// 检查「允许管理所有文件」权限（低版本 Android 回退到存储权限）
  Future<bool> _hasStoragePermission() async {
    try {
      return await Permission.manageExternalStorage.status.isGranted;
    } catch (_) {
      return await Permission.storage.status.isGranted;
    }
  }

  /// 点击「授予权限」：跳转系统授权界面（允许此 App 管理所有文件），
  /// 授权后自动扫描视频；未授权则停留在提示界面可再次点击
  Future<void> _grantPermission() async {
    bool granted;
    try {
      granted = await Permission.manageExternalStorage
          .request()
          .then((s) => s.isGranted);
    } catch (_) {
      granted = await Permission.storage.request().then((s) => s.isGranted);
    }
    if (granted) {
      await _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  void _showViewOptions() {
    showSortOptionsSheet(
      context,
      widget.viewSettings,
      hasFolders: true,
      hasVideos: false,
      showViewMode: true,
    );
  }

  // ── 搜索 ──────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  void _onQueryChanged(String v) => setState(() => _query = v.trim().toLowerCase());

  /// 按名称过滤（不区分大小写）
  bool _matchName(String name) {
    if (_query.isEmpty) return true;
    return name.toLowerCase().contains(_query);
  }

  /// 树状模式过滤：递归过滤（文件夹名匹配保留整棵子树；视频名匹配保留自身）
  List<TreeNode> _filterTree(List<TreeNode> nodes) {
    final result = <TreeNode>[];
    for (final n in nodes) {
      if (n.isFolder) {
        final children = _filterTree(n.children);
        if (children.isNotEmpty || _matchName(n.name)) {
          result.add(_rebuildFolder(n, children));
        }
      } else if (_matchName(n.name)) {
        result.add(n);
      }
    }
    return result;
  }

  TreeNode _rebuildFolder(TreeNode n, List<TreeNode> children) {
    if (identical(children, n.children)) return n;
    return TreeNode(
      name: n.name,
      path: n.path,
      type: n.type,
      children: children,
      videoCount: n.videoCount,
      totalSize: n.totalSize,
      dateModified: n.dateModified,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 多选态整页重建：AppBar 换成选择工具栏、悬浮速拨收起
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => PopScope(
        // 多选态下系统返回键先退出多选，而不是退出页面
        canPop: !_selection.selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selection.exit();
        },
        child: Scaffold(
          appBar:
              _selection.selecting ? _buildSelectionAppBar() : _buildAppBar(),
          body: _buildBody(),
          // 右下角加号略高于悬浮胶囊导航栏（与网络存储页保持同一高度），
          // 水平方向额外左移 12dp，离屏幕右缘更远（仅首页调整）。
          // 多选态收起速拨：它会压住列表末尾几项，而此刻的主操作在顶部工具栏
          floatingActionButton: _selection.selecting
              ? null
              : Padding(
                  padding: const EdgeInsets.only(
                    bottom: kFabLiftAboveNav,
                    right: kHomeFabInsetRight,
                  ),
                  child: _buildSpeedDial(),
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索文件夹与视频',
                border: InputBorder.none,
              ),
              onChanged: _onQueryChanged,
            )
          : const Text('小喵Player'),
      actions: [
        if (_searching)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '取消搜索',
            onPressed: _toggleSearch,
          )
        else
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: _toggleSearch,
          ),
        IconButton(
          icon: const Icon(Icons.sort),
          tooltip: '排序与视图',
          onPressed: _showViewOptions,
        ),
      ],
    );
  }

  /// 多选态顶部工具栏（`[×] 已选 N 项 [全选] [⋮]`）；全选范围 = 当前可见列表
  PreferredSizeWidget _buildSelectionAppBar() {
    final visible = _visibleNodes().map((n) => n.path).toList();
    final allSelected = _selection.containsAll(visible);
    return buildFileSelectionAppBar(
      count: _selection.count,
      allSelected: allSelected,
      onExit: _selection.exit,
      onToggleAll: () => _selection.setAll(visible, selected: !allSelected),
      onOpenMenu: () => _openSelectionMenu(),
    );
  }

  /// 右下角速拨按钮：最近播放 / 打开链接 / 哔哩番剧 / 网络存储。
  /// 「哔哩番剧」进入番剧索引页（阶段二）；「最近播放」直启最后一次播放的
  /// 视频（工作.md：播放历史记录功能）；「打开链接」弹窗输入直链在线播放
  /// （工作.md：链接播放功能）。
  Widget _buildSpeedDial() {
    return SpeedDialFab(
      heroTag: 'home_speed_dial',
      actions: [
        SpeedDialAction(
          icon: Icons.history,
          label: '最近播放',
          onTap: _openRecent,
        ),
        SpeedDialAction(
          icon: Icons.link,
          label: '打开链接',
          onTap: _openLink,
        ),
        SpeedDialAction(
          icon: Icons.live_tv_outlined,
          label: '哔哩番剧',
          onTap: _openBiliBangumi,
        ),
        SpeedDialAction(
          icon: Icons.cloud_outlined,
          label: '网络存储',
          onTap: _openNetworkStorage,
        ),
      ],
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 最近播放（工作.md：播放历史记录功能）：直接播放**最后一次**播放的
  /// 视频；进度由播放页按保存的播放进度自动恢复。无历史提示；本地文件
  /// 已被删除/移动时提示（条目保留，可在「历史记录」页管理删除）。
  Future<void> _openRecent() async {
    final history = PlaybackHistoryService.instance;
    await history.ensureLoaded();
    if (!mounted) return;
    final entry = history.mostRecent;
    if (entry == null) {
      _toast('暂无播放历史');
      return;
    }
    if (!entry.isUrl && !File(entry.path).existsSync()) {
      _toast('文件不存在或已被移动：${entry.title}');
      return;
    }
    await Navigator.of(context).push(
      playerPageRoute(PlayerPage(path: entry.path, title: entry.title)),
    );
    // 返回后刷新，进度条立即更新
    if (mounted) setState(() {});
  }

  /// 打开链接（工作.md：链接播放功能）：弹窗输入在线视频直链 → 播放。
  /// 章节信息由 mpv 解封装远程容器原生读取（对齐 mpvRx：直链交给 mpv，
  /// 章节随容器自带，无需网站接口）。参考 mpvRx 的实现。
  Future<void> _openLink() async {
    await showOpenLinkDialog(
      context,
      onPlay: (url) {
        Navigator.of(context).push(
          playerPageRoute(
            PlayerPage(path: url, title: mediaTitleFromUrl(url)),
          ),
        );
      },
    );
  }

  Future<void> _openNetworkStorage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NetworkStoragePage()),
    );
  }

  void _openBiliBangumi() {
    // 未登录哔哩哔哩账号时仅提示，不进入番剧页（番剧索引/详情接口需要登录态）。
    if (!BiliAccount.instance.isLogin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('需要登录哔哩哔哩账号')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BiliIndexPage()),
    );
  }

  /// 当前视图下**可见（已排序、已过滤）**的节点列表：
  /// 树状模式 = 一级界面列表（根层文件夹 + 根层视频），列表模式 = 文件夹列表。
  ///
  /// 单独抽出来是因为「全选」的范围必须和用户眼睛看到的一致；排序 / 固定前置 /
  /// 搜索过滤三件事也必须在同一处裁决，否则会出现第二套排序真值。
  List<TreeNode> _visibleNodes() {
    final pinnedPaths = PinnedFoldersSettings.instance.paths;
    if (widget.viewSettings.viewMode == ViewMode.tree) {
      var roots = widget.viewSettings.sortTree(_roots);
      roots = mapTreeWithPinnedFirst(roots, pinnedPaths);
      if (_query.isNotEmpty) roots = _filterTree(roots);
      return roots;
    }
    var folders = widget.viewSettings.sortFolders(_folders);
    folders = pinnedFoldersFirst(folders, pinnedPaths);
    if (_query.isNotEmpty) {
      folders = folders.where((n) => _matchName(n.name)).toList();
    }
    return folders;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return _buildMessage(
        icon: Icons.folder_open,
        message: '需要授予存储权限才能扫描视频',
        buttonText: '授予权限',
        buttonIcon: Icons.lock_open,
        onPressed: _grantPermission,
      );
    }
    if (_roots.isEmpty) {
      return _buildMessage(
        icon: Icons.folder_off_outlined,
        message: '没有找到视频',
        buttonText: '重新扫描',
        onPressed: _load,
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.viewSettings,
        PlaybackProgressService.instance,
        PlayerControlsSettings.instance,
        PinnedFoldersSettings.instance,
      ]),
      builder: (context, _) {
        final pinnedPaths = PinnedFoldersSettings.instance.paths;
        final selectedPaths = _selection.paths.toSet();
        final nodes = _visibleNodes();
        if (widget.viewSettings.viewMode == ViewMode.tree) {
          if (nodes.isEmpty && _query.isNotEmpty) {
            return const Center(child: Text('没有匹配的内容'));
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: TreeListView(
              roots: nodes,
              folderFields: widget.viewSettings.fields,
              videoFields: widget.viewSettings.videoFields,
              pinnedPaths: pinnedPaths,
              onFolderTap: _onFolderTap,
              onVideoTap: _onVideoTap,
              onVideoInfoTap: _openMediaInfo,
              onFolderLongPress: _onFolderLongPress,
              onVideoLongPress: _onVideoLongPress,
              selectionMode: _selection.selecting,
              selectedPaths: selectedPaths,
            ),
          );
        }
        if (nodes.isEmpty && _query.isNotEmpty) {
          return const Center(child: Text('没有匹配的文件夹'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: FolderListView(
            folders: nodes,
            fields: widget.viewSettings.fields,
            pinnedPaths: pinnedPaths,
            onFolderTap: _onFolderTap,
            onFolderLongPress: _onFolderLongPress,
            selectionMode: _selection.selecting,
            selectedPaths: selectedPaths,
          ),
        );
      },
    );
  }

  // ── 文件管理（复制/移动/重命名/删除/多选）与固定文件夹 ──────────────

  /// 点卡片：多选态 = 切换选中；否则按当前视图进入文件夹 / 播放视频
  Future<void> _onFolderTap(TreeNode node) async {
    if (_selection.selecting) {
      _selection.toggle(node.path);
      return;
    }
    if (widget.viewSettings.viewMode == ViewMode.tree) {
      await _openTreeFolder(node);
    } else {
      await _openFolder(node);
    }
  }

  Future<void> _onVideoTap(VideoFile video) async {
    if (_selection.selecting) {
      _selection.toggle(video.path);
      return;
    }
    await _openVideo(video);
  }

  /// 长按文件夹：弹出统一菜单（固定/复制/移动/重命名/删除 ── 多选）；
  /// 重命名/删除后该文件夹已不是原路径，首页列表会重扫，无需额外处理。
  ///
  /// 多选态下长按 = 「对整批操作」的快捷入口：长按的那张若还没选就先纳入选择
  /// （否则用户会对着一个空选择弹出菜单）。
  Future<void> _onFolderLongPress(TreeNode node) async {
    if (_selection.selecting) {
      await _openSelectionMenu(ensurePath: node.path);
      return;
    }
    await showFileManagementFlow(
      context,
      title: node.name,
      isDirectory: true,
      sourcePath: node.path,
      onMutated: _refreshAfterMutation,
      onMultiSelect: () => _selection.begin(node.path),
    );
  }

  /// 长按视频：与文件夹同一套菜单（视频没有「固定」项）
  Future<void> _onVideoLongPress(VideoFile video) async {
    if (_selection.selecting) {
      await _openSelectionMenu(ensurePath: video.path);
      return;
    }
    await showFileManagementFlow(
      context,
      title: video.name,
      isDirectory: false,
      sourcePath: video.path,
      onMutated: _refreshAfterMutation,
      onMultiSelect: () => _selection.begin(video.path),
    );
  }

  /// 选中项（按点选先后）；名称/类型从目录树反查，已被删除的路径自动丢弃
  List<FileSelectionItem> _selectedItems() =>
      pickSelection(_selection.paths, indexTreeSelection(_roots));

  /// 多选态呼出批量菜单（顶部工具栏的 ⋮ 与「多选态下长按卡片」共用）
  Future<void> _openSelectionMenu({String? ensurePath}) async {
    if (ensurePath != null && !_selection.isSelected(ensurePath)) {
      _selection.toggle(ensurePath);
    }
    if (_selection.isEmpty) return;
    final acted = await showBatchFileManagementFlow(
      context,
      items: _selectedItems(),
      onMutated: _refreshAfterMutation,
    );
    // 真的做了批量操作才退出多选（只是关掉菜单 / 取消弹窗 → 留在多选态）
    if (acted && mounted) _selection.exit();
  }

  /// 文件操作完成后的本地刷新：清缓存重扫 MediaStore + 重建目录树/文件夹列表，
  /// 并剔除已被删除的选中项（否则批量操作会打到死路径）
  Future<void> _refreshAfterMutation() async {
    await _load();
    if (!mounted) return;
    _selection.retainExisting(indexTreeSelection(_roots).keys);
  }

  /// 树状模式：进入目录浏览页（显示子文件夹 + 视频，可逐级下钻）
  Future<void> _openTreeFolder(TreeNode node) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreeFolderPage(
          node: node,
          viewSettings: widget.viewSettings,
          path: [node],
        ),
      ),
    );
    // 从目录页返回后刷新，进度条立即更新
    if (mounted) setState(() {});
  }

  Future<void> _openFolder(TreeNode node) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderDetailPage(
          title: node.name,
          folderPath: node.path,
          videos: node.children.map((c) => c.video!).toList(),
          viewSettings: widget.viewSettings,
        ),
      ),
    );
    // 从详情页返回后刷新，进度条立即更新
    if (mounted) setState(() {});
  }

  Future<void> _openVideo(VideoFile video) async {
    // 传首页一级界面的排序视频列表（树状模式根层视频），作为「下一集」的兄弟列表
    final roots = widget.viewSettings.sortTree(_roots);
    final playlist = [
      for (final c in roots)
        if (!c.isFolder) c.video!,
    ];
    await Navigator.of(context).push(
      playerPageRoute(PlayerPage(
        path: video.path,
        title: video.name,
        playlist: playlist,
      )),
    );
    // 返回后刷新，进度条立即更新
    if (mounted) setState(() {});
  }

  /// 打开媒体信息页（点击视频卡片最右侧的「i」）
  void _openMediaInfo(VideoFile video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaInfoPage(path: video.path, title: video.name),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
    IconData buttonIcon = Icons.refresh,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
