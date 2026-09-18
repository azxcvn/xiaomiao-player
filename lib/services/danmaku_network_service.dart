/// 弹幕网络服务（弹弹Play 开放弹幕网络业务层，无 UI）：
/// - 搜索：遍历所有**已启用**的弹幕服务器，**逐台实时产出**结果
///   （[searchStream]，先返回的服务器先呈现，不等其余服务器），是否跨服务器
///   去重由设置决定；[search] 是它的"全部收齐再合并"包装；
/// - 自动匹配：对当前视频文件（前 16MB MD5 + 文件名 + 大小）向所有启用
///   服务器发起匹配，合并候选；
/// - 下载：按 episodeId 拉取单集弹幕，转成本地 [DanmakuEntry] 并生成
///   B站 XML 落盘到 `filesDir/danmaku/network/`（持久化记忆用，重启播放/
///   软件后与本地弹幕同一恢复路径）；
/// - 文件哈希：计算文件前 16MB 的 MD5（弹弹Play 匹配接口的约定）。
///
/// **生命周期（P2-11）**：服务持有 [DandanPlayApi]（内含一个 `http.Client`），
/// 使用者用完必须 [dispose]（控制器与网络弹幕面板都会调用）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:moumou/models/danmaku_entry.dart';
import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/services/dandan_play_api.dart';
import 'package:moumou/services/danmaku_server_settings.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/utils/dandan_comment.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 搜索结果条目（番剧 + 来源服务器；去重开启时按 animeId 跨服务器先到先得）。
class DanmakuSearchItem {
  final DandanAnime anime;

  /// 来源服务器地址；null = 默认弹弹Play 服务器
  final String? serverUrl;

  /// 来源服务器名称（搜索结果胶囊标签展示）
  final String serverName;

  const DanmakuSearchItem({
    required this.anime,
    required this.serverUrl,
    required this.serverName,
  });
}

/// 单台服务器的搜索产出（[searchStream] 的逐条事件）。
///
/// [items] 为**本次新增**的结果（去重开启时已剔除重复的 animeId），
/// [upgrades] 为**替换**事件：同一 animeId 已在更早的服务器上屏，但这台返回的
/// 集数**更多**，面板应当用它对同 animeId 的旧卡就地覆盖（见 [searchStream]）。
/// [error] 为该服务器失败原因（成功为 null）；与 [items]/[upgrades] 不同时非空。
class DanmakuServerSearchOutcome {
  final String serverName;

  /// 来源服务器地址；null = 默认弹弹Play 服务器
  final String? serverUrl;

  final List<DanmakuSearchItem> items;
  final List<DanmakuSearchItem> upgrades;
  final String? error;

  const DanmakuServerSearchOutcome({
    required this.serverName,
    required this.serverUrl,
    this.items = const [],
    this.upgrades = const [],
    this.error,
  });
}

/// 搜索合并结果（空结果时 [errors] 记录各服务器失败原因，供 UI 提示）。
class DanmakuSearchResult {
  final List<DanmakuSearchItem> items;
  final List<String> errors;

  const DanmakuSearchResult({required this.items, required this.errors});
}

/// 自动匹配候选（匹配信息 + 来源服务器名/地址）。
class DanmakuMatchItem {
  final DandanMatchInfo match;
  final String serverName;

  /// 来源服务器地址；null = 默认弹弹Play 服务器
  final String? serverUrl;

  const DanmakuMatchItem({
    required this.match,
    required this.serverName,
    required this.serverUrl,
  });
}

/// 网络弹幕落盘文件名（对齐参考项目：非法字符替换为下划线，
/// 保留中文/字母/数字/下划线，避免文件系统差异）。
String networkDanmakuFileName(
  String animeTitle,
  String episodeTitle,
  int episodeId,
) {
  final raw = '${animeTitle}_${episodeTitle}_$episodeId';
  final safe = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_\u4e00-\u9fa5]'), '_');
  return '$safe.xml';
}

class DanmakuNetworkService {
  DanmakuNetworkService({DandanPlayApi? api}) : _api = api ?? DandanPlayApi();

  final DandanPlayApi _api;
  final DanmakuServerSettings _serverSettings =
      DanmakuServerSettings.instance;

  /// 释放底层 API 客户端的连接池（P2-11，幂等）。
  ///
  /// 调用方：`DanmakuController.dispose`（每进一次播放器一个实例）与网络弹幕
  /// 面板 dispose（每开一次面板一个实例）。注入的 [DandanPlayApi] 只会关闭
  /// 「它自己创建」的 client，不动调用方传入的那个。
  void dispose() => _api.close();

  /// 测试用：覆盖落盘目录解析（默认 `getApplicationSupportDirectory` 在
  /// 单元测试环境无平台通道会失败，注入临时目录即可验证落盘逻辑）。
  @visibleForTesting
  static Future<Directory?> Function()? debugDirectoryOverride;

  /// 逐台服务器搜索番剧，**每台返回就立刻产出一条事件**（不等其余服务器）。
  ///
  /// 网络弹幕面板直接消费本流：先返回的服务器结果马上呈现，转圈一直转到
  /// 所有服务器返回或用户点「停止」（取消订阅即终止，后面的服务器不再发起）。
  ///
  /// 去重由 [DanmakuServerSettings.searchDedupe] 裁决：
  /// - 开（默认）：同一 animeId 只留一条。**先到先上屏**，不为了比较而等待；
  ///   但后面某台返回的集数**更多**时，用 [DanmakuServerSearchOutcome.upgrades]
  ///   产出一条替换事件，面板就地覆盖旧卡（来源胶囊跟着变）——既保住"快"，
  ///   又不至于因为某台响应快、结果少就永久丢掉更全的源；
  ///   集数相同或更少则丢弃（卡片不跳动）。
  /// - 关：每台服务器的结果原样产出，同一部番剧会各出一张卡。
  ///
  /// 单台服务器失败不抛出：以带 [DanmakuServerSearchOutcome.error] 的事件
  /// 产出，其余服务器继续。
  Stream<DanmakuServerSearchOutcome> searchStream(String keyword) async* {
    final dedupe = _serverSettings.searchDedupe;
    // animeId → 已上屏的那条（去重时用来比较集数，决定"丢弃"还是"替换"）
    final shown = <int, DanmakuSearchItem>{};
    final servers = _serverSettings.enabledServers;
    // 存在自建服务器时先请求本地网络权限（自建服务器可能在局域网，
    // Android 16+ 缺权限会被系统拦截）
    if (servers.any((s) => !s.isDefault)) {
      await DeviceServices.requestLocalNetworkPermission();
    }
    for (final server in servers) {
      final serverUrl = server.isDefault ? null : server.url;
      try {
        final animes = await _api.searchAnime(keyword, baseUrl: serverUrl);
        final items = <DanmakuSearchItem>[];
        final upgrades = <DanmakuSearchItem>[];
        for (final anime in animes) {
          final item = DanmakuSearchItem(
            anime: anime,
            serverUrl: serverUrl,
            serverName: server.name,
          );
          if (!dedupe) {
            items.add(item);
            continue;
          }
          final existing = shown[anime.animeId];
          if (existing == null) {
            shown[anime.animeId] = item;
            items.add(item);
          } else if (anime.episodes.length >
              existing.anime.episodes.length) {
            // 更全的那台：替换已上屏的卡（相等不算更全，避免卡片无谓跳动）
            shown[anime.animeId] = item;
            upgrades.add(item);
          }
        }
        yield DanmakuServerSearchOutcome(
          serverName: server.name,
          serverUrl: serverUrl,
          items: items,
          upgrades: upgrades,
        );
      } catch (e) {
        yield DanmakuServerSearchOutcome(
          serverName: server.name,
          serverUrl: serverUrl,
          error: '${server.name}: ${e is DandanApiException ? e.message : e}',
        );
      }
    }
  }

  /// 搜索番剧：收齐所有已启用服务器的结果后合并返回（[searchStream] 的包装）。
  ///
  /// UI 走流式 [searchStream]；本方法保留给「需要一次性完整结果」的调用方
  /// （也覆盖原有合并语义的单测）。去重规则与流式一致（同 animeId 集数更多者
  /// 覆盖先到者）。
  Future<DanmakuSearchResult> search(String keyword) async {
    final items = <DanmakuSearchItem>[];
    // animeId → 在 items 中的下标（替换事件按它就地覆盖）
    final positionOf = <int, int>{};
    final errors = <String>[];
    await for (final outcome in searchStream(keyword)) {
      for (final item in outcome.items) {
        positionOf[item.anime.animeId] = items.length;
        items.add(item);
      }
      for (final upgraded in outcome.upgrades) {
        final at = positionOf[upgraded.anime.animeId];
        if (at != null) items[at] = upgraded;
      }
      final error = outcome.error;
      if (error != null) errors.add(error);
    }
    return DanmakuSearchResult(items: items, errors: errors);
  }

  /// 文件匹配：合并所有已启用服务器的候选（按 episodeId 去重）。
  Future<List<DanmakuMatchItem>> matchVideo({
    required String fileName,
    required String fileHash,
    required int fileSize,
  }) async {
    final items = <DanmakuMatchItem>[];
    final seenIds = <int>{};
    // 存在自建服务器时先请求本地网络权限（同 search）
    if (_serverSettings.enabledServers.any((s) => !s.isDefault)) {
      await DeviceServices.requestLocalNetworkPermission();
    }
    for (final server in _serverSettings.enabledServers) {
      try {
        final serverUrl = server.isDefault ? null : server.url;
        final matches = await _api.matchDanmaku(
          fileName: fileName,
          fileHash: fileHash,
          fileSize: fileSize,
          baseUrl: serverUrl,
        );
        for (final match in matches) {
          if (seenIds.add(match.episodeId)) {
            items.add(DanmakuMatchItem(
              match: match,
              serverName: server.name,
              serverUrl: serverUrl,
            ));
          }
        }
      } catch (_) {
        // 单服务器失败不阻断整体（其余服务器结果仍可用）
      }
    }
    return items;
  }

  /// 下载单集弹幕：拉取评论 → 转本地条目 + 生成 B站 XML **落盘**
  /// （`filesDir/danmaku/network/`，与原生手动导入目录同级）。
  ///
  /// 返回条目与落盘路径；落盘失败不影响本次播放（[filePathOrNull] 为
  /// null，条目仍会装载）。条目为空时不落盘（空弹幕文件无记忆价值）。
  Future<({List<DanmakuEntry> entries, String? filePathOrNull})>
      downloadEpisode({
    required int episodeId,
    required String animeTitle,
    required String episodeTitle,
    String? serverUrl,
  }) async {
    final comments = await _api.getComments(episodeId, baseUrl: serverUrl);
    final entries = dandanCommentsToEntries(comments);
    if (entries.isEmpty) {
      return (entries: const <DanmakuEntry>[], filePathOrNull: null);
    }
    final xml = dandanCommentsToXml(comments);
    final path = await _saveXml(
      xml,
      networkDanmakuFileName(animeTitle, episodeTitle, episodeId),
    );
    return (entries: entries, filePathOrNull: path);
  }

  /// 通过番剧名搜索并取回指定 animeId 的完整集列表（自动匹配命中后保存
  /// 切集缓存用）；找不到返回 null。
  Future<List<DandanEpisode>?> fetchAnimeEpisodesById(
    int animeId,
    String animeTitle, {
    String? serverUrl,
  }) async {
    final animes = await _api.searchAnime(animeTitle, baseUrl: serverUrl);
    for (final anime in animes) {
      if (anime.animeId == animeId) return anime.episodes;
    }
    return null;
  }

  /// 计算文件前 16MB 的 MD5（弹弹Play 匹配接口约定）；失败返回 null。
  Future<String?> calculateFileHash(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final length = await file.length();
      final readSize =
          length < 16 * 1024 * 1024 ? length : 16 * 1024 * 1024;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead(0, readSize)) {
        builder.add(chunk);
      }
      return md5.convert(builder.takeBytes()).toString();
    } catch (_) {
      return null;
    }
  }

  // ── 落盘（网络弹幕持久化，工作.md 第 2 点）──────────────────

  /// 落盘目录：`filesDir/danmaku/network/`（getApplicationSupportDirectory
  /// 在 Android 上即 filesDir，与原生手动导入的 danmaku/ 目录同级）。
  static Future<Directory?> cacheDirectory() async {
    final override = debugDirectoryOverride;
    if (override != null) return override();
    try {
      final support = await getApplicationSupportDirectory();
      return Directory(p.join(support.path, 'danmaku', 'network'));
    } catch (_) {
      return null;
    }
  }

  /// 网络弹幕缓存占用字节数（目录不存在/不可读返回 0；供缓存管理页展示）。
  static Future<int> cacheSizeBytes() async {
    try {
      final dir = await cacheDirectory();
      if (dir == null || !await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 清空网络弹幕缓存（只删目录内文件，保留目录本身）。
  ///
  /// 这些 XML 是「看过就有、丢了会重新下载」的派生数据；不清理的话会随观看
  /// 番剧数量无限增长（体检报告 §3-14；用户拍板 2026-09：清理入口放缓存管理页）。
  static Future<void> clearCache() async {
    try {
      final dir = await cacheDirectory();
      if (dir == null || !await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {
            // 单个文件删不掉不影响整体清理
          }
        }
      }
    } catch (_) {
      // 清理失败静默：缓存是派生数据
    }
  }

  /// 写入 XML 文件，返回真实路径；失败返回 null（不阻断本次播放）。
  Future<String?> _saveXml(String xml, String fileName) async {
    try {
      final dir = await cacheDirectory();
      if (dir == null) return null;
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(xml, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
