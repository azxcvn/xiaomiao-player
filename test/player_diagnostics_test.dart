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
        'audio-codec-name': 'aac',
        'width': '1920',
        'height': '1080',
        'video-params/pixelformat': 'yuv420p',
        'container-fps': '23.976',
        'estimated-vf-fps': '23.98',
        'hwdec-current': 'mediacodec-copy',
        'current-vo': 'gpu-next',
        'current-gpu-context': 'androidvk',
        'video-sync': 'audio',
        // ⚠️ 真名是 frame-drop-count（drop-frame-count 在 mpv 中不存在）
        'frame-drop-count': '3',
        'decoder-frame-drop-count': '1',
        'vo-delayed-frame-count': '2',
        'demuxer-cache-duration': '4.2',
        'demuxer-cache-time': '12.0',
        // ⚠️ 缓存字节数取自 demuxer-cache-state 的**整表 JSON**（子属性路径不可用）
        'demuxer-cache-state':
            '{"fw-bytes":8388608,"total-bytes":12800000}',
        'cache-speed': '1048576',
        'video-bitrate': '1420000',
        'audio-bitrate': '128000',
        'audio-params': '48000Hz stereo float',
        'avsync': '0.02',
      });
      expect(s.mediaTitle, '测试视频.mkv');
      expect(s.fileFormat, 'Matroska');
      expect(s.audioCodec, 'aac');
      expect(s.width, 1920);
      expect(s.height, 1080);
      expect(s.pixelFormat, 'yuv420p');
      expect(s.containerFps, closeTo(23.976, 1e-9));
      expect(s.estimatedFps, closeTo(23.98, 1e-9));
      expect(s.hwdec, 'mediacodec-copy');
      expect(s.vo, 'gpu-next');
      expect(s.gpuContext, 'androidvk');
      expect(s.videoSync, 'audio');
      expect(s.droppedFrames, 3);
      expect(s.decoderDroppedFrames, 1);
      expect(s.delayedFrames, 2);
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
        'frame-drop-count': '12.0',
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
        'frame-drop-count': 'NaN',
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
      expect(empty.gpuContext, '--');
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

    test('视频输出拼接实际图形后端（判断 Vulkan 是否真的生效）', () {
      // 两者都有：`vo · 后端`
      expect(formatVideoOutput('gpu-next', 'androidvk'), 'gpu-next · androidvk');
      expect(formatVideoOutput('gpu-next', 'android'), 'gpu-next · android');
      expect(formatVideoOutput('gpu', 'android'), 'gpu · android');
      // 缺一个时只显示可用的那个（不出现 `gpu-next · —` 半截值）
      expect(formatVideoOutput('gpu-next', null), 'gpu-next');
      expect(formatVideoOutput('gpu-next', '--'), 'gpu-next');
      expect(formatVideoOutput(null, 'androidvk'), 'androidvk');
      // 都缺 → 占位符
      expect(formatVideoOutput(null, null), kDiagnosticPlaceholder);
      expect(formatVideoOutput('--', '--'), kDiagnosticPlaceholder);
    });
  });

  group('diagnosticsWarnings', () {
    test('一切正常时无提示', () {
      const s = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        droppedFrames: 0,
        avsync: 0.01,
      );
      expect(diagnosticsWarnings(s), isEmpty);
    });

    test('丢帧 / 软解 / 音画不同步各自命中', () {
      const dropped = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        droppedFrames: 7,
      );
      expect(diagnosticsWarnings(dropped).single, contains('已丢帧 7 帧'));

      const soft = PlayerDiagnosticsSnapshot(hwdec: 'no');
      expect(diagnosticsWarnings(soft).single, contains('软解'));

      const desync = PlayerDiagnosticsSnapshot(
        hwdec: 'mediacodec-copy',
        avsync: -0.4,
      );
      expect(diagnosticsWarnings(desync).single, contains('音画不同步'));
    });

    test('多项异常按优先级全部列出', () {
      const s = PlayerDiagnosticsSnapshot(
        hwdec: 'no',
        droppedFrames: 2,
        avsync: 0.5,
      );
      final warnings = diagnosticsWarnings(s);
      expect(warnings.length, 3);
      expect(warnings.first, contains('已丢帧'));
      expect(warnings[1], contains('软解'));
      expect(warnings[2], contains('音画不同步'));
    });

    test('属性清单覆盖关键诊断项', () {
      expect(kPlayerDiagnosticsProperties, contains('frame-drop-count'));
      expect(kPlayerDiagnosticsProperties, contains('demuxer-cache-time'));
      expect(kPlayerDiagnosticsProperties, contains('hwdec-current'));
      expect(kPlayerDiagnosticsProperties, contains('current-gpu-context'));
      expect(kPlayerDiagnosticsProperties, contains('demuxer-cache-state'));
      expect(kPlayerDiagnosticsProperties, contains('cache-speed'));
      expect(kPlayerDiagnosticsProperties, contains('avsync'));
      expect(kPlayerDiagnosticsProperties.toSet().length,
          kPlayerDiagnosticsProperties.length);
    });

    test('属性清单不含 mpv 中不存在的历史错误名', () {
      // 这三个名字是历史 bug：写错永远读到空值（libmpv 属性表里没有）
      expect(kPlayerDiagnosticsProperties, isNot(contains('drop-frame-count')));
      expect(kPlayerDiagnosticsProperties, isNot(contains('cache-used')));
      expect(
        kPlayerDiagnosticsProperties,
        isNot(contains('vo-delayed-frame-average-ms')),
      );
    });

    test('属性清单不含真机实测永远读不到的字段', () {
      // 这四项已按实测定论移除（Android 纹理输出/MediaCodec 路径下恒为空）
      expect(kPlayerDiagnosticsProperties, isNot(contains('video-codec')));
      expect(kPlayerDiagnosticsProperties, isNot(contains('display-fps')));
      expect(kPlayerDiagnosticsProperties, isNot(contains('vsync-jitter')));
      expect(
        kPlayerDiagnosticsProperties,
        isNot(contains('mistimed-frame-count')),
      );
    });
  });

  group('读取容错（合并 / 失败键名）', () {
    test('isDiagnosticValueAvailable：null / 空串 / -- / 不可读哨兵 都算读不到', () {
      expect(isDiagnosticValueAvailable(null), isFalse);
      expect(isDiagnosticValueAvailable(''), isFalse);
      expect(isDiagnosticValueAvailable('   '), isFalse);
      expect(isDiagnosticValueAvailable('--'), isFalse);
      // 读取失败哨兵：必须算"读不到"，否则会污染快照与合并
      expect(isDiagnosticValueAvailable(kDiagnosticUnreadable), isFalse);
      expect(isDiagnosticValueAvailable(' h264 '), isTrue);
      expect(isDiagnosticValueAvailable('0'), isTrue);
    });

    test('不可读哨兵不覆盖上次好值、也不会透传进快照', () {
      final merged = mergeDiagnosticsRaw(
        previous: const {'width': '1920'},
        current: const {'width': kDiagnosticUnreadable},
      );
      // 保留上次好值
      expect(merged['width'], '1920');
      // 无上次值时落 null（而不是把哨兵字符串显示到面板上）
      final empty = mergeDiagnosticsRaw(
        previous: const {},
        current: const {'width': kDiagnosticUnreadable},
      );
      expect(empty['width'], isNull);
    });

    test('describeDiagnosticKeys：带原始值，区分读不到与空串', () {
      final shown = describeDiagnosticKeys(
        const {
          'pixelFormat': kDiagnosticUnreadable,
          'current-vo': '',
        },
        const ['pixelFormat', 'current-vo', 'width'],
      );
      expect(shown, contains("pixelFormat='<unreadable>'"));
      expect(shown, contains("current-vo=''"));
      expect(shown, contains('width=<missing>'));
    });

    test('缓存字节数从 demuxer-cache-state 整表 JSON 解析', () {
      // 真机实测返回的真实结构（字段名带连字符）
      const raw = '{"cache-end":116.138396,"reader-pts":15.913937,'
          '"cache-duration":100.224458,"eof":false,"underrun":false,'
          '"idle":true,"total-bytes":76388800,"fw-bytes":67109120,'
          '"raw-input-rate":912160,"bof-cached":false,"eof-cached":false}';
      // 优先取 fw-bytes（前向缓存 = 已缓冲可播部分）
      expect(parseDemuxerCacheBytes(raw), 67109120);
      // 只有 total-bytes 时退回它
      expect(
        parseDemuxerCacheBytes('{"total-bytes":123456}'),
        123456,
      );
      // 兼容下划线写法（mpv 版本差异）
      expect(parseDemuxerCacheBytes('{"fw_bytes":4096}'), 4096);
      // 小数兼容
      expect(parseDemuxerCacheBytes('{"fw-bytes":4096.0}'), 4096);
      // 解析失败 / 缺字段 / 空 → null（面板显示占位符）
      expect(parseDemuxerCacheBytes(null), isNull);
      expect(parseDemuxerCacheBytes(''), isNull);
      expect(parseDemuxerCacheBytes('not json'), isNull);
      expect(parseDemuxerCacheBytes('[]'), isNull);
      expect(parseDemuxerCacheBytes('{"eof":true}'), isNull);
    });

    test('快照从整表 JSON 取到缓存占用字节', () {
      final s = PlayerDiagnosticsSnapshot.fromProperties(const {
        'demuxer-cache-state': '{"fw-bytes":67109120,"total-bytes":76388800}',
        'demuxer-cache-duration': '100.2',
      });
      expect(s.cacheUsedBytes, 67109120);
      expect(s.demuxerCacheDurationSec, closeTo(100.2, 1e-9));
    });

    test('mergeDiagnosticsRaw：本次读不到时保留上一次的好值', () {
      final merged = mergeDiagnosticsRaw(
        previous: const {
          'width': '1920',
          'video-params/pixelformat': 'yuv420p',
        },
        current: const {'width': '1280'},
      );
      // 本次读到 → 用新值
      expect(merged['width'], '1280');
      // 本次没给（null）→ 保留上次
      expect(merged['video-params/pixelformat'], 'yuv420p');
      // 两边都没有 → null（面板显示占位符）
      expect(merged['height'], isNull);
    });

    test('mergeDiagnosticsRaw：空串与 -- 不覆盖上次的好值', () {
      final merged = mergeDiagnosticsRaw(
        previous: const {
          'estimated-vf-fps': '23.98',
          'video-params/pixelformat': 'yuv420p',
        },
        // mpv 对不可用属性返回空串；若原样采信就会抹掉好值（历史 bug）
        current: const {
          'estimated-vf-fps': '',
          'video-params/pixelformat': '--',
        },
      );
      expect(merged['estimated-vf-fps'], '23.98');
      expect(merged['video-params/pixelformat'], 'yuv420p');
    });

    test('mergeDiagnosticsRaw：只输出声明过的键（键序稳定）', () {
      final merged = mergeDiagnosticsRaw(
        previous: const {},
        current: const {'width': '1920', 'not-a-real-property': 'x'},
      );
      expect(merged.containsKey('not-a-real-property'), isFalse);
      expect(
        merged.keys.toList(),
        equals(kPlayerDiagnosticsProperties),
      );
      expect(merged['width'], '1920');
    });

    test('failedDiagnosticsKeys：列出读不到的键并排序', () {
      final failed = failedDiagnosticsKeys(
        const {
          'width': '1920',
          'video-params/pixelformat': '--',
          'height': '',
        },
      );
      // 缺失 / 空串 / -- 都算失败
      expect(failed, contains('video-params/pixelformat'));
      expect(failed, contains('height'));
      expect(failed, contains('estimated-vf-fps'));
      // 读到的键不算失败
      expect(failed, isNot(contains('width')));
      // 已排序（警示卡直接拼接展示，顺序需稳定）
      expect(failed, equals([...failed]..sort()));
    });

    test('全部可读时无失败键', () {
      final raw = <String, String?>{
        for (final key in kPlayerDiagnosticsProperties) key: '1',
      };
      expect(failedDiagnosticsKeys(raw), isEmpty);
    });

    test('别名回退机制本身可用（当前清单为空，用自定义键验证）', () {
      // 展开不破坏原有属性、且无重复
      final names = expandDiagnosticPropertyNames();
      expect(names, contains('demuxer-cache-state'));
      expect(names, contains('hwdec-current'));
      expect(names.toSet().length, names.length);

      // 无别名的属性原样取值
      expect(pickDiagnosticValue(const {'width': '1920'}, 'width'),
          {'width': '1920'});
      // 读不到 → null（面板显示占位符）
      expect(pickDiagnosticValue(const {'width': '--'}, 'width'),
          {'width': null});
    });
  });
}
