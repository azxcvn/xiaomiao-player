import 'package:flutter/material.dart';
import 'package:moumou/services/fast_thumbnails.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/widgets/raw_thumb_image.dart';

/// 进度条拖动时的缩略图预览气泡（对齐 kt 项目 `SeekbarThumbnailPreview`）：
/// 16:9 预览图（宽 160）+ 上方章节名胶囊（有章节时）+ 下方时间胶囊，
/// 水平位置跟随拖动比例。
///
/// 帧数据来自 [DeviceServices.getVideoFrameAt]（FFmpeg 快速引擎 RGBA 直通 +
/// 分桶内存缓存），[RawThumbImage] 直接渲染像素。[visible] 控制淡入淡出。
class PlayerThumbnailPreview extends StatelessWidget {
  /// 预览帧（null 时显示加载占位）
  final FastThumbFrame? frame;

  /// 预览时间点
  final Duration time;

  /// 拖动进度比例 0 – 1
  final double fraction;

  /// 是否显示（拖动中显示，松手淡出）
  final bool visible;

  /// 拖动位置所属的章节名（null / 空白 = 不显示章节胶囊）。
  /// 由页面用 `ChapterTracker.chapterTitleAt(拖动位置)` 提供——注意不能按
  /// 当前播放位置取，拖动时播放位置还停在原处。
  final String? chapterTitle;

  const PlayerThumbnailPreview({
    super.key,
    required this.frame,
    required this.time,
    required this.fraction,
    required this.visible,
    this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const previewWidth = 160.0;
            final left = (constraints.maxWidth - previewWidth)
                .clamp(0.0, double.infinity) *
                fraction.clamp(0.0, 1.0);
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: left),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 章节名胶囊（在预览图上方，对齐 mpvRx：章节在上、时间在下）
                    if (chapterTitle != null &&
                        chapterTitle!.trim().isNotEmpty) ...[
                      _ThumbPill(
                        text: chapterTitle!.trim(),
                        maxWidth: previewWidth,
                        monospaceTime: false,
                      ),
                      const SizedBox(height: 5),
                    ],
                    // 16:9 预览图
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: previewWidth,
                        height: previewWidth * 9 / 16,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          color: Colors.black.withValues(alpha: 0.72),
                        ),
                        child: frame != null
                            ? RawThumbImage(frame: frame!, fit: BoxFit.cover)
                            : const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    // 时间胶囊
                    const SizedBox(height: 5),
                    _ThumbPill(
                      text: formatDuration(time.inMilliseconds),
                      maxWidth: previewWidth,
                      monospaceTime: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 气泡里的胶囊（章节名 / 时间共用同一外观）。
///
/// [maxWidth] 与预览图同宽；章节名过长时单行省略（不换行、不撑宽气泡）。
/// [monospaceTime] 只用于时间胶囊的字重（视觉上与章节名区分）。
class _ThumbPill extends StatelessWidget {
  const _ThumbPill({
    required this.text,
    required this.maxWidth,
    required this.monospaceTime,
  });

  final String text;
  final double maxWidth;
  final bool monospaceTime;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
