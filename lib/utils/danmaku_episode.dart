/// 弹幕集数匹配纯函数（切集自动匹配弹幕，工作.md 第 7 点）：
/// 从视频文件名提取集数，再在自动匹配缓存里找到对应集。
///
/// 纯函数（无状态、无 Flutter 依赖），逻辑对齐参考项目 小喵player 的
/// `DanmakuAutoMatchCache.kt`。
library;

import 'package:moumou/models/dandan_models.dart';

/// 从视频文件名提取集数（去扩展名后按多套规则依次匹配）。
///
/// 支持：`01.mkv` / `第01话` / `S01E01` / `EP01` /
/// `[Group] Anime - 01 [1080p].mkv` / `Anime_12.5.mkv` 等。
/// 无法识别返回 null。
///
/// **也接受完整路径**（`/storage/emulated/0/Download/1.mp4`、`smb://nas/a/2.mkv`、
/// `C:\Videos\3.mp4`）：先取路径最后一段再匹配。播放页拿到的是完整路径，而纯
/// 数字文件名（`1`、`2`、`3`…）的规则是**首尾锚定**的，路径里带 `/` 就会失配
/// ——用户实测"文件名是 1、2、3 的视频定位不到"就是这个原因（切集自动匹配那条
/// 链路在调用处 `p.basename` 过，网络弹幕面板这条没有）。
double? extractEpisodeNumber(String fileName) {
  final base = _baseName(fileName);
  final fromBase = _matchEpisodeNumber(base);
  if (fromBase != null) return fromBase;
  // 兜底：万一路径分隔符其实是标题本身的一部分（如「第1/2话」），原串再试一次
  return base == fileName ? null : _matchEpisodeNumber(fileName);
}

/// 取路径最后一段：`/a/b/1.mkv` → `1.mkv`。
///
/// `/` 与 `\` 都当分隔符，不依赖当前平台——Android 上跑来自 Windows 的网络路径
/// 也不会误判。没有分隔符时原样返回。
String _baseName(String path) {
  var cut = -1;
  for (final sep in const ['/', '\\']) {
    final at = path.lastIndexOf(sep);
    if (at > cut) cut = at;
  }
  return cut < 0 ? path : path.substring(cut + 1);
}

/// 按文件名（不含目录）匹配集数：去扩展名后依次套规则。
double? _matchEpisodeNumber(String fileName) {
  final raw = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  // 首尾空白容错：云盘/网络传输/重命名的文件名常带空格，而「纯数字文件名」
  // 等规则是首尾锚定的，一个空格就会失配
  final name = raw.trim();

  // S01E01（季 + 集，取集）
  final sxxExx = RegExp(r'[Ss](\d+)[Ee](\d+)').firstMatch(name);
  if (sxxExx != null) return double.tryParse(sxxExx.group(2)!);

  // 第01话 / 第01集 / 第01回
  final di = RegExp(r'第\s*(\d+(?:\.\d+)?)\s*[话集回話]').firstMatch(name);
  if (di != null) return double.tryParse(di.group(1)!);

  // EP01 / ep01
  final ep = RegExp(r'[Ee][Pp]\s*(\d+(?:\.\d+)?)').firstMatch(name);
  if (ep != null) return double.tryParse(ep.group(1)!);

  // 末尾集数（前有分隔符，可带 v2 修正与 [1080p]/【1080p】等后缀）
  final trailing = RegExp(
    r'[\[【\s\-_#](\d+(?:\.\d+)?)(?:[vV]\d+)?'
    r'(?:\s*(?:\[[^\]]*\]|【[^】]*】|[\]】]))?\s*$',
  ).firstMatch(name);
  if (trailing != null) return double.tryParse(trailing.group(1)!);

  // 开头集数（`01 - Title` 格式）
  final leading = RegExp(r'^(\d+(?:\.\d+)?)\s*[-–—_\s]').firstMatch(name);
  if (leading != null) return double.tryParse(leading.group(1)!);

  // 纯数字文件名
  final pure = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(name);
  if (pure != null) return double.tryParse(pure.group(1)!);

  return null;
}

/// 从集标题提取集数：优先按文件名规则，失败退回「标题里出现的第一个数字」。
double? extractEpisodeNumberFromTitle(String episodeTitle) {
  final direct = extractEpisodeNumber(episodeTitle);
  if (direct != null) return direct;
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(episodeTitle);
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// 按集数在集列表中找到匹配集：先按标题集数精确匹配，失败按「集数取整 →
/// 数组下标」回退（第 N 集 = 列表第 N 项，应对标题无集数的情况）。
DandanEpisode? findMatchingEpisode(
  List<DandanEpisode> episodes,
  double episodeNumber,
) {
  for (final ep in episodes) {
    final num = extractEpisodeNumberFromTitle(ep.episodeTitle);
    if (num != null && (num - episodeNumber).abs() < 0.001) return ep;
  }
  final index = episodeNumber.toInt() - 1;
  if (index >= 0 && index < episodes.length) return episodes[index];
  return null;
}

/// 「按当前视频文件名定位到哪一集」的解析结果。
///
/// [index] < 0 表示未命中（此时 [message] 为给用户看的说明）；命中的 [number]
/// 是解析出的集数（失败时为 null），便于调用方做提示文案。
typedef DanmakuEpisodeLocation = ({int index, double? number, String? message});

/// 从当前视频文件名解析集数，并在集列表里定位（供网络弹幕面板**自动定位**用）。
///
/// 纯函数（无副作用、不依赖 UI）：面板只负责把结果落到滚动 + 高亮上。
/// 解析与匹配都复用 [extractEpisodeNumber] / [findMatchingEpisode]——
/// 与「切集自动匹配」同一套规则，避免两处行为漂移。
DanmakuEpisodeLocation locateCurrentEpisode(
  String? fileName,
  List<DandanEpisode> episodes,
) {
  if (fileName == null || fileName.isEmpty) {
    return (index: -1, number: null, message: null);
  }
  final number = extractEpisodeNumber(fileName);
  if (number == null) {
    return (
      index: -1,
      number: null,
      message: '未能从文件名识别集数，可用上方输入框直接跳转',
    );
  }
  final match = findMatchingEpisode(episodes, number);
  final index = match == null ? -1 : episodes.indexOf(match);
  if (index < 0) {
    return (
      index: -1,
      number: number,
      message: '未找到第 ${number.toInt()} 集，可用上方输入框直接跳转',
    );
  }
  return (index: index, number: number, message: null);
}
