import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/subtitle_memory.dart';

/// 外挂字幕「记忆路径」失效清理测试（B5 / P1-9）。
///
/// 回归场景：用户删掉/改名前次自动加载或手动导入的外挂字幕 → 记忆里的死路径
/// 让 `sub-add` 静默失败，而「记忆非空即跳过同名扫描」又让该视频**永久**没有
/// 字幕。清理规则：失效项一律剔除（由调用方从设置里删除），有效项保持原顺序。
void main() {
  SubtitleMemoryPartition run(List<String> paths, Set<String> existing) {
    return partitionSubtitleMemoryPaths(
      paths,
      exists: existing.contains,
    );
  }

  test('全部存在：无失效项，顺序保持', () {
    final r = run(['/a.srt', '/b.ass'], {'/a.srt', '/b.ass'});
    expect(r.valid, ['/a.srt', '/b.ass']);
    expect(r.stale, isEmpty);
  });

  test('部分失效：失效项进 stale，有效项保留', () {
    final r = run(['/a.srt', '/gone.ass', '/b.srt'], {'/a.srt', '/b.srt'});
    expect(r.valid, ['/a.srt', '/b.srt']);
    expect(r.stale, ['/gone.ass']);
  });

  test('全部失效：valid 为空（调用方据此回落同名扫描）', () {
    final r = run(['/gone.srt', '/also-gone.ass'], <String>{});
    expect(r.valid, isEmpty);
    expect(r.stale, ['/gone.srt', '/also-gone.ass']);
  });

  test('空列表：两边都为空', () {
    final r = run(const [], {'/a.srt'});
    expect(r.valid, isEmpty);
    expect(r.stale, isEmpty);
  });

  test('去重保留首次出现顺序，重复项不会被当成失效项再删一次', () {
    final r = run(['/a.srt', '/a.srt', '/b.ass'], {'/a.srt'});
    expect(r.valid, ['/a.srt']);
    expect(r.stale, ['/b.ass']);
  });

  test('空字符串忽略（历史脏数据）', () {
    final r = run(['', '/a.srt'], {'/a.srt'});
    expect(r.valid, ['/a.srt']);
    expect(r.stale, isEmpty);
  });

  test('失效路径不会出现在 valid 里（防「校验不严继续 sub-add 死路径」）', () {
    final r = run(['/gone.srt'], <String>{});
    expect(r.valid.contains('/gone.srt'), isFalse);
    expect(r.stale, contains('/gone.srt'));
  });
}
