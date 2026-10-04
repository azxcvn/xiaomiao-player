import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/utils/decode_policy.dart';

/// 解码链选择（对齐参照项目 MPVRX 的 `RendererBackendPolicy`）：
/// 档位由用户定、链在开播前按渲染后端定一次，**任何情况下都不改写用户档位**。
void main() {
  // 表改造后档位名称由 l10n 提供（代码里不再有中文标签）
  final zh = lookupAppLocalizations(const Locale('zh'));

  group('preferredDecodeChain', () {
    test('硬解+ / OpenGL：直通优先链', () {
      expect(
        preferredDecodeChain(DecodeMode.hwPlus, usesVulkan: false),
        'mediacodec,mediacodec-copy,no',
      );
    });

    test('硬解+ / Vulkan：普通构建不支持 MediaCodec→Vulkan 映射 → 拷贝优先链', () {
      expect(
        preferredDecodeChain(DecodeMode.hwPlus, usesVulkan: true),
        'mediacodec-copy,no',
      );
      expect(
        preferredDecodeChain(
          DecodeMode.hwPlus,
          usesVulkan: true,
          buildSupportsMediaCodecVulkan: true,
        ),
        'mediacodec,mediacodec-copy,no',
        reason: '换成支持该映射的内核后应恢复直通优先',
      );
    });

    test('硬解：恒定拷贝优先链（不依赖渲染后端）', () {
      for (final vulkan in [true, false]) {
        expect(
          preferredDecodeChain(DecodeMode.hwCopy, usesVulkan: vulkan),
          'mediacodec-copy,no',
        );
      }
    });

    test('软解 / 自动档：原样返回，不被本函数改写语义', () {
      expect(
        preferredDecodeChain(DecodeMode.sw, usesVulkan: false),
        DecodeMode.sw.hwdec,
      );
      expect(
        preferredDecodeChain(DecodeMode.sw, usesVulkan: true),
        'no',
      );
      expect(
        preferredDecodeChain(DecodeMode.autoSafe, usesVulkan: true),
        DecodeMode.autoSafe.hwdec,
      );
    });

    test('两条链都以软解兜底（末位 no），不会把播放逼死', () {
      expect(kHwdecChainDirectFirst.endsWith(',no'), isTrue);
      expect(kHwdecChainCopyFirst.endsWith(',no'), isTrue);
    });
  });

  group('canUseDirectMediaCodec', () {
    test('OpenGL 恒可直通；Vulkan 看构建支持', () {
      expect(canUseDirectMediaCodec(usesVulkan: false), isTrue);
      expect(canUseDirectMediaCodec(usesVulkan: true), isFalse);
      expect(
        canUseDirectMediaCodec(
          usesVulkan: true,
          buildSupportsMediaCodecVulkan: true,
        ),
        isTrue,
      );
    });
  });

  group('档位本身不被链选择改写', () {
    test('无论渲染后端如何，传入的档位对象原样返回其 hwdec 语义', () {
      // 硬解+ 的 enum hwdec 是直通优先链；Vulkan 下写盘的是拷贝链，
      // 但用户看到的档位仍是「硬解+」（界面按 DecodeSettings.mode 显示）
      expect(DecodeMode.hwPlus.hwdec, 'mediacodec,mediacodec-copy,no');
      expect(decodeModeLabel(zh, DecodeMode.hwPlus), '硬解+');
      expect(DecodeMode.hwCopy.hwdec, 'mediacodec-copy');
      expect(decodeModeLabel(zh, DecodeMode.hwCopy), '硬解');
    });
  });
}
