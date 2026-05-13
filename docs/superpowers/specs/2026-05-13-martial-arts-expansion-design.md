# 战棋武学扩展：新范围形状 + 熟练度成长

日期：2026-05-13  
状态：已确认（待进入计划阶段）

## 1. 背景与目标

当前战棋已有3种范围形状（`diamond`、`line`、`target_cross_1`）和3门武学 + 普攻。`data/martial_arts.json` 的 `proficiency_reward` 字段存在但仅在战斗回流时走 `EffectSystem` 写入，战棋内未物化展示或用它做伤害加成。

本阶段目标：
- 新增4种范围形状，实装到 `TacticalRangeSystem`，不与现有形状逻辑耦合
- 新增4门武学，每种对应一个新形状
- 引入轻量跨战斗熟练度：`GameState` 存 `proficiency_map`，战斗中用完招式自动累加，跨阈值有 `damage_bonus` 提升
- 不改战斗数值公式、不改集气/回合/胜负核心逻辑

成功判据：
- 4种新形状在战斗中正确渲染高亮、正确命中/不命中边界
- 熟练度跨战斗累积，阈值后伤害可感知提升
- 全量回归测试通过（现有55+套件）

范围外：
- 敌人招式AI（敌人继续只用普攻）
- 武学图鉴/技能树UI
- 熟练度影响 mp_cost 或 range（本阶段只影响 damage_bonus）

## 2. 总体架构

严格遵循现有四层架构（核心/领域/系统/场景），不改分层原则。

新增：
- `scripts/systems/proficiency_system.gd`（RefCounted）：熟练度计数、阈值查询、伤害加值计算

修改：
- `scripts/systems/tactical_range_system.gd`：新增4个范围算法函数，每种形状独立实现
- `scripts/systems/tactical_combat_system.gd`：`resolve_action` 新形状命中判定；攻击结算后调用 `ProficiencySystem` 累加计数
- `scripts/core/game_state.gd`：新增 `proficiency_map: Dictionary`
- `scripts/scenes/battle_screen.gd`：展示当前选中文招式的熟练度等级
- `data/martial_arts.json`：新增4门武学 + 所有武学补充 `proficiency_thresholds`

不动：
- `scripts/systems/combat_system.gd`（非战棋）
- `scripts/systems/effect_system.gd`、`condition_system.gd`、`inventory_system.gd`、`shop_system.gd` 等
- `scripts/scenes/charge_bar.gd`、`battle_log.gd`、`battle_panel_actor.gd` 等 UI 组件
- `BattleFeedbackDirector`（反馈表现层不介入武学数据）

核心约束：
- 每种新形状一个独立函数（不是万能分支函数），后续添形状直接加函数
- 熟练度系统只读 `GameState.proficiency_map`，不直接操作战斗状态
- 范围高亮和命中判定共用同一函数，消除"高亮显示可打但实际不能打"的不一致

## 3. 关键组件设计

### 3.1 四种新范围形状

每种一个独立纯函数，入参 `(unit_q, unit_r, direction: Vector2i, range: int) -> Array[Vector2i]`（周身/环形无需 direction 参数）：

| 形状 | ID | 描述 | 算法要点 |
|------|-----|------|---------|
| 扇形 | `fan` | 单位前方120度、最远2格的锥形 | 先选方向 -> 遍历 range 内格 -> 夹角 <= 60度 且 曼哈顿距离 <= range |
| 周身 | `surround` | 单位相邻8格全部 | `max(abs(dq), abs(dr)) == 1`，不选方向、不选目标 |
| 穿透 | `pierce` | 直线方向全部命中（不止首个） | 选方向 -> 沿方向投影格子直到 range 上限，过线所有单位都命中 |
| 环形 | `ring` | 以施放者为中心距=2的环形 | `abs(dq) + abs(dr) == 2`，不选方向 |

方向型形状（fan、pierce）交互沿用现有模式：选招后出4方向箭头，点方向即释放。周身、环形点招式直接释放。

**扇形夹角判断**：
```
有向投影 dx*dir.x + dy*dir.y > 0 且 叉积绝对值 <= 点积*tan(60度)
即：偏移量在锥宽内
```

### 3.2 四门新武学

```json
{
  "id": "sword_willow_sweep",
  "name": "回风拂柳",
  "tactical": { "shape": "fan", "range": 2, "mp_cost": 6, "damage_bonus": 5 },
  "shape": "fan",
  "proficiency_thresholds": [10, 25, 50]
},
{
  "id": "sword_all_directions",
  "name": "八方风雨",
  "tactical": { "shape": "surround", "range": 1, "mp_cost": 10, "damage_bonus": 3 },
  "shape": "surround",
  "proficiency_thresholds": [10, 25, 50]
},
{
  "id": "sword_rainbow_pierce",
  "name": "长虹贯日",
  "tactical": { "shape": "pierce", "range": 3, "mp_cost": 7, "damage_bonus": 4 },
  "shape": "pierce",
  "proficiency_thresholds": [12, 30, 60]
},
{
  "id": "sword_ring_aura",
  "name": "剑气环身",
  "tactical": { "shape": "ring", "range": 2, "mp_cost": 8, "damage_bonus": 4 },
  "shape": "ring",
  "proficiency_thresholds": [12, 30, 60]
}
```

`hero_yun.martial_arts` 数组追加这4个 id。现有3门武学补充 `proficiency_thresholds` 字段：
- `basic_sword`：[10, 25, 50]
- `straight_sword_thrust`：[10, 25, 50]
- `sword_aura_swirl`：[12, 30, 60]

### 3.3 轻量熟练度系统

`GameState` 新增字段：

```gdscript
var proficiency_map: Dictionary = {}  # { "basic_sword": 17, "sword_willow_sweep": 3, ... }
```

存档读写覆盖。旧存档缺字段默认 `{}`。

`ProficiencySystem`（RefCounted）：

```gdscript
func get_use_count(map: Dictionary, martial_id: String) -> int
func add_use(map: Dictionary, martial_id: String) -> void
func get_threshold_bonus(map: Dictionary, martial_id: String, thresholds: Array) -> int
func get_level(use_count: int, thresholds: Array) -> int
```

- `get_threshold_bonus`：遍历 `proficiency_thresholds`，统计 `use_count` 跨过的阈值数，每档 +2 damage_bonus
- 例如阈值 `[10, 25, 50]`，当前23次 -> 跨过10 -> Lv.2 -> bonus = +2；跨过25 -> Lv.3 -> +4
- `get_level`：返回 0 到 len(thresholds)，0 表示未达第一档

触发时机：`TacticalCombatSystem.resolve_action` 成功后调用 `ProficiencySystem.add_use(game_state.proficiency_map, martial_id)`。

### 3.4 UI 微调

`battle_screen` 技能选择区：
- 招式按钮旁显示等级文字：`回风拂柳 Lv.2`
- 内力不足时按钮置灰逻辑不变，熟练度不影响可用性判断

## 4. 数据流

### 4.1 熟练度生命周期

```
新游戏 -> proficiency_map = {}
   |
战棋中释放招式 -> TacticalCombatSystem.resolve_action 成功
   |
ProficiencySystem.add_use(game_state.proficiency_map, martial_id)
   |
下次打开战棋 -> battle_screen 读取 map[martial_id] -> 算阈值等级 -> 显示 "Lv.X"
   |
resolve_action 用 get_threshold_bonus 加算伤害
   |
存档 -> GameState.to_dictionary() 写 proficiency_map
```

### 4.2 单次攻击数据流（含熟练度）

```
玩家选招 + 点范围格 -> battle_screen 传 martial_id + target_cells
   |
TacticalCombatSystem.resolve_action:
  1. 校验单位存活、阵营、内力、范围合法性（TacticalRangeSystem 形状函数）
  2. 遍历 target_cells 内敌方单位 -> 算伤害 = max(1, atk + tactical.damage_bonus + prof_bonus - def)
  3. 扣内力、扣敌HP、写日志
  4. ProficiencySystem.add_use(proficiency_map, martial_id)
  5. 检查胜负、返回结果
```

### 4.3 扇形/穿透的方向交互

沿用现有 `straight_sword_thrust` 的选方向模式：
- 选招 -> `range_mode = SKILL_DIR_PREVIEW` -> 4方向箭头出现
- 点方向 -> 立即释放（不二次确认）
- 周身/环形无需选方向，点招式立即释放

## 5. 数据设计

### 5.1 `data/martial_arts.json` 变更

新增4门武学 + 现有3门补 `proficiency_thresholds` 字段。`shape` 枚举扩展：`"fan"`、`"surround"`、`"pierce"`、`"ring"`。

### 5.2 `data/actors.json` 变更

`hero_yun.martial_arts` 追加4个新 id。

### 5.3 `data/maps.json` 不变

### 5.4 `data/terrains.json` 不变

### 5.5 `data/items.json` 不变

### 5.6 `data/dialogues.json` 不变

## 6. 测试策略

### 6.1 回归要求

现有全量测试继续通过（55+ 套件）。

### 6.2 新增测试文件

| 测试文件 | 覆盖内容 |
|---------|---------|
| `tests/test_tactical_range_fan.gd` | 扇形：不同方向命中格正确、方向180度反向空格不命中、边界格判定 |
| `tests/test_tactical_range_surround.gd` | 周身：8格全命中、无目标时空放不报错 |
| `tests/test_tactical_range_pierce.gd` | 穿透：直线多目标命中、首个与末个都受伤、非直线不命中 |
| `tests/test_tactical_range_ring.gd` | 环形：距2格命中、距1/3格不命中 |
| `tests/test_proficiency_system.gd` | 次数累加、阈值等级计算、伤害加值、跨战斗持久化、旧存档兼容 |
| `tests/test_new_martial_arts_data.gd` | 4新武学数据加载、shape/tactical/thresholds 字段完整性 |

### 6.3 扩展现有测试

| 测试文件 | 扩展内容 |
|---------|---------|
| `tests/test_tactical_combat_system.gd` | 扩展用新形状招式命中/不命中 + 熟练度加值验伤 |
| `tests/test_tactical_battle_state.gd` | 扩展 proficiency_map 字段序列化 |
| `tests/test_game_state.gd` | 扩展 proficiency_map 初始化与存档 |

## 7. 实施顺序

每步可独立 commit、可独立 `--headless` 跑测试：

| Step | 内容 | 类型 |
|------|------|------|
| 1 | `proficiency_thresholds` 字段补入 `martial_arts.json`（7门武学）+ 数据加载测试 | 数据 |
| 2 | `GameState.proficiency_map` 字段 + 序列化/旧档兼容 + 测试 | 状态 |
| 3 | `ProficiencySystem`（add_use + get_threshold_bonus）+ 测试 | 系统 |
| 4 | `fan` 范围算法接入 `TacticalRangeSystem` + 测试 | 系统 |
| 5 | `surround` 范围算法接入 `TacticalRangeSystem` + 测试 | 系统 |
| 6 | `pierce` 范围算法接入 `TacticalRangeSystem` + 测试 | 系统 |
| 7 | `ring` 范围算法接入 `TacticalRangeSystem` + 测试 | 系统 |
| 8 | 4门新武学数据 + `hero_yun.martial_arts` 追加 + 数据加载测试 | 数据 |
| 9 | `TacticalCombatSystem.resolve_action` 接入新 shape 命中判定 | 系统 |
| 10 | `resolve_action` 成功后调用 `ProficiencySystem.add_use` + 测试 | 系统 |
| 11 | `resolve_action` 伤害计算接入 `get_threshold_bonus` + 验伤测试 | 系统 |
| 12 | `battle_screen` 技能列表显示熟练度等级 "Lv.X" | UI |
| 13 | 全量回归 `--headless` 跑通 | 验证 |

## 8. 风险与应对

- **R1**：扇形夹角判断在网格坐标系下可能产生非直觉命中。应对：测试用具体格坐标断言，不依赖抽象"角度"。
- **R2**：穿透形状命中多目标时总伤害可能过高。应对：多目标各自独立算防，不合并伤害；后续可加"穿透每过一个目标 -N 伤害"规则。
- **R3**：旧存档无 proficiency_map 字段。应对：from_dictionary 缺字段默认 `{}`，不影响旧存档读取。
