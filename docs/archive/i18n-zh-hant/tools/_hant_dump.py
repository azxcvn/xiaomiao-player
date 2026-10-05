# -*- coding: utf-8 -*-
"""阶段 2 取源工具：按批次把 `lib/l10n/app_zh.arb` 里的键值导成工作文件。

用法（工作目录 = 工程根 C:\\Users\\root\\Desktop\\moumou）：

    py "docs\\archive\\i18n-zh-hant\\tools\\_hant_dump.py"           # 生成全部分批
    py "docs\\archive\\i18n-zh-hant\\tools\\_hant_dump.py" 3         # 只生成第 3 批

产出：`tools/_hant_srcN.txt`，每行 `键<TAB>简体值`（值里的换行写成 `\n`）。
只读源码，只写工具目录，不碰 ARB。
"""

import io
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# 归档位置：<repo>/docs/archive/i18n-zh-hant/tools → 上溯 4 层回到仓库根
ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(SCRIPT_DIR)))
)
ARB = os.path.join(ROOT, "lib", "l10n", "app_zh.arb")

# 分批规则：前缀 → 批次号（settings / player 前半后半各占一批）
PREFIX_BATCH = {
    "common": 1,
    "settings": 2,  # 前半；后半见 SPLIT_HALF
    "player": 4,  # 前半；后半见 SPLIT_HALF
    "bili": 6,
    "media": 6,
    "subtitle": 7,
    "danmaku": 7,
    "audio": 7,
    "decode": 7,
    "network": 8,
    "file": 8,
    "folder": 8,
    "ftp": 8,
    "webdav": 8,
    "smb": 8,
    "net": 8,
    "download": 8,
    "cache": 8,
    "directory": 8,
}
SPLIT_HALF = {"settings": (2, 3), "player": (4, 5)}
DEFAULT_BATCH = 9


def prefix_of(key):
    m = re.match(r"^([a-z]+?)([A-Z_]|$)", key)
    return m.group(1) if m else key


def assign(keys):
    """返回 {批次号: [键...]}，保持 ARB 原顺序。"""
    out = {}
    halves = {}
    for k in keys:
        p = prefix_of(k)
        if p in SPLIT_HALF:
            halves.setdefault(p, []).append(k)
            continue
        out.setdefault(PREFIX_BATCH.get(p, DEFAULT_BATCH), []).append(k)
    for p, (first, second) in SPLIT_HALF.items():
        group = halves.get(p, [])
        mid = (len(group) + 1) // 2
        out.setdefault(first, []).extend(group[:mid])
        out.setdefault(second, []).extend(group[mid:])
    return out


def main():
    wanted = int(sys.argv[1]) if len(sys.argv) > 1 else None
    with io.open(ARB, encoding="utf-8") as f:
        data = json.load(f)
    values = {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}
    batches = assign(list(values.keys()))

    print("ARB keys   : %d" % len(values))
    for n in sorted(batches):
        group = batches[n]
        print("  batch %d : %d keys" % (n, len(group)))
    print("  total   : %d" % sum(len(v) for v in batches.values()))

    for n in sorted(batches):
        if wanted is not None and n != wanted:
            continue
        path = os.path.join(SCRIPT_DIR, "_hant_src%d.txt" % n)
        # 仓库工作区是 CRLF：输出统一 CRLF
        with io.open(path, "w", encoding="utf-8", newline="\r\n") as f:
            for k in batches[n]:
                f.write("%s\t%s\n" % (k, values[k].replace("\n", "\\n")))
        print("wrote %s (%d lines)" % (os.path.basename(path), len(batches[n])))


if __name__ == "__main__":
    main()
