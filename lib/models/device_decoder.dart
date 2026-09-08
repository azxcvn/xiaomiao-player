/// 设备解码器条目模型（设备能力检测页用，工作.md 迁移功能）。
///
/// 纯数据模型：从原生 `DeviceCapabilities.inspect` 的 `decoders` 列表
/// 逐项解析，承载解码器的完整能力信息（名称/MIME/分辨率/声道/特性/
/// 色彩格式/采样率/profile 等），供 [DeviceInfoPage] 与解码器详情页展示。
class DeviceDecoderEntry {
  final String name;
  final String canonicalName;
  final String mimeType;
  final String formatName;
  final bool isHardware;
  final bool isAlias;
  final String mediaType;
  final String maxResolution;
  final String minResolution;
  final int maxChannels;
  final int maxInstances;
  final String alignment;
  final String bitrateRange;
  final List<String> profiles;
  final List<String> colorFormats;
  final List<String> features;
  final List<String> sampleRates;
  final bool isHdrSupported;

  const DeviceDecoderEntry({
    required this.name,
    required this.canonicalName,
    required this.mimeType,
    required this.formatName,
    required this.isHardware,
    required this.isAlias,
    required this.mediaType,
    required this.maxResolution,
    required this.minResolution,
    required this.maxChannels,
    required this.maxInstances,
    required this.alignment,
    required this.bitrateRange,
    required this.profiles,
    required this.colorFormats,
    required this.features,
    required this.sampleRates,
    required this.isHdrSupported,
  });

  /// 从原生 map 解析（字段缺失/类型异常一律容错为默认值）
  factory DeviceDecoderEntry.fromMap(Map<dynamic, dynamic> m) {
    List<String> stringList(String key) {
      final raw = m[key];
      final out = <String>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is String) out.add(e);
        }
      }
      return out;
    }

    return DeviceDecoderEntry(
      name: (m['name'] as String?) ?? '',
      canonicalName: (m['canonicalName'] as String?) ?? '',
      mimeType: (m['mimeType'] as String?) ?? '',
      formatName: (m['formatName'] as String?) ?? '',
      isHardware: (m['isHardware'] as bool?) ?? false,
      isAlias: (m['isAlias'] as bool?) ?? false,
      mediaType: (m['mediaType'] as String?) ?? 'video',
      maxResolution: (m['maxResolution'] as String?) ?? '',
      minResolution: (m['minResolution'] as String?) ?? '',
      maxChannels: ((m['maxChannels'] as num?) ?? 0).toInt(),
      maxInstances: ((m['maxInstances'] as num?) ?? 0).toInt(),
      alignment: (m['alignment'] as String?) ?? '',
      bitrateRange: (m['bitrateRange'] as String?) ?? '',
      profiles: stringList('profiles'),
      colorFormats: stringList('colorFormats'),
      features: stringList('features'),
      sampleRates: stringList('sampleRates'),
      isHdrSupported: (m['isHdrSupported'] as bool?) ?? false,
    );
  }
}
