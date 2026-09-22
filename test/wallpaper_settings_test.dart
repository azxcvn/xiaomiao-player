import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/wallpaper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 自定义壁纸设置测试：默认值、持久化、范围钳制、生效判定、
/// 图片文件丢失兜底、清除（7 项全复位）、拷贝失败不改设置。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sourceImage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WallpaperSettings.instance.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('wallpaper_settings_test');
    WallpaperSettings.debugDirOverride = tempDir.path;
    // 一个「源图片」：内容不重要，只要求存在且非空
    sourceImage = File(p.join(tempDir.path, 'src.png'))
      ..writeAsBytesSync(List<int>.filled(64, 7));
  });

  tearDown(() {
    WallpaperSettings.instance.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final s = WallpaperSettings.instance;

  Future<bool> applyDefaults({String? sourcePath}) => s.apply(
        sourcePath: sourcePath,
        scale: WallpaperSettings.defaultScale,
        offsetX: WallpaperSettings.defaultOffset,
        offsetY: WallpaperSettings.defaultOffset,
        scaleMode: WallpaperScaleMode.fit,
        blur: WallpaperSettings.defaultBlur,
        opacity: WallpaperSettings.defaultOpacity,
      );

  test('默认值：无壁纸 / 缩放 1 / 偏移 0 / 适应 / 模糊 0 / 透明度 1', () async {
    await s.ensureLoaded();
    expect(s.active, isFalse);
    expect(s.path, isNull);
    expect(s.scale, WallpaperSettings.defaultScale);
    expect(s.offsetX, WallpaperSettings.defaultOffset);
    expect(s.offsetY, WallpaperSettings.defaultOffset);
    expect(s.scaleMode, WallpaperScaleMode.fit);
    expect(s.blur, WallpaperSettings.defaultBlur);
    expect(s.opacity, WallpaperSettings.defaultOpacity);
  });

  test('保存：图片被拷进应用目录（带时间戳的新文件），参数一并持久化', () async {
    final ok = await s.apply(
      sourcePath: sourceImage.path,
      scale: 2.5,
      offsetX: 0.5,
      offsetY: -0.5,
      scaleMode: WallpaperScaleMode.fill,
      blur: 20,
      opacity: 0.6,
    );

    expect(ok, isTrue);
    expect(s.active, isTrue);
    final saved = File(s.path!);
    expect(saved.existsSync(), isTrue, reason: '图片必须真被拷进应用目录');
    expect(p.dirname(saved.path), contains('wallpaper'));
    expect(saved.path, isNot(sourceImage.path), reason: '不能直接引用源路径');
    expect(saved.lengthSync(), sourceImage.lengthSync());

    // 模拟重启
    WallpaperSettings.instance.resetForTest();
    WallpaperSettings.debugDirOverride = tempDir.path;
    await s.ensureLoaded();
    expect(s.path, saved.path);
    expect(s.scale, 2.5);
    expect(s.offsetX, 0.5);
    expect(s.offsetY, -0.5);
    expect(s.scaleMode, WallpaperScaleMode.fill);
    expect(s.blur, 20);
    expect(s.opacity, 0.6);
  });

  test('替换壁纸：旧文件被删掉（不留垃圾）', () async {
    await applyDefaults(sourcePath: sourceImage.path);
    final first = s.path!;
    final second = File(p.join(tempDir.path, 'src2.jpg'))
      ..writeAsBytesSync(List<int>.filled(32, 9));

    expect(await applyDefaults(sourcePath: second.path), isTrue);
    expect(s.path, isNot(first));
    expect(File(first).existsSync(), isFalse, reason: '旧壁纸应被删除');
    expect(File(s.path!).existsSync(), isTrue);
  });

  test('只改参数（sourcePath 为 null）：图片不动，参数更新', () async {
    await applyDefaults(sourcePath: sourceImage.path);
    final path = s.path!;

    final ok = await s.apply(
      scale: 3,
      offsetX: -1,
      offsetY: 1,
      scaleMode: WallpaperScaleMode.fill,
      blur: 40,
      opacity: 0.2,
    );

    expect(ok, isTrue);
    expect(s.path, path);
    expect(File(path).existsSync(), isTrue);
    expect(s.scale, 3);
    expect(s.blur, 40);
  });

  test('参数超出范围被钳制（缩放 1–3 / 偏移 ±1 / 模糊 0–40 / 透明度 0–1）', () async {
    await applyDefaults(sourcePath: sourceImage.path);
    await s.apply(
      scale: 99,
      offsetX: -5,
      offsetY: 5,
      scaleMode: WallpaperScaleMode.fit,
      blur: -10,
      opacity: 3,
    );
    expect(s.scale, WallpaperSettings.maxScale);
    expect(s.offsetX, WallpaperSettings.minOffset);
    expect(s.offsetY, WallpaperSettings.maxOffset);
    expect(s.blur, WallpaperSettings.minBlur);
    expect(s.opacity, WallpaperSettings.maxOpacity);

    await s.apply(
      scale: 0.1,
      offsetX: 0,
      offsetY: 0,
      scaleMode: WallpaperScaleMode.fit,
      blur: 100,
      opacity: -1,
    );
    expect(s.scale, WallpaperSettings.minScale);
    expect(s.blur, WallpaperSettings.maxBlur);
    expect(s.opacity, WallpaperSettings.minOpacity);
  });

  test('源图不存在 / 空文件：保存失败且不改动已有设置', () async {
    await applyDefaults(sourcePath: sourceImage.path);
    final keepPath = s.path!;
    final keepScale = s.scale;

    expect(await applyDefaults(sourcePath: p.join(tempDir.path, 'nope.png')),
        isFalse);
    final empty = File(p.join(tempDir.path, 'empty.png'))..writeAsBytesSync([]);
    expect(await applyDefaults(sourcePath: empty.path), isFalse);

    expect(s.path, keepPath);
    expect(s.scale, keepScale);
  });

  test('没有图且没有源图时保存失败（不能凭空生效）', () async {
    expect(await applyDefaults(), isFalse);
    expect(s.active, isFalse);
  });

  test('图片文件丢失：重启读盘时静默回落「无壁纸」', () async {
    await applyDefaults(sourcePath: sourceImage.path);
    final saved = s.path!;
    File(saved).deleteSync();

    WallpaperSettings.instance.resetForTest();
    WallpaperSettings.debugDirOverride = tempDir.path;
    await s.ensureLoaded();

    expect(s.path, isNull);
    expect(s.active, isFalse, reason: '不能挂着不存在的图（否则透明底色会露出黑洞）');
  });

  test('清除：删文件 + 7 项一起回默认', () async {
    await s.apply(
      sourcePath: sourceImage.path,
      scale: 2,
      offsetX: 0.3,
      offsetY: -0.3,
      scaleMode: WallpaperScaleMode.fill,
      blur: 15,
      opacity: 0.5,
    );
    final saved = s.path!;

    await s.clear();

    expect(s.active, isFalse);
    expect(s.path, isNull);
    expect(s.scale, WallpaperSettings.defaultScale);
    expect(s.offsetX, WallpaperSettings.defaultOffset);
    expect(s.offsetY, WallpaperSettings.defaultOffset);
    expect(s.scaleMode, WallpaperScaleMode.fit);
    expect(s.blur, WallpaperSettings.defaultBlur);
    expect(s.opacity, WallpaperSettings.defaultOpacity);
    expect(File(saved).existsSync(), isFalse, reason: '清除要顺手删掉文件');

    // 清除后重启仍是「无壁纸」（键被移除，不留残值）
    WallpaperSettings.instance.resetForTest();
    WallpaperSettings.debugDirOverride = tempDir.path;
    await s.ensureLoaded();
    expect(s.active, isFalse);
    expect(s.scale, WallpaperSettings.defaultScale);
  });

  test('变更会通知监听者（AppFrame / 外观页刷新依据）', () async {
    var notified = 0;
    void listener() => notified++;
    s.addListener(listener);
    addTearDown(() => s.removeListener(listener));

    await applyDefaults(sourcePath: sourceImage.path);
    expect(notified, greaterThan(0));

    final before = notified;
    await s.clear();
    expect(notified, greaterThan(before));
  });

  test('ensureLoaded 复用同一个 load Future', () async {
    final a = s.ensureLoaded();
    final b = s.ensureLoaded();
    expect(identical(a, b), isTrue);
  });

  test('脏数据（未知缩放模式 / 越界数值）被安全兜底', () async {
    SharedPreferences.setMockInitialValues({
      'wallpaper_file': '',
      'wallpaper_scale': 99.0,
      'wallpaper_offset_x': -9.0,
      'wallpaper_scale_mode': 'not-a-mode',
      'wallpaper_blur': 999.0,
      'wallpaper_opacity': 5.0,
    });
    WallpaperSettings.instance.resetForTest();
    WallpaperSettings.debugDirOverride = tempDir.path;

    await s.ensureLoaded();

    expect(s.active, isFalse, reason: '空路径 = 无壁纸');
    expect(s.scale, WallpaperSettings.maxScale);
    expect(s.offsetX, WallpaperSettings.minOffset);
    expect(s.scaleMode, WallpaperScaleMode.fit);
    expect(s.blur, WallpaperSettings.maxBlur);
    expect(s.opacity, WallpaperSettings.maxOpacity);
  });
}
