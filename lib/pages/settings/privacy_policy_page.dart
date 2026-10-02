import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/legal.dart';

/// 用户协议页（设置 → 关于 → 用户协议，工作.md：隐私政策功能）。
///
/// 展示《用户服务协议与隐私政策》完整正文（仅内容，无同意/确认交互），
/// 文本可选中复制，对齐许可证书详情页的阅读体验。
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    // 长文正文按当前语言取（legal_zh / legal_en，不进 ARB）
    final legal = legalTextsFor(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAboutUserAgreement)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题卡片
            Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        legal.agreementTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 完整正文（可选中复制）
            SelectableText(
              legal.agreementBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
