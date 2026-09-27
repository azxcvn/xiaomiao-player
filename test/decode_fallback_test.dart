import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/decode_fallback.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 解码档位自动回退测试（用户需求：默认「硬解+」，设备不支持时自动回退
/// 硬解 / 软解，并让用户看得见）：
/// - `hwdec-current` → 实际生效档的归一（只认精确值，读不准不参与判定）；
/// - 回退目标判定（只降不升、自动/软解不参与）；
/// - 设备能力表判定（整机没有任何硬解器才算「不支持硬解」）；
/// - 编排：降档写设置 + 返回提示文案；读不到一律不动。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settings = DecodeSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetDecodeFallbackHints();
    await settings.ensureLoaded();
  });

  tearDown(resetDecodeFallbackHints);

  group('effectiveDecodeFromHwdec（mpv 实际生效档归一）', () {
    test('精确值 → 对应档位', () {
      expect(effectiveDecodeFromHwdec('mediacodec'), DecodeMode.hwPlus);
      expect(effectiveDecodeFromHwdec('mediacodec-copy'), DecodeMode.hwCopy);
      expect(effectiveDecodeFromHwdec('no'), DecodeMode.sw);
    });

    test('大小写与空白容错', () {
      expect(effectiveDecodeFromHwdec(' MediaCodec-Copy '), DecodeMode.hwCopy);
      expect(effectiveDecodeFromHwdec('NO'), DecodeMode.sw);
    });

    test('读不到 / 不认识 → null（绝不猜）', () {
      expect(effectiveDecodeFromHwdec(null), isNull);
      expect(effectiveDecodeFromHwdec(''), isNull);
      expect(effectiveDecodeFromHwdec('   '), isNull);
      // mpv 若把请求串原样回读，不参与判定（否则会被误当成某档）
      expect(
        effectiveDecodeFromHwdec('mediacodec,mediacodec-copy,no'),
        isNull,
      );
      expect(effectiveDecodeFromHwdec('auto-safe'), isNull);
    });
  });

  group('decodeFallbackTarget（回退目标）', () {
    test('硬解+ 直通失败落到拷贝 → 回退硬解', () {
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwPlus,
          effective: DecodeMode.hwCopy,
        ),
        DecodeMode.hwCopy,
      );
    });

    test('硬解+ / 硬解 都没起来 → 回退软解', () {
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwPlus,
          effective: DecodeMode.sw,
        ),
        DecodeMode.sw,
      );
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwCopy,
          effective: DecodeMode.sw,
        ),
        DecodeMode.sw,
      );
    });

    test('实际档不低于所选档 → 不回退', () {
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwPlus,
          effective: DecodeMode.hwPlus,
        ),
        isNull,
      );
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwCopy,
          effective: DecodeMode.hwCopy,
        ),
        isNull,
      );
      // 实际是直通、用户选的是硬解：也不动（不替用户升档）
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwCopy,
          effective: DecodeMode.hwPlus,
        ),
        isNull,
      );
    });

    test('自动 / 软解不参与回退；读不到不回退', () {
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.autoSafe,
          effective: DecodeMode.sw,
        ),
        isNull,
      );
      expect(
        decodeFallbackTarget(requested: DecodeMode.sw, effective: DecodeMode.sw),
        isNull,
      );
      expect(
        decodeFallbackTarget(
          requested: DecodeMode.hwPlus,
          effective: null,
        ),
        isNull,
      );
    });
  });

  group('deviceHasNoHardwareVideoDecoder（设备能力表）', () {
    Map<String, dynamic> caps({required bool anyHardware}) => {
          'keyCodecs': [
            {'formatName': 'H.264 / AVC', 'hasHardware': anyHardware},
            {'formatName': 'H.265 / HEVC', 'hasHardware': false},
          ],
        };

    test('关键编码器全无硬解 → true（设备不支持硬解）', () {
      expect(deviceHasNoHardwareVideoDecoder(caps(anyHardware: false)), isTrue);
    });

    test('有任一编码有硬解 → false', () {
      expect(deviceHasNoHardwareVideoDecoder(caps(anyHardware: true)), isFalse);
    });

    test('能力表缺失 / 结构异常 → null（不知道，不当成不支持）', () {
      expect(deviceHasNoHardwareVideoDecoder(null), isNull);
      expect(deviceHasNoHardwareVideoDecoder(const {}), isNull);
      expect(
        deviceHasNoHardwareVideoDecoder(const {'keyCodecs': []}),
        isNull,
      );
      expect(
        deviceHasNoHardwareVideoDecoder(const {'keyCodecs': 'bad'}),
        isNull,
      );
    });
  });

  group('autoFallbackDecodeMode（编排）', () {
    /// 造一个假的 mpv 属性读取：只认 `hwdec-current`
    Future<String?> Function(String) reader(
      String? hwdecCurrent, {
      bool throwOnRead = false,
    }) =>
        (name) async {
          if (throwOnRead) throw StateError('mpv 不可用');
          return name == 'hwdec-current' ? hwdecCurrent : '';
        };

    test('硬解+ 只落到拷贝 → 设置回退为硬解并提示', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('mediacodec-copy'),
        retryDelay: Duration.zero,
      );

      expect(settings.mode, DecodeMode.hwCopy);
      expect(message, kDecodeFallbackHwCopyMessage);
    });

    test('硬解+ 完全没起来 + 设备整机无硬解 → 设置回退为软解并提示', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => true,
        retryDelay: Duration.zero,
      );

      expect(settings.mode, DecodeMode.sw);
      expect(message, kDecodeFallbackSwMessage);
    });

    test('硬解+ 完全没起来、但设备有硬解（只是这个编码没硬解）→ 只提示、不改设置',
        () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => false,
        retryDelay: Duration.zero,
      );

      expect(settings.mode, DecodeMode.hwPlus, reason: '不能因为一个编码把整机降到软解');
      expect(message, kDecodeFallbackPerVideoMessage);
    });

    test('只能软解的提示每次 App 运行只提示一次', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final first = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => false,
        retryDelay: Duration.zero,
      );
      final second = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => false,
        retryDelay: Duration.zero,
      );

      expect(first, kDecodeFallbackPerVideoMessage);
      expect(second, isNull);
    });

    test('能力表查不到（null）→ 保守处理：只提示、不改设置', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => null,
        retryDelay: Duration.zero,
      );

      expect(settings.mode, DecodeMode.hwPlus);
      expect(message, kDecodeFallbackPerVideoMessage);
    });

    test('实际档不低于所选档 → 不动设置也不提示', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('mediacodec'),
        retryDelay: Duration.zero,
      );

      expect(settings.mode, DecodeMode.hwPlus);
      expect(message, isNull);
    });

    test('选「自动」不判定（自动档由 mpv 挑安全档）', () async {
      await settings.setMode(DecodeMode.autoSafe);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        deviceHasNoHardwareDecoder: () async => true,
        retryDelay: Duration.zero,
        maxAttempts: 1,
      );

      expect(settings.mode, DecodeMode.autoSafe);
      expect(message, isNull);
    });

    test('读不到 / 读异常 / 不认识的值 → 一律不动（绝不猜）', () async {
      await settings.setMode(DecodeMode.hwPlus);

      for (final read in [
        reader(null),
        reader(''),
        reader('whatever'),
        reader(null, throwOnRead: true),
      ]) {
        final message = await autoFallbackDecodeMode(
          readProperty: read,
          deviceHasNoHardwareDecoder: () async => true,
          retryDelay: Duration.zero,
          maxAttempts: 2,
        );
        expect(message, isNull);
        expect(settings.mode, DecodeMode.hwPlus);
      }
    });

    test('没有视频轨（纯音频）不判定', () async {
      await settings.setMode(DecodeMode.hwPlus);

      final message = await autoFallbackDecodeMode(
        readProperty: reader('no'),
        hasVideoTrack: () => false,
        deviceHasNoHardwareDecoder: () async => true,
        retryDelay: Duration.zero,
        maxAttempts: 2,
      );

      expect(settings.mode, DecodeMode.hwPlus);
      expect(message, isNull);
    });

    test('视频轨稍后上报：等下一轮仍能判定', () async {
      await settings.setMode(DecodeMode.hwPlus);
      var attempts = 0;

      final message = await autoFallbackDecodeMode(
        readProperty: reader('mediacodec-copy'),
        hasVideoTrack: () => ++attempts > 1,
        retryDelay: Duration.zero,
        maxAttempts: 3,
      );

      expect(settings.mode, DecodeMode.hwCopy);
      expect(message, kDecodeFallbackHwCopyMessage);
    });
  });
}
