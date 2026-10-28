/// AB 段循环面板内容（横屏右侧面板 / 竖屏底部面板共用）。
///
/// 两个端点行（A 点 / B 点，显示已设时间，右侧 ✕ 单独清除）+ 实时当前位置
/// +「设为 A / 设为 B」+ 一键清除：
/// - 「设为 A / 设为 B」把此刻播放位置写成该端点（写 mpv `ab-loop-a` /
///   `ab-loop-b`，循环由 mpv 自己执行，拖进度条、切集都不受影响）；
/// - 端点状态存在 [PlayerSessionState]（横竖屏共用一份，转屏不丢），切集时
///   由播放页清掉（mpv 的 ab-loop 属性会跨文件保留，见
///   `resetAbLoopForNewMedia`）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/pages/player/player_session_state.dart';
import 'package:moumou/utils/formatters.dart';
import 'package:moumou/widgets/player_option_chip.dart';

class PlayerAbLoopPanel extends StatelessWidget {
  /// 横竖屏共享的播放会话（A/B 端点就存在这里）
  final PlayerSessionState session;

  /// 当前播放位置（「设为 A / B」取数；面板里的当前位置也随它刷新）
  final ValueListenable<Duration> positionListenable;

  const PlayerAbLoopPanel({
    super.key,
    required this.session,
    required this.positionListenable,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.playerAbLoopDesc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.53),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _AbPointRow(
                label: l10n.playerAbLoopPointA,
                value: session.abLoopA,
                unsetText: l10n.playerAbLoopUnset,
                onClear: session.abLoopA == null ? null : session.clearAbLoopA,
              ),
              const SizedBox(height: 8),
              _AbPointRow(
                label: l10n.playerAbLoopPointB,
                value: session.abLoopB,
                unsetText: l10n.playerAbLoopUnset,
                onClear: session.abLoopB == null ? null : session.clearAbLoopB,
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<Duration>(
                valueListenable: positionListenable,
                builder: (context, position, _) => Text(
                  l10n.playerAbLoopCurrent(
                    formatDuration(position.inMilliseconds),
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // 两个「设为」按钮等宽并排：文案短，长语言/大字号下也不会挤爆
              Row(
                children: [
                  Expanded(
                    child: PlayerOptionChip(
                      label: l10n.playerAbLoopSetA,
                      selected: false,
                      onTap: () =>
                          session.setAbLoopA(positionListenable.value),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlayerOptionChip(
                      label: l10n.playerAbLoopSetB,
                      selected: false,
                      onTap: () =>
                          session.setAbLoopB(positionListenable.value),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ClearAbLoopButton(
                onTap: session.hasAbLoop ? session.clearAbLoop : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 单个端点行：名称 + 时间（或「未设置」）+ 已设置时的清除 ✕
class _AbPointRow extends StatelessWidget {
  final String label;
  final Duration? value;
  final String unsetText;
  final VoidCallback? onClear;

  const _AbPointRow({
    required this.label,
    required this.value,
    required this.unsetText,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value == null ? unsetText : formatDuration(value!.inMilliseconds),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: value == null
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onClear != null) _ClearPointButton(onTap: onClear!),
        ],
      ),
    );
  }
}

/// 端点右侧的清除 ✕（只清当前这一个端点）
class _ClearPointButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearPointButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            Icons.close,
            size: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 底部「清除 AB 循环」：两个端点都未设置时置灰不可点
class _ClearAbLoopButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ClearAbLoopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          l10n.playerAbLoopClear,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled
                ? scheme.error
                : Colors.white.withValues(alpha: 0.24),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
