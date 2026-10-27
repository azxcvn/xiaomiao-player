import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/post_process_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 后处理设置：默认值、读盘恢复、重置、通知。
///
/// 不涉及真实播放器（`_player` 为 null 时所有 mpv 写入都是空操作）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PostProcessService.instance.resetForTest();
  });

  test('默认：总开关关闭、基础调节全 0、效果全关', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    expect(s.enabled, isFalse);
    expect(s.brightness, 0);
    expect(s.contrast, 0);
    expect(s.gamma, 0);
    expect(s.saturation, 0);
    expect(s.hue, 0);
    expect(s.sharpenEnabled, isFalse);
    expect(s.debandEnabled, isFalse);
    expect(s.vignetteEnabled, isFalse);
    expect(s.scanlinesEnabled, isFalse);
    expect(s.naturalColorsEnabled, isFalse);
    expect(s.activeStyleEffectCount, 0);
  });

  test('读盘恢复已保存的参数', () async {
    SharedPreferences.setMockInitialValues({
      'post_process_enabled': true,
      'post_process_brightness': 12.0,
      'post_process_contrast': -20.0,
      'post_process_deband_enabled': true,
      'post_process_deband_threshold': 64.0,
      'post_process_deband_iterations': 3.0,
      'post_process_vignette_enabled': true,
      'post_process_vignette_power': 0.4,
      'post_process_vignette_radius': 0.3,
      'post_process_vignette_softness': 0.2,
      'post_process_scanlines_enabled': true,
      'post_process_natural_enabled': true,
      'post_process_natural_luma': 1.1,
      'post_process_bloom_enabled': true,
      'post_process_bloom_amount': 0.3,
      'post_process_cartoon_enabled': true,
      'post_process_cartoon_strength': 0.7,
    });
    PostProcessService.instance.resetForTest();

    final s = PostProcessService.instance;
    await s.ensureLoaded();

    expect(s.enabled, isTrue);
    expect(s.brightness, 12);
    expect(s.contrast, -20);
    expect(s.debandEnabled, isTrue);
    expect(s.debandThreshold, 64);
    expect(s.debandIterations, 3);
    expect(s.vignetteEnabled, isTrue);
    expect(s.vignettePower, 0.4);
    expect(s.vignetteRadius, 0.3);
    expect(s.vignetteSoftness, 0.2);
    expect(s.bloomEnabled, isTrue);
    expect(s.bloomAmount, 0.3);
    expect(s.cartoonEnabled, isTrue);
    expect(s.cartoonStrength, 0.7);
    expect(s.activeStyleEffectCount, 5);
  });

  test('resetSettings：参数回默认，总开关保留', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();
    s.setBrightness(30);
    s.setVignetteEnabled(true);
    s.setEnabled(true);

    s.resetSettings();

    expect(s.enabled, isTrue, reason: '恢复默认不应把总开关一起关掉');
    expect(s.brightness, 0);
    expect(s.vignetteEnabled, isFalse);
    expect(s.activeStyleEffectCount, 0);
  });

  test('setter 会通知监听者（面板靠它刷新）', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    var notifications = 0;
    void listener() => notifications++;
    s.addListener(listener);
    s.setEnabled(true);
    s.setContrast(20);
    s.setScanlinesEnabled(true);
    s.removeListener(listener);

    expect(notifications, 3);
  });

  test('样式参数范围常量：默认值都在范围内', () {
    expect(
      PostProcessService.defaultSharpenAmount,
      inInclusiveRange(
        PostProcessService.sharpenMin,
        PostProcessService.sharpenMax,
      ),
    );
    expect(
      PostProcessService.defaultVignettePower,
      inInclusiveRange(
        PostProcessService.vignettePowerMin,
        PostProcessService.vignettePowerMax,
      ),
    );
    expect(
      PostProcessService.defaultScanlinesDensity,
      inInclusiveRange(
        PostProcessService.scanlinesDensityMin,
        PostProcessService.scanlinesDensityMax,
      ),
    );
    expect(
      PostProcessService.defaultNaturalLuma,
      inInclusiveRange(
        PostProcessService.naturalLumaMin,
        PostProcessService.naturalLumaMax,
      ),
    );
  });
}
