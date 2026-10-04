# -*- coding: utf-8 -*-
"""生成阶段 4 键位参考：新增键表 + 可复用旧键表。"""
import json
import io
import sys
import subprocess

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
ROOT = r'C:\Users\root\Desktop\moumou'
ZH = ROOT + r'\lib\l10n\app_zh.arb'
EN = ROOT + r'\lib\l10n\app_en.arb'
OUT = ROOT + r'\杂项文件\多语言支持方案\tools\_stage4_keys.md'

zh = json.loads(open(ZH, encoding='utf-8').read())
en = json.loads(open(EN, encoding='utf-8').read())
old = json.loads(subprocess.run(
    ['git', 'show', 'HEAD:lib/l10n/app_zh.arb'], cwd=ROOT,
    capture_output=True).stdout.decode('utf-8'))
oldkeys = set(old)

new = [k for k in zh if not k.startswith('@') and k not in oldkeys]
reuse = [k for k in zh if not k.startswith('@') and k in oldkeys]

# 本阶段实际要复用的旧键（人工挑）
REUSE = [
    'appTitle', 'commonAdd', 'commonCancel', 'commonClear', 'commonConfirm',
    'commonDanmaku', 'commonDelete', 'commonExternalTag', 'commonOff',
    'commonReset', 'commonResolution', 'commonSeconds', 'commonSecondsValue',
    'commonVideo', 'chapterSkipIntro', 'chapterSkipOutro', 'decodeModeHwCopy',
    'loopModeLoopAll', 'playerActionAudio', 'playerActionChapter',
    'playerActionDecode', 'playerActionDiagnostics', 'playerActionEqualizer',
    'playerActionIntroOutro', 'playerActionListen', 'playerActionLoop',
    'playerActionPip', 'playerActionSubtitle', 'playerPreset',
    'settingsFontWeightBlack', 'settingsFontWeightBold',
    'settingsFontWeightExtraBold', 'settingsFontWeightExtraLight',
    'settingsFontWeightLight', 'settingsFontWeightMedium',
    'settingsFontWeightNone', 'settingsFontWeightRegular',
    'settingsFontWeightSemiBold', 'settingsFontWeightThin',
    'settingsPlayerVolumeBoost',
]

lines = ['# 阶段 4 键位参考（自动生成，勿手改）', '',
         f'新增键 {len(new)} 个；本阶段要复用的旧键 {len(REUSE)} 个。', '',
         '## 新增键（zh / en）', '', '| 键 | 中文 | 英文 |', '|---|---|---|']
for k in new:
    lines.append(f'| `{k}` | {zh[k]} | {en[k]} |')
lines += ['', '## 复用的旧键', '', '| 键 | 中文 |', '|---|---|']
for k in REUSE:
    lines.append(f'| `{k}` | {zh[k]} |')
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print('new', len(new), 'reuse', len(REUSE), '->', OUT)
