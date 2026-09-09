/// B 站番剧（PGC）播放列表：整季剧集 + 当前集定位（纯数据 + 纯函数）。
///
/// 参考 PiliPlus `PgcIntroController.nextPlay/prevPlay`：播放页持有**完整剧集
/// 列表**，按 `cid/epId` 定位当前集再前后移动——这样「下一集」「列表循环」
/// 「播放列表面板」三处都能用同一份数据（本项目此前 B 站在线播放只传单集，
/// 导致下一集不可用、列表面板显示「当前文件夹没有视频」）。
///
/// 只覆盖番剧（PGC）；UGC 多分 P/合集的列表化留待后续（模型已按集号 +
/// [BiliEpisode] 承载，扩展时只需新增构造入口）。
library;

import 'package:moumou/models/bili_bangumi.dart';

/// 播放列表条目：原始剧集 + 集号（1 起）。
class BiliPlaylistItem {
  /// 原始剧集（epId/cid/aid/title/longTitle/badge 等唯一数据来源）
  final BiliEpisode episode;

  /// 集号（1 起；用于列表展示「第 N 集」与序号）
  final int index;

  const BiliPlaylistItem({required this.episode, required this.index});

  int get epId => episode.epId;
  int get cid => episode.cid;
  int get aid => episode.aid;

  /// 展示名（长标题优先，缺失回落短标题，再回落「第 N 集」）
  String get title {
    if (episode.longTitle.isNotEmpty) return episode.longTitle;
    if (episode.title.isNotEmpty) return episode.title;
    return '第 $index 集';
  }

  /// 角标（会员 / 限免 / 预告…）
  String get badge => episode.badge;
}

/// 番剧播放列表（整季）。
class BiliPlaylist {
  /// 季 id（0 = 未知）
  final int seasonId;

  /// 番剧名（面板标题用，可空）
  final String seasonTitle;

  final List<BiliPlaylistItem> items;

  const BiliPlaylist({
    this.seasonId = 0,
    this.seasonTitle = '',
    required this.items,
  });

  /// 由季详情构造（剧集顺序即季内播出顺序）。
  factory BiliPlaylist.fromSeasonDetail(BiliSeasonDetail detail) =>
      BiliPlaylist(
        seasonId: detail.seasonId,
        seasonTitle: detail.title,
        items: _wrap(detail.episodes),
      );

  /// 由剧集数组构造（选集页等只有 episodes 的场景）。
  factory BiliPlaylist.fromEpisodes(
    List<BiliEpisode> episodes, {
    int seasonId = 0,
    String seasonTitle = '',
  }) =>
      BiliPlaylist(
        seasonId: seasonId,
        seasonTitle: seasonTitle,
        items: _wrap(episodes),
      );

  static List<BiliPlaylistItem> _wrap(List<BiliEpisode> episodes) => [
        for (var i = 0; i < episodes.length; i++)
          BiliPlaylistItem(episode: episodes[i], index: i + 1),
      ];

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  /// 当前集下标（按 epId 定位；未找到返回 -1）。
  ///
  /// 兼容两种数据来源：播放器侧只拿得到 [BiliMedia.epId]，
  /// 而选集页/详情页拿得到完整 [BiliEpisode]（含 cid）。
  int indexOfEpId(int? epId) {
    if (epId == null || epId <= 0) return -1;
    for (var i = 0; i < items.length; i++) {
      if (items[i].epId == epId) return i;
    }
    return -1;
  }

  /// 下标 [index] 之后是否还有剧集。
  bool hasNextAt(int index) => index >= 0 && index < items.length - 1;

  /// 取下标条目（越界返回 null）。
  BiliPlaylistItem? itemAt(int index) =>
      index >= 0 && index < items.length ? items[index] : null;
}
