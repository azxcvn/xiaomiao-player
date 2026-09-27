import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/audio_track.dart';
import 'package:moumou/services/audio_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 音频声道 / 音频处理设置测试（用户反馈：选好的声道与音频处理，退出播放
/// 再进就回到默认）：默认值、持久化回读、旧数据容错与通知次数。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioSettings.instance.reset();
  });

  final s = AudioSettings.instance;

  test('默认值：安全自动 / 音量标准化关 / 动态范围压缩关', () {
    expect(s.channels, AudioChannels.autoSafe);
    expect(s.volumeNormalization, isFalse);
    expect(s.drc, isFalse);
  });

  test('声道持久化（模拟重启 load）', () async {
    await s.setChannels(AudioChannels.reverseStereo);
    expect(s.channels, AudioChannels.reverseStereo);

    await s.load();
    expect(s.channels, AudioChannels.reverseStereo);
  });

  test('音频处理两项持久化（模拟重启 load）', () async {
    await s.setVolumeNormalization(true);
    await s.setDrc(true);

    await s.load();
    expect(s.volumeNormalization, isTrue);
    expect(s.drc, isTrue);
  });

  test('每次变更通知监听者（控制器据此重应用 mpv），同值不重复通知', () async {
    // 先完成首次读盘：load 自身也会通知一次，不混进下面的计数
    await s.ensureLoaded();
    var notified = 0;
    void listener() => notified++;
    s.addListener(listener);
    addTearDown(() => s.removeListener(listener));

    await s.setChannels(AudioChannels.mono);
    await s.setVolumeNormalization(true);
    await s.setDrc(true);
    expect(notified, 3);

    // 同值再设一次：不重复通知（也就不会重复下发 mpv 属性）
    await s.setChannels(AudioChannels.mono);
    await s.setDrc(true);
    expect(notified, 3);
  });

  test('旧数据里的未知声道名 → 回落安全自动', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_channels', 'removed_channel');

    await s.load();
    expect(s.channels, AudioChannels.autoSafe);
  });

  test('reset 恢复默认（测试间不串状态）', () async {
    await s.setChannels(AudioChannels.stereo);
    await s.setVolumeNormalization(true);
    await s.setDrc(true);

    s.reset();
    expect(s.channels, AudioChannels.autoSafe);
    expect(s.volumeNormalization, isFalse);
    expect(s.drc, isFalse);
  });
}
