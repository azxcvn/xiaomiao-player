/// 文件名集数解析（纯函数，无 Flutter 依赖）。
///
/// 用途（三处共用同一份实现）：
/// - 「切集自动匹配弹幕」从当前视频文件名里取集数（`danmaku_service`）；
/// - 网络弹幕面板按当前集自动定位；
/// - 文件选择器（字幕/音频/弹幕）行尾的「第 N 集」胶囊。
///
/// 设计取舍（为什么不是一条大正则）：
/// - 只认「显式集数标记」与「语境明确的独立数字」，其余一律返回 null ——
///   **宁可不出胶囊，也不显示错的集数**（`1080p`、`2024`、`x264` 这类数字
///   一旦被当成集数，用户会按错集去选文件）；
/// - 决议顺序：显式标记（`第03话` / `S01E03` / `EP03`）→ 合集/特别篇哨兵 →
///   数字 token 打分（`- 03` > `[03]` > 裸数字，同分取靠后者）；
/// - 集数上限 [kMaxEpisodeNumber]：5 位及以上的数字更像编号/时间戳。
///
/// 参考实现（思路来源，本文件是精简版、不追求覆盖冷门命名）：
/// - anitomy（C++）：分词 + 关键词表 + 数字语境判定；
/// - Auto_Bangumi `raw_parser.py`：先抓「集数段」再在段内取数字。
library;

/// 集数上限：超过这个值的「数字」基本是编号、日期或文件大小，按集数处理只会误导。
const int kMaxEpisodeNumber = 9999;

/// 从文件名（或完整路径）解析集数；解析不出来返回 null。
///
/// 支持：`01.mkv` / `第01话` / `第一集` / `S01E03` / `EP03` / `Episode 3` /
/// `[Group] Anime - 01v2 [1080p].mkv` / `[Group][Anime][03][1080p].mkv` /
/// `Anime_12.5.mkv` / `01 - Title.mkv` 等。
double? extractEpisodeNumber(String fileName) {
  final raw = fileName.trim();
  if (raw.isEmpty) return null;
  final base = _baseName(raw);
  final parsed = _parseName(base);
  if (parsed != null) return parsed;
  // 兜底：路径分隔符其实是标题本身的一部分（如 `Show 第1话/ep.mkv`）时按原串再试，
  // **只认显式集数标记**——裸数字一律不认，否则 `/2024/Show.mkv` 这类目录名会被
  // 当成集数（旧实现就踩过这个坑）。
  return base == raw ? null : _explicitEpisode(raw);
}

double? _parseName(String name) {
  final stem = _stripExtension(name).trim();
  if (stem.isEmpty) return null;

  // 1) 显式集数标记：文件名自己写明了「第几集」，直接采信
  final explicit = _explicitEpisode(stem);
  if (explicit != null) return explicit;

  // 2) 合集 / 特别篇 / 剧场版：这类文件没有「第几集」的语义，不猜
  if (_isBatchOrSpecial(stem)) return null;

  // 3) 数字 token 打分：`- 03` > `[03]` > 裸数字，同分取靠后者
  final normalized = _normalizeDots(stem);
  final tokens = _tokenize(normalized);
  var bestScore = -1;
  double? best;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final value = _numberOf(token.text);
    if (value == null || !_validRange(value)) continue;
    // 年份（`2024 - 03` 里的 2024、`(2008)` 这类）不是集数。写明的「第2024集」
    // 另说——那条走的是 1) 显式标记，不受这里限制
    if (_looksLikeYear(value)) continue;
    // 分辨率数字（`[1080]`、裸 `720`）不是集数：宁可这一行不出胶囊
    if (_looksLikeResolution(value)) continue;
    // 区间一端（`01-12` 合集 / `2024-10-01` 日期）不参与
    if (_isRangePart(tokens, normalized, i)) continue;
    final score = token.afterDash ? 10 : (token.inBracket ? 8 : 0);
    if (score >= bestScore) {
      bestScore = score;
      best = value;
    }
  }
  return best;
}

/// 显式集数标记（最高置信，命中即用）。返回前做范围校验。
double? _explicitEpisode(String text) {
  // 第01话 / 第01集 / 第01回 / 第01話 / 第 1.5 话
  final numeric = RegExp(r'第\s*(\d+(?:\.\d+)?)\s*[话話集回]').firstMatch(text);
  if (numeric != null) {
    return _acceptRange(double.tryParse(numeric.group(1)!));
  }
  // 第一话 / 第十二集（中文数字，一 – 九十九）
  final chinese = RegExp(r'第\s*([一二三四五六七八九十]+)\s*[话話集回]')
      .firstMatch(text);
  if (chinese != null) {
    final value = _chineseNumber(chinese.group(1)!);
    return value == null ? null : _acceptRange(value.toDouble());
  }
  // S01E03（季 + 集，取集）
  final seasonEpisode = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,4})').firstMatch(text);
  if (seasonEpisode != null) {
    return _acceptRange(double.tryParse(seasonEpisode.group(2)!));
  }
  // EP03 / Ep.03 / Episode 3
  final ep = RegExp(r'(?:[Ee][Pp]|[Ee]pisode)[\s._-]*(\d{1,4})')
      .firstMatch(text);
  if (ep != null) return _acceptRange(double.tryParse(ep.group(1)!));
  // [E03]（只认方括号里的字母 E，避免把单词里的 e3 当集数）
  final bracketed = RegExp(r'\[\s*[Ee]\.?\s*(\d{1,4})\s*\]').firstMatch(text);
  if (bracketed != null) return _acceptRange(double.tryParse(bracketed.group(1)!));
  return null;
}

/// 取值合法（0 < 值 ≤ [kMaxEpisodeNumber]），否则 null。
double? _acceptRange(double? value) {
  if (value == null || !_validRange(value)) return null;
  return value;
}

/// 取值是否落在集数的合理范围内。
bool _validRange(double value) => value > 0 && value <= kMaxEpisodeNumber;

/// 4 位且落在常见年份区间 → 更像年份而不是集数。
bool _looksLikeYear(double value) {
  if (value != value.roundToDouble()) return false;
  final v = value.toInt();
  return v >= 1900 && v <= 2099;
}

/// 常见分辨率数字（`[1080]`、裸 `720`）→ 当集数几乎必错。
///
/// 代价：真有「第 1080 集」且文件名只写裸数字时会丢胶囊（写 `第1080集` 不受影响）。
/// 这是「宁可不出、也不出错」取舍的一部分。
const Set<int> _resolutionLikeNumbers = {
  240, 360, 480, 540, 576, 720, 1080, 1440, 2160, 4320,
};

bool _looksLikeResolution(double value) {
  return value == value.roundToDouble() &&
      _resolutionLikeNumbers.contains(value.toInt());
}

/// 合集 / 特别篇 / 剧场版类关键字（只按整 token 或中文子串匹配）。
///
/// 故意**不含** `END`、`完`：`[03][END]` 是「第 3 集（最终话）」，那是正经集数。
const List<String> _batchKeywords = [
  '合集',
  '全集',
  '合辑',
  '总集篇',
  '剧场版',
  '特别篇',
  '预告',
  '預告',
  'ova',
  'oad',
  'movie',
  'sp',
  'pv',
  'cm',
  'ncop',
  'nced',
  'menu',
  'recap',
];

/// 是不是「没有第几集语义」的文件。
///
/// 中文关键字按子串匹配（`番名合集` 也算），英文缩写只按**整 token**匹配
/// （避免把 `Sport` 里的 `sp`、`Camp` 里的 `cm` 误判成特别篇）。
bool _isBatchOrSpecial(String stem) {
  for (final token in _tokenize(_normalizeDots(stem))) {
    final normalized = token.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
    if (normalized.isEmpty) continue;
    for (final keyword in _batchKeywords) {
      final isAscii = RegExp(r'^[a-z0-9]+$').hasMatch(keyword);
      if (isAscii ? normalized == keyword : normalized.contains(keyword)) {
        return true;
      }
    }
  }
  return false;
}

/// 一个待分析的分词。
class _Token {
  /// 词面（括号组取括号里的内容）
  final String text;

  /// 是否来自一个完整的括号组（`[03]` / `【03】` / `(03)`）
  final bool inBracket;

  /// 前一个非空白字符是否是破折号（`- 03` 这种最常见的集数写法）
  final bool afterDash;

  /// 在归一化文本里的区间（判断「两个数字之间是不是只有一个破折号」用）
  final int start;
  final int end;

  const _Token(
    this.text, {
    required this.inBracket,
    required this.afterDash,
    required this.start,
    required this.end,
  });
}

/// 分词：括号组整体算一个词，其余按空白与常见分隔符切开。
///
/// 注意 `.` 不能无脑当分隔符：`Anime_12.5.mkv` 的 `12.5` 是一个整体（先由
/// [_normalizeDots] 把「非数字之间的点」换成空格，小数点保留）。
final RegExp _tokenPattern = RegExp(
  r'\[[^\]]*\]|【[^】]*】|\([^)]*\)|（[^）]*）'
  r'|[^\[\]【】()（）\s_\-–—~+&|,;:!?]+',
);

/// [text] 需已过 [_normalizeDots]。
List<_Token> _tokenize(String text) {
  final tokens = <_Token>[];
  for (final match in _tokenPattern.allMatches(text)) {
    final raw = match.group(0)!;
    // 前一个非空白字符是破折号 → 这个词是「- 03」形态的集数
    var i = match.start - 1;
    while (i >= 0 && text[i] == ' ') {
      i--;
    }
    final afterDash = i >= 0 && '–—-~'.contains(text[i]);
    final isBracketGroup = raw.startsWith(RegExp(r'[\[【(（]'));
    if (isBracketGroup) {
      final inner = raw.substring(1, raw.length - 1).trim();
      if (inner.isNotEmpty) {
        tokens.add(_Token(
          inner,
          inBracket: true,
          afterDash: afterDash,
          start: match.start,
          end: match.end,
        ));
      }
      continue;
    }
    tokens.add(_Token(
      raw,
      inBracket: false,
      afterDash: afterDash,
      start: match.start,
      end: match.end,
    ));
  }
  return tokens;
}

/// 把「不夹在数字之间的点」当成空白（小数点保留）。
String _normalizeDots(String text) {
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c != '.') {
      buf.write(c);
      continue;
    }
    final prevIsDigit = i > 0 && _isAsciiDigit(text.codeUnitAt(i - 1));
    final nextIsDigit =
        i + 1 < text.length && _isAsciiDigit(text.codeUnitAt(i + 1));
    buf.write(prevIsDigit && nextIsDigit ? '.' : ' ');
  }
  return buf.toString();
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// 词的数字值：`03` / `12.5` / `03v2`（版本后缀先剥掉）→ 数字；其余 null。
double? _numberOf(String token) {
  final match = RegExp(r'^(\d+(?:\.\d+)?)(?:[vV]\d+)?$').firstMatch(token.trim());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// 这个数字词是不是区间的一端（`01-12` 合集、`2024-10-01` 日期）。
///
/// 判定要求两个数字之间**只有破折号、不带空格**：`01-12` 是区间，而
/// `86 - 03` / `Anime 2 - 03` 是「标题里的数字 + 集数」，不能误判。
bool _isRangePart(List<_Token> tokens, String normalized, int index) {
  final current = tokens[index];
  if (index + 1 < tokens.length) {
    final right = tokens[index + 1];
    if (_numberOf(right.text) != null &&
        _isBareDash(normalized.substring(current.end, right.start))) {
      return true;
    }
  }
  if (index - 1 >= 0) {
    final left = tokens[index - 1];
    if (_numberOf(left.text) != null &&
        _isBareDash(normalized.substring(left.end, current.start))) {
      return true;
    }
  }
  return false;
}

/// 两个词之间是不是「紧贴着一个破折号」（不看空格）。
bool _isBareDash(String gap) => RegExp(r'^[-–—~]$').hasMatch(gap);

/// 中文数字（一 – 九十九）→ 整数；不认识返回 null。
int? _chineseNumber(String text) {
  const digits = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  if (text == '十') return 10;
  final tenAt = text.indexOf('十');
  if (tenAt < 0) return text.length == 1 ? digits[text] : null;
  final tensPart = text.substring(0, tenAt);
  final onesPart = text.substring(tenAt + 1);
  final tens = tensPart.isEmpty ? 1 : digits[tensPart];
  final ones = onesPart.isEmpty ? 0 : digits[onesPart];
  if (tens == null || ones == null) return null;
  return tens * 10 + ones;
}

/// 取路径最后一段：`/a/b/1.mkv` → `1.mkv`。
///
/// `/` 与 `\` 都当分隔符，不依赖当前平台——Android 上跑来自 Windows 的网络路径
/// 也不会误判。没有分隔符时原样返回。
String _baseName(String path) {
  var cut = -1;
  for (final separator in const ['/', '\\']) {
    final at = path.lastIndexOf(separator);
    if (at > cut) cut = at;
  }
  return cut < 0 ? path : path.substring(cut + 1);
}

/// 去掉扩展名：只切「像扩展名」的尾巴。
///
/// 不这么判会把 `Anime 12.5`（无扩展名）当成「扩展名 .5」切掉，反而丢掉小数集。
String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return name;
  final ext = name.substring(dot + 1);
  if (!RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(ext)) return name;
  // 纯数字尾巴是小数点后的小数部分，不是扩展名
  if (RegExp(r'^\d+$').hasMatch(ext)) return name;
  return name.substring(0, dot);
}
