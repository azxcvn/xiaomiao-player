# -*- coding: utf-8 -*-
"""阶段 7 收口记录：把用例表的「结果」列按用户结论填上，并插入执行记录横幅。

用法（工作目录 = 工程根）：

    py "docs\\archive\\i18n-zh-hant\\tools\\_stage7_fill.py"                 # 默认「通过」
    py "docs\\archive\\i18n-zh-hant\\tools\\_stage7_fill.py" --result 未验证

**只在用户明确给出走查结论后运行**（2026-10-05 用户：阶段 7 测试没什么问题 → 全部通过）。
保留原文件的 CRLF 行尾；只改 `09-stage7-device-walkthrough.md`。
"""

import io
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PACK_DIR = os.path.dirname(SCRIPT_DIR)
DOC = os.path.join(PACK_DIR, "09-stage7-device-walkthrough.md")

ROW = re.compile(r"^(\| H-[A-Z0-9]+-[0-9]{3}b? \|.*?) \| \|(\r?)$", re.M)
HEADING = re.compile(r"(## 3\. 用例表\r?\n)")
BANNER_MARK = "执行记录（2026-10-05，用户执行）"


def main():
    result = "通过"
    if "--result" in sys.argv:
        idx = sys.argv.index("--result")
        if idx + 1 < len(sys.argv):
            result = sys.argv[idx + 1]
    date = "2026-10-05"
    if "--date" in sys.argv:
        idx = sys.argv.index("--date")
        if idx + 1 < len(sys.argv):
            date = sys.argv[idx + 1]

    text = io.open(DOC, encoding="utf-8", newline="").read()
    text, filled = ROW.subn(lambda m: m.group(1) + " | " + result + " |" + m.group(2), text)

    banner = (
        "> **执行记录（%s，用户执行）**：**38 条全部%s**，**无缺陷**（缺陷表留空）。\n"
        "> 用户结论原话：「阶段 7 我测试没什么问题」。证据文件按 `_evidence/stage7/README.md` 的命名规则存放。\n\n"
        % (date, result)
    )
    if BANNER_MARK not in text:
        text, k = HEADING.subn(lambda m: m.group(1) + "\n" + banner, text, count=1)
    else:
        k = 0

    io.open(DOC, "w", encoding="utf-8", newline="").write(text)
    print("STAGE7 fill")
    print("  result cells filled : %d" % filled)
    print("  banner inserted     : %s" % ("yes" if k else "already present"))
    print("  doc                 : %s" % DOC)
    return 0


if __name__ == "__main__":
    sys.exit(main())
