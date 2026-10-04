# -*- coding: utf-8 -*-
"""阶段 7 新增 ARB 键（隐私弹窗的 4 条界面文案）：只新增缺失的键，可反复运行。

- 长文正文**不进 ARB**（按语言拆 lib/l10n/legal_*.dart，见 02-implementation-plan.md §1.11）；
- 「用户协议」页标题复用既有键 `settingsAboutUserAgreement`（同中文，§1.10）；
- 运行后必须 `flutter gen-l10n`。
"""
import json
import io
import sys

ZH = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
EN = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'

E = [
    ('legalAgreeCheckbox', '我已阅读并同意以上隐私政策',
     'I have read and agree to the privacy policy above',
     '隐私弹窗：同意复选框文案', None),
    ('legalDisagreeExit', '不同意并退出', 'Disagree and exit',
     '隐私弹窗：不同意（退出应用）按钮', None),
    ('legalAgreeWithCountdown', '同意并继续 ({seconds} 秒)',
     'Agree and continue ({seconds}s)',
     '隐私弹窗：倒计时中的同意按钮', {'seconds': 'String'}),
    ('legalAgreeContinue', '同意并继续', 'Agree and continue',
     '隐私弹窗：倒计时结束后的同意按钮', None),
]


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))
    added = []
    for key, zh_v, en_v, desc, ph in E:
        if key in zh:
            continue
        zh[key] = zh_v
        meta = {'description': desc}
        if ph:
            meta['placeholders'] = {k: {'type': v} for k, v in ph.items()}
        zh['@' + key] = meta
        en[key] = en_v
        added.append(key)
    json.dump(zh, open(ZH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(ZH, 'a', encoding='utf-8').write('\n')
    json.dump(en, open(EN, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(EN, 'a', encoding='utf-8').write('\n')
    print('added:', added or '(none)')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
