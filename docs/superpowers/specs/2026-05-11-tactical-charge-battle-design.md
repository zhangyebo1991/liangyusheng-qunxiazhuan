# 菱形战棋与集气基础切片设计

日期：2026-05-11
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下个版本创建“山道强人菱形战棋与集气基础切片”，把现有山道强人战从按钮式回合战斗升级为小型菱形格战棋战斗，并引入类似金庸群侠传 MOD 的 `0-1000` 集气行动机制。

本阶段的目标不是完整战棋系统，而是在现有探索、任务、条件、效果、背包、存档和战斗回流基础上，验证一场可玩的 `1v2` 战棋战斗能否稳定接入项目主流程。

核心验证点：

- 山道强人触发点进入菱形格战棋战斗，而不是普通按钮回合战斗。
- 战斗规模为云游少侠对山道强人和山道喽啰。
- 单位在战斗中实时集气，集气达到 `1000` 后获得行动权。
- 本版使用暂停制行动：单位获得行动权后，集气时间暂停，行动结束后恢复。
- 玩家行动流程为移动、可选攻击、结束行动。
- 敌人使用同一套移动和攻击规则，由简单 AI 自动行动。
- 胜利后沿用现有战斗回流，清除山道强人对象，推进“山道试剑”，奖励基础剑法熟练度。
- 暂退或失败后回到山道安全位置，不清除敌人触发点。

## 范围

本阶段包含：

- 新增战棋战斗运行时状态，例如 `TacticalBattleState`。
- 新增战棋单位状态，例如 `TacticalUnitState`。
- 新增战棋规则系统，例如 `TacticalCombatSystem`。
- 扩展山道强人战斗触发配置，让它声明 `battle_mode = "tactical"` 和战棋配置。
- 扩展或替换战斗场景表现，显示菱形格、单位、集气条、行动状态、日志和暂退按钮。
- 支持 `1v2` 战斗：云游少侠、山道强人、山道喽啰。
- 支持实时集气、行动暂停、移动范围、攻击范围、普通攻击、敌人 AI、胜负判断。
- 保留暂退。
- 胜利结算继续使用 `GameState.apply_battle_result()`。
- 增加领域、系统、地图触发、结算和场景加载测试。
- 更新 `README.md` 和 `docs/godot-project-structure.md`。

本阶段不做：

- 不做战斗中使用小还丹。
- 不做多武学、技能范围、技能消耗或武学选择 UI。
- 不做队友控制、队伍系统或多人玩家单位。
- 不做地形加成、障碍、复杂寻路或战场编辑器。
- 不做完整 `encounters.json` 内容管线。
- 不做玩家可切换的暂停/即时双模式 UI。
- 不做战斗存档恢复。
- 不做大地图新剧情或官道伏击新战斗。

## 推荐方案

采用“可配置时间模式的菱形战棋系统”。

本版默认时间模式为 `pause_on_action`：战斗平时实时集气，任意单位达到 `1000` 后进入行动阶段并暂停集气；行动完成后该单位集气清零，战斗恢复实时集气。

系统层保留未来即时模式扩展点，例如：

```text
time_mode = "pause_on_action"
future: "realtime_selection"
```

本阶段不开放模式切换 UI，不实现 `realtime_selection` 的行为。这样玩家体验先按暂停制做稳，架构上避免把暂停写死，后续可以扩展为类似逸剑群侠传的两种战斗节奏。

## 玩法设计

山道强人战仍由 `enemy_bandit_gate` 触发。玩家进入战斗后，看到一块小型菱形格战场。战场第一版使用固定尺寸和固定初始站位，重点验证规则闭环。

单位：

- 云游少侠：玩家控制。
- 山道强人：敌方主单位。
- 山道喽啰：敌方辅助单位。

每个单位保存：

- `unit_id`
- `actor_id`
- `display_name`
- `team`
- `hp`
- `max_hp`
- `attack`
- `defense`
- `move_range`
- `attack_range`
- `charge_speed`
- `charge`
- `cell`
- `has_acted`

行动规则：

1. 战斗开始后所有存活单位实时累积集气。
2. 任意单位集气达到 `1000`，系统选出当前行动单位。
3. 集气时间暂停。
4. 玩家单位显示可移动格。
5. 玩家点击目标格移动，也可以原地不动。
6. 移动后如果敌人在攻击范围内，显示可攻击目标。
7. 玩家可以攻击一次，也可以结束行动。
8. 行动结束后该单位集气清零，恢复实时集气。
9. 敌人单位由 AI 自动执行移动和攻击，然后清零集气。

伤害第一版复用当前公式思路：

```text
damage = max(1, attacker.attack - defender.defense)
```

如果后续要把武学威力接回战棋，应另开设计，把 `martial_arts.json` 的招式威力、范围和消耗统一纳入战棋技能系统。本阶段普通攻击足够验证战棋和集气。

## 架构

项目继续保持“领域状态、系统规则、场景表现、核心回流”分层。

### TacticalUnitState

新增领域对象，保存单个战棋单位的运行时状态。

职责：

- 保存单位属性、阵营、气血、格子坐标、集气值和行动状态。
- 判断单位是否存活。
- 支持序列化为字典，便于测试和日志输出。
- 不读取内容数据，不操作 Godot 节点。

### TacticalBattleState

新增领域对象，保存一场战棋战斗的运行时状态。

职责：

- 保存战场尺寸。
- 保存单位列表。
- 保存当前行动单位。
- 保存时间模式、是否正在集气、是否行动暂停。
- 保存来源地图、来源对象、任务编号、胜利效果和日志。
- 保存战斗是否结束和是否胜利。
- 生成 `GameState.apply_battle_result()` 可处理的结算 payload。

它不直接修改任务、地图对象、背包或武学熟练度。

### TacticalCombatSystem

新增系统对象，处理战棋规则。

建议接口：

- `create_battle(game_state, context, repository)`：从战斗上下文、地图配置和角色数据创建 `TacticalBattleState`。
- `advance_charge(battle_state, delta)`：按实时流逝推进集气。
- `get_ready_unit(battle_state)`：选出达到 `1000` 的行动单位。
- `begin_unit_action(battle_state, unit_id)`：进入行动阶段并暂停集气。
- `get_movable_cells(battle_state, unit_id)`：计算可移动格。
- `move_unit(battle_state, unit_id, cell)`：执行移动。
- `get_attackable_units(battle_state, unit_id)`：计算可攻击目标。
- `attack_unit(battle_state, attacker_id, defender_id)`：执行普通攻击。
- `end_unit_action(battle_state, unit_id)`：清零集气并恢复集气。
- `resolve_enemy_action(battle_state, unit_id)`：执行敌人 AI。
- `resolve_retreat(battle_state)`：处理暂退。
- `check_battle_finished(battle_state)`：判断胜负。

系统只返回结果和日志，不创建 UI 节点。

### 战斗场景

战斗界面可以在计划阶段决定是改造 `scripts/scenes/battle_screen.gd`，还是新增 `scripts/scenes/tactical_battle_screen.gd` 并由原战斗入口分流。

无论采用哪种文件结构，场景职责一致：

- 读取 `GameState.peek_battle_context()`。
- 根据 `battle_mode` 决定普通回合战斗或战棋战斗。
- 显示菱形格、单位、可移动格、可攻击目标、集气条、气血、日志和暂退按钮。
- 把玩家点击转成 `TacticalCombatSystem` 调用。
- 战斗结束时调用 `GameState.apply_battle_result()`，再切回来源地图。

场景不直接计算伤害，不直接推进任务，不直接清除地图对象。

## 数据设计

山道强人触发点继续放在 `data/maps.json`。本阶段优先把战棋配置放在该触发对象上，避免过早新增 `data/encounters.json`。

建议战斗上下文或地图对象包含：

```json
{
  "battle_mode": "tactical",
  "encounter_id": "mountain_bandit_tutorial",
  "source_map_id": "mountain_pass",
  "source_object_id": "enemy_bandit_gate",
  "quest_id": "quest_mountain_trial",
  "battlefield": {"width": 7, "height": 5},
  "time_mode": "pause_on_action",
  "units": [
    {
      "unit_id": "hero",
      "actor_id": "hero_yun",
      "team": "player",
      "start_cell": {"q": 1, "r": 2},
      "move_range": 3,
      "attack_range": 1,
      "charge_speed": 240
    },
    {
      "unit_id": "bandit",
      "actor_id": "bandit_01",
      "team": "enemy",
      "start_cell": {"q": 5, "r": 2},
      "move_range": 3,
      "attack_range": 1,
      "charge_speed": 220
    },
    {
      "unit_id": "bandit_lackey",
      "actor_id": "bandit_lackey_01",
      "team": "enemy",
      "start_cell": {"q": 5, "r": 3},
      "move_range": 3,
      "attack_range": 1,
      "charge_speed": 260
    }
  ]
}
```

`actors.json` 继续提供气血、攻击、防御和显示名。战棋专用字段第一版放在战斗配置中，因为它们属于特定遭遇的调校，不一定适用于角色全局属性。

如果未来出现多场战棋战斗，再把 `encounter_id`、战场、单位和胜利效果迁移到独立 `data/encounters.json`。

## 菱形格坐标

本阶段只需要逻辑上的菱形格，不需要复杂地形。

推荐使用二维格坐标：

```text
cell = { q, r }
```

距离计算使用菱形/四方向移动距离：

```text
distance = abs(a.q - b.q) + abs(a.r - b.r)
```

可移动格为战场范围内、距离不超过 `move_range`、且没有被存活单位占用的格子。第一版不做障碍，因此不需要 A* 路径。渲染时把 `{q, r}` 映射到屏幕菱形位置。

## 集气时间轴

集气上限固定为 `1000`。

`advance_charge(delta)` 规则：

1. 如果战斗结束，不推进。
2. 如果当前处于行动阶段，不推进。
3. 对所有存活且未行动中的单位增加集气：

```text
charge += charge_speed * delta
```

4. 如果多个单位同时达到 `1000`，按固定规则选行动者：
   - 玩家单位优先。
   - 同阵营按单位列表顺序。
5. 选中行动者后进入行动阶段，集气暂停。

行动结束后：

```text
unit.charge = 0
current_unit_id = ""
is_action_phase = false
```

本版 UI 展示每个单位的集气条和数值状态，但不提供倍速、暂停按钮或即时模式切换。

## 敌人 AI

第一版敌人 AI 保持简单、可预测、可测试。

行动规则：

1. 如果主角已经在攻击范围内，直接攻击。
2. 否则计算所有可移动格。
3. 选择能让敌人离主角最近的格子。
4. 如果移动后进入攻击范围，攻击一次。
5. 否则结束行动。

平局时按固定格子排序选择，保证测试稳定。

敌人不使用物品，不暂退，不等待，不使用技能。

## UI 与交互

战斗界面主区域显示菱形战场。单位第一版可以使用色块、标签或简单图形，不要求正式美术。

需要显示：

- 菱形格战场。
- 玩家单位和敌方单位。
- 当前行动单位高亮。
- 可移动格高亮。
- 可攻击目标高亮。
- 单位气血。
- 单位集气条。
- 当前战斗状态，例如“等待集气”“云游少侠行动”“山道强人行动”。
- 战斗日志。
- “结束行动”按钮。
- “暂退”按钮。

玩家输入：

- 点击可移动格执行移动。
- 点击可攻击敌人执行攻击。
- 点击“结束行动”跳过攻击。
- 点击“暂退”结束战斗并按失败回流处理。

当不是玩家行动阶段时，玩家不能移动或攻击单位。

## 结算与回流

战棋战斗结束时生成与现有 `GameState.apply_battle_result()` 兼容的 payload。

胜利 payload 应包含：

- `victory = true`
- `hero_hp`
- `source_map_id`
- `source_object_id = "enemy_bandit_gate"`
- `quest_id = "quest_mountain_trial"`
- `martial_art_id = "basic_sword"`
- `proficiency_reward`
- `log`

如果地图战斗对象已经声明 `victory_effects`，优先使用显式效果，继续复用当前 `EffectSystem`。

失败或暂退 payload 应包含：

- `victory = false`
- `hero_hp`
- `source_map_id`
- `source_object_id`
- `log`

失败和暂退不清除地图对象，不推进任务。主角气血由现有失败回流钳制到至少 `1`。

## 错误处理

- 战棋配置缺失关键字段：显示“战斗配置不完整”，允许暂退。
- `battlefield` 无效：使用安全默认值 `7x5` 并记录日志。
- 单位资料缺失：跳过该单位并记录日志。
- 玩家单位缺失：显示错误日志并允许暂退。
- 敌方有效单位为空：直接胜利，避免卡死。
- 单位站位越界或重叠：跳过无效单位并记录日志。
- 没有可移动格：允许原地攻击或结束行动。
- 没有可攻击目标：允许结束行动。
- 集气并列：按固定顺序打破平局，保证测试稳定。
- `battle_mode` 未声明：继续走现有普通回合战斗，保持兼容。

## 测试策略

新增或扩展测试：

- `TacticalUnitState`：初始化、存活判断、集气清零、序列化。
- `TacticalBattleState`：单位列表、当前行动单位、行动阶段、胜负状态、结算 payload。
- `TacticalCombatSystem`：
  - 创建战斗。
  - 实时集气推进。
  - 达到 `1000` 后进入行动阶段。
  - 并列集气按固定顺序选择。
  - 可移动格计算。
  - 攻击范围计算。
  - 移动后攻击。
  - 敌人 AI 移动和攻击。
  - 胜利、失败和暂退。
- 地图数据：山道强人触发点声明战棋配置和山道喽啰资料。
- 回流测试：胜利后清除 `enemy_bandit_gate`、推进 `quest_mountain_trial`、奖励基础剑法熟练度。
- 回流测试：暂退或失败不清除地图对象，主角回到安全位置。
- 场景测试：战斗场景可 headless 加载，关键 UI 节点存在。
- 回归测试：未声明 `battle_mode` 的战斗仍能走普通回合战斗。

## 验收标准

- 玩家触发山道强人后进入菱形格战棋战斗。
- 战场中出现云游少侠、山道强人和山道喽啰。
- 集气条实时增长，达到 `1000` 后进入对应单位行动。
- 玩家行动时集气暂停，玩家可以移动后攻击或结束行动。
- 敌人可以自动移动并攻击主角。
- 击败所有敌人后返回山道，并完成当前山道战斗回流。
- 暂退或失败后返回山道安全位置，敌人触发点仍存在。
- 所有新增和既有测试通过。

## 后续扩展

本切片完成后，可以在独立设计中继续扩展：

- 即时选择模式：玩家操作时敌人继续集气。
- 模式切换 UI：暂停制和即时制两种战斗节奏。
- 多武学、技能范围、内力消耗和招式冷却。
- 队友与多玩家单位控制。
- 地形、障碍和路径寻路。
- 独立 `data/encounters.json`。
- 战斗存档恢复。
