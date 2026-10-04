# -*- coding: utf-8 -*-
"""阶段 8：列出 ARB 里「同中文、不同键」的重复组，并给出每个键的调用点数量，
供 §1.1/§1.2 的收口归并挑唯一真源。

用法：python tools/_stage8_dupes.py
"""
import io
import json
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
ZH = os.path.join(ROOT, 'lib', 'l10n', 'app_zh.arb')
EN = os.path.join(ROOT, 'lib', 'l10n', 'app_en.arb')
PH = re.compile(r'\{(\w+)[,}]')


def dart_sources():
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for fn in files:
            if fn.endswith('.dart') and not fn.startswith('app_localizations'):
                yield open(os.path.join(base, fn), encoding='utf-8').read()


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))
    blob = '\n'.join(dart_sources())

    def refs(key):
        return len(re.findall(r'l10n\.' + re.escape(key) + r'\b', blob))

    groups = {}
    for k, v in zh.items():
        if k.startswith('@') or not isinstance(v, str):
            continue
        sig = tuple(sorted(set(PH.findall(v))))
        groups.setdefault((v, sig), []).append(k)

    dupes = {k: v for k, v in groups.items() if len(v) > 1}
    print(f'同中文多键的组数: {len(dupes)}（涉及 {sum(len(v) for v in dupes.values())} 个键）\n')
    for (val, sig), keys in sorted(dupes.items(), key=lambda kv: -len(kv[1])):
        print(f'── 「{val}」  占位符={list(sig) if sig else "无"}')
        for k in sorted(keys, key=lambda x: -refs(x)):
            print(f'     {k:46s} 调用点 {refs(k):>3}  en={en.get(k)!r}')
        print()


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
