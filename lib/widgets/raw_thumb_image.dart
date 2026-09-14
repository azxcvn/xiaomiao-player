import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:moumou/services/fast_thumbnails.dart';

/// 直接渲染 [FastThumbFrame] 的 RGBA 像素（无 PNG/JPEG 编码往返）。
///
/// 帧切换时异步解码新 [ui.Image]，解码完成前保持上一帧（无缝过渡）；
/// 旧 [ui.Image] 在替换后释放。宽高比由 [frame] 自带，配合 [fit] 拉伸。
class RawThumbImage extends StatefulWidget {
  const RawThumbImage({super.key, required this.frame, this.fit});

  final FastThumbFrame frame;

  /// null 时按原始尺寸显示；一般传 BoxFit.cover
  final BoxFit? fit;

  @override
  State<RawThumbImage> createState() => _RawThumbImageState();
}

class _RawThumbImageState extends State<RawThumbImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode(widget.frame);
  }

  @override
  void didUpdateWidget(RawThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一帧对象（缓存命中/邻近帧复用）不重复解码
    if (oldWidget.frame != widget.frame) {
      _decode(widget.frame);
    }
  }

  void _decode(FastThumbFrame frame) {
    final frameId = frame;
    _decodeInto(frame)
        .then((image) {
          if (!mounted || frameId != widget.frame) {
            image?.dispose();
            return;
          }
          final old = _image;
          _image = image;
          setState(() {});
          old?.dispose();
        })
        // 兜底（P2-41）：`_decodeInto` 内部已 try/catch，但这条链若在更外层出错
        // （未来改动/换实现），错误会变成**未处理异步异常**——这里保证它永不逃逸。
        .catchError((Object error, StackTrace stack) {
          debugPrint('RawThumbImage: 帧解码失败：$error');
          return null;
        });
  }

  /// 解码一帧 RGBA 为 [ui.Image]。
  ///
  /// P2-41：`ImmutableBuffer` / `ImageDescriptor` / `Codec` 都是**原生资源**，
  /// 用完必须 dispose（`getNextFrame()` 拿到的 `ui.Image` 由调用方持有并负责
  /// dispose，不在此处释放）。原来只 dispose 了 image，descriptor/codec/buffer
  /// 每次解码都漏一份 → 缩略图气泡反复拖动时原生内存持续增长。
  static Future<ui.Image?> _decodeInto(FastThumbFrame frame) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(frame.rgba);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: frame.width,
        height: frame.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final info = await codec.getNextFrame();
      return info.image;
    } catch (_) {
      return null;
    } finally {
      // 关掉 codec 不会释放已经交给我们的 image（image 的生命周期独立）
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const SizedBox.shrink();
    }
    return RawImage(
      image: image,
      fit: widget.fit,
    );
  }
}
