/// 哔哩哔哩图床（`*.hdslb.com`）封面图 URL 工具。
///
/// **背景**：B 站接口返回的封面是**原图 URL**（实测一张 `i*.hdslb.com/bfs/...jpg`
/// 约 330 KB），而卡片实际显示只有一两百 dp。图床支持在 URL 后追加
/// `@<宽>w_<高>h_1c.webp` 让服务端现裁现转，实测同一张图：
///
/// | 后缀 | 体积 |
/// |---|---|
/// | 无（原图） | 336,730 B |
/// | `@480w_270h_1c.webp` | 17,346 B |
/// | `@320w_400h_1c.webp` | 14,226 B |
/// | `@240w_320h_1c.webp` | 9,440 B |
///
/// 所以列表封面一律走本工具拿「按屏上尺寸裁过的小图」，而不是直接把原图丢给
/// `Image.network`。配合 `BiliImageCacheService` 的磁盘缓存，二次进入不再重下。
library;

/// 图床裁剪预设：[width]×[height] 与 App 里实际用到的封面比例对应。
///
/// 尺寸都经过真机图床 HEAD 验证可用（返回 200 + `image/webp`）；图床对
/// 比例与尺寸有白名单式限制，所以这里只列验证过的组合，不做任意尺寸拼接。
class BiliCoverSize {
  final int width;
  final int height;
  final String label;

  const BiliCoverSize(this.width, this.height, this.label);

  /// 番剧封面（竖版 3:4）：`BiliCoverCard` 网格、选集列表缩略图
  static const cover3x4 = BiliCoverSize(320, 400, '3:4');

  /// 视频/番剧横版封面（16:9）：搜索结果行、详情页头图
  static const cover16x9 = BiliCoverSize(360, 202, '16:9');

  /// 小尺寸 16:9（列表行内小图，展示宽度约 64-120dp）
  static const small16x9 = BiliCoverSize(320, 180, '16:9 小图');

  /// 全部预设（按像素面积从小到大，供 [BiliCoverSize.bestFor] 就近选择）
  static const List<BiliCoverSize> all = [cover3x4, cover16x9, small16x9];
}

/// 判断是否哔哩哔哩图床地址（只有它支持 `@宽w_高h` 现裁后缀）
bool isBiliImageHost(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'hdslb.com' || host.endsWith('.hdslb.com');
}

/// 把图床 URL 规整为可直接请求的形式：
/// - `http://` → `https://`（接口返回的多是 http，升级后避免明文与降级风险）；
/// - 去掉已存在的 `@...` 后缀（同一张图的不同尺寸不能叠加后缀）。
///
/// 非图床地址原样返回。
String normalizeBiliImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  // 非图床地址原样返回：不改协议、不剥参数。那些 query 可能是鉴权令牌
  // （剥了图就 403），`@` 也可能是合法路径字符，都不是我们该动的东西。
  if (!isBiliImageHost(trimmed)) return trimmed;
  var result = trimmed;
  if (result.startsWith('http://')) {
    result = 'https://${result.substring('http://'.length)}';
  }
  for (final marker in const ['@', '?', '#']) {
    final at = result.indexOf(marker);
    if (at > 0) {
      result = result.substring(0, at);
      break;
    }
  }
  return result;
}

/// 生成按 [size] 裁剪的封面 URL；非图床地址返回 null，调用方回退原 URL。
String? biliImageUrlFor(String url, BiliCoverSize size) {
  final base = normalizeBiliImageUrl(url);
  if (base.isEmpty || !isBiliImageHost(base)) return null;
  return '$base@${size.width}w_${size.height}h_1c.webp';
}

/// 按屏上实际显示尺寸（物理像素）在 [BiliCoverSize.all] 里挑最合适的预设。
///
/// 规则：
/// 1. **先按比例筛**：`targetAspect`（宽/高）与预设比例相差不超过 15% 的才算候选，
///    否则竖版封面会被挑成 16:9 预设（比例不对，`BoxFit.cover` 还要再裁一次）；
/// 2. **再按宽度就近**：候选中取「宽度不小于需求」里最小的那个；需求超过所有
///    候选时取最大的（宁可略糊，也不请求超出白名单的尺寸）。
///
/// 无比例信息（`targetAspect` 为空）时退化为「全局按宽度就近」。
BiliCoverSize biliCoverSizeFor(double widthPx, double heightPx,
    {double? targetAspect}) {
  final need = widthPx <= 0 ? 0.0 : widthPx;
  final sorted = List<BiliCoverSize>.from(BiliCoverSize.all)
    ..sort((a, b) => a.width.compareTo(b.width));

  List<BiliCoverSize> candidates = sorted;
  final aspect = targetAspect ?? (heightPx > 0 ? widthPx / heightPx : null);
  if (aspect != null && aspect > 0) {
    final matched = sorted
        .where((s) =>
            ((s.width / s.height) - aspect).abs() / aspect <= 0.15)
        .toList();
    if (matched.isNotEmpty) candidates = matched;
  }

  for (final size in candidates) {
    if (size.width >= need) return size;
  }
  return candidates.last;
}

/// 直接给出「按屏上尺寸裁剪」的图片 URL。
///
/// [displayWidth] / [displayHeight] 是逻辑像素（dp），[devicePixelRatio] 由调用方
/// 传入（一般 `MediaQuery.devicePixelRatioOf(context)`）。非图床地址返回 null。
String? biliCoverUrlFor({
  required String url,
  required double displayWidth,
  required double displayHeight,
  required double devicePixelRatio,
}) {
  final best = biliCoverSizeFor(
    displayWidth * devicePixelRatio,
    displayHeight * devicePixelRatio,
    targetAspect: displayHeight > 0 ? displayWidth / displayHeight : null,
  );
  return biliImageUrlFor(url, best);
}
