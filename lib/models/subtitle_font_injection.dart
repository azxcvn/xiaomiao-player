/// 自定义字幕字体注入决策（纯函数，便于单测）。
///
/// 背景：Android 上本项目启用 libass 走 mpv 原生字幕渲染
/// （`PlayerConfiguration(libass: true)`），字体目录必须在 `mpv_initialize`
/// **之前**通过 `libassAndroidFontsDir` / `libassAndroidFontName` 注入；运行时
/// `setProperty('sub-fonts-dir')` 会破坏 libass 字体缓存导致字幕消失
/// （见 `docs/ARCHITECTURE.md` §4.10 与 `third_party/media_kit/FORK.md`）。
///
/// ⚠️ **本文件承载的是一条硬约定**：`sub-fonts-dir` 只在构造期注入，任何运行时
/// 写入都是回归。注意「跟随系统字库」同样属于「要注入」——它注入的是
/// [kSystemFontsDir]，而不是靠运行时写属性把目录切回系统字库。历史上正是
/// 「默认字体时运行时写 `sub-fonts-dir=/system/fonts`」这条路径把 libass 字体
/// 缓存打坏，导致**内嵌字幕（含 PGS 等位图字幕）整条不渲染**。
library;

/// `SubtitleSettings.font` 的「跟随系统字库」哨兵值。
///
/// 该值表示不指定用户导入的字体族名，改用系统字库
/// （[kSystemFontsDir] + [kSystemFontName]）渲染。
const String kAutoSubtitleFont = 'auto';

/// Android 系统字库目录（直通系统字体，零 APK 开销）。
///
/// 该路径只在 `PlayerConfiguration` 构造期注入；**禁止**在播放期间
/// `setProperty('sub-fonts-dir')`（见文件头说明）。
const String kSystemFontsDir = '/system/fonts';

/// 系统字库默认字体族名（Android Noto CJK）。
const String kSystemFontName = 'Noto Sans CJK SC';

/// 一次 Player 构造要注入的 libass 字体配置。
class SubtitleFontInjection {
  /// 注入 `libassAndroidFontsDir` 的字体目录绝对路径。
  final String fontsDir;

  /// 注入 `libassAndroidFontName` 的字体族名（libass 按家族名匹配，不是文件名）。
  final String fontName;

  const SubtitleFontInjection({required this.fontsDir, required this.fontName});

  @override
  bool operator ==(Object other) =>
      other is SubtitleFontInjection &&
      other.fontsDir == fontsDir &&
      other.fontName == fontName;

  @override
  int get hashCode => Object.hash(fontsDir, fontName);

  @override
  String toString() =>
      'SubtitleFontInjection(fontsDir: $fontsDir, fontName: $fontName)';
}

/// 本次进入播放器应注入的 libass 字体配置（**永不返回 null**）。
///
/// - 用户已选具体字体（[font] 非 [kAutoSubtitleFont]）且目录就绪（[fontsDir]
///   非空）→ 注入用户字体目录 + 该字体族名；
/// - 否则（含默认「跟随系统字库」、选中字体但目录为空/目录尚未落盘）→ 注入
///   [kSystemFontsDir] + [kSystemFontName]。
///
/// 第二种情况一样是「注入」而非「不注入」：目录为空的用户字体或 `null` 都会
/// 让 media_kit 完全不注入 `sub-fonts-dir`，此时 libass 只能读到 APK 内的
/// `subfont.ttf`（Android 上不存在）→ 文本字幕缺字/方块。系统字库目录必须由
/// 构造期注入，运行时写属性不可用。
SubtitleFontInjection resolveSubtitleFontInjection({
  required String font,
  required String fontsDir,
}) {
  final family = font.trim();
  final dir = fontsDir.trim();
  // 目录或族名任一为空都视为「用户字体不可用」——空族名注入会让 libass 匹配不到
  // 任何字体，比回落系统字库更糟（`shouldInjectCustomSubtitleFont` 只判
  // 「非 auto + 目录非空」，不覆盖空族名，这里必须再判一次）。
  if (family.isEmpty || dir.isEmpty) {
    return const SubtitleFontInjection(
      fontsDir: kSystemFontsDir,
      fontName: kSystemFontName,
    );
  }
  if (shouldInjectCustomSubtitleFont(font: family, fontsDir: dir)) {
    return SubtitleFontInjection(fontsDir: dir, fontName: family);
  }
  return const SubtitleFontInjection(
    fontsDir: kSystemFontsDir,
    fontName: kSystemFontName,
  );
}

/// 是否应在构造 `PlayerConfiguration` 时注入**用户自定义**字体目录。
///
/// 两个条件必须同时成立：
/// - [font] 不是 [kAutoSubtitleFont]：用户确实选了具体字体族名
///   （libass 的 `sub-font` 按**字体家族名**匹配，`'auto'` 无家族名可匹配）；
/// - [fontsDir] 非空：字体目录已就绪（通常由 `DeviceServices` 把用户导入的字体
///   拷贝到应用私有目录后写入设置）。
///
/// 返回 `false` 不代表「不注入字体目录」，而是「注入系统字库」
/// （见 [resolveSubtitleFontInjection]）。
bool shouldInjectCustomSubtitleFont({
  required String font,
  required String fontsDir,
}) {
  return font != kAutoSubtitleFont && fontsDir.isNotEmpty;
}
