/// B 站在线播放启动器：解析 playurl → 构造 [BiliMedia] → push [PlayerPage]。
///
/// 番剧详情、选集页、BV 链接解析三处入口复用，统一「解析中模态进度 →
/// 解析失败 toast → 成功进入播放页」的交互。
///
/// 番剧另传**整季剧集列表**（[BiliPlaylist]）给播放页：详情页/选集页已有
/// 列表时直接传入（零额外请求）；只有单集信息（链接解析等）时在启动器内
/// 与 playurl 并行补拉一次季详情，失败则退化为「无列表」（不阻断播放）。
library;

import 'package:flutter/material.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/models/bili_dash.dart';
import 'package:moumou/models/bili_media.dart';
import 'package:moumou/models/bili_playlist.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/services/bilibili/bili_bangumi_service.dart';
import 'package:moumou/services/bilibili/bili_http.dart';
import 'package:moumou/services/bilibili/bili_video_service.dart';

/// 播放 B 站 PGC 单集（番剧/影视）。
///
/// [playlist] 非空时直接作为播放页的剧集列表（详情页/选集页传入）；
/// 为空时在启动器内补拉季详情构造（拉取失败不阻断播放）。
Future<void> playBiliEpisode(
  BuildContext context,
  BiliEpisode ep, {
  BiliPlaylist? playlist,
}) async {
  final service = BiliVideoService();
  if (!context.mounted) return;
  _showLoading(context);
  try {
    // playurl 与剧集列表并行请求（列表缺失时才拉，避免多一次往返）
    final mediaFuture = service.resolvePgcMedia(ep);
    final playlistFuture = playlist != null
        ? Future<BiliPlaylist?>.value(playlist)
        : _fetchPlaylist(ep);
    final media = await mediaFuture;
    final resolvedPlaylist = await playlistFuture;
    if (!context.mounted) return;
    _dismissLoading(context);
    if (media.playUrl.defaultVideo == null ||
        media.playUrl.defaultAudio == null) {
      _toast(context, '解析播放地址失败');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerPage(
        path: media.videoUrl,
        title: media.title,
        biliMedia: media,
        biliPlaylist: resolvedPlaylist,
      ),
    ));
  } catch (e) {
    if (context.mounted) {
      _dismissLoading(context);
      _toast(context, '播放失败：${_errText(e)}');
    }
  }
}

/// 补拉季详情构造剧集列表（失败返回 null，播放不受影响）。
Future<BiliPlaylist?> _fetchPlaylist(BiliEpisode ep) async {
  try {
    final detail = await BiliBangumiService().fetchSeasonDetail(epId: ep.epId);
    final playlist = BiliPlaylist.fromSeasonDetail(detail);
    return playlist.isEmpty ? null : playlist;
  } catch (_) {
    return null;
  }
}

/// 播放 B 站 UGC（BV 号）。
Future<void> playBiliBvid(BuildContext context, String bvid) async {
  final service = BiliVideoService();
  if (!context.mounted) return;
  _showLoading(context);
  try {
    final video = await service.resolveUgcVideo(bvid);
    final playUrl = await service.fetchUgcPlayUrl(bvid: bvid, cid: video.cid);
    if (!context.mounted) return;
    _dismissLoading(context);
    if (playUrl.defaultVideo == null || playUrl.defaultAudio == null) {
      _toast(context, '解析播放地址失败');
      return;
    }
    final title = video.title.isEmpty ? bvid : video.title;
    final media = _buildUgcMedia(service, video, playUrl);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerPage(
        path: playUrl.defaultVideo!.baseUrl,
        title: title,
        biliMedia: media,
      ),
    ));
  } catch (e) {
    if (context.mounted) {
      _dismissLoading(context);
      _toast(context, '播放失败：${_errText(e)}');
    }
  }
}

BiliMedia _buildUgcMedia(
  BiliVideoService service,
  BiliUgcVideo video,
  BiliPlayUrlResult playUrl,
) {
  final title = video.title.isEmpty ? video.bvid : video.title;
  return BiliMedia(
    cid: video.cid,
    aid: video.aid,
    title: title,
    playUrl: playUrl,
    switchQuality: (qn) async => _buildUgcMedia(
      service,
      video,
      await service.fetchUgcPlayUrl(bvid: video.bvid, cid: video.cid, qn: qn),
    ),
  );
}

void _showLoading(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
}

void _dismissLoading(BuildContext context) {
  Navigator.of(context).pop();
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _errText(Object e) =>
    e is BiliApiException ? e.message : e.toString();
