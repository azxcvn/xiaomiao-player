import 'package:flutter/material.dart';
import 'package:moumou/services/wallpaper_settings.dart';
import 'package:moumou/widgets/settings_ui.dart';
import 'package:moumou/widgets/wallpaper_layer.dart';

/// 壁纸调整页（对齐参考实现 mpvRx 的 `WallpaperEditorScreen`）：
/// 适应/填充分段按钮 + 预览框（拖动/双指捏合）+ 缩放 / 水平 / 垂直 / 模糊 /
/// 透明度 5 条滑杆 + 重置 + 右上「保存壁纸」。
///
/// [sourcePath] 为**新选中的图片路径**（此时各项参数走默认值）；
/// 为 null 表示「调整当前壁纸」（载入已保存的参数）。
///
/// 保存语义：点「保存壁纸」才写设置（复制图片 + 写参数），中途返回不落任何改动；
/// 保存失败（拷贝失败）给提示并留在本页，不改动已有设置。
class WallpaperEditorPage extends StatefulWidget {
  /// 新选的图片路径；null = 编辑当前已生效的壁纸
  final String? sourcePath;

  const WallpaperEditorPage({super.key, this.sourcePath});

  @override
  State<WallpaperEditorPage> createState() => _WallpaperEditorPageState();
}

class _WallpaperEditorPageState extends State<WallpaperEditorPage> {
  late double _scale;
  late double _offsetX;
  late double _offsetY;
  late WallpaperScaleMode _scaleMode;
  late double _blur;
  late double _opacity;
  bool _saving = false;

  /// 手势开始时的缩放：`ScaleUpdateDetails.scale` 是相对手势起点的累计值，
  /// 必须以它为基准相乘（对当前值连乘会指数放大）
  double _scaleAtGestureStart = WallpaperSettings.defaultScale;

  /// 预览框的 key：手势换算需要容器尺寸，用 `RenderBox.size` 取，
  /// **不用 LayoutBuilder**（它在路由 Zoom 转场下会触发每帧布局异常，见
  /// `wallpaper_layer.dart` 的注释）
  final GlobalKey _previewKey = GlobalKey();

  Size? get _previewSize {
    final object = _previewKey.currentContext?.findRenderObject();
    if (object is RenderBox && object.hasSize) return object.size;
    return null;
  }

  /// 正在编辑的图片来源：新图用传入路径，调整现有壁纸用已保存路径
  String? get _imagePath =>
      widget.sourcePath ?? WallpaperSettings.instance.path;

  @override
  void initState() {
    super.initState();
    final s = WallpaperSettings.instance;
    final editingCurrent = widget.sourcePath == null;
    // 调整现有壁纸 → 载入已保存参数；选新图 → 全部走默认值
    _scale = editingCurrent ? s.scale : WallpaperSettings.defaultScale;
    _offsetX = editingCurrent ? s.offsetX : WallpaperSettings.defaultOffset;
    _offsetY = editingCurrent ? s.offsetY : WallpaperSettings.defaultOffset;
    _scaleMode = editingCurrent ? s.scaleMode : WallpaperScaleMode.fit;
    _blur = editingCurrent ? s.blur : WallpaperSettings.defaultBlur;
    _opacity = editingCurrent ? s.opacity : WallpaperSettings.defaultOpacity;
    // 设置早已在 App 启动时 ensureLoaded（外观页那张卡片就是靠它才知道有没有壁纸，
    // 而「调整」只能从卡片进入），这里同步读到的就是最终值。刻意**不**在这里
    // .then(setState)：读盘 Future 在测试里可能于首帧构建期间完成，
    // 那个时机的 setState 会撞上 markNeedsBuild-during-build。
    s.ensureLoaded();
  }

  void _reset() {
    setState(() {
      _scale = WallpaperSettings.defaultScale;
      _offsetX = WallpaperSettings.defaultOffset;
      _offsetY = WallpaperSettings.defaultOffset;
      _scaleMode = WallpaperScaleMode.fit;
      _blur = WallpaperSettings.defaultBlur;
      _opacity = WallpaperSettings.defaultOpacity;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await WallpaperSettings.instance.apply(
      sourcePath: widget.sourcePath,
      scale: _scale,
      offsetX: _offsetX,
      offsetY: _offsetY,
      scaleMode: _scaleMode,
      blur: _blur,
      opacity: _opacity,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('无法保存壁纸，请重新选择图片'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = _imagePath;
    return Scaffold(
      appBar: AppBar(
        title: const Text('调整壁纸'),
        actions: [
          TextButton(
            // 图还没就绪（路径为空）时不给保存
            onPressed: (path == null || _saving) ? null : _save,
            child: const Text('保存壁纸'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<WallpaperScaleMode>(
              segments: [
                for (final mode in WallpaperScaleMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {_scaleMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() {
                  _scaleMode = selection.first;
                  // 切换适应/填充会改变构图，缩放与位移一起清零（对齐 mpvRx）
                  _scale = WallpaperSettings.defaultScale;
                  _offsetX = WallpaperSettings.defaultOffset;
                  _offsetY = WallpaperSettings.defaultOffset;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPreview(scheme, path),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              '拖动以调整位置，双指捏合以缩放。',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          SettingsSliderRow(
            label: '缩放',
            display: '${_scale.toStringAsFixed(2)}x',
            value: _scale,
            min: WallpaperSettings.minScale,
            max: WallpaperSettings.maxScale,
            onChanged: (v) => setState(() => _scale = v),
          ),
          SettingsSliderRow(
            label: '水平位置',
            display: _offsetLabel(_offsetX),
            value: _offsetX,
            min: WallpaperSettings.minOffset,
            max: WallpaperSettings.maxOffset,
            onChanged: (v) => setState(() => _offsetX = v),
          ),
          SettingsSliderRow(
            label: '垂直位置',
            display: _offsetLabel(_offsetY),
            value: _offsetY,
            min: WallpaperSettings.minOffset,
            max: WallpaperSettings.maxOffset,
            onChanged: (v) => setState(() => _offsetY = v),
          ),
          SettingsSliderRow(
            label: '模糊',
            display: _blur.round().toString(),
            value: _blur,
            min: WallpaperSettings.minBlur,
            max: WallpaperSettings.maxBlur,
            onChanged: (v) => setState(() => _blur = v),
          ),
          SettingsSliderRow(
            label: '透明度',
            display: '${(_opacity * 100).round()}%',
            value: _opacity,
            min: WallpaperSettings.minOpacity,
            max: WallpaperSettings.maxOpacity,
            onChanged: (v) => setState(() => _opacity = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.settings_backup_restore, size: 18),
                label: const Text('重置'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 位移读数：显示成「相对屏幕的百分比」（offset × 行程 35%），
  /// 比裸浮点数更能说明画面实际挪了多少
  String _offsetLabel(double offset) {
    if (offset.abs() < 0.005) return '居中';
    final percent = (offset * WallpaperSettings.offsetTravel * 100).round();
    return percent > 0 ? '+$percent%' : '$percent%';
  }

  /// 预览框：与实机走**同一套** [WallpaperLayer]，只差容器尺寸，
  /// 保证所见即所得（遮罩也一起画，mpvRx 的预览少了这层、比实机偏亮）
  Widget _buildPreview(ColorScheme scheme, String? path) {
    return SizedBox(
      // 固定高度（对齐 mpvRx 的 420dp）：横屏 / 平板下都能一眼看全，
      // 变形也不会失控（内容本身可滚动）
      height: 420,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            key: _previewKey,
            onScaleStart: (_) => _scaleAtGestureStart = _scale,
            onScaleUpdate: (details) {
              final size = _previewSize;
              setState(() {
                // 捏合：ScaleUpdateDetails.scale 是「相对手势起点」的累计值，
                // 必须以手势开始时的缩放为基准相乘（不能对当前值连乘，会指数放大）
                _scale = (_scaleAtGestureStart * details.scale).clamp(
                  WallpaperSettings.minScale,
                  WallpaperSettings.maxScale,
                );
                // 拖动：位移增量 ÷ (容器尺寸 × 行程)，与渲染公式严格互逆
                if (size != null && size.width > 0 && size.height > 0) {
                  _offsetX =
                      (_offsetX +
                              details.focalPointDelta.dx /
                                  (size.width * WallpaperSettings.offsetTravel))
                          .clamp(
                            WallpaperSettings.minOffset,
                            WallpaperSettings.maxOffset,
                          );
                  _offsetY =
                      (_offsetY +
                              details.focalPointDelta.dy /
                                  (size.height * WallpaperSettings.offsetTravel))
                          .clamp(
                            WallpaperSettings.minOffset,
                            WallpaperSettings.maxOffset,
                          );
                }
              });
            },
            child: (path == null || path.isEmpty)
                ? Center(
                    child: Text(
                      '图片已不可用，请重新选择',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : WallpaperLayer(
                    path: path,
                    scaleMode: _scaleMode,
                    scale: _scale,
                    offsetX: _offsetX,
                    offsetY: _offsetY,
                    blur: _blur,
                    opacity: _opacity,
                  ),
          ),
        ),
      ),
    );
  }
}
