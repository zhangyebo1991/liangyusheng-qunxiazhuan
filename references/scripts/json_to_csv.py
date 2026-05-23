"""
将 references/structured/ 下的 JSON 文件转换为 CSV。
CSV 更紧凑，减少 token 消耗，方便 AI 阅读和策划查阅。
"""
import json
import csv
import os

STRUCTURED_DIR = os.path.join(os.path.dirname(__file__), '..', 'structured')


def write_csv(filename, headers, rows):
    path = os.path.join(STRUCTURED_DIR, filename)
    with open(path, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)
    print(f'  {filename}: {len(rows)} rows')


def convert_characters():
    with open(os.path.join(STRUCTURED_DIR, 'characters.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for group in data:
        novel = group['novel']
        for c in group['characters']:
            rows.append([novel, c['name'], c['description'], c['importance']])
    write_csv('characters.csv', ['novel', 'name', 'description', 'importance'], rows)


def convert_martial_arts_master():
    with open(os.path.join(STRUCTURED_DIR, 'martial_arts_master.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for item in data:
        novels = '; '.join(item.get('novels', []))
        rows.append([item['category'], item['name'], novels])
    write_csv('martial_arts_master.csv', ['category', 'name', 'novels'], rows)


def convert_martial_arts_by_novel():
    with open(os.path.join(STRUCTURED_DIR, 'martial_arts_by_novel.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for group in data:
        novel = group['novel']
        for ma in group['martial_arts']:
            users = '; '.join(ma.get('users', []))
            rows.append([novel, ma['category'], ma['name'], users, ma.get('school', '') or ''])
    write_csv('martial_arts_by_novel.csv', ['novel', 'category', 'name', 'users', 'school'], rows)


def convert_weapons():
    with open(os.path.join(STRUCTURED_DIR, 'weapons_hidden.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for group in data:
        novel = group['novel']
        for item in group['items']:
            users = '; '.join(item.get('users', []))
            rows.append([
                novel, item['name'], item['type'],
                item.get('appearance', ''), users,
                item.get('combat_description', ''), item.get('comment', '')
            ])
    write_csv('weapons_hidden.csv',
              ['novel', 'name', 'type', 'appearance', 'users', 'combat_description', 'comment'], rows)


def convert_codex():
    with open(os.path.join(STRUCTURED_DIR, 'wuxia_codex.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for section in data:
        for sub in section.get('subsections', []):
            for entry in sub.get('entries', []):
                rows.append([section['title'], sub['title'], entry['name'], entry['description']])
    write_csv('wuxia_codex.csv', ['section', 'subsection', 'name', 'description'], rows)


def convert_relationships():
    with open(os.path.join(STRUCTURED_DIR, 'relationships.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for r in data:
        rows.append([r['from'], r['to'], r['relation'], r.get('novel', ''), r.get('section', '')])
    write_csv('relationships.csv', ['from', 'to', 'relation', 'novel', 'section'], rows)


def convert_battles():
    with open(os.path.join(STRUCTURED_DIR, 'classic_battles.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for b in data:
        rows.append([b['rank'], b['title'], b.get('novel', ''), b['description']])
    write_csv('classic_battles.csv', ['rank', 'title', 'novel', 'description'], rows)


def convert_novels():
    with open(os.path.join(STRUCTURED_DIR, 'novels_overview.json'), encoding='utf-8') as f:
        data = json.load(f)
    rows = []
    for n in data:
        rows.append([n['title'], n['summary']])
    write_csv('novels_overview.csv', ['title', 'summary'], rows)


if __name__ == '__main__':
    print('Converting JSON to CSV...')
    convert_characters()
    convert_martial_arts_master()
    convert_martial_arts_by_novel()
    convert_weapons()
    convert_codex()
    convert_relationships()
    convert_battles()
    convert_novels()
    print('Done.')
