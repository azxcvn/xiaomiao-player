import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/storage_root.dart';
import 'package:moumou/services/device_services.dart';

/// 存储卷根：模型判定 + 原生通道解析（issue #3「无法去往 TF 卡」）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moumou/video_info');

  const internal = StorageRoot(
    name: '内部存储',
    path: '/storage/emulated/0',
    isPrimary: true,
  );
  const sdcard = StorageRoot(
    name: 'SD 卡',
    path: '/storage/ABCD-1234',
    isRemovable: true,
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('storageRootOf 归属判定', () {
    test('内部存储路径归属内部存储卷', () {
      expect(
        storageRootOf('/storage/emulated/0/Movies', [internal, sdcard]),
        same(internal),
      );
    });

    test('外置卡路径归属 SD 卡卷（这是修复前永远走不到的入口）', () {
      expect(
        storageRootOf('/storage/ABCD-1234/Movies/Show', [internal, sdcard]),
        same(sdcard),
      );
    });

    test('卷根自身也算归属', () {
      expect(storageRootOf('/storage/ABCD-1234', [internal, sdcard]), same(sdcard));
    });

    test('前缀相同但不是子路径 → 不归属（/storage/ABCD-1234x 不是卡内）', () {
      expect(storageRootOf('/storage/ABCD-12345', [internal, sdcard]), isNull);
    });

    test('卷外路径 / 空路径 / 空卷列表 → null', () {
      expect(storageRootOf('/data/local/tmp', [internal, sdcard]), isNull);
      expect(storageRootOf('', [internal, sdcard]), isNull);
      expect(storageRootOf('/storage/ABCD-1234/Movies', const []), isNull);
    });

    test('卷根嵌套时取最长匹配（罕见 ROM）', () {
      const outer = StorageRoot(name: '外层', path: '/storage/X');
      const inner = StorageRoot(name: '内层', path: '/storage/X/inner');
      expect(storageRootOf('/storage/X/inner/a', [outer, inner]), same(inner));
    });
  });

  group('DeviceServices.getStorageRoots', () {
    test('解析原生返回的卷列表，丢弃空路径项', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getStorageRoots') return null;
        return [
          {
            'name': '内部存储',
            'path': '/storage/emulated/0',
            'isPrimary': true,
            'isRemovable': false,
          },
          {
            'name': 'SD 卡',
            'path': '/storage/ABCD-1234',
            'isPrimary': false,
            'isRemovable': true,
          },
          {'name': '坏数据', 'path': ''},
        ];
      });

      final roots = await DeviceServices.getStorageRoots();
      expect(roots.map((r) => r.path), [
        '/storage/emulated/0',
        '/storage/ABCD-1234',
      ]);
      expect(roots.first.isPrimary, isTrue);
      expect(roots.last.isRemovable, isTrue);
    });

    test('通道不可用（旧包/测试环境无实现）→ 空表，不抛异常', () async {
      // 未注册任何 handler：invokeMethod 返回 null
      expect(await DeviceServices.getStorageRoots(), isEmpty);
    });
  });
}
