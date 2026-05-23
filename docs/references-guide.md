# 参考资料使用指南

本文档描述 `references/` 目录下所有设计参考资料的内容、结构和策划用途，供 AI 协同设计时参考。

> **格式说明**：结构化数据采用 CSV 格式（非 JSON），原因：这些数据是给人和 AI 阅读的参考资料，不是游戏运行时加载的数据。CSV 更紧凑，减少 token 消耗和视觉噪声。

---

## 目录结构

```
references/
├── structured/              # 结构化 CSV 数据（人/AI 可读）
│   ├── characters.csv
│   ├── martial_arts_master.csv
│   ├── martial_arts_by_novel.csv
│   ├── weapons_hidden.csv
│   ├── wuxia_codex.csv
│   ├── relationships.csv
│   ├── classic_battles.csv
│   └── novels_overview.csv
├── scripts/                 # 转换脚本（Python）
│   ├── convert_characters.py
│   ├── convert_martial_arts.py
│   ├── convert_weapons.py
│   ├── convert_codex.py
│   ├── convert_relationships.py
│   ├── convert_battles.py
│   └── convert_novels.py
├── 全梁著人物资料.xls        # 原始数据
├── 全梁著武功资料.xls
├── 梁羽生武学宝典.md
├── 探索梁羽生创作历程之独门兵器和暗器篇.md
├── 人物关系.txt
├── 梁羽生小说经典的十场大战.txt
├── 梁羽生小说内容简介.txt
└── 早期设定参考-基于金庸群侠传mod/
    ├── 《梁羽生群侠传》构想说明文档.doc
    ├── 《梁羽生群侠传》地名一览.xls
    ├── 可入队人物建议.xls
    ├── 魔兽地图《梁羽生群侠传》物品设定集.txt
    └── 梁群示意图.png
```

---

## 结构化数据文件说明

### characters.csv — 人物数据

- **来源**：`全梁著人物资料.xls`（阵子整理）
- **规模**：34部小说，4593个人物
- **列**：`novel`, `name`, `description`, `importance`（main/other）
- **用途**：
  - 角色系统设计：主要人物 → 核心可玩角色，其他人物 → NPC/配角
  - 角色图鉴/传记系统的文本素材
  - 跨小说人物引用查询

### martial_arts_master.csv — 武功总表

- **来源**：`全梁著武功资料.xls`（阵子整理）
- **规模**：591种武功，18个分类（剑法83种、掌法155种、刀法47种、轻功39种等）
- **列**：`category`, `name`, `novels`（分号分隔的书目列表）
- **用途**：
  - 技能树分类设计：18个分类可直接映射为技能树分支
  - 跨小说武功复用关系查询（如"蹑云十三剑法"出现在15部小说中）

### martial_arts_by_novel.csv — 按小说分列的武功

- **来源**：`全梁著武功资料.xls`
- **规模**：34部小说，2295条记录
- **列**：`novel`, `category`, `name`, `users`（分号分隔的使用者列表）, `school`（门派）
- **用途**：
  - 构建"角色-武功-门派"三角关系
  - 单部小说内的武功配置参考
  - 门派武功体系设计

### weapons_hidden.csv — 独门兵器与暗器

- **来源**：`探索梁羽生创作历程之独门兵器和暗器篇.md`（笑笑道人）
- **规模**：29部小说，76件兵器/暗器
- **列**：`novel`, `name`, `type`（weapon/hidden_weapon）, `appearance`（式样）, `users`, `combat_description`（临阵描写）, `comment`（简评）
- **用途**：
  - 装备系统设计：每件武器的式样和特殊效果可直接用于装备描述
  - 暗器系统设计：独立于常规武器的投射物系统
  - 装备描述文本素材（简评可提炼为物品说明）

### wuxia_codex.csv — 武学宝典

- **来源**：`梁羽生武学宝典.md`（笑笑道人）
- **规模**：11大类，34子分类，349条条目
- **分类**：门派武功、门派辈分及掌门人、兵器、暗器、铠甲、信物、宝物、毒药、灵药、秘籍、异兽
- **列**：`section`, `subsection`, `name`, `description`
- **用途**：
  - 门派体系设计：门派武功 + 门派辈分数据
  - 道具全品类参考：兵器/暗器/铠甲/信物/宝物/毒药/灵药/秘籍/异兽
  - 毒药/灵药系统设计：完整的药效描述

### relationships.csv — 人物关系

- **来源**：`人物关系.txt`（阵子整理）
- **规模**：433条关系
- **列**：`from`, `to`, `relation`, `novel`, `section`
- **关系类型**：父母子女/亲属、夫妻、师徒、情侣、上下属、后人等
- **用途**：
  - 羁绊系统设计：基于关系触发特殊对话/合体技/增益
  - 剧情条件判断：角色间关系作为任务/事件的前置条件
  - 角色关系图谱可视化

### classic_battles.csv — 十场经典大战

- **来源**：`梁羽生小说经典的十场大战.txt`（天山游龙）
- **规模**：10场
- **列**：`rank`（1-10）, `title`, `novel`, `description`
- **用途**：
  - Boss战/关卡设计灵感：每场大战都是经过读者检验的经典场景
  - 战斗演出设计：对战双方、兵器、武功搭配的参考
  - 剧情高潮节点设计

### novels_overview.csv — 小说概览

- **来源**：`梁羽生小说内容简介.txt`（天山游龙，GBK编码）
- **规模**：19部小说
- **列**：`title`, `summary`（剧情摘要）
- **用途**：
  - 主线/支线任务设计：每部小说的剧情可拆解为任务链
  - 世界观背景参考
  - 注：原文件覆盖约20部小说，非全部35部

---

## 原始参考文件说明

### 梁羽生武学宝典.md（~96KB）

笑笑道人撰写的全面武学资料，涵盖门派武功体系、辈分掌门、兵器暗器、铠甲信物、宝物毒药、灵药秘籍、异兽等。是门派和道具系统设计的核心参考。已结构化为 `wuxia_codex.json`。

### 探索梁羽生创作历程之独门兵器和暗器篇.md

笑笑道人对梁著35部小说中独门兵器和暗器的逐部分析，含式样、使用者、临阵描写、简评，以及独门兵器篇总评（8大分类）和暗器篇总评。已结构化为 `weapons_hidden.json`。

### 早期设定参考-基于金庸群侠传mod/

早期基于《金庸群侠传》MOD 的设定方案，包括：
- **构想说明文档**：早期游戏框架构想
- **地名一览**：场景/地图素材
- **可入队人物建议**：角色招募系统参考
- **物品设定集**：成熟的品级体系（C→S）、属性分类、合成公式，可作为装备系统框架参考
- **示意图**：地图布局参考

---

## 数据交叉引用指南

最有价值的是多个数据源之间的联动关系：

### 角色 → 武功 → 门派

```
characters.csv（选角色）
  → martial_arts_by_novel.csv（查该角色会什么武功）
    → martial_arts_master.csv（查该武功分类）
      → wuxia_codex.csv（查门派详情）
```

### 角色 → 兵器 → 装备属性

```
characters.csv（选角色）
  → weapons_hidden.csv（查其兵器式样和特点）
  → wuxia_codex.csv / 兵器（查更多兵器资料）
  → 早期设定参考/物品设定集（参考属性框架和品级体系）
```

### 剧情 → 关卡 → 战斗

```
novels_overview.csv（提取剧情节点）
  → classic_battles.csv（选取经典战斗场景）
  → martial_arts_by_novel.csv（设计战斗参数）
  → relationships.csv（确定角色关系作为剧情条件）
```

### 门派 → 技能树 → 武功解锁

```
wuxia_codex.csv / 门派武功（门派武功列表）
  → martial_arts_by_novel.csv（每部小说的门派归属）
  → data/skill_trees/（现有技能树结构参考）
```

---

## 与游戏数据的关系

游戏运行数据在 `data/` 目录（JSON），由 `DataRepository` 自动加载。`references/structured/` 中的数据为**策划参考**，不直接被游戏加载。

如需将参考数据导入游戏，需要：
1. 按 `data/` 中现有 JSON 的 schema 重新组织字段（CSV → JSON 转换）
2. 生成符合 `id` 命名规范的唯一标识
3. 确保引用关系（如 `martial_arts` 数组中的 id）在目标文件中存在

现有游戏数据规模：
- `actors.json`：少量角色（原型阶段）
- `martial_arts.json`：少量武功
- `items.json`：少量物品

参考资料提供了完整的梁羽生武侠世界内容池，可在后续开发中逐步扩充游戏数据。

---

## 转换脚本说明

`references/scripts/` 下的 Python 脚本用于将原始资料转换为 CSV。分两步：

**第一步**：原始资料 → JSON（中间格式）
```bash
python references/scripts/convert_characters.py
python references/scripts/convert_martial_arts.py
python references/scripts/convert_weapons.py
python references/scripts/convert_codex.py
python references/scripts/convert_relationships.py
python references/scripts/convert_battles.py
python references/scripts/convert_novels.py
```

**第二步**：JSON → CSV（最终格式）
```bash
python references/scripts/json_to_csv.py
```

在项目根目录下运行即可。

依赖：`xlrd`、`pandas`（已安装）
