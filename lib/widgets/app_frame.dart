import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/services/wallpaper_settings.dart';
import 'package:moumou/widgets/wallpaper_layer.dart';

/// 播放页路由标识：播放页 push 时需携带 RouteSettings(name: playerRouteName)
const String playerRouteName = 'player';

/// 播放页路由：**无进出场动画**（瞬时切换）。
///
/// 历史：曾用 200ms FadeTransition（淡入是透明度合成，转场期底层列表页
/// 透出）与 220ms SlideTransition（从右滑入，转场期可见「一半播放页、
/// 一半 app 界面」）——用户明确要求去掉进出播放的动画，进出瞬间完成，
/// 播放页与列表页任何时刻不同框。横屏旋转/沉浸式由播放页自管，与路由无关。
Route<T> playerPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    settings: const RouteSettings(name: playerRouteName),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => page,
  );
}

/// 全局框架：包裹整个 Navigator，处理系统安全区、播放页全屏与自定义壁纸。
///
/// - 普通页面：底部避让系统导航键（三大金刚键），背景为主题色；
/// - 播放页（NavigatorObserver 自动检测）：背景黑色、不消费任何系统栏
///   inset（真正全屏），避免横屏时挖孔/导航栏区域露出浅色背景（白色条）；
/// - **自定义壁纸**（[WallpaperSettings]）：仅非播放页渲染，铺在导航栈背后；
///   壁纸生效时主题的 `scaffoldBackgroundColor` 已置透明（见 `AppTheme`），
///   所以底色由这里自己铺（AMOLED 的 `surface` 是黑，直接取它即可）。
///
/// 注意 left/right 恒为 false：横屏时挖孔在物理左/右侧，若 SafeArea 消费
/// 左右 inset，整个界面会被挖孔挤到一侧并露出背景色。
class AppFrame extends StatelessWidget {
  final Widget child;

  const AppFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppFrameObserver.instance.isPlayerTop,
      builder: (context, isPlayer, _) {
        // 非播放页时按主题设置系统栏（状态栏 + 导航栏）样式：
        // - 深色 / AMOLED：导航栏黑底 + 浅色键（修复三大金刚键区域白底）；
        // - 浅色：导航栏浅色底（对齐主题背景）+ 深色键。
        // 此处是 MaterialApp.builder，在 MaterialApp 内部 _themeBuilder
        // 覆写系统栏样式之后执行（同一构建帧内后写者生效），保证按主题生效；
        // 播放页在栈顶时跳过 —— 播放页自管沉浸式透明系统栏（见 player_page）。
        if (!isPlayer) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor:
                  isDark ? Colors.black : theme.scaffoldBackgroundColor,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );
          return _buildWithWallpaper(context);
        }
        return ColoredBox(
          color: Colors.black,
          child: SafeArea(
            left: false,
            top: false,
            right: false,
            bottom: false,
            child: child,
          ),
        );
      },
    );
  }

  /// 非播放页：底色 → （有壁纸时）壁纸层 → 内容。
  Widget _buildWithWallpaper(BuildContext context) {
    final settings = WallpaperSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final active = settings.active;
        // 壁纸生效时主题底色是透明的，这里得自己铺一层实底：
        // 用 colorScheme.surface（AMOLED 已被压成纯黑，深浅色主题都正确），
        // 否则 Fit 模式的留边/半透明壁纸会露出下层窗口
        final baseColor = active
            ? theme.colorScheme.surface
            : theme.scaffoldBackgroundColor;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: baseColor),
            if (active)
              WallpaperLayer(
                path: settings.path!,
                scaleMode: settings.scaleMode,
                scale: settings.scale,
                offsetX: settings.offsetX,
                offsetY: settings.offsetY,
                blur: settings.blur,
                opacity: settings.opacity,
              ),
            SafeArea(
              left: false,
              top: false,
              right: false,
              bottom: true,
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// 路由观察者：监听栈顶是否为播放页，供 [AppFrame] 切换全屏行为。
/// 全局单例，挂到 MaterialApp.navigatorObservers。
class AppFrameObserver extends NavigatorObserver {
  AppFrameObserver._();

  static final AppFrameObserver instance = AppFrameObserver._();

  /// 栈顶是否为播放页
  final ValueNotifier<bool> isPlayerTop = ValueNotifier(false);

  final List<Route<dynamic>> _stack = [];

  void _update() {
    final top = _stack.isEmpty ? null : _stack.last;
    isPlayerTop.value = top != null && _isPlayerRoute(top);
  }

  bool _isPlayerRoute(Route<dynamic> route) {
    return route.settings.name == playerRouteName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
    _update();
  }

  /// 测试用：重置栈状态
  @visibleForTesting
  void reset() {
    _stack.clear();
    isPlayerTop.value = false;
  }
}
