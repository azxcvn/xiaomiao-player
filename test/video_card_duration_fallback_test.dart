import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:moumou/services/video_info_service.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/video_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_helper.dart';

/// 扫描器拿不到时长的视频（`.nomedia` / 隐藏文件夹里的条目由原生文件系统
/// 补扫得到，`durationMs` 恒为 0）在列表里的进度显示测试。
///
/// 用户反馈：这些视频播完退出后，列表里永远显示「未观看」，进度条也不出现
/// ——因为观看状态与百分比全靠时长换算（时长为 0 直接判未观看）。卡片改为
/// 按需向原生补一次时长。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const path = '/storage/emulated/0/Download/.hidden/movie.mp4';
  const channel = MethodChannel('moumou/video_info');

  /// 原生 `getVideoDuration` 的返回（0 = 拿不到）与调用次数
  var nativeDurationMs = 100000;
  var durationCalls = 0;

  setUp(() {
    // 进度 30s / 时长 100s → 观看中 30%
    SharedPreferences.setMockInitialValues({
      'playback_progress': '{"$path":30000}',
    });
    PlayerControlsSettings.instance.reset();
    PlaybackProgressService.instance.resetForTest();
    VideoInfoService.clearCache();
    nativeDurationMs = 100000;
    durationCalls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getVideoDuration') {
        durationCalls++;
        return nativeDurationMs;
      }
      // getVideoInfo（缩略图）：返回 null → 占位图
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoInfoService.clearCache();
  });

  Future<void> pumpCard(WidgetTester tester, {required int durationMs}) async {
    await PlaybackProgressService.instance.ensureLoaded();
    await tester.pumpWidget(
      MaterialApp(
        locale: kTestLocaleZh,
        localizationsDelegates: kTestLocalizationDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: VideoCard(
            video: VideoFile(
              path: path,
              name: 'movie.mp4',
              durationMs: durationMs,
            ),
            fields: {VideoField.progress, VideoField.duration},
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('扫描器时长缺失：补齐后显示百分比而不是「未观看」', (tester) async {
    await pumpCard(tester, durationMs: 0);

    expect(durationCalls, 1, reason: '时长为 0 时要向原生补一次时长');
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('未观看'), findsNothing);
  });

  testWidgets('扫描器已有时长：不再额外请求原生时长', (tester) async {
    await pumpCard(tester, durationMs: 100000);

    expect(durationCalls, 0);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('原生也拿不到时长：回落「未观看」（不崩、不永久转圈）', (tester) async {
    nativeDurationMs = 0;
    await pumpCard(tester, durationMs: 0);

    expect(durationCalls, 1);
    expect(find.text('未观看'), findsOneWidget);
  });
}
