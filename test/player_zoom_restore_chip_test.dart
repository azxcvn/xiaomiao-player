import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/pages/player/views/player_center_cluster.dart';
import 'package:moumou/pages/player/views/player_zoom_restore_chip.dart';

/// 「还原画面」胶囊的位置回归：
/// 1. 它必须落在**中央控制簇（快退/播放/快进）下沿之下**，留出足够间距——
///    原值 `Alignment(0, 0.34)` 与本页播放键只差约 0.01 倍屏高，真机上与播放
///    按钮的圆形阴影叠在一起（用户反馈）；0.60 实测只有约 37dp，仍显拥挤，
///    故定为 0.64（约 61dp）；
/// 2. 位置比例由 [kZoomRestoreChipAlignmentY] 统一给，横竖屏同款；
/// 3. 不越出屏幕下沿。
///
/// 显隐（跟随控制层唤出）依赖播放页的 `_controlsVisible` / `_session.zoomed`，
/// 属于整页接线，只能真机验证；这里锁定的是「位置」这一层。
void main() {
  /// 测试面尺寸固定 800×600（与播放页一样是「整屏 Stack + Center + Align」，
  /// 中央簇取自身宽度、不被拉伸）。
  Future<({Rect cluster, Rect chip, Size page})> layout(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: PlayerCenterCluster(
                  seekSeconds: 10,
                  playing: true,
                  onSeekBackward: () {},
                  onSeekForward: () {},
                  onTogglePlay: () {},
                ),
              ),
              const Positioned.fill(
                child: Align(
                  alignment: Alignment(0, kZoomRestoreChipAlignmentY),
                  child: PlayerZoomRestoreChip(onTap: _noop),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return (
      cluster: tester.getRect(find.byType(PlayerCenterCluster)),
      chip: tester.getRect(find.byType(PlayerZoomRestoreChip)),
      page: size,
    );
  }

  testWidgets('胶囊在中央控制簇下方，留出足够间距（不与播放按钮阴影重叠）', (tester) async {
    final g = await layout(tester);
    final gap = g.chip.top - g.cluster.bottom;
    expect(
      gap,
      greaterThanOrEqualTo(48),
      reason: '胶囊上沿距中央簇下沿应 ≥48dp（实测 $gap）',
    );
    // 不越出屏幕下沿
    expect(g.chip.bottom, lessThan(g.page.height));
  });

  testWidgets('位置常量是横竖屏共用的那一个值', (tester) async {
    expect(kZoomRestoreChipAlignmentY, 0.64);
    // 竖屏（360×640）按同一比例算出的中心位置应落在下半屏、且仍在屏内
    const portraitHeight = 640.0;
    final centerY = portraitHeight / 2 * (1 + kZoomRestoreChipAlignmentY);
    expect(centerY, greaterThan(portraitHeight / 2));
    expect(centerY - 22, greaterThan(0)); // 22 = 胶囊半高（约 44 高）
    expect(centerY + 22, lessThan(portraitHeight));
  });
}

void _noop() {}
