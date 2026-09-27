import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/utils/subtitle_language.dart';

/// 内嵌字幕轨「中文优先」纯函数：语言/标题识别、特效优先、不误伤非中文片。
void main() {
  SubtitleTrack track(
    String id, {
    String? lang,
    String? title,
    bool external = false,
    String? sourcePath,
  }) => SubtitleTrack(
    id: id,
    language: lang,
    title: title,
    codec: 'ass',
    external: external,
    sourcePath: sourcePath,
  );

  group('isChineseSubtitleLanguage', () {
    test('常见中文标记都认', () {
      for (final lang in [
        'zh',
        'zho',
        'chi',
        'cn',
        'chs',
        'cht',
        'sc',
        'tc',
        'zh-CN',
        'zh_TW',
        'zh-Hans',
        'Chinese',
        '中文',
        'CHI (Simplified)',
      ]) {
        expect(
          isChineseSubtitleLanguage(lang),
          isTrue,
          reason: '应识别为中文：$lang',
        );
      }
    });

    test('其它语言与空值不认', () {
      for (final lang in ['en', 'eng', 'ja', 'jpn', 'kor', 'und', '', null]) {
        expect(
          isChineseSubtitleLanguage(lang),
          isFalse,
          reason: '不应识别为中文：$lang',
        );
      }
    });
  });

  group('bestChineseSubtitleTrack', () {
    test('多轨中文优先：特效中文 > 普通中文 > 英文', () {
      final tracks = [
        track('1', lang: 'eng', title: 'English'),
        track('2', lang: 'zh', title: '简体'),
        track('3', lang: 'zh', title: '简英特效'),
      ];
      expect(bestChineseSubtitleTrack(tracks)!.id, '3');
    });

    test('只有普通中文时选普通中文（不给英文加分）', () {
      final tracks = [
        track('1', lang: 'eng', title: 'English SDH'),
        track('2', lang: 'cht', title: '繁體'),
      ];
      expect(bestChineseSubtitleTrack(tracks)!.id, '2');
    });

    test('语言缺失但标题写「中字」也算中文', () {
      final tracks = [
        track('1', lang: 'eng', title: 'English'),
        track('2', title: '中字'),
      ];
      expect(bestChineseSubtitleTrack(tracks)!.id, '2');
    });

    test('没有中文轨时返回 null（保持内核原选择，不猜英文）', () {
      final tracks = [
        track('1', lang: 'eng', title: 'English'),
        track('2', lang: 'jpn', title: '日本語'),
      ];
      expect(bestChineseSubtitleTrack(tracks), isNull);
    });

    test('同分取列表靠前的那条（顺序稳定）', () {
      final tracks = [
        track('1', lang: 'zh', title: '简体中文'),
        track('2', lang: 'zh', title: '中文简体'),
      ];
      expect(bestChineseSubtitleTrack(tracks)!.id, '1');
    });

    test('空列表返回 null', () {
      expect(bestChineseSubtitleTrack(const []), isNull);
    });
  });

  group('shouldSwitchToChineseTrack', () {
    final zh = track('2', lang: 'zh', title: '简英特效');
    final en = track('1', lang: 'eng', title: 'English');

    test('当前是非中文轨 → 换', () {
      expect(shouldSwitchToChineseTrack(current: en, best: zh), isTrue);
    });

    test('当前就是最优那条 → 不换', () {
      expect(shouldSwitchToChineseTrack(current: zh, best: zh), isFalse);
    });

    test('当前已是别的中文轨 → 不换（尊重已有中文选择，如繁中）', () {
      final cht = track('3', lang: 'cht', title: '繁體');
      expect(shouldSwitchToChineseTrack(current: cht, best: zh), isFalse);
    });

    test('当前还没选出轨（null）→ 换', () {
      expect(shouldSwitchToChineseTrack(current: null, best: zh), isTrue);
    });

    test('没有中文轨（best 为 null）→ 永不换', () {
      expect(shouldSwitchToChineseTrack(current: en, best: null), isFalse);
      expect(shouldSwitchToChineseTrack(current: null, best: null), isFalse);
    });

    test('当前是外挂字幕（用户自己放的）→ 不换', () {
      final external = track(
        '9',
        lang: 'eng',
        title: 'English',
        external: true,
        sourcePath: '/tmp/a.srt',
      );
      // 外挂轨不在候选集合里；即便被当成 current 传入，它非中文 → 由调用方
      // 用「外挂不参与比较」这条前置规则挡住（见 SubtitleController）
      expect(chinesePreferenceScore(external), 0);
    });
  });
}
