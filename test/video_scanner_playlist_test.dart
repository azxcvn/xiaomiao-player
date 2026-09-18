import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/media_scan_settings.dart';
import 'package:moumou/services/video_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「按视频路径补全同目录兄弟列表」的测试（bug：从首页速拨「最近播放」进入
/// 播放页时入口没传 playlist → 播放列表面板里看不到当前视频所在文件夹的
/// 其他视频，只显示「当前文件夹没有其他视频」）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');

  /// mock MediaStore：`getVideos` 返回 [paths] 对应的视频
  void mockVideos(List<String> paths) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'getVideos') return null;
          return [
            for (final p in paths)
              {
                'path': p,
                'name': p.split('/').last,
                'durationMs': 60000,
                'size': 1024,
                'width': 1920,
                'height': 1080,
                'dateModifiedMs': 1700000000000,
              },
          ];
        });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MediaScanSettings.instance.reset();
    VideoScanner.clearCache();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    VideoScanner.clearCache();
  });

  test('返回当前视频所在文件夹的全部视频，按名称自然序升序', () async {
    mockVideos([
      '/storage/emulated/0/Movies/Show/10.mp4',
      '/storage/emulated/0/Movies/Show/2.mp4',
      '/storage/emulated/0/Movies/Show/1.mp4',
      '/storage/emulated/0/Movies/Show/3.mp4',
      '/storage/emulated/0/Movies/Show/4.mp4',
      // 其他文件夹的视频不得混入
      '/storage/emulated/0/Movies/Other/9.mp4',
      '/storage/emulated/0/Movies/Show/Sub/5.mp4',
    ]);

    final siblings = await VideoScanner.folderSiblingsOf(
      '/storage/emulated/0/Movies/Show/3.mp4',
    );

    expect(
      siblings.map((v) => v.name),
      // 自然序（数字感知）：1、2、3、4、10，而不是 1、10、2、3、4
      ['1.mp4', '2.mp4', '3.mp4', '4.mp4', '10.mp4'],
    );
    // 兄弟列表必须含当前视频：播放列表面板与「下一集」按它定位当前项
    expect(siblings.any((v) => v.path.endsWith('/Show/3.mp4')), isTrue);
  });

  test('在线直链 / 本机代理流没有同目录兄弟列表，且不查媒体库', () async {
    var queried = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          queried = true;
          return [];
        });

    expect(
      await VideoScanner.folderSiblingsOf('https://example.com/a.mp4'),
      isEmpty,
    );
    expect(
      await VideoScanner.folderSiblingsOf('http://127.0.0.1:9000/proxy/x.m3u8'),
      isEmpty,
    );
    expect(queried, isFalse);
  });

  test('媒体库不可用时抛出，由调用方（播放页）兜住不打断播放', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'error', message: 'channel down');
        });

    expect(
      () => VideoScanner.folderSiblingsOf('/storage/emulated/0/Movies/Show/1.mp4'),
      throwsA(isA<PlatformException>()),
    );
  });
}
