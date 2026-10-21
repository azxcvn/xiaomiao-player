import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/widgets/player_option_chip.dart';

/// B 站番剧播放列表面板（通过 [showPlayerPanel] 右侧滑入 / 竖屏底部弹出，
/// 标题「播放列表」）。
///
/// 与本地播放列表（[PlayerPlaylistPanel]）的区别：
/// - 顶部三枚排序胶囊：名称升序 / 名称降序 / 番剧顺序（最右，默认选中）；
///   换排序回调 [onSortChanged]，播放页据此重排「下一集 / 自动连播 /
///   列表循环」用的剧集顺序——面板显示与实际播放顺序始终一致；
/// - 排序只在本次播放内有效（状态由播放页持有）；
/// - 条目展示「集号 + 集名 + 角标（会员/限免/预告）」，当前集高亮「播放中」；
/// - 打开后自动滚动定位当前集（固定行高精确计算，同本地面板）。
///
/// ⚠️ 面板是独立弹窗路由，播放页 setState 不会重建它，滚动定位与高亮全部在
/// 本 State 内管理；排序状态在打开时取 [sort]，之后由本页维护并回报。
class PlayerBiliPlaylistPanel extends StatefulWidget {
  final BiliPlaylist playlist;

  /// 当前集 epId（null / ≤0 = 未定位到，不滚动不高亮）
  final int? currentEpId;

  /// 打开面板时的排序方式（播放页当前生效的那份）
  final BiliPlaylistSort sort;

  /// 换排序回调（播放页据此重排实际播放顺序）
  final ValueChanged<BiliPlaylistSort> onSortChanged;

  /// 点击条目回调（播放页负责切集；当前集点击也会触发，调用方自行忽略）
  final ValueChanged<BiliPlaylistItem> onSelect;

  const PlayerBiliPlaylistPanel({
    super.key,
    required this.playlist,
    required this.currentEpId,
    required this.sort,
    required this.onSortChanged,
    required this.onSelect,
  });

  @override
  State<PlayerBiliPlaylistPanel> createState() =>
      _PlayerBiliPlaylistPanelState();
}

class _PlayerBiliPlaylistPanelState extends State<PlayerBiliPlaylistPanel> {
  /// 固定行高：滚动定位按 `索引 × 行高` 精确计算
  static const double _itemExtent = 52;

  final ScrollController _scrollController = ScrollController();

  late BiliPlaylistSort _sort;
  late List<BiliPlaylistItem> _items;

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
    _items = sortBiliPlaylistItems(widget.playlist.items, _sort);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setSort(BiliPlaylistSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _items = sortBiliPlaylistItems(widget.playlist.items, sort);
    });
    // 先让播放页重排实际播放顺序，再滚动定位当前集
    widget.onSortChanged(sort);
    _scrollToCurrent();
  }

  /// 当前集在（排序后）列表里的下标（-1 = 未定位）
  int get _currentPosition {
    final epId = widget.currentEpId;
    if (epId == null || epId <= 0) return -1;
    return _items.indexWhere((item) => item.epId == epId);
  }

  BiliPlaylistItem? get _currentItem {
    final pos = _currentPosition;
    return pos >= 0 ? _items[pos] : null;
  }

  void _scrollToCurrent() {
    final idx = _currentPosition;
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final target = (idx * _itemExtent).clamp(0.0, max);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleSelect(BiliPlaylistItem item) {
    widget.onSelect(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    return Column(
      children: [
        _buildSortRow(l10n),
        _buildHeader(l10n),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    l10n.playerBiliNoEpisodes,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemExtent: _itemExtent,
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildItem(context, index),
                ),
        ),
      ],
    );
  }

  /// 顶部排序区：名称升序 / 名称降序 / 番剧顺序（最右，默认）。
  ///
  /// 三枚等宽胶囊；选中态由本页维护，换排序时回调播放页重排实际播放顺序。
  Widget _buildSortRow(AppLocalizations l10n) {
    PlayerOptionChip chip(String label, BiliPlaylistSort sort) =>
        PlayerOptionChip(
          label: label,
          selected: _sort == sort,
          textAlign: TextAlign.center,
          maxLines: 1,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          onTap: () => _setSort(sort),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: chip(l10n.playlistSortNameAsc, BiliPlaylistSort.nameAsc),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: chip(l10n.playlistSortNameDesc, BiliPlaylistSort.nameDesc),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: chip(l10n.playerBiliSeasonOrder, BiliPlaylistSort.season),
          ),
        ],
      ),
    );
  }

  /// 头部：番剧名 + 「第 X 集 / 共 N 集」。
  ///
  /// 当前集用**集号**（[BiliPlaylistItem.index]）而不是排序后的位置——
  /// 按名称降序时列表位置会反过来，集号始终是「这是第几集」。
  Widget _buildHeader(AppLocalizations l10n) {
    final total = widget.playlist.length;
    final current = _currentItem?.index;
    final title = widget.playlist.seasonTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          if (title.isNotEmpty)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          Text(
            current == null
                ? l10n.playerBiliTotalEpisodes(total)
                : l10n.playerBiliCurrentOfTotal(current, total),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 列表项：集号 + 集名 +（角标）+（当前集）主题色高亮与「播放中」徽标
  Widget _buildItem(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    final item = _items[index];
    final isCurrent = item.epId == widget.currentEpId;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _handleSelect(item),
      child: Container(
        height: _itemExtent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${item.index}',
                style: TextStyle(
                  color: isCurrent ? scheme.primary : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                biliPlaylistItemTitle(l10n, item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? scheme.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (item.badge.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildBadge(context, item.badge),
            ],
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

  /// 角标胶囊（与 [BiliEpisodeTile] 同色系，暗底上提高不透明度）
  Widget _buildBadge(BuildContext context, String badge) {
    final l10n = AppLocalizations.of(context);
    // switch 的匹配键是 B 站接口返回的角标原值（数据，不是 UI 文案），
    // 属不可翻译清单，保持中文；只把显示文案换成 l10n。
    final (Color color, String text) = switch (badge) {
      '会员' => (const Color(0xFFFB7299), 'VIP'),
      '限免' => (const Color(0xFF2E9E5B), l10n.playerBiliFreeLimited),
      '预告' => (Colors.grey, l10n.playerBiliPreview),
      _ => (Colors.grey, badge),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
