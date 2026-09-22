import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 壁纸缩放模式（对齐参考实现 mpvRx 的 `WallpaperScaleMode`）：
/// - [fit]（适应）：整图可见，留边由同图虚化背景填；
/// - [fill]（填充）：等比放大铺满并裁切。
enum WallpaperScaleMode {
  fit('适应'),
  fill('填充');

  final String label;
  const WallpaperScaleMode(this.label);

  /// 解析持久化字符串，未知值回退 [fit]
  static WallpaperScaleMode parse(String? name) => WallpaperScaleMode.values
      .firstWhere((m) => m.name == name, orElse: () => WallpaperScaleMode.fit);
}

/// 自定义壁纸设置：用户选一张图 → 铺在内容与顶部栏之后，可调
/// 缩放 / 水平位置 / 垂直位置 / 模糊 / 透明度。
///
/// 与参考实现 mpvRx（`AppWallpaper.kt` + `AppearancePreferences.kt`）的差异，
/// 都是刻意为之：
/// - **图片不塞进 shared_preferences**（它把图转 Base64 PNG data URI 存偏好，
///   为的是「主题备份可携带」）：Android 的 prefs 是 XML，几十 MB 字符串会拖慢
///   每次读写；我们改为把图**拷进应用目录**、只存路径。代价：将来若做设置备份，
///   壁纸不跟着走（目前没有这个功能）。
/// - **清除时 7 项全重置**（mpvRx 的清除漏了 blur / alpha，残留值会在别处冒出来）。
///
/// 文件放在 `<应用支持目录>/wallpaper/` 而**不是**缓存目录：缓存管理页清
/// 「列表封面缩略图」时会删 cache 下的东西，用户自己选的壁纸不能被顺手删掉。
class WallpaperSettings extends ChangeNotifier {
  static final WallpaperSettings instance = WallpaperSettings._();

  WallpaperSettings._();

  // ── 持久化键（全仓已确认无 wallpaper_ 前缀冲突）────────────────
  static const _keyFile = 'wallpaper_file';
  static const _keyScale = 'wallpaper_scale';
  static const _keyOffsetX = 'wallpaper_offset_x';
  static const _keyOffsetY = 'wallpaper_offset_y';
  static const _keyScaleMode = 'wallpaper_scale_mode';
  static const _keyBlur = 'wallpaper_blur';
  static const _keyOpacity = 'wallpaper_opacity';

  // ── 参数范围（setter / load / UI 滑杆共用同一份真源）──────────────
  static const double minScale = 1.0;
  static const double maxScale = 3.0;
  static const double defaultScale = 1.0;

  static const double minOffset = -1.0;
  static const double maxOffset = 1.0;
  static const double defaultOffset = 0.0;

  static const double minBlur = 0.0;
  static const double maxBlur = 40.0;
  static const double defaultBlur = 0.0;

  static const double minOpacity = 0.0;
  static const double maxOpacity = 1.0;
  static const double defaultOpacity = 1.0;

  // ── 渲染几何（渲染层与调整页共用，避免两处各写一份而漂移）────────
  /// 位移行程：offset = ±1 时平移「容器尺寸 × 该系数」（比例，不是像素）
  static const double offsetTravel = 0.35;

  /// 「适应」模式下垫底的虚化副本参数（对齐 mpvRx 的 1.12 / 0.72 / 28dp）
  static const double fitBackdropScale = 1.12;
  static const double fitBackdropOpacity = 0.72;
  static const double fitBackdropBlur = 28.0;

  /// 模糊滑杆 → `ImageFilter.blur` 的 sigma 换算系数。
  ///
  /// 滑杆范围照抄 mpvRx 的 0–40，但 Compose 的 `Modifier.blur(radius)` 与
  /// Flutter 的 sigma 体感不同；先取 0.5 起步，**真机看着调**这一个常量即可。
  static const double blurSigmaFactor = 0.5;

  /// 解码降采样上限（最长边 px，对齐 mpvRx 的 `MAX_WALLPAPER_DIMENSION_PX`）：
  /// 4000×3000 的图全尺寸解码约 48MB（RGBA），铺满屏根本用不到那么大。
  static const int decodeMaxDimension = 2560;

  /// 测试用：替换「应用支持目录」基准（path_provider 在单元测试里无原生实现）。
  /// 传入的是**基准目录**，壁纸文件仍会放进它下面的 `wallpaper/`。
  @visibleForTesting
  static String? debugDirOverride;

  Future<void>? _loadFuture;

  String? _file;
  double _scale = defaultScale;
  double _offsetX = defaultOffset;
  double _offsetY = defaultOffset;
  WallpaperScaleMode _scaleMode = WallpaperScaleMode.fit;
  double _blur = defaultBlur;
  double _opacity = defaultOpacity;

  /// 壁纸图片的绝对路径；无壁纸时为 null
  String? get path => _file;

  double get scale => _scale;
  double get offsetX => _offsetX;
  double get offsetY => _offsetY;
  WallpaperScaleMode get scaleMode => _scaleMode;
  double get blur => _blur;
  double get opacity => _opacity;

  /// 壁纸是否生效——**唯一判据**（AppFrame 据此决定画不画、主题据此决定透不透明）。
  ///
  /// 文件被用户在文件管理里删掉时 [load] 会把它清空 → 这里自动回 false，
  /// 界面退回不透明主题背景，不会出现「透明 + 没图」的黑屏。
  bool get active => _file != null && _file!.isNotEmpty;

  Future<void> ensureLoaded() => _loadFuture ??= load();

  /// 读盘恢复（失败只回落默认值，绝不让 Future 变 rejected——同 ThemeController
  /// 的纪律：否则每次 setter 首行的 await 都会立刻抛，本次进程内壁纸全废）。
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final file = prefs.getString(_keyFile);
      _file = (file == null || file.isEmpty) ? null : file;
      _scale = _clampScale(prefs.getDouble(_keyScale) ?? defaultScale);
      _offsetX = _clampOffset(prefs.getDouble(_keyOffsetX) ?? defaultOffset);
      _offsetY = _clampOffset(prefs.getDouble(_keyOffsetY) ?? defaultOffset);
      _scaleMode = WallpaperScaleMode.parse(prefs.getString(_keyScaleMode));
      _blur = _clampBlur(prefs.getDouble(_keyBlur) ?? defaultBlur);
      _opacity = _clampOpacity(prefs.getDouble(_keyOpacity) ?? defaultOpacity);

      // 图没了（用户删文件 / 换机 / 清理工具）：静默退回「无壁纸」，
      // 免得永远挂着一个不存在的路径（对齐 AppFontSettings 对丢失字体的处理）
      if (_file != null && !_fileExists(_file!)) {
        _file = null;
      }
    } catch (e) {
      debugPrint('WallpaperSettings: 壁纸读盘失败，沿用默认值：$e');
    } finally {
      notifyListeners();
    }
  }

  /// 保存壁纸：把 [sourcePath]（用户新选的图，可为 null = 只改参数）拷进应用目录，
  /// 并写入全部调整参数。
  ///
  /// 返回 false = 拷贝失败（调用方提示用户重选，**设置保持不变**）。
  /// 拷贝顺序：先写新文件、成功后才删旧文件——中途失败时旧壁纸仍然可用。
  Future<bool> apply({
    String? sourcePath,
    required double scale,
    required double offsetX,
    required double offsetY,
    required WallpaperScaleMode scaleMode,
    required double blur,
    required double opacity,
  }) async {
    await ensureLoaded();

    var target = _file;
    if (sourcePath != null) {
      final copied = await _copyInto(sourcePath);
      if (copied == null) return false;
      target = copied;
    }
    if (target == null) return false;

    final previous = _file;
    _file = target;
    _scale = _clampScale(scale);
    _offsetX = _clampOffset(offsetX);
    _offsetY = _clampOffset(offsetY);
    _scaleMode = scaleMode;
    _blur = _clampBlur(blur);
    _opacity = _clampOpacity(opacity);
    notifyListeners();

    await _persist();
    if (sourcePath != null && previous != null && previous != target) {
      await _deleteQuietly(previous);
    }
    return true;
  }

  /// 清除壁纸：删文件 + **7 项一起回默认**（不用 remove 单键——全删更干净，
  /// 下次 load 自然拿到默认值）。
  Future<void> clear() async {
    await ensureLoaded();
    final previous = _file;
    _file = null;
    _scale = defaultScale;
    _offsetX = defaultOffset;
    _offsetY = defaultOffset;
    _scaleMode = WallpaperScaleMode.fit;
    _blur = defaultBlur;
    _opacity = defaultOpacity;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyFile,
      _keyScale,
      _keyOffsetX,
      _keyOffsetY,
      _keyScaleMode,
      _keyBlur,
      _keyOpacity,
    ]) {
      await prefs.remove(key);
    }
    await _deleteQuietly(previous);
  }

  /// 壁纸文件目录：`<应用支持目录>/wallpaper/`
  Future<Directory> wallpaperDir() async {
    final override = debugDirOverride;
    final base = override ?? (await getApplicationSupportDirectory()).path;
    final dir = Directory(p.join(base, 'wallpaper'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFile, _file ?? '');
    await prefs.setDouble(_keyScale, _scale);
    await prefs.setDouble(_keyOffsetX, _offsetX);
    await prefs.setDouble(_keyOffsetY, _offsetY);
    await prefs.setString(_keyScaleMode, _scaleMode.name);
    await prefs.setDouble(_keyBlur, _blur);
    await prefs.setDouble(_keyOpacity, _opacity);
  }

  /// 把图片拷进应用目录，返回新路径；失败返回 null。
  ///
  /// 文件名带时间戳（不复用原名：同名图替换后 Flutter 的 `FileImage` 缓存键
  /// 不变会显示旧图），扩展名沿用源文件（不认识的回退 .jpg）。
  Future<String?> _copyInto(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!_fileExists(sourcePath)) return null;
      final dir = await wallpaperDir();
      final ext = p.extension(sourcePath).toLowerCase();
      final safeExt = RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '.jpg';
      final target = File(
        p.join(dir.path, 'wallpaper_${DateTime.now().millisecondsSinceEpoch}$safeExt'),
      );
      await source.copy(target.path);
      if (!_fileExists(target.path)) return null;
      return target.path;
    } catch (e) {
      debugPrint('WallpaperSettings: 拷贝壁纸失败：$e');
      return null;
    }
  }

  Future<void> _deleteQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('WallpaperSettings: 删除旧壁纸失败：$e');
    }
  }

  static bool _fileExists(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  static double _clampScale(double v) => v.clamp(minScale, maxScale).toDouble();
  static double _clampOffset(double v) => v.clamp(minOffset, maxOffset).toDouble();
  static double _clampBlur(double v) => v.clamp(minBlur, maxBlur).toDouble();
  static double _clampOpacity(double v) =>
      v.clamp(minOpacity, maxOpacity).toDouble();

  /// 测试用：复位全部状态与加载标记（单例在测试间共享，避免状态泄漏）。
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null;
    _file = null;
    _scale = defaultScale;
    _offsetX = defaultOffset;
    _offsetY = defaultOffset;
    _scaleMode = WallpaperScaleMode.fit;
    _blur = defaultBlur;
    _opacity = defaultOpacity;
    debugDirOverride = null;
    notifyListeners();
  }
}
