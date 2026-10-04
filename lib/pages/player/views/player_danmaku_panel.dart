/// 弹幕二级界面（播放器「更多 → 弹幕」/ 顶栏「弹幕」槽位共用，阶段1+3）：
/// 四个入口——本地弹幕（文件选择器导入）/ 网络弹幕（弹弹Play 搜索三级界面）/
/// 自动匹配（弹弹Play 文件匹配）/ 弹幕设置（与底栏弹幕设置按钮同一行为）。
///
/// 本地弹幕的文件选择器**规则与参数风格与本地字幕文件选择器一致**（工作.md
/// 弹幕第 2 点）：
/// - SDK ≤ 30：系统文件选择器（ACTION_OPEN_DOCUMENT），content:// 由原生侧
///   拷贝到 filesDir/danmaku/ 后返回真实路径；
/// - SDK ≥ 31：复用自建选择器面板 [SubtitleFilePickerPanel]（只换文件过滤
///   器 / 图标 / 记忆键，对齐音频选择器的复用方式，§4.5「不得另写一套外壳」），
///   支持排序与文件夹记忆（独立记忆键）。
///
/// 网络弹幕 / 自动匹配由播放页注入回调（阶段3 实现，见 player_page /
/// player_portrait_page）；弹幕设置与底栏按钮同一回调。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/device_services.dart';
import 'package:moumou/services/danmaku_service.dart';
import 'package:moumou/pages/player/views/subtitle_file_picker.dart';
import 'package:moumou/utils/danmaku_local_file.dart';
import 'package:moumou/widgets/player_panel.dart';

/// 本地弹幕文件选择服务（对齐 [SubtitleFileService] / AudioFileService 的思路）。
///
/// - SDK ≤ 29（Android 10 及以下）：系统选择器（content:// 由原生侧拷贝为真实路径）；
/// - SDK ≥ 30（Android 11 及以上）：复用自建选择器（[SubtitleFilePickerPanel]，
///   独立记忆文件夹）。
class DanmakuFileService {
  DanmakuFileService._();

  static const lastFolderKey = 'danmaku_picker_last_folder';

  /// 系统文件选择器（Android 10 及以下）：content:// 拷贝为应用内真实路径后返回。
  ///
  /// ⚠️ 必须走 [DeviceServices.openDanmakuPicker]（弹幕专用 MIME 白名单）：
  /// 复用字幕选择器会把 .xml（MIME `text/xml`）置灰选不中。
  static Future<String?> pickWithSystemPicker() async {
    final uri = await DeviceServices.openDanmakuPicker();
    if (uri == null) return null;
    final name = uri.split('/').where((s) => s.isNotEmpty).last;
    final fileName = name.isEmpty ? 'danmaku.xml' : name;
    return DeviceServices.copyDanmakuFromUri(uri, fileName);
  }
}

class PlayerDanmakuPanel extends StatelessWidget {
  /// 弹幕控制器（横竖屏共享同一实例）
  final DanmakuController controller;

  /// 打开弹幕设置（面板内就地切换到设置页；由页面注入导航回调，与底栏
  /// 弹幕设置按钮不同——后者在无面板时用 [showPlayerPanel] 单独打开）
  final VoidCallback onSettingsTap;

  /// 面板内二级页就地切换（由页面注入：横屏传 PlayerPanelNavigator、
  /// 竖屏传 PlayerBottomPanelNavigator，面板不直接依赖外壳）
  final void Function(String title, Widget body)? onPushSubPage;

  /// 选择器二级页返回（由页面注入）
  final VoidCallback? onPopSubPage;

  /// 打开网络弹幕搜索三级界面（由页面注入，阶段3）
  final VoidCallback? onNetworkTap;

  /// 触发自动匹配（由页面注入，阶段3）
  final VoidCallback? onAutoMatchTap;

  const PlayerDanmakuPanel({
    super.key,
    required this.controller,
    required this.onSettingsTap,
    this.onPushSubPage,
    this.onPopSubPage,
    this.onNetworkTap,
    this.onAutoMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _DanmakuOptionTile(
          icon: Icons.file_open_outlined,
          label: l10n.playerDanmakuLocal,
          onTap: () => _importLocalDanmaku(context),
        ),
        _DanmakuOptionTile(
          icon: Icons.cloud_outlined,
          label: l10n.playerDanmakuNetwork,
          onTap:
              onNetworkTap ??
              () => _toast(context, l10n.playerDanmakuNetworkComingSoon),
        ),
        _DanmakuOptionTile(
          icon: Icons.auto_fix_high,
          label: l10n.playerDanmakuAutoMatch,
          onTap:
              onAutoMatchTap ??
              () => _toast(context, l10n.playerDanmakuAutoMatchComingSoon),
        ),
        _DanmakuOptionTile(
          icon: Icons.settings_outlined,
          label: l10n.playerDanmakuSettings,
          onTap: onSettingsTap,
        ),
      ],
    );
  }

  // ── 本地弹幕导入（文件选择器，规则对齐本地字幕文件选择器）──

  /// 面板内二级页就地切换（§4.5：复用面板导航器，禁止叠加第二个面板）。
  void _pushSubPage(BuildContext context, String title, Widget body) {
    final push = onPushSubPage;
    if (push != null) {
      push(title, body);
      return;
    }
    // 兜底：无注入时尝试右侧面板导航器（横屏外壳）
    PlayerPanelNavigator.of(context)
        .push(PlayerPanelPage(title: title, body: body));
  }

  /// 导入本地弹幕：按 Android 版本走系统/自建文件选择器。
  /// - Android 10 及以下（SDK ≤ 29）：系统选择器（原生 ACTION_OPEN_DOCUMENT，
  ///   分区存储下非媒体文件只有 SAF 授权才读得到）；
  /// - Android 11 及以上（SDK ≥ 30）：自建选择器（复用 [SubtitleFilePickerPanel]，
  ///   面板二级页）。分派规则与理由见 [DeviceServices.shouldUseSystemPicker]。
  ///
  /// ⚠️ 提示用的 `l10n` 与 `ScaffoldMessenger` **必须在这里取好**（此刻面板还在
  /// 树上）：自建选择器是**面板内二级页**，push 之后面板自身会被移出树
  /// （[PlayerPanel] 只渲染页面栈顶那一页），文件选完时再对旧 context 调
  /// `AppLocalizations.of` / `ScaffoldMessenger.of` 就会命中
  /// 「Looking up a deactivated widget's ancestor is unsafe」——**debug 构建下
  /// 回调直接抛异常：文件点了没反应、弹幕也没导入**（用户实测 `T4-DMK-002`，
  /// Android 16 走自建选择器）。字幕/音频两个面板的 `onPicked` 不碰 context，
  /// 所以只有弹幕这一处踩到。
  Future<void> _importLocalDanmaku(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sdk = await DeviceServices.getSdkInt();
    if (!context.mounted || sdk <= 0) return;
    if (DeviceServices.shouldUseSystemPicker(sdk)) {
      final path = await DanmakuFileService.pickWithSystemPicker();
      if (path == null) return;
      await _loadPickedFile(messenger, l10n, path);
      return;
    }
    // 自建选择器：作为面板二级页就地切换（复用字幕文件选择器外壳，
    // 只换文件过滤器/图标/记忆键——与音频选择器同款复用方式）
    _pushSubPage(
      context,
      l10n.playerPickDanmakuFile,
      SubtitleFilePickerPanel(
        fileFilter: isSupportedDanmakuFile,
        folderKey: DanmakuFileService.lastFolderKey,
        fileIcon: Icons.comment_outlined,
        onPicked: (path) => _loadPickedFile(messenger, l10n, path),
        onClose: () => onPopSubPage?.call(),
      ),
    );
  }

  /// 加载所选弹幕文件并给出轻提示（成功带**弹幕文件名**；空文件/解析失败视为失败）。
  ///
  /// 收 [ScaffoldMessengerState] 与 [AppLocalizations] 而不是 [BuildContext]：
  /// 本方法在「面板已被二级页替换」之后才被调用，那时的 context 已失效
  /// （见 [_importLocalDanmaku] 的注释）。
  Future<void> _loadPickedFile(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    String path,
  ) async {
    final ok = await controller.loadDanmakuFromFile(path);
    if (!messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.playerLocalDanmakuLoaded(danmakuFileNameOf(path))
                : l10n.playerDanmakuLoadFailedCheckFormat,
          ),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _toast(BuildContext context, String message) {
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
}

/// 弹幕二级界面的选项行：图标 + 名称 + 箭头（样式对齐「更多」面板的动作行）。
class _DanmakuOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DanmakuOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      titleAlignment: ListTileTitleAlignment.center,
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
    );
  }
}
