/// 表（枚举 / 映射表）→ 文案 的 **UI 侧**映射。
///
/// 约定（见 `杂项文件/多语言支持方案/02-实施方案.md` §1.9）：
/// - `models/`、`utils/`、`services/` 里**不许** import l10n，所以中文标签一律在
///   本文件用 `AppLocalizations` 现取；
/// - 命名 `<模块><表名>Label`，`switch` 用表达式形式，穷尽性由 `flutter analyze` 兜住；
/// - 枚举的**顺序与名字一个都不许动**（老存档按 index / id 持久化）。
library;

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/audio_track.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/models/bilibili_user.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/models/danmaku_color_mode.dart';
import 'package:moumou/models/danmaku_font_mode.dart';
import 'package:moumou/models/danmaku_server.dart';
import 'package:moumou/models/equalizer_preset.dart';
import 'package:moumou/models/player_action.dart';
import 'package:moumou/models/player_diagnostics.dart';
import 'package:moumou/models/player_loop.dart';
import 'package:moumou/models/playlist_sort.dart';
import 'package:moumou/models/subtitle_dir.dart';
import 'package:moumou/models/subtitle_entry.dart';
import 'package:moumou/models/super_resolution_mode.dart';
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/services/audio_service.dart';
import 'package:moumou/services/cache_manager_service.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/subtitle/subtitle_source_settings.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/services/wallpaper_settings.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:moumou/utils/danmaku_episode.dart';
import 'package:moumou/utils/danmaku_timeline.dart';
import 'package:moumou/utils/network_sort.dart';
import 'package:moumou/utils/player_diagnostics.dart';
import 'package:moumou/utils/retry_policy.dart';

/// 主题模式（外观页「主题模式」）
String appThemeModeLabel(AppLocalizations l10n, AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => l10n.settingsThemeModeSystem,
  AppThemeMode.light => l10n.settingsThemeModeLight,
  AppThemeMode.dark => l10n.settingsThemeModeDark,
  AppThemeMode.amoled => l10n.settingsThemeModeAmoled,
};

/// 预设主题色名称：按 `ThemeController.presetColors` 的**下标**取文案
/// （下标即语义，顺序不许调整）。调用方只遍历该列表，不会越界。
String themeColorLabel(AppLocalizations l10n, int index) => switch (index) {
  0 => l10n.settingsThemeColorSkyBlue,
  1 => l10n.settingsThemeColorBlue,
  2 => l10n.settingsThemeColorLightBlue,
  3 => l10n.settingsThemeColorIndigo,
  4 => l10n.settingsThemeColorTeal,
  5 => l10n.settingsThemeColorCyan,
  6 => l10n.settingsThemeColorGreen,
  7 => l10n.settingsThemeColorMint,
  8 => l10n.settingsThemeColorLightGreen,
  9 => l10n.settingsThemeColorLime,
  10 => l10n.settingsThemeColorYellow,
  11 => l10n.settingsThemeColorAmber,
  12 => l10n.settingsThemeColorOrange,
  13 => l10n.settingsThemeColorDeepOrange,
  14 => l10n.settingsThemeColorRed,
  15 => l10n.settingsThemeColorPink,
  16 => l10n.settingsThemeColorHotPink,
  17 => l10n.settingsThemeColorViolet,
  18 => l10n.settingsThemeColorPurple,
  19 => l10n.settingsThemeColorDeepPurple,
  20 => l10n.settingsThemeColorBlueGrey,
  21 => l10n.settingsThemeColorBrown,
  22 => l10n.settingsThemeColorGrey,
  _ => '',
};

/// 调色板风格名称（外观页「调色板风格」网格）
String paletteVariantLabel(
  AppLocalizations l10n,
  FlexSchemeVariant variant,
) => switch (variant) {
  FlexSchemeVariant.tonalSpot => l10n.settingsPaletteTonalSpot,
  FlexSchemeVariant.fidelity => l10n.settingsPaletteFidelity,
  FlexSchemeVariant.monochrome => l10n.settingsPaletteMonochrome,
  FlexSchemeVariant.neutral => l10n.settingsPaletteNeutral,
  FlexSchemeVariant.vibrant => l10n.settingsPaletteVibrant,
  FlexSchemeVariant.expressive => l10n.settingsPaletteExpressive,
  FlexSchemeVariant.content => l10n.settingsPaletteContent,
  FlexSchemeVariant.rainbow => l10n.settingsPaletteRainbow,
  FlexSchemeVariant.fruitSalad => l10n.settingsPaletteFruitSalad,
  FlexSchemeVariant.candyPop => l10n.settingsPaletteCandyPop,
  FlexSchemeVariant.chroma => l10n.settingsPaletteChroma,
  FlexSchemeVariant.highContrast => l10n.settingsPaletteHighContrast,
  FlexSchemeVariant.jolly => l10n.settingsPaletteJolly,
  FlexSchemeVariant.material => l10n.settingsPaletteMaterial,
  FlexSchemeVariant.material3Legacy => l10n.settingsPaletteMaterial3Legacy,
  FlexSchemeVariant.oneHue => l10n.settingsPaletteOneHue,
  FlexSchemeVariant.soft => l10n.settingsPaletteSoft,
  FlexSchemeVariant.ultraContrast => l10n.settingsPaletteUltraContrast,
  FlexSchemeVariant.vivid => l10n.settingsPaletteVivid,
  FlexSchemeVariant.vividBackground => l10n.settingsPaletteVividBackground,
  FlexSchemeVariant.vividSurfaces => l10n.settingsPaletteVividSurfaces,
};

/// 双击手势模式（播放器设置）
String playerDoubleTapModeLabel(AppLocalizations l10n, DoubleTapMode mode) =>
    switch (mode) {
      DoubleTapMode.pause => l10n.playerDoubleTapPause,
      DoubleTapMode.seek => l10n.playerDoubleTapSeek,
      DoubleTapMode.mixed => l10n.playerDoubleTapMixed,
    };

/// 视频方向模式（播放器设置 · 视频方向）
String playerOrientationModeLabel(
  AppLocalizations l10n,
  VideoOrientationMode mode,
) => switch (mode) {
  VideoOrientationMode.auto => l10n.playerOrientationAuto,
  VideoOrientationMode.portrait => l10n.playerOrientationPortrait,
  VideoOrientationMode.landscape => l10n.playerOrientationLandscape,
};

/// 画面比例（播放器 · 画面比例面板）
///
/// `4:3` / `16:9` 两个比例项不是文案（就是比例本身），直接给原样字符串。
String playerVideoFitLabel(AppLocalizations l10n, PlayerVideoFit fit) =>
    switch (fit) {
      PlayerVideoFit.fill => l10n.playerVideoFitFill,
      PlayerVideoFit.contain => l10n.playerVideoFitContain,
      PlayerVideoFit.cover => l10n.playerVideoFitCover,
      PlayerVideoFit.fitWidth => l10n.playerVideoFitFitWidth,
      PlayerVideoFit.fitHeight => l10n.playerVideoFitFitHeight,
      PlayerVideoFit.none => l10n.playerVideoFitNone,
      PlayerVideoFit.scaleDown => l10n.playerVideoFitScaleDown,
      PlayerVideoFit.ratio4x3 => '4:3',
      PlayerVideoFit.ratio16x9 => '16:9',
    };

/// 播放器顶栏可自定义按钮动作名
String playerTopActionLabel(AppLocalizations l10n, PlayerTopAction action) =>
    switch (action) {
      PlayerTopAction.subtitle => l10n.playerActionSubtitle,
      PlayerTopAction.danmaku => l10n.commonDanmaku,
      PlayerTopAction.audio => l10n.playerActionAudio,
      PlayerTopAction.aspect => l10n.playerActionAspect,
      PlayerTopAction.decode => l10n.playerActionDecode,
      PlayerTopAction.chapter => l10n.playerActionChapter,
      PlayerTopAction.cast => l10n.playerActionCast,
      PlayerTopAction.pip => l10n.playerActionPip,
      PlayerTopAction.listen => l10n.playerActionListen,
      PlayerTopAction.loop => l10n.playerActionLoop,
      PlayerTopAction.introOutro => l10n.playerActionIntroOutro,
      PlayerTopAction.diagnostics => l10n.playerActionDiagnostics,
      PlayerTopAction.equalizer => l10n.playerActionEqualizer,
    };

// ── 首页排序 / 字段（ViewSettings）──────────────────────────────

/// 排序维度（文件夹列表）
String sortFieldLabel(AppLocalizations l10n, SortField field) => switch (field) {
  SortField.name => l10n.commonName,
  SortField.date => l10n.commonDate,
  SortField.size => l10n.commonSize,
  SortField.count => l10n.commonCount,
};

/// 排序方向
String sortOrderLabel(AppLocalizations l10n, SortOrder order) => switch (order) {
  SortOrder.asc => l10n.commonAscending,
  SortOrder.desc => l10n.commonDescending,
};

/// 视图模式（树状 / 列表）
String viewModeLabel(AppLocalizations l10n, ViewMode mode) => switch (mode) {
  ViewMode.tree => l10n.viewModeTree,
  ViewMode.list => l10n.viewModeList,
};

/// 文件夹列表可显示字段名
String folderFieldLabel(AppLocalizations l10n, FolderField field) =>
    switch (field) {
      FolderField.path => l10n.commonPath,
      FolderField.count => l10n.commonCount,
      FolderField.size => l10n.commonSize,
      FolderField.date => l10n.commonDate,
    };

/// 视频列表可显示字段名
String videoFieldLabel(AppLocalizations l10n, VideoField field) =>
    switch (field) {
      VideoField.duration => l10n.commonDuration,
      VideoField.size => l10n.commonSize,
      VideoField.date => l10n.commonDate,
      VideoField.resolution => l10n.commonResolution,
      VideoField.progress => l10n.commonProgress,
      VideoField.subtitle => l10n.commonSubtitleIndicator,
      VideoField.frameRate => l10n.commonFrameRate,
      VideoField.fullName => l10n.commonFullName,
    };

/// 视频列表排序维度
String videoSortFieldLabel(AppLocalizations l10n, VideoSortField field) =>
    switch (field) {
      VideoSortField.name => l10n.commonName,
      VideoSortField.date => l10n.commonDate,
      VideoSortField.size => l10n.commonSize,
      VideoSortField.duration => l10n.commonDuration,
    };

// ── 超分辨率（SuperResolutionService）─────────────────────────

/// 超分质量档名称
String superResolutionQualityLabel(
  AppLocalizations l10n,
  SuperResolutionQuality quality,
) => switch (quality) {
  SuperResolutionQuality.fast => l10n.superResolutionQualityFast,
  SuperResolutionQuality.balanced => l10n.superResolutionQualityBalanced,
  SuperResolutionQuality.high => l10n.superResolutionQualityHigh,
};

/// 超分质量档说明
String superResolutionQualityDescription(
  AppLocalizations l10n,
  SuperResolutionQuality quality,
) => switch (quality) {
  SuperResolutionQuality.fast => l10n.superResolutionQualityFastDesc,
  SuperResolutionQuality.balanced => l10n.superResolutionQualityBalancedDesc,
  SuperResolutionQuality.high => l10n.superResolutionQualityHighDesc,
};

/// Anime4K 模式名称
String superResolutionModeLabel(
  AppLocalizations l10n,
  SuperResolutionMode mode,
) => switch (mode) {
  SuperResolutionMode.off => l10n.commonOff,
  SuperResolutionMode.a => l10n.superResolutionModeA,
  SuperResolutionMode.b => l10n.superResolutionModeB,
  SuperResolutionMode.c => l10n.superResolutionModeC,
  SuperResolutionMode.aPlus => l10n.superResolutionModeAPlus,
  SuperResolutionMode.bPlus => l10n.superResolutionModeBPlus,
  SuperResolutionMode.cPlus => l10n.superResolutionModeCPlus,
};

/// Anime4K 模式说明
String superResolutionModeDescription(
  AppLocalizations l10n,
  SuperResolutionMode mode,
) => switch (mode) {
  SuperResolutionMode.off => l10n.superResolutionModeOffDesc,
  SuperResolutionMode.a => l10n.superResolutionModeADesc,
  SuperResolutionMode.b => l10n.superResolutionModeBDesc,
  SuperResolutionMode.c => l10n.superResolutionModeCDesc,
  SuperResolutionMode.aPlus => l10n.superResolutionModeAPlusDesc,
  SuperResolutionMode.bPlus => l10n.superResolutionModeBPlusDesc,
  SuperResolutionMode.cPlus => l10n.superResolutionModeCPlusDesc,
};

// ── 解码（DecodeSettings）────────────────────────────────────

/// 解码档位名称
String decodeModeLabel(AppLocalizations l10n, DecodeMode mode) => switch (mode) {
  DecodeMode.autoSafe => l10n.commonAuto,
  DecodeMode.hwCopy => l10n.decodeModeHwCopy,
  DecodeMode.hwPlus => l10n.decodeModeHwPlus,
  DecodeMode.sw => l10n.decodeModeSw,
};

/// 解码档位说明
String decodeModeDescription(AppLocalizations l10n, DecodeMode mode) =>
    switch (mode) {
      DecodeMode.autoSafe => l10n.decodeModeAutoSafeDesc,
      DecodeMode.hwCopy => l10n.decodeModeHwCopyDesc,
      DecodeMode.hwPlus => l10n.decodeModeHwPlusDesc,
      DecodeMode.sw => l10n.decodeModeSwDesc,
    };

/// 解码性能预设名称
String decodePresetLabel(AppLocalizations l10n, DecodePreset preset) =>
    switch (preset) {
      DecodePreset.fast => l10n.decodePresetFast,
      DecodePreset.standard => l10n.decodePresetStandard,
      DecodePreset.highQuality => l10n.decodePresetHighQuality,
      DecodePreset.gpuHq => l10n.decodePresetGpuHq,
      DecodePreset.lowLatency => l10n.decodePresetLowLatency,
      DecodePreset.swFast => l10n.decodePresetSwFast,
    };

/// 解码性能预设说明
String decodePresetDescription(AppLocalizations l10n, DecodePreset preset) =>
    switch (preset) {
      DecodePreset.fast => l10n.decodePresetFastDesc,
      DecodePreset.standard => l10n.decodePresetStandardDesc,
      DecodePreset.highQuality => l10n.decodePresetHighQualityDesc,
      DecodePreset.gpuHq => l10n.decodePresetGpuHqDesc,
      DecodePreset.lowLatency => l10n.decodePresetLowLatencyDesc,
      DecodePreset.swFast => l10n.decodePresetSwFastDesc,
    };

// ── 章节跳段 / 播放列表排序 ───────────────────────────────────

/// 章节跳段类型胶囊文案
String chapterSkipTypeLabel(AppLocalizations l10n, ChapterSkipType type) =>
    switch (type) {
      ChapterSkipType.intro => l10n.chapterSkipIntro,
      ChapterSkipType.recap => l10n.chapterSkipRecap,
      ChapterSkipType.outro => l10n.chapterSkipOutro,
      ChapterSkipType.credits => l10n.chapterSkipCredits,
      ChapterSkipType.coldOpen => l10n.chapterSkipColdOpen,
      ChapterSkipType.preview => l10n.chapterSkipPreview,
    };

/// 播放列表排序模式名称
String playlistSortModeLabel(
  AppLocalizations l10n,
  PlaylistSortMode mode,
) => switch (mode) {
  PlaylistSortMode.nameAsc => l10n.playlistSortNameAsc,
  PlaylistSortMode.nameDesc => l10n.playlistSortNameDesc,
  PlaylistSortMode.dateAsc => l10n.playlistSortDateAsc,
  PlaylistSortMode.dateDesc => l10n.playlistSortDateDesc,
};

// ── 字幕轨道 / 样式 ──────────────────────────────────────────

/// 字幕对齐名称
String subtitleAlignLabel(AppLocalizations l10n, SubtitleAlign align) =>
    switch (align) {
      SubtitleAlign.center => l10n.commonCenter,
      SubtitleAlign.left => l10n.subtitleAlignLeft,
      SubtitleAlign.right => l10n.subtitleAlignRight,
    };

/// 字幕描边/背景模式名称
String subtitleBorderStyleLabel(
  AppLocalizations l10n,
  SubtitleBorderStyle style,
) => switch (style) {
  SubtitleBorderStyle.none => l10n.subtitleBorderNone,
  SubtitleBorderStyle.outline => l10n.subtitleBorderOutline,
  SubtitleBorderStyle.box => l10n.subtitleBorderBox,
};

/// 字幕颜色预设名：按 [SubtitlePresetColor.hex] 取（大写，带 `#`）
String subtitlePresetColorLabel(AppLocalizations l10n, String hex) =>
    switch (hex.toUpperCase()) {
      '#FFFFFF' => l10n.subtitlePresetWhite,
      '#FFEB3B' => l10n.subtitlePresetYellow,
      '#4DD0E1' => l10n.subtitlePresetCyan,
      '#81C784' => l10n.subtitlePresetGreen,
      '#000000' => l10n.subtitlePresetBlack,
      '#80000000' => l10n.subtitlePresetTranslucentBlack,
      '#FF000000' => l10n.subtitlePresetOpaqueBlack,
      '#80FFFFFF' => l10n.subtitlePresetTranslucentWhite,
      '#801A2332' => l10n.subtitlePresetTranslucentBlue,
      _ => hex.toUpperCase(),
    };

/// 字幕轨展示名：标题 → 语言 → 「轨道 N」兜底
/// （模型的 [SubtitleTrack.displayTitle] 是纯数据，空串表示要走兜底）
String subtitleTrackDisplayName(AppLocalizations l10n, SubtitleTrack track) =>
    track.displayTitle.isEmpty
        ? l10n.subtitleTrackFallbackName(track.id)
        : track.displayTitle;

/// 字幕轨在面板中的显示名：展示名 + 外挂标记 + 格式后缀，
/// 如「简体中文 · 外挂 · ass」（原 `models/subtitle_track.dart` 的纯函数，
/// 因需要 l10n 而移到 UI 侧映射层）。
String subtitleTrackLabel(AppLocalizations l10n, SubtitleTrack track) {
  final parts = <String>[subtitleTrackDisplayName(l10n, track)];
  if (track.external) parts.add(l10n.commonExternalTag);
  if (track.codec != null && track.codec!.trim().isNotEmpty) {
    parts.add(track.codec!.trim());
  }
  return parts.join(' · ');
}

// ── 音轨（AudioTrack / AudioChannels）────────────────────────

/// 音频声道名称
String audioChannelsLabel(AppLocalizations l10n, AudioChannels channels) =>
    switch (channels) {
      AudioChannels.auto => l10n.commonAuto,
      AudioChannels.autoSafe => l10n.audioChannelAutoSafe,
      AudioChannels.mono => l10n.audioChannelMono,
      AudioChannels.stereo => l10n.audioChannelStereo,
      AudioChannels.reverseStereo => l10n.audioChannelReverseStereo,
    };

/// 音轨展示名：标题 → 语言 → 「音轨 N」兜底
/// （模型的 [AudioTrack.displayTitle] 是纯数据，空串表示要走兜底）
String audioTrackDisplayName(AppLocalizations l10n, AudioTrack track) =>
    track.displayTitle.isEmpty
        ? l10n.audioTrackFallbackName(track.id)
        : track.displayTitle;

/// 音轨在面板中的显示名：展示名 + 外挂标记 + 格式后缀（如「国语 · 外挂 · aac」）
String audioTrackLabel(AppLocalizations l10n, AudioTrack track) {
  final parts = <String>[audioTrackDisplayName(l10n, track)];
  if (track.external) parts.add(l10n.commonExternalTag);
  if (track.codec != null && track.codec!.trim().isNotEmpty) {
    parts.add(track.codec!.trim());
  }
  return parts.join(' · ');
}

// ── 网络存储：排序 / 超时分级 ─────────────────────────────────

/// 网络目录排序字段名（只有名称/日期，与 `common*` 复用）
String networkSortFieldLabel(
  AppLocalizations l10n,
  NetworkSortField field,
) => switch (field) {
  NetworkSortField.name => l10n.commonName,
  NetworkSortField.date => l10n.commonDate,
};

/// 网络目录排序方向名
String networkSortOrderLabel(
  AppLocalizations l10n,
  NetworkSortOrder order,
) => switch (order) {
  NetworkSortOrder.asc => l10n.commonAscending,
  NetworkSortOrder.desc => l10n.commonDescending,
};

/// 网络请求超时分级档位名
String networkTimeoutTierLabel(
  AppLocalizations l10n,
  NetworkTimeoutTier tier,
) => switch (tier) {
  NetworkTimeoutTier.api => l10n.networkTierApi,
  NetworkTimeoutTier.text => l10n.networkTierText,
  NetworkTimeoutTier.download => l10n.networkTierDownload,
  NetworkTimeoutTier.stream => l10n.networkTierStream,
};

// ── 弹幕颜色/字体 · 循环播放 · 字幕目录排序 · 壁纸 · 字幕来源 ──

/// 弹幕颜色三态名称
String danmakuColorModeLabel(
  AppLocalizations l10n,
  DanmakuColorMode mode,
) => switch (mode) {
  DanmakuColorMode.source => l10n.danmakuColorModeSource,
  DanmakuColorMode.random => l10n.danmakuColorModeRandom,
  DanmakuColorMode.fixed => l10n.danmakuColorModeFixed,
};

/// 弹幕字体三态名称
String danmakuFontModeLabel(AppLocalizations l10n, DanmakuFontMode mode) =>
    switch (mode) {
      DanmakuFontMode.followSystem => l10n.danmakuFontModeFollowSystem,
      DanmakuFontMode.followApp => l10n.danmakuFontModeFollowApp,
      DanmakuFontMode.custom => l10n.danmakuFontModeCustom,
    };

/// 循环播放模式名称（关闭复用 commonOff）
String loopModeLabel(AppLocalizations l10n, LoopMode mode) => switch (mode) {
  LoopMode.off => l10n.commonOff,
  LoopMode.loopAll => l10n.loopModeLoopAll,
  LoopMode.repeatOne => l10n.loopModeRepeatOne,
};

/// 字幕目录排序字段名
String subtitleDirSortLabel(AppLocalizations l10n, SubtitleDirSort sort) =>
    switch (sort) {
      SubtitleDirSort.name => l10n.commonName,
      SubtitleDirSort.size => l10n.commonSize,
      SubtitleDirSort.date => l10n.commonDate,
    };

/// 壁纸缩放模式名称
String wallpaperScaleModeLabel(
  AppLocalizations l10n,
  WallpaperScaleMode mode,
) => switch (mode) {
  WallpaperScaleMode.fit => l10n.wallpaperScaleFit,
  WallpaperScaleMode.fill => l10n.wallpaperScaleFill,
};

/// 影视字幕下载来源名称
String subtitleSourceKindLabel(
  AppLocalizations l10n,
  SubtitleSourceKind kind,
) => switch (kind) {
  SubtitleSourceKind.wyzie => l10n.subtitleSourceWyzie,
  SubtitleSourceKind.custom => l10n.subtitleSourceCustom,
};

/// App 字体设置页字重档位名。
///
/// `index` 为 `AppFontSettings.fontWeightIndex`：**-1 = 未自定义（显示"默认"）**，
/// 0..8 依次对应 w100~w900（与弹幕字重滑杆档位一致）——档位顺序即语义，
/// 不许调整。越界（理论上不会发生：滑杆 min/max 已限定）回落"默认"。
String appFontWeightLabel(AppLocalizations l10n, int index) => switch (index) {
  0 => l10n.settingsFontWeightThin,
  1 => l10n.settingsFontWeightExtraLight,
  2 => l10n.settingsFontWeightLight,
  3 => l10n.settingsFontWeightRegular,
  4 => l10n.settingsFontWeightMedium,
  5 => l10n.settingsFontWeightSemiBold,
  6 => l10n.settingsFontWeightBold,
  7 => l10n.settingsFontWeightExtraBold,
  8 => l10n.settingsFontWeightBlack,
  _ => l10n.settingsFontWeightNone,
};

// ── 阶段 6：服务 / 模型 / 工具层产出的显示名与结果文案 ──────────

/// 均衡器预设名：按 [EqualizerPreset.id] 映射（id 是持久化用的稳定标识，
/// 未知 id 原样显示，不做兜底文案）。
String equalizerPresetLabel(AppLocalizations l10n, EqualizerPreset preset) =>
    switch (preset.id) {
      'flat' => l10n.playerEqualizerPresetFlat,
      'dialogue' => l10n.playerEqualizerPresetDialogue,
      'cinema' => l10n.playerEqualizerPresetCinema,
      'bass' => l10n.playerEqualizerPresetBass,
      'treble' => l10n.playerEqualizerPresetTreble,
      'night' => l10n.playerEqualizerPresetNight,
      _ => preset.id,
    };

/// B 站账号会员状态名（服务端 `vip_label.text` 优先，属数据不翻译）
String biliUserVipLabel(AppLocalizations l10n, BiliUser user) {
  final isVip = user.vipStatus > 0 && user.vipType > 0;
  if (!isVip) return l10n.biliVipNormal;
  if (user.vipLabelText.isNotEmpty) return user.vipLabelText;
  return user.vipType >= 2 ? l10n.biliVipAnnual : l10n.biliVipMember;
}

/// 番剧播放列表条目名（长短标题都缺失时回落「第 N 集」）
String biliPlaylistItemTitle(AppLocalizations l10n, BiliPlaylistItem item) =>
    item.title.isNotEmpty ? item.title : l10n.biliPlaylistEpisode('${item.index}');

/// 缓存类别名：按 [CacheCategory.key] 映射（key 是 ASCII 稳定标识）
String cacheCategoryLabel(AppLocalizations l10n, CacheCategory category) =>
    switch (category.key) {
      'listThumbs' => l10n.cacheCategoryListThumbs,
      'networkDanmaku' => l10n.cacheCategoryNetworkDanmaku,
      'biliCovers' => l10n.cacheCategoryBiliCovers,
      'other' => l10n.cacheCategoryOther,
      _ => category.key,
    };

/// 弹幕服务器显示名：内置默认服务器走 l10n，自建服务器用用户填的名字
/// （持久化里存的仍是原值，见 `DanmakuServer.defaultName`）
String danmakuServerDisplayName(AppLocalizations l10n, DanmakuServer server) =>
    server.isDefault ? l10n.danmakuServerDefaultName : server.name;

/// 字幕条目展示名（缺失占位）
String subtitleEntryDisplayName(AppLocalizations l10n, SubtitleEntry entry) =>
    entry.name.isNotEmpty ? entry.name : l10n.subtitleUnknownName;

/// 字幕条目语言展示名（缺失占位）
String subtitleEntryDisplayLanguage(AppLocalizations l10n, SubtitleEntry entry) =>
    entry.language.isNotEmpty ? entry.language : l10n.subtitleUnknownLanguage;

/// 字幕条目来源展示名：自定义源在服务层存 ASCII 码 `custom`
String subtitleEntrySourceLabel(AppLocalizations l10n, SubtitleEntry entry) =>
    entry.source == 'custom' ? l10n.commonCustom : entry.source;

/// 弹幕时间轴偏移文本（0 → 无偏移；正延后 / 负提前）
String danmakuOffsetText(AppLocalizations l10n, double value) {
  if (value == 0) return l10n.danmakuOffsetNone;
  final time = formatDanmakuOffsetDuration(value);
  return value > 0
      ? l10n.danmakuOffsetDelay(time)
      : l10n.danmakuOffsetAdvance(time);
}

/// 诊断：秒 → 文本（<60 秒保留一位小数，≥60 秒走 l10n 的「X 分 Y 秒」）
String diagnosticSecondsText(AppLocalizations l10n, double? seconds) {
  if (seconds == null || seconds < 0) return kDiagnosticPlaceholder;
  if (seconds < 60) return '${seconds.toStringAsFixed(1)} s';
  final m = seconds ~/ 60;
  final s = (seconds - m * 60).toStringAsFixed(0);
  return l10n.playerDiagnosticsDuration('$m', s);
}

/// 诊断：音画同步偏差（秒）→ `+12 ms 音频超前` / `-8 ms 视频超前`
String diagnosticAvsyncText(AppLocalizations l10n, double? seconds) {
  if (seconds == null) return kDiagnosticPlaceholder;
  final ms = seconds * 1000;
  final value = '${ms >= 0 ? '+' : '-'}${ms.abs().toStringAsFixed(0)} ms';
  return ms >= 0
      ? l10n.playerDiagnosticsAvsyncAudioAhead(value)
      : l10n.playerDiagnosticsAvsyncVideoAhead(value);
}

/// 诊断：健康提示（按优先级返回需要用户注意的现象，无异常返回空列表）。
///
/// 原 `utils/player_diagnostics.dart` 的纯函数版因需要 l10n 而移到本层；
/// 阈值 [kAvsyncWarnSec] 仍是 utils 的纯常量。
List<String> diagnosticWarnings(
  AppLocalizations l10n,
  PlayerDiagnosticsSnapshot s,
) {
  final warnings = <String>[];
  final dropped = s.droppedFrames ?? 0;
  if (dropped > 0) {
    warnings.add(l10n.playerDiagnosticsWarnDroppedFrames(dropped));
  }
  if (s.hwdec.trim().toLowerCase() == 'no') {
    warnings.add(l10n.playerDiagnosticsWarnSoftwareDecode);
  }
  final avsync = s.avsync;
  if (avsync != null && avsync.abs() > kAvsyncWarnSec) {
    warnings.add(
      l10n.playerDiagnosticsWarnAvsync(diagnosticAvsyncText(l10n, avsync)),
    );
  }
  return warnings;
}

/// 音轨自动回退原因文案（[fallback] 为空表示无路可退）
String audioFallbackReasonText(
  AppLocalizations l10n,
  AudioFallbackReason reason,
  AudioTrack? fallback,
) =>
    switch (reason) {
      AudioFallbackReason.noAlternative => l10n.playerAudioFallbackNoTrack,
      AudioFallbackReason.switched => l10n.playerAudioFallbackSwitched(
          fallback == null ? '' : audioTrackDisplayName(l10n, fallback),
        ),
    };

/// 网络弹幕集数面板「自动定位失败」的提示（[number] 为识别出的集数，可空）
String danmakuEpisodeLocateHint(
  AppLocalizations l10n,
  DanmakuEpisodeLocateHint hint,
  double? number,
) =>
    switch (hint) {
      DanmakuEpisodeLocateHint.noEpisodeNumber =>
        l10n.playerDanmakuLocateNoEpisode,
      DanmakuEpisodeLocateHint.episodeMissing =>
        l10n.playerDanmakuLocateEpisodeMissing('${number?.toInt()}'),
    };
