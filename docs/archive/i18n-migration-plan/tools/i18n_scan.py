# -*- coding: utf-8 -*-
"""多语言迁移：扫描 / 门禁 / 任务清单生成工具（只读扫描，除 tasks --write 外不改任何文件）。

用途（配合 ../01-execution-protocol.md 使用）：
  python i18n_scan.py baseline               # 总体数字（与 04-data-baseline.md 对账）
  python i18n_scan.py residual               # 全仓残留中文（白名单外）→ 有残留 exit 1
  python i18n_scan.py residual --path lib/pages/settings   # 只查某目录（阶段门禁）
  python i18n_scan.py enums                  # 枚举/表清单（表改造范围）
  python i18n_scan.py dupes                  # 跨文件重复文案（common.* 归并依据）
  python i18n_scan.py tasks                  # 生成/更新 ../03-task-list.md（保留已勾选状态）
  python i18n_scan.py all                    # 以上全部摘要（不含写文件）

约定：
  * 只统计数据，不修改源码；`tasks` 只写 ../03-task-list.md 与 ../05-residual-chinese-report.md。
  * 控制台输出保持 ASCII（避免 Windows 终端中文乱码）；中文内容写入 UTF-8 报告文件。
  * 口径见 ../04-data-baseline.md「数据口径」一节；白名单见同目录 whitelist.json。

退出码：0 = 通过；1 = residual 发现残留（或白名单过期项）；2 = 用法/环境错误。
"""

import argparse
import json
import os
import re
import sys

# ---------------------------------------------------------------- 基础

CJK = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]')
# 汉字区（不含全角标点）：判断「只在 --fullwidth 下才命中」的白名单条目用
HAN = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]')
# 字符串字面量：'''...''' / """...""" / '...' / "..."（含转义，不跨行）
LIT = re.compile(
    r"'''.*?'''|\"\"\".*?\"\"\"|'(?:\\.|[^'\\\n])*'|\"(?:\\.|[^\"\\\n])*\"", re.S
)
ENUM_DECL = re.compile(r"enum\s+(\w+)\s*\{")
ENUM_ENTRY = re.compile(r"^\s{2,}([A-Za-z_]\w*)\s*\(", re.M)
MAP_ENTRY = re.compile(r"['\"][^'\"]*['\"]\s*:\s*['\"][^'\"]*[\u4e00-\u9fff]")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PKG_DIR = os.path.dirname(SCRIPT_DIR)          # 多语言支持方案/
TASKS_MD = os.path.join(PKG_DIR, "03-task-list.md")
RESIDUAL_MD = os.path.join(PKG_DIR, "05-residual-chinese-report.md")
WHITELIST_JSON = os.path.join(SCRIPT_DIR, "whitelist.json")

# 生成物与「按语言拆分的正文常量」：它们本身就是**某一种语言**的文案表
# （gen_l10n 生成的 AppLocalizations、legal_zh / legal_zh_hant / legal_en.dart 长文正文），
# 不是「待翻译的硬编码文案」。所有扫描（baseline / residual / dupes / tasks）
# 一律跳过，否则会被统计成待办任务、也会被算成残留中文。
# 残留门禁侧另有 whitelist.json 的整文件豁免（两道保险，理由写在那边）。
GENERATED_SKIP = {
    "lib/l10n/app_localizations.dart",
    "lib/l10n/app_localizations_zh.dart",
    "lib/l10n/app_localizations_en.dart",
    "lib/l10n/legal_zh.dart",
    "lib/l10n/legal_zh_hant.dart",
    "lib/l10n/legal_en.dart",
}

# 阶段归属（顺序敏感）：表改造相关文件由扫描动态识别，见 phase_of()
PHASE_TITLES = {
    0: "阶段 0 · 基建与测试夹具",
    1: "阶段 1 · 公共层与表改造",
    2: "阶段 2 · 入口、导航与语言入口",
    3: "阶段 3 · 设置页群",
    4: "阶段 4 · 播放器",
    5: "阶段 5 · 其余业务页",
    6: "阶段 6 · 服务/模型/工具层",
    7: "阶段 7 · 长文（隐私政策/用户协议）",
    8: "阶段 8 · Android 原生与收尾",
}
PHASE0_FILES = {"test/l10n_test_helper.dart"}

# 方案新增的文件（不在扫描范围内，因此写死在生成器里；勾选同样会被保留）
NEW_FILE_TASKS = [
    (0, "pubspec.yaml",
     "加 flutter_localizations + intl + flutter: generate: true（只允许这一处依赖改动）"),
    (0, "l10n.yaml",
     "新建：arb-dir=lib/l10n、template=app_zh.arb、nullable-getter: false、preferred-supported-locales: [zh]"),
    (0, "lib/l10n/app_zh.arb",
     "新建：模板（源语言中文），先放 appTitle / commonCancel 两个键"),
    (0, "lib/l10n/app_en.arb",
     "新建：英文（appTitle = Meow Player）"),
    (0, "lib/services/app_locale_settings.dart",
     "新建：语言偏好持久化，键 app_locale，值只允许 'zh' | 'en'，默认 'zh'（无「跟随系统」）"),
    (0, "test/l10n_test_helper.dart",
     "新建：测试夹具（钉 Locale('zh')），保住 535 处 find.text('中文') 断言"),
    (1, "lib/l10n/label_maps.dart",
     "新建：31 个枚举 / 表 → 文案的 UI 侧映射（禁止在 models/utils 里 import l10n）"),
    (2, "lib/widgets/language_picker_dialog.dart",
     "新建：首启语言选择弹窗（隐私同意后弹一次；默认选中简体中文；选项 简体中文 / English）"),
    (2, "test/language_picker_test.dart",
     "新建（AI 追加，方案未列）：语言入口回归测试——弹窗默认选中简体中文 / 选 English 写入 app_locale / 取消不改 / 设置页「语言」组在弹幕与下载之间"),
    (2, "test/app_smoke_test.dart",
     "新建（AI 追加，方案未列）：**真实 MoumouApp 冒烟测试**——阶段 2 曾因 main.dart 用 MaterialApp 之上的 context 取 l10n 而启动即崩（analyze 与当时全部测试都拦不住），本测试是那道防线"),
    (7, "lib/l10n/legal_zh.dart",
     "新建：隐私政策/用户协议中文正文（从 privacy_policy_content.dart 迁入，保留多行原文排版）"),
    (7, "lib/l10n/legal_en.dart",
     "新建：英文正文（AI 翻译即可，用户已确认无需专业/法务审校）"),
    (7, "lib/l10n/legal.dart",
     "新建（方案 §1.11 的可选入口文件）：按 locale 取长文正文（legalTextsFor），未知语言回落中文"),
    (7, "test/legal_texts_test.dart",
     "新建（AI 追加，方案 §1.11 第 6 步要求）：断言 zh / en 两套长文的 4 段都非空、en 无残留汉字"),
    (6, "lib/utils/error_codes.dart",
     "新建（阶段 6）：服务层错误码表（纯数据，无 Flutter / l10n 依赖）——services/models/utils 只产出「码 + 参数」"),
    (6, "lib/l10n/error_texts.dart",
     "新建（阶段 6）：服务层「码 + 参数」→ 文案 的 UI 侧翻译 + 统一入口 serviceErrorText"),
    (6, "lib/widgets/dolby_vision_hint.dart",
     "新建（阶段 6）：杜比视界引导弹窗从 lib/utils 搬到 UI 层（utils 不许 import l10n），原 lib/utils/dolby_vision_hint.dart 删除"),
    (8, "android/app/src/main/res/values/strings.xml",
     "新建：默认（中文）资源，app_name = 小喵Player"),
    (8, "android/app/src/main/res/values-en/strings.xml",
     "新建：英文资源，app_name = Meow Player"),
]
PHASE2_FILES = {
    "lib/main.dart",
    "lib/widgets/capsule_nav_bar.dart",
    "lib/widgets/main_scaffold.dart",
    "lib/widgets/app_frame.dart",
    "lib/pages/settings/settings_page.dart",
}
# 阶段 1 清单里这 8 个文件的中文是「给界面看的文案」（抛出的错误消息，或
# 「未知语言」「年度大会员」「无偏移」这类显示文本）：按 02-implementation-plan.md §1.8 要改成
# 「码 + 参数」、文案由 UI 层翻译，而它们的显示点都在阶段 3–5 的 UI 文件里。
# 用户已拍板：留到阶段 6，与 ftp_client / bili_http 等同类的服务层文案一起做。
PHASE6_FILES = {
    "lib/services/network/webdav_client.dart",
    "lib/utils/file_ops.dart",
    "lib/utils/player_diagnostics.dart",
    "lib/services/build_info_service.dart",
    "lib/services/danmaku_search_store.dart",
    "lib/models/wyzie_models.dart",
    "lib/models/bilibili_user.dart",
    "lib/utils/danmaku_timeline.dart",
}
PHASE7_FILES = {
    "lib/services/privacy_policy_content.dart",
    "lib/pages/settings/privacy_policy_page.dart",
    "lib/widgets/privacy_policy_dialog.dart",
}


def find_root(explicit=None):
    """默认从脚本位置向上找含 pubspec.yaml 的目录。"""
    if explicit:
        return os.path.abspath(explicit)
    d = PKG_DIR
    for _ in range(6):
        if os.path.exists(os.path.join(d, "pubspec.yaml")):
            return d
        d = os.path.dirname(d)
    sys.stderr.write("ERROR: cannot locate project root (no pubspec.yaml). Use --root.\n")
    sys.exit(2)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def line_text(text, pos):
    s = text.rfind("\n", 0, pos) + 1
    e = text.find("\n", pos)
    return text[s : e if e != -1 else len(text)]


def is_comment_line(lt):
    s = lt.lstrip()
    return s.startswith("//") or s.startswith("*")


# 日志调用（红线 13：日志永远保持中文，因此**不算残留**、也不进 ARB）。
# 认多行调用（`debugPrint(\n  '…',\n)`），按括号配平取整个参数区。
# `appendDartLog` 是本仓库自己的日志出口（崩溃日志落盘，见 services/crash_log_service.dart）。
LOG_CALL = re.compile(
    r"(?<![\w.])(debugPrint|debugPrintStack|print|developer\.log|"
    r"appendDartLog|CrashLogService\.appendDartLog)\s*\("
)


def log_spans(text, pattern=None):
    """日志调用「参数区」的字符区间 (start, end) 列表。"""
    pattern = pattern or LOG_CALL
    spans = []
    for m in pattern.finditer(text):
        if is_comment_line(line_text(text, m.start())):
            continue
        start = m.end() - 1  # 指向 '('
        i = start
        depth = 0
        while i < len(text):
            ch = text[i]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    break
            elif ch in "'\"":
                lit = LIT.match(text, i)  # 跳过字符串字面量，避免其中的括号干扰配平
                if lit and lit.end() > i:
                    i = lit.end()
                    continue
            i += 1
        spans.append((start, i))
    return spans


# ── Android（Kotlin / XML）：阶段 8 起 `residual --include-android` 也扫这些 ──────
#
# Kotlin 的日志调用（红线 13：日志永远保持中文，既不算残留也不翻译）：
# Log.d/i/w/e/v（含 android.util.Log 全限定写法）、println、Timber.*。
KOTLIN_LOG_CALL = re.compile(
    r"(?<![\w.])(?:android\.util\.)?Log\.[dviwe]\s*\(|(?<![\w.])println\s*\(|"
    r"(?<![\w.])Timber\.[dviwe]\s*\("
)
# Kotlin 字符串字面量（不含换行的普通串 + 三引号原始串）
KT_LIT = re.compile(r'"""(?:.|\n)*?"""|"(?:\\.|[^"\\\n])*"')
# XML：文本节点 + 属性值
XML_LIT = re.compile(r'"[^"<>\n]*"|>([^<>]+)<')


def strip_kt_comments(text):
    """把 Kotlin 注释替换成等长空白（保持行号不变），保留字符串字面量原样。"""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif ch == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                if text[k] != "\n":
                    out[k] = " "
            i = j
        elif ch == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            i = j + 1
        else:
            i += 1
    return "".join(out)


def strip_xml_comments(text):
    """把 XML 注释替换成等长空白（保持行号不变）。"""
    out = list(text)
    for m in re.finditer(r"<!--(?:.|\n)*?-->", text):
        for k in range(m.start(), m.end()):
            if text[k] != "\n":
                out[k] = " "
    return "".join(out)


def kotlin_literals(text):
    """Kotlin 源码里的中文字面量（跳过注释与日志调用参数区）。"""
    clean = strip_kt_comments(text)
    spans = log_spans(clean, KOTLIN_LOG_CALL)
    for m in KT_LIT.finditer(clean):
        lit = m.group(0)
        if not CJK.search(lit):
            continue
        is_log = any(s <= m.start() < e for s, e in spans)
        yield line_of(clean, m.start()), lit, line_text(clean, m.start()), is_log


def xml_literals(text):
    """XML（资源/清单）里的中文字面量（属性值 + 文本节点，跳过注释）。"""
    clean = strip_xml_comments(text)
    for m in XML_LIT.finditer(clean):
        lit = m.group(0)
        if not CJK.search(lit):
            continue
        yield line_of(clean, m.start()), lit, line_text(clean, m.start()), False


def iter_android(root):
    """android/ 下的 Kotlin / XML 源文件（跳过 build 产物）。"""
    base = os.path.join(root, "android")
    if not os.path.isdir(base):
        return
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in ("build", ".gradle", ".cxx", ".idea")]
        for fn in filenames:
            if fn.endswith((".kt", ".xml")):
                p = os.path.join(dirpath, fn)
                rel = os.path.relpath(p, root).replace("\\", "/")
                yield p, rel



def iter_dart(root, sub):
    base = os.path.join(root, sub)
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in (".git", "build", ".dart_tool")]
        for fn in filenames:
            if fn.endswith(".dart"):
                p = os.path.join(dirpath, fn)
                rel = os.path.relpath(p, root).replace("\\", "/")
                if rel in GENERATED_SKIP:
                    continue
                yield p, rel


def code_literals(text):
    """产出 (行号, 字面量正文, 所在行文本, 是否日志)，跳过注释行。

    「是否日志」= 该字面量落在 debugPrint/print 等日志调用的参数区里（红线 13：
    日志永远中文，既不算残留、也不许顺手英文化，因此统计与门禁都排除它们）。
    """
    spans = log_spans(text)
    for m in LIT.finditer(text):
        lit = m.group(0)
        if not CJK.search(lit):
            continue
        lt = line_text(text, m.start())
        if is_comment_line(lt):
            continue
        is_log = any(s <= m.start() < e for s, e in spans)
        yield line_of(text, m.start()), lit, lt, is_log


# ---------------------------------------------------------------- 白名单

def load_whitelist():
    if not os.path.exists(WHITELIST_JSON):
        return {"files": [], "lines": []}
    with open(WHITELIST_JSON, encoding="utf-8") as fh:
        return json.load(fh)


# ---------------------------------------------------------------- 扫描

def scan_files(root, sub="lib"):
    """返回 [{file, occ, distinct, chars, lines}]（与 residual 同口径：白名单不计数）"""
    wl = load_whitelist()
    wl_files = {e["path"] for e in wl.get("files", [])}
    wl_lines = {}
    for e in wl.get("lines", []):
        wl_lines.setdefault(e["path"], set()).add(int(e["line"]))
    out = []
    for p, rel in iter_dart(root, sub):
        if rel in wl_files:
            continue
        with open(p, encoding="utf-8") as fh:
            text = fh.read()
        occ = 0
        distinct = set()
        chars = 0
        lines = []
        for ln, lit, _lt, is_log in code_literals(text):
            if is_log or ln in wl_lines.get(rel, ()):
                continue
            occ += 1
            distinct.add(lit)
            chars += len(CJK.findall(lit))
            lines.append(ln)
        if occ:
            out.append(
                {
                    "file": rel,
                    "occ": occ,
                    "distinct": len(distinct),
                    "chars": chars,
                    "lines": sorted(lines),
                }
            )
    out.sort(key=lambda r: -r["occ"])
    return out


def scan_enums(root):
    """枚举中文标签（花括号 + 逐项括号配平，精确口径）。"""
    rows = []
    for p, rel in iter_dart(root, "lib"):
        with open(p, encoding="utf-8") as fh:
            t = fh.read()
        for m in ENUM_DECL.finditer(t):
            depth, i = 1, m.end()
            while i < len(t) and depth:
                if t[i] == "{":
                    depth += 1
                elif t[i] == "}":
                    depth -= 1
                i += 1
            block = t[m.start() : i]
            entries = cjk_entries = 0
            for e in ENUM_ENTRY.finditer(block):
                j, d = e.end(), 1
                while j < len(block) and d:
                    if block[j] == "(":
                        d += 1
                    elif block[j] == ")":
                        d -= 1
                    j += 1
                item = block[e.start() : j]
                entries += 1
                if any(CJK.search(x) for x in LIT.findall(item)):
                    cjk_entries += 1
            if cjk_entries:
                rows.append(
                    {"file": rel, "enum": m.group(1), "cjk": cjk_entries, "entries": entries}
                )
    rows.sort(key=lambda r: (-r["cjk"], r["file"]))
    return rows


def enum_files(root):
    return {r["file"] for r in scan_enums(root)}


def map_entry_files(root):
    """含 '键': '中文值' 映射表项的文件（media_info_page 那类）。"""
    files = set()
    for p, rel in iter_dart(root, "lib"):
        with open(p, encoding="utf-8") as fh:
            t = fh.read()
        for m in MAP_ENTRY.finditer(t):
            lt = line_text(t, m.start())
            if is_comment_line(lt):
                continue
            files.add(rel)
            break
    return files


def table_files(root):
    return enum_files(root) | map_entry_files(root)


def scan_dupes(root):
    """同一字面量出现在 >=2 个文件 → common.* 归并依据。"""
    where = {}
    for p, rel in iter_dart(root, "lib"):
        with open(p, encoding="utf-8") as fh:
            t = fh.read()
        for _ln, lit, _lt, is_log in code_literals(t):
            if is_log:
                continue
            where.setdefault(lit, set()).add(rel)
    return {k: sorted(v) for k, v in where.items() if len(v) > 1}


def scan_residual(root, path_prefix=None, include_android=False, fullwidth=False):
    """白名单外的中文（含注释外全部字面量）。

    返回 (残留列表, 过期白名单项, 日志行列表)。日志行只计数、不计入残留（红线 13）。
    [include_android] 为真时一并扫 `android/` 下的 Kotlin / XML（阶段 8）；
    [fullwidth] 为真时口径扩成「汉字 + 全角标点」（默认只算汉字区）。
    """
    wl = load_whitelist()
    wl_files = {e["path"]: e.get("reason", "") for e in wl.get("files", [])}
    wl_lines = {}
    for e in wl.get("lines", []):
        wl_lines.setdefault(e["path"], {})[int(e["line"])] = e.get("reason", "")

    residual = []
    logs = []
    used_lines = set()

    def scan(rel, literals):
        for ln, lit, lt, is_log in literals:
            if path_prefix and not rel.startswith(path_prefix):
                return
            if ln in wl_lines.get(rel, {}):
                used_lines.add((rel, ln))
                continue
            if is_log:
                logs.append({"file": rel, "line": ln, "text": lit[:120]})
                continue
            residual.append(
                {"file": rel, "line": ln, "text": lit[:120], "source": lt.strip()[:160]}
            )

    for p, rel in iter_dart(root, "lib"):
        if rel in wl_files:
            continue
        if path_prefix and not rel.startswith(path_prefix):
            continue
        with open(p, encoding="utf-8") as fh:
            scan(rel, code_literals(fh.read()))

    if include_android:
        for p, rel in iter_android(root):
            if rel in wl_files:
                continue
            if path_prefix and not rel.startswith(path_prefix):
                continue
            with open(p, encoding="utf-8") as fh:
                t = fh.read()
            literals = kotlin_literals(t) if rel.endswith(".kt") else xml_literals(t)
            scan(rel, literals)

    # 只在本次扫描范围内判断“白名单过期”，否则 --path 子集扫描会把范围外条目全报成过期；
    # 同理：没扫 android 就不判 android 条目，没开 --fullwidth 就不判「只含全角标点」的
    # 条目（它们在当前口径下本来就不会命中，报过期是假阳性）。
    in_scope = (lambda rel: (not path_prefix) or rel.startswith(path_prefix))
    expired = []
    for rel, lines in wl_lines.items():
        if not in_scope(rel):
            continue
        if not include_android and rel.startswith("android/"):
            continue
        for ln, reason in lines.items():
            if (rel, ln) in used_lines:
                continue
            if not fullwidth and not line_has_han(root, rel, ln):
                continue
            expired.append({"file": rel, "line": ln, "reason": reason})
    return residual, expired, logs


def line_has_han(root, rel, line):
    """该行是否含汉字（判断「只在扩口径下才命中」的白名单条目用）。"""
    path = os.path.join(root, rel.replace("/", os.sep))
    if not os.path.exists(path):
        return True
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    if line < 1 or line > len(lines):
        return True
    return bool(HAN.search(lines[line - 1]))


# ---------------------------------------------------------------- 阶段归属

def phase_of(rel, tables):
    """阶段归属：**以目录为准**。

    含表的页面文件（如 pages/player/views/audio_player_panels.dart 里的
    AudioSleepPreset）仍归其页面阶段，任务行上加「含表」标注；表本身按
    04-data-baseline.md 的枚举清单在阶段 1 处理。
    """
    if rel in PHASE0_FILES:
        return 0
    if rel in PHASE7_FILES:
        return 7
    if rel in PHASE2_FILES:
        return 2
    if rel in PHASE6_FILES:
        return 6
    if rel.startswith("lib/pages/settings/"):
        return 3
    if rel.startswith("lib/pages/player/"):
        return 4
    if rel.startswith(("lib/pages/", "lib/widgets/")):
        return 5
    if rel in tables or rel.startswith("lib/theme/"):
        return 1
    if rel.startswith(("lib/services/", "lib/models/", "lib/utils/")):
        return 6
    return 5


def test_coupling(root):
    """测试与中文文案的耦合度：find.text(中文) 次数、expect 行含中文数。"""
    out = {}
    for p, rel in iter_dart(root, "test"):
        with open(p, encoding="utf-8") as fh:
            t = fh.read()
        n_find = len(re.findall(r"find\.(text|widgetWithText|textContaining)\([^)]*[\u4e00-\u9fff]", t))
        n_expect = len(re.findall(r"expect\([^\n]*[\u4e00-\u9fff]", t))
        n_label = len(re.findall(r"\.(label|title|desc|description|displayName)\b", t))
        out[rel] = {"find_text": n_find, "expect_cjk": n_expect, "label_use": n_label}
    return out


# ---------------------------------------------------------------- 报告

def baseline_report(root):
    lib = scan_files(root, "lib")
    test = scan_files(root, "test")
    tp = os.path.join(root, "third_party")
    third = scan_files(root, "third_party") if os.path.isdir(tp) else []

    def agg(rows):
        return {
            "files": len(rows),
            "occ": sum(r["occ"] for r in rows),
            "distinct": len({r["file"] + "|" + str(r["lines"][0]) for r in rows}),
            "chars": sum(r["chars"] for r in rows),
        }

    layers = {"ui": 0, "noctx": 0, "main": 0}
    for r in lib:
        if r["file"] == "lib/main.dart":
            layers["main"] += r["occ"]
        elif r["file"].startswith(("lib/pages/", "lib/widgets/", "lib/theme/")):
            layers["ui"] += r["occ"]
        else:
            layers["noctx"] += r["occ"]

    interp = braces = newline = 0
    for p, _rel in iter_dart(root, "lib"):
        with open(p, encoding="utf-8") as fh:
            t = fh.read()
        for _ln, lit, _lt, is_log in code_literals(t):
            if is_log:
                continue
            body = lit[1:-1] if len(lit) > 2 else lit
            if "$" in body:
                interp += 1
            if ("{" in body or "}" in body) and "$" not in body:
                braces += 1
            if "\\n" in body:
                newline += 1

    return {
        "lib": {"files": len(lib), "occ": sum(r["occ"] for r in lib),
                "chars": sum(r["chars"] for r in lib), "layers": layers},
        "test": {"files": len(test), "occ": sum(r["occ"] for r in test)},
        "third_party": {"files": len(third), "occ": sum(r["occ"] for r in third)},
        "arb_syntax": {"interpolation": interp, "bare_braces": braces, "backslash_n": newline},
    }


def write_residual_md(root, residual, expired, path_prefix, logs=(), note=""):
    scope = path_prefix or "lib/"
    lines = [
        "# 残留中文报告",
        "",
        f"- 扫描范围：`{scope}`（白名单见 `tools/whitelist.json`）",
        f"- 残留数：**{len(residual)}**",
        f"- 白名单过期项：**{len(expired)}**",
        f"- 日志行（不计入残留，红线 13 日志永远中文）：**{len(logs)}**",
    ]
    if note:
        lines.append(f"- 口径：{note}")
    lines.append("")
    if residual:
        lines += ["## 残留明细", "", "| 文件 | 行 | 文案 |", "|---|---|---|"]
        for r in residual[:2000]:
            txt = r["text"].replace("|", "\\|").replace("\n", " ")
            lines.append(f"| `{r['file']}` | {r['line']} | {txt} |")
        if len(residual) > 2000:
            lines.append(f"| … | | 还有 {len(residual) - 2000} 条未列出 |")
    if expired:
        lines += ["", "## 白名单过期项（该行已无中文，应从白名单删除）", ""]
        for e in expired:
            lines.append(f"- `{e['file']}:{e['line']}` — {e['reason']}")
    lines.append("")
    with open(RESIDUAL_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return RESIDUAL_MD


def write_tasks_md(root, files, enums, tables, test_files):
    """生成任务清单；保留已有 [x] 勾选状态。"""
    done = set()
    if os.path.exists(TASKS_MD):
        with open(TASKS_MD, encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r"- \[x\] `([^`]+)`", line.strip())
                if m:
                    done.add(m.group(1))

    groups = {}
    for r in files:
        ph = phase_of(r["file"], tables)
        groups.setdefault(ph, []).append(r)

    enum_by_file = {}
    for e in enums:
        enum_by_file.setdefault(e["file"], []).append(f"{e['enum']}({e['cjk']}/{e['entries']})")

    out = [
        "# 任务清单与进度",
        "",
        "> 本文件由 `tools/i18n_scan.py tasks` 生成；**手工勾选会被保留**，可安全反复生成。",
        "> 一条任务 = 一个文件。做完一个文件就跑一次 `flutter analyze`，阶段收口再跑全量 `flutter test`。",
        "",
        "## 进度总览",
        "",
    ]
    total = len(files) + len(test_files) + len(NEW_FILE_TASKS)
    done_cnt = sum(1 for r in files if r["file"] in done)
    new_done = sum(1 for _p, path, _n in NEW_FILE_TASKS if path in done)
    out += [
        f"- lib 文案文件：**{len(files)}** 个，已完成 **{done_cnt}**",
        f"- 新增文件任务：**{len(NEW_FILE_TASKS)}** 个，已完成 **{new_done}**",
        f"- 测试文件（收口）：**{len(test_files)}** 个",
        f"- 合计任务：**{total}**",
        "",
        "> 勾选方式：把 `- [ ]` 改成 `- [x]`。",
        "",
        "## 新增文件任务（方案新增，不在扫描范围内）",
        "",
        "> 这些文件当前不存在，由本方案新建；阶段归属见行尾。勾选同样会被保留。",
        "",
    ]
    for ph, path, note in NEW_FILE_TASKS:
        mark = "x" if path in done else " "
        out.append(f"- [{mark}] `{path}` — {note}（{PHASE_TITLES[ph]}）")
    out.append("")
    for ph in sorted(groups):
        rows = groups[ph]
        occ = sum(r["occ"] for r in rows)
        out += [f"## {PHASE_TITLES[ph]}（{len(rows)} 文件 / {occ} 处）", ""]
        for r in sorted(rows, key=lambda x: -x["occ"]):
            mark = "x" if r["file"] in done else " "
            extra = ""
            if r["file"] in enum_by_file:
                extra = "  ← 表：" + "、".join(enum_by_file[r["file"]])
            out.append(
                f"- [{mark}] `{r['file']}` — {r['occ']} 处 / {r['distinct']} 条 / {r['chars']} 字{extra}"
            )
        out.append("")

    out += ["## 测试收口清单（阶段 0 建夹具，阶段 8 收口）", "",
            "> `find.text 中文` 一列 > 0 的文件属于**强耦合**：接入 l10n 后若未钉 locale 会直接失败。",
            "> `label 访问` 一列 > 0 的文件在枚举删除中文标签字段后会编译失败，需改为 `labelOf(l10n, x)`。",
            ""]
    coupling = test_coupling(root)
    hard = sum(1 for c in coupling.values() if c["find_text"] > 0)
    lab = sum(1 for c in coupling.values() if c["label_use"] > 0)
    out += [f"- 强耦合（find.text 中文）文件：**{hard}** 个",
            f"- 访问枚举标签（label/title/desc）文件：**{lab}** 个", ""]
    for r in sorted(test_files, key=lambda x: -x["occ"]):
        mark = "x" if r["file"] in done else " "
        c = coupling.get(r["file"], {"find_text": 0, "expect_cjk": 0, "label_use": 0})
        tag = ""
        if c["find_text"]:
            tag += f" · find.text 中文 {c['find_text']} 处"
        if c["label_use"]:
            tag += f" · label 访问 {c['label_use']} 处"
        out.append(f"- [{mark}] `{r['file']}` — {r['occ']} 处中文{tag}")
    out.append("")

    with open(TASKS_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    return TASKS_MD, len(files), done_cnt, len(test_files)


# ---------------------------------------------------------------- CLI

def main():
    ap = argparse.ArgumentParser(description="多语言迁移扫描/门禁/任务清单工具")
    ap.add_argument("command",
                    choices=["baseline", "residual", "enums", "dupes", "tasks", "all"])
    ap.add_argument("--root", default=None, help="工程根目录（默认自动上溯找 pubspec.yaml）")
    ap.add_argument("--path", default=None, help="residual 只扫该前缀，如 lib/pages/settings")
    ap.add_argument("--include-android", action="store_true",
                    help="residual 一并扫 android/（Kotlin / XML 的中文字面量）")
    ap.add_argument("--fullwidth", action="store_true",
                    help="residual 把 CJK 判定扩成「汉字 + 全角标点」（06-遗留 §1.3 的缺口口径）")
    ap.add_argument("--json", action="store_true", help="以 JSON 输出（ASCII 转义）")
    args = ap.parse_args()

    if args.fullwidth:
        global CJK
        CJK = re.compile(r"[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]")

    root = find_root(args.root)
    result = {"root": root}

    if args.command in ("baseline", "all"):
        result["baseline"] = baseline_report(root)
    if args.command in ("enums", "all"):
        result["enums"] = scan_enums(root)
    if args.command in ("dupes", "all"):
        d = scan_dupes(root)
        result["dupes"] = {"count": len(d),
                           "top": sorted(((k, len(v)) for k, v in d.items()),
                                         key=lambda kv: -kv[1])[:15]}
    if args.command == "residual":
        res, expired, logs = scan_residual(
            root, args.path, args.include_android, args.fullwidth
        )
        note = ("汉字区 + 全角标点" if args.fullwidth
                else "汉字区（全角标点不在口径内，需另加 --fullwidth）")
        if args.include_android:
            note += "；含 android/ 下 Kotlin / XML（Kotlin 日志调用已排除）"
        md = write_residual_md(root, res, expired, args.path, logs, note)
        result["residual"] = {"count": len(res), "expired": len(expired),
                              "logs": len(logs), "report": md}
    if args.command in ("tasks", "all"):
        files = scan_files(root, "lib")
        tables = table_files(root)
        enums = scan_enums(root)
        tests = scan_files(root, "test")
        md, n, done, nt = write_tasks_md(root, files, enums, tables, tests)
        result["tasks"] = {"report": md, "files": n, "done": done, "test_files": nt}

    if args.json:
        print(json.dumps(result, ensure_ascii=True, indent=2))
    else:
        # 控制台只用 ASCII，避免 Windows 终端乱码；中文细节写在各报告文件里
        if "baseline" in result:
            b = result["baseline"]
            print("== baseline ==")
            print(f"  lib: files={b['lib']['files']} occ={b['lib']['occ']} chars={b['lib']['chars']} "
                  f"layers={b['lib']['layers']}")
            print(f"  test: files={b['test']['files']} occ={b['test']['occ']}")
            print(f"  third_party: {b['third_party']}")
            print(f"  arb syntax: {b['arb_syntax']}")
        if "enums" in result:
            e = result["enums"]
            print("== enums ==")
            print(f"  enums with CJK labels: {len(e)}  entries: {sum(x['cjk'] for x in e)}")
            for x in e[:10]:
                print(f"    {x['cjk']}/{x['entries']}  {x['enum']}  ({x['file']})")
        if "dupes" in result:
            print("== dupes ==")
            print(f"  literals shared by >=2 files: {result['dupes']['count']}")
        if "residual" in result:
            r = result["residual"]
            print("== residual ==")
            print(f"  residual: {r['count']}  expired whitelist: {r['expired']}  "
                  f"logs(excluded): {r['logs']}")
            print(f"  report: {r['report']}")
        if "tasks" in result:
            t = result["tasks"]
            print("== tasks ==")
            print(f"  files: {t['files']}  done: {t['done']}  test files: {t['test_files']}")
            print(f"  report: {t['report']}")

    if args.command == "residual" and (result["residual"]["count"] or result["residual"]["expired"]):
        sys.exit(1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
