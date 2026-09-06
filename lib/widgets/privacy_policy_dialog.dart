import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moumou/services/privacy_policy_content.dart';
import 'package:moumou/utils/app_dialog.dart';

/// 首次启动用户隐私弹窗（工作.md：隐私政策功能）。
///
/// 门禁语义：用户必须等待 5 秒倒计时结束、勾选「同意」复选框后，「同意并继续」
/// 才可用；点「不同意并退出」返回 false（由启动门禁调用 SystemNavigator.pop 退出）。
/// 弹窗不可通过点遮罩或系统返回键关闭（只能点同意/不同意）。
Future<bool?> showPrivacyPolicyDialog(BuildContext context) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PrivacyPolicyDialog(),
  );
}

/// 隐私弹窗内容（自持倒计时与复选框状态）。
class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({super.key});

  /// 同意按钮（测试定位用）
  static const confirmButtonKey = Key('privacyConfirmButton');

  /// 同意复选框（测试定位用）
  static const agreeCheckboxKey = Key('privacyAgreeCheckbox');

  /// 不同意按钮（测试定位用）
  static const cancelButtonKey = Key('privacyCancelButton');

  /// 倒计时秒数（首次启动必须等待该时长后方可确认）
  static const countdownSeconds = 5;

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  int _remaining = PrivacyPolicyDialog.countdownSeconds;
  bool _agreed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 倒计时结束 + 已勾选同意，才允许确认
  bool get _canConfirm => _remaining == 0 && _agreed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      // 门禁弹窗不可被系统返回键关闭，只能点同意/不同意
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560, maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  kPrivacyPolicyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // 正文（可滚动）
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    kPrivacyPolicyBody,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // 同意复选框
              CheckboxListTile(
                key: PrivacyPolicyDialog.agreeCheckboxKey,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                title: const Text(
                  '我已阅读并同意以上隐私政策',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: PrivacyPolicyDialog.cancelButtonKey,
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('不同意并退出'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: PrivacyPolicyDialog.confirmButtonKey,
                        onPressed: _canConfirm
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        // FittedBox 防止倒计时文本换行把按钮撑高（文本往上顶）
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _remaining > 0
                                ? '同意并继续 ($_remaining 秒)'
                                : '同意并继续',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
