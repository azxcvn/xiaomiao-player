import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/async_coalesced_reload.dart';

/// 「等待式」串行重跑器测试（B5 / P1-11）。
///
/// 锁定的语义：并发调用**不互相丢弃**，而是合并成「当前轮 + 一轮补跑」；
/// 每个调用方都在**不早于自己请求**的那一轮完成后才恢复执行。旧实现
/// （`if (_loading) return;`）会让后来者拿「自己改动之前」开始的快照，
/// 「恢复上次选中字幕」因此静默失败。
void main() {
  test('空闲调用：立刻执行一次并完成', () async {
    var runs = 0;
    final reload = AsyncCoalescedReload(() async => runs++);

    await reload.run();

    expect(runs, 1);
    expect(reload.runCount, 1);
    expect(reload.isRunning, isFalse);
  });

  test('在跑期间的多次调用合并为**一轮**补跑', () async {
    var runs = 0;
    final gate = Completer<void>();
    final reload = AsyncCoalescedReload(() async {
      runs++;
      if (runs == 1) await gate.future;
    });

    final first = reload.run();
    final second = reload.run();
    final third = reload.run();

    expect(runs, 1, reason: '首次调用立刻开跑，后续调用不应各自开跑');
    expect(reload.isRunning, isTrue);
    gate.complete();
    await Future.wait([first, second, third]);

    expect(runs, 2, reason: '三个等待者只触发一轮补跑');
    expect(reload.runCount, 2);
    expect(reload.isRunning, isFalse);
  });

  test('等待者要等补跑结束，而不是当前轮结束', () async {
    final order = <String>[];
    var runs = 0;
    final gate = Completer<void>();
    final reload = AsyncCoalescedReload(() async {
      runs++;
      final n = runs;
      order.add('start$n');
      if (n == 1) await gate.future;
      order.add('end$n');
    });

    final first = reload.run();
    final second = reload.run();
    gate.complete();
    await first;
    await second;

    expect(order, ['start1', 'end1', 'start2', 'end2']);
  });

  test('补跑期间的新请求会再触发一轮（保证「不早于我的请求」）', () async {
    var runs = 0;
    final gates = <Completer<void>>[Completer<void>(), Completer<void>()];
    final reload = AsyncCoalescedReload(() async {
      runs++;
      if (runs <= 2) await gates[runs - 1].future;
    });

    final first = reload.run();
    final second = reload.run();
    gates[0].complete();
    // 第 2 轮（补跑）开跑后才有第三个请求
    await pumpEventQueue();
    expect(runs, 2);
    final third = reload.run();
    gates[1].complete();
    await Future.wait([first, second, third]);

    expect(runs, 3, reason: '补跑期间的新请求必须再补一轮');
  });

  test('任务串行：绝不并发执行', () async {
    var active = 0;
    var maxActive = 0;
    final gate = Completer<void>();
    var runs = 0;
    final reload = AsyncCoalescedReload(() async {
      active++;
      maxActive = active > maxActive ? active : maxActive;
      runs++;
      if (runs == 1) await gate.future;
      active--;
    });

    final first = reload.run();
    final second = reload.run();
    gate.complete();
    await Future.wait([first, second]);

    expect(maxActive, 1);
  });

  test('任务抛错：错误交给本轮所有等待者，随后仍可正常使用', () async {
    var runs = 0;
    final gate = Completer<void>();
    final reload = AsyncCoalescedReload(() async {
      runs++;
      if (runs == 1) {
        await gate.future;
        throw StateError('boom');
      }
    });

    final first = reload.run();
    final second = reload.run();
    final firstExpectation = expectLater(first, throwsStateError);
    final secondExpectation = expectLater(second, throwsStateError);
    gate.complete();
    await firstExpectation;
    await secondExpectation;

    expect(runs, 2, reason: '首轮抛错后补跑仍要执行（否则等待者永远挂住）');
    await reload.run();
    expect(runs, 3);
    expect(reload.isRunning, isFalse);
  });

  test('空闲后再次调用：新开一轮', () async {
    var runs = 0;
    final reload = AsyncCoalescedReload(() async => runs++);

    await reload.run();
    await reload.run();

    expect(runs, 2);
  });
}
