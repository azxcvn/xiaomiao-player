/// 远端字幕流解析器：把网络存储上的字幕文件铺成 **无凭据 loopback URL**，
/// 供 mpv 的 `sub-add` 直接加载（播放器层不碰凭据，与视频流同一条纪律）。
///
/// 对齐 mpvRx `SubtitleOps.autoloadNetworkFileSubtitles`：远端列目录 → 命中
/// 同名字幕 → 注册辅助代理流 → `sub-add <proxyUrl>`。URL 由
/// [NetworkStreamingProxy] 注册，形状与视频流一致
/// （`http://127.0.0.1:<port>/<token>/<远端路径>`），因此代理会复用同一 token
/// 下的连接去读这个兄弟文件——代理侧无需新增任何路径。
library;

import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_client_factory.dart';
import 'package:moumou/services/network/network_connection_settings.dart';
import 'package:moumou/services/network/network_streaming_proxy.dart';
import 'package:moumou/utils/network_mime_types.dart';
import 'package:moumou/utils/retry_policy.dart';

/// 字幕流解析抽象：解耦 `SubtitleController`（可单测/可注入假实现）。
abstract class NetworkSubtitleStreamResolver {
  /// 取一条连接配置（找不到返回 null）。
  NetworkConnection? connectionById(int id);

  /// 列 [dirPath]（连接根下的规范化路径，空串 = 连接根）下的条目。
  Future<List<NetworkFile>> listFiles(int connectionId, String dirPath);

  /// 把 [file] 注册为代理流，返回可交给 mpv 的 loopback URL
  /// （`http://127.0.0.1:<port>/<token>/<远端路径>`，与视频流同形状）；
  /// 失败抛异常（上层一律静默放弃自动加载）。
  Future<String> registerSubtitleStream(int connectionId, NetworkFile file);
}

/// 生产实现：连接配置取 [NetworkConnectionSettings]，列表走协议客户端工厂。
///
/// 每次列目录**新建一次性连接**（与 `NetworkRepository.browse` 同规矩），
/// 用完即断——代理持有的是播放流自己的连接，两者互不影响。
class NetworkSubtitleStreams implements NetworkSubtitleStreamResolver {
  const NetworkSubtitleStreams();

  @override
  NetworkConnection? connectionById(int id) =>
      NetworkConnectionSettings.instance.byId(id);

  @override
  Future<List<NetworkFile>> listFiles(int connectionId, String dirPath) async {
    final connection = connectionById(connectionId);
    if (connection == null) {
      throw StateError('网络连接不存在');
    }
    final client = createNetworkClient(connection);
    try {
      // 远端列目录是**后台**动作：整体套 12s 上限，服务器黑洞时不等
      // 协议自身的重试（SMB 内部最多 5 次）拖到几十秒。
      await client.connect().timeout(NetworkTimeoutTier.api.timeout);
      return await client
          .listFiles(dirPath)
          .timeout(NetworkTimeoutTier.api.timeout);
    } finally {
      try {
        await client.disconnect();
      } catch (_) {
        // 断开失败不影响已取到的结果（下次扫描重新建连）
      }
    }
  }

  @override
  Future<String> registerSubtitleStream(
    int connectionId,
    NetworkFile file,
  ) async {
    final connection = connectionById(connectionId);
    if (connection == null) {
      throw StateError('网络连接不存在');
    }
    return NetworkStreamingProxy.instance.registerStream(
      connection,
      file.path,
      fileSize: file.size,
      mimeType: networkMimeTypeForFileName(file.name) ?? 'text/plain',
    );
  }
}

/// 播放器侧注入用的单例。
final NetworkSubtitleStreamResolver networkSubtitleStreams =
    NetworkSubtitleStreams();
