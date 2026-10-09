import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/marquee_text.dart';

/// 面板内导航的一层页面
class PlayerPanelPage {
  final String title;
  final Widget body;

  /// 标题行长标题是否走跑马灯（循环滚动显示完整名称）。
  ///
  /// 默认 false——「弹幕」「倍速」这类固定短标题静态更安静；开启是给标题本身
  /// 就是内容（番剧名等长文本）的页面用的，见网络弹幕的集数二级界面。
  /// 文本一行装得下时 [MarqueeText] 不会启动动画，等同于普通标题。
  final bool marqueeTitle;

  const PlayerPanelPage({
    required this.title,
    required this.body,
    this.marqueeTitle = false,
  });
}

/// 面板导航器：面板内容通过 [PlayerPanelNavigator.of] 获取，push/pop 二级页面。
/// 二级界面在面板内部就地切换（滑动 + 淡入），永不叠加第二个面板/弹窗。
class PlayerPanelNavigator {
  final List<PlayerPanelPage> _pages;
  final VoidCallback _onChanged;

  PlayerPanelNavigator(this._pages, this._onChanged);

  bool get canPop => _pages.length > 1;

  void push(PlayerPanelPage page) {
    _pages.add(page);
    _onChanged();
  }

  void pop() {
    if (_pages.length > 1) {
      _pages.removeLast();
      _onChanged();
    }
  }

  /// 面板内容中获取当前导航器
  static PlayerPanelNavigator of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_PanelNavigatorScope>();
    assert(scope != null, 'PlayerPanelNavigator.of() called outside PlayerPanel');
    return scope!.navigator;
  }
}

/// 面板「让位」状态：true 时整个面板（含自身半透明背景）压到很淡，
/// 让用户看清被面板遮住的播放界面（「按钮大小」拖动滑杆时用）。
///
/// 面板内容用 [PlayerPanelDim.set] 切换；[of] 读当前状态（面板之外返回
/// false，测试里单独摆组件时面板内容不会因此报错）。
class PlayerPanelDim extends InheritedWidget {
  final bool dimmed;

  /// 由面板外壳持有：内容通过它改状态
  final ValueNotifier<bool>? notifier;

  const PlayerPanelDim({
    super.key,
    required this.dimmed,
    this.notifier,
    required super.child,
  });

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PlayerPanelDim>()
          ?.dimmed ??
      false;

  /// 切换「让位」状态（面板不在场时静默忽略）
  static void set(BuildContext context, bool value) {
    context
        .dependOnInheritedWidgetOfExactType<PlayerPanelDim>()
        ?.notifier
        ?.value = value;
  }

  @override
  bool updateShouldNotify(PlayerPanelDim oldWidget) =>
      oldWidget.dimmed != dimmed;
}

class _PanelNavigatorScope extends InheritedWidget {
  final PlayerPanelNavigator navigator;

  /// 面板「让位」状态：true 时整个面板（含自身背景）压到很淡
  final ValueNotifier<bool> dimmed;

  const _PanelNavigatorScope({
    required this.navigator,
    required this.dimmed,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PanelNavigatorScope oldWidget) =>
      navigator != oldWidget.navigator || dimmed != oldWidget.dimmed;
}

/// 从屏幕右缘滑入的半透明设置面板（YouTube 风格）。
///
/// 面板内部维护页面栈，支持二级设置就地切换；
/// 显示/隐藏由 [showPlayerPanel] 统一处理。
class PlayerPanel extends StatefulWidget {
  final List<PlayerPanelPage> pages;
  final VoidCallback onClose;

  /// 是否启用进出场/页内切换动画（工作.md 第 7 点：关闭「启用播放界面
  /// 动画」后为 false，面板直接出现/消失、二级页直接切换）
  final bool animate;

  const PlayerPanel({
    super.key,
    required this.pages,
    required this.onClose,
    this.animate = true,
  });

  @override
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
  // 保持同一 List 引用（导航器持有它）；外层重建时同步内容
  late final List<PlayerPanelPage> _pages = [...widget.pages];
  late final PlayerPanelNavigator _navigator =
      PlayerPanelNavigator(_pages, () => setState(() {}));

  /// 「让位」状态：面板内容可置 true 让整个面板（含背景）压淡
  final ValueNotifier<bool> _dimmed = ValueNotifier<bool>(false);

  @override
  void didUpdateWidget(covariant PlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外层每次 build 都会传入新的 pages（内含最新数据），必须同步，
    // 否则面板停留在首次打开时的旧数据（历史 bug：点预设无高亮/文本不变）。
    _pages
      ..clear()
      ..addAll(widget.pages);
  }

  @override
  void dispose() {
    _dimmed.dispose();
    super.dispose();
  }

  /// 面板底色（未让位）与让位后的底色：让位时**完全透明**（0%），
  /// 只留清晰的内容部件（如拖动中的滑杆）
  static const Color _panelColor = Color(0xE61C1C1E);
  static const Color _panelColorDimmed = Color(0x001C1C1E);

  @override
  Widget build(BuildContext context) {
    // 横屏下不超过 340dp；小屏按 72% 宽收缩
    final width = (MediaQuery.sizeOf(context).width * 0.72).clamp(0.0, 340.0);
    final page = _pages.last;
    // 「让位」：面板底色变淡 + 标题行/内容各自淡出，但内容里显式保留的部件
    // （如拖动中的滑杆）始终满不透明度 —— 全局 AnimatedOpacity 会把滑杆
    // 一起淡掉，做不到「只留滑杆清晰」，所以底色与内容分开处理。
    return ValueListenableBuilder<bool>(
      valueListenable: _dimmed,
      builder: (context, dimmed, _) => Align(
        alignment: Alignment.centerRight,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: _panelColor,
            end: dimmed ? _panelColorDimmed : _panelColor,
          ),
          duration: Duration(milliseconds: widget.animate ? 160 : 0),
          // ⚠️ Material 必须在 Align/SizedBox **之内**：否则它的底色按整屏
          // 布局，让位时整个屏幕都被刷上暗色（历史 bug）
          builder: (context, color, child) => SizedBox(
            width: width,
            height: double.infinity,
            child: Material(
              color: color ?? _panelColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
          child: _PanelNavigatorScope(
              navigator: _navigator,
              dimmed: _dimmed,
              child: PlayerPanelDim(
                dimmed: dimmed,
                notifier: _dimmed,
                child: Column(
                  children: [
                    _buildHeader(page, dimmed),
                    Expanded(
                      // 内容不再统一淡出：让位时由页面自己按 PlayerPanelDim
                      // 决定哪些部件淡（正文/说明）、哪些保持清晰（滑杆）
                      child: AnimatedSwitcher(
                          // 进场 200ms；退场仅 80ms（reverseDuration），
                          // 避免切换瞬间看到旧页面被点击时的水波纹残留；
                          // 工作.md 第 7 点：关闭播放界面动画后直接切换
                          duration: widget.animate
                              ? const Duration(milliseconds: 200)
                              : Duration.zero,
                          reverseDuration: widget.animate
                              ? const Duration(milliseconds: 80)
                              : Duration.zero,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          // 内容顶部对齐（默认 Stack 居中会让内容较短的面板
                          // 垂直居中，如画面比例面板）
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                ?currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.08, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(page.title),
                            child: page.body,
                          ),
                        ),
                    ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  /// 标题行：面板淡出时用 [PlayerPanelDim] 之外的独立 [AnimatedOpacity]，
  /// 让标题跟着一起淡（但拖动中的滑杆不会被裹进来）
  Widget _buildHeader(PlayerPanelPage page, bool dimmed) {
    final l10n = AppLocalizations.of(context);
    return AnimatedOpacity(
      opacity: dimmed ? 0.5 : 1,
      duration: Duration(milliseconds: widget.animate ? 160 : 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(
          children: [
            if (_navigator.canPop)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: l10n.commonBack,
                onPressed: _navigator.pop,
              ),
            Expanded(
              child: panelHeaderTitle(
                text: page.title,
                marquee: page.marqueeTitle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: l10n.commonOff,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// 面板内各页面在「让位」时的淡出透明度（页面自己套 [AnimatedOpacity]，
/// 需要保持清晰的部件跳过不淡）
const double kPlayerPanelDimOpacity = 0.12;

/// 面板内容部分的「让位」透明度包装：让位时淡到 [kPlayerPanelDimOpacity]。
/// 要保留清晰的部件（如拖动中的滑杆）不要包进来。
class PlayerPanelDimFade extends StatelessWidget {
  final bool dimmed;
  final bool animate;
  final Widget child;

  const PlayerPanelDimFade({
    super.key,
    required this.dimmed,
    this.animate = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? kPlayerPanelDimOpacity : 1,
      duration: Duration(milliseconds: animate ? 160 : 0),
      child: child,
    );
  }
}

/// 面板标题行文本（横竖屏两个外壳共用，§4.5：不各写一份）。
///
/// - [marquee] 为 false（默认）：单行省略号，静态；
/// - [marquee] 为 true：复用 [MarqueeText] 跑马灯——**只有装不下时才滚**，
///   装得下等同普通静态标题（见 [MarqueeText] 的溢出判断）。
///
/// 样式与两个外壳原来的标题完全一致。
Widget panelHeaderTitle({required String text, bool marquee = false}) {
  const style = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  if (!marquee) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }
  return MarqueeText(text: text, style: style);
}

/// 公用入口：从屏幕右缘弹出面板（倍速 / 更多 / 编辑控制栏等统一走这里）。
///
/// - 遮罩点击关闭；滑入 + 淡入动画（220ms easeOutCubic）；
/// - 路由标记为播放页（[playerRouteName]），保证播放页全屏安全区不被破坏；
/// - 返回的 Future 在面板关闭时完成；
/// - [animate] 为 null 时跟随「播放器设置 → 启用播放界面动画」开关
///   （工作.md 第 7 点：关闭后面板直接出现/消失）。
Future<void> showPlayerPanel(
  BuildContext context, {
  required List<PlayerPanelPage> pages,
  bool? animate,
}) {
  final withAnimation = animate ?? PlayerControlsSettings.instance.playerAnimations;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: withAnimation
        ? const Duration(milliseconds: 220)
        : Duration.zero,
    // 播放页弹出面板时仍视为播放页路由，避免 AppFrame 退出全屏（§4.3）
    routeSettings: const RouteSettings(name: playerRouteName),
    pageBuilder: (context, animation, secondaryAnimation) => PlayerPanel(
      pages: pages,
      animate: withAnimation,
      onClose: () => Navigator.of(context).pop(),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (!withAnimation) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
