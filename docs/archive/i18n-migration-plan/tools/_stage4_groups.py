# -*- coding: utf-8 -*-
"""把 05 报告按文件分组，并为每条残留文案自动匹配 ARB 键。

用法：先 `i18n_scan.py residual --path lib/pages/player`，再跑本脚本。
输出：tools/_stage4_groupX.md（X = A/B/C/D/M），每行 `行号 | 文案 | 建议调用`。
"""
import json
import io
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = r'C:\Users\root\Desktop\moumou'
REPORT = ROOT + r'\docs\archive\i18n-migration-plan\05-residual-chinese-report.md'
ZH = ROOT + r'\lib\l10n\app_zh.arb'

GROUPS = {
    'A': ['audio_panel.dart', 'audio_player_panels.dart', 'audio_player_page.dart',
          'equalizer_panel.dart', 'player_gesture_indicator.dart',
          'subtitle_file_picker.dart'],
    'B': ['player_danmaku_panel.dart', 'player_danmaku_buttons.dart',
          'player_danmaku_episodes_panel.dart', 'player_danmaku_network_panel.dart'],
    'C': ['player_bili_playlist_panel.dart', 'player_bottom_bar.dart',
          'player_center_cluster.dart', 'player_chapter_panel.dart',
          'player_chapter_skip_panel.dart', 'player_decode_panel.dart',
          'player_intro_outro_panel.dart'],
    'D': ['player_playlist_panel.dart', 'player_play_pause_button.dart',
          'player_quality_panel.dart', 'player_resume_indicator.dart',
          'player_right_actions.dart', 'player_speed_indicator.dart',
          'player_speed_panel.dart', 'player_super_resolution_panel.dart',
          'player_top_bar.dart', 'player_zoom_restore_chip.dart',
          'portrait_edit_panel.dart', 'portrait_player_bottom_bar.dart',
          'portrait_player_top_bar.dart'],
    'M': ['player_page.dart', 'player_portrait_page.dart', 'subtitle_panel.dart',
          'player_danmaku_settings_panel.dart', 'player_diagnostics_panel.dart'],
}

zh = json.loads(open(ZH, encoding='utf-8').read())


def plural_expand(s):
    """{n, plural, other{X}} -> X（每条消息只处理一处 plural 即可）"""
    out = []
    i = 0
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
    v = plural_expand(v)
    return re.sub(r'\{\w+\}', '{}', v)


def canon_dart(lit):
    lit = lit.strip()
    if lit.startswith("'"):
        lit = lit[1:]
    if lit.endswith("'"):
        lit = lit[:-1]
    lit = lit.replace('\\n', '\n').replace("\\'", "'")
    # ${...} 平衡替换
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
    """按出现顺序取出字面量里的插值表达式（$x 与 ${...}）。"""
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


# 值 -> 键（先精确，再规范化；多候选全部保留）
exact, canon = {}, {}
for k, v in zh.items():
    if k.startswith('@') or not isinstance(v, str):
        continue
    exact.setdefault(v, []).append(k)
    canon.setdefault(canon_arb(v), []).append(k)

ROWS_OVERRIDE = {
    ('player_page.dart', 2307):
        'l10n.playerMaxActions(PlayerControlsSettings.maxTopActions)',
    ('portrait_edit_panel.dart', 121):
        'l10n.playerMaxActions(PlayerControlsSettings.maxTopActions)',
    ('player_diagnostics_panel.dart', 209):
        '（并入 playerDiagnosticsFailedValueMore，见下方说明）',
    ('player_diagnostics_panel.dart', 210):
        'l10n.playerDiagnosticsFailedValue(shown) / '
        'l10n.playerDiagnosticsFailedValueMore(shown, failedKeys.length)',
    ('subtitle_panel.dart', 717):
        "l10n.playerDelaySeconds('$sign$text')",
    ('audio_player_panels.dart', 40): 'l10n.audioSleepMinutes(15)',
    ('audio_player_panels.dart', 41): 'l10n.audioSleepMinutes(30)',
    ('audio_player_panels.dart', 42): 'l10n.audioSleepMinutes(60)',
    ('player_chapter_skip_panel.dart', 87):
        'l10n.playerChapterSkipKeywordOwnerHint（L87-89 三段相邻字面量合并为一条）',
    ('player_chapter_skip_panel.dart', 88): '（同上，删除本行字面量）',
    ('player_chapter_skip_panel.dart', 89): '（同上，删除本行字面量）',
    # 同值多键：按上下文选定
    ('player_page.dart', 2269): 'l10n.commonDelete',
    ('portrait_edit_panel.dart', 91): 'l10n.commonDelete',
    ('player_play_pause_button.dart', 50): 'l10n.commonPlay / l10n.commonPause（两个字面量同行）',
    ('player_danmaku_settings_panel.dart', 102): 'l10n.commonSecondsValue(v.round())',
    ('player_danmaku_settings_panel.dart', 112): 'l10n.commonNone',
    ('player_diagnostics_panel.dart', 137): 'l10n.commonPlay',
    ('subtitle_panel.dart', 975): 'l10n.commonBlur',
    ('subtitle_panel.dart', 1270): 'l10n.playerVerticalPosition',
    ('subtitle_panel.dart', 1493): 'l10n.commonRefresh',
    ('audio_player_panels.dart', 43): 'l10n.commonCustom',
}

rows = []
for line in open(REPORT, encoding='utf-8').read().split('\n'):
    m = re.match(r'^\| `(.+?)` \| (\d+) \| (.*) \|$', line)
    if m:
        rows.append((m.group(1), int(m.group(2)), m.group(3)))
print('报告条目', len(rows))

for g, files in GROUPS.items():
    out = [f'# 阶段 4 · 分组 {g} 残留文案与键位建议', '']
    hit = miss = 0
    for f, ln, lit in rows:
        base = f.replace('lib/pages/player/', '').replace('views/', '')
        if base not in files:
            continue
        c = canon_dart(lit)
        candidates = exact.get(c) or canon.get(c) or []
        ov = ROWS_OVERRIDE.get((base, ln))
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
                form = (f'l10n.{key}({", ".join("<" + n + ">" for n in names)})'
                        '  ← 占位符与字面量插值对不上，按上下文填')
            hit += 1
        else:
            form = ('⚠ 多个候选键：' + ' | '.join(candidates)) if candidates else '⚠ 未匹配'
            miss += 1
        out.append(f'- `{base}` L{ln}：`{lit}` → {form}')
    out += ['', f'（共 {hit + miss} 条，未匹配 {miss} 条）', '']
    p = ROOT + f'\\杂项文件\\多语言支持方案\\tools\\_stage4_group{g}.md'
    open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    print(f'{g}: {hit + miss} 条，未匹配 {miss} -> {p}')
