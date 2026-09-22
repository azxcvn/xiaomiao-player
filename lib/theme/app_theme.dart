import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主题定义：根据 seed 色生成浅色 / 深色 / AMOLED 纯黑三种 ThemeData
class AppTheme {
  /// 统一 AppBar 样式：
  /// - [backgroundColor] 显式固定为 surface，滚动到内容下方时背景不再被
  ///   替换为 surfaceContainer（Flutter M3 的滚动变色机制），消除视觉切换
  /// - [scrolledUnderElevation] 置 0，滚动时不叠加阴影/色调
  /// - [wallpaperActive] 为真时顶栏**透明**：自定义壁纸要从状态栏一路铺到内容
  ///   之下（对齐参考实现 mpvRx 的 TopBar 处理），可读性由壁纸层的固定遮罩兜；
  ///   同时必须显式给 [AppBarTheme.systemOverlayStyle]——AppBar 在没指定时
  ///   会**按自身背景色亮度**推断状态栏图标颜色，透明被算成「黑」，于是浅色
  ///   主题下状态栏图标会变白（用户实测反馈），这里改为按主题明暗给
  static AppBarTheme _appBarTheme(
    ColorScheme scheme, {
    bool wallpaperActive = false,
    Brightness brightness = Brightness.light,
  }) => AppBarTheme(
    scrolledUnderElevation: 0,
    backgroundColor: wallpaperActive ? Colors.transparent : scheme.surface,
    systemOverlayStyle: wallpaperActive ? _overlayStyle(brightness) : null,
  );

  /// 透明顶栏下的系统栏样式：图标明暗只看**主题明暗**，不看顶栏那个透明色
  static SystemUiOverlayStyle _overlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );
  }

  /// 页面转场主题。
  ///
  /// 壁纸生效时必须换掉转场遮罩，否则进入新页面时壁纸会被压上一层灰黑滤镜：
  /// - **快照路径**（支持快照的设备）：遮罩是 `backgroundColor`，默认取
  ///   `colorScheme.surface`（不透明）；
  /// - **无快照回退路径**（模拟器等不支持快照的设备）：遮罩是**写死的黑色 60%**
  ///   （框架 `_ZoomEnterTransitionNoCache`），`backgroundColor` 改不到它。
  ///
  /// 但**不能**改成淡入淡出：页面背景是透明的（壁纸要透出来），淡入期间旧页面
  /// 会从透明处透出来 → 叠影（用户实测无法接受）。所以壁纸模式下改成
  /// [_WallpaperSlideTransitionsBuilder] 的**成对整屏滑动**：新页面从右滑入、
  /// 旧页面同步整屏滑出，任何时刻重叠面积为 0，既不叠影也不需要任何遮罩。
  /// 非壁纸模式保持框架默认 Zoom 转场。
  static PageTransitionsTheme _transitionsTheme(bool wallpaperActive) {
    if (!wallpaperActive) return const PageTransitionsTheme();
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _WallpaperSlideTransitionsBuilder(),
      },
    );
  }

  /// 用 flex_seed_scheme 的 SeedColorScheme 生成配色方案，
  /// 支持 21 种 FlexSchemeVariant 调色板风格
  static ColorScheme _scheme(
    Color seed,
    FlexSchemeVariant variant,
    Brightness brightness,
  ) {
    return SeedColorScheme.fromSeeds(
      brightness: brightness,
      primaryKey: seed,
      variant: variant,
    );
  }

  /// 壁纸生效时的页面底色：透明。
  ///
  /// 全仓 38 处 `Scaffold` / 36 处 `AppBar` 的底色都继承主题（没有任何页面
  /// 自己设过），所以「壁纸生效 → 内容背景透明」在这一个地方改就全覆盖，
  /// 不用逐页改。播放页写死了 `Colors.black`，不受影响。
  static const Color _wallpaperBackground = Colors.transparent;

  static ThemeData light(
    Color seed,
    FlexSchemeVariant variant, {
    String? fontFamily,
    FontWeight? fontWeight,
    bool wallpaperActive = false,
  }) {
    final scheme = _scheme(seed, variant, Brightness.light);
    return _withFont(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: fontFamily,
        scaffoldBackgroundColor:
            wallpaperActive ? _wallpaperBackground : null,
        appBarTheme: _appBarTheme(
          scheme,
          wallpaperActive: wallpaperActive,
          brightness: Brightness.light,
        ),
        pageTransitionsTheme: _transitionsTheme(wallpaperActive),
      ),
      fontWeight,
    );
  }

  static ThemeData dark(
    Color seed,
    FlexSchemeVariant variant, {
    String? fontFamily,
    FontWeight? fontWeight,
    bool wallpaperActive = false,
  }) {
    final scheme = _scheme(seed, variant, Brightness.dark);
    return _withFont(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: fontFamily,
        scaffoldBackgroundColor:
            wallpaperActive ? _wallpaperBackground : null,
        appBarTheme: _appBarTheme(
          scheme,
          wallpaperActive: wallpaperActive,
          brightness: Brightness.dark,
        ),
        pageTransitionsTheme: _transitionsTheme(wallpaperActive),
      ),
      fontWeight,
    );
  }

  /// AMOLED 纯黑：把所有 surface 系列压到纯黑/近黑，背景纯黑
  static ThemeData amoled(
    Color seed,
    FlexSchemeVariant variant, {
    String? fontFamily,
    FontWeight? fontWeight,
    bool wallpaperActive = false,
  }) {
    final scheme = _scheme(seed, variant, Brightness.dark).copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF111111),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF232323),
    );
    return _withFont(
      ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        fontFamily: fontFamily,
        scaffoldBackgroundColor:
            wallpaperActive ? _wallpaperBackground : Colors.black,
        appBarTheme: _appBarTheme(
          scheme,
          wallpaperActive: wallpaperActive,
          brightness: Brightness.dark,
        ),
        pageTransitionsTheme: _transitionsTheme(wallpaperActive),
      ),
      fontWeight,
    );
  }

  /// 应用统一字重（全量覆盖 textTheme 各样式，不保留内置字重层级；
  /// 对齐 PiliPlus 做法）。[fontWeight] 为 null 时原样返回。
  static ThemeData _withFont(ThemeData base, FontWeight? fontWeight) {
    if (fontWeight == null) return base;
    TextStyle w(TextStyle? s) =>
        (s ?? const TextStyle()).copyWith(fontWeight: fontWeight);
    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: w(t.displayLarge),
        displayMedium: w(t.displayMedium),
        displaySmall: w(t.displaySmall),
        headlineLarge: w(t.headlineLarge),
        headlineMedium: w(t.headlineMedium),
        headlineSmall: w(t.headlineSmall),
        titleLarge: w(t.titleLarge),
        titleMedium: w(t.titleMedium),
        titleSmall: w(t.titleSmall),
        bodyLarge: w(t.bodyLarge),
        bodyMedium: w(t.bodyMedium),
        bodySmall: w(t.bodySmall),
        labelLarge: w(t.labelLarge),
        labelMedium: w(t.labelMedium),
        labelSmall: w(t.labelSmall),
      ),
    );
  }
}

/// 壁纸模式下的页面转场：**成对整屏滑动**（新页面从右滑入，旧页面同步整屏左移滑出）。
///
/// 存在的理由见 [AppTheme._transitionsTheme]：框架 Zoom 转场会铺一层遮罩（无快照
/// 设备上是写死的黑色 60%）把壁纸压暗；而淡入淡出又会因页面背景透明而叠影。
///
/// 关键在**出场位移必须整屏（100%）**：出场页占 `[-tW, (1-t)W]`、入场页占
/// `[(1-t)W, (2-t)W]`，两者右边沿与左边沿重合，**任何时刻重叠面积都是 0**
/// ——旧页面是真的滑出屏幕，而不是留在原地被盖住（只给 25% 位移时它永远在屏幕内，
/// 透明背景下就会和入场页互相透出来，看着和叠影没区别）。
///
/// 刻意**不加** iOS 那条边缘阴影（Cupertino 转场有）：壁纸模式下任何压暗都不受欢迎。
class _WallpaperSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _WallpaperSlideTransitionsBuilder();

  /// 新页面：屏外右侧 → 原位
  static final Tween<Offset> _enterTween = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  /// 旧页面：原位 → 整屏左移滑出（与新页面同一曲线、同一动画值 → 严格相邻）
  static final Tween<Offset> _exitTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-1, 0),
  );

  static final Animatable<Offset> _enterAnimation = _enterTween.chain(
    CurveTween(curve: Curves.fastOutSlowIn),
  );
  static final Animatable<Offset> _exitAnimation = _exitTween.chain(
    CurveTween(curve: Curves.fastOutSlowIn),
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double>? secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: (secondaryAnimation ?? kAlwaysDismissedAnimation).drive(
        _exitAnimation,
      ),
      child: SlideTransition(
        position: animation.drive(_enterAnimation),
        child: child,
      ),
    );
  }
}
