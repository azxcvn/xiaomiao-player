import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/video_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 视频卡片「完整名称」字段测试（用户反馈：列表里标题显示不全）：
/// 选中该字段时标题不截断（不限行数、整名换行，卡片高度随标题行数变化）；
/// 未选中时维持原来的「最多 2 行 + 省略号」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 足够长的标题：窄视口下远超 2 行，才能验证「换行后卡片变高」
  final longName = '超长视频标题' * 12;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerControlsSettings.instance.reset();
    PlaybackProgressService.instance.resetForTest();
    // 原生视频信息通道 mock（缩略图请求；返回 null → 占位图）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('moumou/video_info'), (
          call,
        ) async {
          return null;
        });
  });

  Future<void> pumpCard(WidgetTester tester, Set<VideoField> fields) async {
    // 窄视口：让长标题在「2 行省略」下必然被截断
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // 列表里用卡片（ListView 给子项松高度约束）：卡片按内容取自身高度，
          // 与真实列表一致——这样才能断言「卡片高度随标题行数变化」
          body: ListView(
            children: [
              VideoCard(
                video: VideoFile(
                  path: '/tmp/$longName.mp4',
                  name: longName,
                  size: 1024 * 1024,
                  durationMs: 60000,
                ),
                fields: fields,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Text nameText(WidgetTester tester) =>
      tester.widget<Text>(find.text(longName));

  testWidgets('选中完整名称：标题不限行数、整名换行、不省略', (tester) async {
    await pumpCard(tester, {VideoField.size, VideoField.fullName});

    final text = nameText(tester);
    expect(text.maxLines, isNull, reason: '不能限制行数');
    expect(text.overflow, isNot(TextOverflow.ellipsis), reason: '不能省略');
    // 整名完整渲染（Text 的渲染宽度没有溢出裁剪）
    expect(tester.takeException(), isNull);
  });

  testWidgets('未选中完整名称：维持 2 行 + 省略号', (tester) async {
    await pumpCard(tester, {VideoField.size});

    final text = nameText(tester);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('选中后卡片变高（高度随标题行数动态变化）', (tester) async {
    await pumpCard(tester, {VideoField.size});
    final truncatedCard = tester.getSize(find.byType(VideoCard)).height;
    final truncatedName = tester.getSize(find.text(longName)).height;

    await pumpCard(tester, {VideoField.size, VideoField.fullName});
    final wrappedCard = tester.getSize(find.byType(VideoCard)).height;
    final wrappedName = tester.getSize(find.text(longName)).height;

    expect(
      wrappedName,
      greaterThan(truncatedName),
      reason: '完整名称要换行显示，标题占的行数必须变多',
    );
    expect(
      wrappedCard,
      greaterThan(truncatedCard),
      reason: '卡片高度随标题行数变高',
    );
  });
}
