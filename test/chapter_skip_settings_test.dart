import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/services/chapter_skip_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 章节跳段设置服务测试：默认值、自动跳过类型增删、自定义关键词、
/// 持久化恢复、损坏数据防御。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChapterSkipSettings.instance.resetForTest();
  });

  final s = ChapterSkipSettings.instance;

  test('默认值：无自动跳过类型、关键词为空', () async {
    await s.ensureLoaded();
    expect(s.autoSkipTypes, isEmpty);
    expect(s.customIntroKeywords, '');
    expect(s.customOutroKeywords, '');
    expect(s.autoSkip(ChapterSkipType.intro), isFalse);
  });

  test('setAutoSkip：开启/关闭对应类型', () async {
    await s.setAutoSkip(ChapterSkipType.intro, true);
    expect(s.autoSkip(ChapterSkipType.intro), isTrue);
    expect(s.autoSkipTypes, {ChapterSkipType.intro});

    await s.setAutoSkip(ChapterSkipType.intro, false);
    expect(s.autoSkip(ChapterSkipType.intro), isFalse);
    expect(s.autoSkipTypes, isEmpty);
  });

  test('自动跳过类型持久化恢复（模拟重启）', () async {
    await s.setAutoSkip(ChapterSkipType.intro, true);
    await s.setAutoSkip(ChapterSkipType.outro, true);
    ChapterSkipSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.autoSkipTypes, {ChapterSkipType.intro, ChapterSkipType.outro});
  });

  test('自定义关键词 trim + 持久化恢复', () async {
    await s.setCustomIntroKeywords('  ap, opening  ');
    await s.setCustomOutroKeywords('ed');
    expect(s.customIntroKeywords, 'ap, opening');
    ChapterSkipSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.customIntroKeywords, 'ap, opening');
    expect(s.customOutroKeywords, 'ed');
  });

  test('损坏数据：未知类型名被忽略，不抛异常', () async {
    SharedPreferences.setMockInitialValues({
      'chapter_skip_auto_types': ['intro', 'bogus', 'outro'],
    });
    ChapterSkipSettings.instance.resetForTest();
    await s.ensureLoaded();
    expect(s.autoSkipTypes, {ChapterSkipType.intro, ChapterSkipType.outro});
  });
}
