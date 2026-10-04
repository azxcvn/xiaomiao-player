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

    test('af 滤镜失败**不算**音轨放不出来（否则会把用户选的轨切走）', () {
      expect(
        isAudioPlaybackFailureLog('cplayer', 'Audio filter initialized failed.'),
        isFalse,
      );
      expect(
        isAudioPlaybackFailureLog(
          'cplayer',
          "Option af: item 'dynaudnorm' isn't supported.",
        ),
        isFalse,
      );
    });
  });

  group('音频滤镜失败日志（内核缺滤镜 → 整段无声的兜底）', () {
    test('「Audio filter initialized failed.」→ 命中（lavfi 图建不起来）', () {
      expect(
        isAudioFilterFailureLog('cplayer', 'Audio filter initialized failed.'),
        isTrue,
      );
      expect(
        isAudioFilterFailureLog('af', '  audio filter initialized failed  '),
        isTrue,
      );
    });

    test("「Option af: item 'xxx' isn't supported.」→ 命中（滤镜名不存在）", () {
      expect(
        isAudioFilterFailureLog(
          'cplayer',
          "Option af: item 'dynaudnorm' isn't supported.",
        ),
        isTrue,
      );
      expect(
        isAudioFilterFailureLog(
          'cplayer',
          "Option af: item 'pan=[stereo|c0=c1|c1=c0]' isn't supported.",
        ),
        isTrue,
      );
    });

    test('media_kit 的属性写入失败日志 → 命中', () {
      expect(
        isAudioFilterFailureLog(
          'media_kit',
          'error: invalid parameter _setProperty(af, 4)',
        ),
        isTrue,
      );
    });

    test('别的选项/别的错误 → 不命中', () {
      expect(
        isAudioFilterFailureLog('cplayer', "Option vf: item 'x' isn't supported."),
        isFalse,
      );
      expect(isAudioFilterFailureLog('ao', 'Could not open audio device'), isFalse);
      expect(isAudioFilterFailureLog('media_kit', 'error: _command(quit)'), isFalse);
      expect(isAudioFilterFailureLog('', ''), isFalse);
    });

    test('从日志里取出出问题的滤镜名', () {
      expect(
        unsupportedAudioFilterFromLog("Option af: item 'dynaudnorm' isn't supported."),
        'dynaudnorm',
      );
      expect(
        unsupportedAudioFilterFromLog(
          "Option af: item 'pan=[stereo|c0=c1|c1=c0]' isn't supported.",
        ),
        'pan',
      );
      expect(
        unsupportedAudioFilterFromLog(
          "Option af: item '@bass:lavfi=[lowshelf=f=250:t=s:g=10]' isn't supported.",
        ),
        'lowshelf',
      );
      expect(
        unsupportedAudioFilterFromLog(
          "Option af: item 'lavfi=[acompressor=threshold=0.1:ratio=4]' isn't supported.",
        ),
        'acompressor',
      );
      expect(
        unsupportedAudioFilterFromLog('Audio filter initialized failed.'),
        isNull,
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

  group('pickTrackAfterExternalRemoval（移除外部音轨后落回内嵌轨）', () {
    const embedded1 = AudioTrack(id: '1', language: 'jpn', codec: 'flac');
    const embedded2 = AudioTrack(id: '2', language: 'chi', codec: 'aac');
    const external = AudioTrack(
      id: '3',
      codec: 'mp3',
      external: true,
      sourcePath: '/tmp/x.mp3',
    );

    test('落回导入前选中的那条内嵌轨（不是第一条）', () {
      final t = pickTrackAfterExternalRemoval(
        tracks: const [embedded1, embedded2, external],
        removedId: external.id,
        aidBeforeImport: embedded2.id,
      );
      expect(t, embedded2);
    });

    test('导入前那条已不在列表里 → 退到第一条内嵌轨', () {
      final t = pickTrackAfterExternalRemoval(
        tracks: const [embedded1, embedded2],
        removedId: external.id,
        aidBeforeImport: '99',
      );
      expect(t, embedded1);
    });

    test('没有记录（aidBeforeImport=null）→ 第一条内嵌轨', () {
      final t = pickTrackAfterExternalRemoval(
        tracks: const [embedded1, embedded2],
        removedId: external.id,
      );
      expect(t, embedded1);
    });

    test('aid 为 auto → 第一条内嵌轨', () {
      final t = pickTrackAfterExternalRemoval(
        tracks: const [embedded1, embedded2],
        removedId: external.id,
        aidBeforeImport: 'auto',
      );
      expect(t, embedded1);
    });

    test('导入前就是「关闭」→ 仍然关闭（null）', () {
      expect(
        pickTrackAfterExternalRemoval(
          tracks: const [embedded1, embedded2],
          removedId: external.id,
          aidBeforeImport: 'no',
        ),
        isNull,
      );
    });

    test('视频本来没有内嵌音轨 → null（不硬选）', () {
      expect(
        pickTrackAfterExternalRemoval(
          tracks: const [external],
          removedId: external.id,
          aidBeforeImport: embedded1.id,
        ),
        isNull,
      );
      expect(
        pickTrackAfterExternalRemoval(
          tracks: const [],
          removedId: external.id,
        ),
        isNull,
      );
    });

    test('还有别的外部音轨时不会被选中（只落内嵌轨）', () {
      const external2 = AudioTrack(
        id: '4',
        external: true,
        sourcePath: '/tmp/y.mp3',
      );
      final t = pickTrackAfterExternalRemoval(
        tracks: const [external2, embedded1],
        removedId: external.id,
      );
      expect(t, embedded1);
    });
  });
}
