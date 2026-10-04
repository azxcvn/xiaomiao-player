import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
for p in [r'C:\Users\root\Desktop\moumou\lib\l10n\app_zh.arb',
          r'C:\Users\root\Desktop\moumou\lib\l10n\app_en.arb',
          r'C:\Users\root\Desktop\moumou\lib\l10n\label_maps.dart',
          r'C:\Users\root\Desktop\moumou\lib\pages\player\player_page.dart']:
    b = open(p, 'rb').read()
    print(p.split('\\')[-1], 'crlf', b.count(b'\r\n'), 'lf', b.count(b'\n'), 'tail', b[-3:])
