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
}
