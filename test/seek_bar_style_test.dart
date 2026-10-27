import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/seek_bar_style.dart';
import 'package:moumou/services/player_controls_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 进度条样式：存档解析 + 设置持久化（播放器设置 → 章节进度条）。
void main() {
  final settings = PlayerControlsSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings.reset();
  });

  group('SeekBarStyle 存档解析', () {
    test('三种样式的键往返一致', () {
      for (final style in SeekBarStyle.values) {
        expect(SeekBarStyle.fromStorage(style.storageKey), style);
      }
    });

    test('未知 / 空 / 非字符串一律回落经典（老版本没有这个键）', () {
      expect(SeekBarStyle.fromStorage(null), SeekBarStyle.classic);
      expect(SeekBarStyle.fromStorage(''), SeekBarStyle.classic);
      expect(SeekBarStyle.fromStorage('glow'), SeekBarStyle.classic);
      expect(SeekBarStyle.fromStorage(1), SeekBarStyle.classic);
    });
  });

  group('播放器设置里的进度条样式', () {
    test('默认经典', () async {
      await settings.ensureLoaded();
      expect(settings.seekBarStyle, SeekBarStyle.classic);
    });

    test('选中后写盘，重启（重新 load）仍是同一个样式', () async {
      await settings.setSeekBarStyle(SeekBarStyle.segmented);
      expect(settings.seekBarStyle, SeekBarStyle.segmented);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('player_controls_seek_bar_style'), 'segmented');

      // 模拟重启：reset 清空内存状态并让 ensureLoaded 重新读盘
      settings.reset();
      expect(settings.seekBarStyle, SeekBarStyle.classic);
      await settings.ensureLoaded();
      expect(settings.seekBarStyle, SeekBarStyle.segmented);
    });

    test('盘里是脏值：加载回落经典，不崩', () async {
      SharedPreferences.setMockInitialValues({
        'player_controls_seek_bar_style': 'not-a-style',
      });
      settings.reset();
      await settings.ensureLoaded();
      expect(settings.seekBarStyle, SeekBarStyle.classic);
    });

    test('切到同一个样式不重复通知', () async {
      await settings.ensureLoaded();
      var notified = 0;
      void listener() => notified++;
      settings.addListener(listener);
      addTearDown(() => settings.removeListener(listener));

      await settings.setSeekBarStyle(SeekBarStyle.classic);
      expect(notified, 0);

      await settings.setSeekBarStyle(SeekBarStyle.capsule);
      expect(notified, 1);
      expect(settings.seekBarStyle, SeekBarStyle.capsule);
    });

    test('reset 回到经典并通知', () async {
      await settings.setSeekBarStyle(SeekBarStyle.capsule);
      var notified = 0;
      void listener() => notified++;
      settings.addListener(listener);
      addTearDown(() => settings.removeListener(listener));

      settings.reset();
      expect(settings.seekBarStyle, SeekBarStyle.classic);
      expect(notified, greaterThan(0));
    });
  });
}
