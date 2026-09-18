import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/subtitle_track.dart';
import 'package:moumou/services/subtitle_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubtitleSettings.instance.reset();
  });

  test('默认值（工作.md 阶段1 第 3 点）', () {
    final s = SubtitleSettings.instance;
    expect(s.delay, 0);
    expect(s.scale, 1.0);
    expect(s.position, 100);
    expect(s.align, SubtitleAlign.center);
    expect(s.color, '#FFFFFF');
    expect(s.font, 'auto');
    expect(s.fontSourceDir, '');
    // 默认尊重内嵌字幕自带样式与字体
    expect(s.overrideEmbeddedStyle, isFalse);
  });

  test('外挂字幕记忆有容量上限，超额淘汰最久未用（§3-14）', () async {
    final s = SubtitleSettings.instance;
    for (var i = 0; i < SubtitleSettings.maxRememberedVideos + 1; i++) {
      await s.addImportedSubtitleFor('/v/$i.mp4', '/subs/$i.ass');
    }
    // 最早那条被淘汰，最新那条在
    expect(s.getImportedSubtitlesFor('/v/0.mp4'), isEmpty);
    expect(
      s.getImportedSubtitlesFor(
        '/v/${SubtitleSettings.maxRememberedVideos}.mp4',
      ),
      ['/subs/${SubtitleSettings.maxRememberedVideos}.ass'],
    );
    // 重启后仍是裁剪后的规模（说明真的写盘了，不是只在内存里裁）
    await s.load();
    var remembered = 0;
    for (var i = 0; i <= SubtitleSettings.maxRememberedVideos; i++) {
      if (s.getImportedSubtitlesFor('/v/$i.mp4').isNotEmpty) remembered++;
    }
    expect(remembered, SubtitleSettings.maxRememberedVideos);
  });

  test('字幕延迟：设置/持久化/±60 范围钳制/快捷叠加', () async {
    final s = SubtitleSettings.instance;
    await s.setDelay(1.5);
    expect(s.delay, 1.5);
    await s.load(); // 模拟重启
    expect(s.delay, 1.5);
    // 快捷叠加：+0.5 → 2.0；-1.0 → 1.0
    await s.adjustDelay(0.5);
    expect(s.delay, 2.0);
    await s.adjustDelay(-1.0);
    expect(s.delay, 1.0);
    // 范围钳制 -60 ~ +60
    await s.adjustDelay(999);
    expect(s.delay, SubtitleSettings.maxDelay);
    await s.adjustDelay(-999);
    expect(s.delay, SubtitleSettings.minDelay);
  });

  test('字幕样式：大小/颜色/内嵌样式覆盖持久化', () async {
    final s = SubtitleSettings.instance;
    await s.setScale(1.8);
    await s.setColor('#FFEB3B');
    await s.setOverrideEmbeddedStyle(true);
    await s.load();
    expect(s.scale, 1.8);
    expect(s.color, '#FFEB3B');
    expect(s.overrideEmbeddedStyle, isTrue);
    // 大小范围钳制 0.5 – 3.0
    await s.setScale(0.1);
    expect(s.scale, SubtitleSettings.minScale);
    await s.setScale(9.9);
    expect(s.scale, SubtitleSettings.maxScale);
  });

  test('背景框大小（sub-shadow-offset）：持久化与 0–20 钳制', () async {
    final s = SubtitleSettings.instance;
    expect(s.shadowOffset, 0);
    await s.setShadowOffset(4);
    expect(s.shadowOffset, 4);
    await s.load(); // 模拟重启
    expect(s.shadowOffset, 4);
    await s.setShadowOffset(-5);
    expect(s.shadowOffset, 0);
    await s.setShadowOffset(999);
    expect(s.shadowOffset, SubtitleSettings.maxStyleValue);
  });

  test('字幕杂项：垂直位置/水平对齐持久化', () async {
    final s = SubtitleSettings.instance;
    await s.setPosition(70);
    await s.setAlign(SubtitleAlign.left);
    await s.load();
    expect(s.position, 70);
    expect(s.align, SubtitleAlign.left);
    // 位置范围钳制 0 – 100
    await s.setPosition(-10);
    expect(s.position, SubtitleSettings.minPos);
    await s.setPosition(999);
    expect(s.position, SubtitleSettings.maxPos);
  });

  test('字幕字体：默认 auto 跟随系统字库 /system/fonts', () async {
    final s = SubtitleSettings.instance;
    expect(s.font, 'auto');
    await s.setFont('auto', '');
    expect(s.font, 'auto');
  });

  test('字体源目录：设置/持久化/清除（工作.md 第 1 点：目录选择记忆）', () async {
    final s = SubtitleSettings.instance;
    expect(s.fontSourceDir, '');
    const uri =
        'content://com.android.externalstorage.documents/tree/primary%3AFonts';
    await s.setFontSourceDir(uri);
    expect(s.fontSourceDir, uri);
    await s.load(); // 模拟重启
    expect(s.fontSourceDir, uri);
    await s.setFontSourceDir(''); // 清除目录
    expect(s.fontSourceDir, '');
    await s.load();
    expect(s.fontSourceDir, '');
  });

  test('描边模式：默认描边（mpv 默认值），设置后持久化', () async {
    final s = SubtitleSettings.instance;
    expect(s.borderStyle, SubtitleBorderStyle.outline);
    await s.setBorderStyle(SubtitleBorderStyle.none);
    expect(s.borderStyle, SubtitleBorderStyle.none);
    await s.load();
    expect(s.borderStyle, SubtitleBorderStyle.none);
    await s.setBorderStyle(SubtitleBorderStyle.box);
    expect(s.borderStyle, SubtitleBorderStyle.box);
    // 清掉背景色后不该停在「背景框」（背景色才是它的驱动源，见 setBackColor）
    await s.setBackColor(null);
    expect(s.borderStyle, SubtitleBorderStyle.outline);
  });

  test('背景颜色隐式驱动描边模式：有背景色 → 背景框；选「无」→ 描边', () async {
    final s = SubtitleSettings.instance;
    expect(s.backColor, isNull);
    expect(s.borderStyle, SubtitleBorderStyle.outline);

    await s.setBackColor('#80000000');
    expect(s.backColor, '#80000000');
    // mpv 只在背景框模式下画 sub-back-color，所以必须联动
    expect(s.borderStyle, SubtitleBorderStyle.box);

    await s.load(); // 模拟重启：两个值都要自洽地回来
    expect(s.backColor, '#80000000');
    expect(s.borderStyle, SubtitleBorderStyle.box);

    await s.setBackColor(null);
    expect(s.backColor, isNull);
    expect(s.borderStyle, SubtitleBorderStyle.outline);
    await s.load();
    expect(s.backColor, isNull);
    expect(s.borderStyle, SubtitleBorderStyle.outline);
  });

  test('历史持久化值兼容：旧值 flat/outline/box 映射到 mpv 0.38+ 的合法取值', () async {
    final s = SubtitleSettings.instance;
    // 旧版本写下的 'flat'（默认值）→ 无边框
    SharedPreferences.setMockInitialValues({'subtitle_settings_border_style': 'flat'});
    await s.load();
    expect(s.borderStyle, SubtitleBorderStyle.none);
    // 旧版本写下的 'outline' → 描边
    SharedPreferences.setMockInitialValues({'subtitle_settings_border_style': 'outline'});
    await s.load();
    expect(s.borderStyle, SubtitleBorderStyle.outline);
    // 旧版本写下的 'box' 但没有背景色 → 回落描边（模式跟随背景色，见 setBackColor）
    SharedPreferences.setMockInitialValues({'subtitle_settings_border_style': 'box'});
    await s.load();
    expect(s.borderStyle, SubtitleBorderStyle.outline);
    // 未知值 → 回落描边（mpv 自己的默认值）
    SharedPreferences.setMockInitialValues({'subtitle_settings_border_style': '???'});
    await s.load();
    expect(s.borderStyle, SubtitleBorderStyle.outline);
  });

  test('历史数据自洽修复：有背景色但模式不是背景框 → 载入时纠正为背景框', () async {
    final s = SubtitleSettings.instance;
    SharedPreferences.setMockInitialValues({
      'subtitle_settings_back_color': '#80000000',
      'subtitle_settings_border_style': 'flat',
    });
    await s.load();
    expect(s.backColor, '#80000000');
    expect(s.borderStyle, SubtitleBorderStyle.box);
  });

  test('外挂字幕记忆：添加/去重/移除/持久化', () async {
    final s = SubtitleSettings.instance;
    expect(s.importedSubtitlePaths, isEmpty);
    await s.addImportedSubtitle('/a/1.srt');
    await s.addImportedSubtitle('/a/1.srt'); // 去重
    await s.addImportedSubtitle('/a/2.ass');
    expect(s.importedSubtitlePaths, ['/a/1.srt', '/a/2.ass']);
    await s.load(); // 模拟重启
    expect(s.importedSubtitlePaths, ['/a/1.srt', '/a/2.ass']);
    await s.removeImportedSubtitle('/a/1.srt');
    expect(s.importedSubtitlePaths, ['/a/2.ass']);
  });

  test('按视频独立外挂字幕记忆与选中轨道：添加/去重/移除/持久化', () async {
    final s = SubtitleSettings.instance;
    const videoA = '/storage/emulated/0/Movies/A.mp4';
    const videoB = '/storage/emulated/0/Movies/B.mp4';

    expect(s.getImportedSubtitlesFor(videoA), isEmpty);
    expect(s.getImportedSubtitlesFor(videoB), isEmpty);

    // 为 A 视频添加外挂字幕
    await s.addImportedSubtitleFor(videoA, '/a/1.srt');
    await s.addImportedSubtitleFor(videoA, '/a/1.srt'); // 去重
    await s.addImportedSubtitleFor(videoA, '/a/2.ass');
    await s.setSelectedSubtitleFor(videoA, '/a/2.ass');

    // 为 B 视频添加外挂字幕
    await s.addImportedSubtitleFor(videoB, '/b/sub.vtt');
    await s.setSelectedSubtitleFor(videoB, 'track_1');

    expect(s.getImportedSubtitlesFor(videoA), ['/a/1.srt', '/a/2.ass']);
    expect(s.getSelectedSubtitleFor(videoA), '/a/2.ass');
    expect(s.getImportedSubtitlesFor(videoB), ['/b/sub.vtt']);
    expect(s.getSelectedSubtitleFor(videoB), 'track_1');

    // 模拟重启持久化加载
    await s.load();
    expect(s.getImportedSubtitlesFor(videoA), ['/a/1.srt', '/a/2.ass']);
    expect(s.getSelectedSubtitleFor(videoA), '/a/2.ass');
    expect(s.getImportedSubtitlesFor(videoB), ['/b/sub.vtt']);
    expect(s.getSelectedSubtitleFor(videoB), 'track_1');

    // 移除 A 视频某一条字幕
    await s.removeImportedSubtitleFor(videoA, '/a/2.ass');
    expect(s.getImportedSubtitlesFor(videoA), ['/a/1.srt']);
    expect(s.getSelectedSubtitleFor(videoA), isNull); // 选中的字幕被删除后清除选中记忆
  });

  test('远端同名字幕记忆：按视频独立、与本地导入列表分开、可持久化（网络存储）', () async {
    final s = SubtitleSettings.instance;
    const videoA = 'http://127.0.0.1:1234/tokenA/share/A.mkv';
    const videoB = 'http://127.0.0.1:1234/tokenB/share/B.mkv';

    expect(s.getRemoteSubtitleFor(videoA), isNull);
    await s.setRemoteSubtitleFor(videoA, buildRemoteSubtitlePath(1, '/share/A.sc.ass'));
    await s.setRemoteSubtitleFor(videoB, buildRemoteSubtitlePath(2, '/share/sub/B.srt'));

    // 与本地导入列表互不干扰：远端记忆不进 File 失效校验的那张表
    expect(s.getImportedSubtitlesFor(videoA), isEmpty);
    expect(parseRemoteSubtitlePath(s.getRemoteSubtitleFor(videoA)),
        (connectionId: 1, remotePath: '/share/A.sc.ass'));
    expect(parseRemoteSubtitlePath(s.getRemoteSubtitleFor(videoB)),
        (connectionId: 2, remotePath: '/share/sub/B.srt'));

    // 模拟重启
    await s.load();
    expect(parseRemoteSubtitlePath(s.getRemoteSubtitleFor(videoA)),
        (connectionId: 1, remotePath: '/share/A.sc.ass'));
    expect(parseRemoteSubtitlePath(s.getRemoteSubtitleFor(videoB)),
        (connectionId: 2, remotePath: '/share/sub/B.srt'));

    // 空值/空路径不写
    await s.setRemoteSubtitleFor('', buildRemoteSubtitlePath(1, '/a.srt'));
    await s.setRemoteSubtitleFor(videoA, '');
    expect(s.getRemoteSubtitleFor(''), isNull);
  });

  test('远端字幕标识编解码：合法可还原，非法一律 null', () {
    expect(buildRemoteSubtitlePath(7, '/share/x.ass'), '7|/share/x.ass');
    expect(parseRemoteSubtitlePath('7|/share/x.ass'),
        (connectionId: 7, remotePath: '/share/x.ass'));
    // 远端路径里再出现 | 也不影响（只按第一个分隔）
    expect(parseRemoteSubtitlePath('7|/share/a|b.ass'),
        (connectionId: 7, remotePath: '/share/a|b.ass'));
    expect(parseRemoteSubtitlePath(null), isNull);
    expect(parseRemoteSubtitlePath(''), isNull);
    expect(parseRemoteSubtitlePath('nosep'), isNull);
    expect(parseRemoteSubtitlePath('x|/a.ass'), isNull); // 连接 id 非数字
    expect(parseRemoteSubtitlePath('7|a.ass'), isNull); // 远端路径不以 / 开头
    expect(parseRemoteSubtitlePath('7|'), isNull); // 远端路径为空
    expect(parseRemoteSubtitlePath('|/a.ass'), isNull); // 连接 id 为空
  });

  test('重置所有样式：颜色/描边/效果回默认，保留延迟/缩放/位置/字体以及强制覆盖内嵌样式开关', () async {
    final s = SubtitleSettings.instance;
    await s.setDelay(3);
    await s.setScale(1.5);
    await s.setPosition(80);
    await s.setFont('myFont', '/data/fonts');
    await s.setColor('#FF0000');
    await s.setBorderColor('#00FF00');
    await s.setBorderStyle(SubtitleBorderStyle.outline);
    await s.setBorderSize(6);
    await s.setBold(true);
    await s.setOverrideEmbeddedStyle(true);
    await s.resetStyles();
    expect(s.color, '#FFFFFF');
    expect(s.borderColor, isNull);
    expect(s.borderStyle, SubtitleBorderStyle.outline);
    expect(s.borderSize, 2.5);
    expect(s.bold, isFalse);
    // 强制覆盖开关保持原选择（不被强制重置）
    expect(s.overrideEmbeddedStyle, isTrue);
    // 不重置的部分保留
    expect(s.delay, 3);
    expect(s.scale, 1.5);
    expect(s.position, 80);
    expect(s.font, 'myFont');
    await s.load(); // 持久化一致
    expect(s.color, '#FFFFFF');
    expect(s.borderColor, isNull);
    expect(s.overrideEmbeddedStyle, isTrue);
  });
}
