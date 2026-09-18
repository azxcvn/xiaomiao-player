/// 弹幕服务器设置子页（工作.md 第 6/7 点）：
/// - 启用/停用已添加的弹幕服务器（弹弹Play 默认服务器不可删除，只能开关）；
/// - 右下角加号添加自建服务器（名称 + 地址），已添加服务器可自由删除/启停；
/// - 「搜索结果自动去重」开关：多台服务器返回同一部番剧时是否只留集数最全的
///   那条（**默认关**；开启前弹二次确认，见 [_SearchDedupeTile]）；
/// - 「切集自动匹配弹幕」开关：与默认弹弹Play 服务器**互斥**（工作.md 第 7 点，
///   收尾阶段恢复的限制）——默认服务器启用时开关变灰 + 副标题换成禁用原因，
///   点击弹 toast 说明；停用默认服务器后自动恢复用户此前的选择
///   （判定与文案统一由 [DanmakuServerSettings] 提供，见 `_AutoMatchTile`）。
///
/// 启用的服务器同时用于网络弹幕搜索（逐台实时呈现，不等齐再合并）与自动匹配。
library;

import 'package:flutter/material.dart';
import 'package:moumou/models/danmaku_server.dart';
import 'package:moumou/services/danmaku_server_settings.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 「切集自动匹配弹幕」被禁用时，盖在该行上的透明命中层 key。
///
/// 禁用态下 `Switch`/`ListTile` 都不响应手势，命中层负责吞掉点击并弹 toast；
/// 暴露 key 供 UI 测试稳定定位（否则只能点被遮挡的文本，触发命中警告）。
const Key kAutoMatchBlockedTapKey = Key('auto_match_blocked_tap');

/// 自建弹幕服务器使用教程（作者撰写的飞书文档）。
///
/// 只在「添加服务器」弹窗里以行内小链接的形式露出——教程的受众正是"正在
/// 填地址、不知道怎么填"的人，放在那里最省空间也最贴场景；不单独占一张
/// 设置卡片（一整行卡片只为一行字，视觉过重且占屏幕）。
const String _helpGuideUrl =
    'https://acnmwaofo249.feishu.cn/wiki/NIp1wW2eKi26s5kbnRqcdFhynLh';

class DanmakuServerPage extends StatelessWidget {
  const DanmakuServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = DanmakuServerSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('弹幕服务器')),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加服务器',
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              Text(
                '启用的服务器将同时用于弹幕搜索与自动匹配，搜索结果按各服务器'
                '返回顺序实时呈现',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SettingsCard(
                child: Column(
                  children: [
                    _SearchDedupeTile(settings: settings),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _AutoMatchTile(settings: settings),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SettingsGroupTitle(title: '服务器'),
              for (final server in settings.servers) ...[
                _DanmakuServerCard(
                  server: server,
                  onToggle: (enabled) =>
                      settings.setServerEnabled(server.id, enabled),
                  onDelete: () => settings.removeServer(server.id),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await showAppDialog<void>(
      context: context,
      builder: (context) => const _AddServerDialog(),
    );
  }
}

/// 「搜索结果自动去重」开关行。
///
/// 多台服务器同时启用时，同一部番剧常常每台都有：
/// - 开：同一部番剧只留一条——先返回的先上屏，后面某台**集数更全**就替换掉
///   那张卡（来源胶囊跟着变）。**默认关**：合并会"吞掉"某些服务器的结果，
///   属于需要用户知情的动作，所以由用户主动开启，且开启前弹一次二次确认
///   （见 [_DedupeConfirmDialog]，勾过「不再提示」就不再打扰）；
/// - 关：每台服务器的结果各自成卡，同一部番剧会并列出现多条，用户按来源
///   自己挑（想看哪台集数更全时有用）。
///
/// 判定只在 `DanmakuNetworkService.searchStream` 里读一次（[searchDedupe]），
/// 页面不做二次处理。
class _SearchDedupeTile extends StatelessWidget {
  final DanmakuServerSettings settings;

  const _SearchDedupeTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final enabled = settings.searchDedupe;
    return SettingsSwitchTile(
      icon: Icons.filter_alt_outlined,
      title: '搜索结果自动去重',
      // 副标题只讲"结果长什么样"：具体会做什么动作（替换/可能看不到某台）
      // 放在开启前的二次确认里，一句话塞不下、塞进去反而误导
      subtitle: Text(
        enabled ? '重复番剧合并为一条，保留集数最全的' : '每台服务器的结果各自展示，可自行挑选来源',
      ),
      value: enabled,
      onChanged: (value) => _onChanged(context, value),
    );
  }

  /// 开启走二次确认（取消则不生效）；关闭立即生效。
  Future<void> _onChanged(BuildContext context, bool value) async {
    if (!value) {
      await settings.setSearchDedupe(false);
      return;
    }
    if (!settings.searchDedupeHintDismissed) {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) => const _DedupeConfirmDialog(),
      );
      if (confirmed != true) return;
    }
    await settings.setSearchDedupe(true);
  }
}

/// 开启「搜索结果自动去重」前的二次确认（确认式：取消则开关不生效）。
///
/// 讲清三件事，避免用户以为"某台服务器搜不到"：
/// 1. 结果依旧是"谁先返回谁先显示"，不会等齐再合并；
/// 2. 同一部番剧只留一条，后续**集数更全**的会替换先到的；
/// 3. 所以某台服务器的结果可能不单独出现——**不代表它没搜到**。
///
/// 勾「不再提示」后（无论确认还是取消）不再弹（[DanmakuServerSettings
/// .searchDedupeHintDismissed]）。
class _DedupeConfirmDialog extends StatefulWidget {
  const _DedupeConfirmDialog();

  @override
  State<_DedupeConfirmDialog> createState() => _DedupeConfirmDialogState();
}

class _DedupeConfirmDialogState extends State<_DedupeConfirmDialog> {
  bool _dontAskAgain = false;

  Future<void> _close(bool confirmed) async {
    if (_dontAskAgain) {
      await DanmakuServerSettings.instance.setSearchDedupeHintDismissed(true);
    }
    if (mounted) Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('开启搜索结果自动去重？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '各服务器返回的结果仍然立刻显示，不会等全部返回。\n'
            '同一部番剧只保留一条；如果后续服务器返回的集数更全，'
            '会自动替换成更全的那条。\n'
            '因此某台服务器的结果可能不单独出现——那不代表它没搜到，'
            '而是被去重合并了。',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 6),
          // 勾选框左对齐贴住正文，不额外撑高弹窗（用 CheckboxListTile 而不是
          // Checkbox + InkWell：后者两层点击识别器会抢同一个 tap）
          CheckboxListTile(
            value: _dontAskAgain,
            onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
            title: Text(
              '不再提示',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => _close(true),
          child: const Text('开启'),
        ),
      ],
    );
  }
}

/// 「切集自动匹配弹幕」开关行（工作.md 第 7 点互斥限制的 UI 呈现）。
///
/// 默认弹弹Play 服务器启用时：开关**变灰禁用**（`onChanged: null`）+ 副标题
/// 换成禁用原因；此时点整行仍会弹 toast 说明为什么不能开（变灰而不解释会让
/// 用户以为是 bug）。
///
/// 两级文案都取自服务层（页面内不写文案字面量，防措辞漂移）：副标题用短句
/// [DanmakuServerSettings.autoMatchBlockedReason]（窄屏不挤），toast 用完整
/// 说明 [DanmakuServerSettings.autoMatchBlockedMessage]。
class _AutoMatchTile extends StatelessWidget {
  final DanmakuServerSettings settings;

  const _AutoMatchTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blockedReason = settings.autoMatchBlockedReason;
    final allowed = blockedReason == null;
    final tile = SettingsSwitchTile(
      icon: Icons.autorenew,
      title: '切集自动匹配弹幕',
      subtitle: Text(
        blockedReason ?? '切集时自动匹配并加载对应集弹幕',
        style: allowed
            ? null
            : TextStyle(color: scheme.error, fontWeight: FontWeight.w500),
      ),
      value: settings.autoMatchEnabled,
      // 禁用态传 null：Switch 与整行同时变灰（Flutter 语义化的禁用外观）
      onChanged: allowed ? (v) => settings.setAutoMatchEnabled(v) : null,
    );
    if (allowed) return tile;
    // 变灰后整行仍可点：吞掉点击并解释原因（`Switch(onChanged: null)` 与
    // `ListTile(onTap: null)` 本身不响应手势，故在外层盖一个透明命中层）
    return Stack(
      children: [
        tile,
        Positioned.fill(
          child: GestureDetector(
            key: kAutoMatchBlockedTapKey,
            behavior: HitTestBehavior.opaque,
            // toast 用完整说明（副标题只放短指引，窄屏两行会挤）
            onTap: () => _toast(
              context,
              settings.autoMatchBlockedMessage ?? blockedReason,
            ),
          ),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 2600),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// 单个服务器卡片：开关 + 名称/地址 + 删除（默认服务器不显示删除）。
class _DanmakuServerCard extends StatelessWidget {
  final DanmakuServer server;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _DanmakuServerCard({
    required this.server,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Switch(value: server.isEnabled, onChanged: onToggle),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    server.url,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (server.isDefault) ...[
                    const SizedBox(height: 2),
                    Text(
                      '内置服务器，不可删除',
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ],
                ],
              ),
            ),
            if (!server.isDefault)
              IconButton(
                tooltip: '删除',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// 添加弹幕服务器弹窗（名称 + 地址）。
class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onChanged);
    _urlController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _urlController.removeListener(_onChanged);
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _urlController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    await DanmakuServerSettings.instance.addServer(
      _nameController.text,
      _urlController.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加弹幕服务器'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '服务器名称',
              hintText: '例：我的服务器',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://example.com',
            ),
          ),
          // 行内小链接（教程入口）：左对齐贴住「服务器地址」输入框下缘，
          // 不占额外高度、不抢主操作（取消 / 添加）的视觉重量
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: _HelpLink(onTap: _openHelp),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        // 地址为空时按钮变灰（onPressed: null）：被禁用的按钮不响应手势，
        // 外层套透明命中层，点它照样能打开教程——不然用户正是在
        // "不知道地址怎么填"的时候，最需要帮助却点不动
        Stack(
          children: [
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('添加'),
            ),
            if (!_canSubmit)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openHelp,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 跳系统浏览器 / 飞书 App 打开教程。
  ///
  /// 用 `externalApplication` 而非 App 内 WebView：飞书文档在 WebView 里
  /// 登录态与跳转体验都很差，交给系统处理更稳。
  Future<void> _openHelp() async {
    final uri = Uri.parse(_helpGuideUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _toast('未找到可用的浏览器');
    }
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
}

/// 弹窗内的行内外链：小号主题色文字 + 前置外链图标（不占整行、无按钮底色）。
class _HelpLink extends StatelessWidget {
  final VoidCallback onTap;

  const _HelpLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        // 纵向留 4：点击热区不至于贴着文字太小，又不撑高弹窗
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 15, color: scheme.primary),
            const SizedBox(width: 5),
            Text(
              '如何获取服务器地址',
              style: TextStyle(
                fontSize: 13,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
