import 'package:flutter/material.dart';
import 'package:moumou/models/playback_history_entry.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/player/player_page.dart';
import 'package:moumou/services/playback_history_service.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/app_frame.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:moumou/widgets/video_card.dart';

/// 历史记录页（工作.md：播放历史记录功能）：「我的 → 播放 → 历史记录」。
///
/// - 条目复用 [VideoCard]（视觉与视频列表一致），**只显示播放进度字段**
///   （历史记录读不到文件大小，不展示大小/时长；进度由保存的播放进度
///   与条目时长计算）；
/// - 条目最右侧为**垃圾桶按钮**，点击删除单条（无二次确认）；
/// - 右上角「清空」一键清除全部（showAppDialog 二次确认）；
/// - 顶部开关「播放历史记录」：关闭后不再记录新播放，已存历史保留可查看；
/// - 点击条目直接重放（本地路径 / 在线直链；进度由播放页自动恢复）。
class PlaybackHistoryPage extends StatefulWidget {
  const PlaybackHistoryPage({super.key});

  @override
  State<PlaybackHistoryPage> createState() => _PlaybackHistoryPageState();
}

class _PlaybackHistoryPageState extends State<PlaybackHistoryPage> {
  final PlaybackHistoryService _history = PlaybackHistoryService.instance;

  /// 历史页固定只显示播放进度字段（不读文件大小/时长等本地元数据）
  static const Set<VideoField> _fields = {VideoField.progress};

  @override
  void initState() {
    super.initState();
    _history.ensureLoaded();
  }

  Future<void> _playEntry(PlaybackHistoryEntry entry) async {
    await Navigator.of(context).push(
      playerPageRoute(PlayerPage(path: entry.path, title: entry.title)),
    );
    // 返回后刷新：进度条变化 + 重放条目被提到最前
    if (mounted) setState(() {});
  }

  /// 一键清空全部历史（showAppDialog 二次确认，工作.md 明确要求）
  Future<void> _confirmClearAll() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除历史记录'),
        content: const Text('确定要清除全部播放历史吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _history.clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          ListenableBuilder(
            listenable: _history,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清除全部历史',
              // 无历史时禁用（置灰不可点）
              onPressed: _history.entries.isEmpty ? null : _confirmClearAll,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _history,
          PlaybackProgressService.instance,
        ]),
        builder: (context, _) {
          final entries = _history.entries;
          return Column(
            children: [
              // ── 播放历史记录开关（关闭只停新记录，已存历史保留）──
              SettingsCard(
                child: SettingsSwitchTile(
                  icon: Icons.history,
                  title: '播放历史记录',
                  subtitle: const Text('关闭后不再记录新的播放'),
                  value: _history.enabled,
                  onChanged: (v) => _history.setEnabled(v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildList(context, scheme, entries)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme scheme,
    List<PlaybackHistoryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 72, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              _history.enabled ? '暂无播放历史' : '暂无播放历史（记录已关闭）',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VideoCard(
            video: VideoFile(
              path: entry.path,
              name: entry.title,
              durationMs: entry.durationMs,
              // 在线直链复用 network 来源语义：跳过本地缩略图/元数据解析
              source: entry.isUrl ? VideoSource.network : VideoSource.local,
            ),
            fields: _fields,
            onTap: () => _playEntry(entry),
            // 最右侧垃圾桶：点击删除单条（无二次确认，清空才有二次确认）
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              tooltip: '删除该条记录',
              visualDensity: VisualDensity.compact,
              onPressed: () => _history.remove(entry.path),
            ),
          ),
        );
      },
    );
  }
}
