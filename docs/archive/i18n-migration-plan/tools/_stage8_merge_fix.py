# -*- coding: utf-8 -*-
"""阶段 8 归并修复：`playerDelaySeconds` 不能并进 `commonSecondsValue`。

原因：两者中文同是「{value} 秒」，但**占位符类型不同**——
`commonSecondsValue` 是 `int`（通用「N 秒」），`playerDelaySeconds` 是 `String`
（字幕延迟读数带正负号/小数，如 `+1.5`）。归并会让调用点类型不匹配。

本脚本把 `playerDelaySeconds` 原样加回（含原描述与类型），并把调用点改回去。
可反复运行。跑完必须 `flutter gen-l10n`。
"""
import io
import json
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
ZH = os.path.join(ROOT, 'lib', 'l10n', 'app_zh.arb')
EN = os.path.join(ROOT, 'lib', 'l10n', 'app_en.arb')
PANEL = os.path.join(ROOT, 'lib', 'pages', 'player', 'views', 'subtitle_panel.dart')

ZH_V = '{value} 秒'
EN_V = '{value} s'
DESC = '播放器字幕延迟面板：带正负号的延迟读数'
PH = {'value': {'type': 'String'}}


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))
    if 'playerDelaySeconds' not in zh:
        zh['playerDelaySeconds'] = ZH_V
        zh['@playerDelaySeconds'] = {'description': DESC, 'placeholders': PH}
        en['playerDelaySeconds'] = EN_V
        json.dump(zh, open(ZH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        open(ZH, 'a', encoding='utf-8').write('\n')
        json.dump(en, open(EN, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        open(EN, 'a', encoding='utf-8').write('\n')
        print('已加回 playerDelaySeconds')
    else:
        print('playerDelaySeconds 已存在，跳过')

    src = open(PANEL, encoding='utf-8').read()
    out, n = re.subn(r'l10n\.commonSecondsValue\(', 'l10n.playerDelaySeconds(', src)
    if n:
        open(PANEL, 'w', encoding='utf-8', newline='\n').write(out)
    print(f'调用点改回 {n} 处')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
