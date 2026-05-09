# 山脚村镇任务延伸切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩展当前山道探索闭环，新增山脚村镇地图、双向地图切换和“送信到客栈”任务闭环。

**Architecture:** 沿用现有“领域逻辑、系统流程、场景表现”分层。地图对象继续由 `data/maps.json` 驱动，新增 `MapTransitionSystem` 解析出口目标，新增 `map_screen_base.gd` 复用地图装配、玩家、摄像机、对象生成、交互和存档入口。山道和村镇场景只保留各自的地形与任务分支。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划实现 `docs/superpowers/specs/2026-05-09-foot-village-quest-slice-design.md`。范围只包含山道和山脚村镇双向切换、村镇主街、3 个村镇内容对象、送信任务、线索文本和存档恢复。不实现商店、背包界面、装备、室内地图、新战斗系统或第三张可进入地图。

本计划不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。

验证命令优先使用项目本地 Godot：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本地 Godot 不存在，先运行：

```powershell
Get-Command godot -ErrorAction SilentlyContinue
```

有 `godot` 命令时改用：

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```

## 文件结构

```text
data/maps.json                                # 扩展山道出口，新增山脚村镇地图、出生点和出口
data/actors.json                              # 增加客栈掌柜和村口脚夫
data/dialogues.json                           # 增加村口、掌柜、告示牌和线索对白
data/quests.json                              # 增加送信到客栈任务
docs/godot-project-structure.md               # 更新第二地图切片说明
README.md                                     # 更新当前目标说明
scenes/foot_village.tscn                      # 新增山脚村镇场景
scripts/core/game_state.gd                    # 增加当前地图切换和地图场景路径帮助方法
scripts/scenes/foot_village_screen.gd         # 山脚村镇场景特有地形和任务流程
scripts/scenes/main_menu_screen.gd            # 增加继续游戏入口
scripts/scenes/map_interactable.gd            # 支持 exit 和 notice 交互展示
scripts/scenes/map_screen_base.gd             # 通用地图装配、交互、存档和地图切换
scripts/scenes/mountain_pass_screen.gd        # 继承通用地图基础，加入山道出口
scripts/systems/map_transition_system.gd      # 出口目标地图和出生点解析
tests/run_tests.gd                            # 接入新增测试套件
tests/test_data_loader.gd                     # 更新角色数量期望
tests/test_map_data.gd                        # 覆盖两张地图、出生点和出口数据
tests/test_map_transition_system.gd           # 覆盖地图切换解析错误和回退
tests/test_save_map_state.gd                  # 覆盖村镇地图状态和线索 flag 存档
```

---

### Task 1: 扩展地图和内容数据

**Files:**
- Modify: `tests/test_data_loader.gd`
- Modify: `tests/test_map_data.gd`
- Modify: `data/maps.json`
- Modify: `data/actors.json`
- Modify: `data/dialogues.json`
- Modify: `data/quests.json`

- [ ] **Step 1: 写失败测试 `tests/test_data_loader.gd`**

Replace `tests/test_data_loader.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("actors", []).size(), 5, "应加载 5 个示例角色")
	assertions.assert_eq(repository.get_actor("hero_yun").get("name", ""), "云游少侠", "应按编号读取角色")
	assertions.assert_eq(repository.get_actor("innkeeper_lu").get("name", ""), "陆掌柜", "应读取客栈掌柜角色")
	assertions.assert_eq(repository.get_actor("porter_chen").get("name", ""), "陈脚夫", "应读取村口脚夫角色")
	assertions.assert_eq(repository.get_martial_art("basic_sword").get("name", ""), "基础剑法", "应按编号读取武学")
	assertions.assert_eq(repository.get_dialogue("intro_meet_master").get("title", ""), "初入江湖", "应按编号读取对话")
	assertions.assert_eq(repository.get_actor("missing_id"), {}, "缺失角色编号应返回空字典")
	repository.free()
```

- [ ] **Step 2: 写失败测试 `tests/test_map_data.gd`**

Replace `tests/test_map_data.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 2, "应加载 2 张示例地图")

	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(mountain.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_true(mountain.get("spawn_points", {}).has("return_from_village"), "山道应包含村镇返回出生点")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("target_map_id", ""), "foot_village", "山道出口应指向山脚村镇")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("name", ""), "山脚村镇", "应按编号读取山脚村镇")
	assertions.assert_eq(village.get("spawn_position", {}).get("x", 0), 120, "村镇默认出生点横坐标应正确")
	assertions.assert_true(village.get("spawn_points", {}).has("village_gate"), "村镇应包含村口出生点")
	assertions.assert_eq(_find_object(village, "npc_innkeeper_lu").get("actor_id", ""), "innkeeper_lu", "村镇应配置客栈掌柜")
	assertions.assert_eq(_find_object(village, "npc_porter_chen").get("actor_id", ""), "porter_chen", "村镇应配置村口脚夫")
	assertions.assert_eq(_find_object(village, "notice_foot_village").get("type", ""), "notice", "村镇应配置告示牌")
	assertions.assert_eq(_find_object(village, "exit_to_mountain_pass").get("target_map_id", ""), "mountain_pass", "村镇应能返回山道")
	assertions.assert_eq(_find_object(village, "exit_to_open_road").get("locked_message", ""), "前路尚未开放。", "未开放出口应有提示")

	assertions.assert_eq(repository.get_quest("quest_deliver_letter").get("title", ""), "送信到客栈", "应读取送信任务")
	assertions.assert_eq(repository.get_dialogue("deliver_letter_complete").get("title", ""), "书信送达", "应读取送信完成对白")
	assertions.assert_eq(repository.get_map("missing_map"), {}, "缺失地图编号应返回空字典")

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
```

- [ ] **Step 3: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`。失败原因包含“应加载 5 个示例角色”或“应加载 2 张示例地图”。

- [ ] **Step 4: 更新 `data/maps.json`**

Replace `data/maps.json` with:

```json
[
  {
    "id": "mountain_pass",
    "name": "山道",
    "spawn_position": {"x": 160, "y": 320},
    "spawn_points": {
      "start": {"x": 160, "y": 320},
      "return_from_village": {"x": 1110, "y": 320}
    },
    "objects": [
      {
        "id": "npc_qingshanke",
        "type": "npc",
        "name": "青衫客",
        "actor_id": "qingshanke",
        "position": {"x": 360, "y": 280},
        "radius": 72,
        "dialogue_id": "mountain_pass_intro",
        "quest_id": "quest_mountain_trial"
      },
      {
        "id": "enemy_bandit_gate",
        "type": "battle_trigger",
        "name": "山道强人",
        "actor_id": "bandit_01",
        "position": {"x": 720, "y": 260},
        "radius": 56,
        "quest_id": "quest_mountain_trial"
      },
      {
        "id": "exit_to_foot_village",
        "type": "exit",
        "name": "山脚村镇",
        "position": {"x": 1160, "y": 320},
        "radius": 72,
        "target_map_id": "foot_village",
        "target_spawn_id": "village_gate",
        "locked_message": "前路尚未开放。"
      }
    ]
  },
  {
    "id": "foot_village",
    "name": "山脚村镇",
    "spawn_position": {"x": 120, "y": 360},
    "spawn_points": {
      "village_gate": {"x": 120, "y": 360},
      "return_from_mountain": {"x": 120, "y": 360},
      "main_street": {"x": 640, "y": 340}
    },
    "objects": [
      {
        "id": "exit_to_mountain_pass",
        "type": "exit",
        "name": "山道",
        "position": {"x": 64, "y": 360},
        "radius": 72,
        "target_map_id": "mountain_pass",
        "target_spawn_id": "return_from_village",
        "locked_message": "前路尚未开放。"
      },
      {
        "id": "npc_porter_chen",
        "type": "npc",
        "name": "陈脚夫",
        "actor_id": "porter_chen",
        "position": {"x": 300, "y": 340},
        "radius": 72,
        "dialogue_id": "foot_village_porter_intro",
        "quest_id": "quest_deliver_letter"
      },
      {
        "id": "notice_foot_village",
        "type": "notice",
        "name": "村口告示",
        "position": {"x": 520, "y": 260},
        "radius": 56,
        "dialogue_id": "foot_village_notice"
      },
      {
        "id": "npc_innkeeper_lu",
        "type": "npc",
        "name": "陆掌柜",
        "actor_id": "innkeeper_lu",
        "position": {"x": 760, "y": 320},
        "radius": 72,
        "dialogue_id": "foot_village_innkeeper_idle",
        "quest_id": "quest_deliver_letter"
      },
      {
        "id": "exit_to_open_road",
        "type": "exit",
        "name": "村外官道",
        "position": {"x": 1180, "y": 360},
        "radius": 72,
        "target_map_id": "",
        "target_spawn_id": "",
        "locked_message": "前路尚未开放。"
      }
    ]
  }
]
```

- [ ] **Step 5: 更新 `data/actors.json`**

Replace `data/actors.json` with:

```json
[
  {
    "id": "hero_yun",
    "name": "云游少侠",
    "level": 1,
    "hp": 120,
    "max_hp": 120,
    "attack": 18,
    "defense": 8,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "qingshanke",
    "name": "青衫客",
    "level": 8,
    "hp": 260,
    "max_hp": 260,
    "attack": 42,
    "defense": 26,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "bandit_01",
    "name": "山道强人",
    "level": 1,
    "hp": 20,
    "max_hp": 20,
    "attack": 12,
    "defense": 4,
    "martial_arts": ["rough_fist"]
  },
  {
    "id": "innkeeper_lu",
    "name": "陆掌柜",
    "level": 3,
    "hp": 160,
    "max_hp": 160,
    "attack": 14,
    "defense": 10,
    "martial_arts": ["basic_sword"]
  },
  {
    "id": "porter_chen",
    "name": "陈脚夫",
    "level": 2,
    "hp": 130,
    "max_hp": 130,
    "attack": 10,
    "defense": 8,
    "martial_arts": ["rough_fist"]
  }
]
```

- [ ] **Step 6: 更新 `data/dialogues.json`**

Replace `data/dialogues.json` with:

```json
[
  {
    "id": "intro_meet_master",
    "title": "初入江湖",
    "lines": [
      {"speaker": "青衫客", "text": "江湖路远，先学会保命。"},
      {"speaker": "云游少侠", "text": "晚辈谨记。"}
    ]
  },
  {
    "id": "mountain_pass_intro",
    "title": "山道初逢",
    "lines": [
      {"speaker": "青衫客", "text": "前方有强人拦路，若想继续赶路，先试试你的剑。"},
      {"speaker": "云游少侠", "text": "晚辈愿往前一试。"}
    ]
  },
  {
    "id": "mountain_pass_complete",
    "title": "试剑归来",
    "lines": [
      {"speaker": "青衫客", "text": "出剑不乱，心也不乱。此丹你收下，路上或能救急。"}
    ]
  },
  {
    "id": "foot_village_porter_intro",
    "title": "村口托信",
    "lines": [
      {"speaker": "陈脚夫", "text": "少侠若往街里去，可否替我把这封信交给客栈陆掌柜？"},
      {"speaker": "云游少侠", "text": "举手之劳，我这就送去。"}
    ]
  },
  {
    "id": "foot_village_porter_reminder",
    "title": "托信未达",
    "lines": [
      {"speaker": "陈脚夫", "text": "陆掌柜就在街中客栈门前，劳烦少侠了。"}
    ]
  },
  {
    "id": "foot_village_porter_after",
    "title": "脚夫道谢",
    "lines": [
      {"speaker": "陈脚夫", "text": "掌柜已知消息，多谢少侠跑这一趟。"}
    ]
  },
  {
    "id": "foot_village_innkeeper_idle",
    "title": "客栈门前",
    "lines": [
      {"speaker": "陆掌柜", "text": "客房已满，若是打听消息，先问问村口脚夫。"}
    ]
  },
  {
    "id": "deliver_letter_complete",
    "title": "书信送达",
    "lines": [
      {"speaker": "陆掌柜", "text": "原来山道已经通了。少侠若继续打听飞红巾踪迹，可往东边官道寻人。"},
      {"speaker": "云游少侠", "text": "多谢掌柜指点。"}
    ]
  },
  {
    "id": "deliver_letter_after",
    "title": "线索再问",
    "lines": [
      {"speaker": "陆掌柜", "text": "飞红巾的消息，仍要往东边官道打听。只是前路眼下还未开放。"}
    ]
  },
  {
    "id": "foot_village_notice",
    "title": "村口告示",
    "lines": [
      {"speaker": "告示", "text": "近日山道强人出没，往来行人结伴而行。若有飞红巾消息，可报与客栈掌柜。"}
    ]
  }
]
```

- [ ] **Step 7: 更新 `data/quests.json`**

Replace `data/quests.json` with:

```json
[
  {
    "id": "quest_first_step",
    "title": "初入江湖",
    "description": "向青衫客请教江湖规矩。",
    "start_dialogue": "intro_meet_master",
    "reward_items": ["herb_small"]
  },
  {
    "id": "quest_mountain_trial",
    "title": "山道试剑",
    "description": "击退山道前方的强人，再回去向青衫客复命。",
    "start_dialogue": "mountain_pass_intro",
    "complete_dialogue": "mountain_pass_complete",
    "reward_items": ["herb_small"],
    "reward_item_amounts": {"herb_small": 1}
  },
  {
    "id": "quest_deliver_letter",
    "title": "送信到客栈",
    "description": "替村口脚夫把书信送到客栈陆掌柜手中。",
    "start_dialogue": "foot_village_porter_intro",
    "complete_dialogue": "deliver_letter_complete",
    "reward_flags": {"clue_foot_village": "掌柜提到飞红巾踪迹"}
  }
]
```

- [ ] **Step 8: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：8 个测试套件
```

Commit:

```powershell
git add data tests/test_data_loader.gd tests/test_map_data.gd
git commit -m "feat: 添加山脚村镇内容数据"
```

---

### Task 2: 添加地图切换系统

**Files:**
- Create: `tests/test_map_transition_system.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/systems/map_transition_system.gd`

- [ ] **Step 1: 写失败测试 `tests/test_map_transition_system.gd`**

Create `tests/test_map_transition_system.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var transition_system = MapTransitionSystemScript.new()

	var mountain = repository.get_map("mountain_pass")
	var village = repository.get_map("foot_village")
	var mountain_exit = _find_object(mountain, "exit_to_foot_village")
	var result = transition_system.resolve_transition(mountain_exit, village)
	assertions.assert_true(result.get("success", false), "山道出口应能切到村镇")
	assertions.assert_eq(result.get("map_id", ""), "foot_village", "切换结果应包含目标地图")
	assertions.assert_eq(result.get("position", Vector2.ZERO), Vector2(120, 360), "切换结果应使用村口出生点")

	var village_exit = _find_object(village, "exit_to_mountain_pass")
	var back = transition_system.resolve_transition(village_exit, mountain)
	assertions.assert_true(back.get("success", false), "村镇出口应能切回山道")
	assertions.assert_eq(back.get("map_id", ""), "mountain_pass", "返回结果应包含山道地图")
	assertions.assert_eq(back.get("position", Vector2.ZERO), Vector2(1110, 320), "返回结果应使用山道返回点")

	var missing_spawn = transition_system.resolve_transition({
		"target_map_id": "foot_village",
		"target_spawn_id": "missing_spawn"
	}, village)
	assertions.assert_true(missing_spawn.get("success", false), "缺失出生点时仍应允许切换")
	assertions.assert_eq(missing_spawn.get("position", Vector2.ZERO), Vector2(120, 360), "缺失出生点应回退默认出生点")

	var missing_target = transition_system.resolve_transition({
		"target_map_id": "missing_map",
		"target_spawn_id": "start",
		"locked_message": "前路尚未开放。"
	}, {})
	assertions.assert_true(not missing_target.get("success", true), "缺失目标地图应返回失败")
	assertions.assert_eq(missing_target.get("message", ""), "前路尚未开放。", "缺失目标地图应返回提示")

	var locked = transition_system.resolve_transition({
		"target_map_id": "",
		"target_spawn_id": "",
		"locked_message": "前路尚未开放。"
	}, village)
	assertions.assert_true(not locked.get("success", true), "空目标地图应返回失败")
	assertions.assert_eq(locked.get("message", ""), "前路尚未开放。", "空目标地图应返回锁定提示")

	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
```

- [ ] **Step 2: 接入测试运行器**

Replace `tests/run_tests.gd` with:

```gdscript
extends SceneTree

const TestAssertionsScript = preload("res://tests/support/test_assertions.gd")
const TestDataLoaderScript = preload("res://tests/test_data_loader.gd")
const TestDomainModelsScript = preload("res://tests/test_domain_models.gd")
const TestQuestAndDialogueScript = preload("res://tests/test_quest_and_dialogue.gd")
const TestCombatAndSaveScript = preload("res://tests/test_combat_and_save.gd")
const TestMapDataScript = preload("res://tests/test_map_data.gd")
const TestMapStateAndFlowScript = preload("res://tests/test_map_state_and_flow.gd")
const TestInteractionSystemScript = preload("res://tests/test_interaction_system.gd")
const TestSaveMapStateScript = preload("res://tests/test_save_map_state.gd")
const TestMapTransitionSystemScript = preload("res://tests/test_map_transition_system.gd")

func _initialize() -> void:
	var assertions = TestAssertionsScript.new()
	var suites: Array = [
		TestDataLoaderScript.new(),
		TestDomainModelsScript.new(),
		TestQuestAndDialogueScript.new(),
		TestCombatAndSaveScript.new(),
		TestMapDataScript.new(),
		TestMapStateAndFlowScript.new(),
		TestInteractionSystemScript.new(),
		TestSaveMapStateScript.new(),
		TestMapTransitionSystemScript.new(),
	]

	for suite in suites:
		suite.run(assertions)

	for failure in assertions.failures:
		push_error(failure)

	if assertions.failures.is_empty():
		print("测试通过：%d 个测试套件" % suites.size())
		quit(0)
	else:
		print("测试失败：%d 个问题" % assertions.failures.size())
		quit(1)
```

- [ ] **Step 3: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含无法加载 `res://scripts/systems/map_transition_system.gd`。

- [ ] **Step 4: 实现 `MapTransitionSystem`**

Create `scripts/systems/map_transition_system.gd`:

```gdscript
extends RefCounted

const DEFAULT_LOCKED_MESSAGE := "前路尚未开放。"

func resolve_transition(exit_object: Dictionary, target_map: Dictionary) -> Dictionary:
	var target_map_id = str(exit_object.get("target_map_id", ""))
	if target_map_id.is_empty():
		push_error("出口缺少目标地图。")
		return {
			"success": false,
			"message": str(exit_object.get("locked_message", DEFAULT_LOCKED_MESSAGE)),
		}

	if target_map.is_empty() or str(target_map.get("id", "")) != target_map_id:
		push_error("目标地图不存在：%s" % target_map_id)
		return {
			"success": false,
			"message": str(exit_object.get("locked_message", DEFAULT_LOCKED_MESSAGE)),
		}

	var spawn_id = str(exit_object.get("target_spawn_id", ""))
	return {
		"success": true,
		"map_id": target_map_id,
		"position": read_spawn_position(target_map, spawn_id),
	}

func read_spawn_position(map_data: Dictionary, spawn_id: String) -> Vector2:
	var fallback = _read_position(map_data.get("spawn_position", {}), Vector2.ZERO)
	var spawn_points = map_data.get("spawn_points", {})
	if typeof(spawn_points) == TYPE_DICTIONARY and not spawn_id.is_empty() and spawn_points.has(spawn_id):
		return _read_position(spawn_points.get(spawn_id, {}), fallback)
	return fallback

func _read_position(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback
```

- [ ] **Step 5: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：9 个测试套件
```

Commit:

```powershell
git add scripts/systems/map_transition_system.gd tests/run_tests.gd tests/test_map_transition_system.gd
git commit -m "feat: 添加地图切换解析系统"
```

---

### Task 3: 扩展游戏状态的当前地图和存档恢复

**Files:**
- Modify: `tests/test_save_map_state.gd`
- Modify: `scripts/core/game_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_save_map_state.gd`**

Replace `tests/test_save_map_state.gd` with:

```gdscript
extends RefCounted

const GameStateScript = preload("res://scripts/core/game_state.gd")

func run(assertions) -> void:
	var state = GameStateScript.new()
	state.start_new_game()
	state.set_player_position(Vector2(444, 333))
	state.quest_system.start_quest("quest_mountain_trial")
	state.quest_system.mark_ready_to_complete("quest_mountain_trial")
	state.resolve_map_object("enemy_bandit_gate")

	var path = "user://test_mountain_pass_save.json"
	assertions.assert_true(state.save_to_path(path), "游戏状态应可写入存档文件")

	var restored = GameStateScript.new()
	assertions.assert_true(restored.load_from_path(path), "游戏状态应可从存档文件读取")

	assertions.assert_eq(restored.map_state.current_map_id, "mountain_pass", "读档应恢复地图编号")
	assertions.assert_eq(restored.map_state.player_position, Vector2(444, 333), "读档应恢复玩家坐标")
	assertions.assert_true(restored.map_state.is_object_resolved("enemy_bandit_gate"), "读档应恢复已解决敌人对象")
	assertions.assert_eq(restored.quest_system.get_status("quest_mountain_trial"), "ready_to_complete", "读档应恢复任务状态")

	var village_state = GameStateScript.new()
	village_state.start_new_game()
	village_state.set_current_map("foot_village", Vector2(760, 320))
	village_state.quest_system.start_quest("quest_deliver_letter")
	village_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	village_state.quest_system.complete_quest("quest_deliver_letter")
	village_state.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
	assertions.assert_eq(village_state.get_current_map_scene_path(), "res://scenes/foot_village.tscn", "村镇地图应映射到村镇场景")
	assertions.assert_eq(village_state.get_scene_path_for_map("missing_map"), "res://scenes/mountain_pass.tscn", "未知地图应回退山道场景")

	var village_path = "user://test_foot_village_save.json"
	assertions.assert_true(village_state.save_to_path(village_path), "村镇状态应可写入存档文件")

	var restored_village = GameStateScript.new()
	assertions.assert_true(restored_village.load_from_path(village_path), "村镇状态应可从存档文件读取")
	assertions.assert_eq(restored_village.map_state.current_map_id, "foot_village", "读档应恢复村镇地图")
	assertions.assert_eq(restored_village.map_state.player_position, Vector2(760, 320), "读档应恢复村镇坐标")
	assertions.assert_eq(restored_village.quest_system.get_status("quest_deliver_letter"), "completed", "读档应恢复送信任务状态")
	assertions.assert_eq(restored_village.flags.get("clue_foot_village", ""), "掌柜提到飞红巾踪迹", "读档应恢复线索标记")

	state.free()
	restored.free()
	village_state.free()
	restored_village.free()
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: 命令退出码非 `0`，错误原因包含 `Nonexistent function 'set_current_map'`。

- [ ] **Step 3: 扩展 `GameState`**

Replace `scripts/core/game_state.gd` with:

```gdscript
extends Node

const PartyStateScript = preload("res://scripts/domain/party_state.gd")
const QuestSystemScript = preload("res://scripts/systems/quest_system.gd")
const MapStateScript = preload("res://scripts/domain/map_state.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")

var party = PartyStateScript.new()
var quest_system = QuestSystemScript.new()
var map_state = MapStateScript.new()
var flags: Dictionary = {}
var battle_context: Dictionary = {}

func start_new_game() -> void:
	party = PartyStateScript.new()
	party.add_member("hero_yun")
	party.add_item("herb_small", 1)
	quest_system = QuestSystemScript.new()
	map_state = MapStateScript.new()
	set_current_map("mountain_pass", Vector2(160, 320))
	flags = {"current_map": "mountain_pass"}
	battle_context = {}
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").game_started.emit()

func set_player_position(position: Vector2) -> void:
	map_state.set_player_position(position)

func set_current_map(map_id: String, position: Vector2) -> void:
	if map_id.is_empty():
		return
	map_state.current_map_id = map_id
	map_state.set_player_position(position)
	flags["current_map"] = map_id

func get_current_map_scene_path() -> String:
	return get_scene_path_for_map(map_state.current_map_id)

func get_scene_path_for_map(map_id: String) -> String:
	match map_id:
		"mountain_pass":
			return "res://scenes/mountain_pass.tscn"
		"foot_village":
			return "res://scenes/foot_village.tscn"
		_:
			return "res://scenes/mountain_pass.tscn"

func set_flag(flag_id: String, value: Variant = true) -> void:
	if flag_id.is_empty():
		return
	flags[flag_id] = value

func resolve_map_object(object_id: String) -> void:
	map_state.mark_object_resolved(object_id)

func is_map_object_resolved(object_id: String) -> bool:
	return map_state.is_object_resolved(object_id)

func set_battle_context(context: Dictionary) -> void:
	battle_context = context.duplicate(true)

func consume_battle_context() -> Dictionary:
	var context = battle_context.duplicate(true)
	battle_context = {}
	return context

func peek_battle_context() -> Dictionary:
	return battle_context.duplicate(true)

func apply_battle_result(result: Dictionary) -> void:
	if bool(result.get("victory", false)):
		var object_id = str(result.get("source_object_id", ""))
		if not object_id.is_empty():
			resolve_map_object(object_id)
		var quest_id = str(result.get("quest_id", ""))
		if not quest_id.is_empty():
			quest_system.mark_ready_to_complete(quest_id)
	else:
		map_state.player_position = Vector2(160, 320)

func save_to_path(path: String) -> bool:
	return SaveSystemScript.new().save_to_path(path, to_dictionary())

func load_from_path(path: String) -> bool:
	var data = SaveSystemScript.new().load_from_path(path)
	if data.is_empty():
		return false
	from_dictionary(data)
	return true

func to_dictionary() -> Dictionary:
	return {
		"party": party.to_dictionary(),
		"quests": quest_system.to_dictionary(),
		"map_state": map_state.to_dictionary(),
		"flags": flags.duplicate(true),
	}

func from_dictionary(data: Dictionary) -> void:
	party = PartyStateScript.new()
	party.from_dictionary(data.get("party", {}))
	quest_system = QuestSystemScript.new()
	quest_system.from_dictionary(data.get("quests", {}))
	map_state = MapStateScript.new()
	map_state.from_dictionary(data.get("map_state", {}))
	flags = data.get("flags", {}).duplicate(true)
	if not flags.has("current_map"):
		flags["current_map"] = map_state.current_map_id
	battle_context = {}
```

- [ ] **Step 4: 运行测试并提交**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：9 个测试套件
```

Commit:

```powershell
git add scripts/core/game_state.gd tests/test_save_map_state.gd
git commit -m "feat: 保存当前地图和线索状态"
```

---

### Task 4: 抽出通用地图场景基础并保持山道行为

**Files:**
- Create: `scripts/scenes/map_screen_base.gd`
- Modify: `scripts/scenes/map_interactable.gd`
- Modify: `scripts/scenes/mountain_pass_screen.gd`

- [ ] **Step 1: 创建通用地图场景基础**

Create `scripts/scenes/map_screen_base.gd`:

```gdscript
extends Node2D

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const HudScript = preload("res://scripts/scenes/hud.gd")
const DialogueBoxScript = preload("res://scripts/scenes/dialogue_box.gd")
const DialogueSystemScript = preload("res://scripts/systems/dialogue_system.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")

var player
var hud
var dialogue_box
var dialogue_system = DialogueSystemScript.new()
var spawner = MapObjectSpawnerScript.new()
var transition_system = MapTransitionSystemScript.new()
var map_data: Dictionary = {}
var interactables: Array = []
var map_id: String = ""
var fallback_spawn: Vector2 = Vector2(160, 320)
var background_color: Color = Color("#6f8f55")
var obstacle_color: Color = Color("#476f3f")

func configure_map(next_map_id: String, next_fallback_spawn: Vector2, next_background_color: Color, next_obstacle_color: Color) -> void:
	map_id = next_map_id
	fallback_spawn = next_fallback_spawn
	background_color = next_background_color
	obstacle_color = next_obstacle_color

func _ready() -> void:
	dialogue_system.set_repository(DataRepository)
	_load_map_data()
	_create_terrain()
	_create_player()
	_create_camera()
	_create_ui()
	_spawn_objects()
	_update_quest_text()

func _process(_delta: float) -> void:
	_update_nearest_interactable()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		var success = GameState.save_to_path("user://save_01.json")
		hud.show_message("存档成功。" if success else "存档失败。")

func _load_map_data() -> void:
	map_data = DataRepository.get_map(map_id)
	if map_data.is_empty():
		push_error("无法读取地图配置：%s" % map_id)
		map_data = {
			"id": map_id,
			"spawn_position": {"x": fallback_spawn.x, "y": fallback_spawn.y},
			"objects": [],
		}

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))

func _add_background(size: Vector2) -> void:
	var terrain = TileMapLayer.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var background = ColorRect.new()
	background.color = background_color
	background.size = size
	background.position = Vector2.ZERO
	add_child(background)
	move_child(background, 0)

func _add_obstacle(rect: Rect2) -> void:
	var body = StaticBody2D.new()
	body.position = rect.position
	var shape = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.size / 2.0
	body.add_child(shape)
	add_child(body)

	var visual = ColorRect.new()
	visual.color = obstacle_color
	visual.position = rect.position
	visual.size = rect.size
	add_child(visual)

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.global_position = _read_spawn_position()
	player.position_changed.connect(_on_player_position_changed)
	player.interact_requested.connect(_interact_with)
	add_child(player)

func _create_camera() -> void:
	var camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	camera.make_current()

func _create_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	dialogue_box = DialogueBoxScript.new()
	add_child(dialogue_box)

func _spawn_objects() -> void:
	var records = spawner.get_spawn_records(map_data, GameState.map_state.resolved_objects)
	for record in records:
		var interactable = MapInteractableScript.new()
		interactable.setup(record)
		interactable.clicked.connect(_on_interactable_clicked)
		interactable.player_entered.connect(_on_interactable_entered)
		interactable.player_exited.connect(_on_interactable_exited)
		interactables.append(interactable)
		add_child(interactable)

func _update_nearest_interactable() -> void:
	var nearest = null
	var best_distance := INF
	for interactable in interactables:
		var distance = player.global_position.distance_to(interactable.global_position)
		var radius = float(interactable.record.get("radius", 48.0))
		if distance <= radius and distance < best_distance:
			nearest = interactable
			best_distance = distance
	player.set_current_interactable(nearest)
	hud.set_prompt(nearest.get_interaction_text() if nearest != null else "")

func _interact_with(_interactable) -> void:
	pass

func _transition_to_exit(record: Dictionary) -> void:
	var target_map_id = str(record.get("target_map_id", ""))
	var target_map = DataRepository.get_map(target_map_id)
	var result = transition_system.resolve_transition(record, target_map)
	if not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "前路尚未开放。")))
		return

	GameState.set_current_map(str(result.get("map_id", "")), result.get("position", fallback_spawn))
	SceneLoader.change_scene(GameState.get_current_map_scene_path())

func _open_dialogue(dialogue_id: String, fallback_text: String = "此人暂时无话可说。") -> void:
	var lines = dialogue_system.get_lines(dialogue_id)
	if lines.is_empty():
		lines = [{"speaker": "旁白", "text": fallback_text}]
	dialogue_box.open(lines)

func _on_interactable_clicked(interactable) -> void:
	var radius = float(interactable.record.get("radius", 48.0))
	if player.global_position.distance_to(interactable.global_position) <= radius:
		_interact_with(interactable)
	else:
		hud.show_message("距离太远。")

func _on_interactable_entered(interactable) -> void:
	hud.set_prompt(interactable.get_interaction_text())

func _on_interactable_exited(_interactable) -> void:
	hud.set_prompt("")

func _on_player_position_changed(position: Vector2) -> void:
	GameState.set_player_position(position)

func _update_quest_text() -> void:
	pass

func _read_spawn_position() -> Vector2:
	if GameState.map_state.current_map_id == map_id:
		return GameState.map_state.player_position
	return fallback_spawn
```

- [ ] **Step 2: 更新 `MapInteractable` 支持出口和告示牌**

Replace `scripts/scenes/map_interactable.gd` with:

```gdscript
extends Area2D

signal clicked(interactable)
signal player_entered(interactable)
signal player_exited(interactable)

var record: Dictionary = {}
var label: Label

func setup(next_record: Dictionary) -> void:
	record = next_record.duplicate(true)
	name = str(record.get("id", "MapInteractable"))
	global_position = _read_position(record.get("position", {}))

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = float(record.get("radius", 48.0))
	shape.shape = circle
	add_child(shape)

	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = _read_color()
	add_child(visual)

	label = Label.new()
	label.text = str(record.get("name", ""))
	label.position = Vector2(-32, -36)
	label.size = Vector2(96, 24)
	add_child(label)

	input_event.connect(_on_input_event)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_interaction_text() -> String:
	var display_name = str(record.get("name", "此处"))
	match str(record.get("type", "")):
		"npc":
			return "按 E 与%s交谈" % display_name
		"battle_trigger":
			return "按 E 挑战%s" % display_name
		"exit":
			return "按 E 前往%s" % display_name
		"notice":
			return "按 E 查看%s" % display_name
		_:
			return "按 E 与%s交互" % display_name

func _read_color() -> Color:
	match str(record.get("type", "")):
		"npc":
			return Color("#8d3b7a")
		"battle_trigger":
			return Color("#8f3b2f")
		"exit":
			return Color("#2f6fdd")
		"notice":
			return Color("#c49a2c")
		_:
			return Color("#666666")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_entered.emit(self)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_current_interactable"):
		player_exited.emit(self)

func _read_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
```

- [ ] **Step 3: 重写山道场景脚本继承基础类**

Replace `scripts/scenes/mountain_pass_screen.gd` with:

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("mountain_pass", Vector2(160, 320), Color("#6f8f55"), Color("#476f3f"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(520, 120, 120, 120))
	_add_obstacle(Rect2(900, 380, 160, 120))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"battle_trigger":
			_start_battle(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	var status = GameState.quest_system.get_status(quest_id)
	if status == "not_started":
		GameState.quest_system.start_quest(quest_id)
		_open_dialogue(str(record.get("dialogue_id", "")))
		hud.show_message("任务开始：山道试剑")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest(quest_id)
		if not GameState.map_state.is_reward_claimed(quest_id):
			GameState.party.add_item("herb_small", 1)
			GameState.map_state.mark_reward_claimed(quest_id)
			hud.show_message("获得：小还丹")
		_open_dialogue("mountain_pass_complete")
	else:
		_open_dialogue(str(record.get("dialogue_id", "")))
	_update_quest_text()

func _start_battle(record: Dictionary) -> void:
	var quest_id = str(record.get("quest_id", ""))
	if GameState.quest_system.get_status(quest_id) == "not_started":
		hud.show_message("先与青衫客交谈。")
		return
	GameState.set_battle_context({
		"enemy_id": str(record.get("actor_id", "")),
		"source_map_id": "mountain_pass",
		"source_object_id": str(record.get("id", "")),
		"quest_id": quest_id,
		"return_position": {
			"x": player.global_position.x,
			"y": player.global_position.y,
		},
	})
	SceneLoader.change_scene("res://scenes/battle.tscn")

func _update_quest_text() -> void:
	var mountain_status = GameState.quest_system.get_status("quest_mountain_trial")
	if mountain_status == "active":
		hud.set_quest_text("山道试剑：击退前方强人")
		return
	if mountain_status == "ready_to_complete":
		hud.set_quest_text("山道试剑：回去向青衫客复命")
		return
	if mountain_status == "completed":
		var delivery_status = GameState.quest_system.get_status("quest_deliver_letter")
		if delivery_status == "active":
			hud.set_quest_text("送信到客栈：将书信交给客栈掌柜")
		elif delivery_status == "ready_to_complete":
			hud.set_quest_text("送信到客栈：与掌柜确认回信")
		elif delivery_status == "completed":
			hud.set_quest_text("送信到客栈：已完成")
		else:
			hud.set_quest_text("山道试剑：已完成")
		return
	hud.set_quest_text("")
```

- [ ] **Step 4: 运行项目加载和测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：9 个测试套件
```

- [ ] **Step 5: 提交**

```powershell
git add scripts/scenes/map_screen_base.gd scripts/scenes/map_interactable.gd scripts/scenes/mountain_pass_screen.gd
git commit -m "refactor: 抽出通用地图场景基础"
```

---

### Task 5: 添加山脚村镇场景和送信任务流程

**Files:**
- Create: `scripts/scenes/foot_village_screen.gd`
- Create: `scenes/foot_village.tscn`

- [ ] **Step 1: 创建山脚村镇场景脚本**

Create `scripts/scenes/foot_village_screen.gd`:

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("foot_village", Vector2(120, 360), Color("#7f8f6a"), Color("#5f6246"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(420, 120, 180, 110))
	_add_obstacle(Rect2(690, 110, 240, 130))
	_add_obstacle(Rect2(360, 500, 180, 100))
	_add_obstacle(Rect2(820, 500, 220, 100))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"npc":
			_talk_to_npc(interactable.record)
		"notice":
			_read_notice(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)

func _talk_to_npc(record: Dictionary) -> void:
	match str(record.get("actor_id", "")):
		"porter_chen":
			_talk_to_porter(record)
		"innkeeper_lu":
			_talk_to_innkeeper(record)
		_:
			_open_dialogue(str(record.get("dialogue_id", "")))

func _talk_to_porter(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		GameState.quest_system.start_quest("quest_deliver_letter")
		_open_dialogue("foot_village_porter_intro")
		hud.show_message("任务开始：送信到客栈")
	elif status == "completed":
		_open_dialogue("foot_village_porter_after")
	else:
		_open_dialogue("foot_village_porter_reminder")
	_update_quest_text()

func _talk_to_innkeeper(_record: Dictionary) -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "not_started":
		_open_dialogue("foot_village_innkeeper_idle")
		return
	if status == "active":
		GameState.quest_system.mark_ready_to_complete("quest_deliver_letter")
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	elif status == "ready_to_complete":
		GameState.quest_system.complete_quest("quest_deliver_letter")
		GameState.set_flag("clue_foot_village", "掌柜提到飞红巾踪迹")
		GameState.map_state.mark_reward_claimed("quest_deliver_letter")
		_open_dialogue("deliver_letter_complete")
		hud.show_message("获得线索：飞红巾踪迹")
	else:
		_open_dialogue("deliver_letter_after")
	_update_quest_text()

func _read_notice(record: Dictionary) -> void:
	_open_dialogue(str(record.get("dialogue_id", "")), "告示字迹模糊，暂时看不清。")

func _update_quest_text() -> void:
	var status = GameState.quest_system.get_status("quest_deliver_letter")
	if status == "active":
		hud.set_quest_text("送信到客栈：将书信交给客栈掌柜")
	elif status == "ready_to_complete":
		hud.set_quest_text("送信到客栈：与掌柜确认回信")
	elif status == "completed":
		hud.set_quest_text("送信到客栈：已完成")
	else:
		hud.set_quest_text("")
```

- [ ] **Step 2: 创建山脚村镇场景文件**

Create `scenes/foot_village.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/foot_village_screen.gd" id="1"]

[node name="FootVillage" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: 运行项目加载和测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：9 个测试套件
```

- [ ] **Step 4: 提交**

```powershell
git add scripts/scenes/foot_village_screen.gd scenes/foot_village.tscn
git commit -m "feat: 添加山脚村镇场景"
```

---

### Task 6: 增加继续游戏入口并恢复对应地图

**Files:**
- Modify: `scripts/scenes/main_menu_screen.gd`

- [ ] **Step 1: 更新主菜单**

Replace `scripts/scenes/main_menu_screen.gd` with:

```gdscript
extends Control

var message_label: Label

func _ready() -> void:
	var title = Label.new()
	title.text = "梁羽生群侠传"
	title.position = Vector2(64, 48)
	add_child(title)

	var start_button = Button.new()
	start_button.text = "开始新游戏"
	start_button.position = Vector2(64, 104)
	start_button.pressed.connect(_start_new_game)
	add_child(start_button)

	var continue_button = Button.new()
	continue_button.text = "继续游戏"
	continue_button.position = Vector2(64, 152)
	continue_button.pressed.connect(_continue_game)
	add_child(continue_button)

	message_label = Label.new()
	message_label.position = Vector2(64, 208)
	message_label.size = Vector2(600, 32)
	add_child(message_label)

func _start_new_game() -> void:
	GameState.start_new_game()
	SceneLoader.change_scene("res://scenes/mountain_pass.tscn")

func _continue_game() -> void:
	if not GameState.load_from_path("user://save_01.json"):
		message_label.text = "没有可用存档。"
		return
	SceneLoader.change_scene(GameState.get_current_map_scene_path())
```

- [ ] **Step 2: 运行项目加载和测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
& $godot --headless --path . -s tests/run_tests.gd
```

Expected:

```text
测试通过：9 个测试套件
```

- [ ] **Step 3: 提交**

```powershell
git add scripts/scenes/main_menu_screen.gd
git commit -m "feat: 添加继续游戏入口"
```

---

### Task 7: 最终验证和文档更新

**Files:**
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: 更新 README**

Replace `README.md` with:

```markdown
# 梁羽生群侠传

这是一个使用 Godot 4.6 和 GDScript 开发的免费单机武侠角色扮演游戏项目。

## 当前目标

当前阶段包含：

- Godot 4.6 项目配置。
- 数据加载、任务、对话、战斗和存档基础逻辑。
- 启动、主菜单、山道探索、山脚村镇和战斗场景。
- 山道探索垂直切片：WASD 连续移动、NPC 交互、任务、战斗返回和奖励。
- 山脚村镇任务延伸切片：山道和村镇双向切换、送信到客栈任务、线索记录和存档恢复。

## 运行方式

安装 Godot 4.6 后，用 Godot 打开本仓库根目录。

如果项目本地 Godot 已下载，可运行：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果 `godot` 命令已加入 PATH，可运行：

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```
```

- [ ] **Step 2: 更新项目结构文档**

Replace `docs/godot-project-structure.md` with:

```markdown
# Godot 项目结构

## 分层规则

- `scripts/domain/`：只放领域数据和规则对象，不依赖 Godot 场景节点。
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、地图切换、交互、任务、对话、战斗和存档。
- `scripts/core/`：放全局服务，例如事件总线、游戏状态和场景切换。
- `scripts/scenes/`：放场景脚本，只负责展示、输入和连接系统。
- `data/`：放 JSON 内容数据，示例数据也必须使用中文。
- `scenes/`：放 Godot 场景文件。
- `tests/`：放 GDScript 逻辑测试。

## 中文规则

项目文档、界面文本、示例任务、示例对白、注释和提交说明优先使用中文。代码标识符、Godot API、路径、配置键和命令保留英文。

## 山道探索切片

山道探索切片使用 WASD 连续移动，不使用格子移动。地图地形放在 Godot 场景中，NPC 和战斗触发点由 `data/maps.json` 配置生成。鼠标只用于点击 NPC、交互对象和 UI，不支持点击地面自动寻路。

## 山脚村镇切片

山脚村镇切片使用同一套地图对象和交互结构。山道出口和村镇返回出口由 `data/maps.json` 配置，`MapTransitionSystem` 解析目标地图和出生点。村镇第一版是一条主街，包含客栈掌柜、村口脚夫、告示牌和未开放官道出口。

## 验证命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本机没有配置项目本地 Godot 或 PATH 中的 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
```

- [ ] **Step 3: 运行最终自动验证**

Run:

```powershell
git status --short
Select-String -Path README.md,docs/godot-project-structure.md,data/*.json,scripts/**/*.gd,tests/*.gd -Pattern 'lorem|Hello World' -CaseSensitive:$false
Get-ChildItem data\*.json | ForEach-Object { $null = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json; Write-Output "JSON_OK $($_.Name)" }
git diff --check HEAD
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

Expected:

```text
JSON_OK actors.json
JSON_OK dialogues.json
JSON_OK items.json
JSON_OK maps.json
JSON_OK martial_arts.json
JSON_OK quests.json
测试通过：9 个测试套件
```

`Select-String` and `git diff --check HEAD` should produce no issue output. `git status --short` may show only user-owned untracked `.spec-workflow/`.

- [ ] **Step 4: 人工场景验收**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64.exe"
& $godot --path .
```

Manual checks:

```text
1. 主菜单点击“开始新游戏”进入山道。
2. WASD 可以连续移动。
3. 山道出口显示“按 E 前往山脚村镇”。
4. 按 E 进入山脚村镇。
5. 村镇主街可以移动，角色不会穿过边界。
6. 靠近陈脚夫显示交互提示。
7. 与陈脚夫交谈后任务摘要显示“送信到客栈：将书信交给客栈掌柜”。
8. 靠近陆掌柜并交谈后，任务完成并显示飞红巾线索。
9. 告示牌可以阅读。
10. 村外官道显示“前路尚未开放。”且不黑屏。
11. 从村镇左侧出口返回山道。
12. 在村镇按 Esc 显示“存档成功。”。
13. 返回主菜单后点击“继续游戏”，能进入存档记录的地图。
```

- [ ] **Step 5: 提交**

```powershell
git add README.md docs/godot-project-structure.md
git commit -m "docs: 更新山脚村镇运行说明"
```

## 自检记录

- Spec 覆盖：本计划覆盖双向地图切换、山脚村镇主街、客栈掌柜、村口脚夫、告示牌、送信任务、线索记录、存档恢复、错误提示和未开放出口。
- 范围控制：本计划不实现商店、背包界面、装备、室内地图、新战斗系统或第三张可进入地图。
- 类型一致性：地图编号统一使用 `mountain_pass` 和 `foot_village`；任务编号统一使用 `quest_deliver_letter`；出口字段统一使用 `target_map_id` 和 `target_spawn_id`；线索 flag 统一使用 `clue_foot_village`。
- 测试路径：新增测试接入 `tests/run_tests.gd`，最终预期为 9 个测试套件。
