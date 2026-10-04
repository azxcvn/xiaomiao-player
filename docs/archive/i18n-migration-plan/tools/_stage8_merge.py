# -*- coding: utf-8 -*-
"""阶段 8 收口：ARB 同中文重复键归并（06-遗留 §1.1）+ 键名与语义不符的改名（§1.2）。

- RENAME：键改名（值 + @元数据一起搬），调用点同步改；
- MERGE：多个键合成一个（调用点改到存活键，旧键从两个 ARB 删除）；
- NEW：归并需要的新键（commonColorXxx / commonDefault）先建出来；
- 「播放」组**故意不并**：commonPlay('Play'，动作) 与 settingsGroupPlayback('Playback'，
  设置分组标题) 语义不同，英文也不同。

用法：python tools/_stage8_merge.py
跑完必须 `flutter gen-l10n`。
"""
import io
import json
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
ZH = os.path.join(ROOT, 'lib', 'l10n', 'app_zh.arb')
EN = os.path.join(ROOT, 'lib', 'l10n', 'app_en.arb')

# 归并需要的新键：(key, zh, en, description)
NEW_KEYS = [
    ('commonColorCyan', '青色', 'Cyan', '通用颜色名：青色（主题色 / 字幕颜色预设共用）'),
    ('commonColorGreen', '绿色', 'Green', '通用颜色名：绿色（主题色 / 字幕颜色预设共用）'),
    ('commonColorYellow', '黄色', 'Yellow', '通用颜色名：黄色（主题色 / 字幕颜色预设共用）'),
    ('commonDefault', '默认', 'Default', '通用：默认（解码档位 / 字体字重等「未自定义」状态）'),
]

# 改名：old -> new（值一起搬）
RENAMES = {
    'settingsErrorLogDeleteConfirm': 'commonDeleteConfirm',
    'danmakuServerDeleteConfirm': 'commonDeleteConfirmIrreversible',
    'settingsDecoderSampleRates': 'mediaInfoSampleRates',
    'settingsGroupLanguage': 'commonLanguage',
    'settingsDownloadManager': 'downloadManagerTitle',
    'settingsVideoDownload': 'biliVideoDownloadTitle',
    'settingsDanmakuDownload': 'biliDanmakuDownloadTitle',
    'settingsSubtitleDownload': 'biliSubtitleDownloadTitle',
    'playerQuality': 'commonQuality',
}

# 归并：old -> 存活键
MERGES = {
    'playerOrientationAuto': 'commonAuto',
    'playerVideoFitContain': 'commonAuto',
    'subtitlePresetCyan': 'commonColorCyan',
    'settingsThemeColorCyan': 'commonColorCyan',
    'subtitlePresetGreen': 'commonColorGreen',
    'settingsThemeColorGreen': 'commonColorGreen',
    'subtitlePresetYellow': 'commonColorYellow',
    'settingsThemeColorYellow': 'commonColorYellow',
    'decodePresetStandard': 'commonDefault',
    'settingsFontWeightNone': 'commonDefault',
    'subtitleBorderNone': 'commonNone',
    'settingsAppearanceTitle': 'settingsGroupAppearance',
    'settingsErrorLogDelete': 'commonDelete',
    'settingsErrorLogRefresh': 'commonRefresh',
    'settingsAppearanceGroupFont': 'settingsFontGroupFont',
    'settingsLicenseTitle': 'settingsAboutLicenses',
    'settingsCacheTitle': 'settingsAboutCacheManagement',
    'settingsAppearanceCustomColor': 'commonCustom',
    'settingsWallpaperBlur': 'commonBlur',
    'settingsWallpaperOffsetY': 'playerVerticalPosition',
    'playerDelaySeconds': 'commonSecondsValue',
}


def dart_files():
    out = []
    for sub in ('lib', 'test'):
        for base, _dirs, files in os.walk(os.path.join(ROOT, sub)):
            for fn in files:
                if fn.endswith('.dart') and not fn.startswith('app_localizations'):
                    out.append(os.path.join(base, fn))
    return out


def main():
    zh = json.load(open(ZH, encoding='utf-8'))
    en = json.load(open(EN, encoding='utf-8'))

    added = []
    for key, zh_v, en_v, desc in NEW_KEYS:
        if key in zh:
            continue
        zh[key] = zh_v
        zh['@' + key] = {'description': desc}
        en[key] = en_v
        added.append(key)

    renamed = []
    for old, new in RENAMES.items():
        if old not in zh:
            print(f'  跳过改名（旧键不存在）：{old}')
            continue
        if new in zh:
            raise SystemExit(f'FAIL: 改名目标已存在 {new}')
        zh[new] = zh[old]
        en[new] = en[old]
        if '@' + old in zh:
            zh['@' + new] = zh.pop('@' + old)
        del zh[old]
        del en[old]
        renamed.append((old, new))

    merged = []
    for old, new in MERGES.items():
        if old not in zh:
            print(f'  跳过归并（旧键不存在）：{old}')
            continue
        if new not in zh:
            raise SystemExit(f'FAIL: 归并目标不存在 {new}')
        del zh[old]
        del en[old]
        zh.pop('@' + old, None)
        merged.append((old, new))

    # 调用点替换（lib/ 与 test/）
    pairs = dict(renamed)
    pairs.update(merged)
    touched = 0
    replaced = 0
    for path in dart_files():
        src = open(path, encoding='utf-8').read()
        out = src
        for old, new in pairs.items():
            out, n = re.subn(r'\bl10n\.' + re.escape(old) + r'\b', 'l10n.' + new, out)
            replaced += n
        if out != src:
            open(path, 'w', encoding='utf-8', newline='\n').write(out)
            touched += 1

    json.dump(zh, open(ZH, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(ZH, 'a', encoding='utf-8').write('\n')
    json.dump(en, open(EN, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    open(EN, 'a', encoding='utf-8').write('\n')

    print(f'新增键 {len(added)}：{added}')
    print(f'改名 {len(renamed)}：{renamed}')
    print(f'归并 {len(merged)} 组（删除 {len(merged)} 个旧键）')
    print(f'改写文件 {touched} 个，替换调用点 {replaced} 处')

    # 残留检查：旧键名是否还在代码里（除 ARB 生成物）
    left = []
    for path in dart_files():
        src = open(path, encoding='utf-8').read()
        for old in pairs:
            if re.search(r'\b' + re.escape(old) + r'\b', src):
                left.append((os.path.relpath(path, ROOT), old))
    if left:
        print('仍有旧键名残留（需手工确认）：')
        for p, k in left:
            print(f'   {p}  {k}')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
