import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/models/danmaku_font_mode.dart';
import 'package:moumou/pages/home/home_page.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/pages/settings/settings_page.dart';
import 'package:moumou/services/app_font_settings.dart';
import 'package:moumou/services/bilibili/bili_account.dart';
import 'package:moumou/services/crash_log_service.dart';
import 'package:moumou/services/danmaku_server_settings.dart';
import 'package:moumou/services/danmaku_settings.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/download/download_manager.dart';
import 'package:moumou/services/equalizer_settings.dart';
import 'package:moumou/services/intro_outro_settings.dart';
import 'package:moumou/services/media_scan_settings.dart';
import 'package:moumou/services/network/network_connection_settings.dart';
import 'package:moumou/services/playback_history_service.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/privacy_policy_settings.dart';
import 'package:moumou/services/subtitle_settings.dart';
import 'package:moumou/services/super_resolution_service.dart';
import 'package:moumou/services/update/update_service.dart';
import 'package:moumou/services/update/update_settings.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/theme/app_theme.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/utils/url_media.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/capsule_nav_bar.dart';
import 'package:moumou/widgets/main_scaffold.dart';
import 'package:moumou/widgets/privacy_policy_dialog.dart';
import 'package:moumou/widgets/update_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 崩溃缓存机制：Dart 侧未捕获异常也写入崩溃日志目录（原生 CrashHandler
  // 负责 Java/Kotlin 崩溃；两者同目录，错误日志页统一查看/导出/复制）
  MediaKit.ensureInitialized();
  // FlutterError（框架层）异常也写日志 —— 必须先于 runApp 挂钩子
  final oldError = FlutterError.onError;
  FlutterError.onError = (details) {
    oldError?.call(details);
    CrashLogService.appendDartLog(
      '━━━ Flutter 异常 ${DateTime.now()} ━━━\n'
      '${details.exception}\n${details.stack ?? ''}\n'
      '━━━━━━━━━━━━━━━━━━━━━━━━',
    );
  };
  // 自定义字体必须在 runApp 前注册进引擎（loadFontFromList 只对当前进程有效，
  // 首次渲染该 family 前未注册会回落默认字体）。App 全局字体 + 弹幕自定义字体
  // 各注册一次（见 §4.12）。
  await AppFontSettings.instance.ensureLoaded();
  await AppFontSettings.instance.registerCurrentFont();
  await DanmakuSettings.instance.ensureLoaded();
  await _registerDanmakuFont();
  // 隐私政策同意状态：runApp 前加载，确保首帧即可读到正确状态
  // （首次启动未同意 → 启动门禁弹隐私弹窗）。
  await PrivacyPolicySettings.instance.ensureLoaded();
  // 更新设置：runApp 前加载，确保自动检查更新读正确开关/忽略版本状态。
  await UpdateSettings.instance.ensureLoaded();
  // Zone 层兜底：异步未捕获异常也写日志
  runZonedGuarded(
    () => runApp(const MoumouApp()),
    (error, stack) {
      CrashLogService.appendDartLog(
        '━━━ Zone 异常 ${DateTime.now()} ━━━\n$error\n$stack\n━━━━━━━━━━━━━━━━━━━━━━━━',
      );
    },
  );
}

/// 冷启动注册弹幕「自定义」字体（仅 custom 模式且已选字体时）。
Future<void> _registerDanmakuFont() async {
  final s = DanmakuSettings.instance;
  if (s.fontMode == DanmakuFontMode.custom &&
      s.customFontFamily != null &&
      s.customFontFile != null) {
    await AppFontSettings.registerFontFile(
      s.customFontFamily!,
      s.customFontFile!,
    );
  }
}

class MoumouApp extends StatefulWidget {
  const MoumouApp({super.key});

  @override
  State<MoumouApp> createState() => _MoumouAppState();
}

class _MoumouAppState extends State<MoumouApp> {
  final ThemeController _themeController = ThemeController();
  final ViewSettings _viewSettings = ViewSettings();

  /// 根 Navigator key：外部打开视频（系统「打开方式」）从 App 顶层 push
  /// 播放页用（widgets/ 层不 import pages/，故挂在这里，见 §3 分层）
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeController.load();
    _viewSettings.load();
    // 外部打开视频（注册为系统播放器，工作.md）：
    // - 热启动（onNewIntent）：原生推送 onExternalVideo → 取走并播放；
    // - 冷启动（onCreate intent 暂存原生侧）：首帧后取走并播放。
    DeviceServices.onExternalVideo = _consumePendingExternalVideo;
    // 首帧门禁：先确认隐私政策（未同意弹隐私弹窗），再消费冷启动外部视频。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onFirstFrame();
    });
    // 用 ensureLoaded 而非 load：播放页恢复进度时也用 ensureLoaded，
    // 两者共享同一 load Future，防止「main 的 load 未完成、播放页已读
    // 空缓存」的竞态（用户反馈：重启后恢复不了进度的根因）
    PlaybackProgressService.instance.ensureLoaded();
    // 用 ensureLoaded 而非 load：setter 侧的 ensureLoaded 与这里共享同一
    // load Future，防止「启动加载未完成、用户已改设置被 load 覆盖」的竞态
    // （risk_audit #9）
    PlayerControlsSettings.instance.ensureLoaded();
    // 片头片尾设置：同 ensureLoaded 模式（面板 setter 与这里共享同一
    // load Future，防竞态）
    IntroOutroSettings.instance.ensureLoaded();
    // 字幕设置（工作.md 阶段1 第 3 点）：同 ensureLoaded 模式（面板 setter
    // 与这里共享同一 load Future，防竞态）
    SubtitleSettings.instance.ensureLoaded();
    // 媒体扫描设置：同 ensureLoaded 模式
    MediaScanSettings.instance.ensureLoaded();
    SuperResolutionService.instance.load();
    // 解码设置（硬解/软解档位）：同 ensureLoaded 模式，播放页创建
    // VideoController 时同步读取（防竞态）
    DecodeSettings.instance.ensureLoaded();
    // 音频均衡器设置（工作.md 均衡器功能）：同 ensureLoaded 模式，
    // AudioController 构造时订阅、applyAudioOptions 读取（防竞态）
    EqualizerSettings.instance.ensureLoaded();
    // 弹幕设置（阶段2）：同 ensureLoaded 模式，DanmakuController 构造时
    // 订阅并读取（面板 setter 与这里共享同一 load Future，防竞态）
    DanmakuSettings.instance.ensureLoaded();
    // 弹幕服务器设置（阶段3 网络弹幕）：同 ensureLoaded 模式，切集自动匹配
    // 与网络搜索读取服务器列表/开关（setter 与这里共享同一 load Future）
    DanmakuServerSettings.instance.ensureLoaded();
    // 网络存储账户（阶段4 网络存储）：同 ensureLoaded 模式，账户列表页
    // ListenableBuilder 订阅、账户增删改用 setter 与这里共享同一 load Future
    NetworkConnectionSettings.instance.ensureLoaded();
    // 播放历史（工作.md：播放历史记录功能）：同 ensureLoaded 模式；
    // 首页速拨「最近播放」与「历史记录」页读取
    PlaybackHistoryService.instance.ensureLoaded();
    // App 全局字体设置（工作.md 第 3 点）：同 ensureLoaded 模式；main() 已在
    // runApp 前 await 注册，这里补 ensureLoaded 防测试/热重载路径竞态
    AppFontSettings.instance.ensureLoaded();
    // 哔哩哔哩账号（工作.md 阶段一）：启动读凭证 + nav 自检（含 buvid 预取），
    // 异步执行不阻塞首帧；「我的」页监听其 ChangeNotifier 实时刷新登录态
    BiliAccount.instance.ensureLoaded();
    // 下载管理器（工作.md 第 2 点）：启动恢复持久化的下载记录，下载管理页
    // 不再「重启即清空」。
    DownloadManager.instance.ensureLoaded();
    // 隐私政策同意状态：main() 已在 runApp 前 await 加载，这里补 ensureLoaded
    // 防测试/热重载路径竞态（与其他设置服务同模式）。
    PrivacyPolicySettings.instance.ensureLoaded();
    // 更新设置：main() 已在 runApp 前 await 加载，这里补 ensureLoaded 防竞态。
    UpdateSettings.instance.ensureLoaded();
  }

  @override
  void dispose() {
    DeviceServices.onExternalVideo = null;
    _themeController.dispose();
    _viewSettings.dispose();
    super.dispose();
  }

  // ── 外部打开视频（系统「打开方式」→ 本项目播放，工作.md）──

  /// 首帧门禁：先确认隐私政策，再安排自动检查更新，最后消费冷启动外部视频。
  Future<void> _onFirstFrame() async {
    final ok = await _ensurePrivacyAccepted();
    if (!ok) return; // 用户未同意 → 已退出应用
    _scheduleAutoUpdateCheck();
    await _consumePendingExternalVideo();
  }

  /// 启动 2 秒后自动检查更新（仅开关开启且未忽略该版本时弹窗）。
  void _scheduleAutoUpdateCheck() {
    Future.delayed(const Duration(seconds: 2), _autoCheckUpdate);
  }

  Future<void> _autoCheckUpdate() async {
    final settings = UpdateSettings.instance;
    if (!settings.autoUpdateEnabled) return;
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null) return;
      if (settings.isVersionIgnored(info.version)) return;
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      await showUpdateDialog(context, info: info, settings: settings);
    } catch (_) {
      return; // 自动检查失败静默
    }
  }

  /// 确保隐私政策已同意；未同意时弹隐私弹窗（10 秒倒计时 + 勾选同意）。
  /// 返回 true 表示可继续进入应用，false 表示用户选择退出。
  Future<bool> _ensurePrivacyAccepted() async {
    if (PrivacyPolicySettings.instance.accepted) return true;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    final agreed = await showPrivacyPolicyDialog(context);
    if (agreed == true) {
      await PrivacyPolicySettings.instance.accept();
      return true;
    }
    // 取消：退出应用（Android 上结束当前 Activity）
    SystemNavigator.pop();
    return false;
  }

  /// 取走原生侧暂存的外部视频并播放（冷启动 + onNewIntent 推送共用入口）
  Future<void> _consumePendingExternalVideo() async {
    // 隐私政策未同意前不处理外部打开（防播放页盖过隐私门禁弹窗）
    if (!PrivacyPolicySettings.instance.accepted) return;
    final pending = await DeviceServices.takeExternalVideo();
    if (pending == null) return;
    final uri = pending['uri'] ?? '';
    if (uri.isEmpty) return;
    await _playExternalVideo(uri, fallbackTitle: pending['title'] ?? '');
  }

  Future<void> _playExternalVideo(
    String uri, {
    String fallbackTitle = '',
  }) async {
    // 解析为可播放路径（content:// 真实路径或缓存拷贝 / file:// / 流媒体直链）
    final resolved = await DeviceServices.resolveVideoUri(uri);
    if (resolved == null) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('无法打开该视频')));
      }
      return;
    }
    // 标题：原生解析的文件名优先；直链由 URL 提取；兜底路径最后一段
    var title = resolved.title;
    if (title.isEmpty) {
      title = isOnlineMedia(resolved.path)
          ? mediaTitleFromUrl(resolved.path)
          : resolved.path.split('/').where((s) => s.isNotEmpty).lastOrNull ??
              resolved.path;
    }
    if (title.isEmpty) title = fallbackTitle;
    if (!mounted) return;
    _navigatorKey.currentState?.push(
      playerPageRoute(PlayerPage(path: resolved.path, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeController, AppFontSettings.instance]),
      builder: (context, _) {
        final seed = _themeController.seedColor;
        final mode = _themeController.mode;
        final variant = _themeController.variant;
        final fontFamily = AppFontSettings.instance.effectiveFamily;
        final fontWeight = AppFontSettings.instance.effectiveFontWeight;

        final light = AppTheme.light(
          seed,
          variant,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
        );
        // AMOLED 模式下深色主题换成纯黑版本
        final dark = mode == AppThemeMode.amoled
            ? AppTheme.amoled(
                seed,
                variant,
                fontFamily: fontFamily,
                fontWeight: fontWeight,
              )
            : AppTheme.dark(
                seed,
                variant,
                fontFamily: fontFamily,
                fontWeight: fontWeight,
              );
        final themeMode = switch (mode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.amoled => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        };

        return MaterialApp(
          title: '小喵Player',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: themeMode,
          // 根 Navigator key：外部打开视频从 App 顶层 push 播放页（见 initState）
          navigatorKey: _navigatorKey,
          // 全局框架：安全区 + 播放页全屏（详见 AppFrame）；
          // App 自定义字体启用时叠加整体字号缩放（仅 Flutter Text）
          builder: (context, child) {
            final scale = AppFontSettings.instance.effectiveTextScale;
            if ((scale - 1.0).abs() < 0.0001) {
              return AppFrame(child: child!);
            }
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: AppFrame(child: child!),
            );
          },
          // 路由观察者：AppFrame 据此检测播放页，切换全屏行为
          navigatorObservers: [AppFrameObserver.instance],
          home: MainScaffold(
            items: [
              CapsuleNavItem(
                icon: Icons.home_outlined,
                label: '首页',
                page: HomePage(viewSettings: _viewSettings),
              ),
              CapsuleNavItem(
                // 「我的」页：账号 + 设置（对齐手机系统设置的信息架构），
                // 图标用联系人头像样式占位（登录后可换成用户头像）
                icon: Icons.account_circle_outlined,
                label: '我的',
                page: SettingsPage(controller: _themeController),
              ),
            ],
          ),
        );
      },
    );
  }
}
