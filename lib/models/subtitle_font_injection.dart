/// 自定义字幕字体注入决策（纯函数，便于单测）。
///
/// 背景：Android 上本项目启用 libass 走 mpv 原生字幕渲染
/// （`PlayerConfiguration(libass: true)`），自定义字体必须在 `mpv_initialize`
/// **之前**通过 `libassAndroidFontsDir` / `libassAndroidFontName` 注入；运行时
/// `setProperty('sub-fonts-dir')` 会破坏 libass 字体缓存导致字幕消失
/// （见 `docs/ARCHITECTURE.md` §4.10 与 `third_party/media_kit/FORK.md`）。
///
/// 「是否需要注入」的判断由本文件的纯函数给出，避免该逻辑散落在播放页
/// `initState` 里无法单测。
library;

/// `SubtitleSettings.font` 的「跟随系统字库」哨兵值。
///
/// 该值表示不指定具体字体族名，由 mpv 用 `sub-fonts-dir` 中的默认字库
/// （本项目为 `/system/fonts`）渲染。
const String kAutoSubtitleFont = 'auto';

/// 是否应在构造 `PlayerConfiguration` 时注入自定义字体目录。
///
/// 两个条件必须同时成立：
/// - [font] 不是 [kAutoSubtitleFont]：用户确实选了具体字体族名
///   （libass 的 `sub-font` 按**字体家族名**匹配，`'auto'` 无家族名可匹配）；
/// - [fontsDir] 非空：字体目录已就绪（通常由 `DeviceServices` 把用户导入的字体
///   拷贝到应用私有目录后写入设置）。
///
/// 任一条件不成立时返回 `false`：播放器不注入字体目录，走系统字库直通
/// （`sub-fonts-dir=/system/fonts`），零 APK 开销。
bool shouldInjectCustomSubtitleFont({
  required String font,
  required String fontsDir,
}) {
  return font != kAutoSubtitleFont && fontsDir.isNotEmpty;
}
