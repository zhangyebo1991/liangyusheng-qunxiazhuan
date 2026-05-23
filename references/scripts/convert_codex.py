"""Parse 梁羽生武学宝典.md to wuxia_codex.json"""
import json, sys, re, os, glob
sys.stdout.reconfigure(encoding='utf-8')

matches = glob.glob('references/*武学宝典*.md')
if not matches:
    print('ERROR: Cannot find codex file')
    sys.exit(1)

with open(matches[0], 'r', encoding='utf-8') as f:
    text = f.read()

# Structure: ## major sections, ### sub-sections, **entries**
# We'll parse into a hierarchical structure

result = []
current_section = None
current_subsection = None
current_entries = []

def flush_subsection():
    global current_subsection, current_entries, current_section
    if current_subsection and current_entries:
        if current_section is None:
            current_section = {"title": "未分类", "subsections": []}
        current_section["subsections"].append({
            "title": current_subsection,
            "entries": current_entries
        })
        current_entries = []

def flush_section():
    global current_section, current_subsection
    flush_subsection()
    if current_section:
        result.append(current_section)
        current_section = None
    current_subsection = None

for line in text.split('\n'):
    # Major section: ## 门派武功, ## 兵器, etc.
    if line.startswith('## ') and not line.startswith('### '):
        flush_section()
        current_section = {"title": line[3:].strip(), "subsections": []}
        current_subsection = None
        continue

    # Sub-section: ### 少林派, ### 武当派, etc.
    if line.startswith('### '):
        flush_subsection()
        current_subsection = line[4:].strip()
        continue

    # Entry: **name**：description or - **name**：description
    m = re.match(r'(?:-\s*)?\*\*(.+?)\*\*[：:]\s*(.*)', line)
    if m:
        # Auto-create a default subsection if none exists
        if current_subsection is None and current_section is not None:
            current_subsection = current_section["title"]
        name = m.group(1).strip()
        desc = m.group(2).strip()
        current_entries.append({"name": name, "description": desc})
        continue

    # Continuation of previous entry (indented or bullet point)
    if current_entries and (line.startswith('  ') or line.startswith('- ') or line.startswith('> ')):
        current_entries[-1]["description"] += '\n' + line.strip()
        continue

    # Standalone paragraph (add as entry with empty name if substantial)
    stripped = line.strip()
    if stripped and current_subsection and not stripped.startswith('---') and not stripped.startswith('> 整理') and not stripped.startswith('> 作者') and not stripped.startswith('> 原文'):
        # Check if it's a continuation paragraph
        if current_entries and not stripped.startswith('**'):
            current_entries[-1]["description"] += ' ' + stripped

flush_section()

os.makedirs('references/structured', exist_ok=True)
with open('references/structured/wuxia_codex.json', 'w', encoding='utf-8') as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

total_sections = len(result)
total_subsections = sum(len(s.get('subsections', [])) for s in result)
total_entries = sum(
    len(sub.get('entries', []))
    for s in result
    for sub in s.get('subsections', [])
)
print(f'Done: {total_sections} sections, {total_subsections} subsections, {total_entries} entries')
for s in result:
    subs = len(s.get('subsections', []))
    ents = sum(len(sub.get('entries', [])) for sub in s.get('subsections', []))
    print(f"  {s['title']}: {subs} subsections, {ents} entries")
