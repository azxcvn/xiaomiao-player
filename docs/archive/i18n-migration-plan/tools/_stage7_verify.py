# -*- coding: utf-8 -*-
"""阶段 7 长文核对：legal_zh / legal_en 的四个字段是否齐全、英文是否残留汉字、
两版的段落数与小节数是否一致。

用法：python tools/_stage7_verify.py
"""
import io
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
ZH = os.path.join(ROOT, 'lib', 'l10n', 'legal_zh.dart')
EN = os.path.join(ROOT, 'lib', 'l10n', 'legal_en.dart')
CJK = re.compile(r'[\u4e00-\u9fff]')


def fields(path):
    src = open(path, encoding='utf-8').read()
    out = {}
    for name in ['policyTitle', 'agreementTitle']:
        m = re.search(name + r":\s*'(.*?)',\n", src, re.S)
        out[name] = m.group(1) if m else None
    for name in ['policyBody', 'agreementBody']:
        m = re.search(name + r":\s*'''(.*?)''',\n", src, re.S)
        out[name] = m.group(1) if m else None
    return out


def stats(text):
    if text is None:
        return None
    body = text.strip('\n')
    paras = [p for p in body.split('\n\n') if p.strip()]
    sections = [p.split('\n')[0] for p in paras if re.match(r'^[一二三四五六七八九十]+、', p)]
    en_sections = [p.split('\n')[0] for p in paras if re.match(r'^\d+\.\s', p.strip())]
    return {
        'chars': len(text),
        'cjk': len(CJK.findall(text)),
        'paras': len(paras),
        'lines': len(body.split('\n')),
        'sections_cn': len(sections),
        'sections_en': len(en_sections),
    }


def main():
    zh, en = fields(ZH), fields(EN)
    for name in ['policyTitle', 'policyBody', 'agreementTitle', 'agreementBody']:
        z, e = stats(zh.get(name)), stats(en.get(name))
        print(f'{name}: zh={z} | en={e}')
    en_all = ' '.join(v or '' for v in en.values())
    print('英文四段里的汉字数:', len(CJK.findall(en_all)))
    print('应用名检查 en 含 Meow Player:', 'Meow Player' in (en.get('policyBody') or '') and 'Meow Player' in (en.get('agreementBody') or ''))
    print('Markdown 星号 ** 残留（en）:', '**' in en_all)
    print()
    for name in ['policyBody', 'agreementBody']:
        print('==', name, '段落首行对照 ==')
        z = [p.split('\n')[0][:44] for p in (zh[name] or '').strip('\n').split('\n\n') if p.strip()]
        e = [p.split('\n')[0][:52] for p in (en[name] or '').strip('\n').split('\n\n') if p.strip()]
        for i in range(max(len(z), len(e))):
            print(f'{i:02d} ZH {z[i] if i < len(z) else "-":<46} | EN {e[i] if i < len(e) else "-"}')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
