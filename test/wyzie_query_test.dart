import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/utils/wyzie_query.dart';

/// Wyzie 查询纯函数测试：来源/逗号参数拼接、语言代码归一化、客户端语言过滤。
void main() {
  test('wyzieSourceParam：空/全 → all，其余小写逗号拼接', () {
    expect(wyzieSourceParam({}), 'all');
    expect(wyzieSourceParam({'all'}), 'all');
    expect(wyzieSourceParam({'Bravo', 'Charlie'}), 'bravo,charlie');
  });

  test('wyzieCommaParam：空/全 → null，其余小写逗号拼接', () {
    expect(wyzieCommaParam({}), isNull);
    expect(wyzieCommaParam({'all'}), isNull);
    expect(wyzieCommaParam({'SRT', 'Ass'}), 'srt,ass');
  });

  test('wyzieLanguageCode：代码直用 / 展示名反查 / 未知原样', () {
    expect(wyzieLanguageCode('en'), 'en');
    expect(wyzieLanguageCode('EN'), 'en');
    expect(wyzieLanguageCode('English'), 'en');
    expect(wyzieLanguageCode('xx'), 'xx');
  });

  test('filterWyzieByLanguages：按代码与展示名过滤，空/全不过滤', () {
    final subs = [
      const WyzieSubtitle(url: 'u1', language: 'en'),
      const WyzieSubtitle(url: 'u2', language: 'English'),
      const WyzieSubtitle(url: 'u3', language: 'zh'),
    ];
    expect(filterWyzieByLanguages(subs, {'en'}).length, 2);
    expect(filterWyzieByLanguages(subs, {'en', 'zh'}).length, 3);
    expect(filterWyzieByLanguages(subs, {}).length, 3);
    expect(filterWyzieByLanguages(subs, {'all'}).length, 3);
    expect(filterWyzieByLanguages(subs, {'ja'}), isEmpty);
  });
}
