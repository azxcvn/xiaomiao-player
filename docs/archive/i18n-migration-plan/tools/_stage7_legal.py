# -*- coding: utf-8 -*-
"""阶段 7：把 `lib/services/privacy_policy_content.dart` 的 4 段中文正文
**逐字**迁入 `lib/l10n/legal_zh.dart`（保留 `'''…'''` 多行排版）。

可反复运行（只写 legal_zh.dart 一个文件）。运行后请核对打印出的字数。
"""
import io
import os
import re
import sys

ROOT = r'C:\Users\root\Desktop\moumou'
SRC = os.path.join(ROOT, 'lib', 'services', 'privacy_policy_content.dart')
DST = os.path.join(ROOT, 'lib', 'l10n', 'legal_zh.dart')

HEADER = '''/// 《用户隐私政策》/《用户服务协议与隐私政策》的**中文正文**（源文）。
///
/// ⚠️ **改中文条款必须同步改 `lib/l10n/legal_en.dart`**——两个文件是一对，
/// 缺一个会让该语言下正文为空（`test/legal_texts_test.dart` 兜底断言非空）。
///
/// 为什么按语言拆 Dart 文件、不塞 ARB：正文是 3400 字的长文，进 ARB 会让键表
/// 无法维护（`02-实施方案.md` §1.11 已拍板）。正文按原文的多行排版原样保留，
/// 便于与旧版本逐行 diff。
///
/// 按语言的取用入口在 `lib/l10n/legal.dart`（`legalTextsFor`）。
library;

/// 中文长文正文（四个字段与英文版 `legalEn` 一一对应）
const ({
  String policyTitle,
  String policyBody,
  String agreementTitle,
  String agreementBody,
}) legalZh = (
  policyTitle: %s,
  policyBody: %s,
  agreementTitle: %s,
  agreementBody: %s,
);
'''


def extract_plain(src, name):
    m = re.search(r"const String " + name + r" = '(.*?)';", src, re.S)
    if not m:
        raise SystemExit('FAIL: 找不到 ' + name)
    return "'" + m.group(1) + "'"


def extract_block(src, name):
    m = re.search(r"const String " + name + r" = '''(.*?)''';", src, re.S)
    if not m:
        raise SystemExit('FAIL: 找不到 ' + name)
    return "'''" + m.group(1) + "'''"


def main():
    src = open(SRC, encoding='utf-8').read()
    policy_title = extract_plain(src, 'kPrivacyPolicyTitle')
    agreement_title = extract_plain(src, 'kUserAgreementTitle')
    policy_body = extract_block(src, 'kPrivacyPolicyBody')
    agreement_body = extract_block(src, 'kUserAgreementBody')
    out = HEADER % (policy_title, policy_body, agreement_title, agreement_body)
    open(DST, 'w', encoding='utf-8', newline='\n').write(out)
    cjk = re.compile(r'[\u4e00-\u9fff]')
    print('写入', DST)
    print('  policyTitle  ', len(cjk.findall(policy_title)), '字')
    print('  agreementTitle', len(cjk.findall(agreement_title)), '字')
    print('  policyBody   ', len(cjk.findall(policy_body)), '字')
    print('  agreementBody', len(cjk.findall(agreement_body)), '字')
    print('  合计', len(cjk.findall(policy_title + agreement_title + policy_body + agreement_body)), '字')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    main()
