import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/ftp_parser.dart';

void main() {
  test('parseMlsdLine 解析文件', () {
    final e = parseMlsdLine('type=file;size=12345;modify=20240102030405; a.mp4');
    expect(e, isNotNull);
    expect(e!.name, 'a.mp4');
    expect(e.isDirectory, isFalse);
    expect(e.size, 12345);
    expect(e.lastModifiedMs, DateTime.utc(2024, 1, 2, 3, 4, 5).millisecondsSinceEpoch);
  });

  test('parseMlsdLine 解析目录', () {
    final e = parseMlsdLine('type=dir;modify=20240101000000; Movies');
    expect(e!, isNotNull);
    expect(e.isDirectory, isTrue);
    expect(e.size, -1);
  });

  test('parseMlsdLine 跳过 . 与 ..', () {
    expect(parseMlsdLine('type=dir; .'), isNull);
    expect(parseMlsdLine('type=dir; ..'), isNull);
    expect(parseMlsdLine('no-space-line'), isNull);
    expect(parseMlsdLine(''), isNull);
  });

  test('mlsdModifyToMs 边界', () {
    expect(mlsdModifyToMs('20240101000000'), DateTime.utc(2024, 1, 1).millisecondsSinceEpoch);
    expect(mlsdModifyToMs('20241301000000'), 0); // 月份越界
    expect(mlsdModifyToMs('short'), 0);
  });

  test('parseUnixListLine 解析文件与目录', () {
    final file = parseUnixListLine('-rw-r--r-- 1 user group 123456789 Sep  1 10:00 a.mp4');
    expect(file, isNotNull);
    expect(file!.isDirectory, isFalse);
    expect(file.size, 123456789);
    expect(file.name, 'a.mp4');

    final dir = parseUnixListLine('drwxr-xr-x 2 user group 4096 Sep  1 10:00 Movies');
    expect(dir, isNotNull);
    expect(dir!.isDirectory, isTrue);
    expect(dir.name, 'Movies');
  });

  // P3：软链行的名字带 ` -> target`，不剥就会拿目标路径去拼远端路径（必 404）
  test('parseUnixListLine 剥掉软链的 ` -> target` 尾巴', () {
    final link = parseUnixListLine(
      'lrwxrwxrwx 1 user group 20 Sep  1 10:00 最新一集 -> /srv/media/真实文件.mp4',
    );
    expect(link, isNotNull);
    expect(link!.name, '最新一集');
    // 软链指向什么这里判定不了，按文件处理
    expect(link.isDirectory, isFalse);
  });

  test('stripSymlinkTarget 只剥 ` -> ` 之后的部分', () {
    expect(stripSymlinkTarget('a.mp4'), 'a.mp4');
    expect(stripSymlinkTarget('a -> b'), 'a');
    expect(stripSymlinkTarget('a -> b -> c'), 'a');
    expect(stripSymlinkTarget(' -> b'), ' -> b'); // 无名字：原样返回，交给上层跳过
    expect(stripSymlinkTarget('-> b'), '-> b');
  });

  test('parseUnixListLine 拒绝非列表行', () {
    expect(parseUnixListLine('total 8'), isNull);
    expect(parseUnixListLine('.'), isNull);
    expect(parseUnixListLine(''), isNull);
  });
}