/// 弹幕服务器配置模型（弹幕网络功能）：内置弹弹Play 默认服务器 + 用户自建
/// 服务器列表项。纯数据模型（无逻辑、无依赖），JSON 序列化供
/// [DanmakuServerSettings] 持久化使用。
library;

/// 宽松取布尔：`1`/`"true"` 之类也算真，无法判定的值回退 [fallback]（P2-12）。
///
/// 裸 `as bool?` 遇到类型不符会抛 `TypeError`；它在 `DanmakuServerSettings`
/// 的解码里被一个大 `catch` 兜住 → **整份服务器列表被丢弃**（用户自建服务器
/// 全部消失，只剩默认服务器）。类型不符只是回退默认值的事，不该毁掉整个列表。
bool _asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}

/// 单个弹幕服务器：名称 + 地址 + 启停开关 + 是否内置默认（不可删除）。
class DanmakuServer {
  /// 唯一 id（默认服务器用固定 'default'，自建用随机 UUID）
  final String id;

  /// 展示名称
  final String name;

  /// API 地址（默认服务器为官方地址；自建服务器为用户填写的 https 地址）
  final String url;

  /// 是否启用（启用后参与搜索 / 匹配，结果合并展示）
  final bool isEnabled;

  /// 是否内置默认（弹弹Play；不可删除，只能开关）
  final bool isDefault;

  const DanmakuServer({
    required this.id,
    required this.name,
    required this.url,
    this.isEnabled = true,
    this.isDefault = false,
  });

  static const String defaultId = 'default';
  static const String defaultName = '弹弹Play（默认）';
  static const String defaultUrl = 'https://api.dandanplay.net';

  /// 内置默认服务器
  factory DanmakuServer.createDefault() => const DanmakuServer(
        id: defaultId,
        name: defaultName,
        url: defaultUrl,
        isEnabled: true,
        isDefault: true,
      );

  DanmakuServer copyWith({String? name, String? url, bool? isEnabled}) =>
      DanmakuServer(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        isEnabled: isEnabled ?? this.isEnabled,
        isDefault: isDefault,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'isEnabled': isEnabled,
        'isDefault': isDefault,
      };

  static DanmakuServer? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final url = json['url'];
    if (id is! String || name is! String || url is! String) return null;
    return DanmakuServer(
      id: id,
      name: name,
      url: url,
      isEnabled: _asBool(json['isEnabled'], true),
      isDefault: _asBool(json['isDefault']),
    );
  }
}
