"""Convert 全梁著武功资料.xls to martial_arts_master.json and martial_arts_by_novel.json"""
import json, sys, os
sys.stdout.reconfigure(encoding='utf-8')

import xlrd

wb = xlrd.open_workbook('references/全梁著武功资料.xls')

# --- Master table (sheet 1: 武功总表) ---
ws_master = wb.sheet_by_index(1)
master = []
current_category = ""

for row in range(1, ws_master.nrows):
    cat = str(ws_master.cell_value(row, 0)).strip()
    name = str(ws_master.cell_value(row, 1)).strip()
    novels = str(ws_master.cell_value(row, 2)).strip()

    if cat:
        current_category = cat
    if not name or name == '武功':
        continue

    master.append({
        "category": current_category,
        "name": name,
        "novels": [n.strip() for n in novels.split('、') if n.strip()]
    })

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/martial_arts_master.json', 'w', encoding='utf-8') as f:
    json.dump(master, f, ensure_ascii=False, indent=2)

print(f'Master: {len(master)} martial arts')

# --- Per-novel sheets (sheets 2..35) ---
by_novel = []
for i in range(2, wb.nsheets):
    ws = wb.sheet_by_index(i)
    novel_name = ws.cell_value(0, 0).replace('返回目录', '').strip()
    arts = []
    current_category = ""

    for row in range(1, ws.nrows):
        cat = str(ws.cell_value(row, 0)).strip()
        name = str(ws.cell_value(row, 1)).strip()
        users = str(ws.cell_value(row, 2)).strip()
        school = str(ws.cell_value(row, 3)).strip()

        if cat:
            current_category = cat
        if not name or name in ('武功', ''):
            continue

        arts.append({
            "category": current_category,
            "name": name,
            "users": [u.strip() for u in users.split('、') if u.strip()],
            "school": school if school else None
        })

    if arts:
        by_novel.append({
            "novel": novel_name,
            "martial_arts": arts
        })

with open('references/structured/martial_arts_by_novel.json', 'w', encoding='utf-8') as f:
    json.dump(by_novel, f, ensure_ascii=False, indent=2)

total = sum(len(n['martial_arts']) for n in by_novel)
print(f'By novel: {len(by_novel)} novels, {total} entries')
