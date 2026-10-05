# -*- coding: utf-8 -*-
"""阶段 3 长文自检：简体源文 vs 繁体译文 vs 英文译文的结构一致性。

用法（工作目录 = 工程根 C:\\Users\\root\\Desktop\\moumou）：

    py "docs\\archive\\i18n-zh-hant\\tools\\_stage3_legal_check.py"

产出：`_evidence/stage3/legal-texts-structure.md`（UTF-8）+ 控制台 ASCII 摘要。
门禁口径：字段名/顺序一致、段落块数一致、逐行"行类型"序列一致、正文无 Markdown 星号、无未转义 `$`。
只读源码，不写源码。
"""

import io
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PACK_DIR = os.path.dirname(SCRIPT_DIR)
# 归档位置：docs/archive/i18n-zh-hant/tools → PACK_DIR=…/i18n-zh-hant，上溯 3 层回到仓库根
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(PACK_DIR)))
OUT = os.path.join(PACK_DIR, "_evidence", "stage3", "legal-texts-structure.md")

FILES = [
    ("zh", os.path.join(ROOT, "lib", "l10n", "legal_zh.dart")),
    ("zh_Hant", os.path.join(ROOT, "lib", "l10n", "legal_zh_hant.dart")),
    ("en", os.path.join(ROOT, "lib", "l10n", "legal_en.dart")),
]
FIELDS = ["policyTitle", "policyBody", "agreementTitle", "agreementBody"]


def read(path):
    return io.open(path, encoding="utf-8").read()


def parse(text):
    """取四个字段：title 用单引号串，body 用三引号块。"""
    out = {}
    for name in FIELDS:
        m = re.search(name + r": '''(.*?)''',", text, re.S)
        if m:
            out[name] = m.group(1)
            continue
        m = re.search(name + r": '(.*?)',", text, re.S)
        out[name] = m.group(1) if m else None
    return out


def kind(line):
    s = line.strip()
    if not s:
        return "blank"
    if re.match(r"^[0-9]+\.", s):
        return "num"
    if re.match(r"^[一二三四五六七八九十]+、", s):
        return "sec"
    if s.startswith("━"):
        return "sep"
    if s.startswith("第") and s.endswith("部分"):
        return "part"
    return "text"


def profile(text):
    data = parse(text)
    bodies = [data.get("policyBody") or "", data.get("agreementBody") or ""]
    kinds = [kind(l) for b in bodies for l in b.splitlines()]
    return {
        "data": data,
        "sections": len(re.findall(r"^[一二三四五六七八九十]+、", text, re.M)),
        "parts": len(re.findall(r"^第[一二三四五六七八九十]+部分", text, re.M)),
        "blocks": sum(len([b for b in re.split(r"\n\s*\n", body) if b.strip()]) for body in bodies),
        "kinds": kinds,
        "stars": sum(b.count("**") for b in bodies),
        "dollars": sum(b.count("$") for b in bodies),
        "han": sum(1 for c in text if "\u4e00" <= c <= "\u9fff"),
    }


def main():
    profiles = {}
    for label, path in FILES:
        if not os.path.exists(path):
            print("FAIL: missing " + path)
            return 1
        profiles[label] = profile(read(path))

    zh, hant, en = profiles["zh"], profiles["zh_Hant"], profiles["en"]
    errors = []

    for name in FIELDS:
        if zh["data"].get(name) in (None, ""):
            errors.append("zh missing field " + name)
        if hant["data"].get(name) in (None, ""):
            errors.append("zh_Hant missing field " + name)
        if en["data"].get(name) in (None, ""):
            errors.append("en missing field " + name)

    if zh["sections"] != hant["sections"]:
        errors.append("section count differs: zh=%d zh_Hant=%d" % (zh["sections"], hant["sections"]))
    if zh["parts"] != hant["parts"]:
        errors.append("part count differs: zh=%d zh_Hant=%d" % (zh["parts"], hant["parts"]))
    if zh["blocks"] != hant["blocks"]:
        errors.append("paragraph blocks differ: zh=%d zh_Hant=%d" % (zh["blocks"], hant["blocks"]))
    if zh["kinds"] != hant["kinds"]:
        errors.append("line-kind sequence differs (zh %d lines vs zh_Hant %d lines)" % (len(zh["kinds"]), len(hant["kinds"])))
    for label in ("zh", "zh_Hant", "en"):
        if profiles[label]["stars"]:
            errors.append("%s: body contains ** (%d)" % (label, profiles[label]["stars"]))
        if profiles[label]["dollars"]:
            errors.append("%s: body contains unescaped $ (%d)" % (label, profiles[label]["dollars"]))

    lines = ["# 阶段 3 · 长文正文结构对比", "", "由 `tools/_stage3_legal_check.py` 生成。", ""]
    lines.append("| 项 | 简体 zh | 繁體 zh_Hant | 英文 en |")
    lines.append("|---|---|---|---|")
    lines.append("| 小节数（一、二、…） | %d | %d | %d |" % (zh["sections"], hant["sections"], en["sections"]))
    lines.append("| 「第 N 部分」数 | %d | %d | %d |" % (zh["parts"], hant["parts"], en["parts"]))
    lines.append("| 段落块数 | %d | %d | %d |" % (zh["blocks"], hant["blocks"], en["blocks"]))
    lines.append("| 正文行数 | %d | %d | %d |" % (len(zh["kinds"]), len(hant["kinds"]), len(en["kinds"])))
    lines.append("| 正文内 `**` | %d | %d | %d |" % (zh["stars"], hant["stars"], en["stars"]))
    lines.append("| 正文内 `$` | %d | %d | %d |" % (zh["dollars"], hant["dollars"], en["dollars"]))
    lines.append("| 汉字数（整文件） | %d | %d | %d |" % (zh["han"], hant["han"], en["han"]))
    lines.append("")
    lines.append("## 结论")
    lines.append("")
    if errors:
        lines.append("**不通过**：")
        lines.append("")
        for e in errors:
            lines.append("- " + e)
    else:
        lines.append("**通过**：字段齐全、小节/部分/段落/逐行结构一致、正文无星号与未转义 `$`。")
    lines.append("")
    lines.append("## 繁体标题（已定稿）")
    lines.append("")
    lines.append("- `policyTitle` = %s" % hant["data"].get("policyTitle"))
    lines.append("- `agreementTitle` = %s" % hant["data"].get("agreementTitle"))
    lines.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(lines) + "\n")

    print("LEGAL " + ("FAIL" if errors else "PASS"))
    print("  sections   zh=%d hant=%d en=%d" % (zh["sections"], hant["sections"], en["sections"]))
    print("  parts      zh=%d hant=%d" % (zh["parts"], hant["parts"]))
    print("  blocks     zh=%d hant=%d en=%d" % (zh["blocks"], hant["blocks"], en["blocks"]))
    print("  body lines zh=%d hant=%d" % (len(zh["kinds"]), len(hant["kinds"])))
    print("  body stars zh=%d hant=%d en=%d" % (zh["stars"], hant["stars"], en["stars"]))
    print("  body $     zh=%d hant=%d en=%d" % (zh["dollars"], hant["dollars"], en["dollars"]))
    print("  han chars  zh=%d hant=%d" % (zh["han"], hant["han"]))
    for e in errors:
        print("  - " + e)
    print("  report     " + OUT)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
