import json, re, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

arb = json.load(open(r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb', encoding='utf-8'))
items = [(k, v) for k, v in arb.items() if not k.startswith('@') and isinstance(v, str)]
items.sort()
for k, v in items:
    print(f'{k}\t{v}')
print(f'--- total {len(items)}', file=sys.stderr)
