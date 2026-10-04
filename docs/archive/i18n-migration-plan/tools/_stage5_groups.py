# -*- coding: utf-8 -*-
"""阶段 5：按分组输出残留文案 + 建议调用（含人工 override）。

用法：先 `i18n_scan.py residual`，再跑本脚本。
"""
import json
import io
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = r'C:\Users\root\Desktop\moumou'
REPORT = ROOT + r'\杂项文件\多语言支持方案\05-残留中文报告.md'
ZH = ROOT + r'\lib\l10n\app_zh.arb'

GROUPS = {
    'A': ['subtitle_download_page.dart', 'media_info_page.dart', 'video_card.dart',
          'bili_cover_image.dart', 'folder_card.dart'],
    'B': ['bili_login_page.dart', 'bili_user_page.dart', 'bili_bangumi_index_page.dart',
          'bili_season_page.dart', 'bili_search_page.dart', 'bili_episode_picker_page.dart',
          'bili_play_launcher.dart', 'bili_video_download_page.dart',
          'bili_danmaku_download_page.dart', 'bili_episode_tile.dart'],
    'C': ['home_page.dart', 'tree_folder_page.dart', 'folder_detail_page.dart',
          'open_link_dialog.dart', 'download_manager_page.dart', 'options_sheet.dart',
          'file_selection_ui.dart', 'directory_picker_dialog.dart'],
    'D': ['network_browser_page.dart', 'account_edit_page.dart', 'network_storage_page.dart',
          'update_dialog.dart', 'cast_device_dialog.dart', 'color_editor_row.dart',
          'player_bottom_panel.dart', 'player_panel.dart'],
    'M': ['subtitle_settings_section.dart', 'folder_actions.dart', 'file_operations_ui.dart',
          'bili_index_page.dart'],
}

zh = json.loads(open(ZH, encoding='utf-8').read())


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


def dart_exprs(lit):
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
            out.append(lit[i + 2:k - 1])
            i = k
        elif lit[i] == '$':
            m = re.compile(r'\$(\w+)').match(lit, i)
            if m:
                out.append(m.group(1))
                i = m.end()
            else:
                i += 1
        else:
            i += 1
    return out


def ph_names(key):
    names = re.findall(r'\{(\w+)\}', plural_expand(zh[key]))
    dedup = []
    for n in names:
        if n != 'plural' and n not in dedup:
            dedup.append(n)
    return dedup


exact, canon = {}, {}
for k, v in zh.items():
    if k.startswith('@') or not isinstance(v, str):
        continue
    exact.setdefault(v, []).append(k)
    canon.setdefault(canon_arb(v), []).append(k)

OVERRIDE = {
    # 同值多键 / 结构特殊（人工定夺）
    ('download_manager_page.dart', 239): 'l10n.commonDelete',
    ('download_manager_page.dart', 257): 'l10n.commonDelete',
    ('download_manager_page.dart', 267): 'l10n.commonDelete',
    ('network_storage_page.dart', 50): 'l10n.commonDelete',
    ('network_storage_page.dart', 192): 'l10n.commonDelete',
    ('folder_actions.dart', 610): '_batchSummary 改传 move/delete 变体（见说明）',
    ('file_operations_ui.dart', 65): 'l10n.commonDelete',
    ('file_operations_ui.dart', 295): 'l10n.commonDelete',
    ('file_operations_ui.dart', 326): 'l10n.commonDelete',
    ('file_operations_ui.dart', 284): 'l10n.settingsErrorLogDeleteConfirm(widget.title)',
    ('file_operations_ui.dart', 287):
        'l10n.fileOpDeleteSelectedMixed(widget.itemCount)（L287-288 两条合并成一条）',
    ('file_operations_ui.dart', 288): '（同上，删除本行字面量）',
    ('file_selection_ui.dart', 30): 'l10n.commonDeselectAll / l10n.commonSelectAll（同行两处）',
    ('color_editor_row.dart', 254): 'l10n.commonNone',
    ('open_link_dialog.dart', 112): 'l10n.commonPlay',
    ('subtitle_settings_section.dart', 574): 'l10n.commonRefresh',
    ('bili_index_page.dart', 268):
        '删除该 const 列表，改用 l10n.biliWeekdayMon..biliWeekdaySun（7 个键）',
    ('bili_index_page.dart', 282): '按 i 返回 l10n.biliWeekdayMon..biliWeekdaySun',
    ('subtitle_settings_section.dart', 588):
        "l10n.subtitleKeyType(keyInfo.type.isNotEmpty ? keyInfo.type : l10n.commonUnknown)",
    ('subtitle_settings_section.dart', 679): "l10n.subtitleCustomSourceHelp('{name}')（L679-681 三条合并）",
    ('subtitle_settings_section.dart', 680): '（同上，删除本行字面量）',
    ('subtitle_settings_section.dart', 681): '（同上，删除本行字面量）',
    ('subtitle_settings_section.dart', 745): "l10n.subtitlePlaceholderHelp('{name}')",
    ('folder_actions.dart', 199): '_batchSummary 改成按 move/delete 选整句（见说明）',
    ('folder_actions.dart', 200): 'l10n.folderAction{Moved,Copied,Deleted}ProgressFailed',
    ('folder_actions.dart', 201): 'l10n.folderAction{Moved,Copied,Deleted}ProgressFailedMore',
    ('folder_actions.dart', 234): 'l10n.folderTransferMoving / l10n.folderTransferCopying',
    ('folder_actions.dart', 336): 'l10n.commonMove / l10n.commonCopy（verb 变量改用 bool move）',
    ('folder_actions.dart', 347): 'l10n.folderTransferMoving / l10n.folderTransferCopying',
    ('folder_actions.dart', 303): 'l10n.folderMovedTo(title, ...)（dest 含 targetName 后缀，见说明）',
    ('folder_actions.dart', 304): 'l10n.folderCopiedTo(title, ...)',
    ('folder_actions.dart', 441): 'l10n.folderActionCancelledThenMoved / ...Copied',
    ('folder_actions.dart', 445): 'l10n.folderActionMovedCount / l10n.folderActionCopiedCount',
    ('folder_actions.dart', 605):
        'l10n.folderDeletedOne(items.first.name) / l10n.folderDeletedCount(done)',
    ('bili_episode_tile.dart', 76): '⚠ 不要改：B 站角标匹配键（white-list 由协调者加）',
    ('update_dialog.dart', 62): 'l10n.updateLinkPending(label)',
    ('update_dialog.dart', 71): 'l10n.updateOpenLinkFailed(label)',
    ('bili_login_page.dart', 160):
        '⚠ 不要改：这是截图相册名 albumPath（与阶段 4 一致保持「小喵Player」），白名单由协调者加',
}

rows = []
for line in open(REPORT, encoding='utf-8').read().split('\n'):
    m = re.match(r'^\| `(.+?)` \| (\d+) \| (.*) \|$', line)
    if m:
        rows.append((m.group(1), int(m.group(2)), m.group(3)))
print('报告条目', len(rows))

for g, files in GROUPS.items():
    out = [f'# 阶段 5 · 分组 {g} 残留文案与键位建议', '']
    hit = miss = 0
    for f, ln, lit in rows:
        base = f.split('/')[-1]
        if base not in files:
            continue
        c = canon_dart(lit)
        candidates = exact.get(c) or canon.get(c) or []
        ov = OVERRIDE.get((base, ln))
        if ov:
            form = ov
            hit += 1
        elif len(candidates) == 1:
            key = candidates[0]
            names = ph_names(key)
            exprs = dart_exprs(lit)
            if not names:
                form = f'l10n.{key}'
            elif len(names) == len(exprs):
                form = f'l10n.{key}(' + ', '.join(exprs) + ')'
            else:
                form = (f'l10n.{key}(' + ', '.join('<' + n + '>' for n in names) + ')'
                        '  ← 占位符与字面量插值对不上，按上下文填')
            hit += 1
        else:
            form = ('⚠ 多个候选键：' + ' | '.join(candidates)) if candidates else '⚠ 未匹配'
            miss += 1
        out.append(f'- `{base}` L{ln}：`{lit}` → {form}')
    out += ['', f'（共 {hit + miss} 条，未匹配/多候选 {miss} 条）', '']
    p = ROOT + f'\\杂项文件\\多语言支持方案\\tools\\_stage5_group{g}.md'
    open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    print(f'{g}: {hit + miss} 条，未匹配 {miss} -> {p}')
