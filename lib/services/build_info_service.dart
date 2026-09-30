import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 构建信息（关于页顶部卡片的三枚字段：版本 / 构建类型 / 提交哈希）。
///
/// 数据来源分三处：
/// - **版本**：`package_info_plus`（`pubspec.yaml` 的 `version:`，如 `1.3.6+4`）；
/// - **构建类型**：编译期常量 [kReleaseMode]（release 包为真，debug/profile 为假），
///   零成本、不依赖任何构建参数；
/// - **提交哈希**：**只能由构建期注入** —— Flutter 没有 Android `BuildConfig` 那样的
///   现成来源，`package_info_plus` 也不提供。三个构建脚本（`tools/build_split_apk.bat`、
///   `tools/build_and_install.ps1`、`tools/usb_debug_run.ps1`）会在构建前读一次
///   `git rev-parse`，用 `--dart-define` 把结果传进来。
///
/// 因此：**用 Android Studio 直接 Run/Debug（或裸 `flutter run`）时读不到哈希**，
/// 此时显示「dev build」而不是编一个值出来（工作纪律：不糊弄）。
class BuildInfo {
  /// 版本名（如 `1.3.6`）；读不到时为空串。
  final String version;

  /// 构建号（versionCode，如 `4`）；读不到时为空串。
  /// 当前不参与 [versionLabel] 展示，保留给需要精确定位安装包的场景。
  final String buildNumber;

  /// 构建类型标签：`release` 或 `debug`（profile 也归入 `debug` 之外的判断见 [isRelease]）。
  final bool isRelease;

  /// 构建期注入的提交哈希（可能是 `b7734f1-dirty` 形式）；未注入时为 `unknown`。
  final String revision;

  const BuildInfo({
    this.version = '',
    this.buildNumber = '',
    this.isRelease = true,
    this.revision = unknownRevision,
  });

  /// 未注入哈希时的占位值（构建脚本与这里必须一致，否则判断会漂移）
  static const String unknownRevision = 'unknown';

  /// 从 `--dart-define` 读取的原始值（编译期常量，测试无法伪造，故逻辑都放纯函数里）
  static const String rawRevision = String.fromEnvironment('GIT_HASH', defaultValue: unknownRevision);

  /// 读取本机 App 的版本信息（失败返回空版本的 [BuildInfo]，不抛异常）
  static Future<BuildInfo> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return BuildInfo(
        version: info.version,
        buildNumber: info.buildNumber,
        isRelease: kReleaseMode,
        revision: rawRevision,
      );
    } catch (_) {
      // 版本读不到不该让关于页崩：退化成空版本 + 编译期常量
      return BuildInfo(isRelease: kReleaseMode, revision: rawRevision);
    }
  }

  /// 版本胶囊文案：只显示版本名（如 `v1.3.6`）；完全读不到时 `v—`。
  ///
  /// 刻意**不带构建号**（`+4`）：Android 上 `package_info_plus` 给的是 versionName 与
  /// versionCode 两个独立值，拿不到 `pubspec.yaml` 里那个原始字符串，
  /// 拼出 `v1.3.6+4` 这种混合形态反而容易被误读成官方版本号的一部分。
  /// 构建号仍可在 [buildNumber] 里取到，需要时再用。
  String get versionLabel {
    final v = version.trim();
    return v.isEmpty ? 'v—' : 'v$v';
  }

  /// 构建类型胶囊文案。
  String get buildTypeLabel => isRelease ? 'release' : 'debug';

  /// 哈希胶囊文案：`b7734f1`（dirty 另有一枚角标，见 [isDirty]）。
  String get revisionLabel {
    final r = normalizeRevision(revision);
    return r.isEmpty ? 'dev build' : r;
  }

  /// 工作区有未提交改动（构建脚本会在哈希后加 `-dirty`）。
  bool get isDirty => revision.toLowerCase().endsWith('-dirty');

  /// 版本是否可用（空版本时胶囊显示占位符，功能上仍可用）
  bool get hasVersion => version.trim().isNotEmpty;

  /// 规范化构建脚本注入的哈希：
  /// - `unknown` / 空 → 空串（调用方据此显示「dev build」）；
  /// - 去掉 git 在 `--long` 形态下加的 `g` 前缀（`g1a2b3c4` → `1a2b3c4`）；
  /// - 去掉 `-dirty` 后缀（是否 dirty 由 [isDirty] 单独表达）。
  static String normalizeRevision(String raw) {
    var r = raw.trim();
    if (r.isEmpty) return '';
    if (r.toLowerCase() == unknownRevision) return '';
    if (r.toLowerCase().endsWith('-dirty')) {
      r = r.substring(0, r.length - '-dirty'.length);
    }
    if (r.length > 1 && (r[0] == 'g' || r[0] == 'G')) {
      // 只剥「g + 十六进制」形态，避免把正常的哈希首字符吃掉
      final rest = r.substring(1);
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(rest)) r = rest;
    }
    return r;
  }

  /// 提示文案：点击哈希胶囊时给出反馈（未注入时说明为什么没有）
  String copyHint() {
    if (!hasRevision) return '本次构建未注入提交哈希（需用 tools/ 里的构建脚本编译）';
    return isDirty ? '已复制 $revisionLabel（工作区有未提交改动）' : '已复制 $revisionLabel';
  }

  /// 是否拿到了构建期注入的哈希
  bool get hasRevision => normalizeRevision(revision).isNotEmpty;
}
