# -*- coding: utf-8 -*-
"""阶段 1 术语覆盖审计：把 ARB 里**真实出现**的词与术语表对一遍，找出漏网术语。

用法（工作目录 = 工程根 C:\\Users\\root\\Desktop\\moumou）：

    py "杂项文件\\繁体中文接入方案\\tools\\_stage1_audit.py"

产出：`_evidence/阶段1/术语覆盖审计.md`（UTF-8，用 read 工具看；控制台中文会乱码，所以不打印中文）。
只读源码与术语表，不写任何源码。
"""

import io
import json
import os
import re
from collections import Counter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PACK_DIR = os.path.dirname(SCRIPT_DIR)
ROOT = os.path.dirname(os.path.dirname(PACK_DIR))

ARB = os.path.join(ROOT, "lib", "l10n", "app_zh.arb")
TERM_DOC = os.path.join(PACK_DIR, "03-阶段1-定调与术语表.md")
OUT_PATH = os.path.join(PACK_DIR, "_evidence", "阶段1", "术语覆盖审计.md")

HAN = r"\u4e00-\u9fff"

# 多形字：一字多繁，翻译时必须按词判（与 03-阶段1 §5 对应）
MULTI_FORM = "发干只台里后面复系制布冲尽松卷于与"

# 简体特征字：只在简体里出现的字（与 tools/arb_hant.py 的提示口径一致）
SIMPLIFIED_ONLY = (
    "们个为么这说时间让设计软网络缓视频图标页录号员单据处务动态显现开关门问题应无连线"
    "弹声画质帧择选项顺复删贴载传输冲统计键盘权隐协议条户证验码账册选暂续备浏览"
    "级结构体类别种类别历风语词汇读读写听视讯软硬盘内存线网络"
)

SIMPLIFIED_SET = set(SIMPLIFIED_ONLY)


def load_values():
    with io.open(ARB, encoding="utf-8") as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("@") and isinstance(v, str)}


def load_terms():
    """从术语表 markdown 的表格里抽出「简体」列的词。"""
    text = io.open(TERM_DOC, encoding="utf-8").read()
    terms = set()
    for line in text.split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        first = cells[0]
        if first in ("简体", "") or set(first) <= set("-: "):
            continue
        for part in re.split(r"\s*/\s*|、", first):
            part = part.strip()
            if part and re.fullmatch("[" + HAN + r"]+", part):
                terms.add(part)
    return terms


def ngrams(values, n):
    counter = Counter()
    for v in values:
        for run in re.findall("[" + HAN + r"]+", v):
            for i in range(len(run) - n + 1):
                counter[run[i : i + n]] += 1
    return counter


def main():
    values = load_values()
    terms = load_terms()
    chars = Counter()
    for v in values.values():
        for c in re.findall("[" + HAN + "]", v):
            chars[c] += 1

    lines = []
    lines.append("# 阶段 1 · 术语覆盖审计")
    lines.append("")
    lines.append("由 `tools/_stage1_audit.py` 生成，只读 `lib/l10n/app_zh.arb` 与术语表。")
    lines.append("")
    lines.append("## 概览")
    lines.append("")
    lines.append("| 项 | 值 |")
    lines.append("|---|---|")
    lines.append("| ARB 值键数 | %d |" % len(values))
    lines.append("| 出现的不同汉字数 | %d |" % len(chars))
    lines.append("| 术语表条目数（解析出的简体词） | %d |" % len(terms))
    lines.append("")

    # 未覆盖高频词：术语表里没有任何词是它的子串，且它本身不是更长词的碎片
    counters = {n: ngrams(values.values(), n) for n in (2, 3, 4, 5)}
    for n, limit in ((4, 40), (3, 60), (2, 60)):
        counter = counters[n]
        longer = counters[n + 1]

        def is_fragment(ng):
            """碎片判定：存在包含它的 (n+1) 字词、且出现次数与它相同 → 它只是更长词的一部分。"""
            return any(ng in cand and c == counter[ng] for cand, c in longer.items())

        uncovered = [
            (ng, c)
            for ng, c in counter.most_common()
            if c >= 2 and not is_fragment(ng) and not any(t in ng for t in terms)
        ][:limit]
        lines.append("## 未覆盖的 %d 字词（Top %d，按出现次数）" % (n, limit))
        lines.append("")
        lines.append("> 已过滤掉「更长词的碎片」（例如「件夹」是「文件夹」的碎片）。")
        lines.append("")
        if not uncovered:
            lines.append("无。")
        else:
            lines.append("| 词 | 次数 |")
            lines.append("|---|---|")
            for ng, c in uncovered:
                lines.append("| %s | %d |" % (ng, c))
        lines.append("")

    # 术语表里 ARB 一次都没命中的词（可能是冗余条目，也可能是改过文案后的残留）
    dead = sorted(t for t in terms if not any(t in v for v in values.values()))
    lines.append("## 术语表里 ARB 未命中的词（%d 条）" % len(dead))
    lines.append("")
    lines.append("> 不必删：多数是「将来会用」或「同义补充」；但若某条与现状明显冲突，说明文案已改，需回填。")
    lines.append("")
    lines.append("、".join(dead) if dead else "无。")
    lines.append("")

    # 多形字命中
    lines.append("## 多形字命中（一字多繁，必须按词判）")
    lines.append("")
    lines.append("| 字 | 次数 | 例（键 = 值片段） |")
    lines.append("|---|---|---|")
    for c in MULTI_FORM:
        if c not in chars:
            continue
        examples = []
        for k, v in values.items():
            if c in v:
                m = re.search(".{0,4}" + c + ".{0,4}", v)
                if m:
                    examples.append("`%s` = %s" % (k, m.group(0)))
                if len(examples) >= 2:
                    break
        lines.append("| %s | %d | %s |" % (c, chars[c], " ｜ ".join(examples)))
    lines.append("")

    # 简体特征字命中（按出现次数排序；同一个字只出现一次）
    hits = sorted(
        ((c, n) for c, n in chars.items() if c in SIMPLIFIED_SET),
        key=lambda x: (-x[1], x[0]),
    )
    lines.append("## 简体特征字命中（翻译时必须换字形）")
    lines.append("")
    lines.append("共命中 **%d** 个不同简体特征字，合计 **%d** 次。" % (len(hits), sum(c for _, c in hits)))
    lines.append("")
    lines.append("| 字 | 次数 | | 字 | 次数 | | 字 | 次数 | | 字 | 次数 |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for i in range(0, len(hits), 4):
        row = hits[i : i + 4]
        cells = []
        for c, n in row:
            cells.extend([c, str(n)])
        while len(cells) < 8:
            cells.extend(["", ""])
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with io.open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print("AUDIT ok")
    print("  arb keys      : %d" % len(values))
    print("  distinct han  : %d" % len(chars))
    print("  term entries  : %d" % len(terms))
    print("  stripped hits : %d distinct chars" % len(hits))
    print("  report        : %s" % OUT_PATH)


if __name__ == "__main__":
    main()
