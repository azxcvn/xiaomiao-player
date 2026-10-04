import 'package:flutter/material.dart';

/// 双击手势模式（可在「播放器设置」中自定义）
///
/// 名称在 `lib/l10n/label_maps.dart` 的 [playerDoubleTapModeLabel]。
/// **顺序即持久化语义**，不许调整。
enum DoubleTapMode {
  pause,
  seek,
  mixed,
}

/// 视频方向模式（设置-播放器设置-视频方向，工作.md 第 5 点）：
/// - [auto]：按视频本身的方向自动横屏/竖屏播放；
/// - [portrait]：无论视频方向，统一竖屏播放；
/// - [landscape]：无论视频方向，统一横屏播放。
///
/// 名称在 `lib/l10n/label_maps.dart` 的 [playerOrientationModeLabel]。
enum VideoOrientationMode {
  auto,
  portrait,
  landscape,
}

/// 画面比例（对齐 PiliPlus 的 VideoFitType）：
/// 通过 Video 组件的 [BoxFit] 与 [aspectRatio] 实现，无需 mpv 属性。
///
/// 名称在 `lib/l10n/label_maps.dart` 的 [playerVideoFitLabel]（`4:3` / `16:9`
/// 两个比例项不自造文案，映射里直接用原样字符串）。
enum PlayerVideoFit {
  fill(BoxFit.fill, null),
  contain(BoxFit.contain, null),
  cover(BoxFit.cover, null),
  fitWidth(BoxFit.fitWidth, null),
  fitHeight(BoxFit.fitHeight, null),
  none(BoxFit.none, null),
  scaleDown(BoxFit.scaleDown, null),
  ratio4x3(BoxFit.contain, 4 / 3),
  ratio16x9(BoxFit.contain, 16 / 9);

  const PlayerVideoFit(this.boxFit, this.aspectRatio);

  /// Video 组件的缩放方式
  final BoxFit boxFit;

  /// 固定宽高比（4:3 / 16:9），其余为 null
  final double? aspectRatio;
}

/// 播放器右上角可自定义的按钮动作（最多 5 个，顺序可调）。
///
/// [implemented] 为 false 的动作是占位入口（音频均衡器/解码之外的未接入项），
/// 顶栏点击提示「功能即将上线」，待后续接入具体功能。
/// [implemented] 为 true 的动作：字幕、音频、比例、画中画、听视频、循环播放、
/// 章节、片头片尾、弹幕（已接入）。
///
/// 注意：倍速（speed）**不在**顶栏动作之列 —— 倍速按钮固定于播放页
/// 底栏（超分辨率按钮左侧），不支持在顶栏控制栏增加或删除。
///
/// 名称在 `lib/l10n/label_maps.dart` 的 [playerTopActionLabel]；
/// **枚举声明序 = 默认展示序，[id] 是持久化标识，都不许改**。
enum PlayerTopAction {
  subtitle('subtitle', Icons.subtitles_outlined, true),
  // 弹幕（阶段1）：顶栏槽位/「更多」均进入弹幕二级界面
  //（本地弹幕/网络弹幕/自动匹配/弹幕设置）；底栏另有弹幕开关/设置按钮
  danmaku('danmaku', Icons.comment_outlined, true),
  audio('audio', Icons.library_music_outlined, true),
  aspect('aspect', Icons.aspect_ratio, true),
  // 解码：已接入（方案 A，四档 hwdec），点击呼出解码面板
  decode('decode', Icons.deblur_outlined, true),
  // 章节：已接入（工作.md 章节功能），点击呼出章节列表（无章节时提示）
  chapter('chapter', Icons.bookmarks_outlined, true),
  // 投屏：已接入（工作.md 投屏 P0），点击弹设备选择（仅本地文件可投）
  cast('cast', Icons.cast, true),
  // v2 新增：pip/listen 已实现（implemented=true）
  pip('pip', Icons.picture_in_picture_alt_outlined, true),
  // 听视频：已接入（工作.md 第 10 点），点击进入听视频界面
  listen('listen', Icons.headphones_outlined, true),
  // v3：循环播放从设置页移入播放界面，作为可自定义槽位动作（可增删）
  loop('loop', Icons.repeat, true),
  // 片头片尾：已接入（工作.md 片头片尾功能），点击呼出跳过设置面板
  introOutro('intro_outro', Icons.movie_filter_outlined, true),
  // 播放诊断：已接入（§4.27），点击呼出运行时诊断面板（缓存/丢帧/硬解/同步）。
  // 位置固定在「片头片尾」之后、「音频均衡器」之前（工作.md 指定序）
  diagnostics('diagnostics', Icons.monitor_heart_outlined, true),
  // 枚举声明序 = 未自定义槽位时「更多」面板与「可添加」列表的默认展示序：
  // 字幕/弹幕/音频/比例/**解码/章节**/投屏/画中画/听视频/循环/片头片尾/
  // **播放诊断**/均衡器
  //（工作.md：解码与章节在「比例」之后、「画中画」之前；播放诊断在「片头片尾」
  //  之后、「音频均衡器」之前）
  equalizer('equalizer', Icons.equalizer_outlined, true);

  /// 持久化标识（稳定，勿改）
  final String id;
  final IconData icon;

  /// 是否已实现具体功能（false = 占位入口，待接入）
  final bool implemented;

  const PlayerTopAction(this.id, this.icon, this.implemented);

  /// 按持久化 id 反查动作（找不到返回 null）
  static PlayerTopAction? byId(String? id) {
    if (id == null) return null;
    for (final a in values) {
      if (a.id == id) return a;
    }
    return null;
  }
}
