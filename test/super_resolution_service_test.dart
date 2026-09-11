import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/super_resolution_mode.dart';
import 'package:moumou/services/super_resolution_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 超分辨率服务测试：模式/质量/记忆开关的状态与持久化逻辑
/// （不涉及 media_kit Player，[setMode]/[setQuality] 不传 player）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SuperResolutionService.instance.reset();
  });

  test('默认值：关闭 / 均衡 / 不记忆', () {
    final s = SuperResolutionService.instance;
    expect(s.mode, SuperResolutionMode.off);
    expect(s.quality, SuperResolutionQuality.balanced);
    expect(s.remember, isFalse);
  });

  test('切换模式/质量总是记录为上次设置', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.bPlus);
    await s.setQuality(SuperResolutionQuality.high);
    expect(s.mode, SuperResolutionMode.bPlus);
    expect(s.quality, SuperResolutionQuality.high);
  });

  test('开启记忆：立即恢复上次的模式与质量', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.c);
    await s.setQuality(SuperResolutionQuality.fast);
    await s.setRemember(true);
    expect(s.remember, isTrue);
    // 恢复的是「最近一次设置」的 c/fast
    expect(s.mode, SuperResolutionMode.c);
    expect(s.quality, SuperResolutionQuality.fast);
  });

  test('开启记忆后再次设置：以最新设置为准', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.c);
    await s.setQuality(SuperResolutionQuality.fast);
    await s.setRemember(true);
    await s.setMode(SuperResolutionMode.aPlus);
    await s.setQuality(SuperResolutionQuality.high);
    expect(s.mode, SuperResolutionMode.aPlus);
    expect(s.quality, SuperResolutionQuality.high);
  });

  test('关闭记忆：回到关闭/均衡', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.aPlus);
    await s.setQuality(SuperResolutionQuality.high);
    await s.setRemember(true);
    await s.setRemember(false);
    expect(s.remember, isFalse);
    expect(s.mode, SuperResolutionMode.off);
    expect(s.quality, SuperResolutionQuality.balanced);
  });

  test('记忆开启时 load 恢复上次设置（模拟重启）', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.b);
    await s.setQuality(SuperResolutionQuality.high);
    await s.setRemember(true);
    await s.load(); // 模拟重启
    expect(s.mode, SuperResolutionMode.b);
    expect(s.quality, SuperResolutionQuality.high);
    expect(s.remember, isTrue);
  });

  test('记忆关闭时 load 回到关闭/均衡（模拟重启）', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.cPlus);
    await s.setQuality(SuperResolutionQuality.high);
    await s.load(); // 未开启记忆 → 不恢复
    expect(s.mode, SuperResolutionMode.off);
    expect(s.quality, SuperResolutionQuality.balanced);
    expect(s.remember, isFalse);
  });

  test('enterPlayer：未开启记忆时本次会话重置为关闭/均衡', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.bPlus);
    await s.setQuality(SuperResolutionQuality.high);
    s.enterPlayer(); // 未开启记忆 → 每次进入播放器都回到默认关闭
    expect(s.mode, SuperResolutionMode.off);
    expect(s.quality, SuperResolutionQuality.balanced);
  });

  test('enterPlayer：开启记忆时保持上次设置', () async {
    final s = SuperResolutionService.instance;
    await s.setMode(SuperResolutionMode.bPlus);
    await s.setQuality(SuperResolutionQuality.high);
    await s.setRemember(true);
    s.enterPlayer(); // 开启记忆 → 保持上次设置
    expect(s.mode, SuperResolutionMode.bPlus);
    expect(s.quality, SuperResolutionQuality.high);
  });

  test('未知持久化值回退默认', () async {
    SharedPreferences.setMockInitialValues({
      'super_resolution_last_mode': '不存在的模式',
      'super_resolution_last_quality': 99,
      'super_resolution_remember': true,
    });
    final s = SuperResolutionService.instance;
    await s.load();
    // 未知模式/质量回退关闭/均衡；记忆开启则应用（即维持默认值）
    expect(s.mode, SuperResolutionMode.off);
    expect(s.quality, SuperResolutionQuality.balanced);
  });

  test('setter 必须先 await 读盘再改内存（P1-30 冷启动竞态）', () async {
    final s = SuperResolutionService.instance;
    // 不 await：调用后 setter 应停在 ensureLoaded 的 await 上，尚未改内存
    final pending = s.setMode(SuperResolutionMode.aPlus);
    expect(
      s.mode,
      SuperResolutionMode.off,
      reason: 'setter 同步段不得改内存，否则读盘（记忆开启时恢复上次档位）会覆盖用户刚选的档位',
    );
    await pending;
    expect(s.mode, SuperResolutionMode.aPlus);
  });

  test('ensureLoaded 复用同一 load Future（与 main.dart 共享）', () async {
    final s = SuperResolutionService.instance;
    final f1 = s.ensureLoaded();
    final f2 = s.ensureLoaded();
    expect(identical(f1, f2), isTrue, reason: '启动加载与 setter 必须共享同一 Future');
    await f1;
  });

  test('读盘完成后再改档：ensureLoaded 不二次回读、不回退', () async {
    SharedPreferences.setMockInitialValues({
      'super_resolution_remember': true,
      'super_resolution_last_mode': SuperResolutionMode.c.id,
      'super_resolution_last_quality': SuperResolutionQuality.fast.index,
    });
    final s = SuperResolutionService.instance..reset();
    await s.ensureLoaded();
    expect(s.mode, SuperResolutionMode.c);
    expect(s.quality, SuperResolutionQuality.fast);

    await s.setMode(SuperResolutionMode.aPlus);
    await s.setQuality(SuperResolutionQuality.high);
    await s.ensureLoaded();

    expect(s.mode, SuperResolutionMode.aPlus, reason: '一次性加载，用户选择优先');
    expect(s.quality, SuperResolutionQuality.high);
  });
}
