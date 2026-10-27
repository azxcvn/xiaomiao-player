/// 后处理服务：基础调节（mpv 内置属性）+ 风格化着色器（运行时生成）。
///
/// 设计要点：
/// - **基础调节**（亮度/对比/伽马/饱和度/色相、去色带、锐化）走 mpv 自身的
///   属性，拖动滑杆即时生效，**不需要重编译着色器**；
/// - **风格化效果**（暗角/扫描线/自然色彩）是 mpv 用户着色器，参数在生成
///   源码时烧成字面量（mpv 没有运行时 uniform），改参数后重建文件并重新挂链，
///   因此做了 220ms 防抖，松手后才应用；
/// - 着色器链统一交给 [PlayerShaderPipeline]，与超分共存、互不覆盖；
/// - 只有 [enabled] 为 true 时才应用任何效果；关闭时把属性复位、链置空。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/models/post_process_preset.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/player_shader_pipeline.dart';
import 'package:moumou/utils/post_process_shaders.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostProcessService extends ChangeNotifier {
  PostProcessService._();

  static final PostProcessService instance = PostProcessService._();

  // ── 持久化 key ────────────────────────────────────────────
  static const _kEnabled = 'post_process_enabled';
  static const _kBrightness = 'post_process_brightness';
  static const _kContrast = 'post_process_contrast';
  static const _kGamma = 'post_process_gamma';
  static const _kSaturation = 'post_process_saturation';
  static const _kHue = 'post_process_hue';
  static const _kSharpenEnabled = 'post_process_sharpen_enabled';
  static const _kSharpenAmount = 'post_process_sharpen_amount';
  static const _kDenoiseEnabled = 'post_process_denoise_enabled';
  static const _kDenoiseStrength = 'post_process_denoise_strength';
  static const _kDenoiseRadius = 'post_process_denoise_radius';
  static const _kDebandEnabled = 'post_process_deband_enabled';
  static const _kDebandThreshold = 'post_process_deband_threshold';
  static const _kDebandRange = 'post_process_deband_range';
  static const _kDebandGrain = 'post_process_deband_grain';
  static const _kDebandIterations = 'post_process_deband_iterations';
  static const _kVignetteEnabled = 'post_process_vignette_enabled';
  static const _kVignettePower = 'post_process_vignette_power';
  static const _kVignetteAspect = 'post_process_vignette_aspect';
  static const _kVignetteRadius = 'post_process_vignette_radius';
  static const _kVignetteSoftness = 'post_process_vignette_softness';
  static const _kScanlinesEnabled = 'post_process_scanlines_enabled';
  static const _kScanlinesDensity = 'post_process_scanlines_density';
  static const _kScanlinesIntensity = 'post_process_scanlines_intensity';
  static const _kNaturalEnabled = 'post_process_natural_enabled';
  static const _kNaturalLuma = 'post_process_natural_luma';
  static const _kNaturalChroma = 'post_process_natural_chroma';
  static const _kBloomEnabled = 'post_process_bloom_enabled';
  static const _kBloomAmount = 'post_process_bloom_amount';
  static const _kBloomSpread = 'post_process_bloom_spread';
  static const _kCartoonEnabled = 'post_process_cartoon_enabled';
  static const _kCartoonStrength = 'post_process_cartoon_strength';
  static const _kWhiteBalanceEnabled = 'post_process_wb_enabled';
  static const _kTemperature = 'post_process_wb_temperature';
  static const _kTint = 'post_process_wb_tint';
  static const _kLevelsEnabled = 'post_process_levels_enabled';
  static const _kInBlack = 'post_process_levels_in_black';
  static const _kInWhite = 'post_process_levels_in_white';
  static const _kLevelsGamma = 'post_process_levels_gamma';
  static const _kFilmicEnabled = 'post_process_filmic_enabled';
  static const _kExposure = 'post_process_filmic_exposure';
  static const _kFilmicToe = 'post_process_filmic_toe';
  static const _kFilmicShoulder = 'post_process_filmic_shoulder';
  static const _kFilmicAmount = 'post_process_filmic_amount';
  static const _kFilmGrainEnabled = 'post_process_film_grain_enabled';
  static const _kFilmGrainIntensity = 'post_process_film_grain_intensity';
  static const _kFilmGrainSize = 'post_process_film_grain_size';

  // ── 参数范围 / 默认值（面板滑杆与重置都用这一份）──────────
  static const double basicMin = -100;
  static const double basicMax = 100;
  static const double sharpenMin = -1;
  static const double sharpenMax = 1;
  static const double denoiseStrengthMin = 0.02;
  static const double denoiseStrengthMax = 0.5;
  static const double denoiseRadiusMin = 0.3;
  static const double denoiseRadiusMax = 1.0;
  static const double debandThresholdMin = 16;
  static const double debandThresholdMax = 96;
  static const double debandRangeMin = 4;
  static const double debandRangeMax = 32;
  static const double debandGrainMin = 0;
  static const double debandGrainMax = 64;
  static const double debandIterationsMin = 0;
  static const double debandIterationsMax = 16;
  static const double vignettePowerMin = 0.1;
  static const double vignettePowerMax = 1.2;
  static const double vignetteAspectMin = 0.5;
  static const double vignetteAspectMax = 2.0;
  static const double vignetteRadiusMin = 0;
  static const double vignetteRadiusMax = 0.9;
  static const double vignetteSoftnessMin = 0.05;
  static const double vignetteSoftnessMax = 1.0;
  static const double scanlinesDensityMin = 0.5;
  static const double scanlinesDensityMax = 2.0;
  static const double scanlinesIntensityMin = 0.5;
  static const double scanlinesIntensityMax = 2.0;
  static const double naturalLumaMin = 0.8;
  static const double naturalLumaMax = 1.6;
  static const double naturalChromaMin = 0.8;
  static const double naturalChromaMax = 1.6;
  static const double bloomAmountMin = 0;
  static const double bloomAmountMax = 1.0;
  static const double bloomSpreadMin = 0.1;
  static const double bloomSpreadMax = 1.0;
  static const double cartoonStrengthMin = 0;
  static const double cartoonStrengthMax = 1.0;
  static const double temperatureMin = -100;
  static const double temperatureMax = 100;
  static const double tintMin = -100;
  static const double tintMax = 100;
  static const double inBlackMin = 0;
  static const double inBlackMax = 0.4;
  static const double inWhiteMin = 0.6;
  static const double inWhiteMax = 1.0;
  static const double levelsGammaMin = 0.2;
  static const double levelsGammaMax = 3.0;
  static const double exposureMin = 0.2;
  static const double exposureMax = 3.0;
  static const double toeMin = 0.5;
  static const double toeMax = 3.0;
  static const double shoulderMin = 0.5;
  static const double shoulderMax = 3.0;
  static const double filmicAmountMin = 0;
  static const double filmicAmountMax = 1.0;
  static const double filmGrainIntensityMin = 0;
  static const double filmGrainIntensityMax = 0.2;
  static const double filmGrainSizeMin = 1;
  static const double filmGrainSizeMax = 4;

  static const double defaultSharpenAmount = 0.35;
  static const double defaultDenoiseStrength = 0.1;
  static const double defaultDenoiseRadius = 1.0;
  static const double defaultDebandThreshold = 48;
  static const double defaultDebandRange = 16;
  static const double defaultDebandGrain = 32;
  static const double defaultDebandIterations = 1;
  static const double defaultVignettePower = 0.6;
  static const double defaultVignetteAspect = 1.0;
  static const double defaultVignetteRadius = 0.0;
  static const double defaultVignetteSoftness = 0.5;
  static const double defaultScanlinesDensity = 1.0;
  static const double defaultScanlinesIntensity = 1.0;
  static const double defaultNaturalLuma = 1.2;
  static const double defaultNaturalChroma = 1.2;
  static const double defaultBloomAmount = 0.6;
  static const double defaultBloomSpread = 0.6;
  static const double defaultCartoonStrength = 0.5;
  static const double defaultTemperature = 0;
  static const double defaultTint = 0;
  static const double defaultInBlack = 0;
  static const double defaultInWhite = 1.0;
  static const double defaultLevelsGamma = 1.0;
  static const double defaultExposure = 1.0;
  static const double defaultToe = 1.0;
  static const double defaultShoulder = 1.0;
  static const double defaultFilmicAmount = 0.7;
  static const double defaultFilmGrainIntensity = 0.03;
  static const double defaultFilmGrainSize = 1.0;

  // ── 状态 ─────────────────────────────────────────────────
  bool _enabled = false;
  double _brightness = 0;
  double _contrast = 0;
  double _gamma = 0;
  double _saturation = 0;
  double _hue = 0;

  bool _sharpenEnabled = false;
  double _sharpenAmount = defaultSharpenAmount;

  bool _denoiseEnabled = false;
  double _denoiseStrength = defaultDenoiseStrength;
  double _denoiseRadius = defaultDenoiseRadius;

  bool _debandEnabled = false;
  double _debandThreshold = defaultDebandThreshold;
  double _debandRange = defaultDebandRange;
  double _debandGrain = defaultDebandGrain;
  double _debandIterations = defaultDebandIterations;

  bool _vignetteEnabled = false;
  double _vignettePower = defaultVignettePower;
  double _vignetteAspect = defaultVignetteAspect;
  double _vignetteRadius = defaultVignetteRadius;
  double _vignetteSoftness = defaultVignetteSoftness;

  bool _scanlinesEnabled = false;
  double _scanlinesDensity = defaultScanlinesDensity;
  double _scanlinesIntensity = defaultScanlinesIntensity;

  bool _naturalEnabled = false;
  double _naturalLuma = defaultNaturalLuma;
  double _naturalChroma = defaultNaturalChroma;

  bool _bloomEnabled = false;
  double _bloomAmount = defaultBloomAmount;
  double _bloomSpread = defaultBloomSpread;

  bool _cartoonEnabled = false;
  double _cartoonStrength = defaultCartoonStrength;

  bool _whiteBalanceEnabled = false;
  double _temperature = defaultTemperature;
  double _tint = defaultTint;

  bool _levelsEnabled = false;
  double _inBlack = defaultInBlack;
  double _inWhite = defaultInWhite;
  double _levelsGamma = defaultLevelsGamma;

  bool _filmicEnabled = false;
  double _exposure = defaultExposure;
  double _filmicToe = defaultToe;
  double _filmicShoulder = defaultShoulder;
  double _filmicAmount = defaultFilmicAmount;

  bool _filmGrainEnabled = false;
  double _filmGrainIntensity = defaultFilmGrainIntensity;
  double _filmGrainSize = defaultFilmGrainSize;

  Player? _player;
  Directory? _shaderDir;

  /// 当前链上使用的着色器文件（参数变化会换新文件名，旧的在应用后删除）
  final Set<String> _shaderFiles = {};

  Future<void>? _loadFuture;
  Timer? _persistTimer;
  Timer? _shaderTimer;

  /// 当前套用的预设（null = 自定义）
  PostProcessPreset? _appliedPreset;

  /// 套用预设时的参数快照，用来判断用户之后有没有手工改过
  String? _presetSignature;

  bool get enabled => _enabled;
  double get brightness => _brightness;
  double get contrast => _contrast;
  double get gamma => _gamma;
  double get saturation => _saturation;
  double get hue => _hue;

  bool get sharpenEnabled => _sharpenEnabled;
  double get sharpenAmount => _sharpenAmount;

  bool get denoiseEnabled => _denoiseEnabled;
  double get denoiseStrength => _denoiseStrength;
  double get denoiseRadius => _denoiseRadius;

  bool get debandEnabled => _debandEnabled;
  double get debandThreshold => _debandThreshold;
  double get debandRange => _debandRange;
  double get debandGrain => _debandGrain;
  double get debandIterations => _debandIterations;

  bool get vignetteEnabled => _vignetteEnabled;
  double get vignettePower => _vignettePower;
  double get vignetteAspect => _vignetteAspect;
  double get vignetteRadius => _vignetteRadius;
  double get vignetteSoftness => _vignetteSoftness;

  bool get scanlinesEnabled => _scanlinesEnabled;
  double get scanlinesDensity => _scanlinesDensity;
  double get scanlinesIntensity => _scanlinesIntensity;

  bool get naturalColorsEnabled => _naturalEnabled;
  double get naturalLuma => _naturalLuma;
  double get naturalChroma => _naturalChroma;

  bool get bloomEnabled => _bloomEnabled;
  double get bloomAmount => _bloomAmount;
  double get bloomSpread => _bloomSpread;

  bool get cartoonEnabled => _cartoonEnabled;
  double get cartoonStrength => _cartoonStrength;

  bool get whiteBalanceEnabled => _whiteBalanceEnabled;
  double get temperature => _temperature;
  double get tint => _tint;

  bool get levelsEnabled => _levelsEnabled;
  double get inBlack => _inBlack;
  double get inWhite => _inWhite;
  double get levelsGamma => _levelsGamma;

  bool get filmicEnabled => _filmicEnabled;
  double get exposure => _exposure;
  double get filmicToe => _filmicToe;
  double get filmicShoulder => _filmicShoulder;
  double get filmicAmount => _filmicAmount;

  bool get filmGrainEnabled => _filmGrainEnabled;
  double get filmGrainIntensity => _filmGrainIntensity;
  double get filmGrainSize => _filmGrainSize;

  /// 当前套用的预设（null = 自定义）
  PostProcessPreset? get appliedPreset => _appliedPreset;

  /// 套用预设后又手工改过参数
  bool get presetModified =>
      _appliedPreset != null && _presetSignature != _stateSignature();

  /// GPU-next 渲染器下 mpv 不支持内置 `sharpen`，面板据此提示用户
  bool get sharpenAvailable => !DecodeSettings.instance.gpuNext;

  /// 当前挂着几个风格化效果（面板用来提示性能开销）
  int get activeStyleEffectCount => [
        _denoiseEnabled,
        _vignetteEnabled,
        _scanlinesEnabled,
        _naturalEnabled,
        _bloomEnabled,
        _cartoonEnabled,
        _whiteBalanceEnabled,
        _levelsEnabled,
        _filmicEnabled,
        _filmGrainEnabled,
      ].where((e) => e).length;

  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;
    _brightness = prefs.getDouble(_kBrightness) ?? 0;
    _contrast = prefs.getDouble(_kContrast) ?? 0;
    _gamma = prefs.getDouble(_kGamma) ?? 0;
    _saturation = prefs.getDouble(_kSaturation) ?? 0;
    _hue = prefs.getDouble(_kHue) ?? 0;
    _sharpenEnabled = prefs.getBool(_kSharpenEnabled) ?? false;
    _sharpenAmount = prefs.getDouble(_kSharpenAmount) ?? defaultSharpenAmount;
    _denoiseEnabled = prefs.getBool(_kDenoiseEnabled) ?? false;
    _denoiseStrength =
        prefs.getDouble(_kDenoiseStrength) ?? defaultDenoiseStrength;
    _denoiseRadius = prefs.getDouble(_kDenoiseRadius) ?? defaultDenoiseRadius;
    _debandEnabled = prefs.getBool(_kDebandEnabled) ?? false;
    _debandThreshold =
        prefs.getDouble(_kDebandThreshold) ?? defaultDebandThreshold;
    _debandRange = prefs.getDouble(_kDebandRange) ?? defaultDebandRange;
    _debandGrain = prefs.getDouble(_kDebandGrain) ?? defaultDebandGrain;
    _debandIterations =
        prefs.getDouble(_kDebandIterations) ?? defaultDebandIterations;
    _vignetteEnabled = prefs.getBool(_kVignetteEnabled) ?? false;
    _vignettePower = prefs.getDouble(_kVignettePower) ?? defaultVignettePower;
    _vignetteAspect = prefs.getDouble(_kVignetteAspect) ?? defaultVignetteAspect;
    _vignetteRadius = prefs.getDouble(_kVignetteRadius) ?? defaultVignetteRadius;
    _vignetteSoftness =
        prefs.getDouble(_kVignetteSoftness) ?? defaultVignetteSoftness;
    _scanlinesEnabled = prefs.getBool(_kScanlinesEnabled) ?? false;
    _scanlinesDensity =
        prefs.getDouble(_kScanlinesDensity) ?? defaultScanlinesDensity;
    _scanlinesIntensity =
        prefs.getDouble(_kScanlinesIntensity) ?? defaultScanlinesIntensity;
    _naturalEnabled = prefs.getBool(_kNaturalEnabled) ?? false;
    _naturalLuma = prefs.getDouble(_kNaturalLuma) ?? defaultNaturalLuma;
    _naturalChroma = prefs.getDouble(_kNaturalChroma) ?? defaultNaturalChroma;
    _bloomEnabled = prefs.getBool(_kBloomEnabled) ?? false;
    _bloomAmount = prefs.getDouble(_kBloomAmount) ?? defaultBloomAmount;
    _bloomSpread = prefs.getDouble(_kBloomSpread) ?? defaultBloomSpread;
    _cartoonEnabled = prefs.getBool(_kCartoonEnabled) ?? false;
    _cartoonStrength =
        prefs.getDouble(_kCartoonStrength) ?? defaultCartoonStrength;
    _whiteBalanceEnabled = prefs.getBool(_kWhiteBalanceEnabled) ?? false;
    _temperature = prefs.getDouble(_kTemperature) ?? defaultTemperature;
    _tint = prefs.getDouble(_kTint) ?? defaultTint;
    _levelsEnabled = prefs.getBool(_kLevelsEnabled) ?? false;
    _inBlack = prefs.getDouble(_kInBlack) ?? defaultInBlack;
    _inWhite = prefs.getDouble(_kInWhite) ?? defaultInWhite;
    _levelsGamma = prefs.getDouble(_kLevelsGamma) ?? defaultLevelsGamma;
    _filmicEnabled = prefs.getBool(_kFilmicEnabled) ?? false;
    _exposure = prefs.getDouble(_kExposure) ?? defaultExposure;
    _filmicToe = prefs.getDouble(_kFilmicToe) ?? defaultToe;
    _filmicShoulder = prefs.getDouble(_kFilmicShoulder) ?? defaultShoulder;
    _filmicAmount = prefs.getDouble(_kFilmicAmount) ?? defaultFilmicAmount;
    _filmGrainEnabled = prefs.getBool(_kFilmGrainEnabled) ?? false;
    _filmGrainIntensity =
        prefs.getDouble(_kFilmGrainIntensity) ?? defaultFilmGrainIntensity;
    _filmGrainSize = prefs.getDouble(_kFilmGrainSize) ?? defaultFilmGrainSize;
    notifyListeners();
  }

  /// 播放页打开媒体后调用：记住播放器、加载设置并整体应用一次
  Future<void> apply(Player player) async {
    _player = player;
    await ensureLoaded();
    await _applyAll();
  }

  /// 解除绑定（播放页 dispose）
  void detach() {
    _player = null;
  }

  // ── 基础调节 setter：即时改 mpv 属性，不重编译着色器 ──────

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    _persist();
    unawaited(_applyAll());
  }

  void setBrightness(double v) => _setBasic(() => _brightness = v, v, _brightness);
  void setContrast(double v) => _setBasic(() => _contrast = v, v, _contrast);
  void setGamma(double v) => _setBasic(() => _gamma = v, v, _gamma);
  void setSaturation(double v) => _setBasic(() => _saturation = v, v, _saturation);
  void setHue(double v) => _setBasic(() => _hue = v, v, _hue);

  void _setBasic(VoidCallback assign, double value, double current) {
    if (current == value) return;
    assign();
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setSharpenEnabled(bool value) {
    if (_sharpenEnabled == value) return;
    _sharpenEnabled = value;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setSharpenAmount(double v) {
    if (_sharpenAmount == v) return;
    _sharpenAmount = v;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setDenoiseEnabled(bool value) {
    if (_denoiseEnabled == value) return;
    _denoiseEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setDenoiseStrength(double v) {
    if (_denoiseStrength == v) return;
    _denoiseStrength = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setDenoiseRadius(double v) {
    if (_denoiseRadius == v) return;
    _denoiseRadius = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setDebandEnabled(bool value) {
    if (_debandEnabled == value) return;
    _debandEnabled = value;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setDebandThreshold(double v) {
    if (_debandThreshold == v) return;
    _debandThreshold = v;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setDebandRange(double v) {
    if (_debandRange == v) return;
    _debandRange = v;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setDebandGrain(double v) {
    if (_debandGrain == v) return;
    _debandGrain = v;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  void setDebandIterations(double v) {
    if (_debandIterations == v) return;
    _debandIterations = v;
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  // ── 风格化 setter：参数变了要重建着色器文件（防抖）────────

  void setVignetteEnabled(bool value) {
    if (_vignetteEnabled == value) return;
    _vignetteEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setVignettePower(double v) {
    if (_vignettePower == v) return;
    _vignettePower = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setVignetteAspect(double v) {
    if (_vignetteAspect == v) return;
    _vignetteAspect = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setVignetteRadius(double v) {
    if (_vignetteRadius == v) return;
    _vignetteRadius = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setVignetteSoftness(double v) {
    if (_vignetteSoftness == v) return;
    _vignetteSoftness = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 泛光（着色器）──────────────────────────────────────────

  void setBloomEnabled(bool value) {
    if (_bloomEnabled == value) return;
    _bloomEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setBloomAmount(double v) {
    if (_bloomAmount == v) return;
    _bloomAmount = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setBloomSpread(double v) {
    if (_bloomSpread == v) return;
    _bloomSpread = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 卡通（着色器）──────────────────────────────────────────

  void setCartoonEnabled(bool value) {
    if (_cartoonEnabled == value) return;
    _cartoonEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setCartoonStrength(double v) {
    if (_cartoonStrength == v) return;
    _cartoonStrength = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 白平衡 ────────────────────────────────────────────────

  void setWhiteBalanceEnabled(bool value) {
    if (_whiteBalanceEnabled == value) return;
    _whiteBalanceEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setTemperature(double v) {
    if (_temperature == v) return;
    _temperature = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setTint(double v) {
    if (_tint == v) return;
    _tint = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 色阶 ──────────────────────────────────────────────────

  void setLevelsEnabled(bool value) {
    if (_levelsEnabled == value) return;
    _levelsEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setInBlack(double v) {
    if (_inBlack == v) return;
    _inBlack = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setInWhite(double v) {
    if (_inWhite == v) return;
    _inWhite = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setLevelsGamma(double v) {
    if (_levelsGamma == v) return;
    _levelsGamma = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 胶片曲线 ──────────────────────────────────────────────

  void setFilmicEnabled(bool value) {
    if (_filmicEnabled == value) return;
    _filmicEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setExposure(double v) {
    if (_exposure == v) return;
    _exposure = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setFilmicToe(double v) {
    if (_filmicToe == v) return;
    _filmicToe = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setFilmicShoulder(double v) {
    if (_filmicShoulder == v) return;
    _filmicShoulder = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setFilmicAmount(double v) {
    if (_filmicAmount == v) return;
    _filmicAmount = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  // ── 胶片颗粒 ──────────────────────────────────────────────

  void setFilmGrainEnabled(bool value) {
    if (_filmGrainEnabled == value) return;
    _filmGrainEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setFilmGrainIntensity(double v) {
    if (_filmGrainIntensity == v) return;
    _filmGrainIntensity = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setFilmGrainSize(double v) {
    if (_filmGrainSize == v) return;
    _filmGrainSize = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setScanlinesEnabled(bool value) {
    if (_scanlinesEnabled == value) return;
    _scanlinesEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setScanlinesDensity(double v) {
    if (_scanlinesDensity == v) return;
    _scanlinesDensity = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setScanlinesIntensity(double v) {
    if (_scanlinesIntensity == v) return;
    _scanlinesIntensity = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setNaturalColorsEnabled(bool value) {
    if (_naturalEnabled == value) return;
    _naturalEnabled = value;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setNaturalLuma(double v) {
    if (_naturalLuma == v) return;
    _naturalLuma = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  void setNaturalChroma(double v) {
    if (_naturalChroma == v) return;
    _naturalChroma = v;
    notifyListeners();
    _persist();
    _scheduleShaderApply();
  }

  /// 恢复默认（总开关保留）
  void resetSettings() {
    _resetFieldsToDefaults();
    _appliedPreset = null;
    _presetSignature = null;
    notifyListeners();
    _persist();
    unawaited(_applyAll());
  }

  /// 只重置基础调节（亮度/对比/伽马/饱和度/色相）
  void resetBasicAdjustments() {
    _resetBasicFields();
    notifyListeners();
    _persist();
    unawaited(_applyProperties());
  }

  /// 只重置画面效果（所有效果开关与参数）
  void resetEffects() {
    _resetEffectFields();
    notifyListeners();
    _persist();
    unawaited(_applyAll());
  }

  /// 参数全部回默认（不动总开关、不动预设标记）
  void _resetFieldsToDefaults() {
    _resetBasicFields();
    _resetEffectFields();
  }

  void _resetBasicFields() {
    _brightness = 0;
    _contrast = 0;
    _gamma = 0;
    _saturation = 0;
    _hue = 0;
  }

  void _resetEffectFields() {
    _sharpenEnabled = false;
    _sharpenAmount = defaultSharpenAmount;
    _denoiseEnabled = false;
    _denoiseStrength = defaultDenoiseStrength;
    _denoiseRadius = defaultDenoiseRadius;
    _debandEnabled = false;
    _debandThreshold = defaultDebandThreshold;
    _debandRange = defaultDebandRange;
    _debandGrain = defaultDebandGrain;
    _debandIterations = defaultDebandIterations;
    _vignetteEnabled = false;
    _vignettePower = defaultVignettePower;
    _vignetteAspect = defaultVignetteAspect;
    _vignetteRadius = defaultVignetteRadius;
    _vignetteSoftness = defaultVignetteSoftness;
    _scanlinesEnabled = false;
    _scanlinesDensity = defaultScanlinesDensity;
    _scanlinesIntensity = defaultScanlinesIntensity;
    _naturalEnabled = false;
    _naturalLuma = defaultNaturalLuma;
    _naturalChroma = defaultNaturalChroma;
    _bloomEnabled = false;
    _bloomAmount = defaultBloomAmount;
    _bloomSpread = defaultBloomSpread;
    _cartoonEnabled = false;
    _cartoonStrength = defaultCartoonStrength;
    _whiteBalanceEnabled = false;
    _temperature = defaultTemperature;
    _tint = defaultTint;
    _levelsEnabled = false;
    _inBlack = defaultInBlack;
    _inWhite = defaultInWhite;
    _levelsGamma = defaultLevelsGamma;
    _filmicEnabled = false;
    _exposure = defaultExposure;
    _filmicToe = defaultToe;
    _filmicShoulder = defaultShoulder;
    _filmicAmount = defaultFilmicAmount;
    _filmGrainEnabled = false;
    _filmGrainIntensity = defaultFilmGrainIntensity;
    _filmGrainSize = defaultFilmGrainSize;
  }

  // ── 预设 ─────────────────────────────────────────────────

  /// 套用预设：先把参数复位，再按预设写入，最后只应用一次。
  ///
  /// 等价于用户在面板里手动把开关和滑杆拨到这一组值；之后继续改参数
  /// 就变成“已微调”（[presetModified]）。
  void applyPreset(PostProcessPreset preset) {
    _resetFieldsToDefaults();
    final f = preset.scale;
    switch (preset.group) {
      case PostProcessPresetGroup.clean:
        _applyCleanPreset(f);
      case PostProcessPresetGroup.film:
        _applyFilmPreset(f);
      case PostProcessPresetGroup.tv:
        _applyTvPreset(f);
      case PostProcessPresetGroup.lowBitrate:
        _applyLowBitratePreset(f);
      case PostProcessPresetGroup.streaming:
        _applyStreamingPreset(f);
      case PostProcessPresetGroup.style:
        switch (preset) {
          case PostProcessPreset.cinematic:
            _applyCinematicPreset();
          case PostProcessPreset.soft:
            _applySoftPreset();
          case PostProcessPreset.retro:
            _applyRetroPreset();
          default:
            break;
        }
    }
    _enabled = true;
    _appliedPreset = preset;
    _presetSignature = _stateSignature();
    notifyListeners();
    _persist();
    unawaited(_applyAll());
  }

  /// 净化：通用的“降噪 + 去色带 + 轻锐化”，不调色、不加对比
  void _applyCleanPreset(double f) {
    _denoiseEnabled = true;
    _denoiseStrength = 0.12 * f;
    _denoiseRadius = 1.0;
    _debandEnabled = true;
    _debandThreshold = 24.0 + 12.0 * (f - 1.0);
    _debandRange = 12.0 + 5.0 * (f - 1.0);
    _debandGrain = 12.0 + 10.0 * (f - 1.0);
    _debandIterations = 1;
    _sharpenEnabled = true;
    _sharpenAmount = 0.2 * f;
  }

  /// 胶片电影：黑位、褪色偏色、高光，外加很轻的锐化与颗粒
  void _applyFilmPreset(double f) {
    _levelsEnabled = true;
    _inBlack = 0.03 + 0.04 * f;
    _inWhite = 1.0 - 0.02 * f;
    _levelsGamma = 1.0 + 0.06 * f;
    _whiteBalanceEnabled = true;
    _temperature = 10.0 * f;
    _filmicEnabled = true;
    _exposure = 1.0 + 0.04 * f;
    _filmicToe = 1.0 + 0.2 * f;
    _filmicShoulder = 1.0 + 0.35 * f;
    _filmicAmount = 0.6 * f;
    _sharpenEnabled = true;
    _sharpenAmount = 0.18 * f;
    _filmGrainEnabled = true;
    _filmGrainIntensity = 0.015 * f;
    _filmGrainSize = 1.0;
    _contrast = 4.0 * f;
  }

  /// 老电视/录像带：噪点、偏色、色带，轻锐化
  void _applyTvPreset(double f) {
    _denoiseEnabled = true;
    _denoiseStrength = 0.12 + 0.1 * f;
    _denoiseRadius = 1.0;
    _whiteBalanceEnabled = true;
    _temperature = -6.0 * f;
    _debandEnabled = true;
    _debandThreshold = 32.0 + 12.0 * f;
    _debandRange = 10;
    _debandGrain = 20;
    _debandIterations = 1;
    _sharpenEnabled = true;
    _sharpenAmount = 0.15 * f;
    _contrast = 3.0 * f;
  }

  /// 低码率（VCD/DVD）：色带、块噪、糊
  void _applyLowBitratePreset(double f) {
    _debandEnabled = true;
    _debandThreshold = 40.0 + 16.0 * f;
    _debandRange = 16;
    _debandGrain = 24;
    _debandIterations = 1;
    _denoiseEnabled = true;
    _denoiseStrength = 0.12 + 0.08 * f;
    _denoiseRadius = 1.0;
    _sharpenEnabled = true;
    _sharpenAmount = 0.12 * f;
  }

  /// 现代流媒体：色带、暗场块，只做极轻的锐化
  void _applyStreamingPreset(double f) {
    _debandEnabled = true;
    _debandThreshold = 28.0 + 12.0 * f;
    _debandRange = 14;
    _debandGrain = 16;
    _debandIterations = 1;
    _sharpenEnabled = true;
    _sharpenAmount = 0.08 * f;
    _contrast = 2.0 * f;
  }

  /// 电影感：暗角 + 泛光 + 颗粒 + 一点对比与饱和
  void _applyCinematicPreset() {
    _vignetteEnabled = true;
    _vignettePower = 0.4;
    _vignetteRadius = 0.15;
    _vignetteSoftness = 0.6;
    _bloomEnabled = true;
    _bloomAmount = 0.25;
    _bloomSpread = 0.4;
    _filmGrainEnabled = true;
    _filmGrainIntensity = 0.02;
    _filmGrainSize = 1.0;
    _contrast = 6;
    _saturation = 3;
  }

  /// 柔和：负锐化，治现代数码过锐
  void _applySoftPreset() {
    _sharpenEnabled = true;
    _sharpenAmount = -0.35;
    _saturation = -3;
  }

  /// 复古：暖白平衡 + 暗角 + 大颗粒
  void _applyRetroPreset() {
    _filmGrainEnabled = true;
    _filmGrainIntensity = 0.05;
    _filmGrainSize = 2.0;
    _whiteBalanceEnabled = true;
    _temperature = 18;
    _tint = 4;
    _vignetteEnabled = true;
    _vignettePower = 0.45;
    _contrast = 4;
  }

  /// 全部参数拼成一个签名，用于判断预设之后有没有被手工改过
  String _stateSignature() => <Object>[
        _enabled,
        _brightness,
        _contrast,
        _gamma,
        _saturation,
        _hue,
        _sharpenEnabled,
        _sharpenAmount,
        _denoiseEnabled,
        _denoiseStrength,
        _denoiseRadius,
        _debandEnabled,
        _debandThreshold,
        _debandRange,
        _debandGrain,
        _debandIterations,
        _vignetteEnabled,
        _vignettePower,
        _vignetteAspect,
        _vignetteRadius,
        _vignetteSoftness,
        _scanlinesEnabled,
        _scanlinesDensity,
        _scanlinesIntensity,
        _naturalEnabled,
        _naturalLuma,
        _naturalChroma,
        _bloomEnabled,
        _bloomAmount,
        _bloomSpread,
        _cartoonEnabled,
        _cartoonStrength,
        _whiteBalanceEnabled,
        _temperature,
        _tint,
        _levelsEnabled,
        _inBlack,
        _inWhite,
        _levelsGamma,
        _filmicEnabled,
        _exposure,
        _filmicToe,
        _filmicShoulder,
        _filmicAmount,
        _filmGrainEnabled,
        _filmGrainIntensity,
        _filmGrainSize,
      ].join('|');

  // ── 应用 ─────────────────────────────────────────────────

  Future<void> _applyAll() async {
    await _applyProperties();
    await _applyShaders();
  }

  Future<void> _applyProperties() async {
    final player = _player;
    if (player == null) return;
    try {
      final native = player.platform as NativePlayer;
      await native.waitForPlayerInitialization;
      await native.waitForVideoControllerInitializationIfAttached;
      Future<void> set(String name, Object value) async {
        try {
          await native.setProperty(name, '$value');
        } catch (_) {
          // 个别渲染器不认某个属性：忽略，不影响其它项
        }
      }

      final on = _enabled;
      await set('brightness', on ? _brightness.round() : 0);
      await set('contrast', on ? _contrast.round() : 0);
      await set('gamma', on ? _gamma.round() : 0);
      await set('saturation', on ? _saturation.round() : 0);
      await set('hue', on ? _hue.round() : 0);

      final deband = on && _debandEnabled;
      await set('deband', deband ? 'yes' : 'no');
      if (deband) {
        await set('deband-threshold', _debandThreshold.round());
        await set('deband-range', _debandRange.round());
        await set('deband-grain', _debandGrain.round());
        await set('deband-iterations', _debandIterations.round());
      }

      // `sharpen` 只对 vo=gpu 生效（GPU-next 下 mpv 直接忽略）
      final sharpen = on && _sharpenEnabled && sharpenAvailable;
      await set('sharpen', sharpen ? _sharpenAmount.toStringAsFixed(2) : '0');
    } catch (e) {
      debugPrint('PostProcessService: 应用基础调节失败: $e');
    }
  }

  void _scheduleShaderApply() {
    _shaderTimer?.cancel();
    _shaderTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(_applyShaders());
    });
  }

  Future<void> _applyShaders() async {
    final player = _player;
    if (player == null) return;
    try {
      final sources = <String, String>{};
      if (_enabled) {
        // 链顺序：降噪 → 色阶/白平衡/胶片曲线 → 局部增强 → 几何/明暗 → 风格化 → 颗粒
        if (_denoiseEnabled) {
          sources['denoise.glsl'] = denoiseShader(
            strength: _denoiseStrength,
            radius: _denoiseRadius,
          );
        }
        if (_levelsEnabled) {
          sources['levels.glsl'] = levelsShader(
            inBlack: _inBlack,
            inWhite: _inWhite,
            gamma: _levelsGamma,
          );
        }
        if (_whiteBalanceEnabled) {
          sources['white_balance.glsl'] = whiteBalanceShader(
            temperature: _temperature,
            tint: _tint,
          );
        }
        if (_filmicEnabled) {
          sources['filmic_curve.glsl'] = filmicCurveShader(
            exposure: _exposure,
            toe: _filmicToe,
            shoulder: _filmicShoulder,
            amount: _filmicAmount,
          );
        }
        if (_naturalEnabled) {
          sources['natural_colors.glsl'] = naturalColorsShader(
            luma: _naturalLuma,
            chroma: _naturalChroma,
          );
        }
        if (_bloomEnabled) {
          sources['bloom.glsl'] = bloomShader(
            amount: _bloomAmount,
            spread: _bloomSpread,
          );
        }
        if (_vignetteEnabled) {
          sources['vignette.glsl'] = vignetteShader(
            power: _vignettePower,
            aspect: _vignetteAspect,
            radius: _vignetteRadius,
            softness: _vignetteSoftness,
          );
        }
        if (_scanlinesEnabled) {
          sources['scanlines.glsl'] = scanlinesShader(
            density: _scanlinesDensity,
            intensity: _scanlinesIntensity,
          );
        }
        if (_cartoonEnabled) {
          sources['cartoon.glsl'] = cartoonShader(edgeStrength: _cartoonStrength);
        }
        if (_filmGrainEnabled) {
          sources['film_grain.glsl'] = filmGrainShader(
            intensity: _filmGrainIntensity,
            size: _filmGrainSize,
          );
        }
      }
      final dir = await _ensureShaderDir();
      final paths = <String>[];
      final currentFiles = <String>{};
      for (final entry in sources.entries) {
        // 文件名带内容 hash：参数一变就是新路径，mpv 才会重载着色器
        // （路径不变时 mpv 认为链没变，不会重读已改写的文件）
        final base = entry.key.substring(0, entry.key.lastIndexOf('.'));
        final fileName = postProcessShaderFileName(base, entry.value);
        final file = File(p.join(dir.path, fileName));
        if (!await file.exists()) {
          await file.writeAsString(entry.value, flush: true);
        }
        paths.add(file.path);
        currentFiles.add(file.path);
      }
      await PlayerShaderPipeline.instance.setPost(player, paths);

      // 上一版的文件已不在链上：删掉，避免参数滑一次攒一个文件
      final stale = _shaderFiles.difference(currentFiles);
      _shaderFiles
        ..clear()
        ..addAll(currentFiles);
      for (final old in stale) {
        try {
          await File(old).delete();
        } catch (_) {
          // 删除失败不影响播放（下次再清）
        }
      }
    } catch (e) {
      debugPrint('PostProcessService: 应用着色器失败: $e');
    }
  }

  Future<Directory> _ensureShaderDir() async {
    final cached = _shaderDir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'post_process'));
    await dir.create(recursive: true);
    _shaderDir = dir;
    return dir;
  }

  // ── 持久化（写盘防抖，滑杆拖动时不刷盘）──────────────────

  void _persist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveNow());
    });
  }

  Future<void> _saveNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, _enabled);
      await prefs.setDouble(_kBrightness, _brightness);
      await prefs.setDouble(_kContrast, _contrast);
      await prefs.setDouble(_kGamma, _gamma);
      await prefs.setDouble(_kSaturation, _saturation);
      await prefs.setDouble(_kHue, _hue);
      await prefs.setBool(_kSharpenEnabled, _sharpenEnabled);
      await prefs.setDouble(_kSharpenAmount, _sharpenAmount);
      await prefs.setBool(_kDenoiseEnabled, _denoiseEnabled);
      await prefs.setDouble(_kDenoiseStrength, _denoiseStrength);
      await prefs.setDouble(_kDenoiseRadius, _denoiseRadius);
      await prefs.setBool(_kDebandEnabled, _debandEnabled);
      await prefs.setDouble(_kDebandThreshold, _debandThreshold);
      await prefs.setDouble(_kDebandRange, _debandRange);
      await prefs.setDouble(_kDebandGrain, _debandGrain);
      await prefs.setDouble(_kDebandIterations, _debandIterations);
      await prefs.setBool(_kVignetteEnabled, _vignetteEnabled);
      await prefs.setDouble(_kVignettePower, _vignettePower);
      await prefs.setDouble(_kVignetteAspect, _vignetteAspect);
      await prefs.setDouble(_kVignetteRadius, _vignetteRadius);
      await prefs.setDouble(_kVignetteSoftness, _vignetteSoftness);
      await prefs.setBool(_kScanlinesEnabled, _scanlinesEnabled);
      await prefs.setDouble(_kScanlinesDensity, _scanlinesDensity);
      await prefs.setDouble(_kScanlinesIntensity, _scanlinesIntensity);
      await prefs.setBool(_kNaturalEnabled, _naturalEnabled);
      await prefs.setDouble(_kNaturalLuma, _naturalLuma);
      await prefs.setDouble(_kNaturalChroma, _naturalChroma);
      await prefs.setBool(_kBloomEnabled, _bloomEnabled);
      await prefs.setDouble(_kBloomAmount, _bloomAmount);
      await prefs.setDouble(_kBloomSpread, _bloomSpread);
      await prefs.setBool(_kCartoonEnabled, _cartoonEnabled);
      await prefs.setDouble(_kCartoonStrength, _cartoonStrength);
      await prefs.setBool(_kWhiteBalanceEnabled, _whiteBalanceEnabled);
      await prefs.setDouble(_kTemperature, _temperature);
      await prefs.setDouble(_kTint, _tint);
      await prefs.setBool(_kLevelsEnabled, _levelsEnabled);
      await prefs.setDouble(_kInBlack, _inBlack);
      await prefs.setDouble(_kInWhite, _inWhite);
      await prefs.setDouble(_kLevelsGamma, _levelsGamma);
      await prefs.setBool(_kFilmicEnabled, _filmicEnabled);
      await prefs.setDouble(_kExposure, _exposure);
      await prefs.setDouble(_kFilmicToe, _filmicToe);
      await prefs.setDouble(_kFilmicShoulder, _filmicShoulder);
      await prefs.setDouble(_kFilmicAmount, _filmicAmount);
      await prefs.setBool(_kFilmGrainEnabled, _filmGrainEnabled);
      await prefs.setDouble(_kFilmGrainIntensity, _filmGrainIntensity);
      await prefs.setDouble(_kFilmGrainSize, _filmGrainSize);
    } catch (e) {
      debugPrint('PostProcessService: 保存设置失败: $e');
    }
  }

  /// 测试用：恢复默认并清掉加载/防抖状态（单例在测试间共享）
  @visibleForTesting
  void resetForTest() {
    _persistTimer?.cancel();
    _shaderTimer?.cancel();
    _loadFuture = null;
    _player = null;
    _shaderDir = null;
    _shaderFiles.clear();
    _enabled = false;
    _brightness = 0;
    _contrast = 0;
    _gamma = 0;
    _saturation = 0;
    _hue = 0;
    _sharpenEnabled = false;
    _sharpenAmount = defaultSharpenAmount;
    _denoiseEnabled = false;
    _denoiseStrength = defaultDenoiseStrength;
    _denoiseRadius = defaultDenoiseRadius;
    _debandEnabled = false;
    _debandThreshold = defaultDebandThreshold;
    _debandRange = defaultDebandRange;
    _debandGrain = defaultDebandGrain;
    _debandIterations = defaultDebandIterations;
    _vignetteEnabled = false;
    _vignettePower = defaultVignettePower;
    _vignetteAspect = defaultVignetteAspect;
    _vignetteRadius = defaultVignetteRadius;
    _vignetteSoftness = defaultVignetteSoftness;
    _scanlinesEnabled = false;
    _scanlinesDensity = defaultScanlinesDensity;
    _scanlinesIntensity = defaultScanlinesIntensity;
    _naturalEnabled = false;
    _naturalLuma = defaultNaturalLuma;
    _naturalChroma = defaultNaturalChroma;
    _bloomEnabled = false;
    _bloomAmount = defaultBloomAmount;
    _bloomSpread = defaultBloomSpread;
    _cartoonEnabled = false;
    _cartoonStrength = defaultCartoonStrength;
    _whiteBalanceEnabled = false;
    _temperature = defaultTemperature;
    _tint = defaultTint;
    _levelsEnabled = false;
    _inBlack = defaultInBlack;
    _inWhite = defaultInWhite;
    _levelsGamma = defaultLevelsGamma;
    _filmicEnabled = false;
    _exposure = defaultExposure;
    _filmicToe = defaultToe;
    _filmicShoulder = defaultShoulder;
    _filmicAmount = defaultFilmicAmount;
    _filmGrainEnabled = false;
    _filmGrainIntensity = defaultFilmGrainIntensity;
    _filmGrainSize = defaultFilmGrainSize;
    _appliedPreset = null;
    _presetSignature = null;
    notifyListeners();
  }
}
