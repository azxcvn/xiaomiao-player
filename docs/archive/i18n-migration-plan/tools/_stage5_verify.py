# -*- coding: utf-8 -*-
"""阶段 5 收口校验：新增 ARB 键是否有调用点 + 是否有键被用在别的文件里。

- 未被任何 lib/ 文件引用的新键 → 可能是「该替换却没替换」或「多建的键」；
- 同时打印每个键出现在哪些文件（便于核对是否用错键）。
"""
import json
import io
import re
import sys
import glob
import subprocess
import collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = r'C:\Users\root\Desktop\moumou'

zh = json.loads(open(ROOT + r'\lib\l10n\app_zh.arb', encoding='utf-8').read())
old = json.loads(subprocess.run(['git', 'show', 'HEAD:lib/l10n/app_zh.arb'], cwd=ROOT,
                                capture_output=True).stdout.decode('utf-8'))
new = [k for k in zh if not k.startswith('@') and k not in old]

uses = collections.defaultdict(set)
srcs = {}
for p in glob.glob(ROOT + r'\lib\**\*.dart', recursive=True):
    rel = p[len(ROOT) + 1:]
    if rel.startswith('lib\\l10n\\'):
        continue
    srcs[rel] = open(p, encoding='utf-8').read()

for k in new:
    pat = re.compile(r'\b' + re.escape(k) + r'\b')
    for rel, t in srcs.items():
        if pat.search(t):
            uses[k].add(rel)

unused = [k for k in new if not uses[k]]
print(f'阶段 5 新增键 {len(new)} 个；未被引用的 {len(unused)} 个：')
for k in unused:
    print('  ', k, '=', zh[k])
print()
print('被引用超过 3 个文件的键（多为 common*，仅供核对）：')
for k in new:
    if len(uses[k]) > 3:
        print('  ', k, len(uses[k]), sorted(uses[k])[:5])
