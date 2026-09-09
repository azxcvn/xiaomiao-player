import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/models/player_diagnostics.dart';
import 'package:moumou/utils/player_diagnostics.dart';

/// 播放诊断面板内容（横屏经 [showPlayerPanel] 右侧滑入，竖屏经
/// [showPlayerBottomPanel] 底部弹出，标题「播放诊断」）。
///
/// 每秒采样一次 mpv 运行时属性（缓存/丢帧/渲染延迟/硬解状态/音画同步），
/// 顶部把「哪里不健康」直接讲清楚，下方按播放/视频/音频/缓存与丢帧分组
/// 列出原始数值——排障不必再靠猜（对齐 mpvRx `Actionable Player Diagnostics`）。
///
/// 属性读取由页面注入（[readProperties]），面板本身不依赖 media_kit/平台通道，
/// 因此可在测试里用假数据驱动（§5.5）。
class PlayerDiagnosticsPanel extends StatefulWidget {
  const PlayerDiagnosticsPanel({
    super.key,
    required this.readProperties,
    this.interval = const Duration(seconds: 1),
  });

  /// 读取 mpv 属性表（属性缺失/不支持时对应值为 null）
  final Future<Map<String, String?>> Function() readProperties;

  /// 采样间隔
  final Duration interval;

  @override
  State<PlayerDiagnosticsPanel> createState() => _PlayerDiagnosticsPanelState();
}

class _PlayerDiagnosticsPanelState extends State<PlayerDiagnosticsPanel> {
  PlayerDiagnosticsSnapshot _snapshot = const PlayerDiagnosticsSnapshot();
  Timer? _timer;
  bool _reading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    _timer = Timer.periodic(widget.interval, (_) => unawaited(_read()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    if (_reading || !mounted) return;
    _reading = true;
    try {
      final raw = await widget.readProperties();
      if (!mounted) return;
      setState(() {
        _snapshot = PlayerDiagnosticsSnapshot.fromProperties(raw);
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    final warnings = diagnosticsWarnings(s);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failed) ...[
            _WarningCard(
              color: Colors.orangeAccent,
              lines: const ['无法读取播放器属性（播放器可能未就绪）'],
            ),
            const SizedBox(height: 12),
          ],
          if (warnings.isNotEmpty) ...[
            _WarningCard(color: Colors.redAccent, lines: warnings),
            const SizedBox(height: 12),
          ],
          _DiagGroup(
            title: '播放',
            rows: [
              ('标题', formatDiagnosticText(s.mediaTitle)),
              ('容器', formatDiagnosticText(s.fileFormat)),
              ('视频编码', formatDiagnosticText(s.videoCodec)),
              ('音频编码', formatDiagnosticText(s.audioCodec)),
              ('硬解', formatDiagnosticText(s.hwdec)),
              ('视频输出', formatDiagnosticText(s.vo)),
              ('同步方式', formatDiagnosticText(s.videoSync)),
            ],
          ),
          const SizedBox(height: 12),
          _DiagGroup(
            title: '视频',
            rows: [
              ('分辨率', formatDiagnosticResolution(s.width, s.height)),
              ('像素格式', formatDiagnosticText(s.pixelFormat)),
              ('容器帧率', formatDiagnosticFps(s.containerFps)),
              ('实际帧率', formatDiagnosticFps(s.estimatedFps)),
              ('屏幕刷新率', formatDiagnosticFps(s.displayFps)),
              ('视频码率', formatDiagnosticBitrate(s.videoBitrate)),
            ],
          ),
          const SizedBox(height: 12),
          _DiagGroup(
            title: '音频',
            rows: [
              ('音频参数', formatDiagnosticText(s.audioParams)),
              ('音频码率', formatDiagnosticBitrate(s.audioBitrate)),
              ('音画同步', formatDiagnosticAvsync(s.avsync)),
            ],
          ),
          const SizedBox(height: 12),
          _DiagGroup(
            title: '缓存与丢帧',
            rows: [
              ('缓冲时长', formatDiagnosticSeconds(s.demuxerCacheDurationSec)),
              ('可播时长', formatDiagnosticSeconds(s.demuxerCacheTimeSec)),
              ('缓存占用', formatDiagnosticBytes(s.cacheUsedBytes)),
              ('下行速率', formatDiagnosticSpeed(s.cacheSpeedBytesPerSec)),
              ('丢帧', _countText(s.droppedFrames)),
              ('解码丢帧', _countText(s.decoderDroppedFrames)),
              ('延迟帧', _countText(s.delayedFrames)),
              ('延迟均值', formatDiagnosticMillis(s.delayedFrameAverageMs)),
              ('时间戳异常帧', _countText(s.mistimedFrames)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '每秒自动刷新 · 数据来自 mpv 运行时属性',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _countText(int? value) =>
      value == null || value < 0 ? kDiagnosticPlaceholder : '$value';
}

/// 诊断分组卡片（暗色面板风格，与其它播放器面板一致）
class _DiagGroup extends StatelessWidget {
  const _DiagGroup({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].$1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 健康提示卡（顶部告警）
class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.color, required this.lines});

  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
