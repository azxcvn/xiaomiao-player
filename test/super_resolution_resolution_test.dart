import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:moumou/models/super_resolution_mode.dart';
import 'package:moumou/services/player_shader_pipeline.dart';
import 'package:moumou/services/super_resolution_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlayerShaderPipeline.instance.resetForTest();
    SuperResolutionService.instance.reset();
    await SuperResolutionService.instance.setMode(SuperResolutionMode.a);
    await SuperResolutionService.instance.setRemember(true);
  });

  for (final params in [
    const VideoParams(),
    const VideoParams(w: 3840, h: 2160),
    const VideoParams(w: 7680, h: 4320),
  ]) {
    test('源尺寸 ${params.w}×${params.h}、显示尺寸未知时不保留超分链', () async {
      final native = _ShaderPlayer();
      final player = Player(platformPlayer: native);
      addTearDown(native.dispose);
      native.state = PlayerState(videoParams: params);
      await PlayerShaderPipeline.instance.setAnime(player, [
        '/remembered.glsl',
      ]);
      native.commands.clear();

      await SuperResolutionService.instance.apply(player);

      expect(native.commands, [
        ['change-list', 'glsl-shaders', 'clr', ''],
      ]);
      expect(SuperResolutionService.instance.mode, SuperResolutionMode.a);
      expect(SuperResolutionService.instance.remember, isTrue);
    });
  }

  test('尺寸延迟到达或切到 4K/8K 时重新禁用；重复尺寸不重复应用', () async {
    final native = _ShaderPlayer();
    final player = Player(platformPlayer: native);
    addTearDown(native.dispose);
    await PlayerShaderPipeline.instance.setAnime(player, ['/remembered.glsl']);
    native.commands.clear();
    final subscription = SuperResolutionService.instance.watchVideoResolution(
      player,
    );
    addTearDown(subscription.cancel);

    for (final params in [
      const VideoParams(),
      const VideoParams(w: 3840, h: 2160),
      const VideoParams(w: 7680, h: 4320),
    ]) {
      final previousCalls = native.commands.length;
      native.reportVideo(params);
      await Future<void>.delayed(Duration.zero);
      expect(native.commands.length, previousCalls + 1);
      expect(native.commands.last, ['change-list', 'glsl-shaders', 'clr', '']);
    }
    native.reportVideo(const VideoParams(w: 7680, h: 4320));
    await Future<void>.delayed(Duration.zero);
    expect(native.commands, hasLength(3));

    await subscription.cancel();
    native.reportVideo(const VideoParams(w: 3840, h: 2160));
    await Future<void>.delayed(Duration.zero);
    expect(native.commands, hasLength(3));
    expect(SuperResolutionService.instance.mode, SuperResolutionMode.a);
  });

  test('4K 关闭超分时保留独立后处理链', () async {
    final native = _ShaderPlayer();
    final player = Player(platformPlayer: native);
    addTearDown(native.dispose);
    native.state = const PlayerState(
      videoParams: VideoParams(w: 3840, h: 2160),
    );
    await PlayerShaderPipeline.instance.setAnime(player, ['/remembered.glsl']);
    await PlayerShaderPipeline.instance.setPost(player, ['/color.glsl']);
    native.commands.clear();

    await SuperResolutionService.instance.apply(player);

    expect(native.commands, [
      ['change-list', 'glsl-shaders', 'set', '/color.glsl'],
    ]);
    expect(SuperResolutionService.instance.remember, isTrue);
  });

  test('尺寸未就绪先等待，普通视频允许应用，4K/8K 保持禁用', () {
    expect(canApplyAnime4kResolution(0, 0), isFalse);
    expect(canApplyAnime4kResolution(1920, 0), isFalse);
    expect(canApplyAnime4kResolution(1280, 720), isTrue);
    expect(canApplyAnime4kResolution(1920, 1080), isTrue);
    expect(canApplyAnime4kResolution(2560, 1440), isTrue);
    expect(canApplyAnime4kResolution(3840, 2160), isFalse);
    expect(canApplyAnime4kResolution(7680, 4320), isFalse);
    expect(canApplyAnime4kResolution(2160, 3840), isFalse);
  });
}

class _ShaderPlayer implements NativePlayer {
  final commands = <List<String>>[];
  final _memory = _MemoryPlayer();

  @override
  PlayerState get state => _memory.state;

  @override
  set state(PlayerState value) => _memory.state = value;

  @override
  PlayerStream get stream => _memory.stream;

  @override
  Future<void> dispose({bool synchronized = true}) => _memory.dispose();

  void reportVideo(VideoParams params) {
    state = PlayerState(videoParams: params);
    _memory.videoParamsController.add(params);
  }

  @override
  Future<void> get waitForPlayerInitialization async {}

  @override
  Future<void> get waitForVideoControllerInitializationIfAttached async {}

  @override
  Future<void> command(
    List<String> command, {
    bool waitForInitialization = true,
  }) async {
    commands.add(List.of(command));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

class _MemoryPlayer extends PlatformPlayer {
  _MemoryPlayer() : super(configuration: const PlayerConfiguration());
}
