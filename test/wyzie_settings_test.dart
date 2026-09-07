import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/wyzie/wyzie_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wyzie 字幕下载设置服务测试：默认值、setter、空集回退、持久化恢复、损坏防御。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WyzieSettings.instance.resetForTest();
  });

  final s = WyzieSettings.instance;

  test('默认值：密钥空 + 来源 all + 语言 en/zh + 格式 srt/ass + 编码 utf-8', () async {
    await s.ensureLoaded();
    expect(s.apiKey, '');
    expect(s.sources, {'all'});
    expect(s.languages, {'en', 'zh'});
    expect(s.formats, {'srt', 'ass'});
    expect(s.encodings, {'utf-8'});
  });

  test('setApiKey 去掉首尾空白', () async {
    await s.setApiKey('  wyzie-abc  ');
    expect(s.apiKey, 'wyzie-abc');
  });

  test('来源持久化恢复（模拟重启）', () async {
    await s.setSources({'bravo', 'charlie'});
    WyzieSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.sources, {'bravo', 'charlie'});
  });

  test('语言/格式/编码持久化恢复', () async {
    await s.setLanguages({'en'});
    await s.setFormats({'vtt'});
    await s.setEncodings({'gbk'});
    WyzieSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.languages, {'en'});
    expect(s.formats, {'vtt'});
    expect(s.encodings, {'gbk'});
  });

  test('空集回退 all（四个 setter 统一语义）', () async {
    await s.setSources({});
    await s.setLanguages({});
    await s.setFormats({});
    await s.setEncodings({});
    expect(s.sources, {'all'});
    expect(s.languages, {'all'});
    expect(s.formats, {'all'});
    expect(s.encodings, {'all'});
  });

  test('损坏数据：StringList 空 → 回退默认值', () async {
    SharedPreferences.setMockInitialValues({
      'wyzie_languages': <String>[],
    });
    WyzieSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.languages, {'en', 'zh'});
  });
}
