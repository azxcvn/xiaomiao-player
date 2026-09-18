import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_directory_cache.dart';

/// 网络目录缓存：命中即免一次远端列目录（返回上级/点进已看过的目录瞬时打开）。
void main() {
  NetworkFile file(String path) => NetworkFile(name: path.split('/').last, path: path);

  test('put / get：命中返回同一份内容', () {
    final cache = NetworkDirectoryCache();
    cache.put('1::/', [file('/a.mkv')]);
    final hit = cache.get('1::/');
    expect(hit?.map((e) => e.name), ['a.mkv']);
  });

  test('未写入的键返回 null', () {
    final cache = NetworkDirectoryCache();
    expect(cache.get('1::/x'), isNull);
  });

  test('过期后返回 null（TTL 到期即视为无缓存）', () {
    // 用 0 TTL 模拟「写入即过期」，避免测试里真的 sleep
    final cache = NetworkDirectoryCache(ttl: Duration.zero);
    cache.put('1::/', [file('/a.mkv')]);
    expect(cache.get('1::/'), isNull);
  });

  test('invalidate 单个目录 / clear 全部', () {
    final cache = NetworkDirectoryCache();
    cache.put('1::/', [file('/a.mkv')]);
    cache.put('1::/sub', [file('/sub/b.mkv')]);
    cache.invalidate('1::/');
    expect(cache.get('1::/'), isNull);
    expect(cache.get('1::/sub'), isNotNull);
    cache.clear();
    expect(cache.get('1::/sub'), isNull);
  });

  test('invalidateConnection 清掉该连接的全部目录', () {
    final cache = NetworkDirectoryCache();
    cache.put('1::/', [file('/a.mkv')]);
    cache.put('2::/', [file('/b.mkv')]);
    cache.invalidateConnection('1::');
    expect(cache.get('1::/'), isNull);
    expect(cache.get('2::/'), isNotNull);
  });

  test('超出上限按最久未用淘汰（刚读过的不会被丢）', () {
    final cache = NetworkDirectoryCache(maxEntries: 2);
    cache.put('1::/a', [file('/a.mkv')]);
    cache.put('1::/b', [file('/b.mkv')]);
    // 读一次 /a：它变成最近使用
    expect(cache.get('1::/a'), isNotNull);
    cache.put('1::/c', [file('/c.mkv')]);
    expect(cache.get('1::/a'), isNotNull, reason: '最近读过的应保留');
    expect(cache.get('1::/b'), isNull, reason: '最久未用的被淘汰');
    expect(cache.length, 2);
  });

  test('缓存内容是只读视图（防止调用方改到缓存）', () {
    final cache = NetworkDirectoryCache();
    cache.put('1::/', [file('/a.mkv')]);
    expect(
      () => cache.get('1::/')!.add(file('/b.mkv')),
      throwsUnsupportedError,
    );
  });
}
