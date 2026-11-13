import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/models/player_loop.dart';
import 'package:moumou/utils/playback_completion.dart';
import 'package:moumou/utils/playback_restore.dart';
import 'package:moumou/utils/video_playback.dart';

void main() {
  test('随机续播可以选择任一项，包括当前视频和已播放过的视频', () {
    for (var index = 0; index < 3; index++) {
      expect(
        nextVideoIndex(
          length: 3,
          currentIndex: 2,
          randomPlayback: true,
          random: _FixedRandom(index),
        ),
        index,
      );
    }
  });

  test('随机模式位于列表末尾仍然自动续播，不触发自动退出', () {
    final hasNext = hasNextVideo(
      length: 3,
      currentIndex: 2,
      randomPlayback: true,
    );
    expect(hasNext, isTrue);
    expect(
      resolveEndOfFileAction(
        loopMode: LoopMode.off,
        autoNext: true,
        autoExit: true,
        hasPlaylist: true,
        hasNext: hasNext,
      ),
      EndOfFileAction.playNext,
    );
  });

  test('只有一个视频时随机仍选当前项，空列表没有下一项', () {
    expect(nextVideoIndex(length: 1, currentIndex: 0, randomPlayback: true), 0);
    expect(
      nextVideoIndex(length: 0, currentIndex: -1, randomPlayback: true),
      isNull,
    );
    expect(
      hasNextVideo(length: 0, currentIndex: -1, randomPlayback: true),
      isFalse,
    );
  });

  test('普通模式仍按顺序，到末尾时没有下一项', () {
    expect(nextVideoIndex(length: 3, currentIndex: 0), 1);
    expect(nextVideoIndex(length: 3, currentIndex: 2), isNull);
    expect(nextVideoIndex(length: 3, currentIndex: -1), isNull);
  });

  test('随机模式忽略各种历史进度，包括时长未知时', () {
    for (final duration in [null, const Duration(minutes: 10)]) {
      for (final saved in [
        null,
        Duration.zero,
        const Duration(minutes: 5),
        const Duration(minutes: 10),
      ]) {
        expect(
          videoResumePosition(
            saved: saved,
            duration: duration,
            watchThreshold: 0.95,
            randomPlayback: true,
          ),
          isNull,
        );
      }
    }
  });

  test('普通播放仍恢复中途进度，并沿用已看完和起始阈值', () {
    Duration? resume(Duration saved, {Duration? duration}) =>
        videoResumePosition(
          saved: saved,
          duration: duration,
          watchThreshold: 0.95,
        );
    const duration = Duration(minutes: 10);
    expect(
      resume(const Duration(minutes: 5), duration: duration),
      const Duration(minutes: 5),
    );
    expect(resume(const Duration(seconds: 10), duration: duration), isNull);
    expect(resume(const Duration(minutes: 10), duration: duration), isNull);
    expect(resume(const Duration(minutes: 5)), const Duration(minutes: 5));
  });

  test('随机选中看了一半的视频：只从头打开，不执行历史位置 seek', () async {
    final player = _RecordingPlayer();
    final restored = await openAndRestore(
      player,
      '/videos/half-watched.mp4',
      saved: videoResumePosition(
        saved: const Duration(minutes: 5),
        duration: const Duration(minutes: 10),
        watchThreshold: 0.95,
        randomPlayback: true,
      ),
    );
    expect(restored, isFalse);
    expect(player.calls, ['open', 'play']);
  });

  test('再次抽中当前视频：先 seek 到零再 play，不重新打开和丢失字幕', () async {
    final player = _RecordingPlayer();
    await restartVideoFromBeginning(player);
    expect(player.calls, ['seek:0', 'play']);
  });
}

class _FixedRandom implements Random {
  final int value;
  _FixedRandom(this.value);

  @override
  int nextInt(int max) => value;
  @override
  bool nextBool() => value.isEven;
  @override
  double nextDouble() => 0;
}

class _RecordingPlayer implements Player {
  final calls = <String>[];

  @override
  PlayerState get state => const PlayerState(duration: Duration(minutes: 10));

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    calls.add('open');
    expect(play, isFalse);
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected player call: ${invocation.memberName}');
}
