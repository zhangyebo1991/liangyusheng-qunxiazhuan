"""Convert 人物关系.txt to relationships.json"""
import json, sys, re, os
sys.stdout.reconfigure(encoding='utf-8')

with open('references/人物关系.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

relationships = []
current_novel = ""
current_section = ""

for line in lines:
    line = line.strip()
    if not line:
        continue

    # Skip source attribution line
    if line.startswith('通过所有'):
        continue

    # Relationship lines: "A --relation--> B"
    match = re.match(r'(.+?)\s*--(.+?)-->\s*(.+)', line)
    if match:
        relationships.append({
            "from": match.group(1).strip(),
            "to": match.group(3).strip(),
            "relation": match.group(2).strip().rstrip('/'),
            "novel": current_novel,
            "section": current_section
        })
        continue

    # Section/subsection headers (lines without --> pattern)
    # Check if it's a novel title (typically 4-6 chars, well-known names)
    # or a sub-section (like "大唐皇室与朝廷")
    if not re.search(r'-->', line):
        # Heuristic: if line is short and looks like a novel title
        if '传' in line or '录' in line or '剑' in line or '缘' in line or '记' in line:
            current_novel = line
            current_section = ""
        else:
            current_section = line

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/relationships.json', 'w', encoding='utf-8') as f:
    json.dump(relationships, f, ensure_ascii=False, indent=2)

print(f'Done: {len(relationships)} relationships')
