"""Parse 探索梁羽生创作历程之独门兵器和暗器篇.md to weapons_hidden.json"""
import json, sys, re, os, glob
sys.stdout.reconfigure(encoding='utf-8')

# Find the file by glob pattern to avoid encoding issues on Windows
matches = glob.glob('references/*独门兵器*.md')
if not matches:
    print('ERROR: Cannot find weapons file')
    sys.exit(1)

with open(matches[0], 'r', encoding='utf-8') as f:
    text = f.read()

# Split by novel sections: ## 《novel_name》
novel_sections = re.split(r'\n## (《.+?》.*?)\n', text)

result = []

for i in range(1, len(novel_sections), 2):
    novel_title = novel_sections[i].strip().strip('《》')
    body = novel_sections[i + 1] if i + 1 < len(novel_sections) else ""

    # Skip sections with no weapon entries (like "空缺")
    if '空缺' in body[:100] and '###' not in body[:500]:
        continue

    items = []
    # Split by ### weapon/hidden weapon name
    weapon_sections = re.split(r'\n### (.+?)\n', body)

    for j in range(1, len(weapon_sections), 2):
        weapon_name = weapon_sections[j].strip()
        weapon_body = weapon_sections[j + 1] if j + 1 < len(weapon_sections) else ""

        # Parse fields
        appearance = ""
        users = []
        combat = ""
        comment = ""

        # Extract 式样
        m = re.search(r'\*\*式样：?\*\*\s*(.*?)(?=\n\*\*|\n---|\Z)', weapon_body, re.DOTALL)
        if m:
            appearance = m.group(1).strip()

        # Extract 使用者/兵器使用人
        m = re.search(r'\*\*(?:使用者|兵器使用人)：?\*\*\s*(.*?)(?=\n\*\*|\n---|\Z)', weapon_body, re.DOTALL)
        if m:
            user_text = m.group(1).strip()
            # Split by 、，, etc.
            users = [u.strip() for u in re.split(r'[、，,；;]', user_text) if u.strip()]
            # Clean up parenthetical descriptions
            users = [re.sub(r'（.*?）', '', u).strip() for u in users]
            users = [u for u in users if u]

        # Extract 临阵/对阵/演示
        m = re.search(r'\*\*(?:临阵|对阵|演示|使用)：?\*\*\s*(.*?)(?=\n\*\*|\n简评|\n---|\Z)', weapon_body, re.DOTALL)
        if m:
            combat = m.group(1).strip()

        # Extract 简评
        m = re.search(r'\*\*简评：?\*\*\s*(.*?)(?=\n---|\n## |\Z)', weapon_body, re.DOTALL)
        if m:
            comment = m.group(1).strip()

        # Determine type: weapon or hidden weapon
        # Heuristic: if it mentions 暗器 in name or comment, it's hidden_weapon
        item_type = "weapon"
        if any(kw in weapon_name for kw in ['镖', '针', '弹', '砂', '芒', '花', '球', '铃', '环', '枕', '钩', '索', '环', '雾', '瘴']):
            item_type = "hidden_weapon"
        if '暗器' in (comment[:100] if comment else ''):
            item_type = "hidden_weapon"

        if weapon_name not in ('总评', '另评') and (appearance or comment):
            items.append({
                "name": weapon_name,
                "type": item_type,
                "appearance": appearance,
                "users": users,
                "combat_description": combat[:300] if combat else "",
                "comment": comment[:500] if comment else ""
            })

    if items:
        result.append({
            "novel": novel_title,
            "items": items
        })

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/weapons_hidden.json', 'w', encoding='utf-8') as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

total = sum(len(n['items']) for n in result)
print(f'Done: {len(result)} novels, {total} items')
for n in result:
    print(f"  《{n['novel']}》: {len(n['items'])} items")
