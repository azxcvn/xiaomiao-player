/// 网络弹幕的**集数二级界面**（问题 3）：只装"当前点中的那一条搜索结果"的
/// 集列表，从网络弹幕搜索面板点结果卡进入（面板内就地切换，不叠第二个弹窗，
/// §4.5：由播放页把 [PlayerPanelPage] push 进横/竖屏面板导航器）。
///
/// 为什么单独开一页：一级（搜索）界面里既要在结果卡内部滑动长集列表、又要
/// 输「跳至第 N 集」，空间非常局促；独立一页后整屏都给集列表，定位与跳转都
/// 有余量。
///
/// **页面头部只占一行**：番剧名交给面板顶部标题行（长标题在那一行跑马灯滚动，
/// 见 [PlayerPanelPage.marqueeTitle]），这里只留「跳至第 N 集」输入框，右侧挂
/// 一行淡字「共 N 集 · 来自 X」——标题 + 信息块 + 跳转条三层叠起来曾吃掉竖屏
/// 2/5 的高度，只剩 3/5 给集列表，滑都滑不开。
///
/// 三件事：
/// 1. **集名完整换行**：不再单行截断 + 长按弹窗，一行装不下就换行、行高自适应；
/// 2. **跳转**：「跳至第 N 集」输入框常驻顶部（集数 > 1 时），回车或点箭头跳；
/// 3. **自动定位**：进页即按当前播放文件名解析集数并命中对应集——
///    **把它滚到首行**（`alignment: 0.0`，即"第 120 集放在最前面"），
///    并做**较长时间的闪烁高亮**（[_flashTotal] ≈ 3.4s），否则用户会觉得
///    "画面莫名自己跳了一下，还以为是 Bug"。
///
/// 集列表**整体布局**（`SingleChildScrollView` + `Column`，非惰性 ListView）：
/// 自动定位要把目标行精确顶到首行，而惰性列表里屏幕外的行还没有 RenderObject，
/// `Scrollable.ensureVisible` 够不着；集名换行后每行高度又不一致，"按行高估算
/// 偏移"同样不准。集列表规模（几十~几百集）下一次性布局的开销可接受，换来
/// 定位绝对精确。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/danmaku_search_store.dart';
import 'package:moumou/utils/danmaku_episode.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 面板内统一强调色（对齐网络弹幕面板的派生方式）
Color _accentOf(BuildContext context) => playerPanelAccent(context);

/// 自动定位/跳转时滚动到位所用时长
const Duration _locateScrollDuration = Duration(milliseconds: 420);

/// 高亮闪烁的单程时长（一次往返 = 2×）
const Duration _flashHalfPeriod = Duration(milliseconds: 480);

/// 高亮闪烁总时长：足够长，用户能看清"是被自动滚到这里了"而不是 Bug
/// （往返约 3.5 次后恢复常态）
const Duration _flashTotal = Duration(milliseconds: 3400);

/// 闪烁高亮层（自动定位/跳转命中的那一行）的 key。
///
/// 暴露给 UI 测试定位落点（滚动是否把命中集顶到首行），同
/// `danmaku_server_page.dart` 的 `kAutoMatchBlockedTapKey` 的思路。
const Key kEpisodeHighlightKey = Key('episode_highlight');

class PlayerDanmakuEpisodesPanel extends StatefulWidget {
  /// 选中的搜索结果（番剧 + 来源服务器）
  final DanmakuSearchItem item;

  /// 当前正在播放的视频文件名（含扩展名）——自动定位用；为空/解析不出则
  /// 不做自动定位（用户仍可用「跳至第 N 集」）
  final String? currentFileName;

  /// 选中某集后的回调（播放页负责保存自动匹配缓存 + 拉取装载 + 提示）
  final void Function(DandanAnime anime, DandanEpisode episode, String? serverUrl)
  onEpisodeSelected;

  const PlayerDanmakuEpisodesPanel({
    super.key,
    required this.item,
    required this.onEpisodeSelected,
    this.currentFileName,
  });

  @override
  State<PlayerDanmakuEpisodesPanel> createState() =>
      _PlayerDanmakuEpisodesPanelState();
}

class _PlayerDanmakuEpisodesPanelState extends State<PlayerDanmakuEpisodesPanel>
    with SingleTickerProviderStateMixin {
  /// 「跳至第 N 集」输入框
  final TextEditingController _jumpController = TextEditingController();

  /// 集列表滚动控制器
  final ScrollController _scroll = ScrollController();

  /// 每集一个 key：滚动定位靠 `Scrollable.ensureVisible` 拿目标行的
  /// RenderObject，比按行高估算偏移精确（集名换行 → 行高不一致）
  late final List<GlobalKey> _rowKeys = List.generate(
    widget.item.anime.episodes.length,
    (_) => GlobalKey(),
  );

  /// 落点行的闪烁高亮（0→1→0 往返），只在 [_highlightIndex] 那一行挂上去
  late final AnimationController _flash;

  /// 当前高亮中的集下标
  int? _highlightIndex;

  /// 定位失败/输入有误的一次性提示（内联一行，不弹对话框）
  String? _locateHint;

  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    // 控制器在 initState 建（不能用 late final 惰性初始化：没触发过闪烁时
    // dispose 会当场创建它，此时元素已 deactivate，取 TickerMode 会抛断言）
    _flash = AnimationController(vsync: this, duration: _flashHalfPeriod);
    // 首帧后再定位：ensureVisible 需要目标行已经布局（拿到 RenderObject）
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _flash.dispose();
    _scroll.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  // ── 定位 ────────────────────────────────────────────────────

  /// 进页自动定位：解析当前视频文件名的集数 → 命中集列表里的那一集。
  ///
  /// 解析与匹配复用 [locateCurrentEpisode]（纯函数，与「切集自动匹配」同一套
  /// 规则，避免两处行为漂移）；失败只在列表上方给一行说明。
  void _autoLocate() {
    if (!mounted) return;
    final loc = locateCurrentEpisode(
      widget.currentFileName,
      widget.item.anime.episodes,
    );
    if (loc.index < 0) {
      final message = loc.message;
      if (message != null) setState(() => _locateHint = message);
      return;
    }
    _focusEpisode(loc.index);
  }

  /// 把第 [index] 集顶到列表首行 + 开始闪烁高亮（自动定位与手动跳转共用）
  void _focusEpisode(int index) {
    setState(() {
      _highlightIndex = index;
      _locateHint = null;
    });
    _startFlash();
    // 等这一帧把高亮行布局出来再滚，避免拿到上一帧的位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTop(index));
  }

  /// 滚动到第 [index] 集，并让它成为**首行**（`alignment: 0.0`）。
  ///
  /// 末几集滚不到首行是受列表底部限制，属正常（此时它已在可视区内）。
  void _scrollToTop(int index) {
    if (!mounted || index < 0 || index >= _rowKeys.length) return;
    final ctx = _rowKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: _locateScrollDuration,
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  /// 开始闪烁高亮，[_flashTotal] 后停在高亮态并清除（总时长够长，用户能看清落点）
  void _startFlash() {
    _flashTimer?.cancel();
    _flash.repeat(reverse: true);
    _flashTimer = Timer(_flashTotal, () {
      if (!mounted) return;
      _flash.stop();
      setState(() => _highlightIndex = null);
    });
  }

  /// 「跳至第 N 集」：按**集标题里的集数**优先匹配，失败按「第 N 集 = 第 N 项」
  /// 回退（与 [findMatchingEpisode] 同一套语义，保证和自动匹配一致）。
  void _jumpToEpisode() {
    final episodes = widget.item.anime.episodes;
    final number = double.tryParse(_jumpController.text.trim());
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
    _focusEpisode(index);
  }

  void _selectEpisode(DandanEpisode episode) {
    // 这次面板关闭是"选完一集"导致的自动关闭，不是用户主动关面板：
    // 搜索结果要留下来，下次打开弹幕面板还能接着上次挑（见 DanmakuSearchStore）
    DanmakuSearchStore.instance.markKeepOnClose();
    widget.onEpisodeSelected(
      widget.item.anime,
      episode,
      widget.item.serverUrl,
    );
    // 选集中后关闭整个弹幕面板（弹出外壳为 showGeneralDialog 路由）
    Navigator.of(context).pop();
  }

  // ── 构建 ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final episodes = widget.item.anime.episodes;
    return Column(
      children: [
        // 只留一行：跳转输入 + 右侧淡字（共 N 集 · 来自哪台服务器）。
        // 番剧名不再单独占一块——顶部标题行已经有了（长标题走跑马灯）。
        if (episodes.length > 1)
          _buildEpisodeLocator(episodes.length)
        else
          _buildMetaOnlyLine(episodes.length),
        _panelDivider(),
        if (_locateHint != null) _buildLocateHint(_locateHint!),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  for (var i = 0; i < episodes.length; i++) ...[
                    if (i > 0) _panelDivider(),
                    _EpisodeRow(
                      key: _rowKeys[i],
                      episode: episodes[i],
                      highlight: _highlightIndex == i ? _flash : null,
                      onTap: () => _selectEpisode(episodes[i]),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 集数 / 来源信息（原顶部信息区的内容，现在压进跳转条右侧的小字）
  String _metaText(int total) =>
      '共 $total 集 · 来自 ${widget.item.serverName}';

  /// 只有 1 集：没有可跳转的目标，就只留一行极简的来源信息
  Widget _buildMetaOnlyLine(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _metaText(total),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  /// 「跳至第 N 集」定位条 + 右侧「共 N 集 · 来自 X」淡字（集数上下限与来源
  /// 都给用户一个预期，且不额外占一块高度）
  Widget _buildEpisodeLocator(int total) {
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
                  const Text(
                    '集',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 窄屏（横屏面板最宽 340dp）优先保住输入框，这行淡字可省略号截断
          Flexible(
            child: Text(
              _metaText(total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
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

/// 面板内分隔线（集行之间）
Widget _panelDivider() => const Divider(
  height: 1,
  thickness: 0.5,
  indent: 16,
  endIndent: 16,
  color: Colors.white10,
);

/// 迷你圆形按钮（28dp，跳转用；与网络弹幕面板的同名小件一致）
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

/// 集列表行：集名（**完整换行**）+ 下载图标；[highlight] 非空时整行闪烁高亮。
///
/// 闪烁用 [Animation] 驱动 `ColoredBox` 颜色，而不是 `setState` 重建整页——
/// 集列表整体布局，逐帧重建整页在长番剧上不划算。
class _EpisodeRow extends StatelessWidget {
  final DandanEpisode episode;
  final VoidCallback onTap;
  final Animation<double>? highlight;

  const _EpisodeRow({
    super.key,
    required this.episode,
    required this.onTap,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentOf(context);
    final content = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                episode.episodeTitle,
                // 不设 maxLines / ellipsis：集名也完整换行（问题 2、3）
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_outlined, size: 16, color: accent),
          ],
        ),
      ),
    );
    final animation = highlight;
    if (animation == null) return content;
    return AnimatedBuilder(
      animation: animation,
      child: content,
      builder: (context, child) => ColoredBox(
        key: kEpisodeHighlightKey,
        color: accent.withValues(alpha: 0.08 + 0.22 * animation.value),
        child: child,
      ),
    );
  }
}
