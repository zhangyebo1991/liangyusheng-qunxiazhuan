# 战棋武学扩展：新范围形状 + 熟练度成长 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增4种范围形状（fan/surround/pierce/ring）+ 4门对应武学 + 轻量跨战斗熟练度系统（每阈值档 +2 damage_bonus）。

**Architecture:** TacticalRangeSystem 每形状一个独立纯函数；ProficiencySystem（RefCounted）读 `martial_proficiency`（已有字段）+ `proficiency_thresholds`（新 JSON 字段）；TacticalCombatSystem.resolve_action 结算后调 ProficiencySystem.add_use 累加次数并计入 damage_bonus。不改集气/回合/胜负核心。

**Tech Stack:** Godot 4.6、GDScript、现有自定义 headless 测试框架（tests/run_tests.gd）。

---

## File Structure（先锁边界）

### Create
- `scripts/systems/proficiency_system.gd`：RefCounted，熟练度计数/等级/加值计算
- `tests/test_proficiency_system.gd`：熟练度单元测试
- `tests/test_tactical_range_fan.gd`：扇形范围测试
- `tests/test_tactical_range_surround.gd`：周身范围测试
- `tests/test_tactical_range_pierce.gd`：穿透范围测试
- `tests/test_tactical_range_ring.gd`：环形范围测试
- `tests/test_new_martial_arts_data.gd`：新武学数据加载测试

### Modify
- `data/martial_arts.json`：4门新武学 + 现有7门补 `proficiency_thresholds`
- `data/actors.json`：`hero_yun.martial_arts` 追加4个新id
- `scripts/systems/tactical_range_system.gd`：新增4个范围算法函数
- `scripts/systems/tactical_combat_system.gd`：`_get_tactical_martial_art` 白名单扩展 + `resolve_action`/`_resolve_generic_skill` 接入熟练度
- `scripts/core/game_state.gd`：`martial_proficiency` 字段已存在，不变（仅依赖现有 `get_martial_proficiency` / `add_martial_proficiency`）
- `scripts/domain/martial_art_record.gd`：新增 `proficiency_thresholds` 字段读取
- `tests/run_tests.gd`：注册7个新测试文件
- `tests/test_data_loader.gd`：扩展覆盖新武学数据

---

### Task 1: 熟练度阈值数据 — martial_arts.json 补充 + data_loader 测试

**Files:**
- Modify: `data/martial_arts.json`
- Modify: `tests/test_data_loader.gd:1-25`

- [ ] **Step 1: 补 proficiency_thresholds 到 martial_arts.json 并确保数据加载测试先失败**

所有7门武学追加 `"proficiency_thresholds"` 字段。现有 `data/martial_arts.json`：

```json
[
  {
    "id": "basic_sword",
    "name": "基础剑法",
    "school": "江湖",
    "power": 12,
    "cost": 3,
    "description": "入门剑招，胜在稳妥。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [10, 25, 50],
    "tactical": {
      "damage_bonus": 6,
      "range": 1,
      "range_shape": "diamond",
      "mp_cost": 3
    }
  },
  {
    "id": "straight_sword_thrust",
    "name": "穿云刺",
    "school": "江湖",
    "power": 10,
    "cost": 5,
    "description": "挺剑直进，可隔一身位刺敌。",
    "proficiency_reward": 0,
    "proficiency_thresholds": [10, 25, 50],
    "shape": "line_2",
    "tactical": {
      "damage_bonus": 4,
      "range": 2,
      "range_shape": "line",
      "mp_cost": 5
    }
  },
  {
    "id": "sword_aura_swirl",
    "name": "剑气漩",
    "school": "江湖",
    "power": 14,
    "cost": 8,
    "description": "凝聚内力一掷，目标处剑气漩起，伤及周遭。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [12, 30, 60],
    "shape": "target_cross_1",
    "cast_range": 3,
    "base_damage": 14,
    "scale_attr": "atk",
    "scale_ratio": 0.6,
    "mp_cost": 8,
    "tactical": {
      "damage_bonus": 10,
      "range": 3,
      "range_shape": "diamond",
      "mp_cost": 8
    }
  },
  {
    "id": "rough_fist",
    "name": "粗浅拳脚",
    "school": "江湖",
    "power": 7,
    "cost": 1,
    "description": "街头斗殴中磨出的拳脚。",
    "proficiency_reward": 0
  }
]
```

在 `test_data_loader.gd` 的 `run()` 末尾（`repository.free()` 之前）加断言：

```gdscript
	# 熟练度阈值字段
	assertions.assert_true(repository.get_martial_art("basic_sword").get("proficiency_thresholds", []) is Array, "基础剑法应有 proficiency_thresholds 数组")
	assertions.assert_eq(int(repository.get_martial_art("basic_sword").get("proficiency_thresholds", [10,25,50])[0]), 10, "基础剑法首阈值应为 10")
	assertions.assert_eq(int(repository.get_martial_art("basic_sword").get("proficiency_thresholds", [10,25,50])[2]), 50, "基础剑法末阈值应为 50")
	assertions.assert_eq(int(repository.get_martial_art("sword_aura_swirl").get("proficiency_thresholds", [12,30,60])[0]), 12, "剑气漩首阈值应为 12")
	# rough_fist 无 tactical，不应强迫有 thresholds（缺失时为可选字段）
```

- [ ] **Step 2: 跑测试确认数据加载认证通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过，新增断言通过。

- [ ] **Step 3: 提交**

```bash
git add data/martial_arts.json tests/test_data_loader.gd
git commit -m "data: add proficiency_thresholds to all martial arts"
```

---

### Task 2: MartialArtRecord 读取 proficiency_thresholds

**Files:**
- Modify: `scripts/domain/martial_art_record.gd:1-48`

- [ ] **Step 1: 追加字段并更新 from_dictionary**

当前 `martial_art_record.gd` 无 `proficiency_thresholds` 字段。在类属性区追加：

```gdscript
var proficiency_thresholds: Array = []
```

在 `from_dictionary` 中，`proficiency_reward` 行之后追加：

```gdscript
	martial_art.proficiency_thresholds = _read_int_array(data.get("proficiency_thresholds", []))
```

在文件末尾（`has_tactical_config` 之后）加辅助方法：

```gdscript
static func _read_int_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for v in value:
		result.append(max(0, int(v)))
	return result
```

- [ ] **Step 2: 跑全量回归确认无断**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 3: 提交**

```bash
git add scripts/domain/martial_art_record.gd
git commit -m "feat: add proficiency_thresholds field to MartialArtRecord"
```

---

### Task 3: ProficiencySystem 新建 + 失败测试

**Files:**
- Create: `tests/test_proficiency_system.gd`
- Create: `scripts/systems/proficiency_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_proficiency_system.gd`：

```gdscript
extends RefCounted

const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")

func run(assertions) -> void:
	var ps = ProficiencySystemScript.new()

	# 0 次使用：等级 0，加值 0
	assertions.assert_eq(ps.get_level(0, [10, 25, 50]), 0, "0 次应 Lv.0")
	assertions.assert_eq(ps.get_bonus(0, [10, 25, 50]), 0, "0 次 bonus = 0")

	# 9 次：未跨过第一个阈值
	assertions.assert_eq(ps.get_level(9, [10, 25, 50]), 0, "9 次应 Lv.0")
	assertions.assert_eq(ps.get_bonus(9, [10, 25, 50]), 0, "9 次 bonus = 0")

	# 10 次：跨过第 1 个阈值 → Lv.1 → bonus +2
	assertions.assert_eq(ps.get_level(10, [10, 25, 50]), 1, "10 次应 Lv.1")
	assertions.assert_eq(ps.get_bonus(10, [10, 25, 50]), 2, "10 次 bonus = 2")

	# 25 次：跨过 2 个阈值 → Lv.2 → bonus +4
	assertions.assert_eq(ps.get_level(25, [10, 25, 50]), 2, "25 次应 Lv.2")
	assertions.assert_eq(ps.get_bonus(25, [10, 25, 50]), 4, "25 次 bonus = 4")

	# 50 次：跨过 3 个阈值 → Lv.3 → bonus +6
	assertions.assert_eq(ps.get_level(50, [10, 25, 50]), 3, "50 次应 Lv.3")
	assertions.assert_eq(ps.get_bonus(50, [10, 25, 50]), 6, "50 次 bonus = 6")

	# 空阈值的武学（无 proficiency_thresholds）
	assertions.assert_eq(ps.get_level(100, []), 0, "空阈值应 Lv.0")
	assertions.assert_eq(ps.get_bonus(100, []), 0, "空阈值 bonus = 0")

	# add_use 跨映射
	var map: Dictionary = {}
	ps.add_use(map, "basic_sword")
	assertions.assert_eq(int(map.get("basic_sword", 0)), 1, "add_use 应累加 1")
	ps.add_use(map, "basic_sword")
	assertions.assert_eq(int(map.get("basic_sword", 0)), 2, "二次 add_use 应累加到 2")
	ps.add_use(map, "sword_willow_sweep")
	assertions.assert_eq(int(map.get("sword_willow_sweep", 0)), 1, "其他武学应独立计数")

	ps.free()
```

- [ ] **Step 2: 注册到 run_tests.gd**

在 `tests/run_tests.gd` 顶部加 preload，`suites` 数组追加（加在 `TestBattleFeedbackDirectorScript` 之后）：

```gdscript
const TestProficiencySystemScript = preload("res://tests/test_proficiency_system.gd")
```

```gdscript
		TestProficiencySystemScript.new(),
```

- [ ] **Step 3: 跑测试确认失败**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 报 `Cannot open file 'res://scripts/systems/proficiency_system.gd'`。

- [ ] **Step 4: 写最小实现**

`scripts/systems/proficiency_system.gd`：

```gdscript
extends RefCounted

func get_level(use_count: int, thresholds: Array) -> int:
	var level := 0
	for t in thresholds:
		if use_count >= int(t):
			level += 1
	return level

func get_bonus(use_count: int, thresholds: Array) -> int:
	return get_level(use_count, thresholds) * 2

func add_use(map: Dictionary, martial_id: String) -> void:
	if martial_id.is_empty():
		return
	map[martial_id] = int(map.get(martial_id, 0)) + 1
```

- [ ] **Step 5: 跑测试确认通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/proficiency_system.gd tests/test_proficiency_system.gd tests/run_tests.gd
git commit -m "test+feat: add proficiency system baseline"
```

---

### Task 4: fan 扇形范围 — TacticalRangeSystem + 测试

**Files:**
- Create: `tests/test_tactical_range_fan.gd`
- Modify: `scripts/systems/tactical_range_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_tactical_range_fan.gd`：

```gdscript
extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()
	# 默认 8x6 网格（不传 terrain_grid 时兜底 DEFAULT_GRID_COLS/ROWS）

	# 主角在 (3,3)，方向右 (1,0)，range=2 → 扇形右方
	var fan_right = rs.get_fan_range({"position": Vector2i(3, 3)}, Vector2i(1, 0), 2)
	assertions.assert_true(fan_right.has(Vector2i(4, 3)), "正右方 1 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(5, 3)), "正右方 2 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(4, 2)), "右上方 1 格应命中")
	assertions.assert_true(fan_right.has(Vector2i(4, 4)), "右下方 1 格应命中")
	assertions.assert_false(fan_right.has(Vector2i(4, 1)), "太远上方应不命中")
	assertions.assert_false(fan_right.has(Vector2i(2, 3)), "左方应全不命中")
	assertions.assert_false(fan_right.has(Vector2i(3, 3)), "自身格不应在结果")

	# 主角在 (3,3)，方向上 (0,-1)，range=2
	var fan_up = rs.get_fan_range({"position": Vector2i(3, 3)}, Vector2i(0, -1), 2)
	assertions.assert_true(fan_up.has(Vector2i(3, 2)), "正上方 1 格应命中")
	assertions.assert_true(fan_up.has(Vector2i(3, 1)), "正上方 2 格应命中")
	assertions.assert_false(fan_up.has(Vector2i(3, 4)), "下方应不命中")

	# 主角在 (0,0)，方向右 (1,0)，range=2 → 只右侧格
	var fan_corner = rs.get_fan_range({"position": Vector2i(0, 0)}, Vector2i(1, 0), 2)
	assertions.assert_true(fan_corner.has(Vector2i(1, 0)), "角落右 1 格应命中")
	assertions.assert_true(fan_corner.has(Vector2i(2, 0)), "角落右 2 格应命中")
	assertions.assert_true(fan_corner.has(Vector2i(1, 1)), "角落右下应命中")

	rs.free()
```

- [ ] **Step 2: 注册 run_tests.gd**

加 preload 和 suite 条目：

```gdscript
const TestTacticalRangeFanScript = preload("res://tests/test_tactical_range_fan.gd")
```

在 suites 数组中追加（在 `TestBattleFeedbackDirectorScript` 后）：

```gdscript
		TestTacticalRangeFanScript.new(),
```

- [ ] **Step 3: 跑测试确认失败**

Expected: `Invalid call. Nonexistent function 'get_fan_range' in base 'RefCounted (TacticalRangeSystemScript)'`。

- [ ] **Step 4: 实现 get_fan_range**

在 `tactical_range_system.gd` 文件末尾（`_grid_dims` 之后）追加：

```gdscript
# 扇形范围：从 unit.position 沿 direction 方向，夹角 ≤ 60 度（锥宽 120 度），
# 曼哈顿距离 ≤ range 的格子。不含自身格。棋盘边界裁剪。
func get_fan_range(unit: Dictionary, direction: Vector2i, range: int, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for r in range(rows):
		for c in range(cols):
			var p := Vector2i(c, r)
			if p == src:
				continue
			var dq := p.x - src.x
			var dr := p.y - src.y
			var dist := abs(dq) + abs(dr)
			if dist > range or dist <= 0:
				continue
			var proj: int = dq * direction.x + dr * direction.y
			if proj <= 0:
				continue
			var cross: int = abs(dq * direction.y - dr * direction.x)
			if cross > proj * 2:  # tan(60°)≈1.732，保守取 2
				continue
			result.append(p)
	return result
```

- [ ] **Step 5: 跑测试确认通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/tactical_range_system.gd tests/test_tactical_range_fan.gd tests/run_tests.gd
git commit -m "feat: add fan-shaped range algorithm to TacticalRangeSystem"
```

---

### Task 5: surround 周身范围

**Files:**
- Create: `tests/test_tactical_range_surround.gd`
- Modify: `scripts/systems/tactical_range_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_tactical_range_surround.gd`：

```gdscript
extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	# 中心 (3,3) 周身 8 格
	var sur = rs.get_surround_range({"position": Vector2i(3, 3)})
	assertions.assert_eq(sur.size(), 8, "中心周身应有 8 格")
	assertions.assert_true(sur.has(Vector2i(2, 2)), "左上应命中")
	assertions.assert_true(sur.has(Vector2i(3, 2)), "上应命中")
	assertions.assert_true(sur.has(Vector2i(4, 2)), "右上应命中")
	assertions.assert_true(sur.has(Vector2i(2, 3)), "左应命中")
	assertions.assert_true(sur.has(Vector2i(4, 3)), "右应命中")
	assertions.assert_true(sur.has(Vector2i(2, 4)), "左下应命中")
	assertions.assert_true(sur.has(Vector2i(3, 4)), "下应命中")
	assertions.assert_true(sur.has(Vector2i(4, 4)), "右下应命中")
	assertions.assert_false(sur.has(Vector2i(3, 3)), "自身不应在范围")

	# 角落 (0,0) 周身仅 3 格
	var sur_corner = rs.get_surround_range({"position": Vector2i(0, 0)})
	assertions.assert_eq(sur_corner.size(), 3, "角落周身应 3 格")
	assertions.assert_true(sur_corner.has(Vector2i(1, 0)), "右")
	assertions.assert_true(sur_corner.has(Vector2i(0, 1)), "下")
	assertions.assert_true(sur_corner.has(Vector2i(1, 1)), "右下")

	rs.free()
```

- [ ] **Step 2: 注册 + 确认失败**

preload + suite 条目同 Task 4 模式。跑测试确认报 `get_surround_range` 不存在。

- [ ] **Step 3: 实现 get_surround_range**

在 `tactical_range_system.gd` 追加：

```gdscript
# 周身范围：单位相邻 8 格（上下左右 + 四角），棋盘边界裁剪。
func get_surround_range(unit: Dictionary, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var p := Vector2i(src.x + dc, src.y + dr)
			if p.x >= 0 and p.x < cols and p.y >= 0 and p.y < rows:
				result.append(p)
	return result
```

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/tactical_range_system.gd tests/test_tactical_range_surround.gd tests/run_tests.gd
git commit -m "feat: add surround range algorithm"
```

---

### Task 6: pierce 穿透范围

**Files:**
- Create: `tests/test_tactical_range_pierce.gd`
- Modify: `scripts/systems/tactical_range_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_tactical_range_pierce.gd`：

```gdscript
extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	# 主角 (3,3)，方向右，range=3 → 3 格直线
	var pierce_right = rs.get_pierce_range({"position": Vector2i(3, 3)}, Vector2i(1, 0), 3)
	assertions.assert_eq(pierce_right.size(), 3, "右穿透应 3 格")
	assertions.assert_true(pierce_right.has(Vector2i(4, 3)), "第一格应命中")
	assertions.assert_true(pierce_right.has(Vector2i(5, 3)), "第二格应命中")
	assertions.assert_true(pierce_right.has(Vector2i(6, 3)), "第三格应命中")

	# 边界裁剪：(6,3) 往右 range=3 → 仅 1 格
	var pierce_edge = rs.get_pierce_range({"position": Vector2i(6, 3)}, Vector2i(1, 0), 3)
	assertions.assert_eq(pierce_edge.size(), 1, "边缘往右应 1 格")
	assertions.assert_true(pierce_edge.has(Vector2i(7, 3)), "应仅 (7,3)")

	# 方向上 (0,-1)，range=3
	var pierce_up = rs.get_pierce_range({"position": Vector2i(3, 3)}, Vector2i(0, -1), 3)
	assertions.assert_eq(pierce_up.size(), 3, "上穿透应 3 格")
	assertions.assert_true(pierce_up.has(Vector2i(3, 0)), "最远应到 (3,0)")

	rs.free()
```

- [ ] **Step 2: 注册 + 确认失败**

- [ ] **Step 3: 实现 get_pierce_range**

在 `tactical_range_system.gd` 追加：

```gdscript
# 穿透范围：从 unit.position 沿 direction 延伸 range 格，
# 路径上所有格全部返回（用于命中判定时遍历）。棋盘边界裁剪。
func get_pierce_range(unit: Dictionary, direction: Vector2i, range: int, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for i in range(1, range + 1):
		var nb: Vector2i = src + direction * i
		if nb.x < 0 or nb.x >= cols or nb.y < 0 or nb.y >= rows:
			break
		result.append(nb)
	return result
```

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/tactical_range_system.gd tests/test_tactical_range_pierce.gd tests/run_tests.gd
git commit -m "feat: add pierce range algorithm"
```

---

### Task 7: ring 环形范围

**Files:**
- Create: `tests/test_tactical_range_ring.gd`
- Modify: `scripts/systems/tactical_range_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试**

`tests/test_tactical_range_ring.gd`：

```gdscript
extends RefCounted

const TacticalRangeSystemScript = preload("res://scripts/systems/tactical_range_system.gd")

func run(assertions) -> void:
	var rs = TacticalRangeSystemScript.new()

	# 主角 (3,3)，距=2 环形
	var ring = rs.get_ring_range({"position": Vector2i(3, 3)}, 2)
	assertions.assert_eq(ring.size(), 8, "距 2 环形应有 8 格")
	assertions.assert_true(ring.has(Vector2i(1, 3)), "距离 2 左")
	assertions.assert_true(ring.has(Vector2i(5, 3)), "距离 2 右")
	assertions.assert_true(ring.has(Vector2i(3, 1)), "距离 2 上")
	assertions.assert_true(ring.has(Vector2i(3, 5)), "距离 2 下")
	assertions.assert_true(ring.has(Vector2i(2, 2)), "距离 2 左上")
	assertions.assert_true(ring.has(Vector2i(4, 2)), "距离 2 右上")
	assertions.assert_true(ring.has(Vector2i(2, 4)), "距离 2 左下")
	assertions.assert_true(ring.has(Vector2i(4, 4)), "距离 2 右下")
	assertions.assert_false(ring.has(Vector2i(3, 3)), "自身不应在环形")
	assertions.assert_false(ring.has(Vector2i(2, 3)), "距离 1 不应在距 2 环形")

	# 角落 (0,0)，距=1 环形
	var ring_1 = rs.get_ring_range({"position": Vector2i(0, 0)}, 1)
	assertions.assert_eq(ring_1.size(), 2, "角落距 1 环形应 2 格")

	rs.free()
```

- [ ] **Step 2: 注册 + 确认失败**

- [ ] **Step 3: 实现 get_ring_range**

在 `tactical_range_system.gd` 追加：

```gdscript
# 环形范围：以 unit.position 为中心，曼哈顿距离 == distance 的所有格。
# 棋盘边界裁剪。
func get_ring_range(unit: Dictionary, distance: int, terrain_grid: Array = []) -> Array:
	var src: Vector2i = unit.get("position", Vector2i(0, 0))
	var dims := _grid_dims(terrain_grid)
	var cols: int = dims.x
	var rows: int = dims.y
	var result: Array = []
	for r in range(rows):
		for c in range(cols):
			var p := Vector2i(c, r)
			if p == src:
				continue
			var dist := abs(p.x - src.x) + abs(p.y - src.y)
			if dist == distance:
				result.append(p)
	return result
```

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/tactical_range_system.gd tests/test_tactical_range_ring.gd tests/run_tests.gd
git commit -m "feat: add ring range algorithm"
```

---

### Task 8: 4门新武学数据 + hero_yun 更新

**Files:**
- Modify: `data/martial_arts.json`
- Modify: `data/actors.json`
- Modify: `tests/test_data_loader.gd:1-25`
- Create: `tests/test_new_martial_arts_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写新武学数据测试（先失败）**

`tests/test_new_martial_arts_data.gd`：

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()

	# 回风拂柳
	var w = repo.get_martial_art("sword_willow_sweep")
	assertions.assert_eq(str(w.get("name", "")), "回风拂柳", "应加载回风拂柳")
	var wt = w.get("tactical", {})
	assertions.assert_eq(str(wt.get("range_shape", "")), "fan", "回风拂柳 shape 应为 fan")
	assertions.assert_eq(int(wt.get("mp_cost", 0)), 6, "回风拂柳 mp_cost = 6")
	assertions.assert_eq(int(wt.get("damage_bonus", 0)), 5, "回风拂柳 damage_bonus = 5")
	assertions.assert_eq(int(wt.get("range", 0)), 2, "回风拂柳 range = 2")
	assertions.assert_eq(int(w.get("proficiency_thresholds", [10,25,50])[0]), 10, "回风拂柳首阈值 = 10")

	# 八方风雨
	var s = repo.get_martial_art("sword_all_directions")
	assertions.assert_eq(str(s.get("name", "")), "八方风雨", "应加载八方风雨")
	assertions.assert_eq(str(s.get("tactical", {}).get("range_shape", "")), "surround", "八方风雨 shape = surround")
	assertions.assert_eq(int(s.get("tactical", {}).get("mp_cost", 0)), 10, "八方风雨 mp_cost = 10")

	# 长虹贯日
	var p = repo.get_martial_art("sword_rainbow_pierce")
	assertions.assert_eq(str(p.get("name", "")), "长虹贯日", "应加载长虹贯日")
	assertions.assert_eq(str(p.get("tactical", {}).get("range_shape", "")), "pierce", "长虹贯日 shape = pierce")
	assertions.assert_eq(int(p.get("tactical", {}).get("range", 0)), 3, "长虹贯日 range = 3")

	# 剑气环身
	var r = repo.get_martial_art("sword_ring_aura")
	assertions.assert_eq(str(r.get("name", "")), "剑气环身", "应加载剑气环身")
	assertions.assert_eq(str(r.get("tactical", {}).get("range_shape", "")), "ring", "剑气环身 shape = ring")
	assertions.assert_eq(int(r.get("tactical", {}).get("mp_cost", 0)), 8, "剑气环身 mp_cost = 8")

	# hero_yun 应学会全部 4 门新武学
	var hero = repo.get_actor("hero_yun")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_willow_sweep"), "主角应学会回风拂柳")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_all_directions"), "主角应学会八方风雨")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_rainbow_pierce"), "主角应学会长虹贯日")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_ring_aura"), "主角应学会剑气环身")

	repo.free()
```

- [ ] **Step 2: 注册 run_tests.gd**

```gdscript
const TestNewMartialArtsDataScript = preload("res://tests/test_new_martial_arts_data.gd")
```

```gdscript
		TestNewMartialArtsDataScript.new(),
```

- [ ] **Step 3: 跑确认失败**

Expected: `get_martial_art("sword_willow_sweep")` 返回 `{}`，断言失败。

- [ ] **Step 4: 写入 4 门新武学到 martial_arts.json**

在 `data/martial_arts.json` 的 `rough_fist` 条目之前插入：

```json
  {
    "id": "sword_willow_sweep",
    "name": "回风拂柳",
    "school": "江湖",
    "power": 14,
    "cost": 6,
    "description": "剑势如风，横扫面前锥形之敌。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [10, 25, 50],
    "shape": "fan",
    "tactical": {
      "damage_bonus": 5,
      "range": 2,
      "range_shape": "fan",
      "mp_cost": 6
    }
  },
  {
    "id": "sword_all_directions",
    "name": "八方风雨",
    "school": "江湖",
    "power": 16,
    "cost": 10,
    "description": "剑光四射，周身之敌无一幸免。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [10, 25, 50],
    "shape": "surround",
    "tactical": {
      "damage_bonus": 3,
      "range": 1,
      "range_shape": "surround",
      "mp_cost": 10
    }
  },
  {
    "id": "sword_rainbow_pierce",
    "name": "长虹贯日",
    "school": "江湖",
    "power": 13,
    "cost": 7,
    "description": "剑气一线穿云，直线上敌皆受创。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [12, 30, 60],
    "shape": "pierce",
    "tactical": {
      "damage_bonus": 4,
      "range": 3,
      "range_shape": "pierce",
      "mp_cost": 7
    }
  },
  {
    "id": "sword_ring_aura",
    "name": "剑气环身",
    "school": "江湖",
    "power": 15,
    "cost": 8,
    "description": "内力外放成环，周身环形之敌尽遭波及。",
    "proficiency_reward": 1,
    "proficiency_thresholds": [12, 30, 60],
    "shape": "ring",
    "tactical": {
      "damage_bonus": 4,
      "range": 2,
      "range_shape": "ring",
      "mp_cost": 8
    }
  },
```

- [ ] **Step 5: 更新 actors.json hero_yun.martial_arts**

```json
"martial_arts": ["basic_sword", "straight_sword_thrust", "sword_aura_swirl", "sword_willow_sweep", "sword_all_directions", "sword_rainbow_pierce", "sword_ring_aura"],
```

- [ ] **Step 6: 更新 test_data_loader.gd 角色数量断言**

当前 `assert_eq(content.get("actors", []).size(), 6)` 不变（actors.json 不新增角色），但需追加武学数量断言：

```gdscript
	assertions.assert_eq(content.get("martial_arts", []).size(), 8, "应加载 8 门武学（含 4 门新）")
```

- [ ] **Step 7: 跑测试确认通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 8: 提交**

```bash
git add data/martial_arts.json data/actors.json tests/test_new_martial_arts_data.gd tests/test_data_loader.gd tests/run_tests.gd
git commit -m "data: add 4 new martial arts with fan/surround/pierce/ring shapes"
```

---

### Task 9: TacticalCombatSystem 扩展 shape 白名单 + resolve_action 新形状结算

**Files:**
- Modify: `scripts/systems/tactical_combat_system.gd`

- [ ] **Step 1: 写扩展测试到 test_tactical_combat_system.gd**

在 `test_tactical_combat_system.gd` 的 `run()` 末尾、`repository.free()` 之前追加：

```gdscript
	# 新形状武学可通过 resolve_action 结算（走 _resolve_generic_skill）。
	# 回风拂柳 → shape=fan，单格命中。
	var fan_battle = system.create_battle(state, _sample_context(), repository)
	fan_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	fan_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	var fan_mp_before = fan_battle.get_unit("hero").mp
	var fan_result = system.resolve_action(fan_battle, "hero", "sword_willow_sweep", [Vector2i(5, 2)])
	assertions.assert_true(bool(fan_result.get("success", false)), "回风拂柳应释放成功")
	assertions.assert_eq(fan_battle.get_unit("hero").mp, fan_mp_before - 6, "回风拂柳应扣 6 点内力")
	assertions.assert_eq(fan_battle.get_unit("bandit").hp, 60 - (18 + 5 - 4), "回风拂柳伤害 = atk + bonus - def")

	# 八方风雨 → shape=surround，多格命中。
	var sur_battle = system.create_battle(state, _sample_context(), repository)
	sur_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	sur_battle.get_unit("bandit").cell = {"q": 4, "r": 3}
	sur_battle.get_unit("lackey").cell = {"q": 5, "r": 2}
	var sur_mp_before = sur_battle.get_unit("hero").mp
	var sur_targets: Array = [Vector2i(4, 3), Vector2i(5, 2)]
	var sur_result = system.resolve_action(sur_battle, "hero", "sword_all_directions", sur_targets)
	assertions.assert_true(bool(sur_result.get("success", false)), "八方风雨应释放成功")
	assertions.assert_eq(sur_battle.get_unit("hero").mp, sur_mp_before - 10, "八方风雨应扣 10 内力")

	# 长虹贯日 → shape=pierce，穿透多目标。
	var pierce_battle = system.create_battle(state, _sample_context(), repository)
	pierce_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	pierce_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	pierce_battle.get_unit("lackey").cell = {"q": 6, "r": 2}
	var pierce_mp_before = pierce_battle.get_unit("hero").mp
	var pierce_targets: Array = [Vector2i(5, 2), Vector2i(6, 2)]
	var pierce_result = system.resolve_action(pierce_battle, "hero", "sword_rainbow_pierce", pierce_targets)
	assertions.assert_true(bool(pierce_result.get("success", false)), "长虹贯日应穿透两目标")

	# 剑气环身 → shape=ring，环形命中。
	var ring_battle = system.create_battle(state, _sample_context(), repository)
	ring_battle.get_unit("hero").cell = {"q": 3, "r": 3}
	ring_battle.get_unit("bandit").cell = {"q": 5, "r": 3}
	var ring_mp_before = ring_battle.get_unit("hero").mp
	var ring_result = system.resolve_action(ring_battle, "hero", "sword_ring_aura", [Vector2i(5, 3)])
	assertions.assert_true(bool(ring_result.get("success", false)), "剑气环身应释放成功")
	assertions.assert_eq(ring_battle.get_unit("hero").mp, ring_mp_before - 8, "剑气环身应扣 8 内力")
```

- [ ] **Step 2: 跑测试确认失败**

Expected: `resolve_action` 走到 `_resolve_generic_skill` 但 repo 能找到数据，`_get_tactical_martial_art` 的白名单可能还没开。关键点是现有代码 `_resolve_generic_skill` 读 `skill_data.get("tactical", {})` 不依赖 `_get_tactical_martial_art`，所以核心路径已通。测试应在后面部分断言失败（`get_attackable_units_for_martial_art`）。

- [ ] **Step 3: 扩展 _get_tactical_martial_art 白名单**

在 `tactical_combat_system.gd` 的 `_get_tactical_martial_art` 中，将白名单行：

```gdscript
	if not ["diamond", "line"].has(martial_art.tactical_range_shape):
		return null
```

替换为：

```gdscript
	if not ["diamond", "line", "fan", "surround", "pierce", "ring", "target_cross_1"].has(martial_art.tactical_range_shape):
		return null
```

- [ ] **Step 4: 跑测试确认通过**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd
git commit -m "feat: whitelist new shapes in tactical combat system + resolve_action tests"
```

---

### Task 10: resolve_action 成功后调用 ProficiencySystem.add_use

**Files:**
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `tests/test_tactical_combat_system.gd`

- [ ] **Step 1: 写失败测试（熟练度未累加）**

在 `test_tactical_combat_system.gd` 的 `run()` 末尾追加：

```gdscript
	# 熟练度累加：用同一 battle 连续施展同一武学应累加计数。
	var prof_battle = system.create_battle(state, _sample_context(), repository)
	prof_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	prof_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	# 首次使用
	system.resolve_action(prof_battle, "hero", "sword_willow_sweep", [Vector2i(5, 2)])
	var count_1 = state.get_martial_proficiency("sword_willow_sweep")
	assertions.assert_eq(count_1, 1, "首次使用回风拂柳后熟练度应 = 1")
	# 二次使用
	system.resolve_action(prof_battle, "hero", "sword_willow_sweep", [Vector2i(5, 2)])
	var count_2 = state.get_martial_proficiency("sword_willow_sweep")
	assertions.assert_eq(count_2, 2, "二次使用回风拂柳后熟练度应 = 2")
```

- [ ] **Step 2: 跑确认失败**

Expected: `熟练度应 = 1` 断言失败（当前 resolve_action 结算后不调 add_use）。

- [ ] **Step 3: 在 resolve_action 接入熟练度**

在 `tactical_combat_system.gd` 顶部加 preload：

```gdscript
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
```

修改 `resolve_action` 的结尾部分。当前代码（约第 170 行）：

```gdscript
	if bool(result.get("success", false)):
		_emit_action_resolved(unit_id, action_id, target_cells)
	return result
```

替换为：

```gdscript
	if bool(result.get("success", false)):
		_emit_action_resolved(unit_id, action_id, target_cells)
		# 熟练度累加：普攻不计数
		if action_id != "attack":
			_proficiency_system.add_use(_proficiency_map, action_id)
	return result
```

在类顶部加成员变量和初始化/注入方法。在 `set_repository` 函数之后追加：

```gdscript
var _proficiency_system = null
var _proficiency_map: Dictionary = {}

func set_proficiency(proficiency_system, proficiency_map: Dictionary) -> void:
	_proficiency_system = proficiency_system
	_proficiency_map = proficiency_map
```

然后在 `resolve_action` 中 `_proficiency_system` 可用时才调用：

```gdscript
	if bool(result.get("success", false)):
		_emit_action_resolved(unit_id, action_id, target_cells)
		if action_id != "attack" and _proficiency_system != null:
			_proficiency_system.add_use(_proficiency_map, action_id)
	return result
```

- [ ] **Step 4: 更新 test_tactical_combat_system.gd**

在 `system.set_repository(repository)` 之后加：

```gdscript
	const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
	var prof_sys = ProficiencySystemScript.new()
	system.set_proficiency(prof_sys, state.martial_proficiency)
```

- [ ] **Step 5: 跑测试确认通过**

- [ ] **Step 6: 提交**

```bash
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd
git commit -m "feat: accumulate proficiency use count on martial art resolution"
```

---

### Task 11: 熟练度加值接入伤害计算

**Files:**
- Modify: `scripts/systems/tactical_combat_system.gd`
- Modify: `tests/test_tactical_combat_system.gd`

- [ ] **Step 1: 写失败测试（熟练度未影响伤害）**

在 `test_tactical_combat_system.gd` 末尾追加：

```gdscript
	# 熟练度加值验伤：手动设基本剑法 25 次 → 跨过 [10, 25] 两阈值 → bonus = +4
	var bonus_battle = system.create_battle(state, _sample_context(), repository)
	bonus_battle.get_unit("hero").cell = {"q": 4, "r": 2}
	bonus_battle.get_unit("bandit").cell = {"q": 5, "r": 2}
	bonus_battle.get_unit("bandit").hp = 60
	state.martial_proficiency["basic_sword"] = 25
	system.resolve_action(bonus_battle, "hero", "basic_sword", [Vector2i(5, 2)])
	# 基础剑法：atk=18, tactical.damage_bonus=6, def=4 → 18+6-4=20
	# 熟练度 bonus = Lv.2 × 2 = +4 → 总伤害 = 24
	assertions.assert_eq(bonus_battle.get_unit("bandit").hp, 60 - 24, "熟练度 Lv.2 时基础剑法伤害应为 24")
```

- [ ] **Step 2: 跑确认失败**

Expected: 伤害仍为 20（60-40=20），断言失败。

- [ ] **Step 3: 修改 _resolve_generic_skill 接入熟练度加值**

在 `_resolve_generic_skill` 中，`damage_bonus` 计算后追加熟练度加值。

当前代码：

```gdscript
	var damage_bonus: int = int(tactical.get("damage_bonus", 0))
```

替换为：

```gdscript
	var damage_bonus: int = int(tactical.get("damage_bonus", 0))
	if _proficiency_system != null and not _proficiency_map.is_empty():
		var thresholds: Array = skill_data.get("proficiency_thresholds", [])
		if typeof(thresholds) == TYPE_ARRAY and not thresholds.is_empty():
			damage_bonus += _proficiency_system.get_bonus(int(_proficiency_map.get(action_id, 0)), thresholds)
```

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_combat_system.gd
git commit -m "feat: integrate proficiency bonus into martial art damage calculation"
```

---

### Task 12: battle_screen 技能菜单显示熟练度等级

**Files:**
- Modify: `scripts/scenes/battle_screen.gd:899-930`

- [ ] **Step 1: 加 preload 和初始化**

在 `battle_screen.gd` 顶部 extends 行之后加 preload：

```gdscript
const ProficiencySystemScript = preload("res://scripts/systems/proficiency_system.gd")
```

在类成员变量区追加：

```gdscript
var _proficiency_system = null
```

在 `_ready()` 末尾加初始化：

```gdscript
	_proficiency_system = ProficiencySystemScript.new()
```

- [ ] **Step 2: 修改 _open_skill_menu() 的 menu item 文字**

当前 `_open_skill_menu()` 中 `menu.add_item(...)` 处（约行 917-922）：

```gdscript
		if not _can_current_unit_use_tactical_art(unit, sid_s):
			menu.add_item("%s（内力不足）" % str(data.get("name", sid_s)))
			menu.set_item_disabled(menu.get_item_count() - 1, true)
		else:
			menu.add_item(str(data.get("name", sid_s)))
```

改为：

```gdscript
		var skill_name: String = str(data.get("name", sid_s))
		var thresholds: Array = data.get("proficiency_thresholds", [])
		var use_count := int(GameState.martial_proficiency.get(sid_s, 0))
		var level := 0
		if _proficiency_system != null:
			level = _proficiency_system.get_level(use_count, thresholds)
		var label := skill_name
		if level > 0:
			label = "%s Lv.%d" % [skill_name, level]
		if not _can_current_unit_use_tactical_art(unit, sid_s):
			menu.add_item("%s（内力不足）" % label)
			menu.set_item_disabled(menu.get_item_count() - 1, true)
		else:
			menu.add_item(label)
```

- [ ] **Step 3: 跑全量回归**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过。

- [ ] **Step 4: 提交**

```bash
git add scripts/scenes/battle_screen.gd
git commit -m "feat: display proficiency level on skill menu in battle screen"
```

---

### Task 13: 全量回归验证

- [ ] **Step 1: 跑全量测试**

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: `测试通过：N 个测试套件`，无失败断言。

- [ ] **Step 2: 如有失败，针对性修复**

---

## 最终验收命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 输出 `测试通过：` 且无新增失败断言。

---

## Self-Review（已执行）

1. **Spec 覆盖检查**
- 4种新形状（fan/surround/pierce/ring）：Task 4-7 覆盖
- 4门新武学：Task 8 覆盖
- 熟练度计数/等级/加值：Task 3 覆盖
- resolve_action 接入熟练度：Task 10-11 覆盖
- UI 显示 Lv.X：Task 12 覆盖
- 回归验证：Task 13 覆盖

2. **占位符扫描**
- 未使用 TBD/TODO/implement later

3. **类型一致性**
- `martial_proficiency` 沿用现有 game_state 字段名
- 阈值字段名 `proficiency_thresholds` 统一
- 范围函数命名：`get_fan_range`、`get_surround_range`、`get_pierce_range`、`get_ring_range`
- 伤害公式统一为 `atk + tactical.damage_bonus + proficiency_bonus - def`
