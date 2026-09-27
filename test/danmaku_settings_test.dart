import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/danmaku_color_mode.dart';
import 'package:moumou/models/danmaku_font_mode.dart';
import 'package:moumou/services/danmaku_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹幕设置服务测试（阶段2）：默认值、钳制、持久化恢复、一键恢复默认，
/// 以及弹幕颜色三态（含旧键迁移）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DanmakuSettings.instance.resetForTest();
  });

  final s = DanmakuSettings.instance;

  test('默认值：字号16 / 字重4 / 速度10s / 不透明1.0 / 描边1.5 / 全部显示', () {
    expect(s.fontSize, 16);
    expect(s.fontWeight, 4);
    expect(s.scrollSeconds, 10);
    expect(s.opacity, 1.0);
    expect(s.strokeWidth, 1.5);
    expect(
      s.colorMode,
      DanmakuColorMode.source,
      reason: '默认跟随弹幕自身颜色（保留会员渐变彩色）',
    );
    expect(s.colorValue, kDanmakuDefaultColor);
    expect(s.area, 1.0);
    expect(s.lineHeight, 1.6);
    expect(s.showTop, isTrue);
    expect(s.showBottom, isTrue);
    expect(s.showScroll, isTrue);
    expect(s.massiveMode, isFalse);
    expect(s.deduplication, isFalse);
    expect(s.merge, isFalse);
    expect(s.timeOffsetSeconds, 0);
  });

  test('样式 setter 持久化（模拟重启 load）', () async {
    await s.setFontSize(24);
    await s.setFontWeight(7);
    await s.setScrollSeconds(6);
    await s.setOpacity(0.5);
    await s.setStrokeWidth(0);
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValue('#FF00FF00');
    await s.load();
    expect(s.fontSize, 24);
    expect(s.fontWeight, 7);
    expect(s.scrollSeconds, 6);
    expect(s.opacity, 0.5);
    expect(s.strokeWidth, 0);
    expect(s.colorMode, DanmakuColorMode.fixed);
    expect(s.colorValue, '#FF00FF00');
  });

  test('配置 setter 持久化（模拟重启 load）', () async {
    await s.setArea(0.5);
    await s.setLineHeight(2.0);
    await s.setShowTop(false);
    await s.setShowBottom(false);
    await s.setShowScroll(false);
    await s.setMassiveMode(true);
    await s.setDeduplication(true);
    await s.load();
    expect(s.area, 0.5);
    expect(s.lineHeight, 2.0);
    expect(s.showTop, isFalse);
    expect(s.showBottom, isFalse);
    expect(s.showScroll, isFalse);
    expect(s.massiveMode, isTrue);
    expect(s.deduplication, isTrue);
    expect(s.merge, isFalse); // 去重开 → 合并保持关
  });

  test('弹幕去重与弹幕合并互斥：开一个自动关另一个', () async {
    // 开合并 → 去重被关
    await s.setDeduplication(true);
    expect(s.deduplication, isTrue);
    await s.setMerge(true);
    expect(s.merge, isTrue);
    expect(s.deduplication, isFalse);

    // 开去重 → 合并被关
    await s.setDeduplication(true);
    expect(s.deduplication, isTrue);
    expect(s.merge, isFalse);

    // 互斥结果已落盘：重载后仍是「只开去重」
    await s.load();
    expect(s.deduplication, isTrue);
    expect(s.merge, isFalse);
  });

  test('弹幕合并持久化 + 关闭动作永远允许', () async {
    await s.setMerge(true);
    await s.load();
    expect(s.merge, isTrue);
    expect(s.deduplication, isFalse);
    await s.setMerge(false);
    await s.load();
    expect(s.merge, isFalse);
  });

  test('字号/速度/不透明度/描边钳制到滑杆范围', () async {
    await s.setFontSize(999);
    expect(s.fontSize, DanmakuSettings.maxFontSize);
    await s.setFontSize(1);
    expect(s.fontSize, DanmakuSettings.minFontSize);
    await s.setScrollSeconds(0.1);
    expect(s.scrollSeconds, DanmakuSettings.minScrollSeconds);
    await s.setScrollSeconds(100);
    expect(s.scrollSeconds, DanmakuSettings.maxScrollSeconds);
    await s.setOpacity(0.01);
    expect(s.opacity, DanmakuSettings.minOpacity);
    await s.setStrokeWidth(50);
    expect(s.strokeWidth, DanmakuSettings.maxStrokeWidth);
  });

  test('区域/行高钳制；字重钳到 0–8', () async {
    await s.setArea(5);
    expect(s.area, DanmakuSettings.maxArea);
    await s.setArea(0.01);
    expect(s.area, DanmakuSettings.minArea);
    await s.setLineHeight(9);
    expect(s.lineHeight, DanmakuSettings.maxLineHeight);
    await s.setFontWeight(99);
    expect(s.fontWeight, 8);
    await s.setFontWeight(-1);
    expect(s.fontWeight, 0);
  });

  test('显示区域 10% 档位吸附：任意值落到最近档位', () async {
    await s.setArea(0.33);
    expect(s.area, 0.3);
    await s.setArea(0.36);
    expect(s.area, 0.4);
    await s.setArea(0.09);
    expect(s.area, DanmakuSettings.minArea); // 下界
    await s.setArea(1.01);
    expect(s.area, DanmakuSettings.maxArea); // 上界
  });

  test('load 时越界历史值收窄', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('danmaku_font_size', 999);
    await prefs.setDouble('danmaku_speed', 0.1);
    await s.load();
    expect(s.fontSize, DanmakuSettings.maxFontSize);
    expect(s.scrollSeconds, DanmakuSettings.minScrollSeconds);
  });

  test('恢复默认：全部回默认值且持久化', () async {
    await s.setFontSize(30);
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValue('#FF123456');
    await s.setShowTop(false);
    await s.setMassiveMode(true);
    await s.setMerge(true);
    await s.setTimeOffset(60);
    await s.reset();
    expect(s.fontSize, 16);
    expect(s.colorMode, DanmakuColorMode.source);
    expect(s.colorValue, kDanmakuDefaultColor);
    expect(s.showTop, isTrue);
    expect(s.massiveMode, isFalse);
    expect(s.merge, isFalse);
    expect(s.timeOffsetSeconds, 0);
    // 持久化确认：重载后仍是默认值
    await s.load();
    expect(s.fontSize, 16);
    expect(s.colorMode, DanmakuColorMode.source);
    expect(s.colorValue, kDanmakuDefaultColor);
    expect(s.merge, isFalse);
    expect(s.timeOffsetSeconds, 0);
  });

  // ── 弹幕颜色三态（issue #1 需求 5 的改良方案）──────────────────────

  test('颜色值：空串回落默认白，避免空值进渲染层', () async {
    await s.setColorValue('');
    expect(s.colorValue, kDanmakuDefaultColor);
  });

  test('颜色模式与颜色值各自持久化，互不干扰', () async {
    await s.setColorValue('#FF336699');
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.load();
    expect(s.colorMode, DanmakuColorMode.fixed);
    expect(s.colorValue, '#FF336699');
  });

  test('旧键迁移：历史 danmaku_random_color=true → 随机色模式', () async {
    // 模拟老用户数据：只有旧的布尔键，没有新的 int 模式键
    SharedPreferences.setMockInitialValues({'danmaku_random_color': true});
    s.resetForTest();
    await s.load();
    expect(
      s.colorMode,
      DanmakuColorMode.random,
      reason: '老用户开着随机色，升级后不能被静默重置回原色',
    );
  });

  test('旧键迁移：danmaku_random_color=false → 原色模式（默认）', () async {
    SharedPreferences.setMockInitialValues({'danmaku_random_color': false});
    s.resetForTest();
    await s.load();
    expect(s.colorMode, DanmakuColorMode.source);
  });

  test('新键优先于旧键（用户已在新版本选过模式）', () async {
    SharedPreferences.setMockInitialValues({
      'danmaku_random_color': true, // 旧值说随机
      'danmaku_color_mode': DanmakuColorMode.fixed.index, // 新值说指定色
    });
    s.resetForTest();
    await s.load();
    expect(s.colorMode, DanmakuColorMode.fixed, reason: '新键存在时以新键为准');
  });

  test('颜色模式 index 越界/损坏回落 source', () {
    expect(DanmakuColorMode.fromIndex(null), DanmakuColorMode.source);
    expect(DanmakuColorMode.fromIndex(-1), DanmakuColorMode.source);
    expect(DanmakuColorMode.fromIndex(99), DanmakuColorMode.source);
    expect(DanmakuColorMode.fromIndex(1), DanmakuColorMode.random);
  });

  test('mpvColorToRgbInt：丢掉 alpha、保留 RGB', () {
    expect(mpvColorToRgbInt('#FF00FF00'), 0x00FF00);
    expect(mpvColorToRgbInt('#00FF00'), 0x00FF00);
    expect(mpvColorToRgbInt('#FFFFFFFF'), 0xFFFFFF);
  });

  // ── 「指定颜色」调色板（多色随机，方案 A）──────────────────────────

  test('调色板：多色持久化 + 实际生效模式', () async {
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues(['#FFFF0000', '#FF00FF00', '#FF0000FF']);
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00', '#FF0000FF']);
    expect(s.colorValue, '#FFFF0000', reason: '首色兼容旧读取口');
    expect(s.hasColorValues, isTrue);
    expect(s.effectiveColorMode, DanmakuColorMode.fixed);
    await s.load();
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00', '#FF0000FF']);
    expect(s.effectiveColorMode, DanmakuColorMode.fixed);
  });

  test('调色板：归一化去空白/去重/截断到上限', () async {
    await s.setColorValues([
      ' #FFFF0000 ',
      '#FFFF0000', // 重复
      '', // 空串
      '   ', // 空白
      '#FF00FF00',
    ]);
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);

    final many = [
      for (var i = 0; i < DanmakuSettings.maxPaletteColors + 4; i++)
        '#FF0000${i.toRadixString(16).padLeft(2, '0')}',
    ];
    await s.setColorValues(many);
    expect(s.colorValues.length, DanmakuSettings.maxPaletteColors);
  });

  test('调色板清空 → 模式回落「跟随弹幕颜色」并持久化', () async {
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues(['#FFFF0000']);
    expect(s.effectiveColorMode, DanmakuColorMode.fixed);
    await s.setColorValues(const []);
    expect(s.colorValues, isEmpty);
    expect(s.hasColorValues, isFalse);
    expect(
      s.colorMode,
      DanmakuColorMode.source,
      reason: '清空调色板时裸模式也要回落，避免留下「选了指色却没颜色」的死状态',
    );
    expect(s.effectiveColorMode, DanmakuColorMode.source);
    await s.load();
    expect(s.colorMode, DanmakuColorMode.source);
    expect(s.colorValues, isEmpty);
  });

  test('调色板：旧单色键迁移成长度 1 的调色板', () async {
    SharedPreferences.setMockInitialValues({
      'danmaku_color_mode': DanmakuColorMode.fixed.index,
      'danmaku_color_value': '#FF123456',
    });
    s.resetForTest();
    await s.load();
    expect(s.colorValues, ['#FF123456'], reason: '升级后行为与升级前一致');
    expect(s.effectiveColorMode, DanmakuColorMode.fixed);
  });

  test('调色板：新键优先于旧单色键', () async {
    SharedPreferences.setMockInitialValues({
      'danmaku_color_value': '#FF123456',
      'danmaku_color_values': ['#FFAAAAAA', '#FFBBBBBB'],
    });
    s.resetForTest();
    await s.load();
    expect(s.colorValues, ['#FFAAAAAA', '#FFBBBBBB']);
  });

  test('调色板：空列表持久化时按「跟随弹幕颜色」写模式', () async {
    SharedPreferences.setMockInitialValues({
      'danmaku_color_mode': DanmakuColorMode.fixed.index,
      'danmaku_color_values': ['#FFFF0000'],
    });
    s.resetForTest();
    await s.load();
    await s.setColorValues(const []);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('danmaku_color_values'), isEmpty);
    expect(prefs.getInt('danmaku_color_mode'), DanmakuColorMode.source.index);
  });

  test('调色板：从空调色板切「指定颜色」自动补默认色（否则点了没反应）', () async {
    await s.setColorMode(DanmakuColorMode.fixed);
    await s.setColorValues(const []);
    expect(s.colorValues, isEmpty);
    expect(s.colorMode, DanmakuColorMode.source);

    // 再切回指定颜色：必须真的生效（真机 bug：怎么点都没反应）
    await s.setColorMode(DanmakuColorMode.fixed);
    expect(s.colorMode, DanmakuColorMode.fixed);
    expect(s.colorValues, [kDanmakuDefaultColor]);
    expect(s.effectiveColorMode, DanmakuColorMode.fixed);

    // 持久化确认：重载后仍是「指定颜色 + 1 色」
    await s.load();
    expect(s.colorMode, DanmakuColorMode.fixed);
    expect(s.colorValues, [kDanmakuDefaultColor]);
  });

  test('调色板：非空时切「指定颜色」不动已选色', () async {
    await s.setColorValues(['#FFFF0000', '#FF00FF00']);
    await s.setColorMode(DanmakuColorMode.fixed);
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);
  });

  test('调色板：添加/移除是增量语义，重复添加与超上限幂等', () async {
    await s.setColorValues(['#FFFF0000']);
    await s.addColorValue('#FF00FF00');
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);
    await s.addColorValue('#FF00FF00'); // 重复添加幂等
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);
    await s.addColorValue('   '); // 空串忽略
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);
    await s.removeColorValue('#FF0000FF'); // 不存在，幂等
    expect(s.colorValues, ['#FFFF0000', '#FF00FF00']);
    await s.removeColorValue('#FF00FF00');
    expect(s.colorValues, ['#FFFF0000']);

    // 加到上限后不再增长
    for (var i = 0; i < DanmakuSettings.maxPaletteColors + 3; i++) {
      await s.addColorValue('#FF0000${i.toRadixString(16).padLeft(2, '0')}');
    }
    expect(s.colorValues.length, DanmakuSettings.maxPaletteColors);
  });

  test('调色板：setColorValue 单色入口等价于「只有一个色的调色板」', () async {
    await s.setColorValue('#FF00FF00');
    expect(s.colorValues, ['#FF00FF00']);
    await s.setColorValue('');
    expect(s.colorValues, [kDanmakuDefaultColor]);
  });

  test('调色板：同色写入不重复通知（面板重建依据）', () async {
    await s.setColorValues(['#FFFF0000']);
    var notified = 0;
    void listener() => notified++;
    s.addListener(listener);
    await s.setColorValues(['#FFFF0000']); // 同值
    s.removeListener(listener);
    expect(notified, 0);
  });

  test('时间轴偏移：取整 / 持久化 / 钳制', () async {
    expect(s.timeOffsetSeconds, 0);
    await s.setTimeOffset(45.6); // 取整到整数秒
    expect(s.timeOffsetSeconds, 46);
    await s.load();
    expect(s.timeOffsetSeconds, 46);
    await s.setTimeOffset(999);
    expect(s.timeOffsetSeconds, DanmakuSettings.maxTimeOffsetSeconds);
    await s.setTimeOffset(-999);
    expect(s.timeOffsetSeconds, DanmakuSettings.minTimeOffsetSeconds);
  });

  test('设置变更触发通知（面板 ListenableBuilder 刷新依据）', () async {
    await s.ensureLoaded(); // 模拟 main.dart 启动加载已完成（load 的通知不计入）
    var notified = 0;
    void listener() => notified++;
    s.addListener(listener);
    await s.setFontSize(20);
    await s.setFontSize(20); // 同值不重复通知
    s.removeListener(listener);
    expect(notified, 1);
  });

  test('弹幕字体默认值：跟随系统 / 无自定义字体', () {
    expect(s.fontMode, DanmakuFontMode.followSystem);
    expect(s.customFontFamily, isNull);
    expect(s.customFontFile, isNull);
  });

  test('弹幕字体模式 / 自定义字体持久化（模拟重启 load）', () async {
    await s.setFontMode(DanmakuFontMode.custom);
    await s.setCustomFont('DmFont', 'dmfont.otf');
    await s.load();
    expect(s.fontMode, DanmakuFontMode.custom);
    expect(s.customFontFamily, 'DmFont');
    expect(s.customFontFile, 'dmfont.otf');
  });

  test('恢复默认：弹幕字体回跟随系统且清自定义字体', () async {
    await s.setFontMode(DanmakuFontMode.followApp);
    await s.setCustomFont('DmFont', 'dmfont.otf');
    await s.reset();
    expect(s.fontMode, DanmakuFontMode.followSystem);
    expect(s.customFontFamily, isNull);
    expect(s.customFontFile, isNull);
    // 持久化确认
    await s.load();
    expect(s.fontMode, DanmakuFontMode.followSystem);
    expect(s.customFontFamily, isNull);
    expect(s.customFontFile, isNull);
  });

  test('屏蔽词：添加去空白/去重/忽略空串/持久化', () async {
    await s.addBlockedKeyword(' 傻逼 ');
    await s.addBlockedKeyword('傻逼'); // 重复，幂等
    await s.addBlockedKeyword('   '); // 空串忽略
    expect(s.blockedKeywords, ['傻逼']);
    await s.load();
    expect(s.blockedKeywords, ['傻逼']);
  });

  test('屏蔽词：移除 / 清空 / 持久化', () async {
    await s.addBlockedKeyword('a');
    await s.addBlockedKeyword('b');
    expect(s.blockedKeywords, ['a', 'b']);
    await s.removeBlockedKeyword('a');
    expect(s.blockedKeywords, ['b']);
    await s.removeBlockedKeyword('x'); // 不存在，幂等
    expect(s.blockedKeywords, ['b']);
    await s.clearBlockedKeywords();
    expect(s.blockedKeywords, isEmpty);
    await s.load();
    expect(s.blockedKeywords, isEmpty);
  });

  test('恢复默认：清空屏蔽词', () async {
    await s.addBlockedKeyword('a');
    await s.reset();
    expect(s.blockedKeywords, isEmpty);
    await s.load();
    expect(s.blockedKeywords, isEmpty);
  });
}
