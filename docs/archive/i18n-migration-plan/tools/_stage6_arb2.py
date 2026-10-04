# -*- coding: utf-8 -*-
"""阶段 6 补充键（第二批）：只新增缺失的键，可反复运行。

- `escape` 语义与 _stage6_arb.py 一致；已存在的键跳过。
- 运行后必须 `flutter gen-l10n`。
"""
import json
import io
import sys

ZH = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
EN = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'

E = [
    ('playerNetworkDanmakuLoadedManual',
     '{anime} · {episode}（{server}）',
     '{anime} · {episode} ({server})',
     '播放器：网络弹幕手动下载成功的回执（服务器名由 UI 侧取 l10n 显示名）',
     {'anime': 'String', 'episode': 'String', 'server': 'String'}),
    ('playerNetworkDanmakuLoadedAuto',
     '{anime} {episode}（{server}）',
     '{anime} {episode} ({server})',
     '播放器：切集自动匹配命中弹幕的回执（服务器名由 UI 侧取 l10n 显示名）',
     {'anime': 'String', 'episode': 'String', 'server': 'String'}),
    ('playerDanmakuLocateNoEpisode',
     '未能从文件名识别集数，可用上方输入框直接跳转',
     'Could not detect an episode number from the file name; use the input above to jump',
     '播放器 · 网络弹幕集数面板：自动定位失败（识别不出集数）', None),
    ('playerDanmakuLocateEpisodeMissing',
     '未找到第 {number} 集，可用上方输入框直接跳转',
     'Episode {number} was not found; use the input above to jump',
     '播放器 · 网络弹幕集数面板：自动定位失败（集列表里没有该集）',
     {'number': 'String'}),
]


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))
    added = []
    for key, zh_v, en_v, desc, ph in E:
        if key in zh:
            continue
        zh[key] = zh_v
        meta = {'description': desc}
        if ph:
            meta['placeholders'] = {k: {'type': v} for k, v in ph.items()}
        zh['@' + key] = meta
        en[key] = en_v
        added.append(key)
    json.dump(zh, open(ZH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(ZH, 'a', encoding='utf-8').write('\n')
    json.dump(en, open(EN, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(EN, 'a', encoding='utf-8').write('\n')
    print('added:', added or '(none)')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
