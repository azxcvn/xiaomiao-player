/// 自定义字幕源的**地址模板展开**与**响应解析**（纯函数，可单测）。
///
/// 自定义源完全由用户填一个地址：仓库里不内置任何第三方域名/密钥。
/// 因此响应结构只能「自动嗅探」常见形状，嗅不出来就明确报错，
/// **不猜、不把解析失败当成「没有字幕」**（那会让用户以为源里没资源）。
///
/// 嗅探规则（按顺序）：
/// - 列表：顶层数组；或对象的 `data` / `subtitles` / `subs` / `results` /
///   `list` / `items` 字段（`data` 里再套一层同样这几个键也认）；
/// - 名称：`name` / `title` / `filename` / `file_name` / `label` / `display`；
/// - 地址：`url` / `link` / `download_url` / `downloadUrl` / `src` / `file`；
/// - 语言：`language` / `lang` / `languages` / `langs`（字符串或字符串数组）；
/// - 格式：`ext` / `format` / `extension` / `type`，缺失时从地址后缀推断。
///
/// 单条缺地址（或不是 http/https）一律丢弃——没有地址就没法下载。
library;

import 'dart:convert';

import 'package:moumou/models/subtitle_entry.dart';
import 'package:moumou/utils/error_codes.dart';

/// 自定义源响应解析失败（与 [FormatException] 区分开，便于页面提示）
class CustomSubtitleParseException implements Exception {
  /// 错误码
  final CustomSubtitleParseErrorCode code;

  const CustomSubtitleParseException(this.code);

  @override
  String toString() => 'CustomSubtitleParseException(${code.name})';
}

/// 展开地址模板：模板里的 `{name}` 会替换成 URL 编码后的关键词；
/// 模板没写占位符时，把关键词直接拼到末尾（适配 `...?name=` 这类地址）。
String expandSubtitleUrlTemplate(String template, String query) {
  final t = template.trim();
  if (t.isEmpty) return '';
  final encoded = Uri.encodeQueryComponent(query.trim());
  if (t.contains('{name}')) return t.replaceAll('{name}', encoded);
  return '$t$encoded';
}

/// 地址模板是否可用（非空即可；是否含 `{name}` 由 [expandSubtitleUrlTemplate] 兼容）
bool isUsableSubtitleUrlTemplate(String template) => template.trim().isNotEmpty;

const List<String> _listKeys = ['data', 'subtitles', 'subs', 'results', 'list', 'items'];
const List<String> _nameKeys = ['name', 'title', 'filename', 'file_name', 'label', 'display'];
const List<String> _urlKeys = ['url', 'link', 'download_url', 'downloadUrl', 'src', 'file'];
const List<String> _langKeys = ['language', 'lang', 'languages', 'langs'];
const List<String> _formatKeys = ['ext', 'format', 'extension', 'type'];

/// 已知字幕格式（用于把 `.SRT` 这类写法归一；不在表里且地址后缀也不认识时兜底 `txt`）
///
/// 表里都是「单独一个文件就能当字幕加载」的格式（`smi`/`sami` 是 SAMI，
/// mpv 也能读；实测自定义源确实会回 `.smi`，早先没收录时会落成 `.txt`）。
const Set<String> kCustomSubtitleFormats = {
  'srt', 'ass', 'ssa', 'sub', 'vtt', 'smi', 'sami', 'sbv', 'ttml', 'dfxp',
  'lrc', 'sup', 'txt',
};

/// 解析自定义源响应体 → 通用字幕条目列表（自动嗅探；见文件头注释）。
///
/// [sourceLabel] 为结果条目里显示的来源标识：默认 `custom`（ASCII 稳定值），
/// 界面文案由 UI 侧映射（见 `label_maps.subtitleEntrySourceLabel`）。
List<SubtitleEntry> parseCustomSubtitleResponse(
  String body, {
  String sourceLabel = 'custom',
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw const CustomSubtitleParseException(
      CustomSubtitleParseErrorCode.notJson,
    );
  }
  final list = _findList(decoded);
  if (list == null) {
    throw const CustomSubtitleParseException(
      CustomSubtitleParseErrorCode.noList,
    );
  }
  final out = <SubtitleEntry>[];
  final seen = <String>{};
  for (final item in list) {
    if (item is! Map) continue;
    final entry = _entryFromMap(item.cast<String, dynamic>(), sourceLabel);
    if (entry == null) continue;
    if (seen.add(entry.url)) out.add(entry);
  }
  return out;
}

/// 在响应里找字幕列表（顶层数组 / 常见键 / `data` 里再套一层）
List<Object?>? _findList(Object? decoded) {
  if (decoded is List) return decoded;
  if (decoded is! Map) return null;
  for (final key in _listKeys) {
    final value = decoded[key];
    if (value is List) return value;
    if (value is Map) {
      for (final nested in _listKeys) {
        final inner = value[nested];
        if (inner is List) return inner;
      }
    }
  }
  return null;
}

SubtitleEntry? _entryFromMap(Map<String, dynamic> map, String sourceLabel) {
  final url = _firstString(map, _urlKeys);
  // 没有可下载的直链 → 丢弃（不猜、不拼相对地址）
  if (url == null || !(url.startsWith('http://') || url.startsWith('https://'))) {
    return null;
  }
  return SubtitleEntry(
    url: url,
    name: _firstString(map, _nameKeys) ?? '',
    language: _languageOf(map),
    format: _normalizeFormat(_firstString(map, _formatKeys), url),
    source: sourceLabel,
    hashMatch: map['isHashMatch'] == true || map['hashMatch'] == true,
  );
}

/// 取第一个非空字符串字段
String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// 语言：字符串直用；数组/多值拼接展示
String _languageOf(Map<String, dynamic> map) {
  for (final key in _langKeys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      final parts = <String>[];
      for (final e in value) {
        if (e is String && e.trim().isNotEmpty) parts.add(e.trim());
      }
      if (parts.isNotEmpty) return parts.join('、');
    }
  }
  return '';
}

/// 格式归一：去点小写；不认识时从地址后缀推断，再兜底 `txt`
String _normalizeFormat(String? raw, String url) {
  final direct = _clean(raw);
  if (direct != null) return direct;
  final fromUrl = _clean(_extensionOf(url));
  return fromUrl ?? 'txt';
}

String? _clean(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');
  if (v.isEmpty) return null;
  return kCustomSubtitleFormats.contains(v) ? v : null;
}

/// 取 URL 路径部分的扩展名（去掉查询串）
String? _extensionOf(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return null;
  return path.substring(dot + 1);
}
