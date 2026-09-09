import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/async_serial_queue.dart';
import 'package:moumou/utils/async_session.dart';
import 'package:moumou/utils/async_single_flight.dart';

/// C1 并发原语测试（§4.29）：
/// - [AsyncSession]：令牌递增 / 最新判定 / 主动作废；
/// - [AsyncSingleFlight]：同 key 只执行一次、失败不缓存、完成后可重新执行；
/// - [AsyncSerialQueue]：严格串行、异常不打断队列、idle 可等待。
void main() {
  group('AsyncSession', () {
    test('start 递增令牌，isCurrent 只认最新', () {
      final s = AsyncSession();
      expect(s.generation, 0);
      final a = s.start();
      expect(a, 1);
      expect(s.isCurrent(a), isTrue);
      final b = s.start();
      expect(b, 2);
      expect(s.isCurrent(a), isFalse); // 旧任务作废
      expect(s.isCurrent(b), isTrue);
    });

    test('invalidate 作废在途任务但不返回新令牌', () {
      final s = AsyncSession();
      final token = s.start();
      s.invalidate();
      expect(s.isCurrent(token), isFalse);
      expect(s.generation, token + 1);
    });

    test('reset 回到 0（测试用）', () {
      final s = AsyncSession()..start()..start();
      s.reset();
      expect(s.generation, 0);
      expect(s.isCurrent(0), isTrue);
    });

    test('模拟快速切换：旧请求结果被丢弃', () async {
      final s = AsyncSession();
      final applied = <String>[];
      Future<void> load(String value, int delayMs) async {
        final token = s.start();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        if (!s.isCurrent(token)) return; // 已被更新的请求取代
        applied.add(value);
      }

      // 先发慢请求，再发快请求：慢的应被丢弃
      final slow = load('旧', 30);
      final fast = load('新', 5);
      await Future.wait([slow, fast]);
      expect(applied, ['新']);
    });
  });

  group('AsyncSingleFlight', () {
    test('同 key 并发只执行一次，共享同一结果', () async {
      final flight = AsyncSingleFlight<int>();
      var calls = 0;
      Future<int> task() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return calls;
      }

      final results = await Future.wait([
        flight.run('a', task),
        flight.run('a', task),
        flight.run('a', task),
      ]);
      expect(calls, 1);
      expect(results, [1, 1, 1]);
      expect(flight.hasInFlight, isFalse);
      expect(flight.inFlightCount, 0);
    });

    test('不同 key 互不影响', () async {
      final flight = AsyncSingleFlight<String>();
      var calls = 0;
      Future<String> task(String v) async {
        calls++;
        return v;
      }

      final results = await Future.wait([
        flight.run('a', () => task('a')),
        flight.run('b', () => task('b')),
      ]);
      expect(results, ['a', 'b']);
      expect(calls, 2);
    });

    test('完成后在途记录清除，再次调用会重新执行', () async {
      final flight = AsyncSingleFlight<int>();
      var calls = 0;
      Future<int> task() async => ++calls;
      expect(await flight.run('k', task), 1);
      expect(await flight.run('k', task), 2);
      expect(calls, 2);
    });

    test('失败不缓存：错误抛给所有等待者且下次重新执行', () async {
      final flight = AsyncSingleFlight<int>();
      var calls = 0;
      Future<int> failing() async {
        calls++;
        throw StateError('boom $calls');
      }

      final first = flight.run('k', failing);
      final second = flight.run('k', failing); // 共享同一个失败 Future
      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      expect(calls, 1);

      // 失败后记录已清除 → 重新执行
      await expectLater(flight.run('k', failing), throwsStateError);
      expect(calls, 2);
      expect(flight.hasInFlight, isFalse);
    });

    test('clear 丢弃在途记录（任务本身仍会完成）', () async {
      final flight = AsyncSingleFlight<int>();
      final future = flight.run('k', () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 1;
      });
      expect(flight.hasInFlight, isTrue);
      flight.clear();
      expect(flight.hasInFlight, isFalse);
      expect(await future, 1);
    });
  });

  group('AsyncSerialQueue', () {
    test('严格按提交顺序串行执行，无并发重叠', () async {
      final queue = AsyncSerialQueue();
      final order = <int>[];
      var active = 0;
      var maxActive = 0;

      final futures = [
        for (var i = 0; i < 4; i++)
          queue.add(() async {
            active++;
            maxActive = active > maxActive ? active : maxActive;
            await Future<void>.delayed(Duration(milliseconds: 10 - i));
            order.add(i);
            active--;
            return i;
          }),
      ];
      expect(await Future.wait(futures), [0, 1, 2, 3]);
      expect(order, [0, 1, 2, 3]);
      expect(maxActive, 1); // 从不重叠
      await queue.idle;
    });

    test('任务异常不打断队列，错误抛给对应调用方', () async {
      final queue = AsyncSerialQueue();
      final done = <String>[];
      final f1 = queue.add(() async {
        done.add('first');
        throw StateError('boom');
      });
      final f2 = queue.add(() async {
        done.add('second');
        return 42;
      });
      final f3 = queue.add(() async {
        done.add('third');
        return 'ok';
      });

      await expectLater(f1, throwsStateError);
      expect(await f2, 42);
      expect(await f3, 'ok');
      expect(done, ['first', 'second', 'third']);
    });

    test('idle 等待队列排空', () async {
      final queue = AsyncSerialQueue();
      final done = <int>[];
      for (var i = 0; i < 3; i++) {
        queue.add(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          done.add(i);
        });
      }
      expect(done, isEmpty);
      await queue.idle;
      expect(done, [0, 1, 2]);
    });

    test('空队列提交立即执行', () async {
      final queue = AsyncSerialQueue();
      expect(await queue.add(() async => 'now'), 'now');
    });
  });
}
