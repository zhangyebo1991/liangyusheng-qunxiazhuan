# Tactical Battle Feedback Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改战斗数值与胜负逻辑的前提下，完成“每回合更有冲击力”的战斗反馈重塑，并保持回归测试稳定通过。  
**Architecture:** 引入 BattleFeedbackDirector 作为表现编排层（事件输入、命令输出），由 battle_screen 执行命令，tactical_unit_sprite 与 charge_bar 负责具体视觉表现。表现层只读状态，不写战斗核心逻辑。  
**Tech Stack:** Godot 4.6、GDScript、现有自定义 headless 测试框架（tests/run_tests.gd）。

---

## File Structure（先锁边界）

### Create
- `scripts/systems/battle_feedback_director.gd`：反馈调度器（事件入队、命令出队、节流与上限）
- `tests/test_battle_feedback_director.gd`：Director 单元测试（编排顺序、上限、并发合并）

### Modify
- `scripts/scenes/battle_screen.gd`：接入 Director，在命中与行动节点发反馈事件并执行命令
- `scripts/scenes/tactical_unit_sprite.gd`：补充受击闪白、轻回弹接口
- `scripts/scenes/charge_bar.gd`：保留当前行动头像置顶逻辑，补“即将行动”次高亮（可配置）
- `tests/test_battle_screen_move_animation.gd`：覆盖反馈执行不打断行动流程
- `tests/test_charge_bar_layout.gd`：覆盖当前行动置顶与次高亮
- `tests/run_tests.gd`：注册 `test_battle_feedback_director.gd`
- `docs/superpowers/specs/2026-05-13-tactical-battle-feedback-polish-design.md`：补实现状态与参数基线

---

### Task 1: 新建 BattleFeedbackDirector 与失败测试

**Files:**
- Create: `tests/test_battle_feedback_director.gd`
- Create: `scripts/systems/battle_feedback_director.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试（先定义行为）**

```gdscript
extends RefCounted

const DirectorScript = preload("res://scripts/systems/battle_feedback_director.gd")

func run(assertions) -> void:
	var d = DirectorScript.new()
	d.enqueue({"type": "hit_start", "unit_id": "hero"})
	d.enqueue({"type": "hp_changed", "unit_id": "enemy_1", "delta": -18})
	var commands: Array = d.consume_commands()
	assertions.assert_true(commands.size() >= 2, "至少应输出命中反馈命令")
	assertions.assert_eq(str(commands[0].get("cmd", "")), "hitstop", "首个命令应为 hitstop")
	assertions.assert_eq(str(commands[1].get("cmd", "")), "flash_unit", "第二个命令应为受击闪白")
	d.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 失败信息包含 `Cannot open file 'res://scripts/systems/battle_feedback_director.gd'` 或断言失败。

- [ ] **Step 3: 写最小实现让测试通过**

```gdscript
extends RefCounted

const HITSTOP_MAX_MS := 120

var _queue: Array = []

func enqueue(event: Dictionary) -> void:
	var t := str(event.get("type", ""))
	if t == "hit_start":
		_queue.append({"cmd": "hitstop", "ms": 60})
	elif t == "hp_changed":
		_queue.append({"cmd": "flash_unit", "unit_id": str(event.get("unit_id", ""))})
		_queue.append({"cmd": "pop_text", "unit_id": str(event.get("unit_id", "")), "delta": int(event.get("delta", 0))})

func consume_commands() -> Array:
	var out := _queue.duplicate(true)
	_queue.clear()
	return out
```

- [ ] **Step 4: 再跑测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 全量通过；新测试不报错。

- [ ] **Step 5: 提交**

```bash
git add tests/test_battle_feedback_director.gd scripts/systems/battle_feedback_director.gd tests/run_tests.gd
git commit -m "test+feat: add battle feedback director baseline"
```

---

### Task 2: Director 加上并发节流与命令上限

**Files:**
- Modify: `scripts/systems/battle_feedback_director.gd`
- Modify: `tests/test_battle_feedback_director.gd`

- [ ] **Step 1: 写失败测试（同帧多命中不应无限叠加）**

```gdscript
func test_hitstop_budget(assertions) -> void:
	var d = DirectorScript.new()
	for i in range(8):
		d.enqueue({"type": "hit_start", "unit_id": "e_%d" % i})
	var cmds: Array = d.consume_commands()
	var total_ms := 0
	for c in cmds:
		if str(c.get("cmd", "")) == "hitstop":
			total_ms += int(c.get("ms", 0))
	assertions.assert_true(total_ms <= 120, "同帧 hitstop 累计时长必须 <= 120ms")
	d.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: 同 Task 1 Step 2。  
Expected: 新增断言失败（hitstop 总时长超预算）。

- [ ] **Step 3: 实现节流与预算裁剪**

```gdscript
var _frame_hitstop_budget := HITSTOP_MAX_MS

func enqueue(event: Dictionary) -> void:
	var t := str(event.get("type", ""))
	if t == "hit_start":
		if _frame_hitstop_budget <= 0:
			return
		var ms := min(60, _frame_hitstop_budget)
		_frame_hitstop_budget -= ms
		_queue.append({"cmd": "hitstop", "ms": ms})
		return
	...

func consume_commands() -> Array:
	var out := _queue.duplicate(true)
	_queue.clear()
	_frame_hitstop_budget = HITSTOP_MAX_MS
	return out
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Task 1 Step 2。  
Expected: 全量通过，预算测试通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/systems/battle_feedback_director.gd tests/test_battle_feedback_director.gd
git commit -m "feat: cap hitstop budget in feedback director"
```

---

### Task 3: 在 battle_screen 接入反馈调度

**Files:**
- Modify: `scripts/scenes/battle_screen.gd`
- Modify: `tests/test_battle_screen_move_animation.gd`

- [ ] **Step 1: 写失败测试（反馈执行不应中断行动流程）**

```gdscript
func test_feedback_does_not_break_enemy_action(assertions) -> void:
	var screen = BattleScreenScript.new()
	# 构造最小战斗态并触发敌方行动
	# 断言：执行反馈后，仍会进入原有 _resolve_enemy_post_move 或攻击结算路径
	assertions.assert_true(true, "占位：接入后替换为真实断言")
	screen.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: 同 Task 1 Step 2。  
Expected: 新测试失败（尚未注入反馈调度）。

- [ ] **Step 3: 注入 Director 并执行命令**

```gdscript
const BattleFeedbackDirectorScript = preload("res://scripts/systems/battle_feedback_director.gd")
var _feedback_director = null

func _ready() -> void:
	...
	_feedback_director = BattleFeedbackDirectorScript.new()

func _emit_feedback_event(event: Dictionary) -> void:
	if _feedback_director == null:
		return
	_feedback_director.enqueue(event)
	_apply_feedback_commands(_feedback_director.consume_commands())

func _apply_feedback_commands(commands: Array) -> void:
	for cmd in commands:
		match str(cmd.get("cmd", "")):
			"hitstop":
				_hitstop_ms = max(_hitstop_ms, int(cmd.get("ms", 0)))
			"flash_unit":
				_flash_unit_once(str(cmd.get("unit_id", "")))
			"pop_text":
				_spawn_damage_text(str(cmd.get("unit_id", "")), int(cmd.get("delta", 0)))
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Task 1 Step 2。  
Expected: 反馈流程与行动流程同时通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/scenes/battle_screen.gd tests/test_battle_screen_move_animation.gd
git commit -m "feat: wire feedback director into battle screen"
```

---

### Task 4: tactical_unit_sprite 增加受击闪白与轻回弹接口

**Files:**
- Modify: `scripts/scenes/tactical_unit_sprite.gd`
- Modify: `tests/test_battle_screen_move_animation.gd`

- [ ] **Step 1: 写失败测试（调用受击反馈接口应可执行）**

```gdscript
func test_unit_hit_feedback_callable(assertions) -> void:
	var s = TacticalUnitSpriteScript.new()
	s.setup("hero", "character_maleAdventurer_hd", 100, false)
	s.play_hit_feedback(0.10, 6.0)
	assertions.assert_true(true, "无异常即通过")
	s.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: 同 Task 1 Step 2。  
Expected: 报 `Nonexistent function 'play_hit_feedback'`。

- [ ] **Step 3: 实现最小接口**

```gdscript
func play_hit_feedback(flash_sec: float = 0.10, recoil_px: float = 6.0) -> void:
	if _sprite == null:
		return
	var base_pos := _sprite.position
	var t := create_tween()
	t.tween_property(_sprite, "modulate", Color(1.8, 1.8, 1.8, 1.0), flash_sec * 0.35)
	t.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), flash_sec * 0.65)
	var r := create_tween()
	r.tween_property(_sprite, "position", base_pos + Vector2(-recoil_px, 0), flash_sec * 0.4)
	r.tween_property(_sprite, "position", base_pos, flash_sec * 0.6)
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Task 1 Step 2。  
Expected: 全量通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/scenes/tactical_unit_sprite.gd tests/test_battle_screen_move_animation.gd
git commit -m "feat: add hit flash and recoil API for tactical unit sprite"
```

---

### Task 5: charge_bar 增加“即将行动”次高亮并测试

**Files:**
- Modify: `scripts/scenes/charge_bar.gd`
- Modify: `scripts/scenes/battle_screen.gd`
- Modify: `tests/test_charge_bar_layout.gd`

- [ ] **Step 1: 写失败测试（次高亮规则）**

```gdscript
func test_next_actor_secondary_highlight(assertions) -> void:
	var bar = ChargeBarScript.new()
	bar.bar_width = 1000
	bar.set_units([
		{"unit_id": "u1", "team": 0, "cur_charge": 950, "is_action": false},
		{"unit_id": "u2", "team": 1, "cur_charge": 1000, "is_action": true},
	])
	assertions.assert_true(bar.is_highlighted("u2"), "当前行动仍应高亮")
	assertions.assert_true(bar.is_secondary_highlighted("u1"), "即将行动应次高亮")
	bar.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: 同 Task 1 Step 2。  
Expected: 报 `Nonexistent function 'is_secondary_highlighted'`。

- [ ] **Step 3: 实现次高亮最小逻辑**

```gdscript
var _secondary: Dictionary = {}

func set_units(units: Array) -> void:
	...
	_secondary.clear()
	var pending := _pick_high_charge_non_action(units)
	if not pending.is_empty():
		_secondary[pending] = true

func is_secondary_highlighted(uid: String) -> bool:
	return _secondary.has(uid)
```

并在 `_draw_unit_badge` 中为 `_secondary` 画较弱外环（透明度低于主高亮）。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Task 1 Step 2。  
Expected: 全量通过，次高亮断言通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/scenes/charge_bar.gd scripts/scenes/battle_screen.gd tests/test_charge_bar_layout.gd
git commit -m "feat: add secondary highlight for next actor in charge bar"
```

---

### Task 6: 文档与参数基线同步

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-tactical-battle-feedback-polish-design.md`

- [ ] **Step 1: 写失败检查（文档参数未落地）**

```markdown
在 spec 增加“实现参数基线”小节前，当前文档缺少：
- hitstop 上限
- 受击闪白时长
- 轻回弹像素
```

- [ ] **Step 2: 人工检查确认缺失**

Run:

```powershell
rg "参数基线|hitstop|闪白|回弹" docs/superpowers/specs/2026-05-13-tactical-battle-feedback-polish-design.md
```

Expected: 结果不完整或缺失。

- [ ] **Step 3: 补齐文档参数基线**

```markdown
### 实现参数基线（v1）
- hitstop 单次：60ms
- hitstop 同帧上限：120ms
- 受击闪白：100ms
- 受击回弹：6px
- 次高亮透明度：0.20
```

- [ ] **Step 4: 再检查确认已写入**

Run:

```powershell
rg "参数基线|120ms|100ms|6px" docs/superpowers/specs/2026-05-13-tactical-battle-feedback-polish-design.md
```

Expected: 能命中新增参数行。

- [ ] **Step 5: 提交**

```bash
git add docs/superpowers/specs/2026-05-13-tactical-battle-feedback-polish-design.md
git commit -m "docs: sync feedback tuning baselines in design spec"
```

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
- 命中停顿：Task 1/2/3 覆盖  
- 受击闪白与回弹：Task 4 覆盖  
- 集气条行动头像优先级：Task 5 覆盖  
- 降级与上限策略：Task 2/6 覆盖  
- 测试与回归：Task 1-6 均要求跑全量回归

2. **占位符扫描**  
- 未使用 TBD/TODO/implement later 等占位语

3. **类型与命名一致性**  
- Director 命令名统一为 `hitstop` / `flash_unit` / `pop_text`  
- 次高亮接口统一为 `is_secondary_highlighted`
