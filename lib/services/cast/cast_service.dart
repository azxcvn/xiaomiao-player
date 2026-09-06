/// 投屏服务：SSDP 发现渲染器 + 本地文件推流（仅推流，不做遥控，P0）。
///
/// 发现走 dlna_dart 的 DLNAManager（Kazumi 同款）；本地文件经 LanMediaServer
/// 暴露为电视可达 URL 后 SetAVTransportURI → Play。设备表按 deviceType
/// 过滤 MediaRenderer（排除 MediaServer/网关等非渲染设备）。
library;

import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:moumou/models/cast_device.dart';
import 'package:moumou/services/cast/lan_media_server.dart';
import 'package:moumou/utils/cast_source.dart';

/// 是否为渲染器（能播放的电视/盒子）：deviceType 含 MediaRenderer。
bool isMediaRenderer(String deviceType) => deviceType.contains('MediaRenderer');

class CastService {
  static final CastService instance = CastService();

  DLNAManager? _manager;
  DeviceManager? _deviceManager;

  /// 启动 SSDP 发现，返回渲染器列表流（已过滤 [isMediaRenderer]）。
  /// 再次调用会先停掉旧发现（对话框关闭也应调 [stopDiscovery]）。
  Future<Stream<List<CastDevice>>> startDiscovery() async {
    stopDiscovery();
    final manager = DLNAManager();
    final dm = await manager.start();
    _manager = manager;
    _deviceManager = dm;
    return dm.devices.stream.map(renderers);
  }

  /// 停止发现（释放 UDP socket / 定时器）。
  void stopDiscovery() {
    _manager?.stop();
    _manager = null;
    _deviceManager = null;
  }

  /// 从设备表过滤出渲染器（稳定：只保留 MediaRenderer）。
  List<CastDevice> renderers(Map<String, DLNADevice> devices) {
    final result = <CastDevice>[];
    for (final d in devices.values) {
      if (isMediaRenderer(d.info.deviceType)) {
        result.add(CastDevice(
          id: d.info.URLBase,
          friendlyName: d.info.friendlyName,
          deviceType: d.info.deviceType,
        ));
      }
    }
    return result;
  }

  /// 解析投屏 URL：P0 仅本地文件（经 [LanMediaServer] 暴露为 LAN URL）；
  /// 其余来源返回 null（首期不支持，调用方提示）。
  Future<String?> resolveUrl(String path) async {
    if (classifyCastSource(path) != CastSource.localFile) return null;
    final filePath = localFilePath(path);
    if (filePath == null) return null;
    return LanMediaServer.instance.expose(filePath);
  }

  /// 推送到指定设备并播放（SetAVTransportURI → Play）。
  Future<void> pushToDevice(CastDevice device, String url) async {
    final dlna = _deviceManager?.deviceList[device.id];
    if (dlna == null) throw StateError('设备已离线');
    await dlna.setUrl(url);
    await dlna.play();
  }
}
