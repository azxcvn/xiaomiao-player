import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/utils/network_entry_filter.dart';

/// 网络目录的条目过滤与搜索（纯逻辑）。
void main() {
  NetworkFile dir(String path) =>
      NetworkFile(name: path.split('/').last, path: path, isDirectory: true);

  NetworkFile file(String path) =>
      NetworkFile(name: path.split('/').last, path: path, size: 100);

  group('isHiddenNetworkEntry（隐藏项判定）', () {
    test('点开头的文件/目录算隐藏', () {
      expect(isHiddenNetworkEntry(dir('/.hidden')), isTrue);
      expect(isHiddenNetworkEntry(file('/.DS_Store')), isTrue);
    });

    test('NAS 元数据目录算隐藏（大小写不敏感）', () {
      expect(isHiddenNetworkEntry(dir('/@eaDir')), isTrue);
      expect(isHiddenNetworkEntry(dir('/@EADIR')), isTrue);
      expect(isHiddenNetworkEntry(dir('/#recycle')), isTrue);
      expect(isHiddenNetworkEntry(dir('/.recycle')), isTrue);
      expect(isHiddenNetworkEntry(dir('/Thumbs.db')), isTrue);
    });

    test('临时/部分文件算隐藏', () {
      expect(isHiddenNetworkEntry(file('/a.mkv.part')), isTrue);
      expect(isHiddenNetworkEntry(file('/a.tmp')), isTrue);
      expect(isHiddenNetworkEntry(file('/a.mkv~')), isTrue);
    });

    test('正常视频/文件夹不算隐藏', () {
      expect(isHiddenNetworkEntry(file('/01.mkv')), isFalse);
      expect(isHiddenNetworkEntry(file('/01.sc.ass')), isFalse);
      expect(isHiddenNetworkEntry(dir('/番剧')), isFalse);
      expect(isHiddenNetworkEntry(dir('/RECYCLE')), isFalse);
    });

    test('showHidden=true 时一律不隐藏', () {
      expect(isHiddenNetworkEntry(dir('/@eaDir'), showHidden: true), isFalse);
      expect(isHiddenNetworkEntry(dir('/.hidden'), showHidden: true), isFalse);
    });
  });

  group('visibleNetworkEntries / searchNetworkEntries', () {
    test('过滤隐藏项并保持顺序', () {
      final entries = [
        dir('/@eaDir'),
        dir('/番剧'),
        file('/01.mkv'),
        file('/.DS_Store'),
      ];
      final visible = visibleNetworkEntries(entries);
      expect(visible.map((e) => e.name), ['番剧', '01.mkv']);
    });

    test('showHidden=true 全部保留', () {
      final entries = [dir('/@eaDir'), file('/01.mkv')];
      expect(visibleNetworkEntries(entries, showHidden: true).length, 2);
    });

    test('搜索大小写不敏感、空查询返回原表', () {
      final entries = [file('/EP01.mkv'), file('/EP02.mkv'), file('/movie.mp4')];
      expect(searchNetworkEntries(entries, '').length, 3);
      expect(searchNetworkEntries(entries, 'ep0').map((e) => e.name),
          ['EP01.mkv', 'EP02.mkv']);
      expect(searchNetworkEntries(entries, 'MOVIE').map((e) => e.name),
          ['movie.mp4']);
      expect(searchNetworkEntries(entries, '不存在'), isEmpty);
    });
  });
}
