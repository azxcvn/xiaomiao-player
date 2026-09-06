import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/version_compare.dart';

/// 版本号比较纯函数测试（工作.md：更新功能）。
void main() {
  test('远端版本更高 → 需要更新', () {
    expect(needUpdate('1.0.0', '1.1.0'), isTrue);
    expect(needUpdate('1.1.10', '1.2.0'), isTrue);
    expect(needUpdate('1.1.9', '1.1.10'), isTrue);
    expect(needUpdate('1.1.10', '1.1.10.1'), isTrue);
  });

  test('远端版本更低或相等 → 不需要更新', () {
    expect(needUpdate('1.1.10', '1.1.10'), isFalse);
    expect(needUpdate('1.2.0', '1.1.10'), isFalse);
    expect(needUpdate('1.1.10', '1.1.9'), isFalse);
    expect(needUpdate('2.0.0', '1.9.9'), isFalse);
  });

  test('忽略前导 v', () {
    expect(needUpdate('v1.0.0', 'v1.1.0'), isTrue);
    expect(needUpdate('v1.1.0', 'v1.1.0'), isFalse);
    expect(needUpdate('1.0.0', 'v1.1.0'), isTrue);
  });

  test('段数不一致：缺失段视为 0', () {
    expect(needUpdate('1.1', '1.1.0'), isFalse); // 1.1 == 1.1.0
    expect(needUpdate('1.1', '1.1.1'), isTrue);
    expect(needUpdate('1.1.0', '1.1'), isFalse);
  });

  test('非数字段取数字前缀 / 视为 0', () {
    expect(needUpdate('1.1.9', '1.1.10-beta'), isTrue);
    expect(needUpdate('1.1.10', '1.1.10-beta'), isFalse); // 数字前缀相等
    expect(needUpdate('1.1.10', '1.1.x'), isFalse); // x 视为 0
  });
}
