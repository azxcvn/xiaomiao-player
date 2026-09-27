import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/subtitle/subtitle_source_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字幕来源设置测试：默认 Wyzie、单选互斥（切换即覆盖）、自定义地址读写与
/// 往返持久化。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubtitleSourceSettings.instance.resetForTest();
  });

  final s = SubtitleSourceSettings.instance;

  test('默认：Wyzie 来源 + 自定义地址为空', () {
    expect(s.kind, SubtitleSourceKind.wyzie);
    expect(s.customUrlTemplate, isEmpty);
    expect(s.customConfigured, isFalse);
  });

  test('单选互斥：切到自定义即覆盖 Wyzie，切回来也一样', () async {
    await s.setKind(SubtitleSourceKind.custom);
    expect(s.kind, SubtitleSourceKind.custom);

    await s.setKind(SubtitleSourceKind.wyzie);
    expect(s.kind, SubtitleSourceKind.wyzie);
    // 只有一个 kind 字段 → 不存在「两个都开/都关」的状态
    expect(SubtitleSourceKind.values.length, 2);
  });

  test('自定义地址：去首尾空白、空串视为未配置', () async {
    await s.setCustomUrlTemplate('  https://example.com/sub?name={name}  ');
    expect(s.customUrlTemplate, 'https://example.com/sub?name={name}');
    expect(s.customConfigured, isTrue);

    await s.setCustomUrlTemplate('   ');
    expect(s.customUrlTemplate, isEmpty);
    expect(s.customConfigured, isFalse);
  });

  test('持久化：模拟重启 load 后来源与地址都在', () async {
    await s.setKind(SubtitleSourceKind.custom);
    await s.setCustomUrlTemplate('https://example.com/api?q={name}');

    await s.load();
    expect(s.kind, SubtitleSourceKind.custom);
    expect(s.customUrlTemplate, 'https://example.com/api?q={name}');
  });

  test('旧数据里的未知 kind → 回落 Wyzie', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subtitle_source_kind', 'removed_kind');

    await s.load();
    expect(s.kind, SubtitleSourceKind.wyzie);
  });

  test('reset 恢复默认（测试间不串状态）', () async {
    await s.setKind(SubtitleSourceKind.custom);
    await s.setCustomUrlTemplate('https://example.com/x?name={name}');

    s.resetForTest();
    expect(s.kind, SubtitleSourceKind.wyzie);
    expect(s.customUrlTemplate, isEmpty);
  });
}
