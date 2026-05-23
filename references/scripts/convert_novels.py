"""Convert 梁羽生小说内容简介.txt to novels_overview.json"""
import json, sys, re, os
sys.stdout.reconfigure(encoding='utf-8')

with open('references/梁羽生小说内容简介.txt', 'rb') as f:
    raw = f.read()

text = raw.decode('gbk', errors='replace')

# Split by the yushengbbs footer marker
sections = re.split(r'（梁羽生相关尽在.*?）', text)

novels = []
# Known novel titles to detect
novel_endings = ['传', '录', '剑', '缘', '记', '旗', '刀', '弹', '箭', '龙', '魔']

for section in sections:
    section = section.strip()
    if not section:
        continue

    lines = [l for l in section.split('\n') if l.strip()]
    if not lines:
        continue

    # Find novel title - first non-empty line that looks like a title
    title = None
    body_start = 0
    for idx, line in enumerate(lines):
        l = line.strip()
        if len(l) < 15 and any(l.endswith(e) for e in novel_endings):
            title = l
            body_start = idx + 1
            break

    if not title:
        continue

    body = '\n'.join(lines[body_start:]).strip()
    if body and '整理者' not in title:
        novels.append({
            "title": title,
            "summary": body
        })

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/novels_overview.json', 'w', encoding='utf-8') as f:
    json.dump(novels, f, ensure_ascii=False, indent=2)

print(f'Done: {len(novels)} novels')
for n in novels:
    print(f"  《{n['title']}》: {len(n['summary'])} chars")
