/// 版本号比较纯函数（工作.md：更新功能，对齐 Kazumi `utils/version.dart`）。
///
/// 语义：远端版本号 [remoteVersion] 大于本地版本号 [localVersion] 时返回 true
/// （需要更新），相等或更小返回 false。
///
/// 解析规则：
/// - 忽略前导 `v`（`v1.1.0` == `1.1.0`）；
/// - 按 `.` 拆分逐段比较，缺失段视为 0（`1.1` == `1.1.0`）；
/// - 每段取数字前缀（`10-beta` → `10`），非数字段视为 0。
library;

/// 远端 > 本地 → true
bool needUpdate(String localVersion, String remoteVersion) {
  final local = _parseVersion(localVersion);
  final remote = _parseVersion(remoteVersion);
  final maxLength = local.length > remote.length ? local.length : remote.length;
  for (var i = 0; i < maxLength; i++) {
    final localSegment = i < local.length ? local[i] : 0;
    final remoteSegment = i < remote.length ? remote[i] : 0;
    if (remoteSegment > localSegment) return true;
    if (remoteSegment < localSegment) return false;
  }
  return false;
}

/// 版本号字符串 → 数字段列表（忽略前导 v、按 `.` 拆分、每段取数字前缀）
List<int> _parseVersion(String version) {
  var v = version.trim();
  if (v.toLowerCase().startsWith('v')) v = v.substring(1);
  return v.split('.').map((segment) {
    final match = RegExp(r'^\d+').firstMatch(segment.trim());
    if (match == null) return 0;
    return int.tryParse(match.group(0)!) ?? 0;
  }).toList();
}
