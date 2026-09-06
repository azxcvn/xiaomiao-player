/// 播放历史条目模型（纯数据）：记录最近播放过的视频，供「最近播放」
/// 直启与「我的 → 播放 → 历史记录」界面展示。
///
/// 只记录**可重放**的来源（本地文件真实路径 / 打开链接的在线 URL）；
/// 网络存储（loopback 代理 URL 退出即失效）与哔哩哔哩在线播放
/// （需登录态重新解析 playurl）不写入历史。
class PlaybackHistoryEntry {
  /// 播放地址：本地绝对路径或在线 URL（作为唯一键去重）
  final String path;

  /// 展示标题（本地=文件名，在线=从 URL 提取）
  final String title;

  /// 是否为在线链接播放（本地文件为 false）
  final bool isUrl;

  /// 最后一次开始播放的时间戳（毫秒）
  final int playedAtMs;

  /// 媒体时长（毫秒，未知为 0；退出播放时回填，供历史列表显示时长/进度条）
  final int durationMs;

  const PlaybackHistoryEntry({
    required this.path,
    required this.title,
    required this.isUrl,
    required this.playedAtMs,
    this.durationMs = 0,
  });

  PlaybackHistoryEntry copyWith({
    String? path,
    String? title,
    bool? isUrl,
    int? playedAtMs,
    int? durationMs,
  }) =>
      PlaybackHistoryEntry(
        path: path ?? this.path,
        title: title ?? this.title,
        isUrl: isUrl ?? this.isUrl,
        playedAtMs: playedAtMs ?? this.playedAtMs,
        durationMs: durationMs ?? this.durationMs,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'isUrl': isUrl,
        'playedAtMs': playedAtMs,
        'durationMs': durationMs,
      };

  /// 防御性解码：字段缺失/类型异常返回 null（损坏条目直接丢弃）
  static PlaybackHistoryEntry? fromJson(dynamic json) {
    if (json is! Map) return null;
    final path = json['path'];
    final title = json['title'];
    final playedAt = json['playedAtMs'];
    if (path is! String || path.isEmpty || title is! String) return null;
    final duration = json['durationMs'];
    return PlaybackHistoryEntry(
      path: path,
      title: title,
      isUrl: json['isUrl'] is bool ? json['isUrl'] as bool : false,
      playedAtMs: playedAt is num ? playedAt.toInt() : 0,
      durationMs: duration is num ? duration.toInt() : 0,
    );
  }
}
