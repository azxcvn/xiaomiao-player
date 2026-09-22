/// 网络存储播放列表的纯逻辑（可单测）：远端列目录结果 → 播放列表用的
/// [VideoFile] 表，以及「当前项」在列表里的比较键。
///
/// 为什么需要单独一套键：本地播放的媒体路径就是视频身份，而网络存储播放的
/// 媒体路径是**回环代理 URL**（`http://127.0.0.1:<port>/<token>/<远端路径>`），
/// 每次注册流都换一个随机 token——同一次会话里同一个文件也可能拿到不同 URL，
/// 拿它当身份会让「播放列表面板高亮当前项 / 下一集 / 同目录过滤」全部失效。
/// 远端路径（连接根下，以 `/` 开头）才是稳定身份。
library;

import 'package:moumou/models/network_file.dart';
import 'package:moumou/models/playlist_sort.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/utils/network_mime_types.dart';

/// 播放列表里「当前项」的比较键（与列表项的 [VideoFile.path] 同源比较）。
///
/// - 网络存储播放（[networkSource] 带远端路径）→ 远端路径；
/// - 本地播放 / 远端路径缺失 → [mediaPath]（回环 URL 或本地绝对路径）。
String playlistKeyOf(String mediaPath, VideoFile? networkSource) {
  final remote = networkSource?.remotePath;
  if (remote == null || remote.isEmpty) return mediaPath;
  return remote;
}

/// 远端目录列表 → 播放列表用的 [VideoFile] 表（纯函数）。
///
/// - 只留**视频文件**：目录与字幕/图片等非视频不进播放列表（远端目录里
///   字幕往往与视频同目录，混进去会点出「无法播放」的条目）；
/// - `path` 与 `remotePath` 都填**远端路径**：列表身份按它比较
///   （见 [playlistKeyOf]），切集时再用它注册回环流；
/// - `size` / `dateModified` 用远端给的原始值：服务器可能不给（大小 0/-1、
///   时间 0 → null），播放列表面板的「日期排序」据此把无日期的排末尾；
/// - 输出按**名称自然序升序**（与播放列表面板默认排序一致）。
List<VideoFile> networkPlaylistFrom(
  List<NetworkFile> files, {
  required int connectionId,
}) {
  final videos = <VideoFile>[];
  for (final f in files) {
    if (f.isDirectory) continue;
    if (!isNetworkVideoFile(f.name)) continue;
    videos.add(
      VideoFile(
        path: f.path,
        name: f.name,
        size: f.size > 0 ? f.size : 0,
        dateModified: f.lastModified > 0
            ? DateTime.fromMillisecondsSinceEpoch(f.lastModified)
            : null,
        source: VideoSource.network,
        remotePath: f.path,
        connectionId: connectionId,
      ),
    );
  }
  return sortVideosForPlaylist(videos, PlaylistSortMode.nameAsc);
}
