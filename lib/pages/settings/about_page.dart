import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/settings/cache_management_page.dart';
import 'package:moumou/pages/settings/error_log_page.dart';
// 前缀导入：本文件自定义 LicensePage 与 material 内置 LicensePage 同名
import 'package:moumou/pages/settings/license_page.dart' as app;
import 'package:moumou/pages/settings/privacy_policy_page.dart';
import 'package:moumou/services/build_info_service.dart';
import 'package:moumou/services/update/update_service.dart';
import 'package:moumou/services/update/update_settings.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:moumou/widgets/update_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于页（设置 → 其他 → 关于）：
/// - 顶部卡片式软件信息（上排：图标 + 名称 + GitHub/邮箱；下排：版本 / 构建类型 /
///   提交哈希三枚等宽胶囊）；
/// - 「信息」组：许可证书、用户协议；
/// - 「工具」组：缓存管理、错误日志；
/// - 「更新」组：手动检查更新 + 自动检查更新。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// 构建信息（版本 / 构建类型 / 提交哈希）；null = 尚未读完
  BuildInfo? _buildInfo;

  /// 使用反馈收件邮箱
  static const _feedbackEmail = '2297065843@qq.com';

  /// GitHub 主页地址（与更新服务共用仓库地址）
  static const _githubUrl = UpdateService.repoUrl;

  @override
  void initState() {
    super.initState();
    BuildInfo.load()
        .then((info) {
          if (mounted) setState(() => _buildInfo = info);
        })
        .catchError((_) {});
  }

  /// 跳转手机邮件并进入写邮件界面（收件人 + 主题「播放器使用反馈」）
  Future<void> _openEmail() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      query: 'subject=${Uri.encodeComponent(l10n.settingsAboutFeedbackSubject)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast(l10n.settingsAboutNoEmailApp);
    }
  }

  /// 跳转浏览器访问 GitHub（地址暂时留空，接入前提示）
  Future<void> _openGitHub() async {
    final l10n = AppLocalizations.of(context);
    if (_githubUrl.isEmpty) {
      _toast(l10n.settingsAboutGithubPending);
      return;
    }
    final uri = Uri.parse(_githubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast(l10n.settingsAboutCannotOpenLink);
    }
  }

  /// 手动检查更新：有更新弹窗，已是最新 Toast，失败 Toast。
  Future<void> _checkForUpdate() async {
    final l10n = AppLocalizations.of(context);
    try {
      final info = await UpdateService.checkForUpdate();
      if (info == null) {
        if (!mounted) return;
        _toast(l10n.settingsAboutUpToDate);
        return;
      }
      if (!mounted) return;
      await showUpdateDialog(
        context,
        info: info,
        settings: UpdateSettings.instance,
      );
    } catch (_) {
      if (!mounted) return;
      _toast(l10n.settingsAboutCheckUpdateFailed);
    }
  }

  /// 复制提交哈希（点击哈希胶囊；未注入时提示原因，不伪造值）
  Future<void> _copyRevision() async {
    final info = _buildInfo;
    if (info == null) return;
    if (info.hasRevision) {
      await Clipboard.setData(ClipboardData(text: info.revisionLabel));
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    _toast(switch (info.copyHint()) {
      BuildInfoCopyHint.noRevision => l10n.buildInfoNoRevision,
      BuildInfoCopyHint.copied => l10n.buildInfoCopied(info.revisionLabel),
      BuildInfoCopyHint.copiedDirty =>
        l10n.buildInfoCopiedDirty(info.revisionLabel),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          const SizedBox(height: 8),
          // ── 顶部卡片：软件信息────────────────────────────
          // 上排：图标 + 名称 + GitHub/邮箱（两个按钮并排，不再纵排）；
          // 下排：版本 / 构建类型 / 提交哈希三枚等宽胶囊（右缘齐平）。
          // 名称左内边距 13 是设计稿逐次微调后的定稿值（见
          // docs/archive/design-about-info-card.html），不要顺手改回 0。
          _AppInfoCard(
            info: _buildInfo,
            onGitHub: _openGitHub,
            onEmail: _openEmail,
            onCopyRevision: _copyRevision,
          ),
          const SizedBox(height: 24),
          // ── 信息组（第一位）─────────────────────────────
          SettingsGroupTitle(title: l10n.settingsAboutGroupInfo),
          SettingsCard(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.gavel_outlined,
                  title: l10n.settingsAboutLicenses,
                  subtitle: Text(l10n.settingsAboutLicensesDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // 前缀引用避免与 Flutter material 内置 LicensePage 冲突
                        builder: (_) => const app.LicensePage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // 用户协议并入信息组（工作.md：隐私政策功能）
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: l10n.settingsAboutUserAgreement,
                  subtitle: Text(l10n.settingsAboutUserAgreementDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 工具组（正中间）─────────────────────────────
          SettingsGroupTitle(title: l10n.settingsAboutGroupTools),
          SettingsCard(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: l10n.settingsAboutCacheManagement,
                  subtitle: Text(l10n.settingsAboutCacheManagementDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CacheManagementPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsTile(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.settingsErrorLogTitle,
                  subtitle: Text(l10n.settingsAboutErrorLogDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ErrorLogPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 更新组（最后一位）────────────────────────────
          SettingsGroupTitle(title: l10n.settingsAboutGroupUpdate),
          ListenableBuilder(
            listenable: UpdateSettings.instance,
            builder: (context, _) {
              final update = UpdateSettings.instance;
              return SettingsCard(
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.system_update_outlined,
                      title: l10n.settingsAboutCheckUpdate,
                      subtitle: Text(l10n.settingsAboutCheckUpdateDesc),
                      onTap: _checkForUpdate,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SettingsSwitchTile(
                      icon: Icons.update_outlined,
                      title: l10n.settingsAboutAutoCheckUpdate,
                      subtitle: Text(l10n.settingsAboutAutoCheckUpdateDesc),
                      value: update.autoUpdateEnabled,
                      onChanged: (v) => update.setAutoUpdateEnabled(v),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 关于页顶部信息卡片。
///
/// 布局（定稿见 docs/archive/design-about-info-card.html）：
/// - 上排 56dp 定高：56dp 圆角图标 + 名称（左内边距 13dp，让名称离右侧按钮更近）
///   + GitHub / 邮箱两个纯图标按钮（横排）；
/// - 下排：版本 / 构建类型 / 提交哈希三枚**等宽**胶囊（各占 1/3，右缘齐平）。
///
/// 名称左内边距 13 是设计稿逐次微调的结果，不是随手写的数——余量只剩约 9dp
/// （304 − 56 − 14 − 76 − 13 ≈ 145，25sp 的「小喵Player」约 132dp），改大之前
/// 先确认不会把名称挤成省略号。
class _AppInfoCard extends StatelessWidget {
  final BuildInfo? info;
  final VoidCallback onGitHub;
  final VoidCallback onEmail;
  final VoidCallback onCopyRevision;

  const _AppInfoCard({
    required this.info,
    required this.onGitHub,
    required this.onEmail,
    required this.onCopyRevision,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  // 应用图标（与桌面/启动图标同源）：assets/icon/
                  // app_icon_display.png 是 1024 源图的 256px 缩放版，
                  // 只作展示用，避免把 621 KB 的图标源文件打进包体。
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/app_icon_display.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      // 名称整体右移一点（设计稿微调定稿值）
                      padding: const EdgeInsets.only(left: 13),
                      child: Text(
                        l10n.appTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    tooltip: 'GitHub',
                    dense: true,
                    onTap: onGitHub,
                    child: SvgPicture.asset(
                      'assets/icons/github.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        scheme.onSurfaceVariant,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    tooltip: l10n.settingsAboutSendFeedback,
                    dense: true,
                    onTap: onEmail,
                    child: SvgPicture.asset(
                      'assets/icons/email.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        scheme.onSurfaceVariant,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 三枚等宽胶囊；哈希胶囊可点击复制（未注入哈希时提示原因）
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: info?.versionLabel ?? l10n.settingsAboutAppNameLoading,
                    background: scheme.primary,
                    foreground: scheme.onPrimary,
                    bold: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    label: info?.buildTypeLabel ?? '—',
                    // debug 用琥珀色与 release 拉开距离（不必读文字也能分辨）
                    background: (info?.isRelease ?? true)
                        ? scheme.primaryContainer
                        : scheme.tertiaryContainer,
                    foreground: (info?.isRelease ?? true)
                        ? scheme.onPrimaryContainer
                        : scheme.onTertiaryContainer,
                    bold: true,
                    dot: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    label: info?.revisionLabel ?? '—',
                    background: scheme.surfaceContainerHighest,
                    foreground: scheme.onSurfaceVariant,
                    mono: true,
                    onTap: onCopyRevision,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 信息卡片里的一枚等宽胶囊：可选前置圆点、等宽字体、可点击。
///
/// 三枚胶囊都用 [Expanded] 包住后传入，宽度由外部决定（各占 1/3），
/// 内容一律居中——右缘因此天然齐平，不会出现「版本短、哈希长」的参差。
class _InfoChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final bool bold;
  final bool mono;
  final bool dot;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.bold = false,
    this.mono = false,
    this.dot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.1,
                color: foreground,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                // 哈希用等宽字体：字符等宽更易核对，也避免 1/l、0/O 看混
                fontFamily: mono ? 'monospace' : null,
                letterSpacing: mono ? 0.3 : null,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: content,
    );
  }
}

/// 关于页顶部卡片的纯图标按钮（邮箱 / GitHub 共用样式）：
/// 无底色容器，仅 Tooltip + InkWell 波纹 + 图标，点击区域约 42×42
/// （[dense] 时为 38×38，用于两个按钮并排的横排布局）。
class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  /// 紧凑内边距（横排时用，避免两个按钮把名称挤窄）
  final bool dense;

  const _HeaderIconButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.all(dense ? 9 : 11),
          child: child,
        ),
      ),
    );
  }
}
