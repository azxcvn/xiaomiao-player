import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/playback_history_entry.dart';
import 'package:moumou/services/playback_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放历史服务测试（工作.md：播放历史记录功能）：
/// 记录去重置顶、上限淘汰、删除单条、一键清空、关闭记录、
/// 时长回填、持久化恢复、损坏数据防御。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  PlaybackHistoryService newService() {
    // 单例跨测试残留：直接 new 一个同 key 的实例读同一 mock 存储
    return PlaybackHistoryService();
  }

  test('默认开启且无历史', () async {
    final s = PlaybackHistoryService();
    await s.load();
    expect(s.enabled, isTrue);
    expect(s.entries, isEmpty);
    expect(s.mostRecent, isNull);
  });

  test('记录并读回（新→旧），mostRecent 为最新', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await Future.delayed(const Duration(milliseconds: 2));
    await s.record('/b.mkv', 'b', isUrl: false);
    await s.load();
    expect(s.entries.map((e) => e.path).toList(), ['/b.mkv', '/a.mkv']);
    expect(s.mostRecent?.path, '/b.mkv');
    expect(s.entries.first.isUrl, isFalse);
  });

  test('重复播放同一路径去重并提到最前', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await Future.delayed(const Duration(milliseconds: 2));
    await s.record('/b.mkv', 'b', isUrl: false);
    await Future.delayed(const Duration(milliseconds: 2));
    await s.record('/a.mkv', 'a', isUrl: false);
    expect(s.entries.map((e) => e.path).toList(), ['/a.mkv', '/b.mkv']);
    expect(s.entries.length, 2);
  });

  test('在线链接条目 isUrl 标记正确', () async {
    final s = newService();
    await s.record('https://x.com/v.mp4', 'v', isUrl: true);
    expect(s.entries.first.isUrl, isTrue);
  });

  test('记录时带时长；重复播放保留已知时长', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false, durationMs: 12000);
    expect(s.entries.first.durationMs, 12000);
    // 第二次记录未带时长（0）：沿用旧值
    await s.record('/a.mkv', 'a', isUrl: false);
    expect(s.entries.first.durationMs, 12000);
    // 第二次带了新时长：覆盖
    await s.record('/a.mkv', 'a', isUrl: false, durationMs: 15000);
    expect(s.entries.first.durationMs, 15000);
  });

  test('时长回填（updateDuration）：条目不存在时静默', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await s.updateDuration('/a.mkv', 99000);
    expect(s.entries.first.durationMs, 99000);
    // 不存在的路径不报错、不新增
    await s.updateDuration('/nope.mkv', 1000);
    expect(s.entries.length, 1);
  });

  test('删除单条', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await s.record('/b.mkv', 'b', isUrl: false);
    await s.remove('/a.mkv');
    expect(s.entries.map((e) => e.path).toList(), ['/b.mkv']);
    // 再删不存在的：静默
    await s.remove('/a.mkv');
    expect(s.entries.length, 1);
  });

  test('一键清空', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await s.record('/b.mkv', 'b', isUrl: false);
    await s.clearAll();
    expect(s.entries, isEmpty);
    expect(s.mostRecent, isNull);
  });

  test('关闭记录后不再写入；已存历史保留', () async {
    final s = newService();
    await s.record('/a.mkv', 'a', isUrl: false);
    await s.setEnabled(false);
    expect(s.enabled, isFalse);
    await s.record('/b.mkv', 'b', isUrl: false);
    expect(s.entries.map((e) => e.path).toList(), ['/a.mkv']);
    // 关闭状态下时长回填仍可作用（不新增条目）
    await s.updateDuration('/a.mkv', 5000);
    expect(s.entries.first.durationMs, 5000);
    // 重新开启后恢复写入
    await s.setEnabled(true);
    await s.record('/b.mkv', 'b', isUrl: false);
    expect(s.entries.first.path, '/b.mkv');
  });

  test('上限淘汰最旧（500 条）', () async {
    final s = newService();
    for (var i = 1; i <= 502; i++) {
      await s.record('/v$i.mkv', 'v$i', isUrl: false);
    }
    expect(s.entries.length, 500);
    expect(s.entries.first.path, '/v502.mkv');
    expect(s.entries.last.path, '/v3.mkv');
  });

  test('持久化：新实例读取同一存储（模拟重启）', () async {
    final first = newService();
    await first.record('/a.mkv', 'a', isUrl: false, durationMs: 8000);
    await Future.delayed(const Duration(milliseconds: 2));
    await first.record('https://x.com/v.mp4', 'v', isUrl: true);
    await first.setEnabled(false);
    final second = newService();
    await second.load();
    expect(second.enabled, isFalse);
    expect(second.entries.map((e) => e.path).toList(),
        ['https://x.com/v.mp4', '/a.mkv']);
    expect(second.entries[1].durationMs, 8000);
    expect(second.entries[0].isUrl, isTrue);
  });

  test('损坏数据：防御性回退空历史且可继续写入', () async {
    SharedPreferences.setMockInitialValues({
      'playback_history_entries': 'not-a-json[',
    });
    final s = newService();
    await s.load();
    expect(s.entries, isEmpty);
    await s.record('/a.mkv', 'a', isUrl: false);
    expect(s.entries.first.path, '/a.mkv');
  });

  test('损坏条目：非法条目丢弃、合法条目保留', () async {
    SharedPreferences.setMockInitialValues({
      'playback_history_entries':
          '[{"path":"/ok.mkv","title":"ok","isUrl":false,"playedAtMs":123,"durationMs":456},'
          '{"title":"no-path"},'
          '"just-a-string",'
          '{"path":"","title":"empty"}]',
    });
    final s = newService();
    await s.load();
    expect(s.entries.length, 1);
    expect(s.entries.first.path, '/ok.mkv');
    expect(s.entries.first.durationMs, 456);
  });

  test('条目模型 toJson/fromJson 往返', () {
    final e = const PlaybackHistoryEntry(
      path: '/x.mkv',
      title: 'x',
      isUrl: false,
      playedAtMs: 777,
      durationMs: 999,
    );
    final back = PlaybackHistoryEntry.fromJson(e.toJson());
    expect(back?.path, '/x.mkv');
    expect(back?.title, 'x');
    expect(back?.isUrl, isFalse);
    expect(back?.playedAtMs, 777);
    expect(back?.durationMs, 999);
    expect(PlaybackHistoryEntry.fromJson('str'), isNull);
    expect(PlaybackHistoryEntry.fromJson(null), isNull);
  });
}
