import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/video_info_service.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/utils/watch_state.dart';
import 'package:moumou/widgets/file_selection_ui.dart';

/// 视频卡片：缩略图 + 名称 + 字段（列表视图与目录详情页共用）。
///
/// 字段共 7 个（由 [fields] 控制显隐）：
/// - **时长**：缩略图右下角标签；**大小**：缩略图左下角标签——
///   两者自动避让缩略图底部进度条（有进度条时上移）；
/// - 其余字段（日期 / 分辨率 / 进度 / 帧率 / 字幕指示器）以标签行展示。
///
/// 进度字段自动计算观看百分比，并驱动卡片状态：
/// 未观看 / 观看中 / 已看完（达到「已观看」阈值，卡片置灰）。
class VideoCard extends StatefulWidget {
  final VideoFile video;
  final Set<VideoField> fields;
  final VoidCallback onTap;

  /// 点击最右侧「i」图标（打开媒体信息页）；null 时显示播放图标
  final VoidCallback? onInfoTap;

  /// 覆盖最右侧图标（优先于 onInfoTap 的「i」/播放图标）。
  /// 历史记录页用它放垃圾桶删除按钮；不传走原有语义。
  final Widget? trailing;

  /// 长按卡片（弹出文件管理菜单：复制/移动/重命名/删除/多选）；null 时无长按行为
  final VoidCallback? onLongPress;

  /// 是否处于多选态（左侧插入勾选圆点，点击语义由调用方改为「选中」）
  final bool selectionMode;

  /// 是否已被选中（仅多选态有意义）
  final bool selected;

  const VideoCard({
    super.key,
    required this.video,
    required this.fields,
    required this.onTap,
    this.onInfoTap,
    this.trailing,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  String? _thumbPath;
  VideoBasicMetadata? _meta;

  /// 是否需要加载基本元数据（帧率 / 字幕指示器字段启用时）
  bool get _needMeta =>
      widget.fields.contains(VideoField.frameRate) ||
      widget.fields.contains(VideoField.subtitle);

  @override
  void initState() {
    super.initState();
    _loadThumb();
    if (_needMeta) _loadMeta();
  }

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_needMeta && _meta == null) _loadMeta();
  }

  Future<void> _loadThumb() async {
    // 网络来源视频无本地缩略图，跳过 MediaMetadataRetriever（避免把远程
    // 相对路径当本地文件解析）。
    if (widget.video.source == VideoSource.network) return;
    final info = await VideoInfoService.get(widget.video.path);
    if (!mounted) return;
    setState(() {
      _thumbPath = info.thumbPath;
    });
  }

  Future<void> _loadMeta() async {
    // 网络来源视频无本地元数据，跳过（避免把远程相对路径当本地文件解析）。
    if (widget.video.source == VideoSource.network) return;
    final meta = await VideoInfoService.getBasicMetadata(widget.video.path);
    if (!mounted) return;
    setState(() => _meta = meta);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fields = widget.fields;
    // 同步读取最新进度（列表重建时自动刷新）
    final progress =
        PlaybackProgressService.instance.getProgress(widget.video.path);

    // ── 观看状态：未观看 / 观看中 / 已看完（看完置灰）────────
    final durationMs = widget.video.durationMs;
    final threshold = PlayerControlsSettings.instance.watchThreshold;
    final state = classifyWatchState(
      durationMs: durationMs,
      progress: progress,
      threshold: threshold,
    );
    final watched = state == WatchState.watched;
    final watching = state == WatchState.watching;
    final progressPercent = watchPercent(
      durationMs: durationMs,
      progress: progress,
    );

    // 缩略图标签：时长右下角、大小左下角（自动避让底部进度条）
    final sizeText =
        fields.contains(VideoField.size) ? formatFileSize(widget.video.size) : null;
    final durationText = fields.contains(VideoField.duration) && durationMs > 0
        ? formatDuration(durationMs)
        : null;
    // 底部是否有进度条：有则标签上移（进度条 3px + 间隙），无则贴底
    final hasProgressBar = progress != null && durationMs > 0;
    final labelBottom = hasProgressBar ? 8.0 : 6.0;

    // 其余字段标签（日期/分辨率/进度/帧率/字幕指示器）
    final tags = <Widget>[];
    if (fields.contains(VideoField.date)) {
      tags.add(_tag(
        scheme,
        Icons.calendar_today_outlined,
        formatDate(widget.video.dateModified),
      ));
    }
    if (fields.contains(VideoField.resolution) &&
        widget.video.width > 0 &&
        widget.video.height > 0) {
      tags.add(_tag(
        scheme,
        Icons.aspect_ratio,
        '${widget.video.width}x${widget.video.height}',
      ));
    }
    if (fields.contains(VideoField.progress)) {
      tags.add(_tag(
        scheme,
        watched
            ? Icons.check_circle
            : (watching
                ? Icons.play_circle_outline
                : Icons.radio_button_unchecked),
        watched
            ? '已看完'
            : (watching ? '$progressPercent%' : '未观看'),
        emphasize: watched,
      ));
    }
    if (fields.contains(VideoField.frameRate)) {
      final fps = _meta?.frameRate ?? 0;
      if (fps > 0) {
        tags.add(_tag(
          scheme,
          Icons.speed,
          '${fps.toStringAsFixed(fps % 1 == 0 ? 0 : 2)} fps',
        ));
      }
    }
    if (fields.contains(VideoField.subtitle)) {
      final meta = _meta;
      final hasSub = meta?.hasEmbeddedSubtitles ?? false;
      final codec = meta?.subtitleCodec ?? '';
      final text = meta == null
          ? '字幕检测中…'
          : hasSub
              ? (codec.isEmpty ? '含字幕' : '字幕 · $codec')
              : '无字幕';
      tags.add(_tag(
        scheme,
        meta == null
            ? Icons.hourglass_top
            : (hasSub
                ? Icons.subtitles_outlined
                : Icons.subtitles_off_outlined),
        text,
      ));
    }

    // 看完置灰：卡片底色换灰 + 名称变灰
    final cardColor = watched
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLow;
    final nameColor = watched ? scheme.onSurfaceVariant : null;

    return Card(
      elevation: 0,
      // 选中态优先于「已看完置灰」：置灰说的是「看过了」，选中说的是
      // 「现在要操作它」，后者是当下的意图，必须一眼看得见
      color: widget.selected ? selectedCardColor(scheme) : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selectedCardSide(scheme, widget.selected),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.selectionMode) SelectionMark(selected: widget.selected),
              // 缩略图（叠加字段标签 + 进度条）
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumbPath != null
                          ? Image.file(File(_thumbPath!), fit: BoxFit.cover)
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.movie_outlined,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                      // 底部进度条（最底层，标签在其上方避让）
                      if (hasProgressBar)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildProgressBar(scheme, progress),
                        ),
                      // 大小：左下角
                      if (sizeText != null && sizeText.isNotEmpty)
                        Positioned(
                          left: 4,
                          bottom: labelBottom,
                          child: _thumbLabel(sizeText),
                        ),
                      // 时长：右下角
                      if (durationText != null)
                        Positioned(
                          right: 4,
                          bottom: labelBottom,
                          child: _thumbLabel(durationText),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: nameColor,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 12, runSpacing: 4, children: tags),
                    ],
                  ],
                ),
              ),
              // 最右侧：trailing 覆盖（如历史页垃圾桶）> 媒体信息「i」> 播放图标
              if (widget.trailing != null)
                widget.trailing!
              else if (widget.onInfoTap != null)
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  tooltip: '媒体信息',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onInfoTap,
                )
              else
                Icon(Icons.play_circle_outline, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(ColorScheme scheme, Duration progress) {
    final ratio = (progress.inMilliseconds / widget.video.durationMs).clamp(
      0.0,
      1.0,
    );
    return Container(
      height: 3,
      color: Colors.black.withValues(alpha: 0.4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio,
          child: Container(color: scheme.primary),
        ),
      ),
    );
  }

  Widget _thumbLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _tag(
    ColorScheme scheme,
    IconData icon,
    String text, {
    bool emphasize = false,
  }) {
    final color = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
