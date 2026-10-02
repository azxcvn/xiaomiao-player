import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/error_codes.dart';
import 'package:moumou/utils/network_path.dart';

/// 断言抛出的 [NetworkPathException] 携带指定错误码。
Matcher _throwsPathCode(NetworkPathErrorCode code) =>
    throwsA(isA<NetworkPathException>().having((e) => e.code, 'code', code));

void main() {
  test('根路径与空路径归一化为 /', () {
    expect(NetworkPath.from('').value, '/');
    expect(NetworkPath.from('/').value, '/');
    expect(NetworkPath.from('///').value, '/');
    expect(NetworkPath.root.isRoot, isTrue);
  });

  test('普通路径规范化', () {
    expect(NetworkPath.from('a/b/c').value, '/a/b/c');
    expect(NetworkPath.from('/a//b/').value, '/a/b');
    expect(NetworkPath.from('A/B').value, '/A/B');
  });

  test('relative 去掉前导斜杠', () {
    expect(NetworkPath.from('/a/b').relative, 'a/b');
    expect(NetworkPath.root.relative, '');
  });

  test('child 拼接', () {
    final root = NetworkPath.from('/movies');
    expect(root.child('年度').value, '/movies/年度');
    expect(NetworkPath.root.child('x').value, '/x');
  });

  test('segments 拆分', () {
    expect(NetworkPath.from('/a/b/c').segments, ['a', 'b', 'c']);
    expect(NetworkPath.root.segments, isEmpty);
  });

  test('拒绝非法路径', () {
    expect(
      () => NetworkPath.from('http://x/y'),
      _throwsPathCode(NetworkPathErrorCode.scheme),
    );
    expect(
      () => NetworkPath.from('a/../b'),
      _throwsPathCode(NetworkPathErrorCode.dotSegment),
    );
    expect(
      () => NetworkPath.from('a/./b'),
      _throwsPathCode(NetworkPathErrorCode.dotSegment),
    );
    expect(
      () => NetworkPath.from(r'a\b'),
      _throwsPathCode(NetworkPathErrorCode.segmentSeparator),
    );
    expect(
      () => NetworkPath.from('a/\u0000b'),
      _throwsPathCode(NetworkPathErrorCode.segmentControlChar),
    );
  });

  test('值相等与 hashCode（代理按路径缓存的前提）', () {
    final a = NetworkPath.from('/movies/a.mp4');
    final b = NetworkPath.from('movies/a.mp4');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect({a: 1}[b], 1);
    expect(a, isNot(NetworkPath.root));
    expect(NetworkPath.root, NetworkPath.from(''));
    // 与其它类型（例如字符串）都不相等
    final Object asString = '/movies/a.mp4';
    expect(a == asString, isFalse);
  });
}