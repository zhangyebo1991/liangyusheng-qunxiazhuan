# 战棋武学与内力基础切片设计

日期：2026-05-12
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“战棋武学与内力基础切片”，把当前“移动后普通攻击”的方格战棋推进到“移动、选招式、消耗内力、利用距离”的最小策略闭环。

当前项目已经具备山道强人 `1v2` 方格战棋、实时集气、行动暂停、普通攻击、敌人移动攻击、暂退、胜负回流、任务奖励和武学熟练度回流。`data/martial_arts.json` 已有 `power`、`cost` 和 `proficiency_reward`，但战棋系统暂时不读取招式数据。本阶段要把武学资料接入战棋，同时加入简化内力模型，让玩家在战棋中有可见、可消耗、可权衡的战斗资源。

## 范围

本阶段包含：

- 主角拥有长期最大内力 `hero_max_mp`，新游戏默认 `20`，随存档保存和恢复。
- 战棋中的玩家单位拥有当前内力和最大内力，每场战棋开局按最大内力回满。
- 战斗内内力消耗只影响当前战斗，不写回长期当前内力。
- `data/martial_arts.json` 扩展战棋字段，用于描述战棋伤害、内力消耗、范围和范围形状。
- 主角在战棋中可用普通攻击、基础剑法和两格直线剑招。
- 基础剑法是近身高伤招式，消耗内力。
- 两格直线剑招用于验证距离和站位价值，消耗内力。
- 战棋 UI 显示内力、招式按钮、当前选中动作和对应可攻击格。
- 敌人本阶段继续只使用普通攻击。
- 胜利、失败、暂退、地图对象清除、任务推进和熟练度奖励沿用现有战斗回流。

本阶段不包含：

- 完整角色面板。
- 长期当前内力管理。
- 内力药、客栈恢复或非战斗恢复规则。
- 敌人招式 AI。
- 复杂地形、障碍、AOE、多目标、状态异常、冷却或技能升级树。
- 将战棋遭遇迁移到独立 `data/encounters.json`。

## 推荐方案

采用“数据化招式 + 简化内力 + 玩家双招式”的方案。

只接入基础剑法的方案风险最低，但战棋仍以贴脸互砍为主，走位价值提升有限。敌我都接招式 AI 的方案更完整，但会同时引入敌人内力、招式选择策略和 AI 测试边界，容易把切片做厚。

推荐方案让玩家立刻获得三个有差异的行动选择：

- 普通攻击：不耗内力，近身保底。
- 基础剑法：近身高伤，消耗少量内力。
- 穿云刺：两格直线攻击，消耗更多内力，用于验证距离与站位。

敌人保持普通攻击，可以让本阶段聚焦玩家侧战斗体验和战棋招式基础设施。

## 架构

项目继续保持“领域状态、系统规则、场景表现、核心回流”分层。

- `data/martial_arts.json` 保存武学静态资料和战棋参数。
- `scripts/domain/martial_art_record.gd` 读取武学字段和战棋配置，不执行战斗规则。
- `scripts/domain/tactical_unit_state.gd` 保存战棋单位当前内力、最大内力和可用武学编号。
- `scripts/systems/tactical_combat_system.gd` 处理招式合法性、范围、扣内力、伤害、日志和胜负。
- `scripts/scenes/battle_screen.gd` 只负责显示内力、按钮、选中动作、格子高亮和点击接线。
- `scripts/core/game_state.gd` 保存主角长期最大内力和存档字段，不知道具体招式如何结算。
- `scripts/systems/data_repository.gd` 继续提供武学资料读取，不承载战棋规则。
- `tests/` 保存武学数据、内力状态、战棋规则、UI 接线和回归测试。

`TacticalCombatSystem` 是战棋规则唯一入口。场景脚本不能直接扣内力或计算招式伤害，避免后续做敌人招式 AI、更多战斗场景或自动测试时出现两套规则。

## 数据设计

### 武学战棋字段

`data/martial_arts.json` 保留现有字段，并增加可选 `tactical` 字段：

```json
{
  "id": "basic_sword",
  "name": "基础剑法",
  "school": "江湖",
  "power": 12,
  "cost": 3,
  "description": "入门剑招，胜在稳妥。",
  "proficiency_reward": 1,
  "tactical": {
    "damage_bonus": 6,
    "range": 1,
    "range_shape": "diamond",
    "mp_cost": 3
  }
}
```

字段含义：

- `damage_bonus`：战棋招式额外伤害加值。
- `range`：最大攻击距离，最小为 `1`。
- `range_shape`：范围形状，第一版支持 `diamond` 和 `line`。
- `mp_cost`：战棋内力消耗。缺失时使用旧字段 `cost`，两者都缺失时为 `0`。

`power` 继续保留给普通回合战斗和后续数值扩展。本阶段战棋伤害读取 `tactical.damage_bonus`，避免直接改变旧回合战斗数值。

### 新增穿云刺

新增玩家可用武学 `straight_sword_thrust`：

```json
{
  "id": "straight_sword_thrust",
  "name": "穿云刺",
  "school": "江湖",
  "power": 10,
  "cost": 5,
  "description": "挺剑直进，可隔一身位刺敌。",
  "proficiency_reward": 0,
  "tactical": {
    "damage_bonus": 4,
    "range": 2,
    "range_shape": "line",
    "mp_cost": 5
  }
}
```

`hero_yun.martial_arts` 增加 `straight_sword_thrust`。敌人资料不变，仍可保留 `rough_fist` 供后续敌人招式 AI 使用。

## 状态设计

### GameState

`GameState` 增加：

```text
hero_max_mp: int = 20
```

规则：

- `start_new_game()` 设置 `hero_max_mp = 20`。
- `to_dictionary()` 保存 `hero_max_mp`。
- `from_dictionary()` 读取 `hero_max_mp`；旧存档缺少字段时使用 `20`。
- 本阶段不新增长期 `hero_mp`，战斗结束不保存当前内力。

### TacticalUnitState

`TacticalUnitState` 增加：

```text
mp: int
max_mp: int
martial_art_ids: Array[String]
```

规则：

- 玩家单位创建时，`max_mp` 取 `GameState.hero_max_mp`，`mp` 等于 `max_mp`。
- 非玩家单位第一版 `max_mp/mp` 可为 `0`，仍能普通攻击。
- `martial_art_ids` 从 actor 的 `martial_arts` 字段读取。
- `to_dictionary()` 和 `from_dictionary()` 保存和恢复这些字段，便于测试和调试。

### TacticalBattleState

`TacticalBattleState.to_result_dictionary()` 不返回 `hero_mp`。当前阶段采用“长期最大内力 + 每场战斗开局回满”的模型，战斗内消耗是战斗局部状态。

## 战棋规则

### 普通攻击

现有 `attack_unit()` 保持为普通攻击入口：

```text
damage = max(1, attacker.attack - defender.defense)
```

普通攻击：

- 不耗内力。
- 使用单位自身 `attack_range`。
- 成功后写日志并检查胜负。
- 玩家普通攻击后自动结束行动，保持现有体验。

### 武学攻击

新增系统接口：

```text
use_martial_art(battle, attacker_id, defender_id, martial_art_id, repository) -> Dictionary
```

执行前校验：

1. 战斗、攻击者和目标存在。
2. 攻击者和目标都存活。
3. 攻击者和目标不同阵营。
4. 攻击者拥有该武学编号。
5. 武学资料存在且包含可用 `tactical` 配置。
6. 攻击者当前内力大于等于 `mp_cost`。
7. 目标在招式范围内。

成功后：

```text
damage = max(1, attacker.attack + tactical.damage_bonus - defender.defense)
attacker.mp -= mp_cost
defender.hp -= damage
```

然后写入战斗日志，目标气血归零时写入击败日志，最后调用现有胜负检查。

### 范围形状

`range_shape = "diamond"`：

```text
distance = abs(a.q - b.q) + abs(a.r - b.r)
distance <= range
```

`range_shape = "line"`：

```text
same_line = a.q == b.q or a.r == b.r
distance = abs(a.q - b.q) + abs(a.r - b.r)
same_line and distance <= range
```

第一版不处理遮挡，因为当前战棋没有障碍物。后续加入障碍和地形时，再扩展 line-of-sight 规则。

### 行动结束

玩家攻击类动作成功后自动结束行动：

- 普通攻击成功后结束。
- 武学攻击成功后结束。
- 移动不结束行动。
- 内力不足、目标无效或范围错误不会结束行动。

这样玩家可以先移动，再选招式攻击；也可以选招式后点击目标。如果释放失败，玩家仍有机会改用普通攻击或调整选择。

## UI 设计

战棋 UI 在现有战场、日志、结束行动和暂退按钮基础上增加玩家招式选择。

### 状态显示

战棋状态区显示：

- 当前阶段，例如“等待集气”或“云游少侠行动”。
- 当前行动单位气血。
- 当前行动单位内力，例如 `内力 17 / 20`。

第一版只在玩家行动时显示内力。等待集气和敌人行动时不显示内力行，保持界面简洁。

### 招式按钮

玩家行动时显示：

- 普通攻击。
- 基础剑法。
- 穿云刺。
- 结束行动。
- 暂退。

默认选中普通攻击。点击招式按钮只切换当前战斗动作，不立即执行。玩家随后点击敌方格子，`BattleScreen` 根据当前动作调用普通攻击或武学攻击。

按钮可用性：

- 非玩家行动时禁用攻击和招式按钮。
- 内力不足时禁用对应招式按钮。
- 武学资料缺失或没有战棋配置时不显示该按钮。
- 普通攻击始终可用，只要玩家处于行动阶段。

### 格子高亮

玩家行动时继续高亮可移动格。攻击格根据当前选中动作计算：

- 普通攻击：使用单位 `attack_range`。
- 基础剑法：使用 `tactical.range = 1` 和 `diamond` 范围。
- 穿云刺：使用 `tactical.range = 2` 和 `line` 范围。

只有敌方目标所在格需要可点击攻击。空格仍用于移动。高亮只做提示，最终合法性仍由 `TacticalCombatSystem` 校验。

## 错误处理

- 旧存档缺少 `hero_max_mp`：读档时默认 `20`。
- actor 缺少 `martial_arts`：战棋单位 `martial_art_ids` 为空，只能普通攻击。
- 武学编号不存在：按钮不显示；如果系统接口被直接调用，返回失败并记录安全消息。
- 武学缺少 `tactical`：不作为战棋招式显示。
- `range_shape` 未知：按不可用处理，返回失败消息。
- 内力不足：不扣内力，不造成伤害，不结束行动。
- 目标不在范围：不扣内力，不造成伤害，不结束行动。
- 非玩家行动时场景收到点击：忽略，保持现有防护。

## 测试计划

新增和更新测试：

- `MartialArtRecord`：读取 `tactical` 配置，缺失 `mp_cost` 时回退到 `cost`，缺失 `tactical` 时保持兼容。
- `GameState`：新游戏默认 `hero_max_mp = 20`；存档读写保存；旧存档缺字段时恢复默认值。
- `TacticalUnitState`：序列化包含 `mp/max_mp/martial_art_ids`。
- `TacticalCombatSystem`：
  - 创建玩家战棋单位时内力回满。
  - 武学属于单位且内力足够时释放成功。
  - 释放后扣内力、造成正确伤害、写入日志。
  - 内力不足时失败且不扣资源。
  - 不属于单位的武学释放失败。
  - `diamond` 范围能命中近身目标。
  - `line` 范围能命中两格直线目标。
  - `line` 范围不能命中斜向或超范围目标。
  - 武学击败最后敌人后触发胜利。
- `BattleScreen`：headless 加载战棋界面时，内力显示和招式按钮存在。
- 回归测试：普通攻击、敌人 AI、暂退、失败回流、胜利回流、旧普通回合战斗继续通过。

## 验收标准

- 山道强人战中，主角有 `20 / 20` 内力并显示在战棋 UI。
- 主角行动时可选择普通攻击、基础剑法和穿云刺。
- 基础剑法近身造成高于普通攻击的伤害，并消耗内力。
- 穿云刺可以攻击两格直线目标。
- 穿云刺不能攻击斜向目标或超出两格的目标。
- 内力不足时对应招式按钮禁用；如果系统接口被直接调用，则释放失败且不扣资源。普通攻击仍可用。
- 玩家移动后仍可以使用当前选中招式攻击合法目标。
- 敌人仍按现有普通攻击 AI 行动。
- 击败敌人后返回山道，并完成地图对象、任务状态和熟练度回流。
- 暂退或失败后仍返回安全位置，敌人触发点保留。
- 所有新增测试和既有测试通过。

## 后续扩展

本切片完成后，可以在独立设计中继续扩展：

- 敌人招式 AI 和敌方内力。
- 多目标、扇形、周身、穿透等范围形状。
- 内力恢复道具、客栈恢复和长期当前内力。
- 武学熟练度影响伤害、消耗或范围。
- 角色面板展示气血、内力、武学和熟练度。
- 独立 `data/encounters.json`，把多场战棋遭遇从地图对象中拆出。
