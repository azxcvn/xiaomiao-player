import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/services/video_info_service.dart';
import 'package:moumou/widgets/video_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 视频卡片字段胶囊测试：
/// - 分辨率与帧率合并成一个标签（`1080p@23.98`）；
/// - 字幕按类型各一个标签（PGS / SRT），没有字幕轨时**不显示任何字幕标签**；
/// - 字段标签里没有图标；
/// - 媒体信息入口不在卡片上（改到长按菜单），卡片右侧不留图标。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');

  /// 原生 `getVideoBasicMetadata` 的返回
  Map<String, dynamic> basicMetadata = const {
    'frameRate': 23.976,
    'hasSubtitles': true,
    'subtitleCodec': 'PGS SRT',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerControlsSettings.instance.reset();
    PlaybackProgressService.instance.resetForTest();
    VideoInfoService.clearCache();
    basicMetadata = const {
      'frameRate': 23.976,
      'hasSubtitles': true,
      'subtitleCodec': 'PGS SRT',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getVideoBasicMetadata') return basicMetadata;
      // getVideoInfo（缩略图）/ getVideoDuration：返回 null → 占位图 / 未知
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoInfoService.clearCache();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Set<VideoField> fields, {
    String path = '/tmp/ep01.mp4',
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              VideoCard(
                video: VideoFile(
                  path: path,
                  name: 'ep01.mp4',
                  size: 512 * 1024 * 1024,
                  durationMs: 60000,
                  width: 1920,
                  height: 1080,
                  dateModified: DateTime(2026, 10, 27),
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

  testWidgets('分辨率 + 帧率合并成一个胶囊', (tester) async {
    await pumpCard(
      tester,
      {VideoField.resolution, VideoField.frameRate},
    );

    expect(find.text('1080p@23.98'), findsOneWidget);
    expect(find.text('1920x1080'), findsNothing);
    expect(find.text('23.98 fps'), findsNothing);
  });

  testWidgets('字幕按类型各一个胶囊，没有「字幕」前缀', (tester) async {
    await pumpCard(tester, {VideoField.subtitle});

    expect(find.text('PGS'), findsOneWidget);
    expect(find.text('SRT'), findsOneWidget);
    expect(find.textContaining('字幕 ·'), findsNothing);
  });

  testWidgets('没有内嵌字幕：不显示字幕胶囊（也不显示「无字幕」）', (tester) async {
    basicMetadata = const {
      'frameRate': 23.976,
      'hasSubtitles': false,
      'subtitleCodec': '',
    };
    await pumpCard(tester, {VideoField.subtitle});

    expect(find.text('无字幕'), findsNothing);
    expect(find.text('含字幕'), findsNothing);
    expect(find.textContaining('字幕检测中'), findsNothing);
    expect(find.text('PGS'), findsNothing);
  });

  testWidgets('字段胶囊里没有图标，日期照常显示', (tester) async {
    await pumpCard(
      tester,
      {
        VideoField.date,
        VideoField.resolution,
        VideoField.frameRate,
        VideoField.progress,
        VideoField.subtitle,
      },
    );

    expect(find.text('2026-10-27'), findsOneWidget);
    expect(find.text('未观看'), findsOneWidget);
    for (final icon in [
      Icons.calendar_today_outlined,
      Icons.aspect_ratio,
      Icons.speed,
      Icons.subtitles_outlined,
      Icons.hourglass_top,
      Icons.radio_button_unchecked,
    ]) {
      expect(find.byIcon(icon), findsNothing, reason: '$icon 不该出现在胶囊里');
    }
  });

  testWidgets('卡片右侧没有媒体信息图标（入口在长按菜单）', (tester) async {
    await pumpCard(tester, {VideoField.resolution});

    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('先只开部分字段、后补开帧率与字幕：标签会自动补上', (tester) async {
    // 打开页面时只需要日期/分辨率/进度（不触发元数据请求）
    await pumpCard(tester, {
      VideoField.date,
      VideoField.resolution,
      VideoField.progress,
    });
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('PGS'), findsNothing);

    // 在「排序与字段」里补开帧率 + 字幕指示器：同一棵元素树重建卡片
    await pumpCard(tester, {...VideoField.values});

    expect(find.text('1080p@23.98'), findsOneWidget);
    expect(find.text('PGS'), findsOneWidget);
    expect(find.text('SRT'), findsOneWidget);
  });

  testWidgets('快速解析回空：自动用完整媒体信息补上帧率与字幕类型', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      // 快速解析超时 / 原生缓存里留着零结果 → 回空
      if (call.method == 'getVideoBasicMetadata') return <String, dynamic>{};
      if (call.method == 'getMediaInfo') {
        return {
          'videoStreams': [
            {'frameRate': '23.976 (24000/1001) FPS'},
          ],
          'textStreams': [
            {'codecId': 'S_HDMV/PGS', 'format': 'PGS'},
            {'codecId': 'S_TEXT/UTF8', 'format': 'SubRip'},
          ],
        };
      }
      return null;
    });

    await pumpCard(tester, {...VideoField.values});

    expect(find.text('1080p@23.98'), findsOneWidget);
    expect(find.text('PGS'), findsOneWidget);
    expect(find.text('SRT'), findsOneWidget);
  });

  testWidgets('字幕类型很多：胶囊往下换行堆叠，卡片跟着变高、不溢出', (tester) async {
    // 只有一种字幕类型
    basicMetadata = const {
      'frameRate': 23.976,
      'hasSubtitles': true,
      'subtitleCodec': 'SRT',
    };
    await pumpCard(tester, {...VideoField.values});
    final singleRowHeight = tester.getSize(find.byType(VideoCard)).height;

    // 多种字幕类型（原生按去重后的编码串返回，一张卡最多出现这几种）
    VideoInfoService.clearCache();
    basicMetadata = const {
      'frameRate': 23.976,
      'hasSubtitles': true,
      'subtitleCodec': 'PGS SRT ASS SSA DVD VTT TX3G',
    };
    await pumpCard(tester, {...VideoField.values}, path: '/tmp/ep02.mp4');

    const labels = ['PGS', 'SRT', 'ASS', 'SSA', 'DVD', 'VTT', 'TX3G'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: '$label 胶囊没显示');
    }
    // 换行了：这些胶囊至少分布在两个不同的纵坐标上
    final rows = {
      for (final label in labels) tester.getCenter(find.text(label)).dy,
    };
    expect(rows.length, greaterThan(1), reason: '胶囊应自动换行而不是挤在一行里');
    // 卡片高度随标签行数变高（没有被裁掉）
    final multiRowHeight = tester.getSize(find.byType(VideoCard)).height;
    expect(multiRowHeight, greaterThan(singleRowHeight));
    expect(tester.takeException(), isNull);
  });
}
