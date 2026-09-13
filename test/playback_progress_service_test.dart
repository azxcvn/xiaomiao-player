import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/playback_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放进度服务的加载健壮性（P1-33）。
///
/// 脏数据不得让 `_loadFuture` 变成 **rejected Future** —— 一旦如此，
/// `ensureLoaded()` 会把那个坏的 Future 一直缓存下去：本次进程内每次调用都立即
/// 失败、`_loaded` 恒为 false → 进度**恢复与保存全部失效**（用户感知为
/// 「重启后恢复不了进度」且此后新进度也存不住）。
///
/// ⚠️ 本服务是单例且没有测试用重置钩子，同一文件内只会真正读盘一次，
/// 因此这里用**一个**用例走完「脏数据 → 回落空表 → 保存仍可用」整条链路。
void main() {
  test('脏 JSON：load 不抛错、回落空表，且后续 save 仍能正常落盘', () async {
    SharedPreferences.setMockInitialValues({
      'playback_progress': '{ 这不是合法 JSON',
    });
    final s = PlaybackProgressService.instance;

    // 修复前：jsonDecode 抛错 → _loadFuture 被钉死（本行直接抛）
    await s.ensureLoaded();
    expect(s.getProgress('/a.mp4'), isNull, reason: '脏数据回落空表，而不是让加载永久失败');
    await s.ensureLoaded(); // 缓存的是同一个已完成 Future，再调一次不应抛

    await s.save('/a.mp4', const Duration(seconds: 42), forcePersist: true);
    expect(s.getProgress('/a.mp4'), const Duration(seconds: 42));

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('playback_progress'),
      contains('/a.mp4'),
      reason: '加载失败后写盘链路必须仍然可用',
    );
  });

  // ── B3：「已看完」标记（EOF 写 100%，随后的退出/切集保存不得覆盖）──────
  group('markCompleted：粘性保护 + 强制落盘', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PlaybackProgressService.instance.resetForTest();
    });

    test('标记后连续的更小位置保存都被丢弃（退出 + dispose 两次保存）', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      const duration = Duration(milliseconds: 1421052);
      const lower = Duration(milliseconds: 1420352); // 时长 −700ms

      s.markCompleted('/v.mp4', duration);
      expect(s.getProgress('/v.mp4'), duration, reason: '同步写内存，立刻可见');

      // EOF 后退出路径会连续保存两次（`_exitPlayer` + `dispose`）：都不能覆盖
      await s.save('/v.mp4', lower, forcePersist: true);
      expect(s.getProgress('/v.mp4'), duration,
          reason: '否则百分比显示 100% 却判不出已看完，重进还会从片尾恢复');
      await s.save('/v.mp4', lower);
      expect(s.getProgress('/v.mp4'), duration,
          reason: '粘性：第二次保存同样不得覆盖（一次性拦截挡不住这个）');

      // 用户从头重看（releaseCompleted）后，中途进度照常写入
      s.releaseCompleted('/v.mp4');
      await s.save('/v.mp4', const Duration(minutes: 5), forcePersist: true);
      expect(s.getProgress('/v.mp4'), const Duration(minutes: 5));
    });

    test('标记强制落盘：不被 30 秒节流吞掉', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      s.markCompleted('/short.mp4', const Duration(milliseconds: 16148));
      // 等写队列排空（另一次保存会 await idle）
      await s.save('/other.mp4', const Duration(seconds: 3),
          forcePersist: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('playback_progress'), contains('16148'));
    });

    test('标记不降级：已有更大值时保留更大者', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      await s.save('/v.mp4', const Duration(minutes: 10), forcePersist: true);
      s.markCompleted('/v.mp4', const Duration(minutes: 9));
      expect(s.getProgress('/v.mp4'), const Duration(minutes: 10));
    });

    test('无标记时保存照常写入（保护不误伤普通进度）', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      await s.save('/plain.mp4', const Duration(minutes: 3),
          forcePersist: true);
      expect(s.getProgress('/plain.mp4'), const Duration(minutes: 3));
    });
  });
}
