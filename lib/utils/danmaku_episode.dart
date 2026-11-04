/// 弹幕集数匹配纯函数（切集自动匹配弹幕，工作.md 第 7 点）：
/// 从视频文件名提取集数，再在自动匹配缓存里找到对应集。
///
/// 纯函数（无状态、无 Flutter 依赖），逻辑对齐参考项目 小喵player 的
/// `DanmakuAutoMatchCache.kt`。
///
/// 集数解析本体已收口到 `utils/episode_number.dart`（字幕/音频/弹幕文件选择器的
/// 「第 N 集」胶囊共用同一份实现）；这里 re-export，既有 import 不受影响。
library;

import 'package:moumou/models/dandan_models.dart';
import 'package:moumou/utils/episode_number.dart';

export 'package:moumou/utils/episode_number.dart' show extractEpisodeNumber;

/// 从集标题提取集数：优先按文件名规则，失败退回「标题里出现的第一个数字」。
///
/// 兜底那条只给**弹弹play 的集标题**用（如「第 3 集 标题」「Episode 3」这种
/// 标题里就一定带集数的场景）；文件选择器的胶囊不用它——那里宁缺勿错。
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

/// 自动定位失败的提示种类（**文案在 UI 层**：`label_maps.danmakuEpisodeLocateHint`）
enum DanmakuEpisodeLocateHint {
  /// 文件名里识别不出集数
  noEpisodeNumber,

  /// 识别出集数，但集列表里没有
  episodeMissing,
}

/// 「按当前视频文件名定位到哪一集」的解析结果。
///
/// [index] < 0 表示未命中（此时 [hint] 说明原因，文案由 UI 层翻译）；命中的
/// [number] 是解析出的集数（失败时为 null），便于调用方做提示文案。
typedef DanmakuEpisodeLocation = ({
  int index,
  double? number,
  DanmakuEpisodeLocateHint? hint,
});

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
    return (index: -1, number: null, hint: null);
  }
  final number = extractEpisodeNumber(fileName);
  if (number == null) {
    return (
      index: -1,
      number: null,
      hint: DanmakuEpisodeLocateHint.noEpisodeNumber,
    );
  }
  final match = findMatchingEpisode(episodes, number);
  final index = match == null ? -1 : episodes.indexOf(match);
  if (index < 0) {
    return (
      index: -1,
      number: number,
      hint: DanmakuEpisodeLocateHint.episodeMissing,
    );
  }
  return (index: index, number: number, hint: null);
}
