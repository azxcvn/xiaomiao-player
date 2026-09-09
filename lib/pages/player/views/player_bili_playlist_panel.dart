import 'package:flutter/material.dart';
import 'package:moumou/models/bili_playlist.dart';

/// B 站番剧播放列表面板（通过 [showPlayerPanel] 右侧滑入 / 竖屏底部弹出，
/// 标题「播放列表」）。
///
/// 与本地播放列表（[PlayerPlaylistPanel]）的区别：
/// - 剧集**天然有序**（季内播出顺序），因此没有排序胶囊；
/// - 条目展示「集号 + 集名 + 角标（会员/限免/预告）」，当前集高亮「播放中」；
/// - 打开后自动滚动定位当前集（固定行高精确计算，同本地面板）。
///
/// ⚠️ 面板是独立弹窗路由，播放页 setState 不会重建它，滚动定位与高亮全部在
/// 本 State 内管理。
class PlayerBiliPlaylistPanel extends StatefulWidget {
  final BiliPlaylist playlist;

  /// 当前集下标（-1 = 未定位到，不滚动不高亮）
  final int currentIndex;

  /// 点击条目回调（播放页负责切集；当前集点击也会触发，调用方自行忽略）
  final ValueChanged<BiliPlaylistItem> onSelect;

  const PlayerBiliPlaylistPanel({
    super.key,
    required this.playlist,
    required this.currentIndex,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    final idx = widget.currentIndex;
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
    final items = widget.playlist.items;
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    '没有获取到剧集列表',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
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

  /// 头部：番剧名 + 「第 X 集 / 共 N 集」
  Widget _buildHeader() {
    final total = widget.playlist.length;
    final current = widget.currentIndex >= 0 ? widget.currentIndex + 1 : null;
    final title = widget.playlist.seasonTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
            current == null ? '共 $total 集' : '第 $current 集 / 共 $total 集',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 列表项：集号 + 集名 +（角标）+（当前集）主题色高亮与「播放中」徽标
  Widget _buildItem(BuildContext context, int index) {
    final item = widget.playlist.items[index];
    final isCurrent = index == widget.currentIndex;
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
                item.title,
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
              _buildBadge(item.badge),
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
                  '播放中',
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
  Widget _buildBadge(String badge) {
    final (Color color, String text) = switch (badge) {
      '会员' => (const Color(0xFFFB7299), 'VIP'),
      '限免' => (const Color(0xFF2E9E5B), '限免'),
      '预告' => (Colors.grey, '预告'),
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
