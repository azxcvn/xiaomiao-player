import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/audio_track.dart';
import 'package:moumou/services/audio_service.dart';

/// 音轨不可播放自动回退（纯函数部分）测试。
///
/// 对应真机 bug：MKV 内 Dolby TrueHD（`A_TRUEHD` / MLP FBA / 8 channels）
/// 在 Android `ao=opensles`（只支持双声道）上放不出来，切过去后完全无声，
/// 应用侧此前不消费 `Player.stream.log` → 静默失败。
void main() {
  group('isAudioPlaybackFailureLog（mpv 日志判定）', () {
    test('ao 前缀的音频输出初始化失败 → 命中', () {
      expect(
        isAudioPlaybackFailureLog(
          'ao',
          'Could not open audio device: initialize failed',
        ),
        isTrue,
      );
    });

    test('ad 前缀的解码器失败 → 命中', () {
      expect(
        isAudioPlaybackFailureLog('ad', 'Error decoding audio: Invalid data'),
        isTrue,
      );
    });

    test('TrueHD 通道布局不支持的报错 → 命中', () {
      expect(
        isAudioPlaybackFailureLog(
          'ao',
          'Audio channel layout 7.1 is not supported by the audio device',
        ),
        isTrue,
      );
    });

    test('cplayer 前缀（无可用音频输出）→ 命中', () {
      expect(
        isAudioPlaybackFailureLog('cplayer', 'Audio: no audio output found'),
        isTrue,
      );
    });

    test('视频解码/网络错误 → 不命中（避免误回退音轨）', () {
      expect(
        isAudioPlaybackFailureLog('vd', 'Error while decoding frame!'),
        isFalse,
      );
      expect(
        isAudioPlaybackFailureLog('ffmpeg', 'http: 404 Not Found'),
        isFalse,
      );
      expect(
        isAudioPlaybackFailureLog('stream', 'Failed to open stream'),
        isFalse,
      );
    });

    test('非错误级/无关日志 → 不命中', () {
      expect(isAudioPlaybackFailureLog('ao', 'Device latency is 0.010000'), isFalse);
      expect(isAudioPlaybackFailureLog('cplayer', 'Track switched'), isFalse);
      expect(isAudioPlaybackFailureLog('', ''), isFalse);
      expect(isAudioPlaybackFailureLog('ad', '   '), isFalse);
    });

    test('前缀大小写与空白容错', () {
      expect(
        isAudioPlaybackFailureLog(' AO ', 'audio device open failed'),
        isTrue,
      );
    });
  });

  group('pickFallbackAudioTrack（回退目标选择）', () {
    const trueHd = AudioTrack(
      id: '2',
      language: 'English',
      codec: 'truehd',
      channels: '7.1',
    );
    const ac3 = AudioTrack(
      id: '3',
      language: 'Chinese',
      codec: 'ac3',
      channels: '5.1',
    );
    const aac = AudioTrack(id: '4', codec: 'aac');
    const external = AudioTrack(
      id: '5',
      codec: 'truehd',
      external: true,
      sourcePath: '/tmp/x.mka',
    );

    test('优先选不同编码的轨道（TrueHD 失败 → AC-3）', () {
      final t = pickFallbackAudioTrack(
        tracks: const [trueHd, ac3],
        failed: trueHd,
        current: trueHd,
      );
      expect(t, ac3);
    });

    test('同编码的其它轨道仍然可用（只是优先级更低）', () {
      final t = pickFallbackAudioTrack(
        tracks: const [trueHd, external],
        failed: trueHd,
        current: trueHd,
      );
      expect(t, external);
    });

    test('内置轨道优先于外部（临时导入）轨道', () {
      final t = pickFallbackAudioTrack(
        tracks: const [trueHd, external, aac],
        failed: trueHd,
        current: trueHd,
      );
      expect(t, aac);
    });

    test('编码未知时不参与「不同编码」优先，仍可回退', () {
      const unknown = AudioTrack(id: '6');
      final t = pickFallbackAudioTrack(
        tracks: const [trueHd, unknown],
        failed: trueHd,
        current: trueHd,
      );
      expect(t, unknown);
    });

    test('只有当前这一条 → 无处可退返回 null', () {
      expect(
        pickFallbackAudioTrack(
          tracks: const [trueHd],
          failed: trueHd,
          current: trueHd,
        ),
        isNull,
      );
      expect(
        pickFallbackAudioTrack(tracks: const [], failed: trueHd, current: trueHd),
        isNull,
      );
    });

    test('失败项未知（failed=null）时只要能避开当前项即可回退', () {
      final t = pickFallbackAudioTrack(
        tracks: const [trueHd, ac3],
        failed: null,
        current: trueHd,
      );
      expect(t, ac3);
    });
  });
}
