import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/player_diagnostics.dart';
import 'package:moumou/utils/player_diagnostics.dart';

/// 播放诊断纯函数测试（§4.27）：
/// - 属性表 → 快照（字段映射 / 字符串数字兼容 / 缺失与非法值兜底）；
/// - 格式化（字节 / 码率 / 网速 / 秒 / 毫秒 / 帧率 / 分辨率 / 音画同步）；
/// - 健康提示（丢帧 / 渲染延迟 / 软解 / 音画不同步 / 时间戳异常）。
void main() {
  group('PlayerDiagnosticsSnapshot.fromProperties', () {
    test('字段映射齐全', () {
      final s = PlayerDiagnosticsSnapshot.fromProperties(const {
        'media-title': '测试视频.mkv',
        'file-format': 'Matroska',
        'video-codec': 'h264 (High)',
        'audio-codec-name': 'aac',
        'width': '1920',
        'height': '1080',
        'video-params/pixelformat': 'yuv420p',
        'container-fps': '23.976',
        'estimated-vf-fps': '23.98',
        'display-fps': '60.0',
        'hwdec-current': 'mediacodec-copy',
        'current-vo': 'gpu',
        'video-sync': 'audio',
        'drop-frame-count': '3',
        'decoder-frame-drop-count': '1',
        'vo-delayed-frame-count': '2',
        'vo-delayed-frame-average-ms': '18.5',
        'mistimed-frame-count': '0',
        'demuxer-cache-duration': '4.2',
        'demuxer-cache-time': '12.0',
        'cache-used': '8388608',
        'cache-speed': '1048576',
        'video-bitrate': '1420000',
        'audio-bitrate': '128000',
        'audio-params': '48000Hz stereo float',
        'avsync': '0.02',
      });
      expect(s.mediaTitle, '测试视频.mkv');
      expect(s.fileFormat, 'Matroska');
      expect(s.videoCodec, 'h264 (High)');
      expect(s.audioCodec, 'aac');
      expect(s.width, 1920);
      expect(s.height, 1080);
      expect(s.pixelFormat, 'yuv420p');
      expect(s.containerFps, closeTo(23.976, 1e-9));
      expect(s.estimatedFps, closeTo(23.98, 1e-9));
      expect(s.displayFps, 60.0);
      expect(s.hwdec, 'mediacodec-copy');
      expect(s.vo, 'gpu');
      expect(s.videoSync, 'audio');
      expect(s.droppedFrames, 3);
      expect(s.decoderDroppedFrames, 1);
      expect(s.delayedFrames, 2);
      expect(s.delayedFrameAverageMs, 18.5);
      expect(s.mistimedFrames, 0);
      expect(s.demuxerCacheDurationSec, 4.2);
      expect(s.demuxerCacheTimeSec, 12.0);
      expect(s.cacheUsedBytes, 8388608);
      expect(s.cacheSpeedBytesPerSec, 1048576);
      expect(s.videoBitrate, 1420000);
      expect(s.audioBitrate, 128000);
      expect(s.audioParams, '48000Hz stereo float');
      expect(s.avsync, 0.02);
    });

    test('数字字段兼容字符串/小数（防 String is not a subtype of num）', () {
      final s = PlayerDiagnosticsSnapshot.fromProperties(const {
        'width': '1920.0',
        'drop-frame-count': '12.0',
        'avsync': '-0.35',
      });
      expect(s.width, 1920);
      expect(s.droppedFrames, 12);
      expect(s.avsync, closeTo(-0.35, 1e-9));
    });

    test('缺失/null/空串/非法值兜底', () {
      final s = PlayerDiagnosticsSnapshot.fromProperties(const {
        'media-title': '   ',
        'width': '',
        'height': null,
        'container-fps': 'abc',
        'drop-frame-count': 'NaN',
      });
      expect(s.mediaTitle, '--');
      expect(s.width, isNull);
      expect(s.height, isNull);
      expect(s.containerFps, isNull);
      expect(s.droppedFrames, isNull);
      // 空属性表也不崩
      final empty = PlayerDiagnosticsSnapshot.fromProperties(const {});
      expect(empty.mediaTitle, '--');
      expect(empty.width, isNull);
      expect(empty.hwdec, '--');
    });
  });

  group('格式化', () {
    test('字节', () {
      expect(formatDiagnosticBytes(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticBytes(-1), kDiagnosticPlaceholder);
      expect(formatDiagnosticBytes(512), '512 B');
      expect(formatDiagnosticBytes(2048), '2.0 KB');
      expect(formatDiagnosticBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatDiagnosticBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
    });

    test('码率', () {
      expect(formatDiagnosticBitrate(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticBitrate(900), '900 b/s');
      expect(formatDiagnosticBitrate(128000), '128 kb/s');
      expect(formatDiagnosticBitrate(1420000), '1.42 Mb/s');
    });

    test('网速', () {
      expect(formatDiagnosticSpeed(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticSpeed(1024), '1.00 KB/s');
      expect(formatDiagnosticSpeed(1024 * 1024 * 2), '2.00 MB/s');
    });

    test('秒/毫秒/帧率/分辨率', () {
      expect(formatDiagnosticSeconds(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticSeconds(3.24), '3.2 s');
      expect(formatDiagnosticSeconds(125), '2 分 5 秒');
      expect(formatDiagnosticMillis(12.34), '12.3 ms');
      expect(formatDiagnosticMillis(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticFps(23.976), '23.98 fps');
      expect(formatDiagnosticFps(0), kDiagnosticPlaceholder);
      expect(formatDiagnosticFps(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticResolution(1920, 1080), '1920×1080');
      expect(formatDiagnosticResolution(null, 1080), kDiagnosticPlaceholder);
      expect(formatDiagnosticResolution(0, 1080), kDiagnosticPlaceholder);
    });

    test('音画同步正负与占位', () {
      expect(formatDiagnosticAvsync(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticAvsync(0.02), '+20 ms 音频超前');
      expect(formatDiagnosticAvsync(-0.35), '-350 ms 视频超前');
      expect(formatDiagnosticAvsync(0), '+0 ms 音频超前');
    });

    test('文本占位归一', () {
      expect(formatDiagnosticText(null), kDiagnosticPlaceholder);
      expect(formatDiagnosticText('  '), kDiagnosticPlaceholder);
      expect(formatDiagnosticText('--'), kDiagnosticPlaceholder);
      expect(formatDiagnosticText(' gpu '), 'gpu');
    });
  });

  group('diagnosticsWarnings', () {
    test('一切正常时无提示', () {
      const s = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        droppedFrames: 0,
        delayedFrameAverageMs: 5,
        avsync: 0.01,
        mistimedFrames: 0,
      );
      expect(diagnosticsWarnings(s), isEmpty);
    });

    test('丢帧 / 渲染延迟 / 软解 / 不同步 / 时间戳异常各自命中', () {
      const dropped = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        droppedFrames: 7,
      );
      expect(diagnosticsWarnings(dropped).single, contains('已丢帧 7 帧'));

      const delayed = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        delayedFrameAverageMs: 33.3,
      );
      expect(diagnosticsWarnings(delayed).single, contains('渲染延迟偏高'));

      const soft = PlayerDiagnosticsSnapshot(hwdec: 'no');
      expect(diagnosticsWarnings(soft).single, contains('软解'));

      const desync = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        avsync: -0.4,
      );
      expect(diagnosticsWarnings(desync).single, contains('音画不同步'));

      const mistimed = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        mistimedFrames: 3,
      );
      expect(diagnosticsWarnings(mistimed).single, contains('时间戳异常帧 3'));
    });

    test('多项异常按优先级全部列出', () {
      const s = PlayerDiagnosticsSnapshot(
        hwdec: 'no',
        droppedFrames: 2,
        delayedFrameAverageMs: 40,
        avsync: 0.5,
        mistimedFrames: 1,
      );
      final warnings = diagnosticsWarnings(s);
      expect(warnings.length, 5);
      expect(warnings.first, contains('已丢帧'));
      expect(warnings[1], contains('渲染延迟'));
      expect(warnings[2], contains('软解'));
      expect(warnings[3], contains('音画不同步'));
      expect(warnings[4], contains('时间戳异常'));
    });

    test('阈值边界：延迟=20ms 不告警，>20ms 告警', () {
      expect(
        diagnosticsWarnings(const PlayerDiagnosticsSnapshot(
          hwdec: 'mediacodec-copy',
          delayedFrameAverageMs: kDelayedFrameWarnMs,
        )),
        isEmpty,
      );
      expect(
        diagnosticsWarnings(const PlayerDiagnosticsSnapshot(
          hwdec: 'mediacodec-copy',
          delayedFrameAverageMs: kDelayedFrameWarnMs + 0.1,
        )),
        hasLength(1),
      );
    });

    test('属性清单覆盖关键诊断项', () {
      expect(kPlayerDiagnosticsProperties, contains('drop-frame-count'));
      expect(kPlayerDiagnosticsProperties, contains('demuxer-cache-time'));
      expect(kPlayerDiagnosticsProperties, contains('hwdec-current'));
      expect(kPlayerDiagnosticsProperties, contains('vo-delayed-frame-average-ms'));
      expect(kPlayerDiagnosticsProperties, contains('cache-speed'));
      expect(kPlayerDiagnosticsProperties, contains('avsync'));
      expect(kPlayerDiagnosticsProperties.toSet().length,
          kPlayerDiagnosticsProperties.length);
    });
  });
}
