import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/post_process_preset.dart';
import 'package:moumou/services/post_process_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 预设：只写参数、不引入第二套状态；应用后可继续手调并标记“已微调”。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PostProcessService.instance.resetForTest();
  });

  test('胶片电影·标准：开色阶/白平衡/胶片曲线/锐化/颗粒，并打开总开关', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.filmStandard);

    expect(s.enabled, isTrue);
    expect(s.appliedPreset, PostProcessPreset.filmStandard);
    expect(s.levelsEnabled, isTrue);
    expect(s.whiteBalanceEnabled, isTrue);
    expect(s.filmicEnabled, isTrue);
    expect(s.sharpenEnabled, isTrue);
    expect(s.filmGrainEnabled, isTrue);
    // 不该动的东西保持关闭
    expect(s.denoiseEnabled, isFalse);
    expect(s.vignetteEnabled, isFalse);
    expect(s.cartoonEnabled, isFalse);
    // 参数落在合法范围内
    expect(s.inBlack, inInclusiveRange(0, 0.4));
    expect(s.inWhite, inInclusiveRange(0.6, 1));
    expect(s.sharpenAmount, inInclusiveRange(-1, 1));
    expect(s.contrast, 4);
  });

  test('轻/中/重：数值按 0.6 / 1.0 / 1.4 缩放', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.filmLight);
    final light = s.inBlack;
    s.applyPreset(PostProcessPreset.filmStandard);
    final standard = s.inBlack;
    s.applyPreset(PostProcessPreset.filmStrong);
    final strong = s.inBlack;

    expect(light, lessThan(standard));
    expect(standard, lessThan(strong));
  });

  test('净化：降噪 + 去色带 + 轻锐化，不调色不加对比', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.cleanStandard);

    expect(s.denoiseEnabled, isTrue);
    expect(s.debandEnabled, isTrue);
    expect(s.sharpenEnabled, isTrue);
    expect(s.whiteBalanceEnabled, isFalse);
    expect(s.levelsEnabled, isFalse);
    expect(s.filmicEnabled, isFalse);
    expect(s.contrast, 0);
    expect(s.debandThreshold, inInclusiveRange(16, 96));
    expect(s.sharpenAmount, inInclusiveRange(-1, 1));
  });

  test('老电视：开降噪/去色带/白平衡/锐化', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.tvStandard);

    expect(s.denoiseEnabled, isTrue);
    expect(s.debandEnabled, isTrue);
    expect(s.whiteBalanceEnabled, isTrue);
    expect(s.sharpenEnabled, isTrue);
    expect(s.denoiseStrength, inInclusiveRange(0.02, 0.5));
    expect(s.denoiseRadius, inInclusiveRange(0.3, 1.0));
  });

  test('低码率与流媒体：都有去色带，流媒体不降噪', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.lowBitrateStandard);
    expect(s.debandEnabled, isTrue);
    expect(s.denoiseEnabled, isTrue);

    s.applyPreset(PostProcessPreset.streamingStandard);
    expect(s.debandEnabled, isTrue);
    expect(s.denoiseEnabled, isFalse);
    expect(s.sharpenEnabled, isTrue);
  });

  test('柔和：负锐化；复古：暖白平衡 + 颗粒 + 暗角', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.soft);
    expect(s.sharpenEnabled, isTrue);
    expect(s.sharpenAmount, lessThan(0));

    s.applyPreset(PostProcessPreset.retro);
    expect(s.whiteBalanceEnabled, isTrue);
    expect(s.temperature, greaterThan(0));
    expect(s.filmGrainEnabled, isTrue);
    expect(s.vignetteEnabled, isTrue);
  });

  test('预设之后手调参数 → presetModified 变 true', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.filmStandard);
    expect(s.presetModified, isFalse);

    s.setBrightness(5);
    expect(s.presetModified, isTrue);
    expect(s.brightness, 5);
  });

  test('重置：参数回默认且清掉预设标记', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.filmStrong);
    s.resetSettings();

    expect(s.appliedPreset, isNull);
    expect(s.levelsEnabled, isFalse);
    expect(s.filmGrainEnabled, isFalse);
    expect(s.contrast, 0);
  });

  test('应用预设不会串味：从胶片切到柔和后，胶片的效果被关掉', () async {
    final s = PostProcessService.instance;
    await s.ensureLoaded();

    s.applyPreset(PostProcessPreset.filmStandard);
    s.applyPreset(PostProcessPreset.soft);

    expect(s.levelsEnabled, isFalse);
    expect(s.whiteBalanceEnabled, isFalse);
    expect(s.filmicEnabled, isFalse);
    expect(s.filmGrainEnabled, isFalse);
    expect(s.sharpenAmount, lessThan(0));
  });
}
