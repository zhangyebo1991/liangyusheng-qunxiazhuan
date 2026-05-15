# 战术 AI 与自动战斗设计

## 背景

当前游戏已具备完整的战棋战斗系统，玩家需要手动控制每个单位的移动和技能释放。随着队友数量增加，逐个操作所有单位（包括主角）会变得繁琐。本阶段目标是引入自动战斗模式，让 AI 代替玩家控制所有单位，AI 能根据技能范围、MP 和敌人位置选择最优行动。

## 目标

- 战斗中可按键切换手动/自动模式
- 自动模式下所有玩家单位（含主角）由 AI 控制
- AI 能评估技能范围、蓝量、敌人位置，选择最优行动
- 核心策略：移动到能打到最多敌人的位置
- 手动/自动可随时切换，不中断战斗

## 非目标

- 不做复杂战术倾向（进攻/保守等）
- 不做队友性格差异
- 不做自动用药
- 不做多回合预判
- 不做复杂仇恨系统

## 核心规则

### 模式切换

战斗中按 `A` 键切换手动/自动模式。切换立即生效：若当前单位正在行动中，自动模式下 AI 继续完成当前行动，手动模式下等待玩家操作。

### AI 决策流程

```
当前单位行动开始
→ 检查当前 MP 和可用技能列表
→ 遍历所有敌人，计算每个敌人位置
→ 对每个可移动位置，评估该位置能攻击到的敌人数量
→ 选择能打到最多敌人的位置+技能组合
→ 若多个组合打到相同数量，优先选伤害高的技能
→ 若 MP 不足释放任何技能，使用普通攻击
→ 移动到目标位置，释放选定技能
```

### 技能评估规则

| 条件 | 处理 |
|------|------|
| MP >= 技能消耗 | 技能可选 |
| MP < 技能消耗 | 跳过该技能 |
| 技能范围覆盖 N 个敌人 | 记录 N 作为评分 |
| 普通攻击 | 作为兜底选项 |

### 位置评估规则

```
for 每个可移动位置:
    for 每个可用技能:
        计算该位置下技能能覆盖的敌人数量
        记录 (位置, 技能, 覆盖数量, 总伤害)
选择 覆盖数量最多 的组合
若数量相同，选 总伤害最高 的组合
```

## 系统设计

### 新增模块

| 模块 | 类型 | 职责 |
|------|------|------|
| `TacticalAI` | system | AI 决策核心，评估位置和技能，返回行动指令 |
| `AutoBattleMode` | domain | 记录当前战斗是手动/自动模式 |

### TacticalAI 接口

```gdscript
# 返回单位的最优行动: { "move_to": Vector2i, "use_skill": String, "target": Vector2i }
func evaluate(unit: TacticalUnitState, enemies: Array, battle_state: TacticalBattleState) -> Dictionary

# 计算某位置下某技能能覆盖的敌人数量
func count_targets_from_position(skill_id: String, position: Vector2i, enemies: Array, battle_state: TacticalBattleState) -> int

# 获取单位可用技能（过滤 MP 不足的）
func get_available_skills(unit: TacticalUnitState, repository: DataRepository) -> Array[String]
```

### AutoBattleMode 数据

```gdscript
var is_auto: bool = false
```

### 战斗流程集成

```
单位集气满 → 开始行动
→ 检查 is_auto
  → true: 调用 TacticalAI.evaluate()，自动执行移动+技能
  → false: 等待玩家手动操作
→ 行动结束，继续集气
```

### 数据需求

- `martial_arts.json` 已有技能范围数据，无需新增
- `TacticalUnitState` 已有 `mp`、`martial_arts` 字段，无需新增

## UI 设计

### 自动战斗切换

| 操作 | 说明 |
|------|------|
| 按键触发 | 战斗中按 `A` 键切换手动/自动模式 |
| 状态显示 | 战场 UI 显示当前模式：`手动` / `自动` |
| 切换时机 | 任何时候可切换，当前单位行动中切换则立即生效 |

### UI 布局

```
┌─────────────────────────────────────┐
│  战场 UI 顶部状态栏                   │
│  ┌─────────────────────────────────┐│
│  │  模式: 手动  [按 A 切换自动]     ││
│  └─────────────────────────────────┘│
│  ... 原有战斗 UI ...                 │
└─────────────────────────────────────┘
```

### 模式行为

**手动模式**：原有交互不变，玩家选择移动、普攻、技能

**自动模式**：
- 玩家单位自动行动，无需点击
- 行动动画正常播放，玩家可观看
- 仍可按 `A` 切回手动模式，当前单位行动暂停等待操作

### 战斗日志

自动模式下，战斗日志显示 AI 决策：
- `云游少侠 移动到 (5,3)`
- `云游少侠 释放 基础剑法，命中 2 名敌人`

## 错误处理

| 情况 | 处理方式 |
|------|----------|
| 所有敌人超出移动范围 | 向最近敌人移动最大距离，不释放技能 |
| 无可用技能且 MP 不足 | 使用普通攻击移动到最近敌人 |
| 多个位置打到相同数量敌人 | 选择总伤害最高的组合 |
| 目标位置被友军占用 | 选择次优位置 |
| 技能范围为 0（自身范围） | 在原地释放，不移动 |
| 切换模式时单位正在行动 | 自动模式：AI 继续完成当前行动；手动模式：等待玩家操作 |
| 存档缺少自动模式字段 | 默认为手动模式 |

## 测试计划

### 新增测试文件

| 测试文件 | 覆盖内容 |
|----------|----------|
| `test_tactical_ai.gd` | AI 决策逻辑：位置评估、技能选择、覆盖数量计算 |
| `test_auto_battle_mode.gd` | 自动/手动模式切换、状态持久化 |

### 测试用例

```gdscript
# test_tactical_ai.gd
func test_selects_skill_with_most_targets()
func test_falls_back_to_normal_attack_when_no_mp()
func test_moves_toward_nearest_enemy_when_no_targets()
func test_avoids_occupied_cells()
func test_prefers_higher_damage_on_equal_targets()

# test_auto_battle_mode.gd
func test_default_is_manual_mode()
func test_toggle_switches_mode()
func test_mode_persists_in_battle_state()
```

### 回归要求

- 全量 `tests/run_tests.gd` 保持通过
- 现有战斗测试不受影响

## 手动验收

1. 进入战棋战斗，按 `A` 切换到自动模式
2. 观察所有玩家单位自动行动，选择最优位置和技能
3. 查看战斗日志，确认 AI 决策合理
4. 按 `A` 切回手动模式，当前单位暂停等待操作
5. 存档退出后重新进入，手动模式为默认状态

## 实施顺序

1. **AutoBattleMode 数据层**
   - 新增 `AutoBattleMode` 类
   - 集成到 `TacticalBattleState`
   - 存档兼容测试

2. **TacticalAI 核心逻辑**
   - 实现 `evaluate()` 方法
   - 实现 `count_targets_from_position()` 方法
   - 实现 `get_available_skills()` 方法
   - 单元测试覆盖

3. **战斗流程集成**
   - 修改 `TacticalCombatSystem` 行动流程
   - 自动模式调用 AI 决策
   - 手动模式保持原有逻辑

4. **UI 与交互**
   - 战场 UI 显示当前模式
   - `A` 键切换逻辑
   - 战斗日志输出

5. **测试与验收**
   - 全量测试通过
   - 手动验收各场景

## 风险与取舍

最大风险是 AI 决策过于简单导致战斗无趣。第一版采用"最大化覆盖"策略，优先打到最多敌人，这比随机行动更有策略性，但不会过度智能。

第二个风险是模式切换打断战斗节奏。设计为即时切换，不中断动画，保持流畅体验。

第三个风险是 AI 行动动画时间过长。复用现有动画系统，不做特殊处理，保持一致体验。
