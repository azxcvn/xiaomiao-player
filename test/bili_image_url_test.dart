import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/bili_image_url.dart';

/// 哔哩哔哩封面 URL 工具测试。
///
/// 这些断言的期望值来自真机图床实测（HEAD 请求返回 200 + `image/webp`），
/// 不是猜的：原图 336,730 B；`@320w_400h_1c.webp` 14,226 B；
/// `@240w_320h_1c.webp` 9,440 B；`@360w_202h_1c.webp` 10,768 B。
void main() {
  group('isBiliImageHost', () {
    test('认图床域名（含子域）', () {
      expect(isBiliImageHost('https://i0.hdslb.com/bfs/archive/a.jpg'), isTrue);
      expect(isBiliImageHost('http://i1.hdslb.com/bfs/archive/a.jpg'), isTrue);
      expect(isBiliImageHost('https://hdslb.com/x.jpg'), isTrue);
    });

    test('非图床地址不认', () {
      expect(isBiliImageHost('https://example.com/a.jpg'), isFalse);
      expect(isBiliImageHost('https://hdslb.com.evil.com/a.jpg'), isFalse);
      expect(isBiliImageHost(''), isFalse);
      expect(isBiliImageHost('not a url'), isFalse);
    });
  });

  group('normalizeBiliImageUrl', () {
    test('图床 http 升级为 https', () {
      expect(
        normalizeBiliImageUrl('http://i1.hdslb.com/bfs/archive/a.jpg'),
        'https://i1.hdslb.com/bfs/archive/a.jpg',
      );
    });

    test('剥掉已有的 @ 裁剪后缀（不能叠加）', () {
      expect(
        normalizeBiliImageUrl('https://i0.hdslb.com/a.jpg@480w_270h_1c.webp'),
        'https://i0.hdslb.com/a.jpg',
      );
      expect(
        normalizeBiliImageUrl('https://i0.hdslb.com/a.jpg@100w.webp'),
        'https://i0.hdslb.com/a.jpg',
      );
    });

    test('剥掉 query / fragment', () {
      expect(
        normalizeBiliImageUrl('https://i0.hdslb.com/a.jpg?x=1'),
        'https://i0.hdslb.com/a.jpg',
      );
      expect(
        normalizeBiliImageUrl('https://i0.hdslb.com/a.jpg#frag'),
        'https://i0.hdslb.com/a.jpg',
      );
    });

    test('非图床地址原样保留（不改协议、不剥参数）', () {
      expect(
        normalizeBiliImageUrl('http://example.com/a.jpg?token=1'),
        'http://example.com/a.jpg?token=1',
      );
    });

    test('空串 / 空白串安全', () {
      expect(normalizeBiliImageUrl(''), '');
      expect(normalizeBiliImageUrl('   '), '');
    });
  });

  group('biliImageUrlFor', () {
    test('拼出验证过的后缀', () {
      expect(
        biliImageUrlFor(
          'http://i1.hdslb.com/bfs/archive/a.jpg',
          BiliCoverSize.cover3x4,
        ),
        'https://i1.hdslb.com/bfs/archive/a.jpg@320w_400h_1c.webp',
      );
      expect(
        biliImageUrlFor(
          'https://i0.hdslb.com/a.jpg',
          BiliCoverSize.cover16x9,
        ),
        'https://i0.hdslb.com/a.jpg@360w_202h_1c.webp',
      );
    });

    test('非图床地址返回 null（调用方回退原 URL）', () {
      expect(biliImageUrlFor('https://example.com/a.jpg', BiliCoverSize.cover3x4), isNull);
      expect(biliImageUrlFor('', BiliCoverSize.cover3x4), isNull);
    });
  });

  group('biliCoverSizeFor', () {
    test('竖版封面挑 3:4 预设（不会被挑成 16:9）', () {
      // 360dp 屏、3x 像素比：网格单元约 168×207dp → 物理约 504×621
      final size = biliCoverSizeFor(504, 621, targetAspect: 168 / 207);
      expect(size.width / size.height, closeTo(0.8, 0.01));
      expect(size, BiliCoverSize.cover3x4);
    });

    test('横版头图挑 16:9 预设', () {
      final size = biliCoverSizeFor(345 * 3, 194 * 3, targetAspect: 345 / 194);
      expect(size, BiliCoverSize.cover16x9);
    });

    test('需求超过所有候选时取候选里最大的', () {
      final size = biliCoverSizeFor(4000, 5000, targetAspect: 0.8);
      expect(size, BiliCoverSize.cover3x4);
    });

    test('尺寸为 0 / 负数时不抛异常', () {
      expect(() => biliCoverSizeFor(0, 0), returnsNormally);
      expect(() => biliCoverSizeFor(-5, -5), returnsNormally);
    });

    test('不传比例时退化为按宽度就近', () {
      expect(biliCoverSizeFor(100, 0).width, BiliCoverSize.cover3x4.width);
    });
  });

  group('biliCoverUrlFor', () {
    test('按屏上尺寸 × 像素比选预设并拼 URL', () {
      // 64×84 的小图（搜索列表），3x 屏 → 192×252 物理像素
      final url = biliCoverUrlFor(
        url: 'https://i0.hdslb.com/a.jpg',
        displayWidth: 64,
        displayHeight: 84,
        devicePixelRatio: 3,
      );
      expect(url, 'https://i0.hdslb.com/a.jpg@320w_400h_1c.webp');
    });

    test('非图床地址返回 null', () {
      final url = biliCoverUrlFor(
        url: 'https://example.com/a.jpg',
        displayWidth: 64,
        displayHeight: 84,
        devicePixelRatio: 3,
      );
      expect(url, isNull);
    });
  });
}
