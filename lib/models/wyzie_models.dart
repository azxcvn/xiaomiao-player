/// Wyzie 字幕 API 数据模型与常量表（字幕条目 / 来源 / 密钥信息 / TMDB 匹配）。
///
/// 纯数据模型（无逻辑、无依赖），`fromJson` 仅做字段映射与容错
/// （缺失/类型不符的字段回退默认值，`url` 缺失视为无效条目返回 null，
/// 由调用方跳过）。语言/格式/编码/来源常量表供设置页展示与查询拼接共用，
/// 对齐 mpvRx `WyzieSearchRepository.kt` 的 `WyzieLanguages/WyzieFormats/
/// WyzieEncodings/WyzieSources`。
library;

/// 单条字幕（`/search` 返回的列表项）。
class WyzieSubtitle {
  final String id;
  final String url;
  final String flagUrl;
  final String format;
  final String encoding;
  final String display;
  final String language;
  final String media;
  final bool hearingImpaired;
  final String source;
  final String release;
  final List<String> releases;
  final String origin;
  final String fileName;
  final String matchedRelease;
  final String matchedFilter;
  final int downloadCount;
  final bool hashMatch;
  final bool ai;

  const WyzieSubtitle({
    this.id = '',
    required this.url,
    this.flagUrl = '',
    this.format = '',
    this.encoding = '',
    this.display = '',
    this.language = '',
    this.media = '',
    this.hearingImpaired = false,
    this.source = '',
    this.release = '',
    this.releases = const [],
    this.origin = '',
    this.fileName = '',
    this.matchedRelease = '',
    this.matchedFilter = '',
    this.downloadCount = 0,
    this.hashMatch = false,
    this.ai = false,
  });

  /// 展示名：优先文件名，其次发布名 / 媒体标题，兜底占位。
  String get displayName {
    if (fileName.isNotEmpty) return fileName;
    if (release.isNotEmpty) return release;
    if (media.isNotEmpty) return media;
    return '未知字幕';
  }

  /// 语言展示名：优先 API 下发的人类可读名，其次语言代码。
  String get displayLanguage => display.isNotEmpty
      ? display
      : (language.isNotEmpty ? language : '未知语言');

  static WyzieSubtitle? fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    final releases = <String>[];
    final rawReleases = json['releases'];
    if (rawReleases is List) {
      for (final r in rawReleases) {
        if (r is String) releases.add(r);
      }
    }
    return WyzieSubtitle(
      id: _asString(json['id']),
      url: url,
      flagUrl: _asString(json['flagUrl']),
      format: _asString(json['format']),
      encoding: _asString(json['encoding']),
      display: _asString(json['display']),
      language: _asString(json['language']),
      media: _asString(json['media']),
      hearingImpaired: json['isHearingImpaired'] == true,
      source: _asString(json['source']),
      release: _asString(json['release']),
      releases: releases,
      origin: _asString(json['origin']),
      fileName: _asString(json['fileName']),
      matchedRelease: _asString(json['matchedRelease']),
      matchedFilter: _asString(json['matchedFilter']),
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      hashMatch: json['isHashMatch'] == true,
      ai: json['ai'] == true,
    );
  }
}

/// `/sources` 返回的分层来源条目（key/名称/免费或付费 tier/标签/是否可用）。
class WyzieSourceItem {
  final String key;
  final String name;
  final String tier;
  final List<String> tags;
  final bool available;

  const WyzieSourceItem({
    required this.key,
    required this.name,
    this.tier = '',
    this.tags = const [],
    this.available = true,
  });

  bool get isFree => tier.toLowerCase() == 'free';

  static WyzieSourceItem? fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (key is! String || key.isEmpty) return null;
    final tags = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is String) tags.add(t);
      }
    }
    return WyzieSourceItem(
      key: key,
      name: _asString(json['name']).isNotEmpty ? _asString(json['name']) : key,
      tier: _asString(json['tier']),
      tags: tags,
      available: json['available'] != false,
    );
  }
}

/// `/sources` 返回的密钥信息（是否有效 + 密钥类型 free/pro）。
class WyzieKeyInfo {
  final bool valid;
  final String type;

  const WyzieKeyInfo({this.valid = false, this.type = ''});

  static WyzieKeyInfo fromJson(Map<String, dynamic> json) => WyzieKeyInfo(
        valid: json['valid'] == true,
        type: _asString(json['type']),
      );
}

/// `/sources` 响应（可用来源 + 免费/付费分组 + 分层条目 + 密钥信息）。
class WyzieSourcesResponse {
  final List<String> sources;
  final List<String> free;
  final List<String> paid;
  final List<WyzieSourceItem> tiered;
  final bool allFree;
  final WyzieKeyInfo? key;
  final List<String> available;
  final List<String> restricted;

  const WyzieSourcesResponse({
    this.sources = const [],
    this.free = const [],
    this.paid = const [],
    this.tiered = const [],
    this.allFree = false,
    this.key,
    this.available = const [],
    this.restricted = const [],
  });

  static WyzieSourcesResponse fromJson(Map<String, dynamic> json) {
    final rawKey = json['key'];
    return WyzieSourcesResponse(
      sources: _stringList(json['sources']),
      free: _stringList(json['free']),
      paid: _stringList(json['paid']),
      tiered: _sourceItems(json['tiered']),
      allFree: json['allFree'] == true,
      key: rawKey is Map ? WyzieKeyInfo.fromJson(rawKey.cast<String, dynamic>()) : null,
      available: _stringList(json['available']),
      restricted: _stringList(json['restricted']),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  static List<WyzieSourceItem> _sourceItems(Object? raw) {
    if (raw is! List) return const [];
    final result = <WyzieSourceItem>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = WyzieSourceItem.fromJson(item.cast<String, dynamic>());
        if (parsed != null) result.add(parsed);
      }
    }
    return result;
  }
}

/// TMDB 媒体搜索命中（`/api/tmdb/search` 返回的单条结果）。
class WyzieTmdbResult {
  final int id;
  final String mediaType;
  final String title;
  final String releaseYear;
  final String poster;
  final String backdrop;
  final String overview;

  const WyzieTmdbResult({
    required this.id,
    this.mediaType = '',
    this.title = '',
    this.releaseYear = '',
    this.poster = '',
    this.backdrop = '',
    this.overview = '',
  });

  static WyzieTmdbResult? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! num) return null;
    return WyzieTmdbResult(
      id: id.toInt(),
      mediaType: _asString(json['mediaType']),
      title: _asString(json['title']),
      releaseYear: _asString(json['releaseYear']),
      poster: _asString(json['poster']),
      backdrop: _asString(json['backdrop']),
      overview: _asString(json['overview']),
    );
  }
}

/// TMDB 媒体搜索响应。
class WyzieTmdbResponse {
  final List<WyzieTmdbResult> results;

  const WyzieTmdbResponse({this.results = const []});

  static WyzieTmdbResponse fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    if (raw is! List) return const WyzieTmdbResponse();
    final results = <WyzieTmdbResult>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = WyzieTmdbResult.fromJson(item.cast<String, dynamic>());
        if (parsed != null) results.add(parsed);
      }
    }
    return WyzieTmdbResponse(results: results);
  }
}

String _asString(Object? v) => v is String ? v : (v == null ? '' : '$v');

/// 语言代码 → 人类可读名（对齐 mpvRx `WyzieLanguages.ALL`）。
const Map<String, String> wyzieLanguages = {
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'pa': 'Punjabi',
  'jv': 'Javanese',
  'vi': 'Vietnamese',
  'te': 'Telugu',
  'mr': 'Marathi',
  'ta': 'Tamil',
  'ur': 'Urdu',
  'tr': 'Turkish',
  'pl': 'Polish',
  'uk': 'Ukrainian',
  'nl': 'Dutch',
  'el': 'Greek',
  'hu': 'Hungarian',
  'sv': 'Swedish',
  'cs': 'Czech',
  'ro': 'Romanian',
  'da': 'Danish',
  'fi': 'Finnish',
  'no': 'Norwegian',
  'he': 'Hebrew',
  'id': 'Indonesian',
  'ms': 'Malay',
  'th': 'Thai',
  'fa': 'Persian',
  'sk': 'Slovak',
  'bg': 'Bulgarian',
  'hr': 'Croatian',
  'sr': 'Serbian',
  'sl': 'Slovenian',
  'et': 'Estonian',
  'lv': 'Latvian',
  'lt': 'Lithuanian',
  'af': 'Afrikaans',
  'sq': 'Albanian',
  'am': 'Amharic',
  'hy': 'Armenian',
  'az': 'Azerbaijani',
  'eu': 'Basque',
  'be': 'Belarusian',
  'bs': 'Bosnian',
  'ca': 'Catalan',
  'cy': 'Welsh',
  'eo': 'Esperanto',
  'ga': 'Irish',
  'gl': 'Galician',
  'ka': 'Georgian',
  'gu': 'Gujarati',
  'ht': 'Haitian Creole',
  'is': 'Icelandic',
  'kn': 'Kannada',
  'kk': 'Kazakh',
  'km': 'Khmer',
  'ky': 'Kyrgyz',
  'lo': 'Lao',
  'mk': 'Macedonian',
  'mg': 'Malagasy',
  'mt': 'Maltese',
  'mi': 'Maori',
  'mn': 'Mongolian',
  'ne': 'Nepali',
  'ps': 'Pashto',
  'si': 'Sinhala',
  'sw': 'Swahili',
  'tg': 'Tajik',
  'tt': 'Tatar',
  'uz': 'Uzbek',
  'yi': 'Yiddish',
  'yo': 'Yoruba',
  'zu': 'Zulu',
};

/// 语言代码按名称排序后的表（设置页多选展示用）。
final Map<String, String> wyzieLanguagesSorted =
    Map.fromEntries(wyzieLanguages.entries.toList()..sort((a, b) => a.value.compareTo(b.value)));

/// 格式代码 → 展示名（对齐 mpvRx `WyzieFormats.ALL`）。
const Map<String, String> wyzieFormats = {
  'srt': 'SRT',
  'ass': 'ASS',
  'ssa': 'SSA',
  'vtt': 'VTT',
  'sub': 'SUB',
};

/// 编码代码 → 展示名（对齐 mpvRx `WyzieEncodings.ALL`）。
const Map<String, String> wyzieEncodings = {
  'iso-8859-6': 'Arabic (ISO-8859-6)',
  'cp1256': 'Arabic (Cp1256)',
  'cp1257': 'Baltic (Cp1257)',
  'iso-8859-13': 'Baltic (ISO-8859-13)',
  'iso-8859-4': 'Baltic, Scandinavia (ISO-8859-4)',
  'iso-8859-14': 'Celtic (ISO-8859-14)',
  'iso-8859-2': 'Central European, Slavic (ISO-8859-2)',
  'ms936': 'Chinese, Simplified (MS936)',
  'gb18030': 'Chinese, Simplified (GB18030)',
  'euc_cn': 'Chinese, Simplified (EUC_CN)',
  'gbk': 'Chinese, Simplified (GBK)',
  'iso-2022-cn': 'Chinese, Simplified (ISO-2022-CN)',
  'ms950': 'Chinese, Traditional (MS950)',
  'ms950_hkscs': 'Chinese, Traditional (Hong Kong) (MS950_HKSCS)',
  'big5': 'Chinese, Traditional (Big5)',
  'big5-hkscs': 'Chinese, Traditional (Hong Kong) (Big5-HKSCS)',
  'cp1251': 'Cyrillic (Cp1251)',
  'iso-8859-5': 'Cyrillic (ISO-8859-5)',
  'cp1250': 'Eastern European (Cp1250)',
  'cp1253': 'Greek (Cp1253)',
  'iso-8859-7': 'Greek (ISO-8859-7)',
  'iso-8859-8': 'Hebrew (ISO-8859-8)',
  'cp1255': 'Hebrew (Cp1255)',
  'iscii91': 'Indic scripts (ISCII91)',
  'ms932': 'Japanese (MS932)',
  'euc_jp': 'Japanese (EUC_JP)',
  'shift_jis': 'Japanese (Shift_JIS)',
  'iso-2022-jp': 'Japanese (ISO-2022-JP)',
  'ms949': 'Korean (MS949)',
  'euc_kr': 'Korean (EUC_KR)',
  'iso-2022-kr': 'Korean (ISO-2022-KR)',
  'iso-8859-10': 'Nordic (ISO-8859-10)',
  'iso-8859-16': 'Romanian (ISO-8859-16)',
  'koi8_r': 'Russian (KOI8_R)',
  'iso-8859-3': 'South European (ISO-8859-3)',
  'tis-620': 'Thai (TIS-620)',
  'iso-8859-11': 'Thai (ISO-8859-11)',
  'cp1254': 'Turkish (Cp1254)',
  'iso-8859-9': 'Turkish (ISO-8859-9)',
  'utf-8': 'Unicode (UTF-8)',
  'utf-16': 'Unicode (UTF-16)',
  'utf-16be': 'Unicode (UTF-16BE)',
  'utf-16le': 'Unicode (UTF-16LE)',
  'utf-32': 'Unicode (UTF-32)',
  'utf-32be': 'Unicode (UTF-32BE)',
  'utf-32le': 'Unicode (UTF-32LE)',
  'us-ascii': '(US-ASCII)',
  'cp1258': 'Vietnamese (Cp1258)',
  'iso-8859-1': 'Western European (ISO-8859-1)',
  'iso-8859-15': 'Western European (ISO-8859-15)',
  'cp1252': 'Western European (ANSI) (Cp1252)',
};

/// 来源 key → 兜底展示名（`/sources` 拉取失败时用，对齐 mpvRx `WyzieSources.ALL`）。
const Map<String, String> wyzieFallbackSources = {
  'all': '全部',
  'bravo': 'Bravo',
  'charlie': 'Charlie',
  'foxtrot': 'Foxtrot',
  'india': 'India',
  'juliet': 'Juliet',
  'lima': 'Lima',
  'mike': 'Mike',
  'november': 'November',
};

/// 兜底 tier 判定（`/sources` 不可用时用，对齐 mpvRx 的静态 fallback）。
bool wyzieFallbackIsFree(String key) => key == 'charlie' || key == 'lima';
