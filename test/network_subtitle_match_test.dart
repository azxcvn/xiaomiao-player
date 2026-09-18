import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/utils/network_subtitle_match.dart';

/// 网络存储视频的「同目录同名字幕」（纯函数）。
///
/// 回归场景：SMB/WebDAV/FTP 上的影片放在共享目录里，外挂字幕与视频同名
/// （含 `.sc` / `.tc` 语言后缀），本地播放能自动挂字幕，网络存储此前完全
/// 读不到——本组函数负责「远端路径 → 目录 / 文件名 / 最佳同名字幕」。
void main() {
  NetworkFile file(String path, {String? name, bool dir = false}) => NetworkFile(
        name: name ?? remoteFileNameOf(path),
        path: path,
        isDirectory: dir,
      );

  group('remoteFileNameOf（远端路径取文件名）', () {
    test('普通路径 / 共享根', () {
      expect(remoteFileNameOf('/share/anime/01.mkv'), '01.mkv');
      expect(remoteFileNameOf('/01.mkv'), '01.mkv');
      expect(remoteFileNameOf('/share/anime/'), 'anime');
    });

    test('中文与空格文件名原样保留', () {
      expect(remoteFileNameOf('/share/番剧/第 01 集.mkv'), '第 01 集.mkv');
    });

    test('percent 编码态还原（WebDAV 路径可能带编码）', () {
      expect(remoteFileNameOf('/share/%E7%AC%AC01%E9%9B%86.mkv'), '第01集.mkv');
      expect(remoteFileNameOf('/share/EP01%20SP.mkv'), 'EP01 SP.mkv');
      // 非法编码串原样返回（不抛异常）
      expect(remoteFileNameOf('/share/100%.mkv'), '100%.mkv');
    });

    test('空路径返回空串', () {
      expect(remoteFileNameOf(''), '');
      expect(remoteFileNameOf('/'), '');
    });
  });

  group('remoteDirOf（远端路径取目录）', () {
    test('取上一级；连接根返回空串（调用方按根列目录）', () {
      expect(remoteDirOf('/share/anime/01.mkv'), '/share/anime');
      expect(remoteDirOf('/share/anime/01.mkv/'), '/share/anime');
      expect(remoteDirOf('/share/anime/sub/01.mkv'), '/share/anime/sub');
      expect(remoteDirOf('/01.mkv'), '');
      expect(remoteDirOf('/'), '');
      expect(remoteDirOf(''), '');
    });
  });

  group('findBestRemoteSubtitle（远端同名字幕匹配）', () {
    test('基本命中：同名前缀 + 字幕扩展名', () {
      final best = findBestRemoteSubtitle(
        'EP01.mkv',
        files: [
          file('/share/EP01.mkv'),
          file('/share/EP01.ass'),
          file('/share/EP02.ass'),
          file('/share/readme.txt'),
        ],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/share/EP01.ass');
    });

    test('扩展名优先级 ass > srt（与本地同规则）', () {
      final best = findBestRemoteSubtitle(
        'EP01.mkv',
        files: [file('/a/EP01.srt'), file('/a/EP01.ass')],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/a/EP01.ass');
    });

    test('语言后缀：简体系统优先 sc，繁体系统优先 tc', () {
      final files = [file('/a/EP01.tc.ass'), file('/a/EP01.sc.ass')];
      expect(
        findBestRemoteSubtitle('EP01.mkv', files: files, systemLanguage: 'zh_cn')?.path,
        '/a/EP01.sc.ass',
      );
      expect(
        findBestRemoteSubtitle('EP01.mkv', files: files, systemLanguage: 'zh_tw')?.path,
        '/a/EP01.tc.ass',
      );
    });

    test('同名（无后缀）优先于带后缀', () {
      final best = findBestRemoteSubtitle(
        'EP01.mkv',
        files: [file('/a/EP01.sc.ass'), file('/a/EP01.ass')],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/a/EP01.ass');
    });

    test('目录不参与匹配（同名目录不算字幕）', () {
      final best = findBestRemoteSubtitle(
        'EP01.mkv',
        files: [file('/a/EP01.ass', dir: true)],
        systemLanguage: 'zh_cn',
      );
      expect(best, isNull);
    });

    test('无同名 / 空目录 → null', () {
      expect(
        findBestRemoteSubtitle(
          'EP01.mkv',
          files: [file('/a/EP02.ass'), file('/a/other.srt')],
          systemLanguage: 'zh_cn',
        ),
        isNull,
      );
      expect(
        findBestRemoteSubtitle('EP01.mkv', files: const [], systemLanguage: 'zh_cn'),
        isNull,
      );
    });

    test('调用方用远端路径取文件名（VideoFile.name 为空时的回落）', () {
      final best = findBestRemoteSubtitle(
        remoteFileNameOf('/a/EP01.mkv'),
        files: [NetworkFile(name: '', path: '/a/EP01.srt')],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/a/EP01.srt');
    });

    test('中文名路径同样命中', () {
      final best = findBestRemoteSubtitle(
        remoteFileNameOf('/share/番剧/第01集.mkv'),
        files: [file('/share/番剧/第01集.ass'), file('/share/番剧/第02集.ass')],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/share/番剧/第01集.ass');
    });

    test('视频名与目录条目都是编码态时同样命中（WebDAV）', () {
      final best = findBestRemoteSubtitle(
        remoteFileNameOf('/share/%E7%AC%AC01%E9%9B%86.mkv'),
        files: [file('/share/%E7%AC%AC01%E9%9B%86.ass')],
        systemLanguage: 'zh_cn',
      );
      expect(best?.path, '/share/%E7%AC%AC01%E9%9B%86.ass');
    });
  });
}
