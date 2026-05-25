"""Convert 全梁著人物资料.xls to characters.json"""
import json, sys, os
sys.stdout.reconfigure(encoding='utf-8')

import xlrd

wb = xlrd.open_workbook('references/全梁著人物资料.xls')
output = []

for i in range(1, wb.nsheets):  # skip sheet 0 (目录)
    ws = wb.sheet_by_index(i)
    novel_name = ws.cell_value(0, 0).replace('返回目录', '').strip()
    characters = []
    current_importance = None

    for row in range(1, ws.nrows):
        name = str(ws.cell_value(row, 0)).strip()
        desc = str(ws.cell_value(row, 1)).strip()

        if '主要人物' in name or '主要人物' in desc:
            current_importance = 'main'
            continue
        if '其他人物' in name or '其他人物' in desc:
            current_importance = 'other'
            continue
        if not name or name in ('人名', ''):
            continue

        characters.append({
            "name": name,
            "description": desc,
            "importance": current_importance or "main"
        })

    if characters:
        output.append({
            "novel": novel_name,
            "characters": characters
        })

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/characters.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

total = sum(len(n['characters']) for n in output)
print(f'Done: {len(output)} novels, {total} characters')
