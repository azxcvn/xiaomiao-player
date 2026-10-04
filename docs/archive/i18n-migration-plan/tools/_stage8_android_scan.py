# -*- coding: utf-8 -*-
"""阶段 8 侦察：列出 android/ 下 .kt / .xml 里的中文字符串字面量（跳过注释）。

用法：python tools/_stage8_android_scan.py [--json]
"""
import io
import json
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
ANDROID = os.path.join(ROOT, 'android')
CJK = re.compile(r'[\u4e00-\u9fff]')
KT_LIT = re.compile(r'"(?:\\.|[^"\\\n])*"')
XML_LIT = re.compile(r'"[^"<>\n]*"|>([^<>]+)<')


def strip_kt_comments(text):
    """把注释内容替换成等长空白（保持行号/列号不变）。"""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
        elif ch == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                if text[k] != '\n':
                    out[k] = ' '
            i = j
        elif ch == '"':
            j = i + 1
            while j < n:
                if text[j] == '\\':
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            i = j + 1
        else:
            i += 1
    return ''.join(out)


def line_of(text, pos):
    return text.count('\n', 0, pos) + 1


def main():
    rows = []
    for base, dirs, files in os.walk(ANDROID):
        dirs[:] = [d for d in dirs if d not in ('build', '.gradle', '.cxx')]
        for fn in files:
            p = os.path.join(base, fn)
            rel = os.path.relpath(p, ROOT).replace('\\', '/')
            if fn.endswith('.kt'):
                raw = open(p, encoding='utf-8').read()
                clean = strip_kt_comments(raw)
                for m in KT_LIT.finditer(clean):
                    lit = m.group(0)
                    if CJK.search(lit):
                        rows.append({'file': rel, 'line': line_of(clean, m.start()),
                                     'text': lit[:120], 'src': raw.split('\n')[line_of(clean, m.start()) - 1].strip()[:160]})
            elif fn.endswith('.xml'):
                raw = open(p, encoding='utf-8').read()
                for m in XML_LIT.finditer(raw):
                    lit = m.group(0)
                    if CJK.search(lit):
                        rows.append({'file': rel, 'line': line_of(raw, m.start()),
                                     'text': lit[:120], 'src': raw.split('\n')[line_of(raw, m.start()) - 1].strip()[:160]})
    if '--json' in sys.argv:
        print(json.dumps(rows, ensure_ascii=True, indent=1))
        return
    per = {}
    for r in rows:
        per.setdefault(r['file'], []).append(r)
    for f in sorted(per, key=lambda k: -len(per[k])):
        print(f'== {f}  ({len(per[f])} 处)')
        for r in per[f]:
            print(f"   {r['line']:>5}  {r['text']}")


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
