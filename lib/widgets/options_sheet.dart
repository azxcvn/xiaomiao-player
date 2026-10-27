import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/app_dialog.dart';

/// 统一的「排序与字段」弹窗（首页 / 目录页 / 详情页共用）。
///
/// - [hasFolders]：是否显示文件夹排序/字段（上半区）
/// - [hasVideos]：是否显示视频排序/字段（下半区）
/// - [showViewMode]：是否显示「显示模式」（仅首页）
///
/// 上半区为文件夹相关（排序方式 → 方向 → 字段），下半区为视频相关，
/// 中间用一条分割线划分；纯文件夹/纯视频时只显示对应半区。
void showSortOptionsSheet(
  BuildContext context,
  ViewSettings viewSettings, {
  required bool hasFolders,
  required bool hasVideos,
  bool showViewMode = false,
}) {
  showAppDialog(
    context: context,
    builder: (context) => _SortOptionsSheet(
      viewSettings: viewSettings,
      hasFolders: hasFolders,
      hasVideos: hasVideos,
      showViewMode: showViewMode,
    ),
  );
}

class _SortOptionsSheet extends StatelessWidget {
  final ViewSettings viewSettings;
  final bool hasFolders;
  final bool hasVideos;
  final bool showViewMode;

  const _SortOptionsSheet({
    required this.viewSettings,
    required this.hasFolders,
    required this.hasVideos,
    required this.showViewMode,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: viewSettings,
          builder: (context, _) {
            final l10n = AppLocalizations.of(context);
            final sections = <Widget>[];
            if (hasFolders) {
              // 上半区：文件夹相关
              sections.addAll([
                _sectionTitle(context, l10n.optionsSheetFolderSort),
                SegmentedButton<SortField>(
                  showSelectedIcon: false,
                  segments: SortField.values
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(sortFieldLabel(l10n, e)),
                        ),
                      )
                      .toList(),
                  selected: {viewSettings.sortField},
                  onSelectionChanged: (s) =>
                      viewSettings.setSortField(s.first),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, l10n.optionsSheetFolderSortDir),
                SegmentedButton<SortOrder>(
                  showSelectedIcon: false,
                  segments: SortOrder.values
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(sortOrderLabel(l10n, e)),
                        ),
                      )
                      .toList(),
                  selected: {viewSettings.sortOrder},
                  onSelectionChanged: (s) =>
                      viewSettings.setSortOrder(s.first),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, l10n.optionsSheetFolderFields),
                // 顺序按「常用优先」排：数量 / 大小（默认选中）放在最前两个，
                // 路径 / 日期跟在后面——不按枚举顺序，避免默认选中项落在中间
                _fieldChips(
                  context,
                  [
                    FolderField.count,
                    FolderField.size,
                    FolderField.path,
                    FolderField.date,
                  ].map((f) {
                    final selected = viewSettings.fields.contains(f);
                    return (
                      label: folderFieldLabel(l10n, f),
                      selected: selected,
                      onToggle: () => viewSettings.toggleField(f),
                    );
                  }).toList(),
                ),
              ]);
            }
            if (hasVideos) {
              if (hasFolders) {
                // 混合页面：文件夹区与视频区之间用一条分割线划分
                sections.addAll(const [
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                ]);
              }
              // 下半区：视频相关
              sections.addAll([
                _sectionTitle(context, l10n.optionsSheetVideoSort),
                SegmentedButton<VideoSortField>(
                  showSelectedIcon: false,
                  segments: VideoSortField.values
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(videoSortFieldLabel(l10n, e)),
                        ),
                      )
                      .toList(),
                  selected: {viewSettings.videoSortField},
                  onSelectionChanged: (s) =>
                      viewSettings.setVideoSortField(s.first),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, l10n.optionsSheetVideoSortDir),
                SegmentedButton<SortOrder>(
                  showSelectedIcon: false,
                  segments: SortOrder.values
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(sortOrderLabel(l10n, e)),
                        ),
                      )
                      .toList(),
                  selected: {viewSettings.videoSortOrder},
                  onSelectionChanged: (s) =>
                      viewSettings.setVideoSortOrder(s.first),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, l10n.optionsSheetVideoFields),
                // 7 个开关，三行胶囊（等宽均分）：
                // 第一行 时长/大小/日期，第二行 进度/分辨率·帧率，
                // 第三行 字幕指示器/完整名称（横向两个）
                _videoFieldChips(context, viewSettings),
              ]);
            }
            if (showViewMode) {
              sections.addAll(const [
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 16),
              ]);
              sections.addAll([
                _sectionTitle(context, l10n.optionsSheetViewMode),
                SegmentedButton<ViewMode>(
                  showSelectedIcon: false,
                  // 列表模式在前、树状模式在后
                  segments: [ViewMode.list, ViewMode.tree]
                      .map(
                        (e) => ButtonSegment(
                          value: e,
                          label: Text(viewModeLabel(l10n, e)),
                        ),
                      )
                      .toList(),
                  selected: {viewSettings.viewMode},
                  onSelectionChanged: (s) =>
                      viewSettings.setViewMode(s.first),
                ),
              ]);
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.homeSortAndFields,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...sections,
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _fieldChips(
    BuildContext context,
    List<({String label, bool selected, VoidCallback onToggle})> items,
  ) {
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (e) => _capsuleChip(
                context,
                label: e.label,
                selected: e.selected,
                onToggle: e.onToggle,
                // Wrap 内按内容自适应宽度（不撑满整行）
                fillWidth: false,
              ),
            )
            .toList(),
      ),
    );
  }

  /// 视频显示字段：三行胶囊布局（7 个开关 = 3 + 2 + 2），**行内等宽均分**。
  ///
  /// - 第一行：时长 / 大小 / 日期（3 个胶囊，各占 1/3 行宽）；
  /// - 第二行：进度 / 分辨率·帧率（2 个胶囊，各占 1/2 行宽）；
  /// - 第三行：字幕指示器 / 完整名称（2 个胶囊，各占 1/2 行宽）。
  ///
  /// 分辨率与帧率在卡片上是**同一个胶囊**（`1080p@23.98`），设置里也合成
  /// 一个开关：点一次同时开/关两个字段（老用户只开了其中一个时，点一下补齐）。
  Widget _videoFieldChips(BuildContext context, ViewSettings viewSettings) {
    final l10n = AppLocalizations.of(context);

    ({String label, bool selected, VoidCallback onToggle}) chip(
      VideoField f,
    ) {
      return (
        label: videoFieldLabel(l10n, f),
        selected: viewSettings.videoFields.contains(f),
        onToggle: () => viewSettings.toggleVideoField(f),
      );
    }

    // 分辨率 + 帧率 合并开关：两个字段都开才算选中，点一下同步两个字段
    const qualityFields = [VideoField.resolution, VideoField.frameRate];
    final qualitySelected =
        qualityFields.every(viewSettings.videoFields.contains);
    final qualityChip = (
      label: l10n.commonResolutionFrameRate,
      selected: qualitySelected,
      onToggle: () {
        // 手写循环（不能用 toggle 的返回值）：enable 在第一次切换后会变，
        // 这里以点击前的状态为准，两个字段朝同一个方向走
        final enable = !qualitySelected;
        for (final f in qualityFields) {
          if (viewSettings.videoFields.contains(f) != enable) {
            viewSettings.toggleVideoField(f);
          }
        }
      },
    );

    // 显式指定每行字段（不依赖枚举顺序）
    final row1 = [
      chip(VideoField.duration),
      chip(VideoField.size),
      chip(VideoField.date),
    ];
    final row2 = [chip(VideoField.progress), qualityChip];
    final row3 = [chip(VideoField.subtitle), chip(VideoField.fullName)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chipRow(context, row1),
        const SizedBox(height: 6),
        _chipRow(context, row2),
        const SizedBox(height: 6),
        _chipRow(context, row3),
      ],
    );
  }

  Widget _chipRow(
    BuildContext context,
    List<({String label, bool selected, VoidCallback onToggle})> items,
  ) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          // 等宽均分：每个胶囊占 1/N 行宽，内容水平居中
          Expanded(
            child: _capsuleChip(
              context,
              label: items[i].label,
              selected: items[i].selected,
              onToggle: items[i].onToggle,
              // 行内等宽胶囊：撑满单元格宽度，内容居中
              fillWidth: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }

  /// 胶囊样式的字段选择项（工作.md 第 2 点：由 FilterChip 的正方形圆角
  /// 背景改为胶囊样式，对齐播放界面-倍速面板的胶囊视觉）：
  /// 选中 = 主题色填充 + 高亮文字；未选中 = 表面色胶囊 + 常规文字。
  Widget _capsuleChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onToggle,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    bool fillWidth = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // Wrap 场景按内容自适应；等宽行场景撑满单元格
        width: fillWidth ? double.infinity : null,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
