# 角色成长系统设计

## 概述

设计一个模块化的角色成长系统，包含技能树、内功心法和武学领悟三个子系统，通过GrowthManager统一管理。

## 核心目标

- **增强成长感**：玩家能明显感受到角色变强
- **丰富战斗体验**：不同构建带来不同战斗风格
- **易于理解和使用**：玩家能快速上手
- **易于扩展**：后续能轻松添加新内容

## 约束条件

- 与现有系统兼容（战斗、任务、对话等）
- 保持简单（第一版不过度复杂）
- 数据驱动（易于通过数据扩展）

## 整体架构

### 模块化设计

三个独立子系统，通过GrowthManager协调：

```
GrowthManager
├── SkillTreeSystem (技能树系统)
├── InnerArtSystem (内功心法系统)
└── InsightSystem (武学领悟系统)
```

### 数据流

1. **战斗结束** → 积累熟练度点数 → 检查领悟触发
2. **对话事件** → 检查领悟触发
3. **使用物品** → 学会技能/检查领悟触发
4. **手动加点** → 消耗熟练度解锁技能树节点
5. **修炼心法** → 消耗修为点提升心法等级（修为点通过战斗和任务获得）

## 详细设计

### 1. 技能树系统

#### 设计理念

- 技能通过秘籍学习
- 每个技能有独立的技能树，有多个分支
- 通用熟练度（战斗积累）用于技能树加点
- 玩家可以自由在任意分支上加点，不需要选择单一路线

#### 数据结构

```json
// data/skill_trees/basic_sword.json
{
  "skill_id": "basic_sword",
  "name": "基础剑法",
  "branches": [
    {
      "id": "power_branch",
      "name": "刚猛路线",
      "nodes": [
        {
          "id": "dmg_1",
          "name": "力道+3",
          "cost": 1,
          "effects": {"damage_bonus": 3}
        },
        {
          "id": "dmg_2",
          "name": "力道+5",
          "cost": 2,
          "requires": ["dmg_1"],
          "effects": {"damage_bonus": 5}
        },
        {
          "id": "crit",
          "name": "暴击强化",
          "cost": 3,
          "requires": ["dmg_2"],
          "effects": {"crit_chance": 0.1}
        }
      ]
    },
    {
      "id": "technique_branch",
      "name": "技巧路线",
      "nodes": [
        {
          "id": "acc_1",
          "name": "精准+5",
          "cost": 1,
          "effects": {"accuracy_bonus": 5}
        },
        {
          "id": "bleed",
          "name": "破绽攻击",
          "cost": 2,
          "requires": ["acc_1"],
          "effects": {"add_effect": "bleed"}
        },
        {
          "id": "multi",
          "name": "连击",
          "cost": 3,
          "requires": ["bleed"],
          "effects": {"extra_strike": 0.15}
        }
      ]
    }
  ]
}
```

#### 节点类型

- **属性节点**：直接增加角色属性（伤害、精准、暴击等）
- **效果节点**：为技能添加特殊效果（流血、眩晕、连击等）

#### 加点规则

- 消耗熟练度点数解锁节点
- 必须满足前置节点要求（requires）
- 可以在任意分支自由加点
- 已解锁节点不可撤销（第一版）

### 2. 内功心法系统

#### 设计理念

- 通过秘籍或剧情学会心法
- 消耗修为点提升心法等级
- 同时只能激活一个心法
- 每级提供属性加成

#### 数据结构

```json
// data/inner_arts/calm_heart.json
{
  "id": "calm_heart",
  "name": "静心诀",
  "description": "入门心法，提升内力根基",
  "max_level": 10,
  "effects_per_level": {
    "max_mp": 3,
    "mp_regen": 1
  },
  "level_up_cost": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]
}
```

#### 心法效果

- 最大内力提升
- 内力恢复速度
- 内力抗性
- 特殊效果（如内力护盾、内力爆发等）

#### 切换机制

- 同时只能激活一个心法
- 切换心法无冷却时间（第一版）
- 切换后立即应用新心法效果

### 3. 武学领悟系统

#### 设计理念

- 通用的条件触发解锁系统
- 不限于战斗，可在游戏中任意场景触发
- 条件可灵活组合（AND逻辑）
- 支持多种触发场景

#### 数据结构

```json
// data/martial_insights/sword_insights.json
{
  "insights": [
    {
      "id": "sword_whirlwind",
      "name": "旋风剑领悟",
      "conditions": [
        {"type": "skill_proficiency", "skill": "basic_sword", "min": 30},
        {"type": "skill_used_count", "skill": "basic_sword", "min": 50},
        {"type": "random", "chance": 0.1}
      ],
      "trigger_scene": "combat",
      "result": {
        "unlock": "sword_whirlwind",
        "message": "实战中你领悟了「旋风剑」！"
      }
    },
    {
      "id": "master_teaching",
      "name": "师父指点",
      "conditions": [
        {"type": "dialogue", "npc": "master_chen", "dialogue_id": "teach_01"},
        {"type": "quest_completed", "quest": "apprentice_trial"}
      ],
      "trigger_scene": "dialogue",
      "result": {
        "unlock": "cloud_step",
        "message": "师父传授了你「云步」身法！"
      }
    },
    {
      "id": "book_insight",
      "name": "秘籍顿悟",
      "conditions": [
        {"type": "item_used", "item": "ancient_sword_manual"},
        {"type": "inner_art_level", "min": 5}
      ],
      "trigger_scene": "any",
      "result": {
        "unlock": "sword_qi_burst",
        "message": "研读古籍，你领悟了「剑气迸发」！"
      }
    }
  ]
}
```

#### 条件类型

- `skill_proficiency` - 技能熟练度
- `skill_used_count` - 技能使用次数
- `dialogue` - 特定NPC对话
- `quest_completed` - 任务完成
- `item_used` - 使用物品
- `inner_art_level` - 内功等级
- `random` - 随机概率
- `level` - 角色等级

#### 触发场景

- `combat` - 战斗中触发
- `dialogue` - 对话中触发
- `item` - 使用物品时触发
- `any` - 任意场景

#### 领悟结果

- 解锁新技能
- 解锁被动能力
- 解锁技能变体
- 显示领悟提示

### 4. GrowthManager 统一管理器

#### 核心职责

- 协调三个子系统
- 提供统一接口
- 管理资源（熟练度点数、修为点）
- 处理存档/读档

#### 接口设计

```gdscript
# scripts/systems/growth_manager.gd
extends RefCounted

# 战斗结束调用
func on_battle_end(battle_data: Dictionary)

# 对话事件调用
func on_dialogue_event(npc_id: String, dialogue_id: String)

# 使用物品调用
func on_item_used(item_id: String)

# 加点技能树节点
func unlock_skill_node(skill_id: String, node_id: String) -> Dictionary

# 升级内功心法
func upgrade_inner_art(art_id: String) -> Dictionary

# 切换激活心法
func switch_active_inner_art(art_id: String) -> Dictionary
```

## 系统集成

### 1. 战斗系统集成

- 战斗结束时调用 `GrowthManager.on_battle_end()`
- 计算熟练度收益（基于战斗难度、敌人数量）
- 检查武学领悟触发条件

### 2. 对话系统集成

- 对话事件时调用 `GrowthManager.on_dialogue_event()`
- 特定对话可触发领悟（如师父传授）

### 3. 物品系统集成

- 使用秘籍物品时，学会对应技能
- 使用特殊物品时，可触发领悟

### 4. 存档系统集成

```gdscript
{
  "proficiency_points": 15,
  "skill_tree_nodes": {"basic_sword": ["dmg_1", "bleed"]},
  "inner_arts": {"calm_heart": 3, "current_active": "calm_heart"},
  "insight_triggers": {"sword_whirlwind": {"last_trigger_battle": 5}}
}
```

### 5. 现有系统扩展

- `growth_system.gd` 保持不变，继续处理经验升级
- `proficiency_system.gd` 扩展，增加熟练度点数管理
- `effect_system.gd` 扩展，支持技能树效果应用

## UI界面设计

### 1. 技能树界面

- **左侧**：技能列表（已学会的武学）
- **中间**：技能树可视化（节点+连线）
- **右侧**：节点详情、加点按钮
- **顶部**：当前熟练度点数显示

### 2. 内功心法界面

- 当前激活心法显示
- 心法列表（已学会的心法）
- 升级按钮、效果预览

### 3. 领悟记录界面

- 已领悟技能/能力列表
- 领悟条件提示（哪些已满足、哪些未满足）

### 4. HUD集成

- 战斗中：熟练度点数变化提示
- 领悟触发时：特殊提示动画

## 实现优先级

### 第一阶段（核心框架）

1. GrowthManager 基础结构
2. 熟练度点数系统（战斗积累）
3. 技能树数据结构+基础加点逻辑

### 第二阶段（技能树完整实现）

1. 技能树UI界面
2. 节点效果应用（属性加成、技能效果）
3. 存档/读档集成

### 第三阶段（内功心法）

1. 内功心法数据+升级逻辑
2. 内功效果应用
3. 心法切换UI

### 第四阶段（武学领悟）

1. 领悟条件系统
2. 多场景触发支持
3. 领悟UI提示

## 数据文件结构

```
data/
├── skill_trees/
│   ├── basic_sword.json
│   ├── basic_spear.json
│   └── ...
├── inner_arts/
│   ├── calm_heart.json
│   ├── flowing_cloud.json
│   └── ...
└── martial_insights/
    ├── sword_insights.json
    ├── spear_insights.json
    └── ...
```

## 成功标准

1. **玩家能感受到成长**：角色明显变强
2. **战斗策略多样化**：不同构建有不同战斗风格
3. **易于理解和使用**：玩家能快速上手
4. **易于扩展**：后续能轻松添加新内容