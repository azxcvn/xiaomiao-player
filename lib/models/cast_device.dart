/// 投屏目标设备（DLNA MediaRenderer）纯数据模型：设备名 + 类型 + 稳定标识。
///
/// 只承载展示与定位所需的最小字段，DLNA 协议细节留在服务层（cast_service.dart）。
class CastDevice {
  /// 稳定标识（设备描述 URLBase，DeviceManager 以它为 key）
  final String id;

  /// 设备展示名（friendlyName）
  final String friendlyName;

  /// 设备类型（urn:...:device:MediaRenderer:1）
  final String deviceType;

  const CastDevice({
    required this.id,
    required this.friendlyName,
    required this.deviceType,
  });

  /// 设备类型末段（如 MediaRenderer），供副标题/图标展示。
  String get kind {
    final parts = deviceType.split(':');
    return parts.length > 3 ? parts[3] : deviceType;
  }
}
