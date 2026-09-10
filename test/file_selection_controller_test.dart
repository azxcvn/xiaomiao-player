import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/file_selection_controller.dart';

/// 多选状态控制器测试（进入 / 退出 / 切换 / 全选 / 剔除失效项）
void main() {
  late FileSelectionController controller;

  setUp(() => controller = FileSelectionController());
  tearDown(() => controller.dispose());

  test('初始：非多选态、空选择', () {
    expect(controller.selecting, isFalse);
    expect(controller.isEmpty, isTrue);
    expect(controller.count, 0);
    expect(controller.paths, isEmpty);
  });

  test('begin：进入多选并立刻选中长按项（不会出现「空选择的多选态」）', () {
    controller.begin('/a');
    expect(controller.selecting, isTrue);
    expect(controller.count, 1);
    expect(controller.isSelected('/a'), isTrue);
  });

  test('begin：重复进入会清掉上一次的选择', () {
    controller.begin('/a');
    controller.toggle('/b');
    controller.begin('/c');
    expect(controller.paths, ['/c']);
  });

  test('toggle：多选态下加选 / 取消，顺序即点选先后', () {
    controller.begin('/a');
    controller.toggle('/b');
    expect(controller.paths, ['/a', '/b']);

    controller.toggle('/a');
    expect(controller.paths, ['/b']);
  });

  test('toggle：非多选态下无效（防误触）', () {
    controller.toggle('/a');
    expect(controller.selecting, isFalse);
    expect(controller.isEmpty, isTrue);
  });

  test('toggle：取消到 0 项仍留在多选态（还能继续选）', () {
    controller.begin('/a');
    controller.toggle('/a');
    expect(controller.count, 0);
    expect(controller.selecting, isTrue);
  });

  test('exit：退出并清空；重复调用不重复通知', () {
    var notified = 0;
    controller.addListener(() => notified++);

    controller.begin('/a');
    expect(notified, 1);

    controller.exit();
    expect(notified, 2);
    expect(controller.selecting, isFalse);
    expect(controller.isEmpty, isTrue);

    controller.exit();
    expect(notified, 2);
  });

  test('setAll：全选与取消全选（都留在多选态）', () {
    controller.begin('/a');

    controller.setAll(['/a', '/b', '/c'], selected: true);
    expect(controller.count, 3);

    controller.setAll(['/a', '/b', '/c'], selected: false);
    expect(controller.isEmpty, isTrue);
    expect(controller.selecting, isTrue);
  });

  test('containsAll：空列表不算全选', () {
    expect(controller.containsAll(const []), isFalse);

    controller.begin('/a');
    expect(controller.containsAll(const []), isFalse);
    expect(controller.containsAll(['/a']), isTrue);
    expect(controller.containsAll(['/a', '/b']), isFalse);
  });

  test('retainExisting：剔除已消失的选中项，无变化时不通知', () {
    var notified = 0;
    controller.addListener(() => notified++);
    controller.begin('/a');
    controller.toggle('/b');
    expect(notified, 2);

    controller.retainExisting(['/a', '/b', '/c']);
    expect(notified, 2);

    controller.retainExisting(['/a']);
    expect(controller.paths, ['/a']);
    expect(notified, 3);

    controller.retainExisting(const []);
    expect(controller.isEmpty, isTrue);
    expect(notified, 4);
  });

  test('paths：返回只读快照，外部改不动内部状态', () {
    controller.begin('/a');
    final snapshot = controller.paths;
    expect(() => snapshot.add('/b'), throwsUnsupportedError);
    expect(controller.count, 1);
  });
}
