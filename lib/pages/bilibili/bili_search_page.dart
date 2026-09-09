import 'package:flutter/material.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/pages/bilibili/bili_season_page.dart';
import 'package:moumou/services/bilibili/bili_bangumi_service.dart';
import 'package:moumou/services/bilibili/bili_http.dart';
import 'package:moumou/services/common_list_controller.dart';
import 'package:moumou/utils/loading_state.dart';

/// 番剧搜索页：顶部搜索框 + 结果列表（media_bangumi 分类，分页加载），
/// 点击结果进入季详情页。
///
/// 列表状态走通用分页控制器 [CommonListController]（§4.29 C2）：三态 +
/// 「刷新失败保留旧列表」+ 加载更多语义统一，页面只负责渲染。
class BiliSearchPage extends StatefulWidget {
  const BiliSearchPage({super.key, this.service});

  /// 测试注入用（默认自建，走真实网络）
  final BiliBangumiService? service;

  @override
  State<BiliSearchPage> createState() => _BiliSearchPageState();
}

class _BiliSearchPageState extends State<BiliSearchPage> {
  static const int _pageSize = 20;

  late final BiliBangumiService _service = widget.service ?? BiliBangumiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// 分页控制器：fetchPage 读取当前关键词（换词时先 reset 再 refresh）
  late final CommonListController<BiliSearchItem> _results =
      CommonListController<BiliSearchItem>(
    fetchPage: (page) async {
      final result = await _service.searchBangumi(_keyword, page: page);
      return PageResult(
        result.list,
        hasMore: page * _pageSize < result.numResults,
      );
    },
    describeError: _errorText,
  );

  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.dispose();
    _results.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _results.loadMore();
    }
  }

  /// 新关键词搜索：清空旧结果后重新加载第一页
  Future<void> _search() async {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    _keyword = kw;
    _results.reset();
    await _results.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '搜索番剧',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      // 控制器是 ChangeNotifier：局部订阅，只重建列表区（§4.1）
      body: ListenableBuilder(
        listenable: _results,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_results.started) {
      return const Center(child: Text('输入关键词搜索番剧'));
    }
    return switch (_results.state) {
      Loaded<List<BiliSearchItem>>(:final data) => data.isEmpty
          ? const Center(child: Text('没有找到相关番剧'))
          : _resultList(data),
      LoadError<List<BiliSearchItem>>(:final message) => _errorView(message),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _errorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _resultList(List<BiliSearchItem> items) {
    final showFooter = _results.isLoadingMore;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: items.length + (showFooter ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _SearchItemCard(item: items[i]);
      },
    );
  }

  static String _errorText(Object e) =>
      e is BiliApiException ? e.message : e.toString();
}

/// 搜索结果条目：封面 + 标题 + 元信息。
class _SearchItemCard extends StatelessWidget {
  final BiliSearchItem item;
  const _SearchItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (item.indexShow.isNotEmpty) item.indexShow,
      if (item.areas.isNotEmpty) item.areas,
      if (item.styles.isNotEmpty) item.styles,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (item.seasonId <= 0) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BiliSeasonPage(seasonId: item.seasonId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _cover(context, item.cover),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (item.mediaScore > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: scheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          item.mediaScore.toStringAsFixed(1),
                          style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(BuildContext context, String cover) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 84,
        child: cover.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.live_tv_outlined, color: scheme.onSurfaceVariant, size: 26),
              )
            : Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant, size: 26),
                ),
              ),
      ),
    );
  }
}
