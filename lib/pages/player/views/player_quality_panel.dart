import 'package:flutter/material.dart';
import 'package:moumou/models/bili_dash.dart';
import 'package:moumou/widgets/player_option_chip.dart';

/// 清晰度面板：列出当前账号可选的画质档（`accept_quality`），当前档高亮，
/// 点击切换画质（切换由父级重新解析 playurl 并重开播放保持进度）。
///
/// 点击后先乐观更新高亮，**再按父级返回的真实档位收口**（[onSelect] 返回
/// 切换后的真实 qn，失败返回 null）：
/// - 成功但服务端因权限回落到别的档 → 高亮钉到**实际**那一档；
/// - 失败 → 回到**切换前**那一档，而不是「开面板时」那一档（§4.15/§7）。
class PlayerQualityPanel extends StatefulWidget {
  const PlayerQualityPanel({
    super.key,
    required this.qualities,
    required this.currentQn,
    required this.onSelect,
  });

  final List<BiliQualityOption> qualities;
  final int currentQn;

  /// 切换画质：返回**切换后的真实 qn**，失败返回 null。
  final Future<int?> Function(int qn) onSelect;

  @override
  State<PlayerQualityPanel> createState() => _PlayerQualityPanelState();
}

class _PlayerQualityPanelState extends State<PlayerQualityPanel> {
  late int _currentQn = widget.currentQn;
  bool _switching = false;

  @override
  void didUpdateWidget(covariant PlayerQualityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 面板打开期间父级换过档（例如外层重建）→ 以真实档位为准
    if (!_switching && widget.currentQn != oldWidget.currentQn) {
      _currentQn = widget.currentQn;
    }
  }

  Future<void> _select(int qn) async {
    if (_switching || qn == _currentQn) return;
    // 切换前的**真实**高亮：失败时回到它，而不是 widget.currentQn
    // （后者是开面板那一刻的快照，连切两档时已经过时）
    final before = _currentQn;
    setState(() {
      _switching = true;
      _currentQn = qn;
    });
    final actual = await widget.onSelect(qn);
    if (!mounted) return;
    setState(() {
      _currentQn = actual ?? before;
      _switching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.qualities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '暂无可用画质',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.qualities.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var j = 0; j < 2 && i + j < widget.qualities.length; j++) ...[
                  if (j > 0) const SizedBox(width: 8),
                  Expanded(
                    child: PlayerOptionChip(
                      label: widget.qualities[i + j].description,
                      selected: widget.qualities[i + j].qn == _currentQn,
                      onTap: () => _select(widget.qualities[i + j].qn),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '切换画质会重开播放并保持进度',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
