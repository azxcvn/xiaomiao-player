/// 在线字幕的**通用条目模型**：与具体来源（Wyzie / 自定义地址）无关。
///
/// 下载页只依赖本模型，Wyzie 结果经 [SubtitleEntry.fromWyzie] 转换一次，
/// 自定义源直接产出本模型——避免把自定义源硬塞进 Wyzie 的十几字段模型里。
library;

import 'package:moumou/models/wyzie_models.dart';

class SubtitleEntry {
  /// 字幕直链（http/https）
  final String url;

  /// 展示名（也是落盘文件名的基底）：文件名 / 发布名 / 标题，可为空
  final String name;

  /// 语言（人类可读名或语言代码，可为空）
  final String language;

  /// 格式（`srt` / `ass` / `ssa` / `vtt` … 小写无点，可为空）
  final String format;

  /// 来源展示名（Wyzie 的 source；自定义源固定「自定义」）
  final String source;

  /// 是否与服务端下发的文件指纹（CID）匹配（只有来源给了才为 true）
  final bool hashMatch;

  const SubtitleEntry({
    required this.url,
    this.name = '',
    this.language = '',
    this.format = '',
    this.source = '',
    this.hashMatch = false,
  });

  /// 展示名 / 语言展示名的**占位兜底**在 UI 层：
  /// `label_maps.subtitleEntryDisplayName` / `subtitleEntryDisplayLanguage`。

  /// Wyzie 条目 → 通用条目（落盘名基底沿用 fileName → release → media）
  static SubtitleEntry fromWyzie(WyzieSubtitle s) => SubtitleEntry(
        url: s.url,
        name: s.fileName.isNotEmpty
            ? s.fileName
            : (s.release.isNotEmpty ? s.release : s.media),
        language: s.display.isNotEmpty ? s.display : s.language,
        format: s.format,
        source: s.source,
        hashMatch: s.hashMatch,
      );
}
