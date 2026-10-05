# -*- coding: utf-8 -*-
"""繁体（zh_Hant）ARB 工具：seed / apply / check / status。

工作目录 = 工程根（C:\\Users\\root\\Desktop\\moumou）：

    py "杂项文件\\繁体中文接入方案\\tools\\arb_hant.py" seed
    py "杂项文件\\繁体中文接入方案\\tools\\arb_hant.py" apply "杂项文件\\繁体中文接入方案\\tools\\_hant_batch1.json"
    py "杂项文件\\繁体中文接入方案\\tools\\arb_hant.py" check
    py "杂项文件\\繁体中文接入方案\\tools\\arb_hant.py" status

设计约定（见 ../04-阶段2-ARB译文.md）：
- 源语言模板是 lib/l10n/app_zh.arb；繁体目标是 lib/l10n/app_zh_Hant.arb。
- 繁体文件**不写 @ 元数据**（元数据只在模板里，与 app_en.arb 现状一致）。
- 硬门禁（exit 1）：@@locale 不对、键集合不一致、占位符集合不一致、ICU 类型不一致、空值、非法元数据。
- 仅提示（不影响 exit code）：与简体逐字相同的键、命中简体特征字的键——用来看"哪里可能漏翻"。
- 控制台只输出 ASCII（Windows 终端中文会乱码）；中文明细写进 tools/_hant_check_report.md。
"""

import argparse
import io
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ZH = os.path.join("lib", "l10n", "app_zh.arb")
DEFAULT_HANT = os.path.join("lib", "l10n", "app_zh_Hant.arb")
DEFAULT_REPORT = os.path.join(SCRIPT_DIR, "_hant_check_report.md")

HANT_LOCALE = "zh_Hant"

# 简体特征字：这些字只在简体里出现，繁体必须换成别的字形。
# 只用于"提示"，不是门禁（会有漏网，也可能有极少数误报）。
# ⚠️ 不要把「硬」「存」这类**繁体同样这么写**的字放进来：阶段 2 实测它们淹没了真命中（52 条提示里 50 条是它俩）。
SIMPLIFIED_ONLY_CHARS = (
    "们个为么这说时间让设计软网络缓视频图标页录号员单据处务动态显现开关门问题应无连线"
    "弹声画质帧择选项顺复删贴载传输冲统计键盘权隐协议条户证验码账册选暂续备浏览"
    "级结构体类别种历风语词汇读听视讯内"
)

ICU_TYPES = ("plural", "selectordinal", "select")


def load_json(path):
    with io.open(path, encoding="utf-8") as f:
        return json.load(f)


def dump_json(path, data):
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.isdir(parent):
        os.makedirs(parent)
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def messages(arb):
    """取"值键"（丢掉 @@locale 与 @key 元数据），保持原顺序。"""
    return {k: v for k, v in arb.items() if not k.startswith("@") and isinstance(v, str)}


def meta_keys(arb):
    return [k for k in arb if k.startswith("@") and k != "@@locale"]


def placeholders(s):
    names = set(re.findall(r"\{(\w+)\s*[,}]", s))
    names |= set(re.findall(r"\{(\w+)\}", s))
    return names


def icu_types(s):
    found = set()
    for t in ICU_TYPES:
        if re.search(r",\s*" + t + r"\s*,", s):
            found.add(t)
    return found


def has_han(s):
    return any("\u4e00" <= c <= "\u9fff" for c in s)


def han_chars(s):
    return [c for c in s if "\u4e00" <= c <= "\u9fff"]


def cmd_seed(args):
    zh = load_json(args.zh)
    out = args.out or args.hant
    if os.path.exists(out) and not args.force:
        print("REFUSE: target exists, use --force to overwrite: " + out)
        return 1
    values = messages(zh)
    data = {"@@locale": HANT_LOCALE}
    for k, v in values.items():
        data[k] = v  # 骨架先原样拷简体，交给 apply 逐批替换
    dump_json(out, data)
    print("SEED ok")
    print("  source      : " + args.zh)
    print("  target      : " + out)
    print("  locale      : " + HANT_LOCALE)
    print("  keys        : " + str(len(values)))
    print("  metadata    : dropped (template only)")
    print("  next        : apply batches, then check")
    return 0


def cmd_apply(args):
    zh = load_json(args.zh)
    out = args.out or args.hant
    if not os.path.exists(out):
        print("FAIL: target not found, run seed first: " + out)
        return 1
    batch = load_json(args.batch)
    if not isinstance(batch, dict):
        print("FAIL: batch must be a JSON object {key: value}")
        return 1

    tmpl = messages(zh)
    hant = load_json(out)
    errors = []
    applied = 0

    for k, v in batch.items():
        if k.startswith("@"):
            errors.append("metadata not allowed in zh_Hant arb: " + k)
            continue
        if k not in tmpl:
            errors.append("key not in template: " + k)
            continue
        if not isinstance(v, str) or not v.strip():
            errors.append("empty value: " + k)
            continue
        p_t, p_h = placeholders(tmpl[k]), placeholders(v)
        if p_t != p_h:
            errors.append(
                "placeholder mismatch: %s  template=%s  batch=%s"
                % (k, sorted(p_t), sorted(p_h))
            )
            continue
        t_t, t_h = icu_types(tmpl[k]), icu_types(v)
        if t_t != t_h:
            errors.append(
                "icu-type mismatch: %s  template=%s  batch=%s" % (k, sorted(t_t), sorted(t_h))
            )
            continue
        hant[k] = v
        applied += 1

    if errors:
        print("FAIL: batch rejected, nothing written (" + str(len(errors)) + " errors)")
        for e in errors[:40]:
            print("  - " + e)
        if len(errors) > 40:
            print("  ... " + str(len(errors) - 40) + " more")
        return 1

    dump_json(out, hant)
    same = sum(1 for k, v in messages(hant).items() if v == tmpl.get(k))
    print("APPLY ok")
    print("  batch   : " + args.batch)
    print("  applied : " + str(applied))
    print("  total   : " + str(len(tmpl)))
    print("  still same as zh : " + str(same))
    return 0


def cmd_check(args):
    zh_path = args.zh
    hant_path = args.hant
    report_path = args.report or DEFAULT_REPORT

    for p in (zh_path, hant_path):
        if not os.path.exists(p):
            print("FAIL: not found: " + p)
            return 1

    zh = load_json(zh_path)
    hant = load_json(hant_path)
    tmpl = messages(zh)
    got = messages(hant)

    hard = []
    locale = hant.get("@@locale")
    if locale != HANT_LOCALE:
        hard.append("@@locale must be '%s', got '%s'" % (HANT_LOCALE, locale))
    extra_meta = meta_keys(hant)
    if extra_meta:
        hard.append("metadata keys are not allowed in zh_Hant arb: " + ", ".join(sorted(extra_meta)[:10]))

    missing = [k for k in tmpl if k not in got]
    extra = [k for k in got if k not in tmpl]
    if missing:
        hard.append("missing keys: %d (first: %s)" % (len(missing), ", ".join(missing[:8])))
    if extra:
        hard.append("unknown keys: %d (first: %s)" % (len(extra), ", ".join(extra[:8])))

    empty, ph_bad, icu_bad, untranslated, suspicious = [], [], [], [], []
    for k, v in tmpl.items():
        if k not in got:
            continue
        hv = got[k]
        if not hv.strip():
            empty.append(k)
            continue
        if placeholders(v) != placeholders(hv):
            ph_bad.append((k, sorted(placeholders(v)), sorted(placeholders(hv))))
        if icu_types(v) != icu_types(hv):
            icu_bad.append((k, sorted(icu_types(v)), sorted(icu_types(hv))))
        hits = sorted(set(han_chars(hv)) & set(SIMPLIFIED_ONLY_CHARS))
        if hv == v and has_han(hv):
            untranslated.append((k, hv))
        if hits:
            suspicious.append((k, hv, hits))

    if empty:
        hard.append("empty values: %d (first: %s)" % (len(empty), ", ".join(empty[:8])))
    if ph_bad:
        hard.append("placeholder mismatch: %d (first: %s)" % (len(ph_bad), ph_bad[0][0]))
    if icu_bad:
        hard.append("icu-type mismatch: %d (first: %s)" % (len(icu_bad), icu_bad[0][0]))

    # 中文明细报告（UTF-8，给 AI 执行者用 read 工具看）
    lines = []
    lines.append("# zh_Hant ARB 检查报告")
    lines.append("")
    lines.append("- 模板：" + zh_path)
    lines.append("- 目标：" + hant_path)
    lines.append("- 键数：%d / 模板 %d" % (len(got), len(tmpl)))
    lines.append("- 硬错误：%d" % len(hard))
    lines.append("- 疑似未转换（与简体逐字相同且含汉字）：%d" % len(untranslated))
    lines.append("- 命中简体特征字：%d" % len(suspicious))
    lines.append("")
    if hard:
        lines.append("## 硬错误（必须清零）")
        lines.append("")
        for e in hard:
            lines.append("- " + e)
        lines.append("")
    if ph_bad or icu_bad:
        lines.append("## 占位符 / ICU 不一致明细")
        lines.append("")
        for k, a, b in ph_bad:
            lines.append("- 占位符 `%s`：模板 %s / 目标 %s" % (k, a, b))
        for k, a, b in icu_bad:
            lines.append("- ICU `%s`：模板 %s / 目标 %s" % (k, a, b))
        lines.append("")
    if untranslated:
        lines.append("## 疑似未转换（与简体逐字相同且含汉字，逐条确认）")
        lines.append("")
        for k, v in untranslated:
            lines.append("- `%s` = %s" % (k, v))
        lines.append("")
    if suspicious:
        lines.append("## 命中简体特征字（可能漏翻，逐条确认）")
        lines.append("")
        for k, v, hits in suspicious:
            lines.append("- `%s` = %s ｜ 命中：%s" % (k, v, " ".join(hits)))
        lines.append("")
    if not hard and not untranslated and not suspicious:
        lines.append("全部通过：键集合、占位符、ICU、空值、locale 均一致，且未发现简体残留。")
        lines.append("")
    with io.open(report_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    print("CHECK " + ("FAIL" if hard else "PASS"))
    print("  template keys : " + str(len(tmpl)))
    print("  target keys   : " + str(len(got)))
    print("  hard errors   : " + str(len(hard)))
    print("  same as zh    : " + str(len(untranslated)) + " (warning)")
    print("  simp-char hit : " + str(len(suspicious)) + " (warning)")
    print("  report        : " + report_path)
    for e in hard:
        print("  - " + e)
    return 1 if hard else 0


def cmd_status(args):
    zh = load_json(args.zh)
    if not os.path.exists(args.hant):
        print("STATUS: target not found: " + args.hant)
        return 1
    hant = load_json(args.hant)
    tmpl = messages(zh)
    got = messages(hant)
    translated = sum(1 for k, v in got.items() if tmpl.get(k) != v)
    print("STATUS")
    print("  template keys : " + str(len(tmpl)))
    print("  target keys   : " + str(len(got)))
    print("  translated    : " + str(translated))
    print("  remaining     : " + str(len(tmpl) - translated))
    return 0


def main():
    ap = argparse.ArgumentParser(description="zh_Hant ARB tool (seed/apply/check/status)")
    ap.add_argument("command", choices=["seed", "apply", "check", "status"])
    ap.add_argument("--zh", default=DEFAULT_ZH, help="模板 arb（默认 lib/l10n/app_zh.arb）")
    ap.add_argument("--hant", default=DEFAULT_HANT, help="繁体 arb（默认 lib/l10n/app_zh_Hant.arb）")
    ap.add_argument("--out", default=None, help="输出路径（seed/apply 用，默认同 --hant）")
    ap.add_argument("--report", default=None, help="check 报告路径（默认 tools/_hant_check_report.md）")
    ap.add_argument("--batch", default=None, help="apply 的批次 json")
    ap.add_argument("--force", action="store_true", help="seed 覆盖已存在的目标文件")
    args = ap.parse_args()

    if args.command == "seed":
        return cmd_seed(args)
    if args.command == "apply":
        if not args.batch:
            print("FAIL: apply needs --batch <file.json>")
            return 1
        return cmd_apply(args)
    if args.command == "check":
        return cmd_check(args)
    return cmd_status(args)


if __name__ == "__main__":
    sys.exit(main())
