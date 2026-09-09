import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/pages/bilibili/bili_play_launcher.dart';
import 'package:moumou/widgets/bili_episode_tile.dart';

/// 全屏选集页：按 30 集一段分段（「1-30」「31-60」…）+ 2 列网格（集号 + 集名 +
/// 角标）+ 正序/倒序。切分段时按方向滑入/滑出（向前翻新页从右进、旧页左出，
/// 向后翻反之）。点击选集进入播放页（播放属阶段三）。
class BiliEpisodePickerPage extends StatefulWidget {
  final List<BiliEpisode> episodes;
  final bool initialReverse;

  const BiliEpisodePickerPage({
    super.key,
    required this.episodes,
    this.initialReverse = false,
  });

  @override
  State<BiliEpisodePickerPage> createState() => _BiliEpisodePickerPageState();
}

class _BiliEpisodePickerPageState extends State<BiliEpisodePickerPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 30;

  late bool _reverse = widget.initialReverse;
  int _page = 0;

  /// 动画期间的上一分段页（与新页一起滑出）。
  int _prevPage = 0;

  /// 翻页方向：1 = 向后翻（页号增大），-1 = 向前翻（页号减小）。
  int _pageDirection = 1;

  late final AnimationController _slideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    // 初始即处于「动画已完成」状态，第一页正常居中显示；切页时才 forward(0) 重播。
    value: 1.0,
  );

  List<BiliEpisode> get _ordered =>
      _reverse ? widget.episodes.reversed.toList() : widget.episodes;

  int get _pageCount => (_ordered.length / _pageSize).ceil();

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _toggleReverse() {
    setState(() {
      _reverse = !_reverse;
      _page = 0;
      _prevPage = 0;
      _pageDirection = 1;
    });
  }

  /// 切到指定分段页（记录方向并触发滑入/滑出动画）。
  void _goToPage(int i) {
    if (i == _page) return;
    setState(() {
      _prevPage = _page;
      _pageDirection = i > _page ? 1 : -1;
      _page = i;
    });
    _slideController.forward(from: 0);
  }

  /// 播放单集：把本页持有的整季剧集列表一并交给播放页（「下一集」用）
  void _playEpisode(BiliEpisode ep) => playBiliEpisode(
        context,
        ep,
        playlist: BiliPlaylist.fromEpisodes(widget.episodes),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选集'),
        actions: [
          TextButton.icon(
            onPressed: _toggleReverse,
            icon: Icon(_reverse ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
            label: Text(_reverse ? '正序' : '倒序'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pageCount > 1) _buildPageSelector(),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildPageSelector() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _pageCount,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final start = i * _pageSize + 1;
          final end = math.min((i + 1) * _pageSize, _ordered.length);
          final selected = _page == i;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _goToPage(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$start-$end',
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_slideController.value);
        // 新页从翻页方向一侧滑入（t 0→1：dir → 0），旧页滑向反方向（0 → -dir）。
        final newTranslation = Offset((1 - t) * _pageDirection, 0);
        final oldTranslation = Offset(-t * _pageDirection, 0);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_slideController.isAnimating)
              FractionalTranslation(
                translation: oldTranslation,
                child: _buildPageGrid(_prevPage),
              ),
            FractionalTranslation(
              translation: newTranslation,
              child: _buildPageGrid(_page),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageGrid(int page) {
    final items = _ordered.skip(page * _pageSize).take(_pageSize).toList();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 60,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => BiliEpisodeTile(
        episode: items[i],
        onTap: () => _playEpisode(items[i]),
      ),
    );
  }
}
