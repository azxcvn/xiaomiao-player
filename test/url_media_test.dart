import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/url_media.dart';

/// 在线媒体链接纯函数测试（工作.md：链接播放功能）：
/// 规范化补协议 / 协议白名单判定 / URL 标题提取。
void main() {
  group('normalizeMediaUrl', () {
    test('完整 URL 原样保留（去空白）', () {
      expect(
        normalizeMediaUrl('  https://example.com/a.mp4  '),
        'https://example.com/a.mp4',
      );
      expect(
        normalizeMediaUrl('rtsp://cam.local/stream'),
        'rtsp://cam.local/stream',
      );
    });

    test('无协议自动补 https://', () {
      expect(
        normalizeMediaUrl('example.com/a.mp4'),
        'https://example.com/a.mp4',
      );
    });

    test('空串 / 纯空白返回 null', () {
      expect(normalizeMediaUrl(''), isNull);
      expect(normalizeMediaUrl('   '), isNull);
    });

    test('含内部空白（自然语言）返回 null', () {
      expect(normalizeMediaUrl('not a url'), isNull);
      expect(normalizeMediaUrl('看看这个 https://x.com/v.mp4'), isNull);
    });

    test('已带 scheme: 形态不补协议（mailto 等交给白名单拒绝）', () {
      // 补 https 会把 scheme 错位成 userinfo，必须保持原样：
      // mailto 为 opaque URI（无 host）→ null；
      // content:// 可解析（原样返回），由 isPlayableMediaUrl 白名单拒绝
      expect(normalizeMediaUrl('mailto:a@b.com'), isNull);
      expect(normalizeMediaUrl('content://media/1'), 'content://media/1');
    });

    test('解析失败 / 无 host 返回 null', () {
      expect(normalizeMediaUrl('https://'), isNull);
      expect(normalizeMediaUrl('///'), isNull);
    });
  });

  group('isPlayableMediaUrl', () {
    test('支持 http/https', () {
      expect(isPlayableMediaUrl('http://a.com/v.mp4'), isTrue);
      expect(isPlayableMediaUrl('https://a.com/v.mp4'), isTrue);
    });

    test('支持流媒体协议（mpv 白名单）', () {
      expect(isPlayableMediaUrl('rtmp://a.com/live'), isTrue);
      expect(isPlayableMediaUrl('rtmps://a.com/live'), isTrue);
      expect(isPlayableMediaUrl('rtsp://a.com/1'), isTrue);
      expect(isPlayableMediaUrl('rtsps://a.com/1'), isTrue);
      expect(isPlayableMediaUrl('rtp://a.com:5000'), isTrue);
      expect(isPlayableMediaUrl('mms://a.com/v'), isTrue);
      expect(isPlayableMediaUrl('mmsh://a.com/v'), isTrue);
      expect(isPlayableMediaUrl('ftp://a.com/v.mp4'), isTrue);
    });

    test('协议大小写不敏感', () {
      expect(isPlayableMediaUrl('HTTPS://A.COM/V.MP4'), isTrue);
    });

    test('不支持/非法的 URL 返回 false', () {
      expect(isPlayableMediaUrl('mailto:a@b.com'), isFalse);
      expect(isPlayableMediaUrl('content://media/1'), isFalse);
      expect(isPlayableMediaUrl('javascript:alert(1)'), isFalse);
      expect(isPlayableMediaUrl('not a url'), isFalse);
      expect(isPlayableMediaUrl(''), isFalse);
    });
  });

  group('mediaTitleFromUrl', () {
    test('取最后一段路径并解码', () {
      expect(
        mediaTitleFromUrl('https://example.com/dir/movie.mkv'),
        'movie.mkv',
      );
      expect(
        mediaTitleFromUrl('https://example.com/dir/%E5%BD%B1%E7%89%87.mp4'),
        '影片.mp4',
      );
    });

    test('去掉 query 与 fragment', () {
      expect(
        mediaTitleFromUrl('https://example.com/v.mp4?token=1&sign=2#frag'),
        'v.mp4',
      );
    });

    test('路径为空回退 host，再兜底原串', () {
      expect(mediaTitleFromUrl('https://example.com'), 'example.com');
      expect(mediaTitleFromUrl('https://example.com/'), 'example.com');
      expect(mediaTitleFromUrl('::::'), '::::');
    });

    test('尾斜杠取前一段', () {
      expect(
        mediaTitleFromUrl('https://example.com/dir/folder/'),
        'folder',
      );
    });

    test('非法百分号序列保留原文', () {
      expect(mediaTitleFromUrl('https://a.com/%zz.mp4'), '%zz.mp4');
    });
  });
}
