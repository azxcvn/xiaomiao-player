import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/bili_bangumi.dart';
import 'package:moumou/pages/bilibili/bili_episode_picker_page.dart';

/// 全屏选集页测试：进入页面第一页集数应直接可见（回归：切页动画控制器
/// 初始值若为 0 会把第一页整体平移到屏幕外，需先切一次页才显示）。
void main() {
  List<BiliEpisode> episodes(int n) => List.generate(
        n,
        (i) => BiliEpisode(
          epId: i + 1,
          aid: 0,
          cid: 0,
          bvid: '',
          title: '第${i + 1}话',
          longTitle: '',
          cover: '',
        ),
      );

  testWidgets('进入选集页：第一页集数直接可见，无需切页', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: BiliEpisodePickerPage(episodes: episodes(5))),
    );
    await tester.pumpAndSettle();

    // hitTestable：确认第一集磁贴实际在屏幕内（而非被平移到屏外）
    expect(find.text('第1话').hitTestable(), findsOneWidget);
    expect(find.text('第5话').hitTestable(), findsOneWidget);
  });
}
