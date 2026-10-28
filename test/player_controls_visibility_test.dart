import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/player_controls_visibility.dart';

/// 暂停时呼出控制层的判定（横竖屏两页共用）。
///
/// 关键场景：mpv 开 keep-open 播完时会先置 pause、再置 eof-reached，暂停事件
/// 可能先到（此刻 completed 还是 false）——只靠 completed 判断会让单集循环
/// 每放完一遍都闪一次控制层。位置到结尾同样视为「播完引起的暂停」。
void main() {
  group('isNearPlaybackEnd', () {
    test('位置到时长（1 秒容差内）算到结尾', () {
      expect(
        isNearPlaybackEnd(const Duration(seconds: 60), const Duration(seconds: 60)),
        isTrue,
      );
      expect(
        isNearPlaybackEnd(const Duration(seconds: 59), const Duration(seconds: 60)),
        isTrue,
      );
      expect(
        isNearPlaybackEnd(
          const Duration(seconds: 58),
          const Duration(seconds: 60),
        ),
        isFalse,
      );
    });

    test('时长未知不算到结尾', () {
      expect(isNearPlaybackEnd(const Duration(seconds: 10), Duration.zero), isFalse);
    });
  });

  group('shouldRevealControlsOnPause', () {
    test('普通暂停照常呼出控制层', () {
      expect(
        shouldRevealControlsOnPause(
          completed: false,
          atEnd: false,
          suppressed: false,
        ),
        isTrue,
      );
    });

    test('播到结尾（按位置判定）不呼出控制层', () {
      expect(
        shouldRevealControlsOnPause(
          completed: false,
          atEnd: true,
          suppressed: false,
        ),
        isFalse,
      );
    });

    test('completed 已置位时不呼出控制层', () {
      expect(
        shouldRevealControlsOnPause(
          completed: true,
          atEnd: false,
          suppressed: false,
        ),
        isFalse,
      );
    });

    test('双击暂停的抑制标志同样不呼出', () {
      expect(
        shouldRevealControlsOnPause(
          completed: false,
          atEnd: false,
          suppressed: true,
        ),
        isFalse,
      );
    });
  });
}
