import 'package:flutter/foundation.dart';
import 'package:moumou/models/audio_track.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 音频声道 / 音频处理设置：全局持久化的音频输出状态。
///
/// 与 [EqualizerSettings] 同一套模式（ChangeNotifier + shared_preferences
/// 单例，播放页音频面板与 [AudioController] 共同监听）：
/// - **音频声道**：自动 / 安全自动 / 单声道 / 立体声 / 反向立体声（mpv
///   `audio-channels`，反向立体声走 `af` 滤镜，见 [audioChannelsPropertyValue]）；
/// - **音频处理**：音量标准化（`dynaudnorm`）/ 动态范围压缩（`acompressor`）。
///
/// ⚠️ 这两项原先与 [AudioController] 同生命周期（每次进播放器重置为
/// 安全自动/关/关）。用户反馈「选好声道与音频处理，退出再进就回到默认」，
/// 故改为**跨会话持久化**：选一次即记住，用户不主动改就一直生效。
class AudioSettings extends ChangeNotifier {
  static final AudioSettings instance = AudioSettings._();

  AudioSettings._();

  /// 加载去重（同 [EqualizerSettings.ensureLoaded]）
  Future<void>? _loadFuture;

  /// 确保已从磁盘加载完成（首次调用触发 load；并发调用共享同一 Future）
  Future<void> ensureLoaded() => _loadFuture ??= load();

  static const _keyChannels = 'audio_channels';
  static const _keyVolumeNormalization = 'audio_volume_normalization';
  static const _keyDrc = 'audio_drc';

  /// 音频声道（默认安全自动）
  AudioChannels _channels = AudioChannels.autoSafe;

  /// 音量标准化开关（默认关闭）
  bool _volumeNormalization = false;

  /// 动态范围压缩开关（默认关闭）
  bool _drc = false;

  AudioChannels get channels => _channels;
  bool get volumeNormalization => _volumeNormalization;
  bool get drc => _drc;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // 声道按枚举名反查：旧数据缺失/指向已删除档位时 [AudioChannels.byName]
    // 回落安全自动（与改动前的默认值一致）
    _channels = AudioChannels.byName(prefs.getString(_keyChannels));
    _volumeNormalization = prefs.getBool(_keyVolumeNormalization) ?? false;
    _drc = prefs.getBool(_keyDrc) ?? false;
    notifyListeners();
  }

  /// 设置音频声道（写盘后由 [AudioController] 监听重应用 mpv 属性）。
  Future<void> setChannels(AudioChannels v) async {
    await ensureLoaded();
    if (_channels == v) return;
    _channels = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChannels, v.name);
  }

  /// 设置音量标准化开关。
  Future<void> setVolumeNormalization(bool v) async {
    await ensureLoaded();
    if (_volumeNormalization == v) return;
    _volumeNormalization = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVolumeNormalization, v);
  }

  /// 设置动态范围压缩开关。
  Future<void> setDrc(bool v) async {
    await ensureLoaded();
    if (_drc == v) return;
    _drc = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDrc, v);
  }

  /// 测试用：恢复默认值（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void reset() {
    _loadFuture = null;
    _channels = AudioChannels.autoSafe;
    _volumeNormalization = false;
    _drc = false;
    notifyListeners();
  }

  /// 序列化当前值（诊断 / 日志用，非持久化路径）
  @override
  String toString() =>
      'AudioSettings(channels: ${_channels.name}, '
      'volumeNormalization: $_volumeNormalization, drc: $_drc)';
}
