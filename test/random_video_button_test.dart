import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/tree_node.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/home/folder_detail_page.dart';
import 'package:moumou/pages/home/tree_folder_page.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/random_video_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

void main() {
  const first = VideoFile(path: '/videos/first.mp4', name: 'first.mp4');
  const second = VideoFile(path: '/videos/second.mp4', name: 'second.mp4');
  const channel = MethodChannel('moumou/video_info');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('空列表禁用按钮，不触发播放', (tester) async {
    var calls = 0;
    await pumpAppZh(
      tester,
      Scaffold(
        body: RandomVideoButton(videos: const [], onSelected: (_) => calls++),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只有一个视频时播放该视频，每次点击只回调一次', (tester) async {
    final selected = <VideoFile>[];
    await pumpAppZh(
      tester,
      Scaffold(
        body: RandomVideoButton(
          videos: const [first],
          onSelected: selected.add,
        ),
      ),
    );

    await tester.tap(find.byTooltip('随机播放'));
    expect(selected, [first]);
  });

  testWidgets('多次随机选择均来自候选列表，不改动列表顺序', (tester) async {
    final selected = <VideoFile>[];
    final candidates = [first, second];
    await pumpAppZh(
      tester,
      Scaffold(
        body: RandomVideoButton(videos: candidates, onSelected: selected.add),
      ),
    );

    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byTooltip('随机播放'));
    }
    expect(selected, hasLength(30));
    expect(selected, everyElement(isIn(candidates)));
    expect(candidates, [first, second]);
  });

  testWidgets('列表目录的随机范围跟随搜索，搜索无结果时禁用', (tester) async {
    await pumpAppZh(
      tester,
      FolderDetailPage(
        title: 'videos',
        videos: const [first, second],
        viewSettings: ViewSettings(),
      ),
    );
    await tester.pumpAndSettle();

    List<VideoFile> candidates() =>
        tester.widget<RandomVideoButton>(find.byType(RandomVideoButton)).videos;
    expect(candidates(), containsAll([first, second]));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SECOND');
    await tester.pump();
    expect(candidates(), [second]);

    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump();
    expect(candidates(), isEmpty);
    final button = find.descendant(
      of: find.byType(RandomVideoButton),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
  });

  testWidgets('树状目录仅抽取当前层视频，不抽取文件夹或子目录视频', (tester) async {
    const node = TreeNode(
      name: 'videos',
      path: '/videos',
      type: TreeNodeType.folder,
      children: [
        TreeNode(
          name: 'first.mp4',
          path: '/videos/first.mp4',
          type: TreeNodeType.video,
          video: first,
        ),
        TreeNode(
          name: 'subfolder',
          path: '/videos/subfolder',
          type: TreeNodeType.folder,
          children: [
            TreeNode(
              name: 'second.mp4',
              path: '/videos/subfolder/second.mp4',
              type: TreeNodeType.video,
              video: second,
            ),
          ],
        ),
      ],
    );
    await pumpAppZh(
      tester,
      TreeFolderPage(node: node, viewSettings: ViewSettings()),
    );
    await tester.pumpAndSettle();

    List<VideoFile> candidates() =>
        tester.widget<RandomVideoButton>(find.byType(RandomVideoButton)).videos;
    expect(candidates(), [first]);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'subfolder');
    await tester.pump();
    expect(candidates(), isEmpty);

    await tester.enterText(find.byType(TextField), 'FIRST');
    await tester.pump();
    expect(candidates(), [first]);
  });
}
