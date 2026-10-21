import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/playlist_sort.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/player_option_chip.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 播放列表面板内容（横屏经 [showPlayerPanel] 右侧滑入、竖屏经
/// [showPlayerBottomPanel] 底部弹出）。
///
/// - 顶部排序区三枚胶囊：左「排序方式」（名称/日期/大小/时长，点开小菜单）、
///   中「排序方向」（升序/降序，点开小菜单）、右固定「跟随主界面」
///   （选中时顺序 = 视频页主界面的顺序，字段/方向两枚胶囊显示主界面的值）；
/// - 排序只改**实际播放列表**：回调 [onChoiceChanged]，由播放页重排
///   「下一集 / 自动连播 / 列表循环」用的那份列表；面板本身只读
///   [playlistListenable]（播放页维护的唯一顺序），不自己存一份顺序，
///   显示与播放永远一致；
/// - 排序只在本次播放内有效（由播放页持有，退出播放页即失效）；
/// - 列表项 = 序号 + 文件名，当前播放项主题色高亮 + 「播放中」徽标；
/// - 排序切换后自动滚动定位到当前项（固定行高 52，滚动偏移精确计算）；
/// - 点击列表项 → [onSelect] 回调并关闭面板。
///
/// ⚠️ 面板是独立弹窗路由，播放页 setState 不会重建它：排序状态、滚动定位
/// 在本 State 内部管理；列表顺序始终来自 [playlistListenable]。
class PlayerPlaylistPanel extends StatefulWidget {
  /// 播放页维护的播放列表（顺序 = 实际播放顺序，竖屏页读同一份）
  final ValueListenable<List<VideoFile>> playlistListenable;

  /// 只列出该目录的视频（打开面板时由播放页确定）
  final String folder;

  /// 当前播放视频路径（高亮与滚动定位依据）
  final String currentPath;

  /// 主界面（视频页）当前的排序字段/方向：「跟随主界面」时两枚胶囊显示它
  final VideoSortChoice mainSort;

  /// 打开面板时的排序状态（null = 跟随主界面）
  final VideoSortChoice? initialChoice;

  /// 切换排序：null = 跟随主界面；非空 = 自定义字段 + 方向。
  /// 调用方据此重排实际播放列表（必须实现，否则排序只改显示不改播放）。
  final ValueChanged<VideoSortChoice?> onChoiceChanged;

  /// 点击列表项回调（由播放页执行切集；当前项点击也会触发，调用方自行忽略）
  final ValueChanged<VideoFile> onSelect;

  const PlayerPlaylistPanel({
    super.key,
    required this.playlistListenable,
    required this.folder,
    required this.currentPath,
    required this.mainSort,
    required this.initialChoice,
    required this.onChoiceChanged,
    required this.onSelect,
  });

  @override
  State<PlayerPlaylistPanel> createState() => _PlayerPlaylistPanelState();
}

class _PlayerPlaylistPanelState extends State<PlayerPlaylistPanel> {
  /// 固定行高：滚动定位按 `索引 × 行高` 精确计算
  static const double _itemExtent = 52;

  /// 当前排序选择（null = 跟随主界面）
  VideoSortChoice? _choice;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _choice = widget.initialChoice;
    // 打开后先滚动到当前项（等首帧布局完成）
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 生效的排序字段/方向：自定义优先，否则显示主界面的值（跟随时两枚胶囊
  /// 展示的就是实际顺序的来源，不误导）
  VideoSortField get _field => _choice?.field ?? widget.mainSort.field;
  SortOrder get _order => _choice?.order ?? widget.mainSort.order;

  void _setChoice(VideoSortChoice? next) {
    // 选中的字段+方向恰好等于主界面排序 → 留在「跟随主界面」（顺序完全一样）
    final choice = next == widget.mainSort ? null : next;
    if (choice == _choice) return;
    setState(() => _choice = choice);
    // 先让播放页重排实际播放列表，面板随后从同一份列表重建
    widget.onChoiceChanged(choice);
    _scrollToCurrent();
  }

  Future<void> _pickField(BuildContext anchorContext) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _showMenu<VideoSortField>(
      anchorContext,
      values: VideoSortField.values,
      labelOf: (f) => videoSortFieldLabel(l10n, f),
      selected: _field,
    );
    if (picked == null || !mounted) return;
    // 保留当前方向，只换字段
    _setChoice((field: picked, order: _order));
  }

  Future<void> _pickOrder(BuildContext anchorContext) async {
    final l10n = AppLocalizations.of(context);
    final picked = await _showMenu<SortOrder>(
      anchorContext,
      values: SortOrder.values,
      labelOf: (o) => sortOrderLabel(l10n, o),
      selected: _order,
    );
    if (picked == null || !mounted) return;
    // 保留当前字段，只换方向
    _setChoice((field: _field, order: picked));
  }

  /// 在胶囊下方弹出小菜单（暗底白字，与播放器面板同色系；当前项打勾）
  Future<T?> _showMenu<T>(
    BuildContext anchorContext, {
    required List<T> values,
    required String Function(T) labelOf,
    required T selected,
  }) async {
    final box = anchorContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight =
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
    final checkColor = playerPanelScheme(anchorContext).primary;
    return showMenu<T>(
      context: anchorContext,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF232326),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        for (final value in values)
          PopupMenuItem<T>(
            value: value,
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelOf(value),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                if (value == selected)
                  Icon(Icons.check, size: 18, color: checkColor),
              ],
            ),
          ),
      ],
    );
  }

  /// 滚动定位到当前项（固定行高：目标偏移 = 索引 × 行高，钳制到可视范围）
  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final videos = filterVideosInFolder(
        widget.playlistListenable.value,
        widget.folder,
      );
      final idx = videos.indexWhere((v) => v.path == widget.currentPath);
      if (idx < 0) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = (idx * _itemExtent).clamp(0.0, max);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleSelect(VideoFile video) {
    widget.onSelect(video);
    // 点击后关闭面板（src 同款：延迟切换后关闭抽屉）
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<List<VideoFile>>(
      valueListenable: widget.playlistListenable,
      builder: (context, playlist, _) {
        final videos = filterVideosInFolder(playlist, widget.folder);
        return Column(
          children: [
            _buildSortRow(context, l10n),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: videos.isEmpty
                  ? Center(
                      child: Text(
                        l10n.playerNoOtherVideos,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemExtent: _itemExtent,
                      itemCount: videos.length,
                      itemBuilder: (context, index) =>
                          _buildItem(context, videos, index),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 顶部排序区：排序方式 + 排序方向（点开小菜单）+ 右侧固定「跟随主界面」。
  ///
  /// 三枚胶囊等宽：跟随态高亮右侧、自定义态高亮左侧两枚，一眼看出当前模式。
  Widget _buildSortRow(BuildContext context, AppLocalizations l10n) {
    final following = _choice == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (chipContext) => _SortMenuChip(
                key: const Key('playlist-sort-field'),
                label: videoSortFieldLabel(l10n, _field),
                highlighted: !following,
                onTap: () => _pickField(chipContext),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (chipContext) => _SortMenuChip(
                key: const Key('playlist-sort-order'),
                label: sortOrderLabel(l10n, _order),
                highlighted: !following,
                onTap: () => _pickOrder(chipContext),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: PlayerOptionChip(
              key: const Key('playlist-sort-follow'),
              label: l10n.playerPlaylistFollowMain,
              selected: following,
              textAlign: TextAlign.center,
              maxLines: 1,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              onTap: () => _setChoice(null),
            ),
          ),
        ],
      ),
    );
  }

  /// 列表项：序号 + 文件名 +（当前项）主题色高亮与「播放中」徽标
  Widget _buildItem(
    BuildContext context,
    List<VideoFile> videos,
    int index,
  ) {
    final l10n = AppLocalizations.of(context);
    final video = videos[index];
    final isCurrent = video.path == widget.currentPath;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _handleSelect(video),
      child: Container(
        height: _itemExtent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? scheme.primary : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                video.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? scheme.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.commonPlaying,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 排序下拉胶囊：文案 + 下拉箭头，选中态用主题色（面板同款暗底配色）。
///
/// 与 [PlayerOptionChip] 的视觉一致（同圆角/同内边距体系），只是多一个箭头
/// 提示「点开有菜单」。
class _SortMenuChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _SortMenuChip({
    super.key,
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = playerPanelScheme(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: highlighted ? scheme.onPrimary : Colors.white,
                  fontSize: 13,
                  fontWeight:
                      highlighted ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: highlighted ? scheme.onPrimary : Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}
