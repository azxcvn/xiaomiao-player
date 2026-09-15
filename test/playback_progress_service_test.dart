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
      expect(
        s.getProgress('/v.mp4'),
        duration,
        reason: '否则百分比显示 100% 却判不出已看完，重进还会从片尾恢复',
      );
      await s.save('/v.mp4', lower);
      expect(
        s.getProgress('/v.mp4'),
        duration,
        reason: '粘性：第二次保存同样不得覆盖（一次性拦截挡不住这个）',
      );

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
      await s.save(
        '/other.mp4',
        const Duration(seconds: 3),
        forcePersist: true,
      );

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
      await s.save(
        '/plain.mp4',
        const Duration(minutes: 3),
        forcePersist: true,
      );
      expect(s.getProgress('/plain.mp4'), const Duration(minutes: 3));
    });
  });

  // ── 删除进度（历史记录页「删除历史时清除进度」级联调用）────────────
  group('removeProgress / clearAllProgress：删除而非仅隐藏', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PlaybackProgressService.instance.resetForTest();
    });

    test('removeProgress 清内存、粘性标记与磁盘（不走 30 秒节流）', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      await s.save('/a.mp4', const Duration(minutes: 10), forcePersist: true);
      await s.save('/b.mp4', const Duration(minutes: 20), forcePersist: true);

      s.removeProgress('/a.mp4');
      await s.flushPendingWrites();

      expect(s.getProgress('/a.mp4'), isNull, reason: '该条进度必须真的没了');
      expect(
        s.getProgress('/b.mp4'),
        const Duration(minutes: 20),
        reason: '只删指定的一条，其余不受影响',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('playback_progress') ?? '';
      expect(raw, isNot(contains('/a.mp4')), reason: '磁盘上也要删掉（非仅内存）');
      expect(raw, contains('/b.mp4'));
    });

    test('removeProgress 连「已看完」粘性一起清（否则重播会存不住进度）', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      const video = '/done.mp4';
      const duration = Duration(milliseconds: 600000);
      s.markCompleted(video, duration);
      expect(s.getProgress(video), duration);
      await s.flushPendingWrites();

      s.removeProgress(video);
      await s.flushPendingWrites();
      expect(s.getProgress(video), isNull);

      // 关键：粘性若残留，这次更小的保存会被静默丢弃（用户「删了进度却存不上新的」）
      await s.save(video, const Duration(minutes: 1), forcePersist: true);
      expect(
        s.getProgress(video),
        const Duration(minutes: 1),
        reason: '删除后重新播放，进度必须能正常记录',
      );
    });

    test('removeProgress 不存在的路径：幂等、不抛错', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      s.removeProgress('/never-played.mp4');
      await s.flushPendingWrites();
      expect(s.getProgress('/never-played.mp4'), isNull);
    });

    test('clearAllProgress 清空全部并落盘', () async {
      final s = PlaybackProgressService.instance;
      await s.ensureLoaded();
      await s.save('/a.mp4', const Duration(minutes: 1), forcePersist: true);
      await s.save('/b.mp4', const Duration(minutes: 2), forcePersist: true);

      s.clearAllProgress();
      await s.flushPendingWrites();

      expect(s.getProgress('/a.mp4'), isNull);
      expect(s.getProgress('/b.mp4'), isNull);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('playback_progress');
      // 空表落盘为 '{}'（不是残留旧快照）
      expect(raw == null || raw == '{}', isTrue, reason: '磁盘上不得残留被清掉的进度');
    });

    test('未加载时调用：先补加载再删（不会被 load 覆盖回来）', () async {
      SharedPreferences.setMockInitialValues({
        'playback_progress': '{"x.mp4":123456}',
      });
      final s = PlaybackProgressService.instance;
      // 故意不 ensureLoaded，直接调删除（removeProgress 应自己补加载）
      s.removeProgress('/x.mp4');
      await s.flushPendingWrites();

      expect(
        s.getProgress('/x.mp4'),
        isNull,
        reason: '若先删后 load，load 的 _cache=decode(...) 会把删除覆盖回来',
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('playback_progress') ?? '';
      expect(raw, isNot(contains('/x.mp4')));
    });
  });
}
