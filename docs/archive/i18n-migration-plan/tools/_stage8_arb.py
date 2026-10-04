# -*- coding: utf-8 -*-
"""阶段 8 新增 ARB 键：全角标点缺口（06-遗留 §1.3）收口用。只新增缺失的键。

对应：`i18n_scan.py residual --fullwidth` 之前报出的 19 处纯全角标点字面量。
运行后必须 `flutter gen-l10n`。
"""
import json
import io
import sys

ZH = r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb'
EN = r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb'

E = [
    ('commonListSeparator', '、', ', ',
     '通用：并列项之间的分隔符（弹幕屏蔽词 / 诊断项 / 字幕来源语言格式编码的摘要）', None),
    ('commonLabelWithColon', '{label}：', '{label}: ',
     '通用：给一段内容加「标签：」前缀（字幕 ASS 限制说明）', {'label': 'String'}),
    ('mediaInfoStreamsGroupTitle', '【{title}】', '[{title}]',
     '媒体信息：复制出的文本里给流分组加方括号标题', {'title': 'String'}),
    ('settingsFontPreviewSample', '0123456789，。！？；：“”（）【】…·',
     '0123456789 ,.!?;:"()[]...·',
     '字体设置页：字体效果预览样例（中文侧顺带展示全角标点字形覆盖）', None),
    ('folderActionDestWithTarget', '{dest}：{target}', '{dest}: {target}',
     '文件操作：目标位置与最终条目名（「已移动到 X」的 X）',
     {'dest': 'String', 'target': 'String'}),
    ('fileOpItemIssue', '「{name}」{reason}', '"{name}": {reason}',
     '文件操作：条目名 + 校验失败原因（批量移动/复制预校验）',
     {'name': 'String', 'reason': 'String'}),
    ('fileOpItemFailed', '{name}：{reason}', '{name}: {reason}',
     '文件操作：条目名 + 失败原因（批量移动/复制/删除的失败汇总）',
     {'name': 'String', 'reason': 'String'}),
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
