import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/wyzie_models.dart';
import 'package:moumou/utils/wyzie_filename.dart';

/// Wyzie 字幕落盘文件名纯函数测试：非法字符清洗、文件名拼装、同批消重。
void main() {
  test('sanitizeFileName：清洗路径非法字符 + 空串兜底', () {
    expect(sanitizeFileName('a/b:c*d?e"f<g>h|i'), 'a_b_c_d_e_f_g_h_i');
    expect(sanitizeFileName('   '), '未命名');
  });

  test('wyzieSubtitleFileName：媒体名.语言.格式', () {
    final sub = WyzieSubtitle(
      url: 'u',
      fileName: 'Movie.Name.1080p',
      language: 'en',
      format: 'srt',
    );
    expect(wyzieSubtitleFileName(sub), 'Movie.Name.1080p.en.srt');
  });

  test('wyzieSubtitleFileName：缺字段回退 fallbackTitle / unknown / txt', () {
    expect(
      wyzieSubtitleFileName(const WyzieSubtitle(url: 'u'), fallbackTitle: 'Inception'),
      'Inception.unknown.txt',
    );
  });

  test('uniqueFileName：占用时在扩展名前插 (n) 递增', () {
    final used = <String>{};
    expect(uniqueFileName('a.srt', used), 'a.srt');
    used.add('a.srt');
    expect(uniqueFileName('a.srt', used), 'a (1).srt');
    used.add('a (1).srt');
    expect(uniqueFileName('a.srt', used), 'a (2).srt');
  });
}
