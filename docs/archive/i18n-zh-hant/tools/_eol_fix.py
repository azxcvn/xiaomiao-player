# -*- coding: utf-8 -*-
"""行尾归一（阶段 4 用）：把本轮新建/重写的文件统一成仓库约定的 **CRLF**。

背景：本仓库工作区是 CRLF（`core.autocrlf=true`，无 `.gitattributes`）。
用"整文件重写"的方式落盘会把文件变成 LF，`git` 会警告
`LF will be replaced by CRLF the next time Git touches it`，且与仓库里其它文件不一致。
（第一轮也踩过同一个坑，当时用的也是脚本处理。）

用法（工作目录 = 工程根 C:\\Users\\root\\Desktop\\moumou）：

    py "docs\\archive\\i18n-zh-hant\\tools\\_eol_fix.py"           # 归一
    py "docs\\archive\\i18n-zh-hant\\tools\\_eol_fix.py" --check    # 只检查，不改

按**字节**处理，不碰内容编码（不会破坏 UTF-8）。
"""

import io
import os
import sys

# 归档位置：<repo>/docs/archive/i18n-zh-hant/tools → 上溯 5 层回到仓库根
ROOT = os.path.dirname(
    os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    )
)

FILES = [
    "lib/l10n/legal.dart",
    "lib/services/app_locale_settings.dart",
    "lib/l10n/legal_zh_hant.dart",
    "lib/l10n/app_zh_Hant.arb",
    "android/app/src/main/res/values-b+zh+Hant/strings.xml",
    "test/zh_hant_locale_test.dart",
]


def report(path):
    data = io.open(path, "rb").read()
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n") - crlf
    if crlf and lf:
        return "MIXED", crlf, lf
    if lf:
        return "LF", crlf, lf
    return "CRLF", crlf, lf


def main():
    check_only = "--check" in sys.argv
    dirty = 0
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print("MISSING %s" % rel)
            continue
        state, crlf, lf = report(path)
        if state == "CRLF":
            print("OK      %s (CRLF=%d)" % (rel, crlf))
            continue
        dirty += 1
        if check_only:
            print("%-7s %s (CRLF=%d LF=%d)" % (state, rel, crlf, lf))
            continue
        data = io.open(path, "rb").read()
        data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        with io.open(path, "wb") as f:
            f.write(data)
        state2, crlf2, lf2 = report(path)
        print("FIXED   %s -> %s (CRLF=%d LF=%d)" % (rel, state2, crlf2, lf2))

    if check_only:
        print("CHECK %s (%d file(s) not CRLF)" % ("FAIL" if dirty else "PASS", dirty))
        return 1 if dirty else 0
    print("EOL done (%d file(s) fixed)" % dirty)
    return 0


if __name__ == "__main__":
    sys.exit(main())
