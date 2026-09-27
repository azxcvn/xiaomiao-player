/// 内嵌字幕轨的**中文优先**选择（纯函数，可单测）。
///
/// 背景：mpv 打开文件时自己挑一条字幕轨（通常是**第一条**），多字幕的片子
/// （正片常见「中英特效 / 简中 / 繁中 / 英文」四五条）默认很可能落在一条英文
/// 或非特效轨上。这里在「用户从没为这个视频选过字幕」时，按语言/标题把默认
/// 选择换成中文优先的那条。
///
/// ## 判定顺序（分数越高越优先）
///
/// 1. 语言或标题命中**中文标记**，且标题带「特效 / 双语 / 简英 / 繁英」→ +3；
/// 2. 语言或标题命中中文标记 → +2；
/// 3. 其余语言 → 0（不参与，保持 mpv 的原选择）。
///
/// 中文标记同时看 `lang`（`zh` / `chi` / `zho` / `cn` / `chs` / `cht` / `sc` /
/// `tc` / 中文本身）与 `title`（「简体 / 繁体 / 简中 / 繁中 / 中字 / 中文 /
/// 中文简体」等）。
///
/// ⚠️ **不做英文优先**：没有中文轨时返回 null，调用方维持原样。
/// ⚠️ 「特效/双语」只在**中文轨之间**比较，不会让英文特效轨压过普通中文轨。
library;

import 'package:moumou/models/subtitle_track.dart';

/// 中文语言标记（小写比较；mpv 的 `lang` 常是 ISO 639-1/2/B 站风格缩写）
const Set<String> _chineseLangMarkers = {
  'zh', 'zho', 'chi', 'cn', 'chs', 'cht', 'zh-cn', 'zh-tw', 'zh-hans',
  'zh-hant', 'sc', 'tc',
};

/// 中文标题关键词
const List<String> _chineseTitleKeywords = [
  '中文', '中字', '简体', '繁体', '简中', '繁中', '中英', '简英', '繁英',
  '简体中文', '繁體', '中文简体', '中文繁体',
];

/// 特效/双语优先关键词（仅中文轨之间比较）
const List<String> _effectKeywords = ['特效', '双语', '简英', '繁英', 'ASS 特效'];

/// 语言标记是否是中文（`zh` / `chi` / `zho` / `chs` / `cht` / 含「中文」等）
bool isChineseSubtitleLanguage(String? language) {
  final lang = (language ?? '').trim().toLowerCase();
  if (lang.isEmpty) return false;
  if (_chineseLangMarkers.contains(lang)) return true;
  // 形如 `zh-Hans` / `zh_CN` / `chi (Simplified)`：把分隔符归一再比前缀
  final head = lang.split(RegExp(r'[-_\s(]')).first;
  if (_chineseLangMarkers.contains(head)) return true;
  return lang.contains('chinese') || lang.contains('中文');
}

/// 标题是否像中文轨
bool _titleLooksChinese(String? title) {
  final t = (title ?? '').toLowerCase();
  if (t.isEmpty) return false;
  for (final k in _chineseTitleKeywords) {
    if (t.contains(k.toLowerCase())) return true;
  }
  return false;
}

/// 标题是否带特效/双语
bool _titleLooksEffect(String? title) {
  final t = (title ?? '').toLowerCase();
  if (t.isEmpty) return false;
  for (final k in _effectKeywords) {
    if (t.contains(k.toLowerCase())) return true;
  }
  return false;
}

/// 单条字幕轨的中文优先得分（0 = 不是中文轨，不参与替换）
int chinesePreferenceScore(SubtitleTrack track) {
  final chinese =
      isChineseSubtitleLanguage(track.language) || _titleLooksChinese(track.title);
  if (!chinese) return 0;
  return _titleLooksEffect(track.title) ? 3 : 2;
}

/// 从字幕轨里挑出中文优先的那条；没有中文轨返回 null（调用方维持原样）。
///
/// 同分时取**列表里靠前**的那条（保持文件里的自然顺序，稳定可预期）。
SubtitleTrack? bestChineseSubtitleTrack(List<SubtitleTrack> tracks) {
  SubtitleTrack? best;
  var bestScore = 0;
  for (final t in tracks) {
    final score = chinesePreferenceScore(t);
    if (score > bestScore) {
      best = t;
      bestScore = score;
    }
  }
  return best;
}

/// 是否该把当前生效轨换成 [best]（纯决策，便于单测）。
///
/// - 当前轨已经和最优轨同一条 → 不换；
/// - 当前轨本身也是中文（含特效） → 不换（尊重用户/文件里已有的中文选择，
///   例如他上次选的繁中，不该被简中特效抢走）；
/// - 其余情况（当前轨是非中文，或 mpv 还没选出轨）→ 换。
bool shouldSwitchToChineseTrack({
  required SubtitleTrack? current,
  required SubtitleTrack? best,
}) {
  if (best == null) return false;
  if (current == null) return true;
  if (current.id == best.id) return false;
  if (chinesePreferenceScore(current) > 0) return false;
  return true;
}
