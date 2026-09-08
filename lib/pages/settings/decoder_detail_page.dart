import 'package:flutter/material.dart';
import 'package:moumou/models/device_decoder.dart';
import 'package:moumou/widgets/settings_ui.dart';

/// 解码器详情页（工作.md 迁移功能，点解码器清单项进入）。
///
/// 展示单个解码器的完整能力信息（对齐参考项目 mpvRx `CodecDetailCard`
/// 展开后的字段）：基本信息 + 分辨率/位率/对齐/实例 + 音频声道/采样率 +
/// 硬件特性 + 色彩格式 + supported profiles/levels。
class DecoderDetailPage extends StatelessWidget {
  final DeviceDecoderEntry decoder;

  const DecoderDetailPage({super.key, required this.decoder});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = decoder;
    final isVideo = d.mediaType == 'video';
    return Scaffold(
      appBar: AppBar(title: Text(d.formatName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          // 头部卡片：formatName + HW/SW + HDR 徽章 + 名称
          SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.formatName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _badge(scheme, d.isHardware ? 'HW' : 'SW', d.isHardware),
                      if (d.isHdrSupported) ...[
                        const SizedBox(width: 6),
                        _badge(scheme, 'HDR', true, secondary: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 基本信息
          const SettingsGroupTitle(title: '基本信息'),
          SettingsCard(
            child: Column(
              children: [
                _kvRow(scheme, 'MIME 类型', d.mimeType),
                if (d.canonicalName.isNotEmpty && d.canonicalName != d.name)
                  _kvRow(scheme, '规范名', d.canonicalName),
                _kvRow(scheme, '类型', isVideo ? '视频解码器' : '音频解码器'),
                _kvRow(scheme, '加速方式', d.isHardware ? '硬件加速' : '软件'),
                if (d.isAlias) _kvRow(scheme, '别名', '是'),
                if (d.bitrateRange.isNotEmpty)
                  _kvRow(scheme, '码率范围', d.bitrateRange),
              ],
            ),
          ),
          // 分辨率 / 对齐 / 实例（仅视频）
          if (isVideo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsGroupTitle(title: '分辨率与能力'),
                SettingsCard(
                  child: Column(
                    children: [
                      if (d.maxResolution.isNotEmpty)
                        _kvRow(scheme, '最大分辨率', d.maxResolution),
                      if (d.minResolution.isNotEmpty)
                        _kvRow(scheme, '最小分辨率', d.minResolution),
                      if (d.alignment.isNotEmpty)
                        _kvRow(scheme, '对齐', d.alignment),
                      if (d.maxInstances > 0)
                        _kvRow(scheme, '最大实例数', '${d.maxInstances}'),
                    ],
                  ),
                ),
              ],
            ),
          // 音频声道 / 采样率（仅音频）
          if (!isVideo && d.maxChannels > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsGroupTitle(title: '音频能力'),
                SettingsCard(
                  child: Column(
                    children: [_kvRow(scheme, '最大声道数', '${d.maxChannels}')],
                  ),
                ),
              ],
            ),
          // 硬件特性胶囊
          if (d.features.isNotEmpty)
            _tagSection(scheme, '硬件特性', d.features, primary: true),
          // 采样率胶囊
          if (d.sampleRates.isNotEmpty)
            _tagSection(scheme, '采样率', d.sampleRates),
          // 色彩格式胶囊
          if (d.colorFormats.isNotEmpty)
            _tagSection(scheme, '色彩格式', d.colorFormats),
          // profiles / levels 胶囊
          if (d.profiles.isNotEmpty)
            _tagSection(scheme, '支持的 Profile / Level', d.profiles),
        ],
      ),
    );
  }

  Widget _badge(
    ColorScheme scheme,
    String text,
    bool hw, {
    bool secondary = false,
  }) {
    final color = secondary
        ? scheme.secondaryContainer
        : hw
        ? scheme.primaryContainer
        : scheme.tertiaryContainer;
    final fg = secondary
        ? scheme.onSecondaryContainer
        : hw
        ? scheme.onPrimaryContainer
        : scheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _kvRow(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagSection(
    ColorScheme scheme,
    String title,
    List<String> items, {
    bool primary = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupTitle(title: title),
        SettingsCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primary
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primary
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
