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
///
/// ## 读取容错（历史 bug 修复）
///
/// 旧实现有两个毛病，会让排障本身变得不可信：
/// 1. **没有超时**：`getProperty` 卡住（播放管线挂掉时常见）会让 `_reading`
///    永远是 true，之后每次 tick 都被 `if (_reading)` 跳过 —— 面板从此冻结，
///    用户看到一片 `—` 且**再也不会变化**，却没有任何提示。
/// 2. **"读到空"和"读取失败"混为一谈**：`readProperties` 返回空值表时不亮
///    `_failed` 灯，于是"什么都没读到"看起来就像"这些属性本来就没有值"。
///
/// 现在：整次读取带超时（[timeout]）；**读取失败的键保留上一次的值**
/// （不被空表覆盖）；被判定为不可读的键名会直接列在警示卡上——
/// 排障时一眼看出**是哪些属性**读不到，不用再数横杠。
class PlayerDiagnosticsPanel extends StatefulWidget {
  const PlayerDiagnosticsPanel({
    super.key,
    required this.readProperties,
    this.interval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 3),
  });

  /// 读取 mpv 属性表。
  ///
  /// 约定：**属性不可读时必须返回 null（或省略该键），不要返回空串**——
  /// 空串会被当作占位符，既无法与"真的空值"区分，也会覆盖掉上一次的好值。
  final Future<Map<String, String?>> Function() readProperties;

  /// 采样间隔
  final Duration interval;

  /// 单次读取的超时上限：超过即判为失败并保留上一次的值（防整面板冻结）
  final Duration timeout;

  @override
  State<PlayerDiagnosticsPanel> createState() => _PlayerDiagnosticsPanelState();
}

class _PlayerDiagnosticsPanelState extends State<PlayerDiagnosticsPanel> {
  /// 上一次**成功读到**的原始属性表（失败/不可读的键从这里取值兜底）
  Map<String, String?> _lastGoodRaw = const {};

  PlayerDiagnosticsSnapshot _snapshot = const PlayerDiagnosticsSnapshot();
  Timer? _timer;
  bool _reading = false;

  /// 整次读取失败（抛异常 / 超时 / 播放器未就绪）
  bool _failed = false;

  /// 本次采样中不可读的键名（已排序，供警示卡列出）
  List<String> _failedKeys = const [];

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
      // 超时保护：读取卡死时不能让整个面板冻结（见类文档）
      final raw = await widget.readProperties().timeout(widget.timeout);
      if (!mounted) return;
      final merged = mergeDiagnosticsRaw(previous: _lastGoodRaw, current: raw);
      final failed = failedDiagnosticsKeys(raw);
      _lastGoodRaw = merged;
      // 真机排障用：把「本次读不到的属性」连同原始值打进日志（面板列不下全部，
      // 且用户截图不便）。带值能区分"读不到"与"读到了但是空串"。
      // debug 包用 `adb logcat -s flutter:*` 即可抓取。
      if (failed.isNotEmpty) {
        debugPrint(
          '[诊断] ${failed.length}/${kPlayerDiagnosticsProperties.length} 项不可读：'
          '${describeDiagnosticKeys(raw, failed)}',
        );
      }
      setState(() {
        _snapshot = PlayerDiagnosticsSnapshot.fromProperties(merged);
        _failed = failed.isNotEmpty;
        _failedKeys = failed;
      });
    } catch (_) {
      // 抛异常 / 超时：保留上一次的值，只亮警示卡（不清空面板）
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failedKeys = const [];
      });
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
              lines: [_readFailureMessage(_failedKeys)],
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
              ('音频编码', formatDiagnosticText(s.audioCodec)),
              ('硬解', formatDiagnosticText(s.hwdec)),
              // 视频输出 + 实际图形后端：`gpu-next · androidvk`（Vulkan）/
              // `gpu-next · android`（OpenGL ES）。开关设了 Vulkan 但这里仍显示
              // android，就说明没生效——判断渲染后端只能看这个实测值。
              ('视频输出', formatVideoOutput(s.vo, s.gpuContext)),
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

  /// 读取失败提示：**列出具体键名**（最多 6 个，其余折成计数）——
  /// 排障时直接知道是哪些属性读不到，不必靠数横杠猜。
  static String _readFailureMessage(List<String> failedKeys) {
    if (failedKeys.isEmpty) {
      return '无法读取播放器属性（播放器可能未就绪或已卡住）';
    }
    const maxNames = 6;
    final shown = failedKeys.take(maxNames).join('、');
    final rest = failedKeys.length - maxNames;
    final suffix = rest > 0 ? ' 等 ${failedKeys.length} 项' : '';
    return '读取失败：$shown$suffix（显示的是上一次成功值）';
  }
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
