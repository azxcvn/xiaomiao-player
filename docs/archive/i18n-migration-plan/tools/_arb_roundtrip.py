import json, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def roundtrip(p):
    orig = open(p, encoding='utf-8').read()
    data = json.loads(orig)
    out = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    print(p)
    print('  identical:', orig == out, 'len', len(orig), len(out))
    if orig != out:
        import difflib
        d = list(difflib.unified_diff(orig.splitlines(), out.splitlines(), lineterm='', n=1))
        print('\n'.join(d[:40]))
    metas = [k for k in data if k.startswith('@')]
    print('  meta keys:', len(metas))

roundtrip(r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb')
roundtrip(r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb')
