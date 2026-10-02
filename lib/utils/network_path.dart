/// 网络连接根下、规范化后的路径值类型（对齐 mpvRx 的 NetworkPath）。
///
/// 值恒为不含 scheme / 凭据 / `.` / `..` 的、以 `/` 开头的显示形式
/// （根为 `/`），`relative` 去掉前导 `/` 供协议客户端拼 URL 用。
library;

import 'package:moumou/utils/error_codes.dart';

/// 网络路径校验失败：[code]，文案在 UI 层（见 `lib/l10n/error_texts.dart`）。
///
/// 原先抛 `ArgumentError`（消息是中文），已无法翻译，故改为携带错误码的自有异常；
/// 调用方本来就按 `catch (e)` 兜底（`_childOrNull` / 流代理），行为等价。
class NetworkPathException implements Exception {
  /// 错误码
  final NetworkPathErrorCode code;

  const NetworkPathException(this.code);

  @override
  String toString() => 'NetworkPathException(${code.name})';
}

class NetworkPath {
  final String value;

  const NetworkPath._(this.value);

  static const root = NetworkPath._('/');

  static const _maxPathChars = 32768;
  static const _maxSegmentChars = 1024;
  static const _maxSegments = 512;

  bool get isRoot => value == '/';

  List<String> get segments =>
      isRoot ? const [] : value.substring(1).split('/');

  String get relative => value.substring(1);

  NetworkPath child(String name) {
    _validateSegment(name);
    return NetworkPath.from(isRoot ? name : '$relative/$name');
  }

  @override
  String toString() => value;

  /// **值相等**：代理的 `knownSizes` / `registerStream` 判断都以值为准。
  ///
  /// 曾因缺 `==` 而按**标识**比较：代理里 `entry.primaryPath` 是注册时那个对象，
  /// 而请求路径由 URL 段重新 `NetworkPath.from` 构造 → 永远不相等，
  /// 「按路径缓存远端大小」永不命中（每个 HTTP 请求都重新查一次远端大小，
  /// `registerStream` 传入的 `fileSize`/`mimeType` 形同虚设）。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NetworkPath && other.value == value);

  @override
  int get hashCode => value.hashCode;

  /// 规范化 + 校验用户/客户端提供的原始路径（不做 URL 解码）。
  static NetworkPath from(String raw) {
    if (raw.contains('://')) {
      throw const NetworkPathException(NetworkPathErrorCode.scheme);
    }
    if (raw.length > _maxPathChars) {
      throw const NetworkPathException(NetworkPathErrorCode.tooLong);
    }
    final segments = raw.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length > _maxSegments) {
      throw const NetworkPathException(NetworkPathErrorCode.tooManySegments);
    }
    for (final s in segments) {
      _validateSegment(s);
    }
    if (segments.isEmpty) return root;
    return NetworkPath._('/${segments.join('/')}');
  }

  static void _validateSegment(String segment) {
    if (segment.isEmpty) {
      throw const NetworkPathException(NetworkPathErrorCode.segmentEmpty);
    }
    if (segment.length > _maxSegmentChars) {
      throw const NetworkPathException(NetworkPathErrorCode.segmentTooLong);
    }
    if (segment == '.' || segment == '..') {
      throw const NetworkPathException(NetworkPathErrorCode.dotSegment);
    }
    if (segment.contains('/') || segment.contains(r'\')) {
      throw const NetworkPathException(NetworkPathErrorCode.segmentSeparator);
    }
    if (segment.codeUnits.any((c) => c == 0 || (c >= 1 && c <= 31) || c == 127)) {
      throw const NetworkPathException(NetworkPathErrorCode.segmentControlChar);
    }
  }
}