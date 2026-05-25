"""Convert 梁羽生小说经典的十场大战.txt to classic_battles.json"""
import json, sys, re, os
sys.stdout.reconfigure(encoding='utf-8')

with open('references/梁羽生小说经典的十场大战.txt', 'r', encoding='utf-8') as f:
    text = f.read()

battles = []
# Pattern: "经典之十：title" or "经典之九：title" or "经典之八，title"
# Split by these headers
parts = re.split(r'(经典之[一二三四五六七八九十]+[：:，,])', text)

for i in range(1, len(parts), 2):
    header = parts[i]  # "经典之十："
    body = parts[i + 1] if i + 1 < len(parts) else ""

    # Extract rank number
    rank_map = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
                '六': 6, '七': 7, '八': 8, '九': 9, '十': 10}
    rank_char = re.search(r'经典之([一二三四五六七八九十]+)', header)
    rank = rank_map.get(rank_char.group(1), 0) if rank_char else 0

    # First line of body is the title
    lines = body.strip().split('\n')
    title = lines[0].strip().rstrip('？')
    description = '\n'.join(lines[1:]).strip()

    # Extract novel name from title or description
    novel_match = re.search(r'《(.+?)》', title + description[:200])
    novel = novel_match.group(1) if novel_match else ""

    battles.append({
        "rank": rank,
        "title": title,
        "novel": novel,
        "description": description[:800]
    })

# Sort by rank
battles.sort(key=lambda x: x['rank'])

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/classic_battles.json', 'w', encoding='utf-8') as f:
    json.dump(battles, f, ensure_ascii=False, indent=2)

print(f'Done: {len(battles)} battles')
for b in battles:
    print(f"  #{b['rank']}: {b['title']}")
