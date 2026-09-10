import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/media_info/media_info_page.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/services/file_selection_controller.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/video_scanner.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/file_ops.dart';
import 'package:moumou/utils/file_selection.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/file_selection_ui.dart';
import 'package:moumou/widgets/folder_actions.dart';
import 'package:moumou/widgets/options_sheet.dart';
import 'package:moumou/widgets/video_card.dart';

/// 文件夹视频列表页：列表模式下点击文件夹进入，只显示该文件夹内的视频。
/// 右上角从左到右：**搜索** → 排序与字段。
///
/// [folderPath] 为文件夹真实绝对路径：文件管理（长按视频的复制/移动/重命名/删除、
/// 多选批量操作）后据此**重新读取磁盘**，避免使用构造时传入的静态视频列表导致
/// 改名/删除后列表不刷新。[videos] 仅作为首帧的初始数据（可省，省略时立即读盘）。
///
/// 多选态下 AppBar 换成选择工具栏（见 `widgets/file_selection_ui.dart`）。
class FolderDetailPage extends StatefulWidget {
  final String title;
  final String? folderPath;
  final List<VideoFile> videos;
  final ViewSettings viewSettings;

  const FolderDetailPage({
    super.key,
    required this.title,
    required this.viewSettings,
    this.folderPath,
    this.videos = const [],
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  late List<VideoFile> _videos = widget.videos;

  /// 多选状态（页面级：退出本页即丢弃）
  final FileSelectionController _selection = FileSelectionController();

  @override
  void initState() {
    super.initState();
    if (widget.folderPath != null) _reloadVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  /// 重新读取该文件夹内的视频（文件管理后调用；MediaStore 缓存先清）
  Future<void> _reloadVideos() async {
    final path = widget.folderPath;
    if (path == null) return;
    VideoScanner.clearCache();
    final all = await VideoScanner.scanVideos();
    if (!mounted) return;
    setState(() {
      _videos = all.where((v) => FileOps.parentOf(v.path) == path).toList();
    });
  }

  /// 文件管理动作完成后的本地刷新：
  /// - **重命名/删除**当前文件夹 → 原路径已不存在，退出本页；
  /// - 否则重新读盘，列表即时更新，并剔除已被删除的选中项。
  Future<bool> _afterMutation() async {
    final path = widget.folderPath;
    if (path != null && !Directory(path).existsSync()) {
      if (mounted) Navigator.of(context).maybePop();
      return true;
    }
    await _reloadVideos();
    if (mounted) _selection.retainExisting(_videos.map((v) => v.path));
    return false;
  }

  void _showVideoOptions() {
    showSortOptionsSheet(
      context,
      widget.viewSettings,
      hasFolders: false,
      hasVideos: true,
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _openPlayer(VideoFile video) async {
    // 传当前可见的排序列表，作为播放页「下一集」的兄弟列表
    final playlist = widget.viewSettings.sortVideos(_videos);
    await Navigator.of(context).push(
      playerPageRoute(PlayerPage(
        path: video.path,
        title: video.name,
        playlist: playlist,
      )),
    );
    // 从播放页返回后主动刷新，进度条立即更新
    if (mounted) setState(() {});
  }

  void _openMediaInfo(VideoFile video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaInfoPage(path: video.path, title: video.name),
      ),
    );
  }

  /// 点卡片：多选态 = 切换选中；否则进入播放
  Future<void> _onVideoTap(VideoFile video) async {
    if (_selection.selecting) {
      _selection.toggle(video.path);
      return;
    }
    await _openPlayer(video);
  }

  /// 长按视频：多选态 = 对整批呼出菜单（长按项若未选先纳入选择）
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
      onMutated: _afterMutation,
      onMultiSelect: () => _selection.begin(video.path),
    );
  }

  /// 当前可见（已排序、已过滤）的视频；全选范围与渲染共用同一份真值
  List<VideoFile> _visibleVideos() {
    var videos = widget.viewSettings.sortVideos(_videos);
    if (_query.isNotEmpty) {
      videos = videos
          .where((v) => v.name.toLowerCase().contains(_query))
          .toList();
    }
    return videos;
  }

  /// 选中项（按点选先后）；已被删除的路径自动丢弃
  List<FileSelectionItem> _selectedItems() =>
      pickSelection(_selection.paths, indexVideoSelection(_videos));

  /// 多选态呼出批量菜单（顶部 ⋮ 与「多选态下长按卡片」共用）
  Future<void> _openSelectionMenu({String? ensurePath}) async {
    if (ensurePath != null && !_selection.isSelected(ensurePath)) {
      _selection.toggle(ensurePath);
    }
    if (_selection.isEmpty) return;
    final acted = await showBatchFileManagementFlow(
      context,
      items: _selectedItems(),
      onMutated: _afterMutation,
    );
    if (acted && mounted) _selection.exit();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索视频',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            )
          : Text(widget.title),
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
          tooltip: '排序与字段',
          onPressed: _showVideoOptions,
        ),
      ],
    );
  }

  /// 多选态顶部工具栏；全选范围 = 当前可见列表
  PreferredSizeWidget _buildSelectionAppBar() {
    final visible = _visibleVideos().map((v) => v.path).toList();
    final allSelected = _selection.containsAll(visible);
    return buildFileSelectionAppBar(
      count: _selection.count,
      allSelected: allSelected,
      onExit: _selection.exit,
      onToggleAll: () => _selection.setAll(visible, selected: !allSelected),
      onOpenMenu: () => _openSelectionMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => PopScope(
        // 多选态下系统返回键先退出多选，而不是退出本页
        canPop: !_selection.selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selection.exit();
        },
        child: Scaffold(
          appBar:
              _selection.selecting ? _buildSelectionAppBar() : _buildAppBar(),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_videos.isEmpty) {
      return const Center(child: Text('该文件夹没有视频'));
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.viewSettings,
        PlaybackProgressService.instance,
        PlayerControlsSettings.instance,
      ]),
      builder: (context, _) {
        final videos = _visibleVideos();
        if (videos.isEmpty && _query.isNotEmpty) {
          return const Center(child: Text('没有匹配的视频'));
        }
        final selectedPaths = _selection.paths.toSet();
        // 底部安全区已由全局 SafeArea 处理
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return VideoCard(
              video: video,
              fields: widget.viewSettings.videoFields,
              onTap: () => _onVideoTap(video),
              onInfoTap: () => _openMediaInfo(video),
              onLongPress: () => _onVideoLongPress(video),
              selectionMode: _selection.selecting,
              selected: selectedPaths.contains(video.path),
            );
          },
        );
      },
    );
  }
}
