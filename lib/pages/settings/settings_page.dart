import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/bilibili/bili_danmaku_download_page.dart';
import 'package:moumou/pages/bilibili/bili_login_page.dart';
import 'package:moumou/pages/bilibili/bili_user_page.dart';
import 'package:moumou/pages/bilibili/bili_video_download_page.dart';
import 'package:moumou/pages/download/download_manager_page.dart';
import 'package:moumou/pages/settings/about_page.dart';
import 'package:moumou/pages/settings/appearance_page.dart';
import 'package:moumou/pages/settings/danmaku_server_page.dart';
import 'package:moumou/pages/settings/device_info_page.dart';
import 'package:moumou/pages/settings/media_scan_settings_page.dart';
import 'package:moumou/pages/settings/playback_history_page.dart';
import 'package:moumou/pages/settings/player_settings_page.dart';
import 'package:moumou/pages/subtitle/subtitle_download_page.dart';
import 'package:moumou/services/bilibili/bili_account.dart';
import 'package:moumou/services/app_locale_settings.dart';
import 'package:moumou/theme/theme_controller.dart';
import 'package:moumou/widgets/language_picker_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 「我的」页（原设置主页）：按大类分组展示设置项，点击进入对应子页。
///
/// 顶部为哔哩哔哩账号登录入口（工作.md：对齐手机系统设置的信息架构——
/// 未登录显示「登录 / 哔哩哔哩账号」占位入口；登录后显示头像、昵称与
/// 会员状态。登录功能后续接入，当前仅入口）。当前第一组为「外观」；
/// 后续新增设置（如播放、存储等）只需在此追加分组。
///
/// 副标题统一用简短说明文字概括功能（如「调整应用外观」），
/// 不展示具体选项摘要；主标题字号大于副标题，形成视觉层级。
class SettingsPage extends StatelessWidget {
  final ThemeController controller;

  const SettingsPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMine)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return ListView(
            // 底部预留悬浮胶囊空间（系统安全区已由全局 SafeArea 处理）
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
            children: [
              // ── 账号登录入口（工作.md 阶段一）──────
              // 未登录显示「登录」入口；登录后显示头像/昵称/等级/会员状态，
              // 点击进入账号信息页（等级/经验/硬币/会员 + 退出登录）。
              ListenableBuilder(
                listenable: BiliAccount.instance,
                builder: (context, _) {
                  final account = BiliAccount.instance;
                  if (account.isLogin) {
                    final user = account.user;
                    return SettingsCard(
                      child: ListTile(
                        onTap: () => _openUserPage(context),
                        leading: _accountAvatar(context, account),
                        title: Text(
                          user.nickname,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text('${user.levelLabel} · ${user.vipLabel}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }
                  return SettingsCard(
                    child: SettingsTile(
                      icon: Icons.account_circle_outlined,
                      title: l10n.commonLogin,
                      subtitle: Text(l10n.biliAccount),
                      onTap: () => _openLogin(context),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // ── 第一组：外观 ──────────────────────────────
              SettingsGroupTitle(title: l10n.settingsGroupAppearance),
              SettingsCard(
                child: SettingsTile(
                  icon: Icons.palette_outlined,
                  title: l10n.settingsAppearanceAndFont,
                  subtitle: Text(l10n.settingsAppearanceAndFontDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AppearancePage(controller: controller),
                      ),
                    );
                  },
                ),
              ),
              // ── 播放（工作.md 第 6 点：原「播放器」改名）──
              SettingsGroupTitle(title: l10n.settingsGroupPlayback),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.play_circle_outline,
                      title: l10n.settingsPlayerSettings,
                      subtitle: Text(l10n.settingsPlayerSettingsDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlayerSettingsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    // 播放历史（工作.md：播放历史记录功能）——查看/删除/清空/
                    // 关闭记录；首页速拨「最近播放」直启最后一条
                    SettingsTile(
                      icon: Icons.history,
                      title: l10n.settingsPlaybackHistory,
                      subtitle: Text(l10n.settingsPlaybackHistoryDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PlaybackHistoryPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // ── 媒体扫描与过滤（工作.md：App 内文件管理；固定文件夹走长按菜单，无独立设置页）──
              SettingsGroupTitle(title: l10n.settingsGroupMediaLibrary),
              SettingsCard(
                child: SettingsTile(
                  icon: Icons.folder_outlined,
                  title: l10n.settingsMediaScan,
                  subtitle: Text(l10n.settingsMediaScanDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MediaScanSettingsPage(),
                      ),
                    );
                  },
                ),
              ),
              // ── 弹幕（工作.md 第 6 点：弹幕服务器管理）────────
              SettingsGroupTitle(title: l10n.commonDanmaku),
              SettingsCard(
                child: SettingsTile(
                  icon: Icons.dns_outlined,
                  title: l10n.settingsDanmakuServer,
                  subtitle: Text(l10n.settingsDanmakuServerDesc),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DanmakuServerPage(),
                      ),
                    );
                  },
                ),
              ),
              // ── 语言（用户已拍板：位置在「弹幕」组下方、「下载」组上方）──
              SettingsGroupTitle(title: l10n.settingsGroupLanguage),
              SettingsCard(
                child: SettingsTile(
                  icon: Icons.translate_outlined,
                  title: l10n.settingsLanguage,
                  // 副标题显示**当前语言**：语言名用自称，不翻译
                  subtitle: Text(
                    AppLocaleSettings.instance.rawValue ==
                            AppLocaleSettings.enCode
                        ? l10n.languageNameEn
                        : l10n.languageNameZh,
                  ),
                  onTap: () => showLanguagePickerDialog(context),
                ),
              ),
              // ── 下载（哔哩生态阶段四：弹幕/视频下载）────────
              SettingsGroupTitle(title: l10n.commonDownload),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.subtitles_outlined,
                      title: l10n.settingsDanmakuDownload,
                      subtitle: Text(l10n.settingsDanmakuDownloadDesc),
                      onTap: () =>
                          _openBiliDownload(context, const BiliDanmakuDownloadPage()),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.download_outlined,
                      title: l10n.settingsVideoDownload,
                      subtitle: Text(l10n.settingsVideoDownloadDesc),
                      onTap: () =>
                          _openBiliDownload(context, const BiliVideoDownloadPage()),
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.closed_caption_outlined,
                      title: l10n.settingsSubtitleDownload,
                      subtitle: Text(l10n.settingsSubtitleDownloadDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubtitleDownloadPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.list_alt_outlined,
                      title: l10n.settingsDownloadManager,
                      subtitle: Text(l10n.settingsDownloadManagerDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DownloadManagerPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // ── 其他（后续在此追加更多项）──────────────
              SettingsGroupTitle(title: l10n.settingsGroupOther),
              SettingsCard(
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.memory_outlined,
                      title: l10n.settingsDeviceInfo,
                      subtitle: Text(l10n.settingsDeviceInfoDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeviceInfoPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SettingsTile(
                      icon: Icons.info_outline,
                      title: l10n.settingsAbout,
                      subtitle: Text(l10n.settingsAboutDesc),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // ── 后续新增设置组示例（按需启用）──────────────
              // const SettingsGroupTitle('播放'),
              // SettingsCard(
              //   child: SettingsTile(
              //     icon: Icons.play_circle_outline,
              //     title: '播放',
              //     onTap: () {},
              //   ),
              // ),
              // const SettingsGroupTitle('存储'),
              // SettingsCard(
              //   child: SettingsTile(
              //     icon: Icons.folder_outlined,
              //     title: '存储',
              //     onTap: () {},
              //   ),
              // ),
            ],
          );
        },
      ),
    );
  }

  /// 打开 B 站下载页（弹幕/视频）：未登录哔哩哔哩账号时仅 toast 提示，
  /// 不进入页面（与首页速拨「哔哩番剧」的登录门禁一致）。
  void _openBiliDownload(BuildContext context, Widget page) {
    if (!BiliAccount.instance.isLogin) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).settingsLoginRequired)),
        );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BiliLoginPage()),
    );
  }

  void _openUserPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BiliUserPage()),
    );
  }

  /// 账号头像：有头像 URL 时用网络头像，否则回退到账号图标。
  Widget _accountAvatar(BuildContext context, BiliAccount account) {
    final scheme = Theme.of(context).colorScheme;
    final face = account.user.face;
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: face.isEmpty ? null : NetworkImage(face),
      onForegroundImageError: face.isEmpty ? null : (_, _) {},
      child: face.isEmpty
          ? Icon(Icons.account_circle, color: scheme.onPrimaryContainer)
          : null,
    );
  }
}
