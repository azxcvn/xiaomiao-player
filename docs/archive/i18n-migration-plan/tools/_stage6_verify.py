# -*- coding: utf-8 -*-
"""阶段 6：核对新增 ARB 键是否都有调用点（键名 → lib/ 里的 `l10n.<key>`）。

用法：python tools/_stage6_verify.py
"""
import io
import json
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

ROOT = r'C:\Users\root\Desktop\moumou'
ZH = os.path.join(ROOT, 'lib', 'l10n', 'app_zh.arb')

sys.path.insert(0, os.path.join(ROOT, '杂项文件', '多语言支持方案', 'tools'))
import _stage6_arb as s6  # noqa: E402
import _stage6_arb2 as s62  # noqa: E402


def new_keys():
    keys = [row[0] for row in s6.E] + [row[0] for row in s62.E]
    return keys


def dart_sources():
    out = []
    for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
        for fn in files:
            if fn.endswith('.dart'):
                p = os.path.join(base, fn)
                if os.path.basename(p).startswith('app_localizations'):
                    continue
                out.append(p)
    return out


def main():
    keys = new_keys()
    zh = json.load(open(ZH, encoding='utf-8'))
    texts = []
    for p in dart_sources():
        texts.append(open(p, encoding='utf-8').read())
    blob = '\n'.join(texts)
    missing_in_arb = [k for k in keys if k not in zh]
    unused = []
    for k in keys:
        if not re.search(r'l10n\.' + re.escape(k) + r'\b', blob):
            unused.append(k)
    print(f'新增键: {len(keys)}  缺 ARB: {len(missing_in_arb)}  无调用点: {len(unused)}')
    for k in missing_in_arb:
        print('  缺 ARB:', k)
    for k in unused:
        print('  无调用点:', k)


if __name__ == '__main__':
    main()
