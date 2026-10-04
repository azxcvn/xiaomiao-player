import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/l10n/app_localizations_zh.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/equalizer_preset.dart';

void main() {
  // 显示名已搬到 UI 层（label_maps）：测试用中文夹具取文案
  final l10n = AppLocalizationsZh();

  group('预设模型', () {
    test('每个预设都是 5 段且增益在 -15~+15', () {
      expect(kEqualizerBandCount, 5);
      expect(kEqualizerBandLabels.length, 5);
      for (final p in kEqualizerPresets) {
        expect(p.bands.length, 5, reason: '预设 ${equalizerPresetLabel(l10n, p)} 应恰有 5 段');
        for (final b in p.bands) {
          expect(
            b,
            inInclusiveRange(-15, 15),
            reason: '预设 ${equalizerPresetLabel(l10n, p)} 越界',
          );
        }
      }
    });

    test('「平直」预设全为 0 且排在最前', () {
      expect(kEqualizerPresets.first.id, 'flat');
      expect(equalizerPresetLabel(l10n, kEqualizerPresets.first), '平直');
      expect(kEqualizerPresets.first.bands, [0, 0, 0, 0, 0]);
    });

    test('内置预设为影视向（平直/对白/电影/低音/高音/夜间）', () {
      final ids = kEqualizerPresets.map((p) => p.id).toList();
      for (final id in [
        'flat',
        'dialogue',
        'cinema',
        'bass',
        'treble',
        'night',
      ]) {
        expect(ids, contains(id));
      }
    });

    test('关键频段幅度足够可闻（至少一处达到 ±6dB）', () {
      for (final p in kEqualizerPresets) {
        if (p.id == 'flat') continue;
        final maxAbs = p.bands.map((b) => b.abs()).reduce((a, b) => a > b ? a : b);
        expect(
          maxAbs,
          greaterThanOrEqualTo(6),
          reason: '预设 ${equalizerPresetLabel(l10n, p)} 幅度过小',
        );
      }
    });
  });

  group('equalizerPresetById', () {
    test('按 id 反查命中', () {
      expect(
        equalizerPresetLabel(l10n, equalizerPresetById('dialogue')!),
        '对白增强',
      );
      expect(
        equalizerPresetLabel(l10n, equalizerPresetById('cinema')!),
        '电影',
      );
    });

    test('未知 id / null 返回 null', () {
      expect(equalizerPresetById('nope'), isNull);
      expect(equalizerPresetById(null), isNull);
    });
  });

  group('equalizerBandsEqual', () {
    test('逐段相等（容差内）', () {
      expect(
        equalizerBandsEqual([1, 2, 3, 4, 5], [1, 2, 3, 4, 5]),
        isTrue,
      );
      expect(
        equalizerBandsEqual([1, 2, 3, 4, 5], [1, 2, 3, 4, 5.005]),
        isTrue,
      );
    });

    test('长度不符 / 数值差异 → false', () {
      expect(equalizerBandsEqual([1, 2, 3, 4, 5], [1, 2, 3, 4]), isFalse);
      expect(equalizerBandsEqual([1, 2, 3, 4, 5], [1, 2, 3, 4, 6]), isFalse);
    });
  });
}
