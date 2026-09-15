/// 网络弹幕搜索面板（工作.md 第 4 点，弹幕「三级界面」）：
/// 顶部搜索框键入关键词 → 通过弹弹Play 开放弹幕网络搜索番剧 → 结果卡片
/// 内联展开集列表（动画）→ 点选集下载并加载到当前视频。
///
/// **重设计（本轮）**——四点体验问题的解法：
/// 1. **紧凑胶囊搜索框**：自绘 40dp 高胶囊容器 + `InputDecoration.collapsed`
///    （不再用 `TextField` 默认 `OutlineInputBorder` + `IconButton` suffix，
///    那套 48dp 最小点击区把输入框顶到 60dp+）；
/// 2. **关键词历史直接挂在搜索框下方**：胶囊 `Wrap` + 末尾「清除」胶囊，
///    不再独占一张分组卡片、不再有分组标签；
/// 3. **搜索命中后自动折叠搜索框**：收成 34dp 的「关键词 · N 部」胶囊条
///    （点它重新展开搜索），结果区拿到全部剩余高度（竖屏底部外壳与其他
///    面板同高，结果区在面板内滚动）；
/// 4. **展开/收起动画重做**：每张结果卡自持 [AnimationController]
///    （进 320ms easeOutCubic / 退 250ms easeInCubic），高度 + 内容淡入淡出
///    错峰（收起时内容先淡出再收高），箭头旋转与高度同一条曲线；收起态
///    子树不构建（零布局开销），展开时把卡头 `ensureVisible` 顶到可视区。
///    集数多于 6 集时集列表落在定高滚动容器里，避免动画期间反复布局长列表。
/// 5. **搜索并发语义（P2-10）**：搜索中再搜不再被静默吞掉（键盘搜索键 /
///    历史胶囊 / 连按搜索都照常发起），并用会话号丢弃旧响应——
///    结果永远属于**最后一次**输入的关键词。
///
/// 横屏在 [showPlayerPanel] 右侧外壳、竖屏在 [showPlayerBottomPanel] 底部
/// 外壳共用本内容（§4.5 约定）；选集中后经 [onEpisodeSelected] 交由播放页
/// 拉取并装载，随后关闭整个面板。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_history.dart';
import 'package:moumou/utils/async_session.dart';
import 'package:moumou/utils/danmaku_episode.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 面板内统一强调色（**跟随主题**，对齐弹幕设置面板的派生方式）：
/// 由当前 `ColorScheme.primary` 派生暗色方案取 primary，见 [playerPanelAccent]。
Color _accentOf(BuildContext context) => playerPanelAccent(context);

/// 结果卡展开（进场）时长
const Duration _expandInDuration = Duration(milliseconds: 320);

/// 结果卡收起（退场）时长——略快于展开，手感更利落
const Duration _expandOutDuration = Duration(milliseconds: 250);

/// 搜索框展开/折叠动画时长
const Duration _searchBarDuration = Duration(milliseconds: 260);

/// 集列表超过该集数时改用定高滚动容器（动画期间不再布局长列表）
const int _episodeInlineLimit = 6;

/// 定高集列表的高度（约 6 行）
const double _episodeListHeight = 264;

class PlayerDanmakuNetworkPanel extends StatefulWidget {
  /// 网络服务（测试可注入）；默认新实例，搜索会合并所有已启用服务器结果
  final DanmakuNetworkService? networkService;

  /// 选中某集后的回调（播放页负责保存自动匹配缓存 + 拉取装载 + 提示）
  final void Function(
    DandanAnime anime,
    DandanEpisode episode,
    String? serverUrl,
  )
  onEpisodeSelected;

  /// 当前正在播放的视频文件名（含扩展名）。
  ///
  /// 用于展开番剧时**自动定位到对应集**：`extractEpisodeNumber` 解析出的集数
  /// 经 `findMatchingEpisode` 命中后滚动 + 高亮，省掉上百集手动翻找。
  /// 为空/解析不出时不做自动定位（用户仍可用「跳至第 N 集」）。
  final String? currentFileName;

  const PlayerDanmakuNetworkPanel({
    super.key,
    this.networkService,
    required this.onEpisodeSelected,
    this.currentFileName,
  });

  @override
  State<PlayerDanmakuNetworkPanel> createState() =>
      _PlayerDanmakuNetworkPanelState();
}

class _PlayerDanmakuNetworkPanelState extends State<PlayerDanmakuNetworkPanel> {
  late final DanmakuNetworkService _network;
  final DanmakuSearchHistory _history = DanmakuSearchHistory();
  final TextEditingController _searchController = TextEditingController();

  /// 搜索会话令牌（[AsyncSession]，§4.29）：后发起的搜索会作废在途的那次，
  /// 旧响应后到一律丢弃（P2-10：结果必须属于**最后一次**输入的关键词）。
  final AsyncSession _searchSession = AsyncSession();

  /// 本页是否自建网络服务（注入的不归本页释放，P2-11）
  late final bool _ownsNetwork;

  List<String> _historyItems = const [];
  List<DanmakuSearchItem> _results = const [];
  bool _loading = false;
  String? _error;

  /// 最近一次成功搜索的关键词（折叠条上展示）
  String _keyword = '';

  /// 搜索框是否展开：搜到结果后自动折叠，让结果区拿到全部高度（问题 3）
  bool _searchOpen = true;

  /// 当前展开的番剧（手风琴式，同时只展开一个）
  int? _expandedAnimeId;

  @override
  void initState() {
    super.initState();
    _network = widget.networkService ?? DanmakuNetworkService();
    _ownsNetwork = widget.networkService == null;
    _reloadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // P2-11：自建的服务持有 http.Client，页面关闭即释放（注入的由调用方管）
    if (_ownsNetwork) _network.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    try {
      final items = await _history.load();
      if (mounted) setState(() => _historyItems = items);
    } catch (_) {
      // 历史读取失败不阻断搜索（视为无历史）
    }
  }

  /// 发起搜索（P2-10）。
  ///
  /// - **搜索中不再吞掉新搜索**：旧实现 `if (trimmed.isEmpty || _loading) return;`
  ///   在 loading 期间静默忽略（键盘搜索键 / 历史胶囊 / 再按搜索都没反应），
  ///   用户以为「搜索坏了」；现在照常发起，用会话号保证**最后一次**输入生效。
  /// - 旧响应后到（弱网下常见）一律丢弃，不会覆盖新关键词的结果。
  Future<void> _doSearch(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final session = _searchSession.start();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
      _expandedAnimeId = null;
      _keyword = trimmed;
    });
    await _history.add(trimmed);
    final result = await _network.search(trimmed);
    if (!mounted || !_searchSession.isCurrent(session)) return;
    setState(() {
      _loading = false;
      _results = result.items;
      _error = result.items.isEmpty
          ? (result.errors.isEmpty
                ? '未找到相关番剧，请尝试其他关键词'
                : '搜索失败：${result.errors.join('；')}')
          : null;
      // 命中才折叠搜索框；无结果/出错保持展开，方便立刻改关键词
      _searchOpen = result.items.isEmpty;
    });
    // 搜索后刷新历史（新关键词插到最前）
    await _reloadHistory();
  }

  void _toggleCard(DanmakuSearchItem item) {
    setState(() {
      _expandedAnimeId = _expandedAnimeId == item.anime.animeId
          ? null
          : item.anime.animeId;
    });
  }

  void _selectEpisode(DanmakuSearchItem item, DandanEpisode episode) {
    widget.onEpisodeSelected(item.anime, episode, item.serverUrl);
    // 选集中后关闭整个弹幕面板（弹出外壳为 showGeneralDialog 路由）
    Navigator.of(context).pop();
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

  /// 折叠条只在「有结果且用户未主动展开」时出现
  bool get _isSearchCollapsed => !_searchOpen && _results.isNotEmpty;

  // ── 搜索区 ──────────────────────────────────────────────────

  /// 展开态：紧凑胶囊搜索框 + 紧随其下的关键词历史胶囊（问题 1、2）
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
  /// 右侧为 28dp 迷你按钮（清空 / 搜索），不再被 `IconButton` 撑高。
  Widget _buildSearchField() {
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
          // 搜索中转圈，但**搜索按钮始终在位**（P2-10）：不然用户在 loading
          // 期间连按搜索没有任何反应，而「再按一次」恰恰是弱网下最常见的操作。
          if (_loading)
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
          if (!_loading && _searchController.text.isNotEmpty)
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
                  _keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_results.length} 部',
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

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_results.isEmpty && _error == null) return _buildEmpty();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        if (_error != null) ...[
          _buildErrorBanner(_error!),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < _results.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _AnimeResultCard(
            key: ValueKey(_results[i].anime.animeId),
            item: _results[i],
            expanded: _expandedAnimeId == _results[i].anime.animeId,
            onToggle: () => _toggleCard(_results[i]),
            onEpisodeSelected: (ep) => _selectEpisode(_results[i], ep),
            currentFileName: widget.currentFileName,
          ),
        ],
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

Widget _panelDivider() => const Divider(
  height: 1,
  thickness: 0.5,
  indent: 16,
  endIndent: 16,
  color: Colors.white10,
);

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

/// 搜索结果卡片：标题 + 胶囊小标签 + 可展开/收起的集列表。
///
/// 展开/收起由卡片自持的 [AnimationController] 驱动（问题 4 重设计）：
/// - 高度用 `Align(heightFactor)`，曲线 进 easeOutCubic / 退 easeInCubic；
/// - 内容淡入淡出与高度**错峰**（展开先长高再显形、收起先淡出再收高），
///   避免旧实现「内容边被裁边挤压」的生硬观感；
/// - 箭头旋转共用同一条曲线，与高度严格同步；
/// - 完全收起时子树不构建（`SizedBox.shrink`），长番剧不留布局开销。
class _AnimeResultCard extends StatefulWidget {
  final DanmakuSearchItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<DandanEpisode> onEpisodeSelected;

  /// 当前播放的视频文件名（用于展开时自动定位到对应集；见面板参数说明）
  final String? currentFileName;

  const _AnimeResultCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
    required this.onEpisodeSelected,
    this.currentFileName,
  });

  @override
  State<_AnimeResultCard> createState() => _AnimeResultCardState();
}

class _AnimeResultCardState extends State<_AnimeResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _expandInDuration,
    reverseDuration: _expandOutDuration,
    value: widget.expanded ? 1 : 0,
  );

  /// 高度因子（展开 easeOutCubic / 收起 easeInCubic）
  late final Animation<double> _height = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// 内容不透明度：展开后 30% 才开始显形；收起时前 45% 就已淡完（错峰）
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.30, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.55, 1, curve: Curves.easeIn),
  );

  /// 卡头 key：展开时把卡头顶到可视区（长列表展开不再「跑到屏幕外」）
  final GlobalKey _headerKey = GlobalKey();

  /// 集列表滚动控制器（超过 [_episodeInlineLimit] 集时才挂到 ListView 上）
  final ScrollController _episodeScroll = ScrollController();

  /// 「跳至第 N 集」输入框（集数多时按集号直达）
  final TextEditingController _jumpController = TextEditingController();

  /// 高亮中的集下标（自动定位/跳转命中后短暂高亮，便于确认落点）
  int? _highlightIndex;

  Timer? _highlightTimer;

  /// 自动定位失败的一次性提示（在集列表上方内联显示，不弹对话框）
  String? _locateHint;

  /// 集列表行高（滚动定位用）：`padding 11*2 + 单行文本 ≈ 40`
  static const double _episodeRowExtent = 40;

  /// 展开时若尚未定位，按当前视频文件名自动定位到对应集。
  ///
  /// 解析/匹配都复用已有纯函数（`extractEpisodeNumber` /
  /// `findMatchingEpisode`）——它们在「切集自动匹配」里已经过真机验证。
  void _locateCurrentEpisodeOnce() {
    if (_locateHint != null || _highlightIndex != null) return;
    final loc = locateCurrentEpisode(
      widget.currentFileName,
      widget.item.anime.episodes,
    );
    if (loc.index < 0) {
      _locateHint = loc.message;
      return;
    }
    _highlightIndex = loc.index;
    _scrollToEpisode(loc.index);
    _scheduleHighlightClear();
  }

  /// 滚动到第 [index] 集（仅长列表需要；短列表内联展示、无需滚动）。
  void _scrollToEpisode(int index) {
    if (widget.item.anime.episodes.length <= _episodeInlineLimit) return;
    if (!_episodeScroll.hasClients) return;
    final max = _episodeScroll.position.maxScrollExtent;
    final target = (index * _episodeRowExtent).clamp(0.0, max);
    _episodeScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// 1.6s 后取消高亮（足够用户确认落点，又不长期占视觉）
  void _scheduleHighlightClear() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _highlightIndex = null);
    });
  }

  /// 「跳至第 N 集」：按**集标题里的集数**优先匹配，失败按「第 N 集 = 第 N 项」
  /// 回退（与 [findMatchingEpisode] 同一套语义，保证和自动匹配一致）。
  void _jumpToEpisode() {
    final episodes = widget.item.anime.episodes;
    final raw = _jumpController.text.trim();
    final number = double.tryParse(raw);
    if (number == null) {
      setState(() => _locateHint = '请输入集数（数字）');
      return;
    }
    final match = findMatchingEpisode(episodes, number);
    final index = match == null ? -1 : episodes.indexOf(match);
    if (index < 0) {
      setState(() => _locateHint = '没有第 ${number.toInt()} 集');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _locateHint = null;
      _highlightIndex = index;
    });
    _scrollToEpisode(index);
    _scheduleHighlightClear();
  }

  @override
  void didUpdateWidget(covariant _AnimeResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _controller.forward();
      _ensureHeaderVisible();
      // 展开动画走完再定位：此刻集列表已布局完成、滚动控制器才有 clients
      // （短列表内联展示不需要滚动，也无需延时）
      if (widget.item.anime.episodes.length > _episodeInlineLimit) {
        _locateTimer?.cancel();
        _locateTimer = Timer(_expandInDuration, () {
          if (mounted) setState(_locateCurrentEpisodeOnce);
        });
      } else {
        _locateCurrentEpisodeOnce();
      }
    } else {
      _controller.reverse();
    }
  }

  /// 展开后延时自动定位的定时器（等集列表布局完成）
  Timer? _locateTimer;

  @override
  void dispose() {
    _locateTimer?.cancel();
    _highlightTimer?.cancel();
    _episodeScroll.dispose();
    _jumpController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 与展开动画同步滚动（卡头高度固定，展开期间位置不变，可立即发起）
  void _ensureHeaderVisible() {
    final ctx = _headerKey.currentContext;
    if (ctx == null || Scrollable.maybeOf(ctx) == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: _expandInDuration,
      curve: Curves.easeOutCubic,
      alignment: 0.02,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.item.anime;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            key: _headerKey,
            onTap: widget.onToggle,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // 番剧名超长会被截断：点标题看完整名称（与集名同一出口）
                        if (anime.animeTitle.length > 18)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: GestureDetector(
                              onTap: () => showEpisodeTitleDialog(
                                context,
                                anime.animeTitle,
                              ),
                              child: Text(
                                '查看完整名称',
                                style: TextStyle(
                                  color: _accentOf(context),
                                  fontSize: 11,
                                ),
                              ),
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
                            // 默认弹弹Play 同样标注——只标自建服务器时，默认
                            // 那条"没有标签"反而让人以为是别的来源。
                            _CapsuleLabel(widget.item.serverName),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _height.drive(Tween(begin: 0.0, end: 0.5)),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white38,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 集列表：高度因子 + 内容淡入淡出错峰；完全收起时不构建子树
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isDismissed) return const SizedBox.shrink();
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _height.value,
                  child: FadeTransition(
                    opacity: _fade,
                    child: _buildEpisodes(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodes() {
    final episodes = widget.item.anime.episodes;
    final rows = <Widget>[
      for (var i = 0; i < episodes.length; i++) ...[
        if (i > 0) _panelDivider(),
        _EpisodeRow(
          episode: episodes[i],
          highlighted: _highlightIndex == i,
          onTap: () => widget.onEpisodeSelected(episodes[i]),
        ),
      ],
    ];
    return Column(
      children: [
        _panelDivider(),
        // 集数定位条：集数多（>6）才出现——短番剧直接看得到，加了是噪声
        if (episodes.length > _episodeInlineLimit) _buildEpisodeLocator(),
        if (_locateHint != null) _buildLocateHint(_locateHint!),
        // 集数少 → 直接内联；集数多 → 定高滚动容器（动画期间布局量恒定）
        if (episodes.length <= _episodeInlineLimit)
          Column(children: rows)
        else
          SizedBox(
            height: _episodeListHeight,
            child: Scrollbar(
              child: ListView(
                controller: _episodeScroll,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: rows,
              ),
            ),
          ),
      ],
    );
  }

  /// 「跳至第 N 集」定位条（集数上下限给用户一个预期）
  Widget _buildEpisodeLocator() {
    final total = widget.item.anime.episodes.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  const Text(
                    '跳至第',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _jumpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _jumpToEpisode(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      cursorColor: _accentOf(context),
                      cursorHeight: 14,
                      decoration: const InputDecoration.collapsed(
                        hintText: '集数',
                        hintStyle: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '集 / 共 $total 集',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniIconButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: '跳转',
            color: _accentOf(context),
            onTap: _jumpToEpisode,
          ),
        ],
      ),
    );
  }

  /// 定位失败提示（内联一行，不弹对话框——面板里弹窗体验更重）
  Widget _buildLocateHint(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// 集列表行：集标题 + 下载图标；[highlighted] 时整行高亮（定位落点）。
///
/// 标题单行过长会截断，点击标题弹出完整文本 + 复制（长番剧集名常带
/// 字幕组/分辨率后缀，一行放不下）。
class _EpisodeRow extends StatelessWidget {
  final DandanEpisode episode;
  final VoidCallback onTap;
  final bool highlighted;

  const _EpisodeRow({
    required this.episode,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: highlighted
            ? _accentOf(context).withValues(alpha: 0.16)
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                // 长按看完整集名（单击仍是「选中该集」，不改变原有交互）
                onLongPress: () =>
                    showEpisodeTitleDialog(context, episode.episodeTitle),
                child: Text(
                  episode.episodeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_outlined, size: 16, color: _accentOf(context)),
          ],
        ),
      ),
    );
  }
}

/// 集标题完整内容弹窗（长文本被截断时的出口）：完整文本 + 一键复制。
///
/// 用 `showDialog` 而非本 App 惯用的 `showAppDialog`：后者是「顶层面板路由」
/// 语义（播放器面板用），而这里只需要一个轻量对话框。样式与
/// `showPlayerPanel` 内的卡片一致（暗底 + 主色描边）。
Future<void> showEpisodeTitleDialog(BuildContext context, String title) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text(
        '完整集名',
        style: TextStyle(color: Colors.white, fontSize: 15),
      ),
      content: SelectableText(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: title));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('复制'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
