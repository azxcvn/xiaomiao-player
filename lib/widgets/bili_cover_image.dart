import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/bili_image_cache_service.dart';
import 'package:moumou/utils/bili_image_url.dart';

/// 哔哩哔哩封面图：**先查磁盘缓存 → 未命中下载 → 落盘 → 按显示尺寸解码**。
///
/// 与直接 `Image.network` 的差别（真机问题的修复点）：
/// - 请求的是图床裁过的 `@<w>w_<h>h_1c.webp`，单张从约 330 KB 降到约 10-17 KB；
/// - 解码按屏上尺寸（`targetWidth/Height`），同一张图不再以原图分辨率进内存；
/// - 图片落盘（[BiliImageCacheService]），退出再进 / 下拉刷新不再重下。
///
/// 提供两种用法：
/// - [BiliCoverImage.auto]：父容器给多大就用多大（网格单元里最省事）；
/// - [BiliCoverImage]（显式宽高）：固定尺寸的位置（如搜索列表 64×84）。
class BiliCoverImage extends StatelessWidget {
  final String url;

  /// 逻辑像素尺寸；[BiliCoverImage.auto] 构造时用 [LayoutBuilder] 实测填入。
  final double? width;
  final double? height;

  final BoxFit fit;

  /// url 为空时的占位（默认灰色底 + 电视图标）
  final Widget? emptyPlaceholder;

  /// 加载/解码失败时的占位（默认灰色底 + 破图图标）
  final Widget? errorPlaceholder;

  const BiliCoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.emptyPlaceholder,
    this.errorPlaceholder,
  });

  /// 撑满父容器：用实测约束决定请求与解码尺寸。
  const BiliCoverImage.auto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.emptyPlaceholder,
    this.errorPlaceholder,
  })  : width = null,
        height = null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (url.trim().isEmpty) {
      return emptyPlaceholder ?? _fallback(scheme, Icons.live_tv_outlined);
    }

    final w = width;
    final h = height;
    if (w != null && h != null && w > 0 && h > 0) {
      return _build(context, w, h);
    }
    // 未给尺寸：实测父容器约束后按实测值构建（网格单元里用）
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final ch =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;
        return _build(context, cw, ch);
      },
    );
  }

  Widget _build(BuildContext context, double displayWidth, double displayHeight) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // 图床裁剪 URL（非图床地址为 null → 退回原始 URL，行为与改动前一致）
    final requestUrl = biliCoverUrlFor(
          url: url,
          displayWidth: displayWidth,
          displayHeight: displayHeight,
          devicePixelRatio: dpr,
        ) ??
        url;

    final targetW = (displayWidth * dpr).round().clamp(1, 4096);
    final targetH = (displayHeight * dpr).round().clamp(1, 4096);

    return Image(
      image: BiliCoverImageProvider(
        url: requestUrl,
        targetWidth: targetW,
        targetHeight: targetH,
        l10n: l10n,
      ),
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          errorPlaceholder ?? _fallback(scheme, Icons.broken_image_outlined),
    );
  }

  Widget _fallback(ColorScheme scheme, IconData icon) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 28),
    );
  }
}

/// 磁盘缓存版图片源。
///
/// key 为值相等类（[BiliCoverImageKey]），同 URL + 同解码尺寸命中 Flutter 图像
/// 缓存后不会再走本类的 `loadImage`；未命中时才去查磁盘/发请求。
@immutable
class BiliCoverImageProvider extends ImageProvider<BiliCoverImageProvider> {
  final String url;
  final int targetWidth;

  /// 仅用于解码尺寸与缓存键（图床已按显示尺寸裁剪，无需再算解码高度）
  final int targetHeight;

  /// 失败文案的来源：provider 在 [BiliCoverImage._build] 里创建，只有那里拿得到
  /// context。它只影响异常提示、与「图怎么加载」无关，所以不参与
  /// [operator ==] / [hashCode]——本类的缓存键仍只有 url + 解码尺寸。
  final AppLocalizations l10n;

  const BiliCoverImageProvider({
    required this.url,
    required this.targetWidth,
    required this.targetHeight,
    required this.l10n,
  });

  @override
  Future<BiliCoverImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<BiliCoverImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    BiliCoverImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key),
      scale: 1.0,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _loadCodec(BiliCoverImageProvider key) async {
    final file = await BiliImageCacheService.download(
      key.url,
      width: key.targetWidth,
      height: key.targetHeight,
    );
    if (file == null) {
      throw _BiliCoverUnavailable(key.l10n);
    }
    // ImmutableBuffer 是**原生资源**：一旦创建，无论后面解码成功与否都要 dispose
    // （这个项目的缩略图解码就踩过同一个坑：漏 dispose 会导致原生内存随滚动增长）。
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw _BiliCoverUnavailable(key.l10n);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      // 按屏上尺寸解码：原图分辨率不再进内存（这也是流量之外的另一处开销）
      return await ui.instantiateImageCodecFromBuffer(
        buffer,
        targetWidth: key.targetWidth,
        targetHeight: key.targetHeight,
      );
    } catch (_) {
      buffer.dispose();
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BiliCoverImageProvider &&
        other.url == url &&
        other.targetWidth == targetWidth &&
        other.targetHeight == targetHeight;
  }

  @override
  int get hashCode => Object.hash(url, targetWidth, targetHeight);

  @override
  String toString() =>
      'BiliCoverImageProvider($url, ${targetWidth}x$targetHeight)';
}

/// 缓存与网络都拿不到时抛出（`Image` 的 errorBuilder 会接住）
class _BiliCoverUnavailable implements Exception {
  const _BiliCoverUnavailable(this.l10n);

  final AppLocalizations l10n;

  @override
  String toString() => l10n.biliCoverUnavailable;
}
