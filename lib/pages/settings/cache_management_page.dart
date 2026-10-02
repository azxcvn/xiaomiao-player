import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/services/cache_manager_service.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 缓存管理页（设置 → 关于 → 工具 → 缓存管理）：
/// 展示各类缓存占用，支持逐类清除与「一键清除所有缓存」（二次确认），
/// 右上角刷新按钮 + 下拉刷新可重新读取当前缓存大小。
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  Map<String, int> _sizes = const {};
  bool _loading = false;

  /// 各类别图标（服务层不依赖 UI，图标放页面层）
  static const _icons = {
    'listThumbs': Icons.video_library_outlined,
    'other': Icons.folder_zip_outlined,
  };

  int get _totalBytes => _sizes.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final sizes = await CacheManagerService.getCacheSizes();
    if (!mounted) return;
    setState(() {
      _sizes = sizes;
      _loading = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// 统一确认弹窗（返回是否确认）
  Future<bool> _confirm(String title, String content) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _clearCategory(CacheCategory category) async {
    final l10n = AppLocalizations.of(context);
    final size = _sizes[category.key] ?? 0;
    final label = cacheCategoryLabel(l10n, category);
    final confirmed = await _confirm(
      l10n.settingsCacheClearCategoryTitle(label),
      l10n.settingsCacheClearCategoryBody(
        label,
        formatFileSize(size),
      ),
    );
    if (!confirmed) return;
    final ok = await CacheManagerService.clearCategory(category);
    _toast(
      ok
          ? l10n.settingsCacheCategoryCleared(label)
          : l10n.settingsCacheClearFailed,
    );
    _refresh();
  }

  /// 一键清除所有缓存：二次弹窗确认
  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context);
    final first = await _confirm(
      l10n.settingsCacheClearAllTitle,
      l10n.settingsCacheClearAllBody(
        formatFileSize(_totalBytes),
        '· ${cacheCategoryLabel(l10n, CacheManagerService.listThumbs)}\n'
            '· ${cacheCategoryLabel(l10n, CacheManagerService.other)}',
      ),
    );
    if (!first) return;
    final second = await _confirm(
      l10n.settingsCacheConfirmAgainTitle,
      l10n.settingsCacheConfirmAgainBody,
    );
    if (!second) return;
    final ok = await CacheManagerService.clearAll();
    _toast(
      ok ? l10n.settingsCacheAllCleared : l10n.settingsCacheClearFailed,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsAboutCacheManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            SettingsGroupTitle(title: l10n.settingsCacheGroupTitle),
            SettingsCard(
              child: Column(
                children: [
                  for (final category in CacheManagerService.all) ...[
                    if (category != CacheManagerService.all.first)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(
                        _icons[category.key] ?? Icons.folder_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        cacheCategoryLabel(l10n, category),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _loading
                            ? l10n.settingsCacheReading
                            : formatFileSize(_sizes[category.key] ?? 0),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed:
                            _loading ? null : () => _clearCategory(category),
                        child: Text(l10n.commonClear),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 一键清除所有缓存（危险操作，二次确认）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _loading ? null : _clearAll,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(
                  l10n.settingsCacheClearAllButton(formatFileSize(_totalBytes)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.settingsCacheFooterNote,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
