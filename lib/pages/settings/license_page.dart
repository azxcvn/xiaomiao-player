import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 自定义许可证书页（设置 → 关于 → 许可证书，工作.md 第 7 点重做）：
/// - 不再使用折叠式（ExpansionTile）：改为**列表 + 二级详情页**——
///   每个包一行（图标 + 包名 + 许可数量 + 箭头），点击进入该包的许可详情页；
/// - 顶部保留紧凑卡片式头部：小图标 + 应用名 + 版本号 水平排列 + 许可数量角标；
/// - 详情页展示完整许可文本（可选中复制），带一键复制按钮。
class LicensePage extends StatefulWidget {
  const LicensePage({super.key});

  @override
  State<LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<LicensePage> {
  late Future<Map<String, LicenseEntry>> _licensesFuture;
  String? _version;

  /// `LicenseRegistry.licenses` 是 `Stream<LicenseEntry>`；本 SDK 的
  /// LicenseRegistry 没有 collectLicenses()，这里手动把流一次性收集为
  /// `Future<Map<String, LicenseEntry>>`（包名 → 许可条目），配合 FutureBuilder
  /// 整页渲染，避免每个许可单独建流监听。
  static Future<Map<String, LicenseEntry>> _collectLicenses() async {
    final map = <String, LicenseEntry>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        map[package] = entry;
      }
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _licensesFuture = _collectLicenses();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((_) {});
  }

  void _reload() {
    setState(() => _licensesFuture = _collectLicenses());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLicenseTitle)),
      body: FutureBuilder<Map<String, LicenseEntry>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _reload);
          }
          final map = snapshot.data;
          if (map == null || map.isEmpty) {
            return Center(
              child: Text(
                l10n.settingsLicenseEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          // 按包名排序（忽略大小写），保持列表稳定有序
          final packages = map.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          // 许可条目数百条：表头固定，条目走 SliverList 懒构建（P2-38 同族收口，
          // 与 device_info_page 一致，不再一次性 `for` 全量构建）
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                sliver: SliverList.list(
                  children: [
                    _LicenseHeaderCard(
                      version: _version,
                      licenseCount: packages.length,
                    ),
                    const SizedBox(height: 20),
                    SettingsGroupTitle(title: l10n.settingsLicenseOpenSource),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverList.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, i) {
                    final package = packages[i];
                    return _LicenseEntryTile(
                      package: package,
                      entry: map[package]!,
                      onTap: () => _openDetail(package, map[package]!),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(String package, LicenseEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LicenseDetailPage(package: package, entry: entry),
      ),
    );
  }
}

/// 紧凑卡片式头部（设计稿见 docs/archive/design-license-header.html，方案 B）：
/// 左「App 图标」+ 右两行——名称一行，下面并排两枚胶囊（版本 / 项数）。
///
/// 与旧版的差别：版本号从名称后面拆出来、项数从右侧实心角标改为弱化胶囊。
/// 原先角标占约 90dp 且颜色最重，会把注意力从应用名上抢走；改成两枚胶囊后
/// 信息全在左侧，横向（名称）可用宽度也从约 110dp 涨到约 180dp。
class _LicenseHeaderCard extends StatelessWidget {
  final String? version;
  final int licenseCount;

  const _LicenseHeaderCard({required this.version, required this.licenseCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // 13/14 与设计稿一致（旧的 12/14 在图标 44dp 下上留白显小）
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App 图标（与关于页/桌面图标同源）：assets/icon/app_icon_display.png
            // 是 1024 源图的 256px 缩放版，只作展示用，避免把 621 KB 的图标源文件
            // 打进包体。
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/icon/app_icon_display.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: _LicenseChip(
                          // 版本只显示版本名（与关于页一致，不带构建号）
                          label: version == null
                              ? l10n.settingsLicenseVersionLoading
                              : 'v$version',
                          background: scheme.primary,
                          foreground: scheme.onPrimary,
                          bold: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _LicenseChip(
                          label: l10n.settingsLicenseCount(licenseCount),
                          background: scheme.surfaceContainerHigh,
                          foreground: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头部卡片里的一枚胶囊：圆角全包、字号 11.5，长文本省略。
class _LicenseChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool bold;

  const _LicenseChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.1,
            color: foreground,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 单个包的一行入口：图标 + 包名 + 许可段落数 + 右箭头；点击进入详情页。
class _LicenseEntryTile extends StatelessWidget {
  final String package;
  final LicenseEntry entry;
  final VoidCallback onTap;

  const _LicenseEntryTile({
    required this.package,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.code_rounded,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          package,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          l10n.settingsLicenseParagraphCount(entry.paragraphs.length),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

/// 许可证书详情页（二级界面）：完整许可文本 + 一键复制。
class LicenseDetailPage extends StatelessWidget {
  final String package;
  final LicenseEntry entry;

  const LicenseDetailPage({
    super.key,
    required this.package,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final licenseText = entry.paragraphs.map((p) => p.text).join('\n\n');
    return Scaffold(
      appBar: AppBar(
        title: Text(package, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.settingsLicenseCopy,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: licenseText));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsLicenseCopied),
                    duration: const Duration(milliseconds: 1200),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部摘要卡片：包名 + 许可段落数
            Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.settingsLicenseParagraphCount(
                          entry.paragraphs.length,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 完整许可文本（可选中复制）
            SelectableText(
              licenseText,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 许可收集失败时的错误视图（带重试）
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            l10n.settingsLicenseLoadFailed,
            style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
