import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// 应用名（任务切换器 / 窗口标题）；英文侧固定 Meow Player
  ///
  /// In zh, this message translates to:
  /// **'小喵Player'**
  String get appTitle;

  /// 通用按钮：取消
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// 外观页 · 主题模式
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeModeSystem;

  /// 外观页 · 主题模式
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeModeLight;

  /// 外观页 · 主题模式
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeModeDark;

  /// 外观页 · 主题模式
  ///
  /// In zh, this message translates to:
  /// **'AMOLED 纯黑'**
  String get settingsThemeModeAmoled;

  /// 外观页 · 预设主题色（名称与 3 字中文对应，英文按色名直译）
  ///
  /// In zh, this message translates to:
  /// **'天蓝色'**
  String get settingsThemeColorSkyBlue;

  /// No description provided for @settingsThemeColorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get settingsThemeColorBlue;

  /// No description provided for @settingsThemeColorLightBlue.
  ///
  /// In zh, this message translates to:
  /// **'浅蓝色'**
  String get settingsThemeColorLightBlue;

  /// No description provided for @settingsThemeColorIndigo.
  ///
  /// In zh, this message translates to:
  /// **'靛蓝色'**
  String get settingsThemeColorIndigo;

  /// No description provided for @settingsThemeColorTeal.
  ///
  /// In zh, this message translates to:
  /// **'蓝绿色'**
  String get settingsThemeColorTeal;

  /// No description provided for @settingsThemeColorMint.
  ///
  /// In zh, this message translates to:
  /// **'薄荷绿'**
  String get settingsThemeColorMint;

  /// No description provided for @settingsThemeColorLightGreen.
  ///
  /// In zh, this message translates to:
  /// **'浅绿色'**
  String get settingsThemeColorLightGreen;

  /// No description provided for @settingsThemeColorLime.
  ///
  /// In zh, this message translates to:
  /// **'酸橙色'**
  String get settingsThemeColorLime;

  /// No description provided for @settingsThemeColorAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀色'**
  String get settingsThemeColorAmber;

  /// No description provided for @settingsThemeColorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙色'**
  String get settingsThemeColorOrange;

  /// No description provided for @settingsThemeColorDeepOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙红色'**
  String get settingsThemeColorDeepOrange;

  /// No description provided for @settingsThemeColorRed.
  ///
  /// In zh, this message translates to:
  /// **'红色'**
  String get settingsThemeColorRed;

  /// No description provided for @settingsThemeColorPink.
  ///
  /// In zh, this message translates to:
  /// **'粉红色'**
  String get settingsThemeColorPink;

  /// No description provided for @settingsThemeColorHotPink.
  ///
  /// In zh, this message translates to:
  /// **'亮粉色'**
  String get settingsThemeColorHotPink;

  /// No description provided for @settingsThemeColorViolet.
  ///
  /// In zh, this message translates to:
  /// **'紫罗兰'**
  String get settingsThemeColorViolet;

  /// No description provided for @settingsThemeColorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get settingsThemeColorPurple;

  /// No description provided for @settingsThemeColorDeepPurple.
  ///
  /// In zh, this message translates to:
  /// **'深紫色'**
  String get settingsThemeColorDeepPurple;

  /// No description provided for @settingsThemeColorBlueGrey.
  ///
  /// In zh, this message translates to:
  /// **'蓝灰色'**
  String get settingsThemeColorBlueGrey;

  /// No description provided for @settingsThemeColorBrown.
  ///
  /// In zh, this message translates to:
  /// **'棕色'**
  String get settingsThemeColorBrown;

  /// No description provided for @settingsThemeColorGrey.
  ///
  /// In zh, this message translates to:
  /// **'灰色'**
  String get settingsThemeColorGrey;

  /// 外观页 · 调色板风格（flex_seed_scheme 的 FlexSchemeVariant）
  ///
  /// In zh, this message translates to:
  /// **'标准型'**
  String get settingsPaletteTonalSpot;

  /// No description provided for @settingsPaletteFidelity.
  ///
  /// In zh, this message translates to:
  /// **'保真型'**
  String get settingsPaletteFidelity;

  /// No description provided for @settingsPaletteMonochrome.
  ///
  /// In zh, this message translates to:
  /// **'单色型'**
  String get settingsPaletteMonochrome;

  /// No description provided for @settingsPaletteNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性型'**
  String get settingsPaletteNeutral;

  /// No description provided for @settingsPaletteVibrant.
  ///
  /// In zh, this message translates to:
  /// **'鲜艳型'**
  String get settingsPaletteVibrant;

  /// No description provided for @settingsPaletteExpressive.
  ///
  /// In zh, this message translates to:
  /// **'鲜明型'**
  String get settingsPaletteExpressive;

  /// No description provided for @settingsPaletteContent.
  ///
  /// In zh, this message translates to:
  /// **'柔和型'**
  String get settingsPaletteContent;

  /// No description provided for @settingsPaletteRainbow.
  ///
  /// In zh, this message translates to:
  /// **'彩虹型'**
  String get settingsPaletteRainbow;

  /// No description provided for @settingsPaletteFruitSalad.
  ///
  /// In zh, this message translates to:
  /// **'果味型'**
  String get settingsPaletteFruitSalad;

  /// No description provided for @settingsPaletteCandyPop.
  ///
  /// In zh, this message translates to:
  /// **'糖果型'**
  String get settingsPaletteCandyPop;

  /// No description provided for @settingsPaletteChroma.
  ///
  /// In zh, this message translates to:
  /// **'饱和型'**
  String get settingsPaletteChroma;

  /// No description provided for @settingsPaletteHighContrast.
  ///
  /// In zh, this message translates to:
  /// **'对比型'**
  String get settingsPaletteHighContrast;

  /// No description provided for @settingsPaletteJolly.
  ///
  /// In zh, this message translates to:
  /// **'欢快型'**
  String get settingsPaletteJolly;

  /// No description provided for @settingsPaletteMaterial.
  ///
  /// In zh, this message translates to:
  /// **'经典型'**
  String get settingsPaletteMaterial;

  /// No description provided for @settingsPaletteMaterial3Legacy.
  ///
  /// In zh, this message translates to:
  /// **'旧版型'**
  String get settingsPaletteMaterial3Legacy;

  /// No description provided for @settingsPaletteOneHue.
  ///
  /// In zh, this message translates to:
  /// **'单色相'**
  String get settingsPaletteOneHue;

  /// No description provided for @settingsPaletteSoft.
  ///
  /// In zh, this message translates to:
  /// **'淡雅型'**
  String get settingsPaletteSoft;

  /// No description provided for @settingsPaletteUltraContrast.
  ///
  /// In zh, this message translates to:
  /// **'超对比'**
  String get settingsPaletteUltraContrast;

  /// No description provided for @settingsPaletteVivid.
  ///
  /// In zh, this message translates to:
  /// **'生动型'**
  String get settingsPaletteVivid;

  /// No description provided for @settingsPaletteVividBackground.
  ///
  /// In zh, this message translates to:
  /// **'亮背景'**
  String get settingsPaletteVividBackground;

  /// No description provided for @settingsPaletteVividSurfaces.
  ///
  /// In zh, this message translates to:
  /// **'亮表面'**
  String get settingsPaletteVividSurfaces;

  /// 播放器设置 · 双击手势模式
  ///
  /// In zh, this message translates to:
  /// **'双击暂停/播放'**
  String get playerDoubleTapPause;

  /// No description provided for @playerDoubleTapSeek.
  ///
  /// In zh, this message translates to:
  /// **'双击左退右进'**
  String get playerDoubleTapSeek;

  /// No description provided for @playerDoubleTapMixed.
  ///
  /// In zh, this message translates to:
  /// **'混合模式'**
  String get playerDoubleTapMixed;

  /// No description provided for @playerOrientationPortrait.
  ///
  /// In zh, this message translates to:
  /// **'锁定竖屏'**
  String get playerOrientationPortrait;

  /// No description provided for @playerOrientationLandscape.
  ///
  /// In zh, this message translates to:
  /// **'锁定横屏'**
  String get playerOrientationLandscape;

  /// 播放器 · 画面比例（4:3 / 16:9 两个比例项不自造文案，保持原样）
  ///
  /// In zh, this message translates to:
  /// **'拉伸'**
  String get playerVideoFitFill;

  /// No description provided for @playerVideoFitCover.
  ///
  /// In zh, this message translates to:
  /// **'裁剪'**
  String get playerVideoFitCover;

  /// No description provided for @playerVideoFitFitWidth.
  ///
  /// In zh, this message translates to:
  /// **'等宽'**
  String get playerVideoFitFitWidth;

  /// No description provided for @playerVideoFitFitHeight.
  ///
  /// In zh, this message translates to:
  /// **'等高'**
  String get playerVideoFitFitHeight;

  /// No description provided for @playerVideoFitNone.
  ///
  /// In zh, this message translates to:
  /// **'原始'**
  String get playerVideoFitNone;

  /// No description provided for @playerVideoFitScaleDown.
  ///
  /// In zh, this message translates to:
  /// **'限制'**
  String get playerVideoFitScaleDown;

  /// 播放器顶栏可自定义按钮动作名
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get playerActionSubtitle;

  /// No description provided for @playerActionAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get playerActionAudio;

  /// No description provided for @playerActionAspect.
  ///
  /// In zh, this message translates to:
  /// **'比例'**
  String get playerActionAspect;

  /// No description provided for @playerActionDecode.
  ///
  /// In zh, this message translates to:
  /// **'解码'**
  String get playerActionDecode;

  /// No description provided for @playerActionChapter.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get playerActionChapter;

  /// No description provided for @playerActionCast.
  ///
  /// In zh, this message translates to:
  /// **'投屏'**
  String get playerActionCast;

  /// No description provided for @playerActionPip.
  ///
  /// In zh, this message translates to:
  /// **'画中画'**
  String get playerActionPip;

  /// No description provided for @playerActionListen.
  ///
  /// In zh, this message translates to:
  /// **'听视频'**
  String get playerActionListen;

  /// No description provided for @playerActionLoop.
  ///
  /// In zh, this message translates to:
  /// **'循环播放'**
  String get playerActionLoop;

  /// No description provided for @playerActionIntroOutro.
  ///
  /// In zh, this message translates to:
  /// **'片头片尾'**
  String get playerActionIntroOutro;

  /// No description provided for @playerActionDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'播放诊断'**
  String get playerActionDiagnostics;

  /// No description provided for @playerActionEqualizer.
  ///
  /// In zh, this message translates to:
  /// **'音频均衡器'**
  String get playerActionEqualizer;

  /// 通用：排序维度 / 字段名（多处复用，同一句中文只留一个键）
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get commonName;

  /// No description provided for @commonDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get commonDate;

  /// No description provided for @commonSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get commonSize;

  /// No description provided for @commonCount.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get commonCount;

  /// No description provided for @commonDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get commonDuration;

  /// No description provided for @commonAscending.
  ///
  /// In zh, this message translates to:
  /// **'升序'**
  String get commonAscending;

  /// No description provided for @commonDescending.
  ///
  /// In zh, this message translates to:
  /// **'降序'**
  String get commonDescending;

  /// No description provided for @commonPath.
  ///
  /// In zh, this message translates to:
  /// **'路径'**
  String get commonPath;

  /// No description provided for @commonResolution.
  ///
  /// In zh, this message translates to:
  /// **'分辨率'**
  String get commonResolution;

  /// No description provided for @commonProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度'**
  String get commonProgress;

  /// No description provided for @commonSubtitleIndicator.
  ///
  /// In zh, this message translates to:
  /// **'字幕指示器'**
  String get commonSubtitleIndicator;

  /// No description provided for @commonFrameRate.
  ///
  /// In zh, this message translates to:
  /// **'帧率'**
  String get commonFrameRate;

  /// No description provided for @commonFullName.
  ///
  /// In zh, this message translates to:
  /// **'完整名称'**
  String get commonFullName;

  /// 首页视图模式
  ///
  /// In zh, this message translates to:
  /// **'树状模式'**
  String get viewModeTree;

  /// No description provided for @viewModeList.
  ///
  /// In zh, this message translates to:
  /// **'列表模式'**
  String get viewModeList;

  /// 超分 · 质量档（名称 + 说明）
  ///
  /// In zh, this message translates to:
  /// **'流畅'**
  String get superResolutionQualityFast;

  /// No description provided for @superResolutionQualityFastDesc.
  ///
  /// In zh, this message translates to:
  /// **'低 GPU 占用，速度优先'**
  String get superResolutionQualityFastDesc;

  /// No description provided for @superResolutionQualityBalanced.
  ///
  /// In zh, this message translates to:
  /// **'均衡'**
  String get superResolutionQualityBalanced;

  /// No description provided for @superResolutionQualityBalancedDesc.
  ///
  /// In zh, this message translates to:
  /// **'速度与画质平衡，推荐'**
  String get superResolutionQualityBalancedDesc;

  /// No description provided for @superResolutionQualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高清'**
  String get superResolutionQualityHigh;

  /// No description provided for @superResolutionQualityHighDesc.
  ///
  /// In zh, this message translates to:
  /// **'高 GPU 占用，画质最佳'**
  String get superResolutionQualityHighDesc;

  /// No description provided for @superResolutionModeOffDesc.
  ///
  /// In zh, this message translates to:
  /// **'不启用超分辨率，输出原始画面'**
  String get superResolutionModeOffDesc;

  /// No description provided for @superResolutionModeA.
  ///
  /// In zh, this message translates to:
  /// **'模式A'**
  String get superResolutionModeA;

  /// No description provided for @superResolutionModeADesc.
  ///
  /// In zh, this message translates to:
  /// **'优化 1080p 动画\n高模糊度、重采样伪影'**
  String get superResolutionModeADesc;

  /// No description provided for @superResolutionModeB.
  ///
  /// In zh, this message translates to:
  /// **'模式B'**
  String get superResolutionModeB;

  /// No description provided for @superResolutionModeBDesc.
  ///
  /// In zh, this message translates to:
  /// **'优化 720p 动画\n低模糊度、下采样振铃'**
  String get superResolutionModeBDesc;

  /// No description provided for @superResolutionModeC.
  ///
  /// In zh, this message translates to:
  /// **'模式C'**
  String get superResolutionModeC;

  /// No description provided for @superResolutionModeCDesc.
  ///
  /// In zh, this message translates to:
  /// **'优化 480p 动画\n最高 PSNR、低感知质量'**
  String get superResolutionModeCDesc;

  /// No description provided for @superResolutionModeAPlus.
  ///
  /// In zh, this message translates to:
  /// **'模式A+'**
  String get superResolutionModeAPlus;

  /// No description provided for @superResolutionModeAPlusDesc.
  ///
  /// In zh, this message translates to:
  /// **'A+A 双段放大\n最高感知质量，更强的线条重建（较慢）'**
  String get superResolutionModeAPlusDesc;

  /// No description provided for @superResolutionModeBPlus.
  ///
  /// In zh, this message translates to:
  /// **'模式B+'**
  String get superResolutionModeBPlus;

  /// No description provided for @superResolutionModeBPlusDesc.
  ///
  /// In zh, this message translates to:
  /// **'B+B 双段放大\n高感知质量，更好的 720p 效果（较慢）'**
  String get superResolutionModeBPlusDesc;

  /// No description provided for @superResolutionModeCPlus.
  ///
  /// In zh, this message translates to:
  /// **'模式C+'**
  String get superResolutionModeCPlus;

  /// No description provided for @superResolutionModeCPlusDesc.
  ///
  /// In zh, this message translates to:
  /// **'C+A 双段放大\n略高感知质量，改进的 480p 效果（较慢）'**
  String get superResolutionModeCPlusDesc;

  /// No description provided for @decodeModeAutoSafeDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动选择安全硬解'**
  String get decodeModeAutoSafeDesc;

  /// No description provided for @decodeModeHwCopy.
  ///
  /// In zh, this message translates to:
  /// **'硬解'**
  String get decodeModeHwCopy;

  /// No description provided for @decodeModeHwCopyDesc.
  ///
  /// In zh, this message translates to:
  /// **'强制硬解，兼容字幕与超分'**
  String get decodeModeHwCopyDesc;

  /// No description provided for @decodeModeHwPlus.
  ///
  /// In zh, this message translates to:
  /// **'硬解+'**
  String get decodeModeHwPlus;

  /// No description provided for @decodeModeHwPlusDesc.
  ///
  /// In zh, this message translates to:
  /// **'直通优先，失败自动回退'**
  String get decodeModeHwPlusDesc;

  /// No description provided for @decodeModeSw.
  ///
  /// In zh, this message translates to:
  /// **'软解'**
  String get decodeModeSw;

  /// No description provided for @decodeModeSwDesc.
  ///
  /// In zh, this message translates to:
  /// **'纯 CPU 解码'**
  String get decodeModeSwDesc;

  /// 解码性能预设（名称 + 说明）
  ///
  /// In zh, this message translates to:
  /// **'快速'**
  String get decodePresetFast;

  /// No description provided for @decodePresetFastDesc.
  ///
  /// In zh, this message translates to:
  /// **'性能优先'**
  String get decodePresetFastDesc;

  /// No description provided for @decodePresetStandardDesc.
  ///
  /// In zh, this message translates to:
  /// **'标准配置'**
  String get decodePresetStandardDesc;

  /// No description provided for @decodePresetHighQuality.
  ///
  /// In zh, this message translates to:
  /// **'高质量'**
  String get decodePresetHighQuality;

  /// No description provided for @decodePresetHighQualityDesc.
  ///
  /// In zh, this message translates to:
  /// **'画质优先'**
  String get decodePresetHighQualityDesc;

  /// No description provided for @decodePresetGpuHq.
  ///
  /// In zh, this message translates to:
  /// **'GPU 高质量'**
  String get decodePresetGpuHq;

  /// No description provided for @decodePresetGpuHqDesc.
  ///
  /// In zh, this message translates to:
  /// **'高画质渲染'**
  String get decodePresetGpuHqDesc;

  /// No description provided for @decodePresetLowLatency.
  ///
  /// In zh, this message translates to:
  /// **'低延迟'**
  String get decodePresetLowLatency;

  /// No description provided for @decodePresetLowLatencyDesc.
  ///
  /// In zh, this message translates to:
  /// **'减少缓冲'**
  String get decodePresetLowLatencyDesc;

  /// No description provided for @decodePresetSwFast.
  ///
  /// In zh, this message translates to:
  /// **'软解快速'**
  String get decodePresetSwFast;

  /// No description provided for @decodePresetSwFastDesc.
  ///
  /// In zh, this message translates to:
  /// **'软解加速'**
  String get decodePresetSwFastDesc;

  /// 章节跳段类型胶囊文案
  ///
  /// In zh, this message translates to:
  /// **'跳过片头'**
  String get chapterSkipIntro;

  /// No description provided for @chapterSkipRecap.
  ///
  /// In zh, this message translates to:
  /// **'跳过前情提要'**
  String get chapterSkipRecap;

  /// No description provided for @chapterSkipOutro.
  ///
  /// In zh, this message translates to:
  /// **'跳过片尾'**
  String get chapterSkipOutro;

  /// No description provided for @chapterSkipCredits.
  ///
  /// In zh, this message translates to:
  /// **'跳过制作人员'**
  String get chapterSkipCredits;

  /// No description provided for @chapterSkipColdOpen.
  ///
  /// In zh, this message translates to:
  /// **'跳过正片前段'**
  String get chapterSkipColdOpen;

  /// No description provided for @chapterSkipPreview.
  ///
  /// In zh, this message translates to:
  /// **'跳过下集预告'**
  String get chapterSkipPreview;

  /// 播放列表排序胶囊
  ///
  /// In zh, this message translates to:
  /// **'名称升序'**
  String get playlistSortNameAsc;

  /// No description provided for @playlistSortNameDesc.
  ///
  /// In zh, this message translates to:
  /// **'名称降序'**
  String get playlistSortNameDesc;

  /// No description provided for @playlistSortDateAsc.
  ///
  /// In zh, this message translates to:
  /// **'日期升序'**
  String get playlistSortDateAsc;

  /// No description provided for @playlistSortDateDesc.
  ///
  /// In zh, this message translates to:
  /// **'日期降序'**
  String get playlistSortDateDesc;

  /// No description provided for @subtitleAlignLeft.
  ///
  /// In zh, this message translates to:
  /// **'左对齐'**
  String get subtitleAlignLeft;

  /// No description provided for @subtitleAlignRight.
  ///
  /// In zh, this message translates to:
  /// **'右对齐'**
  String get subtitleAlignRight;

  /// No description provided for @subtitleBorderOutline.
  ///
  /// In zh, this message translates to:
  /// **'描边'**
  String get subtitleBorderOutline;

  /// No description provided for @subtitleBorderBox.
  ///
  /// In zh, this message translates to:
  /// **'背景框'**
  String get subtitleBorderBox;

  /// 字幕颜色预设名（按 hex 取；同一颜色多处复用同一个键）
  ///
  /// In zh, this message translates to:
  /// **'白色'**
  String get subtitlePresetWhite;

  /// No description provided for @subtitlePresetBlack.
  ///
  /// In zh, this message translates to:
  /// **'黑色'**
  String get subtitlePresetBlack;

  /// No description provided for @subtitlePresetTranslucentBlack.
  ///
  /// In zh, this message translates to:
  /// **'半透明黑'**
  String get subtitlePresetTranslucentBlack;

  /// No description provided for @subtitlePresetOpaqueBlack.
  ///
  /// In zh, this message translates to:
  /// **'纯黑'**
  String get subtitlePresetOpaqueBlack;

  /// No description provided for @subtitlePresetTranslucentWhite.
  ///
  /// In zh, this message translates to:
  /// **'半透明白'**
  String get subtitlePresetTranslucentWhite;

  /// No description provided for @subtitlePresetTranslucentBlue.
  ///
  /// In zh, this message translates to:
  /// **'半透明蓝'**
  String get subtitlePresetTranslucentBlue;

  /// 外挂轨道标记（字幕/音轨标签行共用，同一句中文只留一个键）
  ///
  /// In zh, this message translates to:
  /// **'外挂'**
  String get commonExternalTag;

  /// 通用：自动（解码档位 / 音频声道共用）
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get commonAuto;

  /// 音频声道（mpv audio-channels）
  ///
  /// In zh, this message translates to:
  /// **'安全自动'**
  String get audioChannelAutoSafe;

  /// No description provided for @audioChannelMono.
  ///
  /// In zh, this message translates to:
  /// **'单声道'**
  String get audioChannelMono;

  /// No description provided for @audioChannelStereo.
  ///
  /// In zh, this message translates to:
  /// **'立体声'**
  String get audioChannelStereo;

  /// No description provided for @audioChannelReverseStereo.
  ///
  /// In zh, this message translates to:
  /// **'反向立体声'**
  String get audioChannelReverseStereo;

  /// 音轨既无标题也无语言时的回退名
  ///
  /// In zh, this message translates to:
  /// **'音轨 {id}'**
  String audioTrackFallbackName(String id);

  /// 字幕轨既无标题也无语言时的回退名
  ///
  /// In zh, this message translates to:
  /// **'轨道 {id}'**
  String subtitleTrackFallbackName(String id);

  /// 网络请求超时分级档位名
  ///
  /// In zh, this message translates to:
  /// **'常规 API'**
  String get networkTierApi;

  /// No description provided for @networkTierText.
  ///
  /// In zh, this message translates to:
  /// **'文本响应'**
  String get networkTierText;

  /// No description provided for @networkTierDownload.
  ///
  /// In zh, this message translates to:
  /// **'文件下载'**
  String get networkTierDownload;

  /// No description provided for @networkTierStream.
  ///
  /// In zh, this message translates to:
  /// **'媒体流'**
  String get networkTierStream;

  /// 通用：关闭（超分模式 / 循环模式共用）
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonOff;

  /// 弹幕颜色三态
  ///
  /// In zh, this message translates to:
  /// **'跟随弹幕颜色'**
  String get danmakuColorModeSource;

  /// No description provided for @danmakuColorModeRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机渐变色'**
  String get danmakuColorModeRandom;

  /// No description provided for @danmakuColorModeFixed.
  ///
  /// In zh, this message translates to:
  /// **'指定颜色'**
  String get danmakuColorModeFixed;

  /// 弹幕字体三态
  ///
  /// In zh, this message translates to:
  /// **'跟随系统字体'**
  String get danmakuFontModeFollowSystem;

  /// No description provided for @danmakuFontModeFollowApp.
  ///
  /// In zh, this message translates to:
  /// **'跟随App字体'**
  String get danmakuFontModeFollowApp;

  /// No description provided for @danmakuFontModeCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义字体'**
  String get danmakuFontModeCustom;

  /// 循环播放模式（关闭复用 commonOff）
  ///
  /// In zh, this message translates to:
  /// **'列表循环'**
  String get loopModeLoopAll;

  /// No description provided for @loopModeRepeatOne.
  ///
  /// In zh, this message translates to:
  /// **'单集循环'**
  String get loopModeRepeatOne;

  /// 自定义壁纸缩放模式
  ///
  /// In zh, this message translates to:
  /// **'适应'**
  String get wallpaperScaleFit;

  /// No description provided for @wallpaperScaleFill.
  ///
  /// In zh, this message translates to:
  /// **'填充'**
  String get wallpaperScaleFill;

  /// 影视字幕下载来源（单选互斥）
  ///
  /// In zh, this message translates to:
  /// **'Wyzie 字幕服务'**
  String get subtitleSourceWyzie;

  /// No description provided for @subtitleSourceCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义字幕地址'**
  String get subtitleSourceCustom;

  /// 底部导航项
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navMine.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMine;

  /// 通用：登录
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get commonLogin;

  /// 通用按钮：确定
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// 通用：弹幕（设置组 / 播放器动作名共用）
  ///
  /// In zh, this message translates to:
  /// **'弹幕'**
  String get commonDanmaku;

  /// 通用：下载（设置组名）
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get commonDownload;

  /// 「我的」页账号入口 / 登录页
  ///
  /// In zh, this message translates to:
  /// **'哔哩哔哩账号'**
  String get biliAccount;

  /// 设置页分组标题
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsGroupAppearance;

  /// No description provided for @settingsAppearanceAndFont.
  ///
  /// In zh, this message translates to:
  /// **'外观与字体'**
  String get settingsAppearanceAndFont;

  /// No description provided for @settingsAppearanceAndFontDesc.
  ///
  /// In zh, this message translates to:
  /// **'调整应用外观与字体'**
  String get settingsAppearanceAndFontDesc;

  /// No description provided for @settingsGroupPlayback.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get settingsGroupPlayback;

  /// No description provided for @settingsPlayerSettings.
  ///
  /// In zh, this message translates to:
  /// **'播放设置'**
  String get settingsPlayerSettings;

  /// No description provided for @settingsPlayerSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'调整播放相关设置'**
  String get settingsPlayerSettingsDesc;

  /// No description provided for @settingsPlaybackHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get settingsPlaybackHistory;

  /// No description provided for @settingsPlaybackHistoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看与管理播放历史'**
  String get settingsPlaybackHistoryDesc;

  /// No description provided for @settingsGroupMediaLibrary.
  ///
  /// In zh, this message translates to:
  /// **'媒体库'**
  String get settingsGroupMediaLibrary;

  /// No description provided for @settingsMediaScan.
  ///
  /// In zh, this message translates to:
  /// **'媒体扫描与过滤'**
  String get settingsMediaScan;

  /// No description provided for @settingsMediaScanDesc.
  ///
  /// In zh, this message translates to:
  /// **'扫描规则与文件夹过滤'**
  String get settingsMediaScanDesc;

  /// No description provided for @settingsDanmakuServer.
  ///
  /// In zh, this message translates to:
  /// **'弹幕服务器'**
  String get settingsDanmakuServer;

  /// No description provided for @settingsDanmakuServerDesc.
  ///
  /// In zh, this message translates to:
  /// **'网络弹幕服务器与切集自动匹配'**
  String get settingsDanmakuServerDesc;

  /// No description provided for @settingsDanmakuDownloadDesc.
  ///
  /// In zh, this message translates to:
  /// **'B 站弹幕下载'**
  String get settingsDanmakuDownloadDesc;

  /// No description provided for @settingsVideoDownloadDesc.
  ///
  /// In zh, this message translates to:
  /// **'B 站视频下载'**
  String get settingsVideoDownloadDesc;

  /// No description provided for @settingsSubtitleDownloadDesc.
  ///
  /// In zh, this message translates to:
  /// **'影视字幕下载'**
  String get settingsSubtitleDownloadDesc;

  /// No description provided for @settingsDownloadManagerDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看下载任务进度'**
  String get settingsDownloadManagerDesc;

  /// No description provided for @settingsGroupOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get settingsGroupOther;

  /// No description provided for @settingsDeviceInfo.
  ///
  /// In zh, this message translates to:
  /// **'设备信息'**
  String get settingsDeviceInfo;

  /// No description provided for @settingsDeviceInfoDesc.
  ///
  /// In zh, this message translates to:
  /// **'硬件与编解码能力检测'**
  String get settingsDeviceInfoDesc;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsAboutDesc.
  ///
  /// In zh, this message translates to:
  /// **'版本信息与工具'**
  String get settingsAboutDesc;

  /// 未登录时打开 B 站下载页的提示
  ///
  /// In zh, this message translates to:
  /// **'需要登录哔哩哔哩账号'**
  String get settingsLoginRequired;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get settingsLanguage;

  /// 语言自称，**中英两版内容相同**（不翻译；弹窗与设置页共用）
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageNameZh;

  /// 语言自称，**中英两版内容相同**（不翻译；弹窗与设置页共用）
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// 首启语言弹窗标题：**中英两版内容相同**（刻意双语，让任何用户都看得懂）
  ///
  /// In zh, this message translates to:
  /// **'选择语言 / Choose Language'**
  String get languagePickerTitle;

  /// 外部打开视频失败提示
  ///
  /// In zh, this message translates to:
  /// **'无法打开该视频'**
  String get mainVideoOpenFailed;

  /// 通用：时间
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get commonTime;

  /// 播放设置页：分组标题
  ///
  /// In zh, this message translates to:
  /// **'手势'**
  String get settingsPlayerGroupGesture;

  /// No description provided for @settingsPlayerVolumeSensitivity.
  ///
  /// In zh, this message translates to:
  /// **'音量灵敏度'**
  String get settingsPlayerVolumeSensitivity;

  /// No description provided for @settingsPlayerBrightnessSensitivity.
  ///
  /// In zh, this message translates to:
  /// **'亮度灵敏度'**
  String get settingsPlayerBrightnessSensitivity;

  /// No description provided for @settingsPlayerGroupOrientation.
  ///
  /// In zh, this message translates to:
  /// **'视频方向'**
  String get settingsPlayerGroupOrientation;

  /// No description provided for @settingsPlayerOrientationFollowVideo.
  ///
  /// In zh, this message translates to:
  /// **'跟随视频方向'**
  String get settingsPlayerOrientationFollowVideo;

  /// No description provided for @settingsPlayerOrientationAlwaysPortrait.
  ///
  /// In zh, this message translates to:
  /// **'始终竖屏'**
  String get settingsPlayerOrientationAlwaysPortrait;

  /// No description provided for @settingsPlayerOrientationAlwaysLandscape.
  ///
  /// In zh, this message translates to:
  /// **'始终横屏'**
  String get settingsPlayerOrientationAlwaysLandscape;

  /// No description provided for @settingsPlayerUiFollowGravity.
  ///
  /// In zh, this message translates to:
  /// **'界面跟随重力旋转'**
  String get settingsPlayerUiFollowGravity;

  /// No description provided for @settingsPlayerGroupTopInfo.
  ///
  /// In zh, this message translates to:
  /// **'顶部信息'**
  String get settingsPlayerGroupTopInfo;

  /// No description provided for @settingsPlayerShowTimeDesc.
  ///
  /// In zh, this message translates to:
  /// **'显示当前时间'**
  String get settingsPlayerShowTimeDesc;

  /// No description provided for @settingsPlayerBattery.
  ///
  /// In zh, this message translates to:
  /// **'电量'**
  String get settingsPlayerBattery;

  /// No description provided for @settingsPlayerShowBatteryDesc.
  ///
  /// In zh, this message translates to:
  /// **'显示当前电量'**
  String get settingsPlayerShowBatteryDesc;

  /// No description provided for @settingsPlayerNetSpeed.
  ///
  /// In zh, this message translates to:
  /// **'网速'**
  String get settingsPlayerNetSpeed;

  /// No description provided for @settingsPlayerShowNetSpeedDesc.
  ///
  /// In zh, this message translates to:
  /// **'显示实时网速'**
  String get settingsPlayerShowNetSpeedDesc;

  /// No description provided for @settingsPlayerDataType.
  ///
  /// In zh, this message translates to:
  /// **'数据类型'**
  String get settingsPlayerDataType;

  /// No description provided for @settingsPlayerShowDataTypeDesc.
  ///
  /// In zh, this message translates to:
  /// **'显示 WiFi / 移动数据'**
  String get settingsPlayerShowDataTypeDesc;

  /// No description provided for @settingsPlayerGroupBehavior.
  ///
  /// In zh, this message translates to:
  /// **'播放行为'**
  String get settingsPlayerGroupBehavior;

  /// No description provided for @settingsPlayerPersistentProgressBar.
  ///
  /// In zh, this message translates to:
  /// **'常驻进度线'**
  String get settingsPlayerPersistentProgressBar;

  /// No description provided for @settingsPlayerPersistentProgressBarDesc.
  ///
  /// In zh, this message translates to:
  /// **'隐藏控制层后底部显示细线'**
  String get settingsPlayerPersistentProgressBarDesc;

  /// No description provided for @settingsPlayerChapterProgressBar.
  ///
  /// In zh, this message translates to:
  /// **'显示章节进度条'**
  String get settingsPlayerChapterProgressBar;

  /// No description provided for @settingsPlayerChapterProgressBarDesc.
  ///
  /// In zh, this message translates to:
  /// **'进度条标记章节并显示章节名'**
  String get settingsPlayerChapterProgressBarDesc;

  /// No description provided for @settingsPlayerThumbnailPreview.
  ///
  /// In zh, this message translates to:
  /// **'进度条缩略图'**
  String get settingsPlayerThumbnailPreview;

  /// No description provided for @settingsPlayerThumbnailPreviewDesc.
  ///
  /// In zh, this message translates to:
  /// **'拖动进度条时预览画面'**
  String get settingsPlayerThumbnailPreviewDesc;

  /// No description provided for @settingsPlayerRememberSpeed.
  ///
  /// In zh, this message translates to:
  /// **'记住上次倍速'**
  String get settingsPlayerRememberSpeed;

  /// No description provided for @settingsPlayerRememberSpeedDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动恢复上次倍速'**
  String get settingsPlayerRememberSpeedDesc;

  /// No description provided for @settingsPlayerSaveVolumeToSystem.
  ///
  /// In zh, this message translates to:
  /// **'保存音量到系统'**
  String get settingsPlayerSaveVolumeToSystem;

  /// No description provided for @settingsPlayerSaveVolumeToSystemDesc.
  ///
  /// In zh, this message translates to:
  /// **'退出时把音量写回系统'**
  String get settingsPlayerSaveVolumeToSystemDesc;

  /// No description provided for @settingsPlayerPinchToZoom.
  ///
  /// In zh, this message translates to:
  /// **'双指缩小视频'**
  String get settingsPlayerPinchToZoom;

  /// No description provided for @settingsPlayerPinchToZoomDesc.
  ///
  /// In zh, this message translates to:
  /// **'双指缩放画面'**
  String get settingsPlayerPinchToZoomDesc;

  /// No description provided for @settingsPlayerButtonBackground.
  ///
  /// In zh, this message translates to:
  /// **'按钮背景'**
  String get settingsPlayerButtonBackground;

  /// No description provided for @settingsPlayerButtonBackgroundDesc.
  ///
  /// In zh, this message translates to:
  /// **'为控制按钮加半透明背景'**
  String get settingsPlayerButtonBackgroundDesc;

  /// No description provided for @settingsPlayerAutoNext.
  ///
  /// In zh, this message translates to:
  /// **'自动连播'**
  String get settingsPlayerAutoNext;

  /// No description provided for @settingsPlayerAutoNextDesc.
  ///
  /// In zh, this message translates to:
  /// **'播完自动放下一集'**
  String get settingsPlayerAutoNextDesc;

  /// No description provided for @settingsPlayerAutoExit.
  ///
  /// In zh, this message translates to:
  /// **'播放完毕自动退出'**
  String get settingsPlayerAutoExit;

  /// No description provided for @settingsPlayerAutoExitDesc.
  ///
  /// In zh, this message translates to:
  /// **'最后一个播完自动退出'**
  String get settingsPlayerAutoExitDesc;

  /// No description provided for @settingsPlayerSpeedIndicator.
  ///
  /// In zh, this message translates to:
  /// **'倍速播放指示器'**
  String get settingsPlayerSpeedIndicator;

  /// No description provided for @settingsPlayerSpeedIndicatorDesc.
  ///
  /// In zh, this message translates to:
  /// **'长按时顶部显示倍速提示'**
  String get settingsPlayerSpeedIndicatorDesc;

  /// No description provided for @settingsPlayerUiAnimations.
  ///
  /// In zh, this message translates to:
  /// **'启用播放界面动画'**
  String get settingsPlayerUiAnimations;

  /// No description provided for @settingsPlayerUiAnimationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'控制层与面板的进出场动画'**
  String get settingsPlayerUiAnimationsDesc;

  /// No description provided for @settingsPlayerLockExemptDoubleTap.
  ///
  /// In zh, this message translates to:
  /// **'锁定状态豁免双击'**
  String get settingsPlayerLockExemptDoubleTap;

  /// No description provided for @settingsPlayerLockExemptDoubleTapDesc.
  ///
  /// In zh, this message translates to:
  /// **'启用锁定状态下双击屏幕播放/暂停的功能'**
  String get settingsPlayerLockExemptDoubleTapDesc;

  /// No description provided for @settingsPlayerVolumeBoost.
  ///
  /// In zh, this message translates to:
  /// **'音量增强'**
  String get settingsPlayerVolumeBoost;

  /// No description provided for @settingsPlayerVolumeBoostDesc.
  ///
  /// In zh, this message translates to:
  /// **'系统音量满后继续放大'**
  String get settingsPlayerVolumeBoostDesc;

  /// 播放设置页：分组标题（解码组标题复用 playerActionDecode）
  ///
  /// In zh, this message translates to:
  /// **'已观看进度阈值'**
  String get settingsPlayerWatchThreshold;

  /// No description provided for @settingsPlayerEnableGpuNext.
  ///
  /// In zh, this message translates to:
  /// **'启用 GPU-next'**
  String get settingsPlayerEnableGpuNext;

  /// No description provided for @settingsPlayerGpuNextDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用 libplacebo 新渲染器'**
  String get settingsPlayerGpuNextDesc;

  /// No description provided for @settingsPlayerEnableVulkan.
  ///
  /// In zh, this message translates to:
  /// **'启用 Vulkan'**
  String get settingsPlayerEnableVulkan;

  /// No description provided for @settingsPlayerVulkanDesc.
  ///
  /// In zh, this message translates to:
  /// **'优先使用 Vulkan 渲染'**
  String get settingsPlayerVulkanDesc;

  /// No description provided for @settingsPlayerVulkanNeedsGpuNext.
  ///
  /// In zh, this message translates to:
  /// **'需先启用上方的「GPU-next」：Vulkan 只对 GPU-next 渲染器生效'**
  String get settingsPlayerVulkanNeedsGpuNext;

  /// No description provided for @settingsPlayerRestartHint.
  ///
  /// In zh, this message translates to:
  /// **'切换后需重启播放器（重开视频）生效；'**
  String get settingsPlayerRestartHint;

  /// No description provided for @settingsPlayerNoBlackScreenHint.
  ///
  /// In zh, this message translates to:
  /// **'设备或驱动不支持时会自动回落 OpenGL，不会黑屏'**
  String get settingsPlayerNoBlackScreenHint;

  /// 通用按钮：确定启用（二次确认弹窗）
  ///
  /// In zh, this message translates to:
  /// **'确定启用'**
  String get commonEnable;

  /// 通用按钮：确定开启（二次确认弹窗）
  ///
  /// In zh, this message translates to:
  /// **'确定开启'**
  String get commonTurnOn;

  /// 播放设置：二次确认弹窗（标题 + 正文，正文里的换行在 ARB 写 \n）
  ///
  /// In zh, this message translates to:
  /// **'启用锁定状态豁免双击'**
  String get settingsPlayerLockExemptDialogTitle;

  /// No description provided for @settingsPlayerLockExemptDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'开启后，控制层锁定期间双击屏幕即可暂停/播放。\n\n只豁免这一个手势：左右滑动快进快退、上下滑动音量与亮度、长按倍速在锁定状态下依然不会生效；单击呼出解锁按钮也不受影响。\n\n锁定本是防误触用的，若视频会在口袋/包里误暂停，请保持关闭。'**
  String get settingsPlayerLockExemptDialogBody;

  /// No description provided for @settingsPlayerGravityDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启界面跟随重力旋转'**
  String get settingsPlayerGravityDialogTitle;

  /// No description provided for @settingsPlayerGravityDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'生效前提（两个都要满足）：\n① 手机系统设置里已开启「自动旋转」；\n② 本页「视频方向」设为「自动」。\n\n两个前提满足后，再开启本开关，播放界面的横竖屏才会跟随手机方向（竖起来进竖屏播放页，横过来回横屏播放页）。前提不满足时仍按「视频方向」的设置播放，本开关不生效。\n\n「锁定竖屏 / 锁定横屏」是明确指定的方向，不受本开关影响。'**
  String get settingsPlayerGravityDialogBody;

  /// No description provided for @settingsPlayerGpuNextWarning.
  ///
  /// In zh, this message translates to:
  /// **'启用后超分辨率功能将无法使用；\n可尝试配合软解播放杜比视界视频。\n\n是否继续？'**
  String get settingsPlayerGpuNextWarning;

  /// No description provided for @settingsPlayerVulkanWarning.
  ///
  /// In zh, this message translates to:
  /// **'视频输出将优先使用 Vulkan 渲染，新建的上下文不再限定 OpenGL ES。\n\n若设备或驱动不支持，会自动回落 OpenGL，不会黑屏。\n\n注意：普通内核下 MediaCodec 直通只对 OpenGL 生效，开 Vulkan 后「硬解+」会直接走硬解拷贝（不再尝试直通）。\n\n切换后需重启播放器（重开视频）生效。'**
  String get settingsPlayerVulkanWarning;

  /// 通用单位：秒
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get commonSeconds;

  /// 通用：N 秒（数值 + 单位）
  ///
  /// In zh, this message translates to:
  /// **'{value} 秒'**
  String commonSecondsValue(int value);

  /// 播放设置：长按倍速 / 快进时长 / 已观看阈值 / 增强上限 四个滑杆项
  ///
  /// In zh, this message translates to:
  /// **'长按倍速'**
  String get settingsPlayerLongPressSpeed;

  /// No description provided for @settingsPlayerLongPressSpeedDesc.
  ///
  /// In zh, this message translates to:
  /// **'长按临时倍速，可左右滑动调速'**
  String get settingsPlayerLongPressSpeedDesc;

  /// 快进/快退时长输入框的越界提示
  ///
  /// In zh, this message translates to:
  /// **'1 – {max} 秒'**
  String settingsPlayerSeekRange(int max);

  /// No description provided for @settingsPlayerSeekSeconds.
  ///
  /// In zh, this message translates to:
  /// **'快进/快退时长'**
  String get settingsPlayerSeekSeconds;

  /// No description provided for @settingsPlayerTapValueHint.
  ///
  /// In zh, this message translates to:
  /// **'点击数值可自定义秒数'**
  String get settingsPlayerTapValueHint;

  /// No description provided for @settingsPlayerWatchThresholdTitle.
  ///
  /// In zh, this message translates to:
  /// **'「已观看」进度阈值'**
  String get settingsPlayerWatchThresholdTitle;

  /// No description provided for @settingsPlayerWatchThresholdDesc.
  ///
  /// In zh, this message translates to:
  /// **'进度达到该比例即视为已看完'**
  String get settingsPlayerWatchThresholdDesc;

  /// No description provided for @settingsPlayerBoostCap.
  ///
  /// In zh, this message translates to:
  /// **'增强上限'**
  String get settingsPlayerBoostCap;

  /// 音量增强上限说明（percent = 100 + 上限值）
  ///
  /// In zh, this message translates to:
  /// **'最高增强至 {percent}%音量'**
  String settingsPlayerBoostCapDesc(int percent);

  /// 通用按钮：删除
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// 通用：编辑
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// 通用按钮：添加
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get commonAdd;

  /// 通用按钮：保存
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// 通用：更多操作（菜单 tooltip）
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get commonMoreActions;

  /// 通用：不再提示（二次确认勾选框）
  ///
  /// In zh, this message translates to:
  /// **'不再提示'**
  String get commonDontAskAgain;

  /// 通用按钮：开启（区别于「确定开启」）
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get commonTurnOnShort;

  /// 弹幕服务器页（页面标题复用 settingsDanmakuServer）
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get danmakuServerAdd;

  /// No description provided for @danmakuServerIntro.
  ///
  /// In zh, this message translates to:
  /// **'启用的服务器将同时用于弹幕搜索与自动匹配，搜索结果按各服务器返回顺序实时呈现'**
  String get danmakuServerIntro;

  /// No description provided for @danmakuServerGroupServers.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get danmakuServerGroupServers;

  /// No description provided for @danmakuServerDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get danmakuServerDelete;

  /// No description provided for @danmakuServerDedupe.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果自动去重'**
  String get danmakuServerDedupe;

  /// No description provided for @danmakuServerDedupeOnDesc.
  ///
  /// In zh, this message translates to:
  /// **'重复番剧合并为一条，保留集数最全的'**
  String get danmakuServerDedupeOnDesc;

  /// No description provided for @danmakuServerDedupeOffDesc.
  ///
  /// In zh, this message translates to:
  /// **'每台服务器的结果各自展示，可自行挑选来源'**
  String get danmakuServerDedupeOffDesc;

  /// No description provided for @danmakuServerDedupeDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启搜索结果自动去重？'**
  String get danmakuServerDedupeDialogTitle;

  /// No description provided for @danmakuServerDedupeDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'各服务器返回的结果仍然立刻显示，不会等全部返回。\n同一部番剧只保留一条；如果后续服务器返回的集数更全，会自动替换成更全的那条。\n因此某台服务器的结果可能不单独出现——那不代表它没搜到，而是被去重合并了。'**
  String get danmakuServerDedupeDialogBody;

  /// No description provided for @danmakuServerAutoMatch.
  ///
  /// In zh, this message translates to:
  /// **'切集自动匹配弹幕'**
  String get danmakuServerAutoMatch;

  /// No description provided for @danmakuServerAutoMatchDesc.
  ///
  /// In zh, this message translates to:
  /// **'切集时自动匹配并加载对应集弹幕'**
  String get danmakuServerAutoMatchDesc;

  /// No description provided for @danmakuServerBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置服务器，不可编辑、删除'**
  String get danmakuServerBuiltIn;

  /// No description provided for @danmakuServerEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get danmakuServerEdit;

  /// No description provided for @danmakuServerNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称'**
  String get danmakuServerNameLabel;

  /// No description provided for @danmakuServerNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例：我的服务器'**
  String get danmakuServerNameHint;

  /// No description provided for @danmakuServerUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get danmakuServerUrlLabel;

  /// No description provided for @danmakuServerNoBrowser.
  ///
  /// In zh, this message translates to:
  /// **'未找到可用的浏览器'**
  String get danmakuServerNoBrowser;

  /// No description provided for @danmakuServerHelpLink.
  ///
  /// In zh, this message translates to:
  /// **'如何获取服务器地址'**
  String get danmakuServerHelpLink;

  /// 媒体扫描与过滤页（页面标题复用 settingsMediaScan）
  ///
  /// In zh, this message translates to:
  /// **'扫描规则'**
  String get mediaScanGroupRules;

  /// No description provided for @mediaScanNoMedia.
  ///
  /// In zh, this message translates to:
  /// **'扫描包含 .nomedia 的文件夹'**
  String get mediaScanNoMedia;

  /// No description provided for @mediaScanNoMediaDesc.
  ///
  /// In zh, this message translates to:
  /// **'扫描系统忽略的目录'**
  String get mediaScanNoMediaDesc;

  /// No description provided for @mediaScanHiddenFolders.
  ///
  /// In zh, this message translates to:
  /// **'扫描以 . 开头的隐藏文件夹'**
  String get mediaScanHiddenFolders;

  /// No description provided for @mediaScanHiddenFoldersDesc.
  ///
  /// In zh, this message translates to:
  /// **'扫描隐藏文件'**
  String get mediaScanHiddenFoldersDesc;

  /// No description provided for @mediaScanGroupFilterMode.
  ///
  /// In zh, this message translates to:
  /// **'文件夹过滤模式'**
  String get mediaScanGroupFilterMode;

  /// No description provided for @mediaScanAll.
  ///
  /// In zh, this message translates to:
  /// **'全部扫描'**
  String get mediaScanAll;

  /// No description provided for @mediaScanAllDesc.
  ///
  /// In zh, this message translates to:
  /// **'扫描所有未跳过的文件夹'**
  String get mediaScanAllDesc;

  /// No description provided for @mediaScanBlacklist.
  ///
  /// In zh, this message translates to:
  /// **'黑名单模式'**
  String get mediaScanBlacklist;

  /// No description provided for @mediaScanBlacklistDesc.
  ///
  /// In zh, this message translates to:
  /// **'排除指定文件夹'**
  String get mediaScanBlacklistDesc;

  /// No description provided for @mediaScanWhitelist.
  ///
  /// In zh, this message translates to:
  /// **'白名单模式'**
  String get mediaScanWhitelist;

  /// No description provided for @mediaScanWhitelistDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅扫描指定文件夹'**
  String get mediaScanWhitelistDesc;

  /// No description provided for @mediaScanBlacklistList.
  ///
  /// In zh, this message translates to:
  /// **'黑名单文件夹列表'**
  String get mediaScanBlacklistList;

  /// No description provided for @mediaScanWhitelistList.
  ///
  /// In zh, this message translates to:
  /// **'白名单文件夹列表'**
  String get mediaScanWhitelistList;

  /// No description provided for @mediaScanAddFolder.
  ///
  /// In zh, this message translates to:
  /// **'添加文件夹'**
  String get mediaScanAddFolder;

  /// No description provided for @mediaScanBlacklistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无黑名单文件夹（未排除任何目录）'**
  String get mediaScanBlacklistEmpty;

  /// No description provided for @mediaScanWhitelistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无白名单文件夹（未添加时默认显示全部）'**
  String get mediaScanWhitelistEmpty;

  /// No description provided for @mediaScanNoMediaDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'开启提示'**
  String get mediaScanNoMediaDialogTitle;

  /// No description provided for @mediaScanNoMediaDialogBody.
  ///
  /// In zh, this message translates to:
  /// **'此功能将扫描系统默认忽略的 .nomedia 文件夹。\n\n开启后，某些应用程序的缓存视频、临时文件或表情包也可能被展示在媒体列表中。是否继续？'**
  String get mediaScanNoMediaDialogBody;

  /// No description provided for @mediaScanAddBlacklistFolder.
  ///
  /// In zh, this message translates to:
  /// **'添加黑名单文件夹'**
  String get mediaScanAddBlacklistFolder;

  /// No description provided for @mediaScanAddWhitelistFolder.
  ///
  /// In zh, this message translates to:
  /// **'添加白名单文件夹'**
  String get mediaScanAddWhitelistFolder;

  /// No description provided for @mediaScanPickBlacklistHint.
  ///
  /// In zh, this message translates to:
  /// **'选择要排除的媒体文件夹（点击直接添加）：'**
  String get mediaScanPickBlacklistHint;

  /// No description provided for @mediaScanPickWhitelistHint.
  ///
  /// In zh, this message translates to:
  /// **'选择要仅保留扫描的媒体文件夹（点击直接添加）：'**
  String get mediaScanPickWhitelistHint;

  /// No description provided for @mediaScanNoMoreFolders.
  ///
  /// In zh, this message translates to:
  /// **'未发现更多媒体文件夹'**
  String get mediaScanNoMoreFolders;

  /// 候选文件夹条目副标题：路径 + 视频个数
  ///
  /// In zh, this message translates to:
  /// **'{path}\n{count, plural, other{{count} 个视频}}'**
  String mediaScanFolderItemSubtitle(String path, int count);

  /// No description provided for @mediaScanBrowseOther.
  ///
  /// In zh, this message translates to:
  /// **'浏览设备其他目录...'**
  String get mediaScanBrowseOther;

  /// No description provided for @mediaScanPickFolder.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get mediaScanPickFolder;

  /// No description provided for @mediaScanGoUp.
  ///
  /// In zh, this message translates to:
  /// **'上一级'**
  String get mediaScanGoUp;

  /// No description provided for @mediaScanNoSubfolders.
  ///
  /// In zh, this message translates to:
  /// **'当前目录下无子文件夹'**
  String get mediaScanNoSubfolders;

  /// 自建目录选择器的确认按钮
  ///
  /// In zh, this message translates to:
  /// **'选择当前文件夹 ({name})'**
  String mediaScanPickCurrentFolder(String name);

  /// 错误日志页（设置 → 关于 → 工具 → 错误日志）页面标题
  ///
  /// In zh, this message translates to:
  /// **'错误日志'**
  String get settingsErrorLogTitle;

  /// 错误日志详情页：刷新按钮 tooltip（进入即读最新内容）
  ///
  /// In zh, this message translates to:
  /// **'刷新（实时查看）'**
  String get settingsErrorLogRefreshRealtime;

  /// 错误日志页顶部：日志保存路径（path = 目录绝对路径）
  ///
  /// In zh, this message translates to:
  /// **'日志保存路径：\n{path}'**
  String settingsErrorLogSavePath(String path);

  /// 错误日志页分组标题（count = 日志文件个数）
  ///
  /// In zh, this message translates to:
  /// **'崩溃日志（{count}）'**
  String settingsErrorLogGroupCount(int count);

  /// 错误日志页：列表为空时的占位标题
  ///
  /// In zh, this message translates to:
  /// **'暂无错误日志'**
  String get settingsErrorLogEmpty;

  /// 错误日志页：列表为空时的占位说明
  ///
  /// In zh, this message translates to:
  /// **'应用崩溃时日志会自动记录到这里'**
  String get settingsErrorLogEmptyDesc;

  /// 错误日志：复制日志内容按钮（列表 tooltip 与详情页按钮共用）
  ///
  /// In zh, this message translates to:
  /// **'一键复制'**
  String get settingsErrorLogCopy;

  /// 错误日志：导出日志按钮（列表 tooltip 与详情页按钮共用）
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get settingsErrorLogExport;

  /// 错误日志：复制成功的 toast
  ///
  /// In zh, this message translates to:
  /// **'日志内容已复制到剪贴板'**
  String get settingsErrorLogCopied;

  /// 错误日志：导出失败的 toast
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get settingsErrorLogExportFailed;

  /// 错误日志：导出成功的 toast（path = 导出目标路径）
  ///
  /// In zh, this message translates to:
  /// **'已导出到\n{path}'**
  String settingsErrorLogExportedTo(String path);

  /// 错误日志：删除单个日志的二次确认标题
  ///
  /// In zh, this message translates to:
  /// **'删除日志'**
  String get settingsErrorLogDeleteTitle;

  /// 错误日志：删除成功的 toast
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get settingsErrorLogDeleted;

  /// 错误日志：删除失败的 toast
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get settingsErrorLogDeleteFailed;

  /// 错误日志页底部：清空全部日志按钮
  ///
  /// In zh, this message translates to:
  /// **'清空全部日志'**
  String get settingsErrorLogClearAll;

  /// 错误日志：清空全部日志的二次确认正文（count = 日志文件个数）
  ///
  /// In zh, this message translates to:
  /// **'将删除全部 {count} 个日志文件，此操作不可恢复。'**
  String settingsErrorLogClearAllConfirm(int count);

  /// 错误日志：清空全部成功的 toast
  ///
  /// In zh, this message translates to:
  /// **'已清空全部日志'**
  String get settingsErrorLogClearedAll;

  /// 错误日志：清空全部失败的 toast
  ///
  /// In zh, this message translates to:
  /// **'清空失败'**
  String get settingsErrorLogClearFailed;

  /// App 字体设置页页面标题
  ///
  /// In zh, this message translates to:
  /// **'App字体设置'**
  String get settingsFontTitle;

  /// App 字体设置页顶部：启用自定义字体开关标题
  ///
  /// In zh, this message translates to:
  /// **'启用自定义字体'**
  String get settingsFontEnable;

  /// App 字体设置页：开关已开启时的副标题
  ///
  /// In zh, this message translates to:
  /// **'已开启：使用下方导入的字体'**
  String get settingsFontEnabledDesc;

  /// App 字体设置页：开关已关闭时的副标题
  ///
  /// In zh, this message translates to:
  /// **'已关闭：跟随系统字体'**
  String get settingsFontDisabledDesc;

  /// App 字体设置页：中文字体预览示例文字（三行，换行在 ARB 写 \n；纯展示用）
  ///
  /// In zh, this message translates to:
  /// **'生如夏花之绚烂，死如秋叶之静美。\n我把你的名字写在树叶上，风把它吹走了；\n我把你的名字写在沙滩上，浪把它冲走了；'**
  String get settingsFontPreviewText;

  /// App 字体设置页：预览区下方的说明小字
  ///
  /// In zh, this message translates to:
  /// **'部分字体可能不生效'**
  String get settingsFontPreviewHint;

  /// App 字体设置页：字体分组标题
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get settingsFontGroupFont;

  /// App 字体设置页：字号滑杆标题
  ///
  /// In zh, this message translates to:
  /// **'字体字号'**
  String get settingsFontSizeLabel;

  /// App 字体设置页：字重滑杆标题
  ///
  /// In zh, this message translates to:
  /// **'字体字重'**
  String get settingsFontWeightLabel;

  /// App 字体设置页：字重档位 w100
  ///
  /// In zh, this message translates to:
  /// **'极细'**
  String get settingsFontWeightThin;

  /// App 字体设置页：字重档位 w200
  ///
  /// In zh, this message translates to:
  /// **'很细'**
  String get settingsFontWeightExtraLight;

  /// App 字体设置页：字重档位 w300
  ///
  /// In zh, this message translates to:
  /// **'细'**
  String get settingsFontWeightLight;

  /// App 字体设置页：字重档位 w400
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get settingsFontWeightRegular;

  /// App 字体设置页：字重档位 w500
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get settingsFontWeightMedium;

  /// App 字体设置页：字重档位 w600
  ///
  /// In zh, this message translates to:
  /// **'较粗'**
  String get settingsFontWeightSemiBold;

  /// App 字体设置页：字重档位 w700
  ///
  /// In zh, this message translates to:
  /// **'粗'**
  String get settingsFontWeightBold;

  /// App 字体设置页：字重档位 w800
  ///
  /// In zh, this message translates to:
  /// **'很粗'**
  String get settingsFontWeightExtraBold;

  /// App 字体设置页：字重档位 w900
  ///
  /// In zh, this message translates to:
  /// **'极粗'**
  String get settingsFontWeightBlack;

  /// App 字体设置页：导入字体行标题
  ///
  /// In zh, this message translates to:
  /// **'导入字体'**
  String get settingsFontImport;

  /// App 字体设置页：导入进行中的行标题
  ///
  /// In zh, this message translates to:
  /// **'正在导入...'**
  String get settingsFontImporting;

  /// App 字体设置页：导入行副标题（name = 当前字体文件族名）
  ///
  /// In zh, this message translates to:
  /// **'当前字体：{name}'**
  String settingsFontCurrent(String name);

  /// App 字体设置页：未导入字体时导入行副标题
  ///
  /// In zh, this message translates to:
  /// **'点击选择 .ttf/.otf 字体文件'**
  String get settingsFontPickHint;

  /// App 字体设置页：重新选择字体按钮 tooltip
  ///
  /// In zh, this message translates to:
  /// **'重新选择'**
  String get settingsFontReselect;

  /// App 字体设置页：重置字号与字重按钮
  ///
  /// In zh, this message translates to:
  /// **'重置字号与字重'**
  String get settingsFontReset;

  /// App 字体设置页：导入的字体解析不出族名时的 toast
  ///
  /// In zh, this message translates to:
  /// **'字体解析失败，请更换字体文件'**
  String get settingsFontParseFailed;

  /// App 字体设置页：导入成功的 toast（name = 字体文件族名）
  ///
  /// In zh, this message translates to:
  /// **'已应用字体：{name}'**
  String settingsFontApplied(String name);

  /// 关于页：「信息」分组标题
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get settingsAboutGroupInfo;

  /// 关于页：「工具」分组标题
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get settingsAboutGroupTools;

  /// 关于页：「更新」分组标题
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get settingsAboutGroupUpdate;

  /// 关于页：许可证书入口标题
  ///
  /// In zh, this message translates to:
  /// **'许可证书'**
  String get settingsAboutLicenses;

  /// 关于页：许可证书入口副标题
  ///
  /// In zh, this message translates to:
  /// **'查看本应用使用的全部开源许可'**
  String get settingsAboutLicensesDesc;

  /// 关于页：用户协议入口标题
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get settingsAboutUserAgreement;

  /// 关于页：用户协议入口副标题
  ///
  /// In zh, this message translates to:
  /// **'预览用户服务协议与隐私政策'**
  String get settingsAboutUserAgreementDesc;

  /// 关于页：缓存管理入口标题
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get settingsAboutCacheManagement;

  /// 关于页：缓存管理入口副标题
  ///
  /// In zh, this message translates to:
  /// **'查看与清除各类缓存'**
  String get settingsAboutCacheManagementDesc;

  /// 关于页：错误日志入口副标题
  ///
  /// In zh, this message translates to:
  /// **'查看 / 导出 / 复制崩溃日志'**
  String get settingsAboutErrorLogDesc;

  /// 关于页：手动检查更新项标题
  ///
  /// In zh, this message translates to:
  /// **'手动检查更新'**
  String get settingsAboutCheckUpdate;

  /// 关于页：手动检查更新项副标题
  ///
  /// In zh, this message translates to:
  /// **'检查是否有新版本'**
  String get settingsAboutCheckUpdateDesc;

  /// 关于页：自动检查更新项标题
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get settingsAboutAutoCheckUpdate;

  /// 关于页：自动检查更新项副标题
  ///
  /// In zh, this message translates to:
  /// **'启动后自动检查新版本'**
  String get settingsAboutAutoCheckUpdateDesc;

  /// 关于页：邮件反馈的默认主题
  ///
  /// In zh, this message translates to:
  /// **'播放器使用反馈'**
  String get settingsAboutFeedbackSubject;

  /// 关于页：跳转邮件失败时的 toast
  ///
  /// In zh, this message translates to:
  /// **'未找到可用的邮件应用'**
  String get settingsAboutNoEmailApp;

  /// 关于页：GitHub 地址未配置时的 toast
  ///
  /// In zh, this message translates to:
  /// **'GitHub 主页地址待接入'**
  String get settingsAboutGithubPending;

  /// 关于页：链接打不开时的 toast
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get settingsAboutCannotOpenLink;

  /// 关于页：手动检查更新时没有新版本的 toast
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get settingsAboutUpToDate;

  /// 关于页：手动检查更新失败的 toast
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败，请稍后重试'**
  String get settingsAboutCheckUpdateFailed;

  /// 关于页：顶部卡片邮箱按钮的 tooltip
  ///
  /// In zh, this message translates to:
  /// **'发送使用反馈'**
  String get settingsAboutSendFeedback;

  /// 关于页：构建信息还没读完时版本胶囊的占位文案
  ///
  /// In zh, this message translates to:
  /// **'读取中'**
  String get settingsAboutAppNameLoading;

  /// 许可证书页：列表分组标题
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get settingsLicenseOpenSource;

  /// 许可证书页：没有收集到任何许可时的空态
  ///
  /// In zh, this message translates to:
  /// **'暂无许可信息'**
  String get settingsLicenseEmpty;

  /// 许可证书页：版本号还没读到时胶囊的占位文案
  ///
  /// In zh, this message translates to:
  /// **'版本读取中'**
  String get settingsLicenseVersionLoading;

  /// 许可证书页：头部卡片的许可包数量胶囊
  ///
  /// In zh, this message translates to:
  /// **'{count} 项许可'**
  String settingsLicenseCount(int count);

  /// 许可证书页：某个包包含的许可段落数（列表行副标题与详情页摘要卡片共用）
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{1 个许可段落} other{{count} 个许可段落}}'**
  String settingsLicenseParagraphCount(int count);

  /// 许可证书详情页：复制按钮 tooltip
  ///
  /// In zh, this message translates to:
  /// **'复制许可文本'**
  String get settingsLicenseCopy;

  /// 许可证书详情页：复制成功的 toast
  ///
  /// In zh, this message translates to:
  /// **'许可文本已复制'**
  String get settingsLicenseCopied;

  /// 许可证书页：许可收集失败的提示
  ///
  /// In zh, this message translates to:
  /// **'许可信息加载失败'**
  String get settingsLicenseLoadFailed;

  /// 外观设置子页：主题模式分组标题
  ///
  /// In zh, this message translates to:
  /// **'外观模式'**
  String get settingsAppearanceMode;

  /// 外观设置子页：主题色分组标题
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get settingsAppearanceThemeColor;

  /// 外观设置子页：调色板风格分组标题
  ///
  /// In zh, this message translates to:
  /// **'调色板风格'**
  String get settingsAppearancePaletteVariant;

  /// 外观设置子页：App 字体设置项副标题
  ///
  /// In zh, this message translates to:
  /// **'自定义全局字体'**
  String get settingsAppearanceCustomFontDesc;

  /// 外观设置子页：壁纸分组标题
  ///
  /// In zh, this message translates to:
  /// **'壁纸'**
  String get settingsAppearanceGroupWallpaper;

  /// 外观设置子页：主题色网格第 24 格（取系统壁纸主色）
  ///
  /// In zh, this message translates to:
  /// **'动态色'**
  String get settingsAppearanceDynamicColor;

  /// 外观设置子页：Android 12 以下点动态色的 toast
  ///
  /// In zh, this message translates to:
  /// **'安卓版本过低，不支持该功能'**
  String get settingsAppearanceSdkTooLow;

  /// 外观设置子页：取不到壁纸主色时的 toast
  ///
  /// In zh, this message translates to:
  /// **'无法读取壁纸颜色'**
  String get settingsAppearanceReadWallpaperFailed;

  /// 外观设置子页：自定义选色弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'自定义主题色'**
  String get settingsAppearanceCustomColorTitle;

  /// 外观设置子页：选壁纸时系统没有可用图片选择器的 toast
  ///
  /// In zh, this message translates to:
  /// **'这台设备没有可用的系统图片选择器'**
  String get settingsAppearanceNoImagePicker;

  /// 外观设置子页：壁纸卡片标题
  ///
  /// In zh, this message translates to:
  /// **'自定义壁纸'**
  String get settingsAppearanceWallpaperTitle;

  /// 外观设置子页：已设置壁纸时的说明
  ///
  /// In zh, this message translates to:
  /// **'壁纸显示在页面内容与顶部栏之后'**
  String get settingsAppearanceWallpaperActiveDesc;

  /// 外观设置子页：未设置壁纸时的说明
  ///
  /// In zh, this message translates to:
  /// **'选一张图片，铺在页面内容与顶部栏之后'**
  String get settingsAppearanceWallpaperPickDesc;

  /// 外观设置子页：已有壁纸时的选择按钮
  ///
  /// In zh, this message translates to:
  /// **'替换壁纸'**
  String get settingsAppearanceReplaceWallpaper;

  /// 外观设置子页：没有壁纸时的选择按钮
  ///
  /// In zh, this message translates to:
  /// **'选择壁纸'**
  String get settingsAppearanceChooseWallpaper;

  /// 外观设置子页：进入壁纸编辑页的按钮
  ///
  /// In zh, this message translates to:
  /// **'调整'**
  String get settingsAppearanceAdjustWallpaper;

  /// 解码器详情页：基本信息分组标题
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get settingsDecoderBasicInfo;

  /// 解码器详情页：MIME 类型字段名
  ///
  /// In zh, this message translates to:
  /// **'MIME 类型'**
  String get settingsDecoderMimeType;

  /// 解码器详情页：规范名字段名
  ///
  /// In zh, this message translates to:
  /// **'规范名'**
  String get settingsDecoderCanonicalName;

  /// 解码器详情页：编解码器类型字段名
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get settingsDecoderType;

  /// 解码器详情页：类型为视频时的取值
  ///
  /// In zh, this message translates to:
  /// **'视频解码器'**
  String get settingsDecoderVideoCodec;

  /// 解码器详情页：类型为音频时的取值
  ///
  /// In zh, this message translates to:
  /// **'音频解码器'**
  String get settingsDecoderAudioCodec;

  /// 解码器详情页：加速方式字段名
  ///
  /// In zh, this message translates to:
  /// **'加速方式'**
  String get settingsDecoderAcceleration;

  /// 解码器详情页：硬件解码时的取值
  ///
  /// In zh, this message translates to:
  /// **'硬件加速'**
  String get settingsDecoderHardwareAcceleration;

  /// 解码器详情页：软件解码时的取值
  ///
  /// In zh, this message translates to:
  /// **'软件'**
  String get settingsDecoderSoftware;

  /// 解码器详情页：别名字段名
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get settingsDecoderAlias;

  /// 解码器详情页：是 / 否布尔字段的肯定取值
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get settingsDecoderYes;

  /// 解码器详情页：码率范围字段名
  ///
  /// In zh, this message translates to:
  /// **'码率范围'**
  String get settingsDecoderBitrateRange;

  /// 解码器详情页：分辨率与能力分组标题
  ///
  /// In zh, this message translates to:
  /// **'分辨率与能力'**
  String get settingsDecoderResolutionCapability;

  /// 解码器详情页：最大分辨率字段名
  ///
  /// In zh, this message translates to:
  /// **'最大分辨率'**
  String get settingsDecoderMaxResolution;

  /// 解码器详情页：最小分辨率字段名
  ///
  /// In zh, this message translates to:
  /// **'最小分辨率'**
  String get settingsDecoderMinResolution;

  /// 解码器详情页：对齐字段名
  ///
  /// In zh, this message translates to:
  /// **'对齐'**
  String get settingsDecoderAlignment;

  /// 解码器详情页：最大实例数字段名
  ///
  /// In zh, this message translates to:
  /// **'最大实例数'**
  String get settingsDecoderMaxInstances;

  /// 解码器详情页：音频能力分组标题
  ///
  /// In zh, this message translates to:
  /// **'音频能力'**
  String get settingsDecoderAudioCapability;

  /// 解码器详情页：最大声道数字段名
  ///
  /// In zh, this message translates to:
  /// **'最大声道数'**
  String get settingsDecoderMaxChannels;

  /// 解码器详情页：硬件特性胶囊分组标题
  ///
  /// In zh, this message translates to:
  /// **'硬件特性'**
  String get settingsDecoderHardwareFeatures;

  /// 解码器详情页：色彩格式胶囊分组标题
  ///
  /// In zh, this message translates to:
  /// **'色彩格式'**
  String get settingsDecoderColorFormats;

  /// 解码器详情页：supported profiles / levels 胶囊分组标题
  ///
  /// In zh, this message translates to:
  /// **'支持的 Profile / Level'**
  String get settingsDecoderProfiles;

  /// 缓存管理页：缓存类别分组标题
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get settingsCacheGroupTitle;

  /// 缓存管理页：缓存大小尚未读出时的占位文字
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get settingsCacheReading;

  /// 缓存管理页：单类清除确认弹窗标题（label = 缓存类别名）
  ///
  /// In zh, this message translates to:
  /// **'清除{label}'**
  String settingsCacheClearCategoryTitle(String label);

  /// 缓存管理页：单类清除确认弹窗正文（label = 缓存类别名；size = 已格式化的大小）
  ///
  /// In zh, this message translates to:
  /// **'将删除「{label}」缓存（{size}），确定？'**
  String settingsCacheClearCategoryBody(String label, String size);

  /// 缓存管理页：单类清除成功的 toast（label = 缓存类别名）
  ///
  /// In zh, this message translates to:
  /// **'已清除{label}'**
  String settingsCacheCategoryCleared(String label);

  /// 缓存管理页：清除失败的 toast（单类与一键清除共用）
  ///
  /// In zh, this message translates to:
  /// **'清除失败'**
  String get settingsCacheClearFailed;

  /// 缓存管理页：一键清除的首次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'清除所有缓存'**
  String get settingsCacheClearAllTitle;

  /// 缓存管理页：一键清除的首次确认弹窗正文（size = 已格式化的总大小；两条类别名为举例，与 service 层 CacheCategory.label 同串）
  ///
  /// In zh, this message translates to:
  /// **'将删除全部缓存（当前共 {size}）：\n{items}\n\n此操作不可恢复。'**
  String settingsCacheClearAllBody(String size, String items);

  /// 缓存管理页：一键清除的二次确认弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'再次确认'**
  String get settingsCacheConfirmAgainTitle;

  /// 缓存管理页：一键清除的二次确认弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有缓存吗？'**
  String get settingsCacheConfirmAgainBody;

  /// 缓存管理页：一键清除成功的 toast
  ///
  /// In zh, this message translates to:
  /// **'已清除全部缓存'**
  String get settingsCacheAllCleared;

  /// 缓存管理页：一键清除按钮（size = 已格式化的总大小）
  ///
  /// In zh, this message translates to:
  /// **'一键清除所有缓存（{size}）'**
  String settingsCacheClearAllButton(String size);

  /// 缓存管理页：底部说明文字
  ///
  /// In zh, this message translates to:
  /// **'列表封面缩略图会在下次扫描时重新生成；进度条缩略图为纯内存缓存，随播放页退出自动清空，不占用存储。'**
  String get settingsCacheFooterNote;

  /// 通用按钮：重试（原 settingsLicenseRetry 归并到此）
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// 通用：视频（解码器清单筛选胶囊等）
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get commonVideo;

  /// 通用：全部
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// 设备信息页（页面标题复用 settingsDeviceInfo；硬解/软解复用 decodeModeHwCopy/decodeModeSw，音频复用 playerActionAudio）
  ///
  /// In zh, this message translates to:
  /// **'不支持'**
  String get settingsDeviceUnsupported;

  /// No description provided for @settingsDeviceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知设备'**
  String get settingsDeviceUnknown;

  /// No description provided for @settingsDeviceHdrCapability.
  ///
  /// In zh, this message translates to:
  /// **'屏幕 HDR 能力'**
  String get settingsDeviceHdrCapability;

  /// No description provided for @settingsDeviceHdrUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前屏幕不支持 HDR（或系统未报告 HDR 能力）'**
  String get settingsDeviceHdrUnsupported;

  /// No description provided for @settingsDeviceKeyVideoEncoders.
  ///
  /// In zh, this message translates to:
  /// **'关键视频编码器'**
  String get settingsDeviceKeyVideoEncoders;

  /// No description provided for @settingsDeviceDecoderList.
  ///
  /// In zh, this message translates to:
  /// **'解码器清单'**
  String get settingsDeviceDecoderList;

  /// 解码器清单标题右侧的统计
  ///
  /// In zh, this message translates to:
  /// **'硬解 {hw} · 软解 {sw} · 视频 {video} · 音频 {audio}'**
  String settingsDeviceDecoderSummary(int hw, int sw, int video, int audio);

  /// No description provided for @settingsDeviceSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索解码器（名称 / MIME / 格式 / Profile）'**
  String get settingsDeviceSearchHint;

  /// No description provided for @settingsDeviceNoMatchingDecoder.
  ///
  /// In zh, this message translates to:
  /// **'无匹配的解码器'**
  String get settingsDeviceNoMatchingDecoder;

  /// 解码器声道数标签
  ///
  /// In zh, this message translates to:
  /// **'{count} 声道'**
  String settingsDeviceChannels(int count);

  /// No description provided for @settingsDeviceCapabilityError.
  ///
  /// In zh, this message translates to:
  /// **'无法读取设备能力（可能为不支持的原生通道）'**
  String get settingsDeviceCapabilityError;

  /// 通用按钮：清除（历史记录 / 壁纸等）
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get commonClear;

  /// 通用按钮：重置
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get commonReset;

  /// 通用：居中（字幕对齐 / 壁纸位置）
  ///
  /// In zh, this message translates to:
  /// **'居中'**
  String get commonCenter;

  /// 播放历史页（页面标题复用 settingsPlaybackHistory）
  ///
  /// In zh, this message translates to:
  /// **'清除历史记录'**
  String get settingsHistoryClearAllTitle;

  /// No description provided for @settingsHistoryClearAllBodyWithProgress.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除全部播放历史吗？\n\n同时会清除全部播放进度（含「已看完」标记），此操作不可恢复。'**
  String get settingsHistoryClearAllBodyWithProgress;

  /// No description provided for @settingsHistoryClearAllBody.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除全部播放历史吗？此操作不可恢复。'**
  String get settingsHistoryClearAllBody;

  /// No description provided for @settingsHistoryClearAllTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清除全部历史'**
  String get settingsHistoryClearAllTooltip;

  /// No description provided for @settingsHistoryEnabled.
  ///
  /// In zh, this message translates to:
  /// **'播放历史记录'**
  String get settingsHistoryEnabled;

  /// No description provided for @settingsHistoryEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭后不再记录新的播放'**
  String get settingsHistoryEnabledDesc;

  /// No description provided for @settingsHistoryClearProgressOnDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除历史时清除进度'**
  String get settingsHistoryClearProgressOnDelete;

  /// No description provided for @settingsHistoryClearProgressOnDeleteDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭时两套数据互相独立'**
  String get settingsHistoryClearProgressOnDeleteDesc;

  /// No description provided for @settingsHistoryClearProgressOnDesc.
  ///
  /// In zh, this message translates to:
  /// **'开启后，删除历史记录会同时清除该视频的播放进度'**
  String get settingsHistoryClearProgressOnDesc;

  /// No description provided for @settingsHistoryClearProgressBlocked.
  ///
  /// In zh, this message translates to:
  /// **'需先开启上方的「播放历史记录」；关闭时不记录历史，但播放进度会一直保留'**
  String get settingsHistoryClearProgressBlocked;

  /// No description provided for @settingsHistoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放历史'**
  String get settingsHistoryEmpty;

  /// No description provided for @settingsHistoryEmptyDisabled.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放历史（记录已关闭）'**
  String get settingsHistoryEmptyDisabled;

  /// No description provided for @settingsHistoryDeleteEntryWithProgress.
  ///
  /// In zh, this message translates to:
  /// **'删除该条记录（同时清除播放进度）'**
  String get settingsHistoryDeleteEntryWithProgress;

  /// No description provided for @settingsHistoryDeleteEntry.
  ///
  /// In zh, this message translates to:
  /// **'删除该条记录'**
  String get settingsHistoryDeleteEntry;

  /// 壁纸编辑页（页面标题 + 各滑杆标签）
  ///
  /// In zh, this message translates to:
  /// **'无法保存壁纸，请重新选择图片'**
  String get settingsWallpaperSaveFailed;

  /// No description provided for @settingsWallpaperAdjustTitle.
  ///
  /// In zh, this message translates to:
  /// **'调整壁纸'**
  String get settingsWallpaperAdjustTitle;

  /// No description provided for @settingsWallpaperSave.
  ///
  /// In zh, this message translates to:
  /// **'保存壁纸'**
  String get settingsWallpaperSave;

  /// No description provided for @settingsWallpaperDragHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动以调整位置，双指捏合以缩放。'**
  String get settingsWallpaperDragHint;

  /// No description provided for @settingsWallpaperScale.
  ///
  /// In zh, this message translates to:
  /// **'缩放'**
  String get settingsWallpaperScale;

  /// No description provided for @settingsWallpaperOffsetX.
  ///
  /// In zh, this message translates to:
  /// **'水平位置'**
  String get settingsWallpaperOffsetX;

  /// No description provided for @settingsWallpaperOpacity.
  ///
  /// In zh, this message translates to:
  /// **'透明度'**
  String get settingsWallpaperOpacity;

  /// No description provided for @settingsWallpaperImageUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'图片已不可用，请重新选择'**
  String get settingsWallpaperImageUnavailable;

  /// 通用按钮：返回（播放器顶栏 / 听视频页）
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// 通用按钮：更多（播放器顶栏「更多」面板入口）
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get commonMore;

  /// 通用：播放（播放/暂停按钮、诊断面板分组名）
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get commonPlay;

  /// 通用：暂停（播放/暂停按钮）
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get commonPause;

  /// 通用：播放中（列表当前项标记）
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get commonPlaying;

  /// 通用按钮：搜索
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// 通用按钮：清空（输入框 / 屏蔽词列表）
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get commonClearAll;

  /// 通用：无（数值为 0 时的读数）
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get commonNone;

  /// 通用：未设置（空态读数）
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get commonNotSet;

  /// 通用：自定义（定时关闭预设）
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get commonCustom;

  /// 通用按钮：跳转（弹幕集数跳转）
  ///
  /// In zh, this message translates to:
  /// **'跳转'**
  String get commonJump;

  /// 通用：排序方式（字幕文件选择器）
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get commonSortBy;

  /// 通用按钮：上级目录（字幕文件选择器）
  ///
  /// In zh, this message translates to:
  /// **'上级'**
  String get commonGoUp;

  /// 通用按钮：刷新（字体目录）
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get commonRefresh;

  /// 通用按钮：一键重置（均衡器 / 片头片尾）
  ///
  /// In zh, this message translates to:
  /// **'一键重置'**
  String get commonOneKeyReset;

  /// 通用按钮：恢复默认设置（弹幕设置）
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置'**
  String get commonRestoreDefaults;

  /// 通用：正在加载（字体目录读取中）
  ///
  /// In zh, this message translates to:
  /// **'正在加载...'**
  String get commonLoadingDots;

  /// 通用字段名：标题（诊断面板）
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get commonTitle;

  /// 通用：模糊（字幕文字效果）
  ///
  /// In zh, this message translates to:
  /// **'模糊'**
  String get commonBlur;

  /// 通用：集（弹幕集数跳转输入框后缀）
  ///
  /// In zh, this message translates to:
  /// **'集'**
  String get commonEpisodeUnit;

  /// 播放页提示：自动匹配到并加载了外挂字幕
  ///
  /// In zh, this message translates to:
  /// **'已自动加载字幕：{fileName}'**
  String playerAutoLoadedSubtitle(String fileName);

  /// 播放页提示：自动匹配到并加载了弹幕文件
  ///
  /// In zh, this message translates to:
  /// **'已自动加载弹幕：{fileName}'**
  String playerAutoLoadedDanmaku(String fileName);

  /// 播放页提示：加载弹幕成功（附加来源说明）
  ///
  /// In zh, this message translates to:
  /// **'已加载弹幕：{message}'**
  String playerDanmakuLoaded(String message);

  /// 播放页提示：所选清晰度不可用后自动切换
  ///
  /// In zh, this message translates to:
  /// **'该清晰度不可用，已切换到 {name}'**
  String playerQualityUnavailableSwitched(String name);

  /// 播放页提示：切换清晰度异常
  ///
  /// In zh, this message translates to:
  /// **'切换画质失败：{error}'**
  String playerQualitySwitchFailed(String error);

  /// 播放页提示：截图异常
  ///
  /// In zh, this message translates to:
  /// **'截图失败：{error}'**
  String playerScreenshotFailed(String error);

  /// 播放页提示：截图拿到空数据
  ///
  /// In zh, this message translates to:
  /// **'截图失败：未获取到图像'**
  String get playerScreenshotNoImage;

  /// 播放页提示：截图保存成功
  ///
  /// In zh, this message translates to:
  /// **'已保存到相册'**
  String get playerSavedToGallery;

  /// 播放页提示：截图保存到相册失败
  ///
  /// In zh, this message translates to:
  /// **'截图保存失败：{error}'**
  String playerScreenshotSaveFailed(String error);

  /// 播放器面板：弹幕设置入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'弹幕设置'**
  String get playerDanmakuSettings;

  /// 播放页提示：已跳过片头
  ///
  /// In zh, this message translates to:
  /// **'已跳过片头'**
  String get playerSkippedIntro;

  /// 播放页提示：已跳过片尾
  ///
  /// In zh, this message translates to:
  /// **'已跳过片尾'**
  String get playerSkippedOutro;

  /// 播放页提示：离线时无法切集
  ///
  /// In zh, this message translates to:
  /// **'网络连接不存在，无法切换'**
  String get playerNoNetworkCannotSwitch;

  /// 播放页提示：切集/切换失败
  ///
  /// In zh, this message translates to:
  /// **'切换失败：{error}'**
  String playerSwitchFailed(String error);

  /// 播放页错误卡片：播放地址解析失败
  ///
  /// In zh, this message translates to:
  /// **'解析播放地址失败'**
  String get playerResolveUrlFailed;

  /// 播放页提示：B 站切集失败
  ///
  /// In zh, this message translates to:
  /// **'切集失败：{error}'**
  String playerSwitchEpisodeFailed(String error);

  /// 播放器面板：倍速（横竖屏一致）
  ///
  /// In zh, this message translates to:
  /// **'播放倍速'**
  String get playerPlaybackSpeed;

  /// 播放器：超分辨率（面板标题 / 底栏按钮 / 记忆项）
  ///
  /// In zh, this message translates to:
  /// **'超分辨率'**
  String get playerSuperResolution;

  /// 播放器面板：画面比例
  ///
  /// In zh, this message translates to:
  /// **'画面比例'**
  String get playerAspectRatio;

  /// 播放页提示：该来源不支持投屏
  ///
  /// In zh, this message translates to:
  /// **'暂不支持投屏该来源'**
  String get playerCastUnsupportedSource;

  /// 播放器「编辑控制栏」：未放置区标题
  ///
  /// In zh, this message translates to:
  /// **'未放置的功能'**
  String get playerFeatureNotPlaced;

  /// 播放器「更多」面板：未实现动作的副标题
  ///
  /// In zh, this message translates to:
  /// **'功能即将上线'**
  String get playerFeatureComingSoon;

  /// 播放器：编辑控制栏入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'编辑控制栏'**
  String get playerEditControlBar;

  /// 播放器「编辑控制栏」：已启用区标题
  ///
  /// In zh, this message translates to:
  /// **'已启用（长按拖拽排序）'**
  String get playerActionsEnabledHint;

  /// 播放器「编辑控制栏」：已启用区空态
  ///
  /// In zh, this message translates to:
  /// **'暂无已启用动作，从下方添加'**
  String get playerNoEnabledActions;

  /// 播放器「编辑控制栏」：可添加区标题
  ///
  /// In zh, this message translates to:
  /// **'可添加'**
  String get playerAddable;

  /// 播放器「编辑控制栏」：槽位已满提示
  ///
  /// In zh, this message translates to:
  /// **'{max, plural, other{最多允许放 {max} 个}}'**
  String playerMaxActions(int max);

  /// 播放器「编辑控制栏」：重置按钮
  ///
  /// In zh, this message translates to:
  /// **'重置控制栏'**
  String get playerResetControlBar;

  /// 播放器：网络弹幕（弹幕面板入口 / 面板标题）
  ///
  /// In zh, this message translates to:
  /// **'网络弹幕'**
  String get playerDanmakuNetwork;

  /// 播放器：弹幕加载失败（错误卡片标题）
  ///
  /// In zh, this message translates to:
  /// **'弹幕加载失败'**
  String get playerDanmakuLoadFailed;

  /// 播放器：网络弹幕匹配中
  ///
  /// In zh, this message translates to:
  /// **'正在匹配弹幕，请稍候…'**
  String get playerDanmakuMatching;

  /// 播放器：网络弹幕无匹配结果
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的弹幕'**
  String get playerDanmakuNoMatch;

  /// 播放器：选择弹幕匹配结果弹窗
  ///
  /// In zh, this message translates to:
  /// **'选择匹配结果'**
  String get playerDanmakuPickMatch;

  /// 播放页提示：设备不支持画中画
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持画中画'**
  String get playerPipUnsupported;

  /// 播放页提示：进入画中画异常
  ///
  /// In zh, this message translates to:
  /// **'进入画中画失败'**
  String get playerPipFailed;

  /// 播放器：播放列表（面板标题 / 底栏按钮）
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playerPlaylist;

  /// 播放器：锁定控制层（按钮语义）
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get playerLock;

  /// 播放器：解锁控制层（按钮语义）
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get playerUnlock;

  /// 播放器：截图按钮语义
  ///
  /// In zh, this message translates to:
  /// **'截图'**
  String get playerScreenshot;

  /// 播放器：缩放后还原画面胶囊
  ///
  /// In zh, this message translates to:
  /// **'还原画面'**
  String get playerRestoreView;

  /// 播放器音轨面板：音轨分组标题
  ///
  /// In zh, this message translates to:
  /// **'音轨'**
  String get playerAudioTrack;

  /// 播放器音轨面板：无音轨空态
  ///
  /// In zh, this message translates to:
  /// **'当前视频没有音轨，可在下方导入外部音轨'**
  String get playerNoAudioTrackHint;

  /// 播放器音轨面板：外部音轨分组
  ///
  /// In zh, this message translates to:
  /// **'外部音轨'**
  String get playerExternalAudioTrack;

  /// 播放器音轨面板：导入外部音轨入口
  ///
  /// In zh, this message translates to:
  /// **'导入外部音轨'**
  String get playerImportExternalAudioTrack;

  /// 播放器音轨面板：外部音轨临时生效说明
  ///
  /// In zh, this message translates to:
  /// **'临时生效，退出播放后不保留'**
  String get playerTempEffectHint;

  /// 播放器音轨面板：音频声道
  ///
  /// In zh, this message translates to:
  /// **'音频声道'**
  String get playerAudioChannel;

  /// 播放器音轨面板：音频处理分组
  ///
  /// In zh, this message translates to:
  /// **'音频处理'**
  String get playerAudioProcessing;

  /// 播放器音轨面板：音量标准化开关
  ///
  /// In zh, this message translates to:
  /// **'音量标准化'**
  String get playerVolumeNormalize;

  /// 播放器音轨面板：动态范围压缩开关
  ///
  /// In zh, this message translates to:
  /// **'动态范围压缩'**
  String get playerDynamicRangeCompress;

  /// 播放器音轨面板：选择音频文件
  ///
  /// In zh, this message translates to:
  /// **'选择音频文件'**
  String get playerPickAudioFile;

  /// 播放器音轨面板：导入成功提示
  ///
  /// In zh, this message translates to:
  /// **'已导入外部音轨'**
  String get playerExternalAudioImported;

  /// 播放器：导入外挂音轨/字幕失败提示
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请检查文件格式'**
  String get playerImportFailedCheckFormat;

  /// 播放器音轨面板：移除外部音轨按钮
  ///
  /// In zh, this message translates to:
  /// **'移除已导入的音轨'**
  String get playerRemoveAudioTrack;

  /// 听视频：倍速面板标题
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get audioPlaybackSpeed;

  /// 听视频：循环模式（关闭）
  ///
  /// In zh, this message translates to:
  /// **'循环关闭'**
  String get audioRepeatOff;

  /// 听视频：循环模式（单曲循环）；列表循环复用 loopModeLoopAll
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get audioRepeatSingle;

  /// 听视频：定时关闭
  ///
  /// In zh, this message translates to:
  /// **'定时关闭'**
  String get audioSleepTimer;

  /// 听视频：定时关闭（播完当前曲目）
  ///
  /// In zh, this message translates to:
  /// **'播完当前'**
  String get audioSleepEndOfTrack;

  /// 听视频：定时关闭（播完当前）说明
  ///
  /// In zh, this message translates to:
  /// **'将在当前曲目播放结束后停止'**
  String get audioSleepEndOfTrackHint;

  /// 听视频：定时关闭剩余时间
  ///
  /// In zh, this message translates to:
  /// **'剩余 {time}'**
  String audioSleepRemaining(String time);

  /// 听视频：自定义定时关闭弹窗
  ///
  /// In zh, this message translates to:
  /// **'自定义定时关闭'**
  String get audioSleepCustomTitle;

  /// 听视频：定时关闭分钟档位（15 / 30 / 60 / 自定义输入）
  ///
  /// In zh, this message translates to:
  /// **'{minutes, plural, other{{minutes} 分钟}}'**
  String audioSleepMinutes(int minutes);

  /// 听视频：随机播放
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get audioShuffle;

  /// 听视频：播放列表面板标题（带曲目数）
  ///
  /// In zh, this message translates to:
  /// **'播放列表（{count}）'**
  String playerPlaylistWithCount(int count);

  /// 播放器均衡器面板：总开关
  ///
  /// In zh, this message translates to:
  /// **'启用均衡器'**
  String get playerEqualizerEnable;

  /// 播放器均衡器面板：总开关说明
  ///
  /// In zh, this message translates to:
  /// **'调节频段增益、低音增强和虚拟环绕'**
  String get playerEqualizerDesc;

  /// 播放器：预设（均衡器 / 倍速面板分组标题）
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get playerPreset;

  /// 播放器均衡器面板：频段调节分组
  ///
  /// In zh, this message translates to:
  /// **'频段调节'**
  String get playerEqualizerBands;

  /// 播放器均衡器面板：低音增强
  ///
  /// In zh, this message translates to:
  /// **'低音增强'**
  String get playerEqualizerBass;

  /// 播放器均衡器面板：虚拟环绕
  ///
  /// In zh, this message translates to:
  /// **'虚拟环绕'**
  String get playerEqualizerSurround;

  /// 播放器 B 站剧集面板：空态
  ///
  /// In zh, this message translates to:
  /// **'没有获取到剧集列表'**
  String get playerBiliNoEpisodes;

  /// 播放器 B 站剧集面板：总集数
  ///
  /// In zh, this message translates to:
  /// **'{total, plural, other{共 {total} 集}}'**
  String playerBiliTotalEpisodes(int total);

  /// 播放器 B 站剧集面板：当前集 / 总集数
  ///
  /// In zh, this message translates to:
  /// **'第 {current} 集 / 共 {total, plural, other{{total} 集}}'**
  String playerBiliCurrentOfTotal(int current, int total);

  /// 播放器 B 站剧集面板：限免集标记
  ///
  /// In zh, this message translates to:
  /// **'限免'**
  String get playerBiliFreeLimited;

  /// 播放器 B 站剧集面板：预告标记
  ///
  /// In zh, this message translates to:
  /// **'预告'**
  String get playerBiliPreview;

  /// 播放器底栏：下一集按钮
  ///
  /// In zh, this message translates to:
  /// **'下一集'**
  String get playerNextEpisode;

  /// 播放器底栏：选择投屏设备
  ///
  /// In zh, this message translates to:
  /// **'选择屏幕'**
  String get playerCastSelectScreen;

  /// 播放器手势提示：双击左侧快退
  ///
  /// In zh, this message translates to:
  /// **'快退 {seconds} 秒'**
  String playerSeekBackSeconds(int seconds);

  /// 播放器手势提示：双击右侧快进
  ///
  /// In zh, this message translates to:
  /// **'快进 {seconds} 秒'**
  String playerSeekForwardSeconds(int seconds);

  /// 播放器章节面板：标题
  ///
  /// In zh, this message translates to:
  /// **'章节跳段'**
  String get playerChapterPanelTitle;

  /// 播放器章节面板：空态
  ///
  /// In zh, this message translates to:
  /// **'当前视频无章节信息'**
  String get playerNoChapters;

  /// 播放器章节面板：章节总数
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{共 {count} 章}}'**
  String playerChapterCount(int count);

  /// 播放器章节跳段面板：自动跳过开关
  ///
  /// In zh, this message translates to:
  /// **'自动跳过'**
  String get playerChapterSkipAuto;

  /// 播放器章节跳段面板：自动跳过说明
  ///
  /// In zh, this message translates to:
  /// **'进入对应片段时自动跳到片段结束；关闭则仅弹出跳过胶囊'**
  String get playerChapterSkipAutoDesc;

  /// 播放器章节跳段面板：自定义关键词分组
  ///
  /// In zh, this message translates to:
  /// **'自定义关键词'**
  String get playerChapterSkipCustomKeywords;

  /// 播放器章节跳段面板：关键词输入说明
  ///
  /// In zh, this message translates to:
  /// **'按章节标题匹配，支持逗号 / 分号 / 换行分隔'**
  String get playerChapterSkipKeywordsHint;

  /// 播放器章节跳段面板：片头关键词
  ///
  /// In zh, this message translates to:
  /// **'片头关键词'**
  String get playerIntroKeywords;

  /// 播放器章节跳段面板：片头关键词提示
  ///
  /// In zh, this message translates to:
  /// **'如 ap、op、开场'**
  String get playerIntroKeywordsHint;

  /// 播放器章节跳段面板：片尾关键词
  ///
  /// In zh, this message translates to:
  /// **'片尾关键词'**
  String get playerOutroKeywords;

  /// 播放器章节跳段面板：片尾关键词提示
  ///
  /// In zh, this message translates to:
  /// **'如 ed、ending、结尾'**
  String get playerOutroKeywordsHint;

  /// 播放器章节跳段面板：关键词归属说明（多行拼接）
  ///
  /// In zh, this message translates to:
  /// **'关键词归属由你填入的位置决定：填进「片头关键词」即判为片头、填进「片尾关键词」即判为片尾；同一标题命中多类时按固定优先级（前情提要 > 正片前段 > 制作人员 > 下集预告 > 片尾 > 片头）取一类。'**
  String get playerChapterSkipKeywordOwnerHint;

  /// 播放器弹幕按钮：关闭弹幕
  ///
  /// In zh, this message translates to:
  /// **'关闭弹幕'**
  String get playerDanmakuClose;

  /// 播放器弹幕按钮：打开弹幕
  ///
  /// In zh, this message translates to:
  /// **'打开弹幕'**
  String get playerDanmakuOpen;

  /// 播放器弹幕集数跳转：非法输入提示
  ///
  /// In zh, this message translates to:
  /// **'请输入集数（数字）'**
  String get playerEpisodeInvalidInput;

  /// 播放器弹幕集数跳转：集数不存在
  ///
  /// In zh, this message translates to:
  /// **'没有第 {number} 集'**
  String playerEpisodeNotFound(int number);

  /// 播放器弹幕集数面板：某台服务器的集数
  ///
  /// In zh, this message translates to:
  /// **'{total, plural, other{共 {total} 集 · 来自 {server}}}'**
  String playerEpisodeTotalFromServer(int total, String server);

  /// 播放器弹幕集数跳转：输入行前缀
  ///
  /// In zh, this message translates to:
  /// **'跳至第'**
  String get playerJumpToEpisode;

  /// 播放器弹幕集数跳转：输入框标签
  ///
  /// In zh, this message translates to:
  /// **'集数'**
  String get playerEpisodeNumber;

  /// 播放器网络弹幕面板：搜索框提示
  ///
  /// In zh, this message translates to:
  /// **'输入番剧名称'**
  String get playerDanmakuNetworkSearchHint;

  /// 播放器网络弹幕面板：停止搜索
  ///
  /// In zh, this message translates to:
  /// **'停止搜索'**
  String get playerDanmakuStopSearch;

  /// 播放器网络弹幕面板：搜索结果数（部）
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 部}}'**
  String playerDanmakuResultCountUnit(int count);

  /// 播放器网络弹幕面板：搜索中状态
  ///
  /// In zh, this message translates to:
  /// **'正在搜索 · 已获得 {count, plural, other{{count} 部}}'**
  String playerDanmakuSearchingWithCount(int count);

  /// 播放器网络弹幕面板：已停止搜索状态
  ///
  /// In zh, this message translates to:
  /// **'已停止搜索 · 共 {count, plural, other{{count} 部}}'**
  String playerDanmakuSearchStoppedCount(int count);

  /// 播放器网络弹幕面板：部分服务器失败
  ///
  /// In zh, this message translates to:
  /// **'部分服务器搜索失败：{errors}'**
  String playerDanmakuPartialServerFailed(String errors);

  /// 播放器网络弹幕面板：搜索中
  ///
  /// In zh, this message translates to:
  /// **'搜索中…'**
  String get playerDanmakuSearching;

  /// 播放器网络弹幕面板：空态提示
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索网络弹幕'**
  String get playerDanmakuNetworkInputHint;

  /// 播放器网络弹幕面板：番剧集数（集）
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 集}}'**
  String playerEpisodeCountUnit(int count);

  /// 播放器弹幕面板：本地弹幕入口
  ///
  /// In zh, this message translates to:
  /// **'本地弹幕'**
  String get playerDanmakuLocal;

  /// 播放器弹幕面板：网络弹幕未实现提示
  ///
  /// In zh, this message translates to:
  /// **'「网络弹幕」功能即将上线'**
  String get playerDanmakuNetworkComingSoon;

  /// 播放器弹幕面板：自动匹配入口
  ///
  /// In zh, this message translates to:
  /// **'自动匹配'**
  String get playerDanmakuAutoMatch;

  /// 播放器弹幕面板：自动匹配未实现提示
  ///
  /// In zh, this message translates to:
  /// **'「自动匹配」功能即将上线'**
  String get playerDanmakuAutoMatchComingSoon;

  /// 播放器弹幕面板：选择文件
  ///
  /// In zh, this message translates to:
  /// **'选择弹幕文件'**
  String get playerPickDanmakuFile;

  /// 播放器弹幕面板：本地弹幕导入成功
  ///
  /// In zh, this message translates to:
  /// **'已加载本地弹幕（{count, plural, other{{count} 条}}）'**
  String playerLocalDanmakuLoaded(int count);

  /// 播放器弹幕面板：导入失败提示
  ///
  /// In zh, this message translates to:
  /// **'弹幕加载失败，请检查文件格式'**
  String get playerDanmakuLoadFailedCheckFormat;

  /// 播放器弹幕设置：弹幕样式分组
  ///
  /// In zh, this message translates to:
  /// **'弹幕样式'**
  String get playerDanmakuStyle;

  /// 播放器弹幕设置：弹幕字号
  ///
  /// In zh, this message translates to:
  /// **'弹幕字号'**
  String get playerDanmakuFontSize;

  /// 播放器弹幕设置：弹幕速度
  ///
  /// In zh, this message translates to:
  /// **'弹幕速度'**
  String get playerDanmakuSpeed;

  /// 播放器弹幕设置：弹幕速度说明
  ///
  /// In zh, this message translates to:
  /// **'数值越小弹幕越快'**
  String get playerDanmakuSpeedDesc;

  /// 播放器：描边粗细（弹幕设置 / 字幕样式）
  ///
  /// In zh, this message translates to:
  /// **'描边粗细'**
  String get playerStrokeWidth;

  /// 播放器弹幕设置：不透明度
  ///
  /// In zh, this message translates to:
  /// **'不透明度'**
  String get playerOpacity;

  /// 播放器弹幕设置：弹幕配置分组
  ///
  /// In zh, this message translates to:
  /// **'弹幕配置'**
  String get playerDanmakuConfig;

  /// 播放器弹幕设置：显示区域
  ///
  /// In zh, this message translates to:
  /// **'显示区域'**
  String get playerDanmakuDisplayArea;

  /// 播放器弹幕设置：弹幕行高
  ///
  /// In zh, this message translates to:
  /// **'弹幕行高'**
  String get playerDanmakuLineHeight;

  /// 播放器弹幕设置：顶部弹幕
  ///
  /// In zh, this message translates to:
  /// **'顶部弹幕'**
  String get playerDanmakuTop;

  /// 播放器弹幕设置：底部弹幕
  ///
  /// In zh, this message translates to:
  /// **'底部弹幕'**
  String get playerDanmakuBottom;

  /// 播放器弹幕设置：滚动弹幕
  ///
  /// In zh, this message translates to:
  /// **'滚动弹幕'**
  String get playerDanmakuScroll;

  /// 播放器弹幕设置：海量弹幕
  ///
  /// In zh, this message translates to:
  /// **'海量弹幕'**
  String get playerDanmakuMassive;

  /// 播放器弹幕设置：海量弹幕说明
  ///
  /// In zh, this message translates to:
  /// **'轨道占满时叠加绘制，弹幕过多不再丢弃'**
  String get playerDanmakuMassiveDesc;

  /// 播放器弹幕设置：弹幕去重
  ///
  /// In zh, this message translates to:
  /// **'弹幕去重'**
  String get playerDanmakuDedupe;

  /// 播放器弹幕设置：弹幕去重说明
  ///
  /// In zh, this message translates to:
  /// **'相同时间下相同弹幕合并为一条'**
  String get playerDanmakuDedupeDesc;

  /// 播放器弹幕设置：弹幕合并
  ///
  /// In zh, this message translates to:
  /// **'弹幕合并'**
  String get playerDanmakuMerge;

  /// 播放器弹幕设置：弹幕合并说明
  ///
  /// In zh, this message translates to:
  /// **'不同时间内相同弹幕合并且计数'**
  String get playerDanmakuMergeDesc;

  /// 播放器弹幕设置：弹幕偏移分组
  ///
  /// In zh, this message translates to:
  /// **'弹幕偏移'**
  String get playerDanmakuOffset;

  /// 播放器弹幕设置：时间轴偏移
  ///
  /// In zh, this message translates to:
  /// **'时间轴偏移'**
  String get playerDanmakuTimelineOffset;

  /// 播放器弹幕设置：时间轴提前 1 秒
  ///
  /// In zh, this message translates to:
  /// **'提前 1 秒'**
  String get playerDanmakuAdvanceOneSecond;

  /// 播放器弹幕设置：时间轴延后 1 秒
  ///
  /// In zh, this message translates to:
  /// **'延后 1 秒'**
  String get playerDanmakuDelayOneSecond;

  /// 播放器弹幕设置：重置偏移
  ///
  /// In zh, this message translates to:
  /// **'重置偏移'**
  String get playerDanmakuResetOffset;

  /// 播放器弹幕设置：弹幕字体分组
  ///
  /// In zh, this message translates to:
  /// **'弹幕字体'**
  String get playerDanmakuFont;

  /// 播放器弹幕设置：跟随弹幕颜色说明
  ///
  /// In zh, this message translates to:
  /// **'保留弹幕自带颜色（含会员渐变彩色）'**
  String get danmakuColorModeSourceDesc;

  /// 播放器弹幕设置：随机渐变色说明
  ///
  /// In zh, this message translates to:
  /// **'忽略文件颜色，按色轮逐条随机着色'**
  String get danmakuColorModeRandomDesc;

  /// 播放器弹幕设置：指定颜色说明
  ///
  /// In zh, this message translates to:
  /// **'弹幕从下面已选颜色里随机取色'**
  String get danmakuColorModeFixedDesc;

  /// 播放器弹幕设置：调色板上限提示
  ///
  /// In zh, this message translates to:
  /// **'{max, plural, other{最多选 {max} 种颜色}}'**
  String playerDanmakuPaletteMaxHint(int max);

  /// 播放器弹幕设置：调色板标题
  ///
  /// In zh, this message translates to:
  /// **'弹幕颜色（可多选，随机使用）'**
  String get playerDanmakuPaletteTitle;

  /// 播放器弹幕设置：重复添加颜色提示
  ///
  /// In zh, this message translates to:
  /// **'该颜色已在调色板中'**
  String get playerDanmakuColorExists;

  /// 播放器弹幕设置：调色板已满提示
  ///
  /// In zh, this message translates to:
  /// **'{max, plural, other{已选满 {max} 种}}'**
  String playerDanmakuPaletteFull(int max);

  /// 播放器弹幕设置：添加到调色板按钮
  ///
  /// In zh, this message translates to:
  /// **'添加到调色板'**
  String get playerDanmakuAddToPalette;

  /// 播放器弹幕设置：已选颜色数
  ///
  /// In zh, this message translates to:
  /// **'已选 {selected}/{max, plural, other{{max} 种}}'**
  String playerDanmakuPaletteSelected(int selected, int max);

  /// 播放器弹幕设置：屏蔽词分组
  ///
  /// In zh, this message translates to:
  /// **'屏蔽词'**
  String get playerDanmakuBlockWords;

  /// 播放器弹幕设置：屏蔽词输入提示
  ///
  /// In zh, this message translates to:
  /// **'输入要屏蔽的关键词'**
  String get playerDanmakuBlockWordsHint;

  /// 播放器：字体目录导入成功提示
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 个字体文件，共 {total, plural, other{{total} 种字体}}'**
  String playerFontsImported(int count, int total);

  /// 播放器：选择字体目录
  ///
  /// In zh, this message translates to:
  /// **'选择字体目录'**
  String get playerPickFontDir;

  /// 播放器：导入字体目录提示
  ///
  /// In zh, this message translates to:
  /// **'点击导入包含 .ttf/.otf 字体的目录'**
  String get playerFontDirImportHint;

  /// 播放器：字体目录已加载数量
  ///
  /// In zh, this message translates to:
  /// **'已加载 {count, plural, other{{count} 种字体}}'**
  String playerFontsLoaded(int count);

  /// 播放器弹幕设置：选择字体
  ///
  /// In zh, this message translates to:
  /// **'选择字体'**
  String get playerPickFont;

  /// 播放器解码面板：重启提示标题
  ///
  /// In zh, this message translates to:
  /// **'需重启应用'**
  String get playerRestartRequired;

  /// 播放器解码面板：重启提示正文
  ///
  /// In zh, this message translates to:
  /// **'解码配置已修改，重启应用后生效。\n\n是否立即重启？'**
  String get playerDecodeRestartBody;

  /// 播放器解码面板：稍后重启
  ///
  /// In zh, this message translates to:
  /// **'稍后重启'**
  String get playerRestartLater;

  /// 播放器解码面板：立即重启
  ///
  /// In zh, this message translates to:
  /// **'立即重启'**
  String get playerRestartNow;

  /// 播放器解码面板：解码预设分组
  ///
  /// In zh, this message translates to:
  /// **'解码预设'**
  String get playerDecodePreset;

  /// 播放器解码面板：解码预设分组说明
  ///
  /// In zh, this message translates to:
  /// **'切换后需重启应用生效，可选立即重启'**
  String get playerDecodePresetDesc;

  /// 播放器解码面板：硬解+ 档说明
  ///
  /// In zh, this message translates to:
  /// **'「硬解+」直通不可用时由内核依次回退硬解 / 软解'**
  String get playerDecodeHwPlusDesc;

  /// 播放器诊断面板：容器格式
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get playerDiagnosticsContainer;

  /// 播放器诊断面板：音频编码
  ///
  /// In zh, this message translates to:
  /// **'音频编码'**
  String get playerDiagnosticsAudioCodec;

  /// 播放器诊断面板：视频输出
  ///
  /// In zh, this message translates to:
  /// **'视频输出'**
  String get playerDiagnosticsVideoOutput;

  /// 播放器诊断面板：同步方式
  ///
  /// In zh, this message translates to:
  /// **'同步方式'**
  String get playerDiagnosticsSyncMode;

  /// 播放器诊断面板：像素格式
  ///
  /// In zh, this message translates to:
  /// **'像素格式'**
  String get playerDiagnosticsPixelFormat;

  /// 播放器诊断面板：容器帧率
  ///
  /// In zh, this message translates to:
  /// **'容器帧率'**
  String get playerDiagnosticsContainerFps;

  /// 播放器诊断面板：实际帧率
  ///
  /// In zh, this message translates to:
  /// **'实际帧率'**
  String get playerDiagnosticsActualFps;

  /// 播放器诊断面板：视频码率
  ///
  /// In zh, this message translates to:
  /// **'视频码率'**
  String get playerDiagnosticsVideoBitrate;

  /// 播放器诊断面板：音频参数
  ///
  /// In zh, this message translates to:
  /// **'音频参数'**
  String get playerDiagnosticsAudioParams;

  /// 播放器诊断面板：音频码率
  ///
  /// In zh, this message translates to:
  /// **'音频码率'**
  String get playerDiagnosticsAudioBitrate;

  /// 播放器诊断面板：音画同步
  ///
  /// In zh, this message translates to:
  /// **'音画同步'**
  String get playerDiagnosticsAvSync;

  /// 播放器诊断面板：缓存与丢帧分组
  ///
  /// In zh, this message translates to:
  /// **'缓存与丢帧'**
  String get playerDiagnosticsCacheGroup;

  /// 播放器诊断面板：缓冲时长
  ///
  /// In zh, this message translates to:
  /// **'缓冲时长'**
  String get playerDiagnosticsBufferDuration;

  /// 播放器诊断面板：可播时长
  ///
  /// In zh, this message translates to:
  /// **'可播时长'**
  String get playerDiagnosticsPlayableDuration;

  /// 播放器诊断面板：缓存占用
  ///
  /// In zh, this message translates to:
  /// **'缓存占用'**
  String get playerDiagnosticsCacheUsage;

  /// 播放器诊断面板：下行速率
  ///
  /// In zh, this message translates to:
  /// **'下行速率'**
  String get playerDiagnosticsDownlinkRate;

  /// 播放器诊断面板：丢帧
  ///
  /// In zh, this message translates to:
  /// **'丢帧'**
  String get playerDiagnosticsDroppedFrames;

  /// 播放器诊断面板：解码丢帧
  ///
  /// In zh, this message translates to:
  /// **'解码丢帧'**
  String get playerDiagnosticsDecodeDropped;

  /// 播放器诊断面板：延迟帧
  ///
  /// In zh, this message translates to:
  /// **'延迟帧'**
  String get playerDiagnosticsDelayedFrames;

  /// 播放器诊断面板：刷新说明
  ///
  /// In zh, this message translates to:
  /// **'每秒自动刷新 · 数据来自 mpv 运行时属性'**
  String get playerDiagnosticsAutoRefreshHint;

  /// 播放器诊断面板：全部读取失败警告
  ///
  /// In zh, this message translates to:
  /// **'无法读取播放器属性（播放器可能未就绪或已卡住）'**
  String get playerDiagnosticsReadFailed;

  /// 播放器诊断面板：部分属性读取失败警告
  ///
  /// In zh, this message translates to:
  /// **'读取失败：{keys}（显示的是上一次成功值）'**
  String playerDiagnosticsFailedValue(String keys);

  /// 播放器诊断面板：部分属性读取失败警告（其余折成计数）
  ///
  /// In zh, this message translates to:
  /// **'读取失败：{keys} 等 {count} 项（显示的是上一次成功值）'**
  String playerDiagnosticsFailedValueMore(String keys, int count);

  /// 播放器片头片尾面板：片头范围
  ///
  /// In zh, this message translates to:
  /// **'片头范围'**
  String get playerIntroRange;

  /// 播放器片头片尾面板：片尾范围
  ///
  /// In zh, this message translates to:
  /// **'片尾范围'**
  String get playerOutroRange;

  /// 播放器片头片尾面板：范围设置说明
  ///
  /// In zh, this message translates to:
  /// **'拖动或输入设置时间，可按需调整上方范围'**
  String get playerRangeHint;

  /// 播放器片头片尾面板：设为当前时间
  ///
  /// In zh, this message translates to:
  /// **'设为当前时间'**
  String get playerSetToCurrentTime;

  /// 播放器片头片尾面板：设为当前剩余时间
  ///
  /// In zh, this message translates to:
  /// **'设为当前剩余时间'**
  String get playerSetToRemainingTime;

  /// 播放器片头片尾面板：总开关
  ///
  /// In zh, this message translates to:
  /// **'启用跳过片头片尾'**
  String get playerEnableIntroOutroSkip;

  /// 播放器片头片尾面板：总开关说明
  ///
  /// In zh, this message translates to:
  /// **'通过手动设置秒数来跳过片头片尾'**
  String get playerIntroOutroSkipDesc;

  /// 播放器播放列表面板：空态
  ///
  /// In zh, this message translates to:
  /// **'当前文件夹没有其他视频'**
  String get playerNoOtherVideos;

  /// 播放器画质面板：空态
  ///
  /// In zh, this message translates to:
  /// **'暂无可用画质'**
  String get playerNoQuality;

  /// 播放器画质面板：切换说明
  ///
  /// In zh, this message translates to:
  /// **'切换画质会重开播放并保持进度'**
  String get playerQualitySwitchHint;

  /// 播放器进度恢复胶囊：提示
  ///
  /// In zh, this message translates to:
  /// **'已恢复上次播放进度'**
  String get playerResumeIndicator;

  /// 播放器进度恢复胶囊：重头开始
  ///
  /// In zh, this message translates to:
  /// **'重头开始'**
  String get playerRestartFromBeginning;

  /// 播放器倍速指示器：当前倍速
  ///
  /// In zh, this message translates to:
  /// **'正在 {speed} 倍速播放'**
  String playerSpeedPlaying(String speed);

  /// 播放器倍速指示器：滑动调节说明
  ///
  /// In zh, this message translates to:
  /// **'左右滑动可临时调节长按倍数'**
  String get playerSpeedSwipeHint;

  /// 播放器倍速面板：重复添加提示
  ///
  /// In zh, this message translates to:
  /// **'该倍速已在预设中'**
  String get playerSpeedAlreadyInPresets;

  /// 播放器倍速面板：自定义预设上限提示
  ///
  /// In zh, this message translates to:
  /// **'{max, plural, other{自定义预设已达上限（{max} 个）}}'**
  String playerSpeedPresetLimit(int max);

  /// 播放器倍速面板：我的预设分组
  ///
  /// In zh, this message translates to:
  /// **'我的预设'**
  String get playerMyPresets;

  /// 播放器倍速面板：精确调速
  ///
  /// In zh, this message translates to:
  /// **'精确调速'**
  String get playerPreciseSpeed;

  /// 播放器倍速面板：临时应用按钮
  ///
  /// In zh, this message translates to:
  /// **'临时应用'**
  String get playerApplyTemporarily;

  /// 播放器倍速面板：添加到预设
  ///
  /// In zh, this message translates to:
  /// **'添加到预设'**
  String get playerAddToPresets;

  /// 播放器倍速面板：倍速归位（回到 1x）
  ///
  /// In zh, this message translates to:
  /// **'归位'**
  String get playerSpeedReset;

  /// 播放器倍速面板：重置预设
  ///
  /// In zh, this message translates to:
  /// **'重置预设'**
  String get playerResetPresets;

  /// 播放器超分面板：模式
  ///
  /// In zh, this message translates to:
  /// **'模式'**
  String get playerMode;

  /// 播放器超分面板：超分质量
  ///
  /// In zh, this message translates to:
  /// **'超分质量'**
  String get playerSuperResolutionQuality;

  /// 播放器超分面板：记忆超分模式开关
  ///
  /// In zh, this message translates to:
  /// **'记忆超分模式'**
  String get playerRememberSuperResolution;

  /// 播放器超分面板：记忆超分模式说明
  ///
  /// In zh, this message translates to:
  /// **'开启后自动应用上次的超分模式与质量'**
  String get playerRememberSuperResolutionDesc;

  /// 播放器字幕面板：字幕轨道分组
  ///
  /// In zh, this message translates to:
  /// **'字幕轨道'**
  String get playerSubtitleTracks;

  /// 播放器字幕面板：无字幕空态
  ///
  /// In zh, this message translates to:
  /// **'当前视频没有字幕，可在下方导入外挂字幕'**
  String get playerNoSubtitleHint;

  /// 播放器字幕面板：关闭字幕
  ///
  /// In zh, this message translates to:
  /// **'关闭字幕'**
  String get playerSubtitleOff;

  /// 播放器字幕面板：外挂字幕分组
  ///
  /// In zh, this message translates to:
  /// **'外挂字幕'**
  String get playerExternalSubtitle;

  /// 播放器字幕面板：导入外部字幕入口
  ///
  /// In zh, this message translates to:
  /// **'导入外部字幕'**
  String get playerImportExternalSubtitle;

  /// 播放器字幕面板：字幕设置分组
  ///
  /// In zh, this message translates to:
  /// **'字幕设置'**
  String get playerSubtitleSettings;

  /// 播放器字幕面板：字幕延迟入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'字幕延迟'**
  String get playerSubtitleDelay;

  /// 播放器字幕面板：字幕样式入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'字幕样式'**
  String get playerSubtitleStyle;

  /// 播放器字幕面板：字幕杂项入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'字幕杂项'**
  String get playerSubtitleMisc;

  /// 播放器字幕面板：字幕字体入口 / 页标题
  ///
  /// In zh, this message translates to:
  /// **'字幕字体'**
  String get playerSubtitleFont;

  /// 播放器字幕面板：选择字幕文件
  ///
  /// In zh, this message translates to:
  /// **'选择字幕文件'**
  String get playerPickSubtitleFile;

  /// 播放器字幕面板：导入成功提示
  ///
  /// In zh, this message translates to:
  /// **'已导入外挂字幕'**
  String get playerExternalSubtitleImported;

  /// 播放器字幕面板：移除外部字幕按钮
  ///
  /// In zh, this message translates to:
  /// **'移除已导入的字幕'**
  String get playerRemoveSubtitle;

  /// 播放器字幕延迟面板：快捷调整分组
  ///
  /// In zh, this message translates to:
  /// **'快捷调整'**
  String get playerQuickAdjust;

  /// 播放器字幕延迟面板：重置为 0 秒
  ///
  /// In zh, this message translates to:
  /// **'重置为 0 秒'**
  String get playerResetToZeroSeconds;

  /// 播放器字幕样式面板：文字颜色
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get playerTextColor;

  /// 播放器字幕样式面板：描边颜色
  ///
  /// In zh, this message translates to:
  /// **'描边颜色'**
  String get playerStrokeColor;

  /// 播放器字幕样式面板：背景颜色
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get playerBackgroundColor;

  /// 播放器字幕样式面板：背景框大小
  ///
  /// In zh, this message translates to:
  /// **'背景框大小'**
  String get playerBackgroundBoxSize;

  /// 播放器字幕样式面板：文字效果分组
  ///
  /// In zh, this message translates to:
  /// **'文字效果'**
  String get playerTextEffects;

  /// 播放器字幕样式面板：粗体
  ///
  /// In zh, this message translates to:
  /// **'粗体'**
  String get playerBold;

  /// 播放器字幕样式面板：斜体
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get playerItalic;

  /// 播放器字幕样式面板：字间距
  ///
  /// In zh, this message translates to:
  /// **'字间距'**
  String get playerLetterSpacing;

  /// 播放器字幕杂项面板：优先选中文字幕轨
  ///
  /// In zh, this message translates to:
  /// **'优先选中文字幕轨'**
  String get playerPreferChineseSubtitle;

  /// 播放器字幕杂项面板：优先选中文字幕轨说明
  ///
  /// In zh, this message translates to:
  /// **'默认启用中文轨（含「特效/双语」优先）；手动选过的不改'**
  String get playerPreferChineseSubtitleDesc;

  /// 播放器字幕杂项面板：不优先中文时的说明
  ///
  /// In zh, this message translates to:
  /// **'交给内核默认挑选（通常是文件里的第一条）'**
  String get playerSubtitleTrackAutoDesc;

  /// 播放器字幕杂项面板：强制覆盖内嵌样式
  ///
  /// In zh, this message translates to:
  /// **'强制覆盖内嵌样式'**
  String get playerForceOverrideStyle;

  /// 播放器字幕杂项面板：覆盖开启说明
  ///
  /// In zh, this message translates to:
  /// **'使用上方设置渲染字幕样式'**
  String get playerForceOverrideStyleDesc;

  /// 播放器字幕杂项面板：覆盖关闭说明
  ///
  /// In zh, this message translates to:
  /// **'字幕使用自带的样式与字体'**
  String get playerStyleFromSubtitleDesc;

  /// 播放器字幕样式面板：重置所有样式
  ///
  /// In zh, this message translates to:
  /// **'重置所有样式'**
  String get playerResetAllStyles;

  /// 播放器字幕样式面板：ASS 限制说明标题
  ///
  /// In zh, this message translates to:
  /// **'ASS 内嵌字幕的限制'**
  String get playerAssLimitTitle;

  /// 播放器字幕样式面板：ASS 限制项（不生效）
  ///
  /// In zh, this message translates to:
  /// **'粗体 / 斜体 / 模糊'**
  String get playerAssLimitBoldItalicBlur;

  /// 播放器字幕样式面板：ASS 限制项说明
  ///
  /// In zh, this message translates to:
  /// **'开启覆盖也不生效（mpv 渲染限制）'**
  String get playerAssLimitNoEffect;

  /// 播放器字幕样式面板：ASS 可覆盖项
  ///
  /// In zh, this message translates to:
  /// **'颜色 / 描边 / 背景 / 大小 / 位置 / 字间距'**
  String get playerAssLimitStyleItems;

  /// 播放器字幕样式面板：ASS 可覆盖项说明
  ///
  /// In zh, this message translates to:
  /// **'开启覆盖后生效'**
  String get playerAssLimitTakesEffect;

  /// 播放器字幕样式面板：文本字幕
  ///
  /// In zh, this message translates to:
  /// **'SRT / VTT 等文本字幕'**
  String get playerAssLimitTextFormats;

  /// 播放器字幕样式面板：文本字幕说明
  ///
  /// In zh, this message translates to:
  /// **'所有样式都直接生效'**
  String get playerAssLimitAllEffective;

  /// 播放器字幕样式面板：缩放与位置分组
  ///
  /// In zh, this message translates to:
  /// **'字幕缩放与位置'**
  String get playerSubtitleScalePosition;

  /// 播放器字幕样式面板：缩放比例
  ///
  /// In zh, this message translates to:
  /// **'缩放比例'**
  String get playerScaleRatio;

  /// 播放器字幕样式面板：垂直位置
  ///
  /// In zh, this message translates to:
  /// **'垂直位置'**
  String get playerVerticalPosition;

  /// 播放器字幕样式面板：垂直位置读数
  ///
  /// In zh, this message translates to:
  /// **'{value}（100=窗口底部）'**
  String playerVerticalPositionValue(int value);

  /// 播放器字幕样式面板：重置缩放与位置
  ///
  /// In zh, this message translates to:
  /// **'重置缩放与位置'**
  String get playerResetScalePosition;

  /// 播放器字幕字体面板：刷新字体目录提示
  ///
  /// In zh, this message translates to:
  /// **'已刷新，共 {count, plural, other{{count} 种字体}}'**
  String playerFontsRefreshed(int count);

  /// 播放器字幕字体面板：清除字体目录提示
  ///
  /// In zh, this message translates to:
  /// **'已清除字体目录'**
  String get playerFontDirCleared;

  /// 播放器字幕字体面板：字体更改说明
  ///
  /// In zh, this message translates to:
  /// **'字体更改需退出播放器并重新进入后生效'**
  String get playerFontChangeHint;

  /// 播放器字幕字体面板：字体目录
  ///
  /// In zh, this message translates to:
  /// **'字体目录'**
  String get playerFontDir;

  /// 播放器字幕字体面板：选择字体目录提示
  ///
  /// In zh, this message translates to:
  /// **'点击选择包含 .ttf/.otf 字体的目录'**
  String get playerFontDirPickHint;

  /// 播放器字幕字体面板：清除目录
  ///
  /// In zh, this message translates to:
  /// **'清除目录'**
  String get playerFontDirClear;

  /// 播放器字幕字体面板：当前字体
  ///
  /// In zh, this message translates to:
  /// **'当前字体'**
  String get playerCurrentFont;

  /// 播放器字幕字体面板：默认字体
  ///
  /// In zh, this message translates to:
  /// **'默认字体'**
  String get playerDefaultFont;

  /// 播放器字幕字体面板：未选目录提示
  ///
  /// In zh, this message translates to:
  /// **'请先选择字体目录'**
  String get playerPickFontDirFirst;

  /// 播放器字幕字体面板：跟随系统字库
  ///
  /// In zh, this message translates to:
  /// **'跟随系统字库'**
  String get playerFollowSystemFonts;

  /// 播放器字幕字体面板：字体更改完整说明
  ///
  /// In zh, this message translates to:
  /// **'字体更改需退出播放器并重新进入后生效；内嵌 ASS 字幕需开启「强制覆盖内嵌样式」后字体设置才会生效。'**
  String get playerFontChangeHintFull;

  /// 通用按钮：复制（文件操作 / 媒体信息）
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get commonCopy;

  /// 通用按钮：粘贴（打开链接弹窗）
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get commonPaste;

  /// 通用：未知（值缺失时的兜底）
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get commonUnknown;

  /// 通用：已保存（副标题状态）
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get commonSaved;

  /// 通用按钮：展开
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get commonExpand;

  /// 通用按钮：收起
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get commonCollapse;

  /// 通用：全选（勾选栏）
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get commonSelectAll;

  /// 通用：取消全选
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get commonDeselectAll;

  /// 通用按钮：测试
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get commonTest;

  /// 通用按钮：测试连接（网络账户 / 字幕来源）
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get commonTestConnection;

  /// 通用：测试中
  ///
  /// In zh, this message translates to:
  /// **'测试中…'**
  String get commonTesting;

  /// 通用：保存中
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get commonSaving;

  /// 通用动作：移动（文件操作菜单）
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get commonMove;

  /// 通用动作：重命名
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get commonRename;

  /// 通用动作：继续（下载任务）
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get commonResume;

  /// 通用：正序（选集顺序）
  ///
  /// In zh, this message translates to:
  /// **'正序'**
  String get commonOrderAsc;

  /// 通用：倒序（选集顺序）
  ///
  /// In zh, this message translates to:
  /// **'倒序'**
  String get commonOrderDesc;

  /// 通用提示：保存失败
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get commonSaveFailed;

  /// 通用提示：保存失败（带原因）
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String commonSaveFailedWith(String error);

  /// 通用提示：连接成功
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get commonConnectOk;

  /// 通用提示：连接失败
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String commonConnectFailed(String error);

  /// 通用：取消搜索（首页 / 目录页 / 网络浏览）
  ///
  /// In zh, this message translates to:
  /// **'取消搜索'**
  String get commonCancelSearch;

  /// 通用：清除搜索
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get commonClearSearch;

  /// B 站页：索引 tab / 入口
  ///
  /// In zh, this message translates to:
  /// **'索引'**
  String get biliIndexTitle;

  /// B 站索引页：推荐 tab
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get biliRecommend;

  /// B 站入口名 / 首页入口
  ///
  /// In zh, this message translates to:
  /// **'哔哩番剧'**
  String get biliBangumi;

  /// B 站索引页：解析链接入口
  ///
  /// In zh, this message translates to:
  /// **'解析链接'**
  String get biliParseLink;

  /// B 站下载页：解析按钮
  ///
  /// In zh, this message translates to:
  /// **'解析'**
  String get biliParse;

  /// B 站番剧索引页：空态
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get biliNothingHere;

  /// B 站索引页：追番时间表
  ///
  /// In zh, this message translates to:
  /// **'追番时间表'**
  String get biliTimeline;

  /// B 站追番时间表：今天 tab
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get biliToday;

  /// B 站追番时间表：周一
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get biliWeekdayMon;

  /// B 站追番时间表：周二
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get biliWeekdayTue;

  /// B 站追番时间表：周三
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get biliWeekdayWed;

  /// B 站追番时间表：周四
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get biliWeekdayThu;

  /// B 站追番时间表：周五
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get biliWeekdayFri;

  /// B 站追番时间表：周六
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get biliWeekdaySat;

  /// B 站追番时间表：周日
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get biliWeekdaySun;

  /// B 站剧集卡片角标：已追番
  ///
  /// In zh, this message translates to:
  /// **'已追番'**
  String get biliFollowed;

  /// B 站：链接无法识别
  ///
  /// In zh, this message translates to:
  /// **'无法识别该链接（支持 ss/ep/BV/av 号与 b23.tv 短链）'**
  String get biliLinkUnrecognized;

  /// B 站：解析番剧链接弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'解析番剧链接'**
  String get biliParseBangumiLink;

  /// B 站：解析链接输入提示
  ///
  /// In zh, this message translates to:
  /// **'粘贴番剧/视频链接或 b23.tv 短链'**
  String get biliPasteAnimeLinkHint;

  /// B 站搜索页标题
  ///
  /// In zh, this message translates to:
  /// **'搜索番剧'**
  String get biliSearchAnime;

  /// B 站搜索页输入提示
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索番剧'**
  String get biliSearchAnimeHint;

  /// B 站搜索页空态
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关番剧'**
  String get biliNoAnimeFound;

  /// B 站番剧详情页标题（兜底）
  ///
  /// In zh, this message translates to:
  /// **'番剧详情'**
  String get biliSeasonDetail;

  /// B 站番剧详情页：无选集
  ///
  /// In zh, this message translates to:
  /// **'暂无选集'**
  String get biliNoEpisodeSelection;

  /// B 站番剧详情页：查看全部
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get biliViewAll;

  /// B 站：选集
  ///
  /// In zh, this message translates to:
  /// **'选集'**
  String get biliSelectEpisode;

  /// B 站番剧详情页：评分
  ///
  /// In zh, this message translates to:
  /// **'评分 {score}'**
  String biliRating(String score);

  /// B 站播放量：亿级（value 已按 1e8 折算）
  ///
  /// In zh, this message translates to:
  /// **'{value}亿'**
  String biliCountHundredMillion(String value);

  /// B 站播放量：万级（value 已按 1e4 折算）
  ///
  /// In zh, this message translates to:
  /// **'{value}万'**
  String biliCountTenThousand(String value);

  /// B 站番剧详情页：简介
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get biliIntro;

  /// B 站番剧详情页：多季
  ///
  /// In zh, this message translates to:
  /// **'多季'**
  String get biliMultiSeason;

  /// B 站剧集卡片：第 N 话
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 话'**
  String biliEpisodeNo(int number);

  /// B 站 UGC：拿不到标题时的兜底标题
  ///
  /// In zh, this message translates to:
  /// **'B 站视频'**
  String get biliVideoFallbackTitle;

  /// B 站：播放失败提示
  ///
  /// In zh, this message translates to:
  /// **'播放失败：{error}'**
  String biliPlayFailed(String error);

  /// B 站账号页：等级
  ///
  /// In zh, this message translates to:
  /// **'等级'**
  String get biliLevel;

  /// B 站账号页：资产分组
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get biliAssets;

  /// B 站账号页：硬币
  ///
  /// In zh, this message translates to:
  /// **'硬币'**
  String get biliCoins;

  /// B 站账号页：硬币说明
  ///
  /// In zh, this message translates to:
  /// **'用于投币等操作'**
  String get biliCoinsDesc;

  /// B 站账号页：退出登录
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get biliSignOut;

  /// B 站账号页：已满级
  ///
  /// In zh, this message translates to:
  /// **'已满级'**
  String get biliMaxLevel;

  /// B 站账号页：经验值
  ///
  /// In zh, this message translates to:
  /// **'经验值 {current} / {next}'**
  String biliExpValue(int current, int next);

  /// B 站账号页：退出确认
  ///
  /// In zh, this message translates to:
  /// **'确定退出哔哩哔哩账号吗？'**
  String get biliSignOutConfirm;

  /// B 站账号页：退出确认按钮
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get biliSignOutAction;

  /// B 站登录：二维码获取中
  ///
  /// In zh, this message translates to:
  /// **'正在获取二维码...'**
  String get biliLoginQrLoading;

  /// B 站登录：扫码提示
  ///
  /// In zh, this message translates to:
  /// **'请使用哔哩哔哩客户端扫码'**
  String get biliLoginScanHint;

  /// B 站登录：二维码获取失败
  ///
  /// In zh, this message translates to:
  /// **'获取二维码失败，请重试'**
  String get biliLoginQrFailed;

  /// B 站登录：二维码失效刷新中
  ///
  /// In zh, this message translates to:
  /// **'二维码已失效，正在刷新...'**
  String get biliLoginQrRefreshing;

  /// B 站登录：已扫码待确认
  ///
  /// In zh, this message translates to:
  /// **'已扫码，请在手机上确认'**
  String get biliLoginScannedConfirm;

  /// B 站登录：凭证获取失败
  ///
  /// In zh, this message translates to:
  /// **'登录凭证获取失败，请重试'**
  String get biliLoginCredentialFailed;

  /// B 站登录：成功提示
  ///
  /// In zh, this message translates to:
  /// **'登录成功：{nickname}'**
  String biliLoginSuccess(String nickname);

  /// B 站登录：失败提示
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请重试'**
  String get biliLoginFailedRetry;

  /// B 站登录：二维码保存成功
  ///
  /// In zh, this message translates to:
  /// **'二维码已保存到相册'**
  String get biliQrSavedToGallery;

  /// B 站登录：未装客户端
  ///
  /// In zh, this message translates to:
  /// **'未检测到哔哩哔哩客户端'**
  String get biliClientNotFound;

  /// B 站登录：Cookie 为空提示
  ///
  /// In zh, this message translates to:
  /// **'请先粘贴 Cookie'**
  String get biliPasteCookieFirst;

  /// B 站登录：Cookie 无效
  ///
  /// In zh, this message translates to:
  /// **'登录失败：Cookie 无效或已过期'**
  String get biliCookieInvalid;

  /// B 站登录页标题
  ///
  /// In zh, this message translates to:
  /// **'哔哩哔哩登录'**
  String get biliLoginTitle;

  /// B 站登录：扫码 tab
  ///
  /// In zh, this message translates to:
  /// **'扫码登录'**
  String get biliLoginQrTab;

  /// B 站登录：Cookie tab
  ///
  /// In zh, this message translates to:
  /// **'Cookie 登录'**
  String get biliLoginCookieTab;

  /// B 站登录：二维码剩余时间
  ///
  /// In zh, this message translates to:
  /// **'剩余有效时间：{seconds} 秒'**
  String biliLoginRemaining(int seconds);

  /// B 站登录：刷新二维码按钮
  ///
  /// In zh, this message translates to:
  /// **'刷新二维码'**
  String get biliQrRefresh;

  /// B 站登录：保存二维码按钮
  ///
  /// In zh, this message translates to:
  /// **'保存到相册'**
  String get biliSaveToGallery;

  /// B 站登录：唤起 App 按钮
  ///
  /// In zh, this message translates to:
  /// **'打开哔哩哔哩'**
  String get biliOpenApp;

  /// B 站登录：唤起 App 说明
  ///
  /// In zh, this message translates to:
  /// **'「打开哔哩哔哩」会在已安装的哔哩哔哩客户端中自动唤起扫码确认。'**
  String get biliOpenAppDesc;

  /// B 站登录：Cookie 登录说明
  ///
  /// In zh, this message translates to:
  /// **'从浏览器复制 Cookie 粘贴登录（扫码异常时的备用方式）'**
  String get biliCookieLoginDesc;

  /// B 站登录：登录中
  ///
  /// In zh, this message translates to:
  /// **'登录中...'**
  String get biliLoggingIn;

  /// B 站登录：Cookie 隐私说明
  ///
  /// In zh, this message translates to:
  /// **'Cookie 仅本地加密保存，不会上传或记录日志。'**
  String get biliCookiePrivacy;

  /// 下载：未设置目录（B 站视频/弹幕/字幕三处共用）
  ///
  /// In zh, this message translates to:
  /// **'请先设置下载目录'**
  String get downloadSetDirFirst;

  /// 下载：目录失效
  ///
  /// In zh, this message translates to:
  /// **'下载目录不存在，请重新选择'**
  String get downloadDirGone;

  /// B 站弹幕下载：加入任务提示
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已添加 {count} 个弹幕下载任务}}'**
  String biliDanmakuTasksAdded(int count);

  /// B 站视频下载：加入任务提示
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已添加 {count} 个视频下载任务}}'**
  String biliVideoTasksAdded(int count);

  /// B 站下载：链接输入提示
  ///
  /// In zh, this message translates to:
  /// **'粘贴 B 站视频/番剧链接（BV / av / ss / ep / b23.tv）'**
  String get biliPasteVideoLinkHint;

  /// B 站下载：空态提示
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接后点「解析」'**
  String get biliPasteThenParse;

  /// 下载：目录未设置
  ///
  /// In zh, this message translates to:
  /// **'未设置下载目录'**
  String get downloadNoDir;

  /// 下载：设置目录按钮
  ///
  /// In zh, this message translates to:
  /// **'设置目录'**
  String get downloadSetDir;

  /// B 站弹幕下载：已选集数
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已选 {count} 集}}'**
  String biliEpisodesSelected(int count);

  /// B 站视频下载：已选 / 总数
  ///
  /// In zh, this message translates to:
  /// **'已选 {selected} / 共 {total, plural, other{{total} 集}}'**
  String biliEpisodesSelectedOfTotal(int selected, int total);

  /// B 站弹幕下载：下载按钮
  ///
  /// In zh, this message translates to:
  /// **'下载弹幕（{count}）'**
  String biliDownloadDanmaku(int count);

  /// B 站视频下载：下载按钮
  ///
  /// In zh, this message translates to:
  /// **'下载视频（{count}）'**
  String biliDownloadVideo(int count);

  /// B 站视频下载：同步弹幕开关
  ///
  /// In zh, this message translates to:
  /// **'同步下载弹幕'**
  String get biliSyncDanmaku;

  /// 字幕下载设置：字幕来源分组
  ///
  /// In zh, this message translates to:
  /// **'字幕来源'**
  String get subtitleSourceSection;

  /// 字幕来源：Wyzie 说明
  ///
  /// In zh, this message translates to:
  /// **'经 sub.wyzie.io 搜索，需要 API 密钥'**
  String get subtitleWyzieDesc;

  /// 字幕来源：自定义说明
  ///
  /// In zh, this message translates to:
  /// **'自填接口地址，片名会发送到该地址'**
  String get subtitleCustomDesc;

  /// 字幕来源：自定义参数分组
  ///
  /// In zh, this message translates to:
  /// **'自定义参数'**
  String get subtitleCustomParams;

  /// 字幕来源：Wyzie 参数分组
  ///
  /// In zh, this message translates to:
  /// **'Wyzie 参数'**
  String get subtitleWyzieParams;

  /// 字幕来源：密钥项
  ///
  /// In zh, this message translates to:
  /// **'WYZIE API 密钥'**
  String get subtitleWyzieApiKey;

  /// 字幕来源：Wyzie 来源列表
  ///
  /// In zh, this message translates to:
  /// **'Wyzie 来源'**
  String get subtitleWyzieSources;

  /// 字幕下载：字幕语言
  ///
  /// In zh, this message translates to:
  /// **'字幕语言'**
  String get subtitleLanguage;

  /// 字幕下载：首选格式
  ///
  /// In zh, this message translates to:
  /// **'首选格式'**
  String get subtitlePreferredFormat;

  /// 字幕下载：首选编码
  ///
  /// In zh, this message translates to:
  /// **'首选编码'**
  String get subtitlePreferredEncoding;

  /// 字幕来源：自定义接口地址
  ///
  /// In zh, this message translates to:
  /// **'接口地址'**
  String get subtitleApiEndpoint;

  /// 字幕来源：测试说明
  ///
  /// In zh, this message translates to:
  /// **'用一个片名试搜一次，看能否解析出字幕'**
  String get subtitleCustomTestHint;

  /// 字幕来源：测试中
  ///
  /// In zh, this message translates to:
  /// **'正在测试…'**
  String get subtitleTesting;

  /// 字幕来源：测试成功但无结果
  ///
  /// In zh, this message translates to:
  /// **'连接成功，但没解析出字幕'**
  String get subtitleTestNoResult;

  /// 字幕来源：测试成功
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{连接成功，解析出 {count} 条字幕}}'**
  String subtitleTestOk(int count);

  /// 字幕来源：测试失败
  ///
  /// In zh, this message translates to:
  /// **'测试失败：{error}'**
  String subtitleTestFailed(String error);

  /// 字幕来源筛选：全部来源
  ///
  /// In zh, this message translates to:
  /// **'全部来源'**
  String get subtitleAllSources;

  /// 字幕语言筛选：全部语言
  ///
  /// In zh, this message translates to:
  /// **'全部语言'**
  String get subtitleAllLanguages;

  /// 字幕格式筛选：全部格式
  ///
  /// In zh, this message translates to:
  /// **'全部格式'**
  String get subtitleAllFormats;

  /// 字幕编码筛选：全部编码
  ///
  /// In zh, this message translates to:
  /// **'全部编码'**
  String get subtitleAllEncodings;

  /// 字幕来源：密钥输入提示
  ///
  /// In zh, this message translates to:
  /// **'粘贴密钥（wyzie-…）'**
  String get subtitlePasteKeyHint;

  /// 字幕来源：获取密钥帮助
  ///
  /// In zh, this message translates to:
  /// **'如何获取密钥'**
  String get subtitleHowToGetKey;

  /// 字幕来源：密钥类型
  ///
  /// In zh, this message translates to:
  /// **'密钥类型：{type}'**
  String subtitleKeyType(String type);

  /// 字幕来源：密钥无效
  ///
  /// In zh, this message translates to:
  /// **'密钥无效'**
  String get subtitleKeyInvalid;

  /// 字幕来源筛选：免费来源分组
  ///
  /// In zh, this message translates to:
  /// **'免费来源'**
  String get subtitleFreeSource;

  /// 字幕来源筛选：付费来源分组
  ///
  /// In zh, this message translates to:
  /// **'付费来源'**
  String get subtitlePaidSource;

  /// 字幕来源：自定义地址说明。{placeholder} 是语法记号，调用点传字面量 {name}（ARB 里的裸花括号会被 gen_l10n 当成占位符，ICU 单引号转义不生效 —— 见 06 遗留）
  ///
  /// In zh, this message translates to:
  /// **'地址里可用 {placeholder} 作为片名占位（不写占位符则把片名拼到末尾）。\n搜索时片名会发送到你填写的地址，请自行确认该服务的条款与可用性；本应用不内置、也不代理任何第三方字幕服务。'**
  String subtitleCustomSourceHelp(String placeholder);

  /// 字幕来源：自定义地址输入说明。{placeholder} 是语法记号，调用点传字面量 {name}
  ///
  /// In zh, this message translates to:
  /// **'用 {placeholder} 占位片名；没有占位符时片名会拼到末尾。'**
  String subtitlePlaceholderHelp(String placeholder);

  /// 字幕来源：自定义接口帮助
  ///
  /// In zh, this message translates to:
  /// **'如何自定义接口地址'**
  String get subtitleHowToCustomEndpoint;

  /// 字幕来源：测试弹窗输入提示
  ///
  /// In zh, this message translates to:
  /// **'填一个片名（如 你的名字）'**
  String get subtitleTestNameHint;

  /// 字幕来源：测试弹窗说明
  ///
  /// In zh, this message translates to:
  /// **'用这个片名请求一次，看能否解析出字幕。'**
  String get subtitleTestNameDesc;

  /// 字幕下载：未设密钥
  ///
  /// In zh, this message translates to:
  /// **'请先设置 WYZIE API 密钥'**
  String get subtitleSetWyzieKeyFirst;

  /// 字幕下载：未设自定义地址
  ///
  /// In zh, this message translates to:
  /// **'请先设置自定义字幕地址'**
  String get subtitleSetCustomUrlFirst;

  /// 字幕下载：全部成功提示
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已下载 {count} 个字幕}}'**
  String subtitleDownloadedCount(int count);

  /// 字幕下载：部分失败提示
  ///
  /// In zh, this message translates to:
  /// **'下载完成：成功 {ok}，失败 {fail}'**
  String subtitleDownloadResult(int ok, int fail);

  /// 字幕下载：搜索框提示
  ///
  /// In zh, this message translates to:
  /// **'输入影视名称或 IMDB / TMDB ID'**
  String get subtitleSearchHint;

  /// 字幕下载：返回设置
  ///
  /// In zh, this message translates to:
  /// **'返回设置'**
  String get subtitleBackToSettings;

  /// 字幕下载：无结果提示
  ///
  /// In zh, this message translates to:
  /// **'未找到字幕，请换个关键词或调整字幕设置'**
  String get subtitleNoResultHint;

  /// 字幕下载：设置面板标题
  ///
  /// In zh, this message translates to:
  /// **'字幕下载设置'**
  String get subtitleDownloadSettings;

  /// 字幕下载：空态提示
  ///
  /// In zh, this message translates to:
  /// **'输入关键词后点「确定」搜索字幕'**
  String get subtitleSearchHintShort;

  /// 字幕下载：结果头（关键词 + 条数）
  ///
  /// In zh, this message translates to:
  /// **'{query} · {count, plural, other{{count} 条}}'**
  String subtitleResultHeader(String query, int count);

  /// 字幕下载：重新搜索
  ///
  /// In zh, this message translates to:
  /// **'重新搜索'**
  String get subtitleSearchAgain;

  /// 字幕下载：已选 / 总数
  ///
  /// In zh, this message translates to:
  /// **'已选 {selected} / {total, plural, other{{total} 条}}'**
  String subtitleSelectedOfTotal(int selected, int total);

  /// 字幕下载：来源未知
  ///
  /// In zh, this message translates to:
  /// **'未知来源'**
  String get subtitleUnknownSource;

  /// 字幕下载：下载中
  ///
  /// In zh, this message translates to:
  /// **'下载中…'**
  String get subtitleDownloadingNow;

  /// 字幕下载：下载按钮
  ///
  /// In zh, this message translates to:
  /// **'下载字幕（{count}）'**
  String subtitleDownloadButton(int count);

  /// 视频卡片菜单：媒体信息
  ///
  /// In zh, this message translates to:
  /// **'媒体信息'**
  String get mediaInfoItem;

  /// 媒体信息页：复制成功
  ///
  /// In zh, this message translates to:
  /// **'媒体信息已复制'**
  String get mediaInfoCopied;

  /// 媒体信息页标题（带文件名）
  ///
  /// In zh, this message translates to:
  /// **'媒体信息 - {title}'**
  String mediaInfoTitleWithName(String title);

  /// 媒体信息页：通用信息大标题
  ///
  /// In zh, this message translates to:
  /// **'【通用信息】'**
  String get mediaInfoGeneralHeader;

  /// 媒体信息页：视频流分组
  ///
  /// In zh, this message translates to:
  /// **'视频流'**
  String get mediaInfoVideoStreams;

  /// 媒体信息页：音频流分组
  ///
  /// In zh, this message translates to:
  /// **'音频流'**
  String get mediaInfoAudioStreams;

  /// 媒体信息页：字幕流分组
  ///
  /// In zh, this message translates to:
  /// **'字幕流'**
  String get mediaInfoSubtitleStreams;

  /// 媒体信息页：获取失败
  ///
  /// In zh, this message translates to:
  /// **'媒体信息获取失败'**
  String get mediaInfoFetchFailed;

  /// 媒体信息页：通用信息分组
  ///
  /// In zh, this message translates to:
  /// **'通用信息'**
  String get mediaInfoGeneral;

  /// 媒体信息字段：格式
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get mediaInfoFormat;

  /// 媒体信息字段：格式版本
  ///
  /// In zh, this message translates to:
  /// **'格式版本'**
  String get mediaInfoFormatVersion;

  /// 媒体信息字段：文件大小
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get mediaInfoFileSize;

  /// 媒体信息字段：总比特率
  ///
  /// In zh, this message translates to:
  /// **'总比特率'**
  String get mediaInfoOverallBitrate;

  /// 媒体信息字段：编码日期
  ///
  /// In zh, this message translates to:
  /// **'编码日期'**
  String get mediaInfoEncodedDate;

  /// 媒体信息字段：编码应用
  ///
  /// In zh, this message translates to:
  /// **'编码应用'**
  String get mediaInfoWritingApp;

  /// 媒体信息字段：编码库
  ///
  /// In zh, this message translates to:
  /// **'编码库'**
  String get mediaInfoWritingLibrary;

  /// 媒体信息字段：第 N 条视频流
  ///
  /// In zh, this message translates to:
  /// **'视频流 #{index}'**
  String mediaInfoVideoStreamNo(int index);

  /// 媒体信息字段：第 N 条音频流
  ///
  /// In zh, this message translates to:
  /// **'音频流 #{index}'**
  String mediaInfoAudioStreamNo(int index);

  /// 媒体信息字段：第 N 条字幕流
  ///
  /// In zh, this message translates to:
  /// **'字幕流 #{index}'**
  String mediaInfoSubtitleStreamNo(int index);

  /// 媒体信息页：空态
  ///
  /// In zh, this message translates to:
  /// **'未获取到媒体信息'**
  String get mediaInfoNoInfo;

  /// 媒体信息字段：编码
  ///
  /// In zh, this message translates to:
  /// **'编码'**
  String get mediaInfoCodec;

  /// 媒体信息字段：配置
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get mediaInfoProfile;

  /// 媒体信息字段：编码 ID
  ///
  /// In zh, this message translates to:
  /// **'编码ID'**
  String get mediaInfoCodecId;

  /// 媒体信息字段：宽
  ///
  /// In zh, this message translates to:
  /// **'宽'**
  String get mediaInfoWidth;

  /// 媒体信息字段：高
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get mediaInfoHeight;

  /// 媒体信息字段：宽高比
  ///
  /// In zh, this message translates to:
  /// **'宽高比'**
  String get mediaInfoAspectRatio;

  /// 媒体信息字段：帧率模式
  ///
  /// In zh, this message translates to:
  /// **'帧率模式'**
  String get mediaInfoFrameRateMode;

  /// 媒体信息字段：比特率
  ///
  /// In zh, this message translates to:
  /// **'比特率'**
  String get mediaInfoBitrate;

  /// 媒体信息字段：位深度
  ///
  /// In zh, this message translates to:
  /// **'位深度'**
  String get mediaInfoBitDepth;

  /// 媒体信息字段：色彩空间
  ///
  /// In zh, this message translates to:
  /// **'色彩空间'**
  String get mediaInfoColorSpace;

  /// 媒体信息字段：色度子采样
  ///
  /// In zh, this message translates to:
  /// **'色度子采样'**
  String get mediaInfoChromaSubsampling;

  /// 媒体信息字段：HDR 格式
  ///
  /// In zh, this message translates to:
  /// **'HDR格式'**
  String get mediaInfoHdrFormat;

  /// 媒体信息字段：声道
  ///
  /// In zh, this message translates to:
  /// **'声道'**
  String get mediaInfoChannels;

  /// 媒体信息字段：流大小
  ///
  /// In zh, this message translates to:
  /// **'流大小'**
  String get mediaInfoStreamSize;

  /// 媒体信息页：流选项卡
  ///
  /// In zh, this message translates to:
  /// **'流'**
  String get mediaInfoStream;

  /// 网络存储页标题 / 首页入口
  ///
  /// In zh, this message translates to:
  /// **'网络存储'**
  String get networkStorageTitle;

  /// 账户编辑：主机为空
  ///
  /// In zh, this message translates to:
  /// **'请先填写主机地址'**
  String get networkHostInputRequired;

  /// 账户编辑：端口非法
  ///
  /// In zh, this message translates to:
  /// **'端口需为 1-65535'**
  String get networkPortInvalid;

  /// 账户编辑：默认端口提示（SMB）
  ///
  /// In zh, this message translates to:
  /// **'默认 {port}（群晖 5005/5006）'**
  String networkDefaultPortWithSynology(String port);

  /// 账户编辑：默认端口提示
  ///
  /// In zh, this message translates to:
  /// **'默认 {port}'**
  String networkDefaultPort(String port);

  /// 账户编辑页：标题
  ///
  /// In zh, this message translates to:
  /// **'编辑账户'**
  String get networkEditAccount;

  /// 账户编辑页 / 网络存储页：添加账户
  ///
  /// In zh, this message translates to:
  /// **'添加账户'**
  String get networkAddAccount;

  /// 账户编辑：显示名称
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get networkDisplayName;

  /// 账户编辑：名称提示
  ///
  /// In zh, this message translates to:
  /// **'例如：家庭 NAS'**
  String get networkDisplayNameHint;

  /// 账户编辑：名称为空
  ///
  /// In zh, this message translates to:
  /// **'请输入名称'**
  String get networkNameRequired;

  /// 账户编辑：协议
  ///
  /// In zh, this message translates to:
  /// **'协议'**
  String get networkProtocolLabel;

  /// 账户编辑：主机地址
  ///
  /// In zh, this message translates to:
  /// **'主机地址'**
  String get networkHostLabel;

  /// 账户编辑：主机提示
  ///
  /// In zh, this message translates to:
  /// **'IP 或域名'**
  String get networkHostHint;

  /// 账户编辑：主机为空提示
  ///
  /// In zh, this message translates to:
  /// **'请输入主机地址'**
  String get networkHostRequiredInput;

  /// 账户编辑：端口
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get networkPortLabel;

  /// 账户编辑：路径提示
  ///
  /// In zh, this message translates to:
  /// **'默认为 /'**
  String get networkPathDefaultHint;

  /// 账户编辑：匿名登录
  ///
  /// In zh, this message translates to:
  /// **'匿名登录'**
  String get networkAnonymous;

  /// 账户编辑：匿名登录说明
  ///
  /// In zh, this message translates to:
  /// **'FTP / SMB 匿名访问时开启'**
  String get networkAnonymousDesc;

  /// 账户编辑：使用 HTTPS
  ///
  /// In zh, this message translates to:
  /// **'使用 HTTPS'**
  String get networkUseHttps;

  /// 账户编辑：HTTPS 说明
  ///
  /// In zh, this message translates to:
  /// **'启用后使用加密连接（默认端口 443）'**
  String get networkUseHttpsDesc;

  /// 账户编辑：账号
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get networkUsername;

  /// 账户编辑：密码
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get networkPassword;

  /// 账户编辑：隐藏密码
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get networkHidePassword;

  /// 账户编辑：显示密码
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get networkShowPassword;

  /// 网络浏览：排序胶囊标题（字段 + 方向拼成一句，英文靠空格）
  ///
  /// In zh, this message translates to:
  /// **'按{field}{order}'**
  String networkSortByBoth(String field, String order);

  /// 网络浏览：搜索入口
  ///
  /// In zh, this message translates to:
  /// **'搜索本目录'**
  String get networkSearchCurrentDir;

  /// 网络浏览：刷新
  ///
  /// In zh, this message translates to:
  /// **'刷新本目录'**
  String get networkRefreshCurrentDir;

  /// 网络浏览：回到根目录
  ///
  /// In zh, this message translates to:
  /// **'回到共享根目录'**
  String get networkBackToRoot;

  /// 网络浏览：显示隐藏文件
  ///
  /// In zh, this message translates to:
  /// **'显示隐藏文件'**
  String get networkShowHiddenFiles;

  /// 网络浏览：无匹配
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的文件'**
  String get networkNoMatchingFiles;

  /// 网络浏览：空目录
  ///
  /// In zh, this message translates to:
  /// **'该目录为空'**
  String get networkDirEmpty;

  /// 网络浏览：只有隐藏文件
  ///
  /// In zh, this message translates to:
  /// **'本目录只有隐藏文件'**
  String get networkOnlyHiddenFiles;

  /// 网络浏览：返回上一级
  ///
  /// In zh, this message translates to:
  /// **'返回上一级'**
  String get networkBackUp;

  /// 网络浏览：修改时间
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get networkModifiedTime;

  /// 网络浏览：字段缺失
  ///
  /// In zh, this message translates to:
  /// **'服务器未提供'**
  String get networkServerNotProvided;

  /// 网络浏览：位置
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get networkLocation;

  /// 网络浏览：连接
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get networkConnectionLabel;

  /// 网络存储：删除账户
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get networkDeleteAccount;

  /// 网络存储：空态
  ///
  /// In zh, this message translates to:
  /// **'还没有网络存储账户'**
  String get networkNoAccounts;

  /// 网络存储：空态说明
  ///
  /// In zh, this message translates to:
  /// **'点击右下角 + 添加 WebDAV / SMB / FTP 账户'**
  String get networkNoAccountsHint;

  /// 文件夹详情页：搜索视频
  ///
  /// In zh, this message translates to:
  /// **'搜索视频'**
  String get homeSearchVideos;

  /// 首页 / 目录页：搜索提示
  ///
  /// In zh, this message translates to:
  /// **'搜索文件夹与视频'**
  String get homeSearchFoldersAndVideos;

  /// 排序与字段弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'排序与字段'**
  String get homeSortAndFields;

  /// 首页：排序与视图入口
  ///
  /// In zh, this message translates to:
  /// **'排序与视图'**
  String get homeSortAndView;

  /// 文件夹空态
  ///
  /// In zh, this message translates to:
  /// **'该文件夹没有视频'**
  String get homeNoVideosInFolder;

  /// 文件夹详情：无匹配视频
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的视频'**
  String get homeNoMatchingVideos;

  /// 首页 / 目录页：无匹配
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的内容'**
  String get homeNoMatchingContent;

  /// 首页：无匹配文件夹
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的文件夹'**
  String get homeNoMatchingFolders;

  /// 首页：最近播放入口
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get homeRecentPlayed;

  /// 首页 / 弹窗：打开链接
  ///
  /// In zh, this message translates to:
  /// **'打开链接'**
  String get homeOpenLink;

  /// 首页：文件缺失提示
  ///
  /// In zh, this message translates to:
  /// **'文件不存在或已被移动：{title}'**
  String homeFileGone(String title);

  /// 首页：权限提示
  ///
  /// In zh, this message translates to:
  /// **'请在系统设置中手动开启存储权限'**
  String get homePermissionHintInSettings;

  /// 首页：权限被拒说明
  ///
  /// In zh, this message translates to:
  /// **'存储权限已被拒绝，需要到系统设置里手动开启'**
  String get homePermissionDeniedDetail;

  /// 首页：权限说明
  ///
  /// In zh, this message translates to:
  /// **'需要授予存储权限才能扫描视频'**
  String get homePermissionNeeded;

  /// 首页：去设置按钮
  ///
  /// In zh, this message translates to:
  /// **'去系统设置开启'**
  String get homeOpenSettings;

  /// 首页：授予权限按钮
  ///
  /// In zh, this message translates to:
  /// **'授予权限'**
  String get homeGrantPermission;

  /// 首页：无视频
  ///
  /// In zh, this message translates to:
  /// **'没有找到视频'**
  String get homeNoVideosFound;

  /// 首页：重新扫描
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get homeRescan;

  /// 首页：重新检查权限
  ///
  /// In zh, this message translates to:
  /// **'我已开启，重新检查'**
  String get homeRecheckPermission;

  /// 打开链接：剪贴板空
  ///
  /// In zh, this message translates to:
  /// **'剪贴板为空'**
  String get openLinkClipboardEmpty;

  /// 打开链接：链接非法
  ///
  /// In zh, this message translates to:
  /// **'链接无效，支持 http/https/rtmp/rtsp 等流媒体协议'**
  String get openLinkInvalid;

  /// 打开链接：输入提示
  ///
  /// In zh, this message translates to:
  /// **'输入视频直链，将在线播放'**
  String get openLinkHint;

  /// 下载管理：清除已完成
  ///
  /// In zh, this message translates to:
  /// **'清除已完成'**
  String get downloadClearFinished;

  /// 下载管理：清除已完成说明
  ///
  /// In zh, this message translates to:
  /// **'只清除已完成和失败的下载记录，不会删除已下载的文件。'**
  String get downloadClearFinishedDesc;

  /// 下载管理：空态
  ///
  /// In zh, this message translates to:
  /// **'暂无下载任务'**
  String get downloadNoTasks;

  /// 下载管理：失败兜底文案
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadFailed;

  /// 下载状态：完成
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get downloadStatusCompleted;

  /// 下载状态：失败
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadStatusFailed;

  /// 下载状态：合并中
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get downloadStatusMerging;

  /// 下载状态：下载中
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadStatusDownloading;

  /// 下载状态：等待
  ///
  /// In zh, this message translates to:
  /// **'等待'**
  String get downloadStatusPending;

  /// 下载管理：合并中不可暂停
  ///
  /// In zh, this message translates to:
  /// **'合并中，无法暂停'**
  String get downloadMergingCannotPause;

  /// 投屏：搜索启动失败
  ///
  /// In zh, this message translates to:
  /// **'投屏搜索启动失败：{error}'**
  String castSearchStartFailed(String error);

  /// 投屏：已投屏
  ///
  /// In zh, this message translates to:
  /// **'已投屏到 {device}'**
  String castConnected(String device);

  /// 投屏：失败
  ///
  /// In zh, this message translates to:
  /// **'投屏失败：{error}'**
  String castFailed(String error);

  /// 投屏：搜索中
  ///
  /// In zh, this message translates to:
  /// **'正在搜索投屏设备…'**
  String get castSearching;

  /// 投屏：未发现设备
  ///
  /// In zh, this message translates to:
  /// **'未发现可投屏设备，请确认手机与电视连接同一 WiFi 后重试。'**
  String get castNoDevicesFound;

  /// 调色组件：展开自定义调色
  ///
  /// In zh, this message translates to:
  /// **'自定义调色'**
  String get colorEditorCustom;

  /// 调色组件：收起自定义调色
  ///
  /// In zh, this message translates to:
  /// **'收起自定义调色'**
  String get colorEditorCollapseCustom;

  /// 目录选择器：目录不可读
  ///
  /// In zh, this message translates to:
  /// **'目录不可读或不存在'**
  String get directoryPickerUnreadable;

  /// 目录选择器：标题
  ///
  /// In zh, this message translates to:
  /// **'选择下载目录'**
  String get directoryPickerTitle;

  /// 目录选择器：上级目录
  ///
  /// In zh, this message translates to:
  /// **'上级目录'**
  String get directoryPickerUp;

  /// 目录选择器：确认按钮
  ///
  /// In zh, this message translates to:
  /// **'选择此目录'**
  String get directoryPickerSelectThis;

  /// 目录选择器：空态
  ///
  /// In zh, this message translates to:
  /// **'该目录下没有子目录'**
  String get directoryPickerEmpty;

  /// 文件操作菜单：固定
  ///
  /// In zh, this message translates to:
  /// **'固定'**
  String get fileOpPin;

  /// 文件操作菜单：取消固定
  ///
  /// In zh, this message translates to:
  /// **'取消固定'**
  String get fileOpUnpin;

  /// 文件操作菜单：多选
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get fileOpMultiSelect;

  /// 重命名弹窗：名称标签
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get fileOpNewName;

  /// 重命名弹窗：提示
  ///
  /// In zh, this message translates to:
  /// **'扩展名之前的名称'**
  String get fileOpNameHint;

  /// 重命名弹窗：扩展名锁定说明
  ///
  /// In zh, this message translates to:
  /// **'扩展名固定为 {ext}，不可修改'**
  String fileOpLockedExt(String ext);

  /// 删除确认：文件夹默认语义
  ///
  /// In zh, this message translates to:
  /// **'仅删除该文件夹内的视频文件，其它文件不会被删除。'**
  String get fileOpDeleteFolderVideosOnly;

  /// 删除确认：多选纯视频
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{确定删除选中的 {count} 个视频吗？}}'**
  String fileOpDeleteSelectedVideos(int count);

  /// 删除确认：多选含文件夹
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{将删除选中的 {count} 项：文件夹只删除里面的视频文件，其它文件不会被删除。}}'**
  String fileOpDeleteSelectedMixed(int count);

  /// 删除确认：删除所有文件勾选
  ///
  /// In zh, this message translates to:
  /// **'删除所有文件'**
  String get fileOpDeleteAllFiles;

  /// 传输进度：准备中
  ///
  /// In zh, this message translates to:
  /// **'准备中…'**
  String get fileOpPreparing;

  /// 传输进度：整批第几项
  ///
  /// In zh, this message translates to:
  /// **'第 {current}/{total} 项'**
  String fileOpProgressItem(int current, int total);

  /// 传输进度：单项计数
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total, plural, other{{total} 项}}'**
  String fileOpProgressItems(int done, int total);

  /// 传输进度：处理中
  ///
  /// In zh, this message translates to:
  /// **'处理中…'**
  String get fileOpProcessing;

  /// 传输进度：字节进度（含百分比）
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total}（{percent}%）'**
  String fileOpBytesProgress(String done, String total, String percent);

  /// 多选工具栏：退出多选
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get fileSelectionExit;

  /// 多选工具栏：已选数量
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{已选 {count} 项}}'**
  String fileSelectionSelected(int count);

  /// 多选工具栏：文件操作菜单
  ///
  /// In zh, this message translates to:
  /// **'文件操作'**
  String get fileSelectionOps;

  /// 文件操作进度：正在移动
  ///
  /// In zh, this message translates to:
  /// **'正在移动…'**
  String get folderTransferMoving;

  /// 文件操作进度：正在复制
  ///
  /// In zh, this message translates to:
  /// **'正在复制…'**
  String get folderTransferCopying;

  /// 文件操作：已取消
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get folderActionCancelled;

  /// 文件操作：移动成功
  ///
  /// In zh, this message translates to:
  /// **'已移动「{title}」到 {dest}'**
  String folderMovedTo(String title, String dest);

  /// 文件操作：复制成功
  ///
  /// In zh, this message translates to:
  /// **'已复制「{title}」到 {dest}'**
  String folderCopiedTo(String title, String dest);

  /// 文件操作：批量移动（含失败项）
  ///
  /// In zh, this message translates to:
  /// **'已移动 {done}/{total, plural, other{{total} 项}}，失败：{failures}'**
  String folderActionMovedProgressFailed(int done, int total, String failures);

  /// 文件操作：批量复制（含失败项）
  ///
  /// In zh, this message translates to:
  /// **'已复制 {done}/{total, plural, other{{total} 项}}，失败：{failures}'**
  String folderActionCopiedProgressFailed(int done, int total, String failures);

  /// 文件操作：批量删除（含失败项）
  ///
  /// In zh, this message translates to:
  /// **'已删除 {done}/{total, plural, other{{total} 项}}，失败：{failures}'**
  String folderActionDeletedProgressFailed(
    int done,
    int total,
    String failures,
  );

  /// 文件操作：批量移动（失败项过多只列前 3）
  ///
  /// In zh, this message translates to:
  /// **'已移动 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项'**
  String folderActionMovedProgressFailedMore(
    int done,
    int total,
    String failures,
    int count,
  );

  /// 文件操作：批量复制（失败项过多只列前 3）
  ///
  /// In zh, this message translates to:
  /// **'已复制 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项'**
  String folderActionCopiedProgressFailedMore(
    int done,
    int total,
    String failures,
    int count,
  );

  /// 文件操作：批量删除（失败项过多只列前 3）
  ///
  /// In zh, this message translates to:
  /// **'已删除 {done}/{total, plural, other{{total} 项}}，失败：{failures} 等 {count} 项'**
  String folderActionDeletedProgressFailedMore(
    int done,
    int total,
    String failures,
    int count,
  );

  /// 文件操作：取消但已移动部分
  ///
  /// In zh, this message translates to:
  /// **'已取消（已移动 {done, plural, other{{done} 项}}）'**
  String folderActionCancelledThenMoved(int done);

  /// 文件操作：取消但已复制部分
  ///
  /// In zh, this message translates to:
  /// **'已取消（已复制 {done, plural, other{{done} 项}}）'**
  String folderActionCancelledThenCopied(int done);

  /// 文件操作：批量移动完成
  ///
  /// In zh, this message translates to:
  /// **'已移动 {done, plural, other{{done} 项}}到 {dest}'**
  String folderActionMovedCount(int done, String dest);

  /// 文件操作：批量复制完成
  ///
  /// In zh, this message translates to:
  /// **'已复制 {done, plural, other{{done} 项}}到 {dest}'**
  String folderActionCopiedCount(int done, String dest);

  /// 文件操作：重命名无变化
  ///
  /// In zh, this message translates to:
  /// **'名称没有变化'**
  String get folderNameUnchanged;

  /// 文件操作：重命名成功
  ///
  /// In zh, this message translates to:
  /// **'已重命名为 {newName}'**
  String folderRenamedTo(String newName);

  /// 文件操作：删除单项
  ///
  /// In zh, this message translates to:
  /// **'已删除「{title}」'**
  String folderDeletedOne(String title);

  /// 文件操作：批量删除完成
  ///
  /// In zh, this message translates to:
  /// **'已删除 {done, plural, other{{done} 项}}'**
  String folderDeletedCount(int done);

  /// 文件夹卡片：视频个数
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 个视频}}'**
  String folderVideoCount(int count);

  /// 排序与字段：文件夹排序方式
  ///
  /// In zh, this message translates to:
  /// **'文件夹排序方式'**
  String get optionsSheetFolderSort;

  /// 排序与字段：文件夹排序方向
  ///
  /// In zh, this message translates to:
  /// **'文件夹排序方向'**
  String get optionsSheetFolderSortDir;

  /// 排序与字段：文件夹显示字段
  ///
  /// In zh, this message translates to:
  /// **'文件夹显示字段'**
  String get optionsSheetFolderFields;

  /// 排序与字段：视频排序方式
  ///
  /// In zh, this message translates to:
  /// **'视频排序方式'**
  String get optionsSheetVideoSort;

  /// 排序与字段：视频排序方向
  ///
  /// In zh, this message translates to:
  /// **'视频排序方向'**
  String get optionsSheetVideoSortDir;

  /// 排序与字段：视频显示字段
  ///
  /// In zh, this message translates to:
  /// **'视频显示字段'**
  String get optionsSheetVideoFields;

  /// 排序与字段：显示模式
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get optionsSheetViewMode;

  /// 更新弹窗：主下载站
  ///
  /// In zh, this message translates to:
  /// **'主下载站'**
  String get updatePrimarySource;

  /// 更新弹窗：备用下载站
  ///
  /// In zh, this message translates to:
  /// **'备用下载站'**
  String get updateBackupSource;

  /// 更新弹窗：下载链接待接入
  ///
  /// In zh, this message translates to:
  /// **'{label}链接待接入'**
  String updateLinkPending(String label);

  /// 更新弹窗：链接打不开
  ///
  /// In zh, this message translates to:
  /// **'无法打开{label}链接'**
  String updateOpenLinkFailed(String label);

  /// 更新弹窗：发现新版本
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}'**
  String updateNewVersion(String version);

  /// 更新弹窗：忽略本版本
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get updateIgnore;

  /// 更新弹窗：稍后提醒
  ///
  /// In zh, this message translates to:
  /// **'稍后提醒'**
  String get updateLater;

  /// 更新弹窗：立即更新
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// 更新弹窗：选择下载方式
  ///
  /// In zh, this message translates to:
  /// **'选择下载方式'**
  String get updateChooseMethod;

  /// 更新弹窗：下载方式待接入
  ///
  /// In zh, this message translates to:
  /// **'待接入'**
  String get updatePending;

  /// 视频卡片：已看完
  ///
  /// In zh, this message translates to:
  /// **'已看完'**
  String get videoCardWatched;

  /// 视频卡片：未观看
  ///
  /// In zh, this message translates to:
  /// **'未观看'**
  String get videoCardUnwatched;

  /// 视频卡片：字幕检测中
  ///
  /// In zh, this message translates to:
  /// **'字幕检测中…'**
  String get videoCardDetectingSubtitle;

  /// 视频卡片：含字幕
  ///
  /// In zh, this message translates to:
  /// **'含字幕'**
  String get videoCardHasSubtitle;

  /// 视频卡片：字幕格式
  ///
  /// In zh, this message translates to:
  /// **'字幕 · {codec}'**
  String videoCardSubtitleCodec(String codec);

  /// 视频卡片：无字幕
  ///
  /// In zh, this message translates to:
  /// **'无字幕'**
  String get videoCardNoSubtitle;

  /// B 站封面图兜底提示
  ///
  /// In zh, this message translates to:
  /// **'哔哩封面不可用（缓存未命中且下载失败）'**
  String get biliCoverUnavailable;

  /// 错误：网络请求异常（bili / 弹弹Play / Wyzie / 自定义字幕共用）
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败: {error}'**
  String errorNetworkRequestFailed(String error);

  /// 错误：HTTP 非 2xx（bili / 弹弹Play / Wyzie / 下载共用）
  ///
  /// In zh, this message translates to:
  /// **'请求失败（HTTP {status}）'**
  String errorHttpRequestFailed(String status);

  /// 错误：搜索接口 HTTP 非 2xx（Wyzie / 自定义字幕）
  ///
  /// In zh, this message translates to:
  /// **'搜索失败（HTTP {status}）'**
  String errorHttpSearchFailed(String status);

  /// 错误：下载 HTTP 非 2xx（Wyzie / 自定义字幕 / WebDAV / 下载任务）
  ///
  /// In zh, this message translates to:
  /// **'下载失败（HTTP {status}）'**
  String errorHttpDownloadFailed(String status);

  /// 错误：响应不是 JSON 对象
  ///
  /// In zh, this message translates to:
  /// **'响应不是 JSON 对象'**
  String get errorResponseNotJson;

  /// 错误：响应解析异常（bili / 弹弹Play）
  ///
  /// In zh, this message translates to:
  /// **'响应解析失败：{error}'**
  String errorResponseParseFailed(String error);

  /// 错误：响应解码异常（弹弹Play）
  ///
  /// In zh, this message translates to:
  /// **'响应解码失败：{error}'**
  String errorResponseDecodeFailed(String error);

  /// 错误：下载异常（Wyzie / 自定义字幕）
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String errorDownloadFailed(String error);

  /// 错误：下载体积超上限（Wyzie / 自定义字幕）
  ///
  /// In zh, this message translates to:
  /// **'下载失败：文件过大（{received} 字节）'**
  String errorDownloadTooLarge(String received);

  /// 错误：响应体积超上限（Wyzie / 自定义字幕）
  ///
  /// In zh, this message translates to:
  /// **'响应异常（已读 {received} 字节，超过 {max} 上限）'**
  String errorResponseTooLarge(String received, String max);

  /// 错误：响应过大已放弃解析（弹弹Play / Wyzie）
  ///
  /// In zh, this message translates to:
  /// **'响应过大（{received} 字节），已放弃解析'**
  String errorResponseTooLargeAborted(String received);

  /// 错误：服务端返回失败（弹弹Play / bili）
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误'**
  String get errorServerReturned;

  /// 错误：服务端返回失败（带业务 code；bili / 弹弹Play）
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误（code={code}）'**
  String errorServerReturnedCode(String code);

  /// 错误：兜底未知错误
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get errorUnknown;

  /// 错误：网络连接缺失（播放列表源 / 网络字幕流）
  ///
  /// In zh, this message translates to:
  /// **'网络连接不存在'**
  String get errorNetworkConnectionMissing;

  /// B 站错误：缺少 WBI 密钥（播放地址）
  ///
  /// In zh, this message translates to:
  /// **'未获取到 WBI 密钥，无法解析播放地址'**
  String get biliWbiKeyMissingPlay;

  /// B 站错误：缺少 WBI 密钥（搜索）
  ///
  /// In zh, this message translates to:
  /// **'未获取到 WBI 密钥，无法搜索'**
  String get biliWbiKeyMissingSearch;

  /// B 站错误：触发风控验证
  ///
  /// In zh, this message translates to:
  /// **'触发风控验证（v_voucher），请稍后重试或切换网络'**
  String get biliRiskControlTriggered;

  /// B 站错误：视频不存在（code -404）
  ///
  /// In zh, this message translates to:
  /// **'视频不存在或无权访问'**
  String get biliVideoNotFound;

  /// B 站错误：无权访问（code -403）
  ///
  /// In zh, this message translates to:
  /// **'无权访问，可能需要登录或大会员'**
  String get biliVideoNoAccess;

  /// B 站错误：需要大会员（code -10403）
  ///
  /// In zh, this message translates to:
  /// **'需要大会员权限'**
  String get biliVideoVipRequired;

  /// B 站错误：风控验证失败（code -352）
  ///
  /// In zh, this message translates to:
  /// **'风控验证失败，请稍后重试'**
  String get biliVideoRiskControlFailed;

  /// B 站错误：专属视频（code 87008）
  ///
  /// In zh, this message translates to:
  /// **'专属视频，需开通相应权限'**
  String get biliVideoExclusive;

  /// B 站下载：链接无法识别
  ///
  /// In zh, this message translates to:
  /// **'无法识别 B 站链接（支持 BV / av / ss / ep / 合集链接 / b23.tv 短链）'**
  String get biliDownloadLinkUnrecognized;

  /// B 站下载：没有分 P
  ///
  /// In zh, this message translates to:
  /// **'未解析到视频分 P'**
  String get biliDownloadNoVideoParts;

  /// B 站下载：番剧无集数
  ///
  /// In zh, this message translates to:
  /// **'该番剧没有可下载的集数'**
  String get biliDownloadBangumiNoEpisodes;

  /// B 站下载：合集无可下载视频
  ///
  /// In zh, this message translates to:
  /// **'该合集没有可下载的视频'**
  String get biliDownloadCollectionNoVideos;

  /// B 站下载：合集暂无内容
  ///
  /// In zh, this message translates to:
  /// **'该合集暂无内容'**
  String get biliDownloadCollectionEmpty;

  /// B 站下载：该集无弹幕
  ///
  /// In zh, this message translates to:
  /// **'该集没有弹幕'**
  String get biliDownloadNoDanmaku;

  /// B 站下载：未取到视频流
  ///
  /// In zh, this message translates to:
  /// **'未获取到视频流'**
  String get biliDownloadNoVideoStream;

  /// B 站下载：音视频合并失败
  ///
  /// In zh, this message translates to:
  /// **'音视频合并失败'**
  String get biliDownloadMergeFailed;

  /// B 站下载：网络请求失败（无详情）
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败'**
  String get biliDownloadNetworkFailed;

  /// B 站下载：写盘失败
  ///
  /// In zh, this message translates to:
  /// **'写入文件失败（磁盘空间或权限）'**
  String get biliDownloadWriteFailed;

  /// B 站下载：写盘失败（带异常详情）
  ///
  /// In zh, this message translates to:
  /// **'写入文件失败（磁盘空间或权限）：{error}'**
  String biliDownloadWriteFailedDetail(String error);

  /// Wyzie：HTTP 400（接口判定为无结果）
  ///
  /// In zh, this message translates to:
  /// **'搜索失败（HTTP 400）'**
  String get wyzieSearchNoSubtitles;

  /// Wyzie：没有匹配的影视
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的影视，请换个关键词'**
  String get wyzieNoMatch;

  /// 自定义字幕：接口地址无效
  ///
  /// In zh, this message translates to:
  /// **'自定义字幕地址无效（需要 http/https 地址）'**
  String get customSubtitleUrlInvalid;

  /// 自定义字幕：响应无法解析（内嵌解析失败原因）
  ///
  /// In zh, this message translates to:
  /// **'无法解析该地址的响应：{message}'**
  String customSubtitleResponseUnparsable(String message);

  /// 自定义字幕解析：不是合法 JSON
  ///
  /// In zh, this message translates to:
  /// **'响应不是合法 JSON'**
  String get customSubtitleResponseNotJson;

  /// 自定义字幕解析：没有字幕列表
  ///
  /// In zh, this message translates to:
  /// **'响应里找不到字幕列表'**
  String get customSubtitleResponseNoList;

  /// 弹弹Play：自建服务器地址无效
  ///
  /// In zh, this message translates to:
  /// **'服务器地址无效（需以 http/https 开头）: {url}'**
  String dandanServerUrlInvalid(String url);

  /// 网络错误：连接超时（FTP / WebDAV 共用）
  ///
  /// In zh, this message translates to:
  /// **'连接超时：服务器无响应，请检查地址与端口'**
  String get networkConnectTimeout;

  /// FTP 错误：拒绝连接
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器拒绝连接（代码 {code}）'**
  String ftpRefusedConnection(String code);

  /// FTP 错误：不支持断点续传
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器不支持断点续传（REST）'**
  String get ftpResumeUnsupported;

  /// FTP 错误：拒绝文件传输
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器拒绝文件传输（代码 {code}）'**
  String ftpTransferRejected(String code);

  /// FTP 错误：根目录不可用
  ///
  /// In zh, this message translates to:
  /// **'FTP 根目录不可用（代码 {code}）'**
  String ftpRootUnavailable(String code);

  /// FTP 错误：登录失败
  ///
  /// In zh, this message translates to:
  /// **'FTP 登录失败，请检查账号密码'**
  String get ftpLoginFailed;

  /// FTP 错误：拒绝二进制模式
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器拒绝二进制模式'**
  String get ftpBinaryModeRejected;

  /// FTP 错误：目录列表失败
  ///
  /// In zh, this message translates to:
  /// **'FTP 目录列表失败（代码 {code}）'**
  String ftpListFailed(String code);

  /// FTP 错误：连接被关闭
  ///
  /// In zh, this message translates to:
  /// **'FTP 连接被服务器关闭'**
  String get ftpConnectionClosed;

  /// FTP 错误：异常响应
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器返回异常响应'**
  String get ftpUnexpectedResponse;

  /// FTP 错误：连接中断
  ///
  /// In zh, this message translates to:
  /// **'FTP 连接中断'**
  String get ftpConnectionInterrupted;

  /// FTP 错误：不支持被动模式
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器不支持被动模式'**
  String get ftpPassiveUnsupported;

  /// FTP 错误：被动模式响应无法解析
  ///
  /// In zh, this message translates to:
  /// **'FTP 被动模式响应无法解析'**
  String get ftpPassiveParseFailed;

  /// WebDAV 错误：目标不是文件
  ///
  /// In zh, this message translates to:
  /// **'文件不存在或不是文件'**
  String get webdavNotAFile;

  /// WebDAV 错误：目标是目录
  ///
  /// In zh, this message translates to:
  /// **'目标是一个目录'**
  String get webdavTargetIsDirectory;

  /// WebDAV 错误：忽略 Range 请求
  ///
  /// In zh, this message translates to:
  /// **'服务器忽略了分段请求，无法精确跳转'**
  String get webdavRangeIgnored;

  /// WebDAV 错误：Range 请求失败
  ///
  /// In zh, this message translates to:
  /// **'分段请求失败（HTTP {status}）'**
  String webdavRangeFailed(String status);

  /// WebDAV 错误：Range 起点不一致
  ///
  /// In zh, this message translates to:
  /// **'服务器返回的分段起点与请求不一致'**
  String get webdavRangeStartMismatch;

  /// WebDAV 错误：下载 401
  ///
  /// In zh, this message translates to:
  /// **'下载失败（HTTP {status}，认证失败）'**
  String webdavDownloadFailedAuth(String status);

  /// WebDAV 错误：目录响应超上限
  ///
  /// In zh, this message translates to:
  /// **'目录过大：响应超过 {mb}MB'**
  String webdavDirectoryTooLarge(String mb);

  /// WebDAV 错误：请求失败
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 请求失败（HTTP {status}）'**
  String webdavRequestFailed(String status);

  /// WebDAV 错误：请求 401
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 请求失败（HTTP {status}，认证失败）'**
  String webdavRequestFailedAuth(String status);

  /// SMB 错误：尚未连接
  ///
  /// In zh, this message translates to:
  /// **'SMB 尚未连接'**
  String get smbNotConnected;

  /// SMB 错误：账号密码错误
  ///
  /// In zh, this message translates to:
  /// **'用户名或密码错误'**
  String get smbAuthFailed;

  /// SMB 错误：拒绝访问
  ///
  /// In zh, this message translates to:
  /// **'拒绝访问（权限不足）'**
  String get smbAccessDenied;

  /// SMB 错误：路径不存在
  ///
  /// In zh, this message translates to:
  /// **'路径不存在'**
  String get smbPathNotFound;

  /// SMB 错误：请求失败
  ///
  /// In zh, this message translates to:
  /// **'SMB 请求失败'**
  String get smbRequestFailed;

  /// 网络路径校验：含 scheme
  ///
  /// In zh, this message translates to:
  /// **'网络路径不能包含 URI scheme'**
  String get netPathScheme;

  /// 网络路径校验：整体过长
  ///
  /// In zh, this message translates to:
  /// **'网络路径过长'**
  String get netPathTooLong;

  /// 网络路径校验：段数过多
  ///
  /// In zh, this message translates to:
  /// **'网络路径段数过多'**
  String get netPathTooManySegments;

  /// 网络路径校验：空段
  ///
  /// In zh, this message translates to:
  /// **'路径段不能为空'**
  String get netPathSegmentEmpty;

  /// 网络路径校验：单段过长
  ///
  /// In zh, this message translates to:
  /// **'路径段过长'**
  String get netPathSegmentTooLong;

  /// 网络路径校验：. / .. 段
  ///
  /// In zh, this message translates to:
  /// **'网络路径不能包含 . 或 ..'**
  String get netPathDotSegment;

  /// 网络路径校验：段内含分隔符
  ///
  /// In zh, this message translates to:
  /// **'路径段不能包含分隔符'**
  String get netPathSegmentSeparator;

  /// 网络路径校验：段内含控制字符
  ///
  /// In zh, this message translates to:
  /// **'路径段不能包含控制字符'**
  String get netPathSegmentControlChar;

  /// 文件操作：源文件缺失
  ///
  /// In zh, this message translates to:
  /// **'源文件不存在或已被移动'**
  String get fileOpSourceMissing;

  /// 文件操作：写入失败（文件名 + 异常）
  ///
  /// In zh, this message translates to:
  /// **'写入失败：{name}（{error}）'**
  String fileOpWriteFailed(String name, String error);

  /// 文件操作：复制成功但删除源失败
  ///
  /// In zh, this message translates to:
  /// **'已复制到目标位置，但删除原文件失败，请手动清理'**
  String get fileOpCopiedButDeleteFailed;

  /// 文件操作：临时文件重命名失败
  ///
  /// In zh, this message translates to:
  /// **'重命名临时文件失败：{error}'**
  String fileOpRenameTempFailed(String error);

  /// 文件操作：目标已存在同名项
  ///
  /// In zh, this message translates to:
  /// **'同目录下已存在同名文件或文件夹'**
  String get fileOpTargetExists;

  /// 文件操作：重命名失败
  ///
  /// In zh, this message translates to:
  /// **'重命名失败：{error}'**
  String fileOpRenameFailed(String error);

  /// 文件操作：文件缺失
  ///
  /// In zh, this message translates to:
  /// **'文件不存在或已被删除'**
  String get fileOpFileMissing;

  /// 文件操作：删除失败
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String fileOpDeleteFailed(String error);

  /// 文件操作：文件夹缺失
  ///
  /// In zh, this message translates to:
  /// **'文件夹不存在或已被删除'**
  String get fileOpFolderMissing;

  /// 文件操作：文件夹内无视频
  ///
  /// In zh, this message translates to:
  /// **'该文件夹内没有可删除的视频文件'**
  String get fileOpNoVideosInFolder;

  /// 文件操作校验：未选目标文件夹
  ///
  /// In zh, this message translates to:
  /// **'请选择目标文件夹'**
  String get fileOpSelectTargetFolder;

  /// 文件操作校验：目标文件夹不可用
  ///
  /// In zh, this message translates to:
  /// **'目标文件夹不存在或不可读'**
  String get fileOpTargetUnreadable;

  /// 文件操作校验：文件夹已在目标目录
  ///
  /// In zh, this message translates to:
  /// **'该文件夹已经在这个目录里了'**
  String get fileOpAlreadyInFolder;

  /// 文件操作校验：视频已在目标目录
  ///
  /// In zh, this message translates to:
  /// **'该视频已经在这个目录里了'**
  String get fileOpAlreadyInFolderVideo;

  /// 文件操作校验：不能移到自己的子目录
  ///
  /// In zh, this message translates to:
  /// **'不能把文件夹复制或移动到它自己的子目录里'**
  String get fileOpIntoItself;

  /// 文件名校验：空
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空'**
  String get fileOpNameEmpty;

  /// 文件名校验：不合法
  ///
  /// In zh, this message translates to:
  /// **'名称不合法'**
  String get fileOpNameInvalid;

  /// 文件名校验：含路径分隔符
  ///
  /// In zh, this message translates to:
  /// **'名称不能包含路径分隔符'**
  String get fileOpNameHasSeparator;

  /// 文件名校验：含非法字符
  ///
  /// In zh, this message translates to:
  /// **'名称不能包含 \\ / : * ? \" < > | 等字符'**
  String get fileOpNameIllegalChars;

  /// 重命名输入校验：扩展名前为空
  ///
  /// In zh, this message translates to:
  /// **'请输入扩展名之前的名称'**
  String get fileOpNameEmptyBeforeExt;

  /// 通用按钮：知道了（杜比视界提示）
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get commonGotIt;

  /// 通用：多条错误拼接用的分隔符（弹幕搜索失败原因）
  ///
  /// In zh, this message translates to:
  /// **'；'**
  String get commonErrorsSeparator;

  /// 均衡器预设：平直
  ///
  /// In zh, this message translates to:
  /// **'平直'**
  String get playerEqualizerPresetFlat;

  /// 均衡器预设：对白增强
  ///
  /// In zh, this message translates to:
  /// **'对白增强'**
  String get playerEqualizerPresetDialogue;

  /// 均衡器预设：电影
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get playerEqualizerPresetCinema;

  /// 均衡器预设：低音震撼
  ///
  /// In zh, this message translates to:
  /// **'低音震撼'**
  String get playerEqualizerPresetBass;

  /// 均衡器预设：高音清晰
  ///
  /// In zh, this message translates to:
  /// **'高音清晰'**
  String get playerEqualizerPresetTreble;

  /// 均衡器预设：柔和夜间
  ///
  /// In zh, this message translates to:
  /// **'柔和夜间'**
  String get playerEqualizerPresetNight;

  /// B 站账号：普通会员
  ///
  /// In zh, this message translates to:
  /// **'普通会员'**
  String get biliVipNormal;

  /// B 站账号：年度大会员
  ///
  /// In zh, this message translates to:
  /// **'年度大会员'**
  String get biliVipAnnual;

  /// B 站账号：大会员
  ///
  /// In zh, this message translates to:
  /// **'大会员'**
  String get biliVipMember;

  /// B 站播放列表：无标题时的集名
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 集'**
  String biliPlaylistEpisode(String index);

  /// 字幕条目：无展示名时的占位
  ///
  /// In zh, this message translates to:
  /// **'未知字幕'**
  String get subtitleUnknownName;

  /// 字幕条目：无语言时的占位
  ///
  /// In zh, this message translates to:
  /// **'未知语言'**
  String get subtitleUnknownLanguage;

  /// 弹幕：内置默认服务器的显示名（仅显示，持久化值不变）
  ///
  /// In zh, this message translates to:
  /// **'弹弹Play（默认）'**
  String get danmakuServerDefaultName;

  /// 弹幕设置：禁止开启自动匹配的短原因
  ///
  /// In zh, this message translates to:
  /// **'请先停用弹弹Play 服务器'**
  String get danmakuServerAutoMatchBlocked;

  /// 弹幕设置：禁止开启自动匹配的完整说明
  ///
  /// In zh, this message translates to:
  /// **'已启用「{name}」服务器时不可开启「切集自动匹配弹幕」，如需使用请先停用该服务器'**
  String danmakuServerAutoMatchBlockedDetail(String name);

  /// 弹幕搜索：无结果
  ///
  /// In zh, this message translates to:
  /// **'未找到相关番剧，请尝试其他关键词'**
  String get danmakuSearchNoResult;

  /// 弹幕搜索：各服务器错误汇总
  ///
  /// In zh, this message translates to:
  /// **'搜索失败：{errors}'**
  String danmakuSearchFailed(String errors);

  /// 弹幕时间轴偏移：0
  ///
  /// In zh, this message translates to:
  /// **'无偏移'**
  String get danmakuOffsetNone;

  /// 弹幕时间轴偏移：正
  ///
  /// In zh, this message translates to:
  /// **'延后 {time}'**
  String danmakuOffsetDelay(String time);

  /// 弹幕时间轴偏移：负
  ///
  /// In zh, this message translates to:
  /// **'提前 {time}'**
  String danmakuOffsetAdvance(String time);

  /// 播放器：音轨回退失败提示
  ///
  /// In zh, this message translates to:
  /// **'当前音轨无法播放，且没有其它可切换的音轨'**
  String get playerAudioFallbackNoTrack;

  /// 播放器：音轨自动回退提示
  ///
  /// In zh, this message translates to:
  /// **'当前音轨无法播放，已自动切换到「{name}」'**
  String playerAudioFallbackSwitched(String name);

  /// 播放器诊断：≥60 秒的时长文本
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分 {seconds} 秒'**
  String playerDiagnosticsDuration(String minutes, String seconds);

  /// 播放器诊断：音画同步（音频超前）
  ///
  /// In zh, this message translates to:
  /// **'{value} 音频超前'**
  String playerDiagnosticsAvsyncAudioAhead(String value);

  /// 播放器诊断：音画同步（视频超前）
  ///
  /// In zh, this message translates to:
  /// **'{value} 视频超前'**
  String playerDiagnosticsAvsyncVideoAhead(String value);

  /// 播放器诊断：丢帧告警
  ///
  /// In zh, this message translates to:
  /// **'已丢帧 {dropped} 帧：渲染跟不上，可尝试降超分档位或改硬解'**
  String playerDiagnosticsWarnDroppedFrames(int dropped);

  /// 播放器诊断：软解告警
  ///
  /// In zh, this message translates to:
  /// **'当前为软解（CPU 解码）：高码率/高分辨率可能掉帧发热'**
  String get playerDiagnosticsWarnSoftwareDecode;

  /// 播放器诊断：音画不同步告警
  ///
  /// In zh, this message translates to:
  /// **'音画不同步：{value}'**
  String playerDiagnosticsWarnAvsync(String value);

  /// 缓存类别：视频列表封面缩略图
  ///
  /// In zh, this message translates to:
  /// **'视频列表封面缩略图'**
  String get cacheCategoryListThumbs;

  /// 缓存类别：网络弹幕缓存
  ///
  /// In zh, this message translates to:
  /// **'网络弹幕缓存'**
  String get cacheCategoryNetworkDanmaku;

  /// 缓存类别：哔哩封面缓存
  ///
  /// In zh, this message translates to:
  /// **'哔哩封面缓存'**
  String get cacheCategoryBiliCovers;

  /// 缓存类别：其他缓存
  ///
  /// In zh, this message translates to:
  /// **'其他缓存'**
  String get cacheCategoryOther;

  /// 检查更新：Release 正文为空时的占位
  ///
  /// In zh, this message translates to:
  /// **'暂无更新说明'**
  String get updateNoNotes;

  /// 关于页：构建信息没有提交哈希
  ///
  /// In zh, this message translates to:
  /// **'本次构建未注入提交哈希（需用 tools/ 里的构建脚本编译）'**
  String get buildInfoNoRevision;

  /// 关于页：复制提交哈希提示
  ///
  /// In zh, this message translates to:
  /// **'已复制 {revision}'**
  String buildInfoCopied(String revision);

  /// 关于页：复制提交哈希提示（工作区有改动）
  ///
  /// In zh, this message translates to:
  /// **'已复制 {revision}（工作区有未提交改动）'**
  String buildInfoCopiedDirty(String revision);

  /// 投屏：设备离线
  ///
  /// In zh, this message translates to:
  /// **'设备已离线'**
  String get castDeviceOffline;

  /// 投屏：本机没有局域网 IPv4
  ///
  /// In zh, this message translates to:
  /// **'未找到局域网 IPv4 地址'**
  String get castNoLanIpv4;

  /// 投屏：待投屏文件不存在
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get castFileMissing;

  /// 播放器：杜比视界引导弹窗标题
  ///
  /// In zh, this message translates to:
  /// **'杜比视界视频'**
  String get dolbyVisionHintTitle;

  /// 播放器：杜比视界引导弹窗正文
  ///
  /// In zh, this message translates to:
  /// **'该视频为杜比视界（Dolby Vision）编码。\n若画面发绿/发紫，请在「播放设置 → 解码」启用 GPU-next 渲染并切换软解；\n若仍无法解决，则该设备可能不支持杜比视界播放。'**
  String get dolbyVisionHintBody;

  /// 播放器：网络弹幕手动下载成功的回执（服务器名由 UI 侧取 l10n 显示名）
  ///
  /// In zh, this message translates to:
  /// **'{anime} · {episode}（{server}）'**
  String playerNetworkDanmakuLoadedManual(
    String anime,
    String episode,
    String server,
  );

  /// 播放器：切集自动匹配命中弹幕的回执（服务器名由 UI 侧取 l10n 显示名）
  ///
  /// In zh, this message translates to:
  /// **'{anime} {episode}（{server}）'**
  String playerNetworkDanmakuLoadedAuto(
    String anime,
    String episode,
    String server,
  );

  /// 播放器 · 网络弹幕集数面板：自动定位失败（识别不出集数）
  ///
  /// In zh, this message translates to:
  /// **'未能从文件名识别集数，可用上方输入框直接跳转'**
  String get playerDanmakuLocateNoEpisode;

  /// 播放器 · 网络弹幕集数面板：自动定位失败（集列表里没有该集）
  ///
  /// In zh, this message translates to:
  /// **'未找到第 {number} 集，可用上方输入框直接跳转'**
  String playerDanmakuLocateEpisodeMissing(String number);

  /// 隐私弹窗：同意复选框文案
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意以上隐私政策'**
  String get legalAgreeCheckbox;

  /// 隐私弹窗：不同意（退出应用）按钮
  ///
  /// In zh, this message translates to:
  /// **'不同意并退出'**
  String get legalDisagreeExit;

  /// 隐私弹窗：倒计时中的同意按钮
  ///
  /// In zh, this message translates to:
  /// **'同意并继续 ({seconds} 秒)'**
  String legalAgreeWithCountdown(String seconds);

  /// 隐私弹窗：倒计时结束后的同意按钮
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get legalAgreeContinue;

  /// 通用：并列项之间的分隔符（弹幕屏蔽词 / 诊断项 / 字幕来源语言格式编码的摘要）
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get commonListSeparator;

  /// 通用：给一段内容加「标签：」前缀（字幕 ASS 限制说明）
  ///
  /// In zh, this message translates to:
  /// **'{label}：'**
  String commonLabelWithColon(String label);

  /// 媒体信息：复制出的文本里给流分组加方括号标题
  ///
  /// In zh, this message translates to:
  /// **'【{title}】'**
  String mediaInfoStreamsGroupTitle(String title);

  /// 字体设置页：字体效果预览样例（中文侧顺带展示全角标点字形覆盖）
  ///
  /// In zh, this message translates to:
  /// **'0123456789，。！？；：“”（）【】…·'**
  String get settingsFontPreviewSample;

  /// 文件操作：目标位置与最终条目名（「已移动到 X」的 X）
  ///
  /// In zh, this message translates to:
  /// **'{dest}：{target}'**
  String folderActionDestWithTarget(String dest, String target);

  /// 文件操作：条目名 + 校验失败原因（批量移动/复制预校验）
  ///
  /// In zh, this message translates to:
  /// **'「{name}」{reason}'**
  String fileOpItemIssue(String name, String reason);

  /// 文件操作：条目名 + 失败原因（批量移动/复制/删除的失败汇总）
  ///
  /// In zh, this message translates to:
  /// **'{name}：{reason}'**
  String fileOpItemFailed(String name, String reason);

  /// 通用颜色名：青色（主题色 / 字幕颜色预设共用）
  ///
  /// In zh, this message translates to:
  /// **'青色'**
  String get commonColorCyan;

  /// 通用颜色名：绿色（主题色 / 字幕颜色预设共用）
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get commonColorGreen;

  /// 通用颜色名：黄色（主题色 / 字幕颜色预设共用）
  ///
  /// In zh, this message translates to:
  /// **'黄色'**
  String get commonColorYellow;

  /// 通用：默认（解码档位 / 字体字重等「未自定义」状态）
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get commonDefault;

  /// 错误日志：删除单个日志的二次确认正文
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？'**
  String commonDeleteConfirm(String name);

  /// 删除服务器二次确认
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？此操作不可撤销。'**
  String commonDeleteConfirmIrreversible(String name);

  /// 解码器详情页：采样率胶囊分组标题
  ///
  /// In zh, this message translates to:
  /// **'采样率'**
  String get mediaInfoSampleRates;

  /// 设置页「语言」组（在弹幕组下方、下载组上方）
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get commonLanguage;

  /// No description provided for @downloadManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get downloadManagerTitle;

  /// No description provided for @biliVideoDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'视频下载'**
  String get biliVideoDownloadTitle;

  /// No description provided for @biliDanmakuDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹幕下载'**
  String get biliDanmakuDownloadTitle;

  /// No description provided for @biliSubtitleDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'字幕下载'**
  String get biliSubtitleDownloadTitle;

  /// 播放器「更多」面板 / 清晰度面板：清晰度
  ///
  /// In zh, this message translates to:
  /// **'清晰度'**
  String get commonQuality;

  /// 播放器字幕延迟面板：带正负号的延迟读数
  ///
  /// In zh, this message translates to:
  /// **'{value} 秒'**
  String playerDelaySeconds(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
