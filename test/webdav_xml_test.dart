import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/webdav_xml.dart';

void main() {
  test('percentDecode 基本解码', () {
    expect(percentDecode('a%20b'), 'a b');
    expect(percentDecode('%E4%B8%AD'), '中');
    expect(percentDecode('no-percent'), 'no-percent');
    expect(percentDecode('bad%xxy'), 'bad%xxy'); // 非法序列原样保留
  });

  test('parseHttpDate 解析 RFC1123 日期', () {
    final ms = parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT');
    expect(ms, DateTime.utc(1994, 11, 6, 8, 49, 37).millisecondsSinceEpoch);
    expect(parseHttpDate('not a date'), 0);
    expect(parseHttpDate(''), 0);
  });

  test('parseWebDavMultistatus 解析目录与文件', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/movies/</d:href>
    <d:propstat><d:prop>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getlastmodified>Mon, 01 Jan 2024 00:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/movies/a%20movie.mp4</d:href>
    <d:propstat><d:prop>
      <d:resourcetype/>
      <d:getcontentlength>123456</d:getcontentlength>
      <d:getlastmodified>Tue, 02 Jan 2024 01:02:03 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>
''';
    final resources = parseWebDavMultistatus(xml);
    expect(resources.length, 2);

    final dir = resources[0];
    expect(dir.href, '/movies/');
    expect(dir.name, 'movies');
    expect(dir.isDirectory, isTrue);
    expect(dir.contentLength, -1);

    final file = resources[1];
    expect(file.href, '/movies/a movie.mp4');
    expect(file.name, 'a movie.mp4');
    expect(file.isDirectory, isFalse);
    expect(file.contentLength, 123456);
    expect(file.lastModifiedMs, DateTime.utc(2024, 1, 2, 1, 2, 3).millisecondsSinceEpoch);
  });

  test('parseWebDavMultistatus 跳过无 href 的块', () {
    const xml = '''
<d:multistatus xmlns:d="DAV:">
  <d:response><d:propstat><d:prop/></d:propstat></d:response>
  <d:response><d:href>/ok.mp4</d:href><d:propstat><d:prop><d:getcontentlength>9</d:getcontentlength></d:prop></d:propstat></d:response>
</d:multistatus>
''';
    final resources = parseWebDavMultistatus(xml);
    expect(resources.length, 1);
    expect(resources[0].name, 'ok.mp4');
  });

  // P3：服务端 href 里的 `&` 按 XML 规范写作 `&amp;`，不解开就会拿字面量
  // `a&amp;b` 去请求 → 404
  test('parseWebDavMultistatus 反转义 href 里的 XML 实体', () {
    const xml = '''
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/music/Tom&amp;Jerry.mp4</d:href>
    <d:propstat><d:prop/></d:propstat>
  </d:response>
  <d:response>
    <d:href>/music/a%20&amp;%20b.mp3</d:href>
    <d:propstat><d:prop/></d:propstat>
  </d:response>
</d:multistatus>
''';
    final resources = parseWebDavMultistatus(xml);
    // 实体先反转义、再百分号解码：两条都该还原出真正的 `&`
    expect(resources[0].href, '/music/Tom&Jerry.mp4');
    expect(resources[0].name, 'Tom&Jerry.mp4');
    expect(resources[1].href, '/music/a & b.mp3');
    expect(resources[1].name, 'a & b.mp3');
  });

  test('unescapeXmlEntities：内置实体 + 数字实体，认不出的原样保留', () {
    expect(unescapeXmlEntities('a&amp;b'), 'a&b');
    expect(unescapeXmlEntities('&lt;tag&gt;'), '<tag>');
    expect(unescapeXmlEntities('&quot;q&quot;'), '"q"');
    expect(unescapeXmlEntities('it&apos;s'), "it's");
    expect(unescapeXmlEntities('&#38;&#x26;'), '&&');
    expect(unescapeXmlEntities('&unknown;'), '&unknown;');
    expect(unescapeXmlEntities('plain'), 'plain');
  });
}