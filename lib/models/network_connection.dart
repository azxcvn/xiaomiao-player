/// 网络存储协议枚举与连接（账号）配置模型。
library;

/// 支持的远程协议（对齐 mpvRx 的 NetworkProtocol）
///
/// [defaultPort] / [secureDefaultPort] 分别对应「明文」与「加密」两种默认端口：
/// WebDAV 的明文 HTTP 是 80、HTTPS 是 443（`useHttps` 决定用哪个）；
/// SMB / FTP 无加密变体，两者相同。界面在协议或 HTTPS 开关变化而用户**没手改
/// 过端口**时，按 [defaultPortFor] 自动跟随。
enum NetworkProtocol {
  smb('SMB', 445),
  ftp('FTP', 21),
  webdav('WebDAV', 80, secureDefaultPort: 443);

  final String displayName;
  final int defaultPort;

  /// 加密连接的默认端口（仅 WebDAV 有意义；其余等于 [defaultPort]）。
  final int secureDefaultPort;

  const NetworkProtocol(this.displayName, this.defaultPort, {int? secureDefaultPort})
      : secureDefaultPort = secureDefaultPort ?? defaultPort;

  /// 该协议在给定 scheme 下应预填的端口（[useHttps] 只对 WebDAV 生效）。
  int defaultPortFor({bool useHttps = false}) =>
      useHttps ? secureDefaultPort : defaultPort;

  /// 按持久化用的字符串名反查（未知值返回 null，调用方决定兜底）
  static NetworkProtocol? tryParse(String value) {
    for (final p in NetworkProtocol.values) {
      if (p.name == value) return p;
    }
    return null;
  }
}

/// 编辑账户时，协议或 HTTPS 开关变化后端口应预填成什么（纯函数，可单测）。
///
/// 规则：**只有**当前端口恰好等于「旧协议 + 旧 scheme」的默认端口（或为空/非法）
/// 时才跟随成新默认端口；用户手改过的端口（如群晖 WebDAV 5005/5006、自定义
/// 8080）一律原样保留，绝不被开关悄悄改掉。[touched] 为 true 时也不跟随。
String resolvePortOnChange({
  required String currentText,
  required NetworkProtocol previousProtocol,
  required bool previousHttps,
  required NetworkProtocol nextProtocol,
  required bool nextHttps,
  bool touched = false,
}) {
  final current = currentText.trim();
  final next = nextProtocol.defaultPortFor(useHttps: nextHttps).toString();
  if (touched) return current;
  final previous = previousProtocol.defaultPortFor(useHttps: previousHttps);
  final parsed = int.tryParse(current);
  if (parsed == null || parsed == previous) return next;
  return current;
}

/// 一条网络连接（账号）配置。纯数据，可 json 序列化。
class NetworkConnection {
  final int id; // 本地自增 id（0 = 尚未入库）
  final String name;
  final NetworkProtocol protocol;
  final String host;
  final int port;
  final String username;
  final String password;
  final String path; // 根路径，默认 '/'
  final bool isAnonymous;
  final bool useHttps; // 仅 WebDAV

  const NetworkConnection({
    this.id = 0,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.username = '',
    this.password = '',
    this.path = '/',
    this.isAnonymous = false,
    this.useHttps = false,
  });

  NetworkConnection copyWith({
    int? id,
    String? name,
    NetworkProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    String? path,
    bool? isAnonymous,
    bool? useHttps,
  }) {
    return NetworkConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      path: path ?? this.path,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      useHttps: useHttps ?? this.useHttps,
    );
  }

  /// JSON 序列化。
  ///
  /// [includePassword] = false 时**不写密码**：密码只进加密存储
  /// （`NetworkConnectionSettings` 的 secure storage），SharedPreferences 里
  /// 不留明文（§4.11）。只有加密写入失败时才会退回 `true` 兜底。
  Map<String, dynamic> toJson({bool includePassword = true}) => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'username': username,
        if (includePassword) 'password': password,
        'path': path,
        'isAnonymous': isAnonymous,
        'useHttps': useHttps,
      };

  /// 容错解析：字段缺失/类型不符时回退默认值，损坏单条不拖垮整个列表。
  factory NetworkConnection.fromJson(Map<String, dynamic> json) {
    return NetworkConnection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '未命名',
      protocol:
          NetworkProtocol.tryParse(json['protocol'] as String? ?? '') ??
              NetworkProtocol.webdav,
      host: (json['host'] as String?) ?? '',
      port: (json['port'] as num?)?.toInt() ?? NetworkProtocol.webdav.defaultPort,
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      path: (json['path'] as String?) ?? '/',
      isAnonymous: (json['isAnonymous'] as bool?) ?? false,
      useHttps: (json['useHttps'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'NetworkConnection(id=$id, name=$name, protocol=$protocol, credentials=<redacted>)';
}