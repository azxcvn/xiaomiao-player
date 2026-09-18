/// 网络弹幕搜索面板（工作.md 第 4 点，弹幕「三级界面」）：
/// 顶部搜索框键入关键词 → 弹弹Play 开放弹幕网络搜索番剧 → 结果卡列表 →
/// 点某条结果进入集数二级界面（[PlayerDanmakuEpisodesPanel]）选集装载。
///
/// **搜索结果存在 [DanmakuSearchStore]，不在本面板 State 里**：
/// 外壳只构建页面栈栈顶那一页，点结果进二级界面会把本面板卸载——状态放这里
/// 就会"返回后结果全没了、还得重搜一次"（用户实测反馈），重复请求还容易触发
/// 弹弹Play 风控。搬进会话对象后：面板内前进/后退、乃至"选完一集自动关闭后
/// 再打开面板"，关键词、结果、滚动位置都还在；只有用户主动关面板才清空
/// （见 [DanmakuSearchStore.beginPanelSession]）。
///
/// **本轮重设计——逐台实时呈现（问题 1、2）**：
/// 1. **搜索结果不再等齐再合并**：`DanmakuNetworkService.searchStream` 每台
///    服务器返回就产出一条事件，面板立刻把结果挂上去——先返回的服务器一眼
///    可见，不必等最慢的那台（启用多服务器时旧行为是"转圈转很久、什么都看
///    不到，也不知道是在搜、没搜到、还是卡了"）。同一部番剧若后来的服务器
///    集数更多，就地覆盖那张卡，不会因为"谁快谁赢"丢掉更全的源；
/// 2. **搜索中显示转圈 + 停止**：转圈表示"还在向后面的服务器搜"，右侧「停止」
///    随时可中断（取消订阅即终止，后续服务器不再发起），已经搜出来的结果留在
///    列表里可以直接点；搜索中不折叠搜索框（停止按钮必须可见）；
/// 3. **结果计数条**：搜索中 / 已停止时在列表上方显示「已获得 N 部」，让用户
///    看到进度而不是面对一个空转的圈；
/// 4. **标题完整换行**：番剧名不再截断 + 「查看完整名称」弹窗，一行装不下就
///    换行、卡片跟着长高（问题 2 第一点）；
/// 5. **点结果 → 集数二级界面**：面板内不再就地展开集列表——一级界面里既
///    要滑动又要输跳转集数非常局促（问题 3），改由播放页 push
///    [PlayerDanmakuEpisodesPanel]，那里有整屏高度做定位与跳转。
///
/// 搜索框沿用上一轮两点：紧凑胶囊（40dp 定高）+ 关键词历史胶囊直接贴在下方；
/// 命中且有结果时折叠成「关键词 · N 部」条，把高度让给结果区。
///
/// 横屏在 [showPlayerPanel] 右侧外壳、竖屏在 [showPlayerBottomPanel] 底部
/// 外壳共用本内容（§4.5 约定）；点结果经 [onResultTap] 交由播放页 push 二级
/// 界面，选集中后由播放页拉取装载并关闭整个面板。
library;

import 'package:flutter/material.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_history.dart';
import 'package:moumou/services/danmaku_search_store.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 面板内统一强调色（**跟随主题**，对齐弹幕设置面板的派生方式）：
/// 由当前 `ColorScheme.primary` 派生暗色方案取 primary，见 [playerPanelAccent]。
Color _accentOf(BuildContext context) => playerPanelAccent(context);

/// 搜索框展开/折叠动画时长
const Duration _searchBarDuration = Duration(milliseconds: 260);

class PlayerDanmakuNetworkPanel extends StatefulWidget {
  /// 搜索会话（测试可注入）；默认用应用级单例，结果跨面板存活。
  /// 注入的那个由调用方负责释放（面板只监听，不 dispose）。
  final DanmakuSearchStore? store;

  /// 点某条搜索结果（播放页负责 push 集数二级界面，见
  /// [PlayerDanmakuEpisodesPanel]）；面板自己不做导航，避免依赖外壳类型。
  final void Function(DanmakuSearchItem item) onResultTap;

  const PlayerDanmakuNetworkPanel({
    super.key,
    this.store,
    required this.onResultTap,
  });

  @override
  State<PlayerDanmakuNetworkPanel> createState() =>
      _PlayerDanmakuNetworkPanelState();
}

class _PlayerDanmakuNetworkPanelState extends State<PlayerDanmakuNetworkPanel> {
  late final DanmakuSearchStore _store;
  final DanmakuSearchHistory _history = DanmakuSearchHistory();
  final TextEditingController _searchController = TextEditingController();

  /// 结果列表滚动控制器：**关掉 PageStorage 的自动记忆**，滚动位置只由
  /// [DanmakuSearchStore.listOffset] 说了算（否则新关键词的结果会"继承"上一轮
  /// 滚动位置）
  final ScrollController _resultsScroll = ScrollController(
    keepScrollOffset: false,
  );

  List<String> _historyItems = const [];

  /// 搜索框是否展开：搜到结果后自动折叠，让结果区拿到全部高度
  bool _searchOpen = true;

  /// 上一帧是否在搜索（用来抓"搜索结束"这一下降沿 → 折叠搜索框）
  bool _wasSearching = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? DanmakuSearchStore.instance;
    _store.addListener(_onStoreChanged);
    // 还原上次的关键词与滚动位置（结果本身在 store 里，见类注释）
    _searchController.text = _store.keyword;
    _searchOpen = _store.results.isEmpty || _store.searching;
    _wasSearching = _store.searching;
    _resultsScroll.addListener(() => _store.listOffset = _resultsScroll.offset);
    if (_store.listOffset > 0 && _store.results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    }
    _reloadHistory();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchController.dispose();
    _resultsScroll.dispose();
    super.dispose();
  }

  void _restoreOffset() {
    if (!mounted || !_resultsScroll.hasClients) return;
    final max = _resultsScroll.position.maxScrollExtent;
    _resultsScroll.jumpTo(_store.listOffset.clamp(0.0, max));
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      final searching = _store.searching;
      // 抓"搜索结束"下降沿：全部返回/用户停止且有结果 → 折叠搜索框
      if (_wasSearching && !searching && _store.results.isNotEmpty) {
        _searchOpen = false;
      }
      _wasSearching = searching;
    });
  }

  Future<void> _reloadHistory() async {
    try {
      final items = await _history.load();
      if (mounted) setState(() => _historyItems = items);
    } catch (_) {
      // 历史读取失败不阻断搜索（视为无历史）
    }
  }

  /// 发起搜索：历史记一笔，其余全交给 [DanmakuSearchStore]。
  Future<void> _doSearch(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    // 搜索中必须展开：转圈与「停止」都在搜索框右侧（问题 2）
    setState(() => _searchOpen = true);
    await _history.add(trimmed);
    if (!mounted) return;
    await _store.search(trimmed);
    // 搜索后刷新历史（新关键词插到最前）
    await _reloadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索区：展开态（搜索框 + 历史胶囊）↔ 折叠态（关键词胶囊条）
        // 高度差用 AnimatedSize 平滑过渡，内容用 AnimatedSwitcher 交叉淡入
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: AnimatedSize(
            duration: _searchBarDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: _searchBarDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              ),
              child: KeyedSubtree(
                key: ValueKey(_isSearchCollapsed),
                child: _isSearchCollapsed
                    ? _buildCollapsedSearchBar()
                    : _buildSearchArea(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildBody()),
      ],
    );
  }

  /// 折叠条只在「有结果、用户未主动展开、且当前没在搜索」时出现
  /// （搜索中要露出转圈与「停止」）
  bool get _isSearchCollapsed =>
      !_searchOpen && _store.results.isNotEmpty && !_store.searching;

  // ── 搜索区 ──────────────────────────────────────────────────

  /// 展开态：紧凑胶囊搜索框 + 紧随其下的关键词历史胶囊
  Widget _buildSearchArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        if (_historyItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildHistoryCapsules(),
          ),
      ],
    );
  }

  /// 紧凑胶囊搜索框：40dp 定高、`InputDecoration.collapsed`，
  /// 右侧为 28dp 迷你按钮（清空 / 搜索 / 停止），不被 `IconButton` 撑高。
  ///
  /// 搜索中右侧换成「转圈 + 停止」：此时唯一有意义的动作就是停止（问题 2），
  /// 搜索箭头隐藏以免误触重搜；键盘搜索键与历史胶囊仍可发起新搜索。
  Widget _buildSearchField() {
    final searching = _store.searching;
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 17, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _doSearch,
              // 清空按钮随输入显隐
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.25,
              ),
              cursorColor: _accentOf(context),
              cursorHeight: 16,
              decoration: const InputDecoration.collapsed(
                hintText: '输入番剧名称',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          ),
          if (searching) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accentOf(context),
                ),
              ),
            ),
            _MiniIconButton(
              icon: Icons.stop_rounded,
              tooltip: '停止搜索',
              color: Colors.white70,
              onTap: _store.stop,
            ),
          ] else ...[
            if (_searchController.text.isNotEmpty)
              _MiniIconButton(
                icon: Icons.close_rounded,
                tooltip: '清空',
                color: Colors.white54,
                onTap: () => setState(_searchController.clear),
              ),
            _MiniIconButton(
              icon: Icons.arrow_forward_rounded,
              tooltip: '搜索',
              color: _accentOf(context),
              onTap: () => _doSearch(_searchController.text),
            ),
          ],
        ],
      ),
    );
  }

  /// 关键词历史：胶囊 Wrap 直接贴在搜索框下方，末尾跟一枚「清除」胶囊
  Widget _buildHistoryCapsules() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final keyword in _historyItems)
          _HistoryCapsule(
            keyword: keyword,
            onTap: () {
              _searchController.text = keyword;
              _doSearch(keyword);
            },
          ),
        _HistoryCapsule(
          keyword: '清除',
          icon: Icons.delete_outline,
          dimmed: true,
          onTap: () async {
            await _history.clear();
            await _reloadHistory();
          },
        ),
      ],
    );
  }

  /// 折叠态：34dp 关键词胶囊条（点击回到搜索框），把高度让给结果区
  Widget _buildCollapsedSearchBar() {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _searchOpen = true),
        child: Container(
          height: 34,
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(
            children: [
              Icon(Icons.search, size: 15, color: _accentOf(context)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  _store.keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_store.results.length} 部',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more, size: 17, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  // ── 结果区 ──────────────────────────────────────────────────

  /// 列表上方的状态条文案（搜索进度 / 停止 / 部分失败）；无需展示时为 null。
  ///
  /// 「已获得 N 部」是问题 1 里"用户不知道在搜、没搜到还是卡了"的直接解法：
  /// 数字在涨 = 在搜；转圈消失 + 数字不动 = 搜完了。
  String? get _statusText {
    final results = _store.results;
    if (_store.searching) return '正在搜索 · 已获得 ${results.length} 部';
    if (_store.stopped) return '已停止搜索 · 共 ${results.length} 部';
    if (results.isNotEmpty && _store.serverErrors.isNotEmpty) {
      return '部分服务器搜索失败：${_store.serverErrors.join('；')}';
    }
    return null;
  }

  Widget _buildBody() {
    final results = _store.results;
    final error = _store.error;
    // 还没拿到任何结果：整屏转圈（有结果后就让位给列表，转圈留在搜索框里）
    if (_store.searching && results.isEmpty) return _buildLoading();
    // 停在空态：没搜过，或搜完确实没命中（用户手动停止不算——那种情况
    // 要显示「已停止搜索 · 共 0 部」让他知道是自己停的）
    if (results.isEmpty && error == null && !_store.stopped) {
      return _buildEmpty();
    }
    final status = _statusText;
    return ListView(
      // 关键词做 key：换关键词 = 全新列表，从顶部开始（不继承上一轮滚动位置）
      key: ValueKey(_store.keyword),
      controller: _resultsScroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        if (status != null) ...[
          _buildStatusStrip(status),
          const SizedBox(height: 8),
        ],
        if (error != null) ...[
          _buildErrorBanner(error),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _AnimeResultCard(
            item: results[i],
            onTap: () => widget.onResultTap(results[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusStrip(String message) {
    final searching = _store.searching;
    return Row(
      children: [
        Icon(
          searching
              ? Icons.sync
              : (_store.stopped ? Icons.stop_circle_outlined
                    : Icons.error_outline),
          size: 13,
          color: Colors.white38,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _accentOf(context),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '搜索中…',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search, size: 40, color: Colors.white24),
          SizedBox(height: 10),
          Text(
            '输入关键词搜索网络弹幕',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 面板内公共小组件（设计规范对齐弹幕设置面板）────────────────────

/// 搜索框内的迷你圆形按钮（28dp，替代默认 48dp 的 [IconButton]）
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: Icon(icon, size: 18, color: color)),
        ),
      ),
    );
  }
}

/// 小标签胶囊（类型 / 集数 / 来源服务器）。
class _CapsuleLabel extends StatelessWidget {
  final String text;
  const _CapsuleLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      ),
    );
  }
}

/// 关键词历史胶囊（[icon] + [dimmed] 复用为末尾的「清除」胶囊）。
class _HistoryCapsule extends StatelessWidget {
  final String keyword;
  final IconData? icon;
  final bool dimmed;
  final VoidCallback onTap;

  const _HistoryCapsule({
    required this.keyword,
    required this.onTap,
    this.icon,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dimmed ? Colors.white38 : Colors.white70;
    return Material(
      color: Colors.white.withValues(alpha: dimmed ? 0.04 : 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: icon == null ? 14 : 10,
            right: 14,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(keyword, style: TextStyle(color: fg, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索结果卡片：番剧名 + 胶囊小标签（类型 / 集数 / 来源服务器），点进集数二级界面。
///
/// 番剧名**不截断**：一行装不下就换行、卡片跟着长高（问题 2 第一点）——
/// 旧实现截断 + 「查看完整名称」按钮 + 弹窗，既看不全又要多点一次。
class _AnimeResultCard extends StatelessWidget {
  final DanmakuSearchItem item;
  final VoidCallback onTap;

  const _AnimeResultCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final anime = item.anime;
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.animeTitle,
                      // 不设 maxLines / ellipsis：完整换行展示
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (anime.typeDescription.isNotEmpty)
                          _CapsuleLabel(anime.typeDescription),
                        _CapsuleLabel('${anime.episodes.length} 集'),
                        // **每个**结果都标来源服务器名，用户点选集前就能
                        // 判断这条来自哪里（issue #1 需求 4）。
                        _CapsuleLabel(item.serverName),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 箭头表示"点进去还有一级"（集数界面）
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
