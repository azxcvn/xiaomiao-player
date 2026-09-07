/// Wyzie 字幕查询纯函数：把设置集合拼接成 `/search` 查询参数，
/// 以及客户端按语言过滤结果（Wyzie 接口常无视 language 参数返回全语言，
/// 需本地兜底过滤）。
library;

import 'package:moumou/models/wyzie_models.dart';

/// 来源参数：空集或含「all」→ `all`（不限来源），否则逗号拼接小写。
String wyzieSourceParam(Set<String> sources) {
  if (sources.isEmpty || sources.contains('all')) return 'all';
  return sources.map((s) => s.toLowerCase()).join(',');
}

/// 逗号拼接参数（language/format/encoding 共用）：空集或含「all」→ null
/// （省略该查询参数，由服务端默认），否则逗号拼接小写。
String? wyzieCommaParam(Set<String> values) {
  if (values.isEmpty || values.contains('all')) return null;
  return values.map((v) => v.toLowerCase()).join(',');
}

/// 把字幕的语言字段归一化为语言代码（接口可能下发代码或人类可读名）。
String wyzieLanguageCode(String raw) {
  final lower = raw.trim().toLowerCase();
  if (wyzieLanguages.containsKey(lower)) return lower;
  for (final e in wyzieLanguages.entries) {
    if (e.value.toLowerCase() == lower) return e.key;
  }
  return lower;
}

/// 按已选语言过滤结果；空集或含「all」不过滤（返回原列表）。
List<WyzieSubtitle> filterWyzieByLanguages(
  List<WyzieSubtitle> results,
  Set<String> languages,
) {
  if (languages.isEmpty || languages.contains('all')) return results;
  final allowed = languages.map((l) => l.toLowerCase()).toSet();
  return results
      .where((sub) => allowed.contains(wyzieLanguageCode(sub.language)))
      .toList();
}
