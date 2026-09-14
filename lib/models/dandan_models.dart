/// 弹弹Play 开放弹幕网络 API 的数据模型（搜索 / 弹幕 / 文件匹配）。
///
/// 纯数据模型（无逻辑、无依赖），`fromJson` 仅做字段映射与容错
/// （缺失/类型不符的字段回退默认值，单条损坏由调用方跳过），
/// 供 `services/dandan_play_api.dart` 解析响应使用。
///
/// **为什么用 [_asString]/[_asDouble] 而不是裸 `as String?` / `as num?`
/// （P2-12）**：自建弹幕服务器（用户自己填地址的那种）经常把字段类型写错
/// （`"type": 1`、`"shift": "1.5"`）。裸强转遇到类型不符会抛
/// `TypeError`，而它在 `fromJson` 里没人接 → **整条响应解析失败**、搜索
/// 结果全空、用户以为自建服务器没配好。这里按「类型不符回退默认值」的文件
/// 契约做容错（对齐 `bili_bangumi.dart` / `bilibili_user.dart` 的 `_asInt`
/// 约定）。
library;

/// 宽松取字符串：非字符串一律回退 `''`（不抛异常）
String _asString(Object? v) => v is String ? v : '';

/// 宽松取 double：数字/数字字符串都接受，其余回退 [fallback]
double _asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// 单集信息（节目编号 episodeId = 弹幕库 id，用于拉取该集弹幕）。
class DandanEpisode {
  final int episodeId;
  final String episodeTitle;

  const DandanEpisode({required this.episodeId, required this.episodeTitle});

  static DandanEpisode? fromJson(Map<String, dynamic> json) {
    final id = json['episodeId'];
    final title = json['episodeTitle'];
    if (id is! num || title is! String) return null;
    return DandanEpisode(episodeId: id.toInt(), episodeTitle: title);
  }
}

/// 搜索结果中的一部番剧（含其全部集列表）。
class DandanAnime {
  final int animeId;
  final String animeTitle;
  final String type;
  final String typeDescription;
  final List<DandanEpisode> episodes;

  const DandanAnime({
    required this.animeId,
    required this.animeTitle,
    required this.type,
    required this.typeDescription,
    required this.episodes,
  });

  static DandanAnime? fromJson(Map<String, dynamic> json) {
    final id = json['animeId'];
    final title = json['animeTitle'];
    if (id is! num || title is! String) return null;
    final rawEpisodes = json['episodes'];
    final episodes = <DandanEpisode>[];
    if (rawEpisodes is List) {
      for (final e in rawEpisodes) {
        if (e is Map) {
          final ep = DandanEpisode.fromJson(e.cast<String, dynamic>());
          if (ep != null) episodes.add(ep);
        }
      }
    }
    return DandanAnime(
      animeId: id.toInt(),
      animeTitle: title,
      type: _asString(json['type']),
      typeDescription: _asString(json['typeDescription']),
      episodes: episodes,
    );
  }
}

/// 单条弹幕评论（`p` 为 "time,mode,color,userId" 逗号串，`m` 为文本）。
class DandanComment {
  final int cid;
  final String p;
  final String m;

  const DandanComment({required this.cid, required this.p, required this.m});

  static DandanComment? fromJson(Map<String, dynamic> json) {
    final cid = json['cid'];
    final p = json['p'];
    final m = json['m'];
    if (cid is! num || p is! String || m is! String) return null;
    return DandanComment(cid: cid.toInt(), p: p, m: m);
  }
}

/// 文件匹配（/api/v2/match）返回的单条匹配候选。
class DandanMatchInfo {
  final int episodeId;
  final int animeId;
  final String animeTitle;
  final String episodeTitle;
  final String type;
  final String typeDescription;
  final double shift;

  const DandanMatchInfo({
    required this.episodeId,
    required this.animeId,
    required this.animeTitle,
    required this.episodeTitle,
    required this.type,
    required this.typeDescription,
    this.shift = 0,
  });

  static DandanMatchInfo? fromJson(Map<String, dynamic> json) {
    final episodeId = json['episodeId'];
    final animeId = json['animeId'];
    final animeTitle = json['animeTitle'];
    final episodeTitle = json['episodeTitle'];
    if (episodeId is! num ||
        animeId is! num ||
        animeTitle is! String ||
        episodeTitle is! String) {
      return null;
    }
    return DandanMatchInfo(
      episodeId: episodeId.toInt(),
      animeId: animeId.toInt(),
      animeTitle: animeTitle,
      episodeTitle: episodeTitle,
      type: _asString(json['type']),
      typeDescription: _asString(json['typeDescription']),
      shift: _asDouble(json['shift']),
    );
  }
}
