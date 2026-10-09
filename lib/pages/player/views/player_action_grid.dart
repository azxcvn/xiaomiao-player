/// 播放器控制栏自定义相关组件（横竖屏两个播放页共用）：
/// - [PlayerActionGridTile]：网格项 = 圆角方底（只比图标大一圈）+ 图标 +
///   名称（在下方，不占底衬）；
/// - [PlayerActionGrid]：紧凑网格（每行 3–4 个，按可用宽度自动定列数）；
/// - [PlayerActionPreviewRow]：控制栏 5 格预览条（已选动作，长按拖动排序 +
///   右上角 ✕ 移除 + 空槽框提示）；
/// - [PlayerPanelSectionLabel]：面板内的小节标题（原横竖屏各一份，现统一）。
///
/// 尺寸原则（用户反馈）：格子要紧凑，一屏尽量多露出可点的动作 ——
/// 底衬只包图标、名称贴在下方，格子宽度按列数均分，不留大片空白。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/pages/player/views/player_pressable.dart';
import 'package:moumou/services/player_controls_settings.dart';

/// 格子最小宽度：低于它就减一列（宁可 3 列大一点，也不挤成 4 列看不清）
const double _kMinTileWidth = 72;

/// 方底（底衬）边长范围：只比图标大一圈
const double _kMinSquare = 44;
const double _kMaxSquare = 52;

/// 名称行高（10 号字，一行）
const double _kLabelHeight = 28;

/// 网格内边距与间距（横竖屏两个面板共用同一套算法）
const double _kGridHPadding = 12;
const double _kGridVPadding = 2;
const double _kGridMainSpacing = 6;
const double _kGridCrossSpacing = 6;

/// 网格项：圆角方底（只比图标大一圈）+ 图标，名称在方底下方。
///
/// [badge] 是右上角角标（自定义页用它显示 ＋）；[highlight] 为主题色描边。
/// 尺寸由 [PlayerActionGrid] 算好后传入。
class PlayerActionGridTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final Widget? badge;
  final bool highlight;
  final bool muted;
  final VoidCallback? onTap;

  final double width;
  final double height;

  const PlayerActionGridTile({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.badge,
    this.highlight = false,
    this.muted = false,
    this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final square = height - _kLabelHeight;
    // 图标占方底的约一半（方底只比图标大一圈）
    final iconSize = (square * 0.5).clamp(18.0, 24.0);
    Widget tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: square,
          height: square,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: muted ? 0.04 : 0.08),
              borderRadius: BorderRadius.circular(square * 0.26),
              border: highlight
                  ? Border.all(color: scheme.primary.withValues(alpha: 0.7))
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: Colors.white.withValues(alpha: muted ? 0.5 : 1),
                  ),
                ),
                // 角标固定在右下角（与预览条同一套视觉）
                if (badge != null)
                  Positioned(right: 0, bottom: 0, child: badge!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: muted ? 0.55 : 0.92),
            fontSize: 10,
          ),
        ),
      ],
    );
    if (onTap != null) {
      tile = PlayerPressable(
        onTap: onTap,
        borderRadius: BorderRadius.all(Radius.circular(square * 0.26)),
        child: tile,
      );
    }
    if (tooltip != null) {
      tile = Tooltip(message: tooltip!, child: tile);
    }
    return SizedBox(width: width, height: height, child: tile);
  }
}

/// 网格尺寸（按可用宽度定列数）
class PlayerActionGridMetrics {
  final int columns;
  final double tileWidth;
  final double tileHeight;

  const PlayerActionGridMetrics(this.columns, this.tileWidth, this.tileHeight);
}

/// 按可用宽度算列数与格子尺寸：宽度够就 4 列（一屏多露动作），
/// 不够就回落到 3 列。横竖屏两个面板共用同一套算法。
PlayerActionGridMetrics playerActionGridMetrics(double availableWidth) {
  final usable = availableWidth - _kGridHPadding * 2;
  var columns = 4;
  if (usable / 4 < _kMinTileWidth) columns = 3;
  final tileWidth = (usable - _kGridCrossSpacing * (columns - 1)) / columns;
  final square = tileWidth.clamp(_kMinSquare, _kMaxSquare);
  return PlayerActionGridMetrics(columns, tileWidth, square + _kLabelHeight);
}

/// 3–4 列动作网格（盒子形态）：按内容自适应高度，**自身不滚动**（由外层
/// 滚动容器统一滚动，避免出现「只有网格那一小块能滑」的局促滚动区）。
///
/// [height] 给定时把网格限制在该高度内（极矮的面板里兜底）。
class PlayerActionGrid extends StatelessWidget {
  final List<Widget> Function(double tileWidth, double tileHeight) tiles;
  final double? height;

  const PlayerActionGrid({super.key, required this.tiles, this.height});

  @override
  Widget build(BuildContext context) {
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final m = playerActionGridMetrics(width);
        // shrinkWrap + 禁滚：高度按内容算，滚动交给外层
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: m.columns,
          padding: const EdgeInsets.symmetric(
            horizontal: _kGridHPadding,
            vertical: _kGridVPadding,
          ),
          mainAxisSpacing: _kGridMainSpacing,
          crossAxisSpacing: _kGridCrossSpacing,
          childAspectRatio: m.tileWidth / m.tileHeight,
          children: tiles(m.tileWidth, m.tileHeight),
        );
      },
    );
    if (height == null) return child;
    return SizedBox(height: height, child: child);
  }
}

/// 网格的 sliver 形态：可直接塞进 [CustomScrollView]（「更多」面板用）
class PlayerActionGridSliver extends StatelessWidget {
  final List<Widget> Function(double tileWidth, double tileHeight) tiles;

  const PlayerActionGridSliver({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent.isFinite
            ? constraints.crossAxisExtent
            : MediaQuery.sizeOf(context).width;
        final m = playerActionGridMetrics(width);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kGridHPadding,
            vertical: _kGridVPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: m.columns,
              mainAxisSpacing: _kGridMainSpacing,
              crossAxisSpacing: _kGridCrossSpacing,
              childAspectRatio: m.tileWidth / m.tileHeight,
            ),
            delegate: SliverChildListDelegate(tiles(m.tileWidth, m.tileHeight)),
          ),
        );
      },
    );
  }
}

/// 控制栏 5 格预览条：只呈现用户在顶栏选中的动作（返回/「更多」是固定
/// 按钮，不参与自定义，故不出现）。
///
/// - 顺序 = 播放页顶栏从左到右的顺序；
/// - 长按拖动排序 → [onReorder]（拖动中整体放大 + 加暗底，表明已进入排序态）；
/// - 右下角「－」移除（[onRemove] 非空时显示）；
/// - 未放满时画空槽框，提示还能放几个。
class PlayerActionPreviewRow extends StatelessWidget {
  final List<PlayerTopAction> slots;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(PlayerTopAction action) onRemove;

  /// 给每个槽位（含空槽）挂外部 key（自定义页用它定位飞行起终点）
  final GlobalKey Function(PlayerTopAction? action, int index)? keyOf;

  /// 该槽位（下标）是否正被飞行副本占用：是则图标先隐身，
  /// 等飞行副本落下再显形
  final bool Function(int index)? isSlotHidden;

  const PlayerActionPreviewRow({
    super.key,
    required this.slots,
    required this.onReorder,
    required this.onRemove,
    this.keyOf,
    this.isSlotHidden,
  });

  /// 与 [PlayerControlsSettings.maxTopActions] 一致（5 格，竖屏顶栏同上限）
  static const int slotCount = PlayerControlsSettings.maxTopActions;

  static const double _slotHeight = 52;
  static const double _gap = 6;

  /// 槽位最小/最大边长：均分后过窄时靠滚动容纳
  static const double _minSlot = 40;
  static const double _maxSlot = 64;

  @override
  Widget build(BuildContext context) {
    final placed = slots.take(slotCount).toList();
    // 面板内容左右各留 12，与可添加网格同一左缘
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          // 5 格均分整行宽度（间距相等、刚好填满），观感上不留右侧空白
          final slot = math
              .min(_maxSlot, (width - _gap * (slotCount - 1)) / slotCount)
              .clamp(_minSlot, _maxSlot);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: _slotHeight,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: onReorder,
                itemCount: slotCount,
                // 拖动反馈：被拎起的那份整体放大 + 深色底（表明正在排序）
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(animation.value);
                    return Transform.scale(
                      scale: 1 + 0.12 * t,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35 * t),
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                    );
                  },
                ),
                itemBuilder: (context, i) {
                  if (i >= placed.length) {
                    // ⚠️ key 必须逐槽唯一：空槽共用同一 key 会让
                    // ReorderableListView 的元素复用错乱，直接踩到 framework 的
                    // `!childSemantics.renderObject._needsLayout` 断言
                    return Padding(
                      key: ValueKey('empty-slot-$i'),
                      padding: const EdgeInsets.only(right: _gap),
                      child: SizedBox(
                        key: keyOf?.call(null, i),
                        width: slot,
                        height: _slotHeight,
                        child: const _EmptySlot(),
                      ),
                    );
                  }
                  final a = placed[i];
                  return Padding(
                    key: ValueKey('slot-${a.id}'),
                    padding: const EdgeInsets.only(right: _gap),
                    child: SizedBox(
                      key: keyOf?.call(a, i),
                      width: slot,
                      height: _slotHeight,
                      child: ReorderableDelayedDragStartListener(
                        index: i,
                        child: _PreviewSlot(
                          action: a,
                          // 飞行中：这一格的图标先隐身，避免与飞行副本重合
                          hidden: isSlotHidden?.call(i) ?? false,
                          onRemove: () => onRemove(a),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 已放置槽位：半透明圆角底 + 居中图标 + 右下角「－」移除角标。
///
/// **点击整个方块即可移除**（与可添加网格「点方块即添加」一致，角标只是
/// 可见的提示，不是唯一热区）；长按 0.5 秒仍然是拖动排序，两者在手势上
/// 不冲突（单击松手即触发，长按超过阈值才进拖动）。
///
/// 拖动反馈见 [PlayerActionPreviewRow] 的 proxyDecorator：拖动时整体放大 +
/// 加暗底，明确「已进入排序状态」。
///
/// ⚠️ 槽位本身**不能包 [Tooltip]**：它的「长按显示名称」会抢掉同一个长按
/// 手势，导致长按只弹名称、拖不动。
class _PreviewSlot extends StatelessWidget {
  final PlayerTopAction action;
  final VoidCallback onRemove;

  /// 正在被飞行副本替代：图标与角标先隐身（保留格子底板，飞行落点不变形）
  final bool hidden;

  const _PreviewSlot({
    required this.action,
    required this.onRemove,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            // 图标居中（角标挪到右下角，不再挤压图标）
            child: Center(
              child: AnimatedOpacity(
                opacity: hidden ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
            ),
          ),
          if (!hidden) _RemoveBadge(onRemove: onRemove),
        ],
      ),
    );
  }
}

/// 右下角「移除」角标：红底减号（与网格里蓝底加号同一套视觉语言）
class _RemoveBadge extends StatelessWidget {
  final VoidCallback onRemove;

  const _RemoveBadge({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: onRemove,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFE5484D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.remove,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空槽：淡色圆角框（提示还能放几个）
///
/// ⚠️ 用带边框的 [Container] 而不是只带 painter 的 `CustomPaint`：后者直接
/// 放进横向 ReorderableListView 会踩到 framework 的
/// `!childSemantics.renderObject._needsLayout` 断言（widget 测试直接红）。
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white38),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// 面板内的小节标题（横竖屏共用，原两份实现已合并）
///
/// 上下留白偏紧（top 6）：竖屏底部面板只有屏高 42%，标题行越矮，
/// 可添加网格越有空间（固定行过高会直接把网格挤没）。
class PlayerPanelSectionLabel extends StatelessWidget {
  final String text;

  const PlayerPanelSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 「点击方块 → 图标飞向目标位置」的动画：让增删的结果可见，而不是目标位置
/// 凭空多一个、来源位置凭空少一个。
///
/// 用法：页内持有一个 [PlayerActionFlyAnimationController]（它管各元素的
/// [GlobalKey]），把 [PlayerActionFlyAnimation] 包在页面外层并把 controller
/// 传进来；点击时先调 `flyTo/flyBack`（取旧布局的起终点）再改数据，
/// overlay 里的图标副本就会从旧位置飞到新位置。
class PlayerActionFlyAnimation extends StatefulWidget {
  /// 由页内持有：负责记录元素 key 并触发飞行
  final PlayerActionFlyAnimationController controller;

  /// 飞行开始/结束时回调（页面据此重建，让目标槽位图标隐身/显形）
  final VoidCallback? onFlyingChanged;

  final Widget child;

  const PlayerActionFlyAnimation({
    super.key,
    required this.controller,
    this.onFlyingChanged,
    required this.child,
  });

  @override
  State<PlayerActionFlyAnimation> createState() =>
      PlayerActionFlyAnimationState();
}

class PlayerActionFlyAnimationState extends State<PlayerActionFlyAnimation>
    with SingleTickerProviderStateMixin {
  /// 单个控制器反复使用（`forward(from: 0)` 重启）：一次飞行新建一个
  /// [AnimationController] 会踩到 SingleTickerProvider 的「一个 State 只能
  /// 供一个控制器」限制，连续点几下方块就报错。
  ///
  /// ⚠️ 必须在 [initState] 里建：用 `late final` 懒初始化时，万一首次访问发生
  /// 在 [dispose]，会对着已 deactivate 的 element 建 ticker（TickerMode 查
  /// 祖先直接抛错）。
  late final AnimationController _controller;

  OverlayEntry? _entry;

  /// 飞行序号：连续点击时用来判断「结束回调属于哪一次飞行」，
  /// 只让最新那次负责收尾
  int _flightSeq = 0;
  PlayerTopAction? _action;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  double _fromSize = 44;
  double _toSize = 44;

  /// 正在飞行的动作：目的地那一格的图标先隐身，等副本落下再显形 ——
  /// 否则副本与目标位置已经画好的图标完全重合，「看不见在飞」。
  PlayerTopAction? get flyingAction => _action;

  /// 飞行目标所在的槽位下标（目标格图标先隐身）
  int? _hiddenSlotIndex;

  /// 该槽位是否正被飞行副本占用（图标先隐身）
  bool isSlotHidden(int index) => _hiddenSlotIndex == index;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    widget.controller.attach(this);
  }

  @override
  void didUpdateWidget(covariant PlayerActionFlyAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      widget.controller.attach(this);
    }
  }

  /// 从网格方块飞到预览条槽位（添加方向）
  ///
  /// [atIndex] 是**目标空槽的位置**：添加时目标槽位在数据落地前还不存在，
  /// 只能借那个空槽的几何位置当落点。
  void flyToSlot(PlayerTopAction action, {required int atIndex}) => _fly(
        action: action,
        fromKey: widget.controller.tileKey(action),
        toKey: widget.controller.slotKeyAt(atIndex),
        hideSlotIndex: atIndex,
      );

  /// 从预览条槽位飞回网格方块（移除方向）
  void flyToTile(PlayerTopAction action, {required int atIndex}) => _fly(
        action: action,
        fromKey: widget.controller.slotKeyAt(atIndex),
        toKey: widget.controller.tileKey(action),
      );

  void _fly({
    required PlayerTopAction action,
    required GlobalKey fromKey,
    required GlobalKey toKey,
    int? hideSlotIndex,
  }) {
    final fromBox = fromKey.currentContext?.findRenderObject();
    final toBox = toKey.currentContext?.findRenderObject();
    // 目标不可见（被滚动出视口/已满）时不飞，动作照常完成
    if (fromBox is! RenderBox || toBox is! RenderBox) return;
    if (!fromBox.hasSize || !toBox.hasSize) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final fromRect = fromBox.localToGlobal(Offset.zero) & fromBox.size;
    final toRect = toBox.localToGlobal(Offset.zero) & toBox.size;
    _from = fromRect.center;
    _to = toRect.center;
    _fromSize = fromRect.shortestSide * 0.5;
    _toSize = toRect.shortestSide * 0.5;
    // 先让目的地图标隐身，再插入副本：落下时两者交替，接得上
    setState(() {
      _action = action;
      _hiddenSlotIndex = hideSlotIndex;
    });
    widget.onFlyingChanged?.call();
    _entry?.remove();
    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildFlight(_controller.value),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    final seq = ++_flightSeq;
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || seq != _flightSeq) return;
      _endFlight(entry);
    });
  }

  void _endFlight(OverlayEntry entry) {
    entry.remove();
    if (identical(_entry, entry)) _entry = null;
    setState(() {
      _action = null;
      _hiddenSlotIndex = null;
    });
    widget.onFlyingChanged?.call();
  }

  Widget _buildFlight(double t) {
    final action = _action;
    if (action == null) return const SizedBox.shrink();
    final curved = Curves.easeInOutCubic.transform(t);
    final center = Offset.lerp(_from, _to, curved)!;
    // 飞行中略放大（被拎起来），落位时收回到目标尺寸
    final size = _fromSize + (_toSize - _fromSize) * curved;
    final lift = (curved < 0.5 ? curved : 1 - curved) * 2;
    return Stack(
      children: [
        Positioned(
          left: center.dx - size / 2,
          top: center.dy - size / 2,
          child: Transform.scale(
            scale: 1 + 0.15 * lift,
            child: SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16 + 0.1 * lift),
                  borderRadius: BorderRadius.circular(size * 0.26),
                ),
                child: Center(
                  child: Icon(
                    action.icon,
                    color: Colors.white,
                    size: size * 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    _entry?.remove();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 飞行动画的控制手柄：页面持有一个，负责按键记录各元素 key，
/// 并在点击时驱动 [PlayerActionFlyAnimation] 里的 overlay 动画。
class PlayerActionFlyAnimationController {
  /// 可添加网格里各方块的 key（按动作）
  final Map<PlayerTopAction, GlobalKey> tileKeys = {};

  /// 预览条里各槽位的 key（**按下标**：空槽同样要 key —— 添加时目标槽位
  /// 在数据落地前还不存在，落点只能借用那个空槽的位置）
  final Map<int, GlobalKey> slotIndexKeys = {};

  PlayerActionFlyAnimationState? _host;

  void attach(PlayerActionFlyAnimationState host) => _host = host;

  void detach(PlayerActionFlyAnimationState host) {
    if (_host == host) _host = null;
  }

  GlobalKey tileKey(PlayerTopAction a) =>
      tileKeys.putIfAbsent(a, () => GlobalKey());

  GlobalKey slotKeyAt(int index) =>
      slotIndexKeys.putIfAbsent(index, () => GlobalKey());

  /// 预览条槽位的外部 key（动作参数只为调用点可读，落点按下标定位）
  GlobalKey slotKey(PlayerTopAction? action, int index) => slotKeyAt(index);

  /// 从网格方块飞到预览条槽位（添加）：[atIndex] = 目标空槽下标
  void flyTo(PlayerTopAction a, {required int atIndex}) =>
      _host?.flyToSlot(a, atIndex: atIndex);

  /// 从预览条槽位飞回网格方块（移除）：[atIndex] = 该槽位当前下标
  void flyBack(PlayerTopAction a, {required int atIndex}) =>
      _host?.flyToTile(a, atIndex: atIndex);

  /// 该动作是否正在飞行（移除方向：源槽位图标立刻隐身）
  bool isFlying(PlayerTopAction a) => _host?.flyingAction == a;

  /// 该槽位下标是否正被飞行副本占用
  bool isSlotHidden(int index) => _host?.isSlotHidden(index) ?? false;

  void dispose() {
    _host = null;
    tileKeys.clear();
    slotIndexKeys.clear();
  }
}
