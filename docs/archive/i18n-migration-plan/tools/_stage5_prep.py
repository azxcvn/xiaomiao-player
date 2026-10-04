# -*- coding: utf-8 -*-
"""阶段 5 准备：跑全仓 residual → 过滤出阶段 5 文件 → 与现有 ARB 键匹配。

输出：
  tools/_stage5_residual.md  阶段 5 的全部残留行（文件/行/文案/建议键或"未匹配"）
  tools/_stage5_new.txt      未匹配到现有键的**去重文案**（需要新建键）
"""
import json
import io
import re
import sys
import subprocess
import collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = r'C:\Users\root\Desktop\moumou'
TOOLS = ROOT + r'\杂项文件\多语言支持方案\tools'
PY = r'C:\Users\root\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'

# 阶段 5 文件清单（来自 03-任务清单.md 阶段 5 小节）
STAGE5 = """lib/pages/subtitle/views/subtitle_settings_section.dart
lib/pages/media_info/media_info_page.dart
lib/pages/bilibili/bili_login_page.dart
lib/pages/network/account_edit_page.dart
lib/widgets/file_operations_ui.dart
lib/pages/subtitle/subtitle_download_page.dart
lib/pages/home/home_page.dart
lib/widgets/folder_actions.dart
lib/pages/bilibili/bili_index_page.dart
lib/pages/download/download_manager_page.dart
lib/pages/network/network_browser_page.dart
lib/pages/bilibili/bili_season_page.dart
lib/pages/bilibili/bili_video_download_page.dart
lib/pages/bilibili/bili_danmaku_download_page.dart
lib/widgets/update_dialog.dart
lib/pages/bilibili/bili_user_page.dart
lib/pages/network/network_storage_page.dart
lib/widgets/cast_device_dialog.dart
lib/widgets/options_sheet.dart
lib/pages/home/open_link_dialog.dart
lib/pages/home/tree_folder_page.dart
lib/widgets/video_card.dart
lib/pages/bilibili/bili_bangumi_index_page.dart
lib/pages/home/folder_detail_page.dart
lib/widgets/bili_episode_tile.dart
lib/widgets/directory_picker_dialog.dart
lib/pages/bilibili/bili_play_launcher.dart
lib/pages/bilibili/bili_search_page.dart
lib/widgets/file_selection_ui.dart
lib/pages/bilibili/bili_episode_picker_page.dart
lib/widgets/color_editor_row.dart
lib/widgets/player_bottom_panel.dart
lib/widgets/player_panel.dart
lib/pages/subtitle/subtitle_settings_page.dart
lib/widgets/bili_cover_image.dart
lib/widgets/folder_card.dart
lib/widgets/speed_dial_fab.dart""".split('\n')

# 1) 全仓 residual（子进程；报告写到 05-残留中文报告.md）
subprocess.run([PY, TOOLS + r'\i18n_scan.py', 'residual'], cwd=ROOT,
               capture_output=True)

zh = json.loads(open(ROOT + r'\lib\l10n\app_zh.arb', encoding='utf-8').read())


def plural_expand(s):
    out, i = [], 0
    pat = re.compile(r'\{\w+, plural, ')
    while True:
        m = pat.search(s, i)
        if not m:
            out.append(s[i:])
            break
        out.append(s[i:m.start()])
        depth, k = 0, m.start()
        while k < len(s):
            if s[k] == '{':
                depth += 1
            elif s[k] == '}':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        body = s[m.end():k]
        om = re.search(r'other\{', body)
        if om:
            d, j = 0, om.end() - 1
            while j < len(body):
                if body[j] == '{':
                    d += 1
                elif body[j] == '}':
                    d -= 1
                    if d == 0:
                        break
                j += 1
            out.append(body[om.end():j])
        i = k + 1
    return ''.join(out)


def canon_arb(v):
    return re.sub(r'\{\w+\}', '{}', plural_expand(v))


def canon_dart(lit):
    lit = lit.strip()
    if lit.startswith("'"):
        lit = lit[1:]
    if lit.endswith("'"):
        lit = lit[:-1]
    lit = lit.replace('\\n', '\n').replace("\\'", "'")
    out, i = [], 0
    while i < len(lit):
        if lit.startswith('${', i):
            depth, k = 1, i + 2
            while k < len(lit) and depth:
                if lit[k] == '{':
                    depth += 1
                elif lit[k] == '}':
                    depth -= 1
                k += 1
            out.append('{}')
            i = k
        elif lit[i] == '$':
            m = re.compile(r'\$(\w+)').match(lit, i)
            if m:
                out.append('{}')
                i = m.end()
            else:
                out.append(lit[i])
                i += 1
        else:
            out.append(lit[i])
            i += 1
    return ''.join(out)


exact, canon = {}, {}
for k, v in zh.items():
    if k.startswith('@') or not isinstance(v, str):
        continue
    exact.setdefault(v, []).append(k)
    canon.setdefault(canon_arb(v), []).append(k)

rows = []
rep = open(TOOLS + r'\..\05-残留中文报告.md', encoding='utf-8').read()
for line in rep.split('\n'):
    m = re.match(r'^\| `(.+?)` \| (\d+) \| (.*) \|$', line)
    if m:
        rows.append((m.group(1), int(m.group(2)), m.group(3)))

stage5 = [r for r in rows if r[0] in STAGE5]
print('阶段 5 残留行', len(stage5), '（任务清单口径 493）')
missing_files = [f for f in STAGE5 if f not in {r[0] for r in stage5}]
print('清单里但报告中没有残留的文件：', missing_files)

out = ['# 阶段 5 残留明细（自动生成）', '']
unmatched = collections.OrderedDict()
matched = 0
for f, ln, lit in stage5:
    c = canon_dart(lit)
    cands = exact.get(c) or canon.get(c) or []
    if len(cands) == 1:
        form = f'`{cands[0]}`'
        matched += 1
    elif len(cands) > 1:
        form = '⚠ 多候选：' + ' | '.join(cands)
        unmatched.setdefault(lit, []).append(f'{f}:{ln}')
    else:
        form = '未匹配'
        unmatched.setdefault(lit, []).append(f'{f}:{ln}')
    out.append(f'- `{f}` L{ln}：`{lit}` → {form}')
open(TOOLS + r'\_stage5_residual.md', 'w', encoding='utf-8', newline='\n').write(
    '\n'.join(out) + '\n')
print('唯一匹配现有键：', matched, '；未匹配/多候选的去重文案：', len(unmatched))

lines = ['# 阶段 5 需要新建键（或人工定夺）的去重文案', '']
for lit, where in unmatched.items():
    lines.append(f'- `{lit}`   ← {", ".join(where[:4])}' + (' …' if len(where) > 4 else ''))
open(TOOLS + r'\_stage5_new.txt', 'w', encoding='utf-8', newline='\n').write(
    '\n'.join(lines) + '\n')
print('→', TOOLS + r'\_stage5_new.txt')
