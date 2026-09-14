/// 通用格式化工具：文件大小 / 日期 / 时长（文件夹卡片与视频卡片共用）
library;

/// 字节数 → 人类可读大小（B / KB / MB / GB）
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

/// 日期 → yyyy-MM-dd（null 返回空串）
String formatDate(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 截图文件名：`小喵Player-yyyy-MM-dd-HHmmss.png`（含到秒的时间，
/// 避免同一天多张截图重名互相覆盖；工作.md 播放器截图命名）。
String formatScreenshotName(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '小喵Player-${dt.year}-${two(dt.month)}-${two(dt.day)}'
      '-${two(dt.hour)}${two(dt.minute)}${two(dt.second)}.png';
}

/// 毫秒 → 时长文本（mm:ss 或 h:mm:ss）
String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 播放页底栏时间文本：「已播/总时长」⇄「已播/剩余时长」（点击底栏时间切换）。
///
/// **剩余时长负值必须清零**（B4/P1-5）：拖动进度条越过结尾或终帧位置略超
/// 时长时，`total - pos` 为负，而 [formatDuration] 走 `~/` + `%`
/// （`-5000` → `"59:55"`），屏幕上会出现 `-59:55` 这种荒唐显示。
/// 横竖屏两页共用本函数，避免任一侧再漏钳制。
String formatPlaybackTimeText({
  required Duration position,
  required Duration duration,
  required bool showRemaining,
}) {
  final pos = formatDuration(position.inMilliseconds);
  if (showRemaining && duration > Duration.zero) {
    final remaining = duration - position;
    final r = remaining.isNegative ? Duration.zero : remaining;
    return '$pos / -${formatDuration(r.inMilliseconds)}';
  }
  return '$pos / ${formatDuration(duration.inMilliseconds)}';
}

/// 倍速显示：1.0 → '1.0x'，1.25 → '1.25x'（播放器倍速胶囊 / 倍速面板共用）
String formatSpeed(double speed) {
  final s = speed.toStringAsFixed(speed == speed.roundToDouble() ? 1 : 2);
  return '${s}x';
}

/// 网速显示（工作.md 阶段1 第 1 点）：自动切换 KB/MB，保留两位小数。
/// [bytesPerSecond] 为每秒字节数：< 1024 KB/s 显示 KB，否则显示 MB。
String formatNetworkSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0.00 KB/s';
  final kb = bytesPerSecond / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(2)} KB/s';
  return '${(kb / 1024).toStringAsFixed(2)} MB/s';
}

/// 判断媒体路径是否为在线资源（工作.md 阶段1 第 1 点：网速详情仅在线播放时显示）。
/// 本地文件返回 false，http/https/rtmp/rtsp 等网络协议返回 true。
bool isOnlineMedia(String path) {
  final lower = path.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('rtmp://') ||
      lower.startsWith('rtsp://') ||
      lower.startsWith('mms://') ||
      lower.startsWith('srt://');
}
