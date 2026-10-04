# -*- coding: utf-8 -*-
"""阶段 8 探测：把残留扫描的 CJK 判定扩成「汉字 + 全角标点」后，还剩多少、都是什么。

（对应 06-遗留与待办.md §1.3 的「全角标点不在扫描口径内」缺口；本脚本只读。）
"""
import io
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
sys.path.insert(0, os.path.join(ROOT, '杂项文件', '多语言支持方案', 'tools'))
import i18n_scan as S  # noqa: E402

HAN = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]')
FULL = re.compile(r'[\u3000-\u303f\uff00-\uffef]')
PURE_PUNCT = re.compile(r'^[^A-Za-z0-9\u4e00-\u9fff]*$')


def main():
    S.CJK = re.compile(r'[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]')
    res, _expired, logs = S.scan_residual(ROOT, None, False)
    with_han = [r for r in res if HAN.search(r['text'])]
    punct_only = [r for r in res if not HAN.search(r['text']) and FULL.search(r['text'])]
    print(f'扩口径后总命中 {len(res)}；其中含汉字 {len(with_han)}；纯全角标点 {len(punct_only)}')
    print('（未扩口径时全仓残留 = 0）')
    for r in res:
        kind = '汉字' if HAN.search(r['text']) else '标点'
        print(f"  [{kind}] {r['file']}:{r['line']}  {r['text']}")


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
