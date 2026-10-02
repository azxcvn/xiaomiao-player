import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/app_locale_settings.dart';
import 'package:moumou/utils/app_dialog.dart';

/// 语言选择弹窗（首启门禁与设置页「语言设置」共用）。
///
/// 约定（用户已拍板，见 `杂项文件/多语言支持方案/02-实施方案.md` §1.7）：
/// - 选项只有 **简体中文 / English** 两项（**自称，不翻译**），没有「跟随系统」；
/// - **默认选中简体中文**（`app_locale` 缺省即 `'zh'`）；
/// - 确认后写入 `app_locale` 并**立即生效**（`AppLocaleSettings` 是 ChangeNotifier，
///   `MaterialApp` 监听到通知后直接换语言，无需重启）；
/// - 这是「选择」不是「门禁」：**允许点遮罩/返回键关闭，关闭 = 保持当前语言**，
///   避免把用户卡在弹窗里。
Future<void> showLanguagePickerDialog(BuildContext context) async {
  final current = AppLocaleSettings.instance.rawValue;
  final picked = await showAppDialog<String>(
    context: context,
    builder: (context) => _LanguagePickerDialog(initial: current),
  );
  if (picked == null) return; // 关闭 = 保持当前语言
  await AppLocaleSettings.instance.setLocale(picked);
}

class _LanguagePickerDialog extends StatefulWidget {
  /// 打开时的当前语言（作为默认选中项）
  final String initial;

  const _LanguagePickerDialog({required this.initial});

  @override
  State<_LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<_LanguagePickerDialog> {
  late String _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 语言名用「自称」：两个选项在任何语言下都显示各自母语写法
    final options = <(String, String)>[
      (AppLocaleSettings.zhCode, l10n.languageNameZh),
      (AppLocaleSettings.enCode, l10n.languageNameEn),
    ];
    return AlertDialog(
      // 刻意双语标题（中英两版内容相同），保证任何用户都看得懂
      title: Text(l10n.languagePickerTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (code, name) in options)
            ListTile(
              dense: true,
              title: Text(name),
              trailing: _value == code
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => setState(() => _value = code),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
