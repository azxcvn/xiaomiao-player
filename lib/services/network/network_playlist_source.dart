/// 网络存储播放列表数据源（播放页用）：按「连接 id + 当前视频远端路径」
/// 列出同目录视频，转成播放列表用的 [VideoFile] 表。
///
/// 背景：播放页「入口没传 playlist」时按当前视频所在文件夹补全兄弟列表——本地
/// 走 `VideoScanner.folderSiblingsOf`，网络存储的媒体路径是回环代理 URL，那条
/// 本地链路恒不成立（`http://...` 不是本地绝对路径），于是列表永远空着、面板
/// 只显示「当前文件夹没有其他视频」。远端这一路补在这里。
///
/// 与字幕侧 `NetworkSubtitleStreams` 同一套规矩：每次列目录**新建一次性连接**、
/// 用完即断，整体套 12s 上限（服务器黑洞时不等协议自身的重试拖到几十秒）；
/// 失败一律**不抛**，返回空表——列表补全失败绝不能影响播放本身。
library;

import 'package:flutter/foundation.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/network/network_client_factory.dart';
import 'package:moumou/services/network/network_connection_settings.dart';
import 'package:moumou/utils/network_playlist.dart';
import 'package:moumou/utils/network_subtitle_match.dart';
import 'package:moumou/utils/retry_policy.dart';

class NetworkPlaylistSource {
  const NetworkPlaylistSource();

  /// 取一条连接配置（找不到返回 null）。
  NetworkConnection? connectionById(int id) =>
      NetworkConnectionSettings.instance.byId(id);

  /// 列 [dirPath]（连接根下的规范化路径，空串 = 连接根）下的条目。
  /// 失败抛异常，由 [siblingVideosOf] 兜住。
  Future<List<NetworkFile>> listFiles(int connectionId, String dirPath) async {
    final connection = connectionById(connectionId);
    if (connection == null) {
      throw StateError('网络连接不存在');
    }
    // Android 16+ 本地网络保护：连局域网 NAS 前先请求权限（缺失会被系统拦截）。
    // 正常流程浏览页已经请求过，这里兜住「直接补全」的路径。
    await DeviceServices.requestLocalNetworkPermission();
    final client = createNetworkClient(connection);
    try {
      await client.connect().timeout(NetworkTimeoutTier.api.timeout);
      return await client
          .listFiles(dirPath)
          .timeout(NetworkTimeoutTier.api.timeout);
    } finally {
      try {
        await client.disconnect();
      } catch (_) {
        // 断开失败不影响已取到的结果（下次列目录重新建连）
      }
    }
  }

  /// 当前视频所在远端目录下的视频（含当前视频本身；与播放列表面板默认排序
  /// 一致：名称自然序升序）。远端路径空 = 说不上是哪个目录，直接返回空表；
  /// 其余任何失败（连接不存在 / 超时 / 权限）也一律返回空表。
  Future<List<VideoFile>> siblingVideosOf({
    required int connectionId,
    required String remotePath,
  }) async {
    if (remotePath.isEmpty) return const [];
    try {
      final files = await listFiles(connectionId, remoteDirOf(remotePath));
      return networkPlaylistFrom(files, connectionId: connectionId);
    } catch (e) {
      debugPrint('[网络播放列表] 远端列目录失败：$e');
      return const [];
    }
  }
}

/// 播放页侧注入用的单例（测试可自建实例并覆写 [NetworkPlaylistSource.listFiles]）。
final NetworkPlaylistSource networkPlaylistSource = NetworkPlaylistSource();
