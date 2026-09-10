import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/pinned_folders_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 固定文件夹设置服务测试（默认空 / 固定与取消 / 批量替换 / 持久化 / 损坏防御）
void main() {
  final settings = PinnedFoldersSettings.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 单例在测试进程内共享：逐用例复位内存态与加载缓存
    settings.debugReset();
  });

  test('默认：没有固定任何文件夹', () async {
    await settings.ensureLoaded();
    expect(settings.paths, isEmpty);
    expect(settings.count, 0);
    expect(settings.isPinned('/storage/emulated/0/A'), isFalse);
  });

  test('toggle：固定后 isPinned 为真且通知监听者', () async {
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.toggle('/storage/emulated/0/A');
    expect(settings.isPinned('/storage/emulated/0/A'), isTrue);
    expect(settings.count, 1);
    expect(notified, 1);

    // 再次 toggle = 取消固定
    await settings.toggle('/storage/emulated/0/A');
    expect(settings.isPinned('/storage/emulated/0/A'), isFalse);
    expect(notified, 2);
  });

  test('setPinned：幂等（重复设置同一状态不重复通知）', () async {
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.setPinned('/storage/emulated/0/A', true);
    await settings.setPinned('/storage/emulated/0/A', true);
    expect(notified, 1);

    await settings.setPinned('/storage/emulated/0/A', false);
    await settings.setPinned('/storage/emulated/0/A', false);
    expect(notified, 2);
  });

  test('空路径被忽略', () async {
    await settings.toggle('');
    await settings.setPinned('', true);
    expect(settings.paths, isEmpty);
  });

  test('setPinnedAll：一次固定多个，只通知一次', () async {
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.setPinnedAll(['/a', '/b', '/c'], pinned: true);
    expect(settings.count, 3);
    expect(notified, 1);

    // 全部已经是固定态 → 无变化，不再通知
    await settings.setPinnedAll(['/a', '/b', '/c'], pinned: true);
    expect(notified, 1);

    // 取消固定同样只通知一次
    await settings.setPinnedAll(['/a', '/b', '/c'], pinned: false);
    expect(settings.paths, isEmpty);
    expect(notified, 2);
  });

  test('setPinnedAll：部分已固定时仍按「有变化才通知」处理，空串被忽略', () async {
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.setPinned('/a', true);
    expect(notified, 1);

    await settings.setPinnedAll(['/a', '/b', ''], pinned: true);
    expect(settings.paths, {'/a', '/b'});
    expect(notified, 2);

    await settings.setPinnedAll(const [], pinned: true);
    expect(notified, 2);
  });

  test('paths 返回只读快照（外部修改会抛错，内部不受影响）', () async {
    await settings.setPinned('/storage/emulated/0/A', true);
    final snapshot = settings.paths;
    expect(() => snapshot.add('/storage/emulated/0/B'), throwsUnsupportedError);
    expect(settings.count, 1);
  });

  test('replaceAll：批量替换并通知一次', () async {
    var notified = 0;
    void listener() => notified++;
    settings.addListener(listener);
    addTearDown(() => settings.removeListener(listener));

    await settings.replaceAll(['/a', '/b', '/a']);
    expect(settings.count, 2);
    expect(notified, 1);

    // 与当前集合相同 → 不通知
    await settings.replaceAll(['/a', '/b']);
    expect(notified, 1);

    await settings.replaceAll(const []);
    expect(settings.paths, isEmpty);
    expect(notified, 2);
  });

  test('持久化：固定后写盘，冷启动（重新 ensureLoaded）能读回', () async {
    await settings.setPinned('/storage/emulated/0/A', true);
    await settings.setPinned('/storage/emulated/0/B', true);

    // 模拟重启：清空内存态 + 清掉加载缓存后再加载
    settings.debugReset();
    expect(settings.paths, isEmpty);
    await settings.ensureLoaded();

    expect(
      settings.paths,
      containsAll(['/storage/emulated/0/A', '/storage/emulated/0/B']),
    );
    expect(settings.count, 2);
  });

  test('取消固定后写盘：冷启动不再出现', () async {
    await settings.setPinned('/storage/emulated/0/A', true);
    await settings.setPinned('/storage/emulated/0/A', false);

    settings.debugReset();
    await settings.ensureLoaded();
    expect(settings.isPinned('/storage/emulated/0/A'), isFalse);
  });

  test('损坏防御：存储里的空串在加载后被过滤', () async {
    SharedPreferences.setMockInitialValues({
      'pinned_folder_paths': ['/a', '', '/b'],
    });
    settings.debugReset();
    await settings.ensureLoaded();
    expect(settings.paths, {'/a', '/b'});
  });

  test('损坏防御：存储值类型不对（非字符串列表）时不抛异常', () async {
    SharedPreferences.setMockInitialValues({'pinned_folder_paths': 12345});
    settings.debugReset();
    await settings.ensureLoaded();
    expect(settings.paths, isEmpty);
  });
}
