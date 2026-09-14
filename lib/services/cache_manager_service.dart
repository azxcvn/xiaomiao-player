import 'package:flutter/services.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/video_info_service.dart';

/// 缓存类别（key 与原生 `getCacheSizes` / `clearCache` 对应；纯数据，无 UI 依赖）
class CacheCategory {
  final String key;
  final String label;

  const CacheCategory(this.key, this.label);
}

/// 缓存管理服务：查询/清除各类应用缓存。
///
/// 原生实现见 `MainActivity.kt`（`cacheDir/thumbs/` 为列表封面；
/// 未来类别如弹幕/字幕预留 `other`）。
/// 进度条缩略图已切换为 FFmpeg 快速引擎 + 纯内存缓存（随播放页退出清空），
/// 不再产生磁盘缓存。
class CacheManagerService {
  CacheManagerService._();

  static const MethodChannel _channel = MethodChannel('moumou/video_info');

  /// 视频列表封面缩略图缓存
  static const listThumbs = CacheCategory('listThumbs', '视频列表封面缩略图');

  /// 网络弹幕缓存（`filesDir/danmaku/network/` 的 XML）
  ///
  /// ⚠️ 这一类**由 Dart 侧管理**（原生 `getCacheSizes`/`clearCache` 不认识它），
  /// 所以体积统计与清理都在 [getCacheSizes] / [clearCategory] / [clearAll] 里
  /// 单独处理；不清理会随观看番剧数量无限增长（体检报告 §3-14）。
  static const networkDanmaku = CacheCategory('networkDanmaku', '网络弹幕缓存');

  /// 其他缓存（未来：字幕文件等）
  static const other = CacheCategory('other', '其他缓存');

  /// 全部类别（顺序即展示顺序）
  static const all = [listThumbs, networkDanmaku, other];

  /// 各缓存类别占用字节数（失败返回空 map）
  static Future<Map<String, int>> getCacheSizes() async {
    final map = <String, int>{};
    try {
      final raw = await _channel.invokeMapMethod<String, Object>('getCacheSizes');
      if (raw != null) {
        map.addAll(raw.map((k, v) => MapEntry(k, (v as num).toInt())));
      }
    } catch (_) {
      // 原生通道不可用（测试/异常）：至少给出 Dart 侧类别
    }
    map[networkDanmaku.key] = await DanmakuNetworkService.cacheSizeBytes();
    return map;
  }

  /// 清除单个类别缓存
  static Future<bool> clearCategory(CacheCategory category) async {
    if (category.key == networkDanmaku.key) {
      await DanmakuNetworkService.clearCache();
      return true;
    }
    try {
      await _channel.invokeMethod<void>('clearCache', {'category': category.key});
      if (category.key == listThumbs.key) {
        VideoInfoService.clearCache();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 一键清除所有缓存（同时清掉进度条缩略图、列表封面与网络弹幕的 Dart 侧缓存）
  static Future<bool> clearAll() async {
    await DanmakuNetworkService.clearCache();
    try {
      await _channel.invokeMethod<void>('clearAllCaches');
      DeviceServices.clearFrameCache();
      VideoInfoService.clearCache();
      return true;
    } catch (_) {
      return false;
    }
  }
}
