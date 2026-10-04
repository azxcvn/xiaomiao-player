# -*- coding: utf-8 -*-
"""校验 app_zh.arb / app_en.arb：键集合、占位符集合、plural 一致性。"""
import json
import re
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
A = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
B = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'
zh = json.loads(open(A, encoding='utf-8').read())
en = json.loads(open(B, encoding='utf-8').read())


def vals(d):
    return {k: v for k, v in d.items() if not k.startswith('@') and isinstance(v, str)}


z, e = vals(zh), vals(en)
print('zh keys', len(z), 'en keys', len(e))
print('only zh', sorted(set(z) - set(e)))
print('only en', sorted(set(e) - set(z)))


def phs(s):
    # 取所有占位符名（含 plural 占位符）
    names = set(re.findall(r'\{(\w+)[,}]', s))
    # plural 分支内层 {count}
    names |= set(re.findall(r'\{(\w+)\}', s))
    return names


def is_plural(s):
    return ', plural,' in s


bad = []
for k in sorted(z):
    if k not in e:
        continue
    pz, pe = phs(z[k]), phs(e[k])
    if pz != pe:
        bad.append(('ph', k, sorted(pz), sorted(pe)))
    if is_plural(z[k]) != is_plural(e[k]):
        bad.append(('plural', k, is_plural(z[k]), is_plural(e[k])))
for b in bad:
    print(b)

# 元数据 placeholders 与实际使用是否一致
meta_bad = []
for k, v in z.items():
    if not k.startswith('@') or k == '@@locale':
        continue
    key = k[1:]
    declared = set((zh[k].get('placeholders') or {}).keys())
    if declared != phs(v if isinstance(v, str) else z.get(key, '')):
        meta_bad.append((key, sorted(declared), sorted(phs(z.get(key, '')))))
print('meta mismatch:', meta_bad)
print('bad count', len(bad), 'meta bad', len(meta_bad))
