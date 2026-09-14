/// 哔哩哔哩番剧链接解析纯函数：从用户粘贴的 URL/文本中提取 season_id / ep_id /
/// BV 号 / av 号四种令牌，供「输入链接解析 → 详情页」入口使用。
///
/// 覆盖 `bangumi/play/ss12345`、`bangumi/play/ep123456`、`video/BVxxxx`、
/// `video/av12345` 四类；UGC（BV/av）播放属阶段三，这里只负责识别出类型，
/// 由调用方决定提示。
///
/// **边界纪律（踩过）**：ss/ep/av 令牌只承认两种出现形态——
/// ①**URL 路径里**（`/ep123`，数字 1~9 位）；②**整串就是令牌**（`ep123456`，
/// 数字 ≥3 位）。旧实现是裸 `ep(\d+)`，于是 `step2`（教程）、`SS2 第二季`、
/// `AV1 编码`、`第12集 ep12 更新` 这类**普通文本**全被当成链接（§4.14/§7）。
/// 位数上限顺带保证 `int.parse` 不会因超长数字串抛 `FormatException`
/// （超长必然不是真的 id）。
library;

// ── ss（季）──────────────────────────────────────────────────────
final RegExp _reSsPath = RegExp(r'/ss(\d{1,9})(?![0-9A-Za-z])', caseSensitive: false);
final RegExp _reSsBare = RegExp(r'^ss(\d{3,9})(?![0-9A-Za-z])', caseSensitive: false);

// ── ep（集）──────────────────────────────────────────────────────
final RegExp _reEpPath = RegExp(r'/ep(\d{1,9})(?![0-9A-Za-z])', caseSensitive: false);
final RegExp _reEpBare = RegExp(r'^ep(\d{3,9})(?![0-9A-Za-z])', caseSensitive: false);

// ── av（老 UGC 号）───────────────────────────────────────────────
final RegExp _reAvPath = RegExp(r'/av(\d{1,9})(?![0-9A-Za-z])', caseSensitive: false);
final RegExp _reAvBare = RegExp(r'^av(\d{3,9})(?![0-9A-Za-z])', caseSensitive: false);

/// BV 号：`BV` + 恰好 10 位 base62，两侧不得再粘字母数字
/// （否则 `xxBV1xx411c7mDyy` 之类的串里会被截出一段假的 BV）。
final RegExp _reBv = RegExp(r'(?<![0-9A-Za-z])[bB][vV][0-9A-Za-z]{10}(?![0-9A-Za-z])');

/// UP 主合集列表链接：`space.bilibili.com/{mid}/lists/{season_id}?type=season`。
final RegExp _reSeasonList = RegExp(
  r'space\.bilibili\.com/(\d{1,12})/lists/(\d{1,12})',
  caseSensitive: false,
);

/// 按「路径形态 → 整串形态」顺序取第一个令牌的数字值；都没有返回 null。
int? _tokenValue(String text, RegExp pathForm, RegExp bareForm) {
  final m = pathForm.firstMatch(text) ?? bareForm.firstMatch(text);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// 解析出的番剧引用（season / episode / UGC 三选一，其余为 0/空）。
///
/// UGC 支持 BV 号与 av 号两种形式（老链接、分享短链里 av 号仍常见，工作.md 第 8 点）。
class BiliBangumiRef {
  final int seasonId;
  final int epId;
  final String bvid;
  final int aid;

  const BiliBangumiRef({
    this.seasonId = 0,
    this.epId = 0,
    this.bvid = '',
    this.aid = 0,
  });

  bool get hasSeason => seasonId > 0;
  bool get hasEpisode => epId > 0;
  bool get hasAid => aid > 0;
  bool get isUgc => bvid.isNotEmpty || aid > 0;

  /// 是否识别出任何可解析的令牌。
  bool get isValid => hasSeason || hasEpisode || isUgc;
}

/// 解析链接文本；未识别到任何令牌返回 null。
BiliBangumiRef? parseBiliBangumiUrl(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  // 优先 season_id（番剧季详情是阶段二入口页）
  final ss = _tokenValue(text, _reSsPath, _reSsBare);
  if (ss != null) return BiliBangumiRef(seasonId: ss);

  final ep = _tokenValue(text, _reEpPath, _reEpBare);
  if (ep != null) return BiliBangumiRef(epId: ep);

  final bv = _reBv.firstMatch(text);
  if (bv != null) return BiliBangumiRef(bvid: bv.group(0)!);

  final av = _tokenValue(text, _reAvPath, _reAvBare);
  if (av != null) return BiliBangumiRef(aid: av);

  return null;
}

/// UP 主合集列表引用（`space.bilibili.com/{mid}/lists/{season_id}`）。
class BiliSeasonListRef {
  final int mid;
  final int seasonId;

  const BiliSeasonListRef({required this.mid, required this.seasonId});
}

/// 解析 UP 主合集列表链接；未识别到返回 null。
BiliSeasonListRef? parseBiliSeasonListUrl(String input) {
  final m = _reSeasonList.firstMatch(input);
  if (m == null) return null;
  final mid = int.tryParse(m.group(1)!);
  final seasonId = int.tryParse(m.group(2)!);
  if (mid == null || seasonId == null) return null;
  return BiliSeasonListRef(mid: mid, seasonId: seasonId);
}
