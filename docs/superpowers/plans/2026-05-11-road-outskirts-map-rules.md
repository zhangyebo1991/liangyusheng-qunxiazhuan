# 村外官道与地图规则基础切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增村外官道小地图，并把地图场景路径、出口解锁、条件对象和拾取奖励沉到数据与通用系统层。

**Architecture:** 沿用“领域逻辑、系统流程、场景表现”分层。地图路径、出口条件、对象条件和拾取奖励由 `data/maps.json` 与系统层驱动；具体地图场景只负责地形、障碍和少量地图个性化接线。第一版只支持单个任务状态条件和 `pickup` 奖励对象，避免提前做复杂脚本事件系统。

**Tech Stack:** Godot 4.6、GDScript、JSON 数据文件、Godot 无头脚本测试、PowerShell 验证命令。

---

## 范围检查

本计划实现 [docs/superpowers/specs/2026-05-11-road-outskirts-map-rules-design.md](../specs/2026-05-11-road-outskirts-map-rules-design.md)。

范围包含：

- 地图记录增加 `scene_path`。
- 新增 `road_outskirts` 地图、场景和场景脚本。
- 村镇官道出口从未开放出口改为条件出口。
- `MapTransitionSystem` 支持任务状态条件。
- `MapObjectSpawner` 支持任务状态条件过滤。
- 新增 `MapRewardSystem` 作为拾取奖励唯一入口。
- `MapScreenBase` 支持 `pickup` 交互。
- `MapInteractable` 支持 `pickup` 提示和调试颜色。
- README 和项目结构文档补充当前地图规则能力。

本计划不包含新敌人、新任务链、随机遭遇、世界地图、正式美术、多条件表达式系统或完整脚本化事件系统。

验证命令优先使用项目本地 Godot：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

当前测试套件里地图切换负例会打印预期错误日志，只要最终退出码为 `0` 且输出 `测试通过` 即可。

## 文件结构

```text
data/maps.json                                # 补齐 scene_path，新增 road_outskirts、条件官道出口和路边包裹
docs/godot-project-structure.md               # 补充官道地图规则切片说明
README.md                                     # 更新当前目标列表
scenes/road_outskirts.tscn                    # 新增官道 Godot 场景
scripts/core/game_state.gd                    # 地图场景路径从 DataRepository 读取
scripts/scenes/foot_village_screen.gd         # shop/exit 之外保持原有村镇交互，条件出口走通用系统
scripts/scenes/map_interactable.gd            # pickup 类型提示和颜色
scripts/scenes/map_screen_base.gd             # 接入 MapRewardSystem，处理 pickup 成功后移除对象和刷新 UI
scripts/scenes/road_outskirts_screen.gd       # 新增官道场景脚本
scripts/systems/map_object_spawner.gd         # 按任务状态过滤对象
scripts/systems/map_reward_system.gd          # 新增拾取奖励发放规则
scripts/systems/map_transition_system.gd      # 按任务状态校验出口条件
tests/run_tests.gd                            # 接入新增测试套件
tests/test_interaction_system.gd              # pickup 提示与条件对象过滤测试
tests/test_map_data.gd                        # 3 张地图、scene_path、官道出口和包裹数据测试
tests/test_map_reward_system.gd               # 新增拾取奖励规则测试
tests/test_map_transition_system.gd           # 官道出口锁定和解锁测试
tests/test_save_map_state.gd                  # road_outskirts 场景路径和包裹 resolved 存档恢复
tests/test_pickup_map_screen.gd               # MapScreenBase pickup 接线测试
```

---

### Task 1: 地图数据和场景路径数据化

**Files:**
- Modify: `tests/test_map_data.gd`
- Modify: `tests/test_save_map_state.gd`
- Modify: `data/maps.json`
- Modify: `scripts/core/game_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_map_data.gd`**

Replace `tests/test_map_data.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	var content = repository.load_all()

	assertions.assert_eq(content.get("maps", []).size(), 3, "应加载 3 张示例地图")

	var mountain = repository.get_map("mountain_pass")
	assertions.assert_eq(mountain.get("name", ""), "山道", "应按编号读取山道地图")
	assertions.assert_eq(mountain.get("scene_path", ""), "res://scenes/mountain_pass.tscn", "山道应声明场景路径")
	assertions.assert_eq(mountain.get("spawn_position", {}).get("x", 0), 160, "山道出生点横坐标应正确")
	assertions.assert_true(mountain.get("spawn_points", {}).has("return_from_village"), "山道应包含村镇返回出生点")
	assertions.assert_eq(_find_object(mountain, "exit_to_foot_village").get("target_map_id", ""), "foot_village", "山道出口应指向山脚村镇")

	var village = repository.get_map("foot_village")
	assertions.assert_eq(village.get("name", ""), "山脚村镇", "应按编号读取山脚村镇")
	assertions.assert_eq(village.get("scene_path", ""), "res://scenes/foot_village.tscn", "村镇应声明场景路径")
	assertions.assert_eq(village.get("spawn_position", {}).get("x", 0), 120, "村镇默认出生点横坐标应正确")
	assertions.assert_true(village.get("spawn_points", {}).has("village_gate"), "村镇应包含村口出生点")
	assertions.assert_eq(_find_object(village, "npc_innkeeper_lu").get("actor_id", ""), "innkeeper_lu", "村镇应配置客栈掌柜")
	assertions.assert_eq(_find_object(village, "npc_porter_chen").get("actor_id", ""), "porter_chen", "村镇应配置村口脚夫")
	assertions.assert_eq(_find_object(village, "notice_foot_village").get("type", ""), "notice", "村镇应配置告示牌")
	assertions.assert_eq(_find_object(village, "exit_to_mountain_pass").get("target_map_id", ""), "mountain_pass", "村镇应能返回山道")

	var pharmacy = _find_object(village, "shop_foot_village_pharmacy")
	assertions.assert_eq(pharmacy.get("type", ""), "shop", "村镇应配置药铺对象")
	assertions.assert_eq(pharmacy.get("name", ""), "药铺", "药铺对象应显示中文名称")
	assertions.assert_eq(pharmacy.get("shop_id", ""), "foot_village_pharmacy", "药铺对象应保存商店编号")
	var pharmacy_items = pharmacy.get("items", [])
	assertions.assert_eq(pharmacy_items.size(), 1, "药铺第一版只应配置一个商品")
	if pharmacy_items.size() > 0:
		assertions.assert_eq(pharmacy_items[0], "herb_small", "药铺第一版应出售小还丹")
	else:
		assertions.assert_true(false, "药铺第一版应出售小还丹")

	var road_exit = _find_object(village, "exit_to_road_outskirts")
	assertions.assert_eq(road_exit.get("type", ""), "exit", "村镇应配置官道出口")
	assertions.assert_eq(road_exit.get("target_map_id", ""), "road_outskirts", "官道出口应指向村外官道")
	assertions.assert_eq(road_exit.get("target_spawn_id", ""), "from_foot_village", "官道出口应指向官道村口出生点")
	assertions.assert_eq(road_exit.get("required_quest_id", ""), "quest_deliver_letter", "官道出口应要求送信任务")
	assertions.assert_eq(road_exit.get("required_quest_status", ""), "completed", "官道出口应要求送信任务完成")
	assertions.assert_eq(road_exit.get("locked_message", ""), "脚夫说前路不太平，先把书信送到客栈再说。", "官道出口应有条件锁定提示")

	var road = repository.get_map("road_outskirts")
	assertions.assert_eq(road.get("name", ""), "村外官道", "应按编号读取村外官道")
	assertions.assert_eq(road.get("scene_path", ""), "res://scenes/road_outskirts.tscn", "官道应声明场景路径")
	assertions.assert_true(road.get("spawn_points", {}).has("from_foot_village"), "官道应包含村镇进入出生点")
	var bundle = _find_object(road, "pickup_roadside_bundle")
	assertions.assert_eq(bundle.get("type", ""), "pickup", "官道应配置路边包裹")
	assertions.assert_eq(bundle.get("name", ""), "路边包裹", "包裹应显示中文名称")
	assertions.assert_eq(bundle.get("reward_coins", 0), 20, "包裹应奖励 20 文")
	assertions.assert_eq(bundle.get("reward_item_amounts", {}).get("herb_small", 0), 1, "包裹应奖励 1 个小还丹")

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

- [ ] **Step 2: 扩展场景路径测试 `tests/test_save_map_state.gd`**

In `tests/test_save_map_state.gd`, after the existing assertion:

```gdscript
assertions.assert_eq(village_state.get_current_map_scene_path(), "res://scenes/foot_village.tscn", "村镇地图应映射到村镇场景")
```

add:

```gdscript
	village_state.set_current_map("road_outskirts", Vector2(120, 360))
	assertions.assert_eq(village_state.get_current_map_scene_path(), "res://scenes/road_outskirts.tscn", "官道地图应从地图数据映射到官道场景")
	village_state.resolve_map_object("pickup_roadside_bundle")
	assertions.assert_true(village_state.is_map_object_resolved("pickup_roadside_bundle"), "拾取包裹后应记录为已解决对象")
```

Keep the existing unknown-map fallback assertion directly after these new assertions:

```gdscript
	assertions.assert_eq(village_state.get_scene_path_for_map("missing_map"), "res://scenes/mountain_pass.tscn", "未知地图应回退山道场景")
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，错误包含“应加载 3 张示例地图”或“官道地图应从地图数据映射到官道场景”。

- [ ] **Step 4: 更新 `data/maps.json`**

Replace `data/maps.json` with:

```json
[
  {
    "id": "mountain_pass",
    "name": "山道",
    "scene_path": "res://scenes/mountain_pass.tscn",
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
    "scene_path": "res://scenes/foot_village.tscn",
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
        "id": "shop_foot_village_pharmacy",
        "type": "shop",
        "name": "药铺",
        "position": {"x": 980, "y": 320},
        "radius": 72,
        "shop_id": "foot_village_pharmacy",
        "items": ["herb_small"]
      },
      {
        "id": "exit_to_road_outskirts",
        "type": "exit",
        "name": "村外官道",
        "position": {"x": 1180, "y": 360},
        "radius": 72,
        "target_map_id": "road_outskirts",
        "target_spawn_id": "from_foot_village",
        "required_quest_id": "quest_deliver_letter",
        "required_quest_status": "completed",
        "locked_message": "脚夫说前路不太平，先把书信送到客栈再说。"
      }
    ]
  },
  {
    "id": "road_outskirts",
    "name": "村外官道",
    "scene_path": "res://scenes/road_outskirts.tscn",
    "spawn_position": {"x": 120, "y": 360},
    "spawn_points": {
      "from_foot_village": {"x": 120, "y": 360}
    },
    "objects": [
      {
        "id": "pickup_roadside_bundle",
        "type": "pickup",
        "name": "路边包裹",
        "position": {"x": 620, "y": 340},
        "radius": 56,
        "reward_items": ["herb_small"],
        "reward_item_amounts": {"herb_small": 1},
        "reward_coins": 20
      },
      {
        "id": "notice_road_outskirts_sign",
        "type": "notice",
        "name": "官道路牌",
        "position": {"x": 260, "y": 300},
        "radius": 56,
        "dialogue_id": ""
      }
    ]
  }
]
```

- [ ] **Step 5: 实现数据化场景路径 `scripts/core/game_state.gd`**

In `scripts/core/game_state.gd`, add this preload after the existing `SaveSystemScript` preload:

```gdscript
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
```

Add this constant after `STARTING_COINS`:

```gdscript
const DEFAULT_MAP_SCENE_PATH := "res://scenes/mountain_pass.tscn"
```

Replace `get_scene_path_for_map()` with:

```gdscript
func get_scene_path_for_map(map_id: String) -> String:
	var map_data = _get_map_data(map_id)
	if map_data.is_empty():
		push_error("地图编号不存在：%s" % map_id)
		return DEFAULT_MAP_SCENE_PATH
	var scene_path = str(map_data.get("scene_path", ""))
	if scene_path.is_empty():
		push_error("地图缺少场景路径：%s" % map_id)
		return DEFAULT_MAP_SCENE_PATH
	return scene_path
```

Add these helper methods near the bottom of the file before `_normalize_hero_hp()`:

```gdscript
func _get_map_data(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	if is_inside_tree() and has_node("/root/DataRepository"):
		return get_node("/root/DataRepository").get_map(map_id)
	var repository = DataRepositoryScript.new()
	var map_data = repository.get_map(map_id)
	repository.free()
	return map_data
```

- [ ] **Step 6: 运行测试确认通过当前任务**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：15 个测试套件`。地图切换负例仍会打印预期错误日志。

- [ ] **Step 7: 提交**

```powershell
git add tests/test_map_data.gd tests/test_save_map_state.gd data/maps.json scripts/core/game_state.gd
git commit -m "feat: data-drive map scene paths"
```

---

### Task 2: 条件出口和条件对象生成

**Files:**
- Modify: `tests/test_map_transition_system.gd`
- Modify: `tests/test_interaction_system.gd`
- Modify: `scripts/systems/map_transition_system.gd`
- Modify: `scripts/systems/map_object_spawner.gd`
- Modify: `scripts/scenes/map_screen_base.gd`

- [ ] **Step 1: 写失败测试 `tests/test_map_transition_system.gd`**

Replace `tests/test_map_transition_system.gd` with:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const MapTransitionSystemScript = preload("res://scripts/systems/map_transition_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var transition_system = MapTransitionSystemScript.new()

	var mountain = repository.get_map("mountain_pass")
	var village = repository.get_map("foot_village")
	var road = repository.get_map("road_outskirts")
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

	var road_exit = _find_object(village, "exit_to_road_outskirts")
	var locked_state = GameStateScript.new()
	locked_state.start_new_game()
	var locked_road = transition_system.resolve_transition(road_exit, road, locked_state)
	assertions.assert_true(not locked_road.get("success", true), "送信任务未完成时官道出口应锁定")
	assertions.assert_eq(locked_road.get("message", ""), "脚夫说前路不太平，先把书信送到客栈再说。", "官道锁定时应返回配置提示")

	var unlocked_state = GameStateScript.new()
	unlocked_state.start_new_game()
	unlocked_state.quest_system.start_quest("quest_deliver_letter")
	unlocked_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	unlocked_state.quest_system.complete_quest("quest_deliver_letter")
	var unlocked_road = transition_system.resolve_transition(road_exit, road, unlocked_state)
	assertions.assert_true(unlocked_road.get("success", false), "送信任务完成后官道出口应开放")
	assertions.assert_eq(unlocked_road.get("map_id", ""), "road_outskirts", "官道出口应切换到村外官道")
	assertions.assert_eq(unlocked_road.get("position", Vector2.ZERO), Vector2(120, 360), "官道出口应使用村口进入出生点")

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

	locked_state.free()
	unlocked_state.free()
	repository.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for object in map_data.get("objects", []):
		if object.get("id", "") == object_id:
			return object
	return {}
```

- [ ] **Step 2: 扩展对象生成测试 `tests/test_interaction_system.gd`**

In `tests/test_interaction_system.gd`, add this preload after `MapInteractableScript`:

```gdscript
const GameStateScript = preload("res://scripts/core/game_state.gd")
```

After the existing resolved-object spawner assertions, add:

```gdscript
	var conditional_state = GameStateScript.new()
	conditional_state.start_new_game()
	var conditional_records_locked = spawner.get_spawn_records({
		"objects": [
			{
				"id": "pickup_locked_bundle",
				"type": "pickup",
				"required_quest_id": "quest_deliver_letter",
				"required_quest_status": "completed",
				"position": {"x": 620, "y": 340}
			}
		]
	}, [], conditional_state)
	assertions.assert_eq(conditional_records_locked.size(), 0, "任务条件不满足时对象不应生成")

	conditional_state.quest_system.start_quest("quest_deliver_letter")
	conditional_state.quest_system.mark_ready_to_complete("quest_deliver_letter")
	conditional_state.quest_system.complete_quest("quest_deliver_letter")
	var conditional_records_unlocked = spawner.get_spawn_records({
		"objects": [
			{
				"id": "pickup_locked_bundle",
				"type": "pickup",
				"required_quest_id": "quest_deliver_letter",
				"required_quest_status": "completed",
				"position": {"x": 620, "y": 340}
			}
		]
	}, [], conditional_state)
	assertions.assert_eq(conditional_records_unlocked.size(), 1, "任务条件满足时对象应生成")
	conditional_state.free()
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，`resolve_transition()` 尚未支持第三个参数，或条件对象过滤断言失败。

- [ ] **Step 4: 实现 `scripts/systems/map_transition_system.gd`**

Replace `scripts/systems/map_transition_system.gd` with:

```gdscript
extends RefCounted

const DEFAULT_LOCKED_MESSAGE := "前路尚未开放。"

func resolve_transition(exit_object: Dictionary, target_map: Dictionary, game_state = null) -> Dictionary:
	var target_map_id = str(exit_object.get("target_map_id", ""))
	if target_map_id.is_empty():
		push_error("出口缺少目标地图。")
		return _failure(exit_object)

	if target_map.is_empty() or str(target_map.get("id", "")) != target_map_id:
		push_error("目标地图不存在：%s" % target_map_id)
		return _failure(exit_object)

	if not _meets_required_quest(exit_object, game_state):
		return _failure(exit_object)

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

func _meets_required_quest(record: Dictionary, game_state) -> bool:
	var quest_id = str(record.get("required_quest_id", ""))
	var required_status = str(record.get("required_quest_status", ""))
	if quest_id.is_empty() and required_status.is_empty():
		return true
	if quest_id.is_empty() or required_status.is_empty():
		return false
	if game_state == null or game_state.quest_system == null:
		return false
	return game_state.quest_system.get_status(quest_id) == required_status

func _failure(exit_object: Dictionary) -> Dictionary:
	return {
		"success": false,
		"message": str(exit_object.get("locked_message", DEFAULT_LOCKED_MESSAGE)),
	}

func _read_position(value: Variant, fallback: Vector2) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback
```

- [ ] **Step 5: 实现 `scripts/systems/map_object_spawner.gd`**

Replace `scripts/systems/map_object_spawner.gd` with:

```gdscript
extends RefCounted

func get_spawn_records(map_data: Dictionary, resolved_objects: Array, game_state = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object in map_data.get("objects", []):
		var object_id = str(object.get("id", ""))
		if object_id.is_empty():
			continue
		if resolved_objects.has(object_id):
			continue
		if not _meets_required_quest(object, game_state):
			continue
		result.append(object)
	return result

func read_position(object: Dictionary) -> Vector2:
	var position = object.get("position", {})
	if typeof(position) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))

func _meets_required_quest(record: Dictionary, game_state) -> bool:
	var quest_id = str(record.get("required_quest_id", ""))
	var required_status = str(record.get("required_quest_status", ""))
	if quest_id.is_empty() and required_status.is_empty():
		return true
	if quest_id.is_empty() or required_status.is_empty():
		return false
	if game_state == null or game_state.quest_system == null:
		return false
	return game_state.quest_system.get_status(quest_id) == required_status
```

- [ ] **Step 6: 接入 `scripts/scenes/map_screen_base.gd`**

In `_spawn_objects()`, replace:

```gdscript
var records = spawner.get_spawn_records(map_data, resolved_objects)
```

with:

```gdscript
var records = spawner.get_spawn_records(map_data, resolved_objects, game_state)
```

In `_transition_to_exit(record)`, replace:

```gdscript
var result = transition_system.resolve_transition(record, target_map)
```

with:

```gdscript
var game_state = _get_game_state()
var result = transition_system.resolve_transition(record, target_map, game_state)
```

Then remove the duplicate later declaration:

```gdscript
var game_state = _get_game_state()
```

The resulting `_transition_to_exit()` should be:

```gdscript
func _transition_to_exit(record: Dictionary) -> void:
	var target_map_id = str(record.get("target_map_id", ""))
	var data_repository = _get_data_repository()
	var target_map = data_repository.get_map(target_map_id) if data_repository != null else {}
	var game_state = _get_game_state()
	var result = transition_system.resolve_transition(record, target_map, game_state)
	if not bool(result.get("success", false)):
		hud.show_message(str(result.get("message", "前路尚未开放。")))
		return

	if game_state == null:
		hud.show_message("前路尚未开放。")
		return
	game_state.set_current_map(str(result.get("map_id", "")), result.get("position", fallback_spawn))
	var scene_loader = _get_scene_loader()
	if scene_loader != null:
		scene_loader.change_scene(game_state.get_current_map_scene_path())
```

- [ ] **Step 7: 运行测试确认通过当前任务**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：15 个测试套件`。

- [ ] **Step 8: 提交**

```powershell
git add tests/test_map_transition_system.gd tests/test_interaction_system.gd scripts/systems/map_transition_system.gd scripts/systems/map_object_spawner.gd scripts/scenes/map_screen_base.gd
git commit -m "feat: gate map transitions by quest status"
```

---

### Task 3: 拾取奖励系统

**Files:**
- Create: `tests/test_map_reward_system.gd`
- Create: `scripts/systems/map_reward_system.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: 写失败测试 `tests/test_map_reward_system.gd`**

Create `tests/test_map_reward_system.gd`:

```gdscript
extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")
const MapObjectSpawnerScript = preload("res://scripts/systems/map_object_spawner.gd")
const MapRewardSystemScript = preload("res://scripts/systems/map_reward_system.gd")

func run(assertions) -> void:
	var repository = DataRepositoryScript.new()
	repository.load_all()
	var reward_system = MapRewardSystemScript.new()
	reward_system.set_repository(repository)

	var state = GameStateScript.new()
	state.start_new_game()
	var initial_coins = state.party.coins
	var initial_herbs = state.party.get_item_count("herb_small")
	var pickup = {
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"reward_items": ["herb_small"],
		"reward_item_amounts": {"herb_small": 1},
		"reward_coins": 20
	}
	var result = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(result.get("success", false), "有效包裹应可领取")
	assertions.assert_eq(result.get("message", ""), "获得：小还丹、20 文。", "领取包裹应返回物品和铜钱提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "领取包裹应增加小还丹")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "领取包裹应增加铜钱")
	assertions.assert_true(state.is_map_object_resolved("pickup_roadside_bundle"), "领取包裹后应标记对象已解决")

	var duplicate = reward_system.claim_pickup(state, pickup)
	assertions.assert_true(not duplicate.get("success", true), "已领取包裹不应重复领取")
	assertions.assert_eq(duplicate.get("message", ""), "这里什么也没有。", "重复领取应显示空提示")
	assertions.assert_eq(state.party.get_item_count("herb_small"), initial_herbs + 1, "重复领取不应增加物品")
	assertions.assert_eq(state.party.coins, initial_coins + 20, "重复领取不应增加铜钱")

	var coin_only_state = GameStateScript.new()
	coin_only_state.start_new_game()
	var coin_only = reward_system.claim_pickup(coin_only_state, {
		"id": "pickup_coin_pouch",
		"type": "pickup",
		"name": "钱袋",
		"reward_coins": 12
	})
	assertions.assert_true(coin_only.get("success", false), "纯铜钱奖励应可领取")
	assertions.assert_eq(coin_only.get("message", ""), "获得：12 文。", "纯铜钱奖励应返回铜钱提示")
	assertions.assert_eq(coin_only_state.party.coins, 92, "纯铜钱奖励应增加余额")

	var invalid_state = GameStateScript.new()
	invalid_state.start_new_game()
	var invalid = reward_system.claim_pickup(invalid_state, {
		"id": "pickup_invalid",
		"type": "pickup",
		"name": "空包裹",
		"reward_items": ["missing_item"],
		"reward_item_amounts": {"missing_item": 1},
		"reward_coins": 0
	})
	assertions.assert_true(not invalid.get("success", true), "全部奖励无效时不应成功")
	assertions.assert_eq(invalid.get("message", ""), "这里什么也没有。", "全部奖励无效时应显示空提示")
	assertions.assert_true(not invalid_state.is_map_object_resolved("pickup_invalid"), "全部奖励无效时不应标记对象已解决")

	var no_id = reward_system.claim_pickup(invalid_state, {
		"type": "pickup",
		"reward_coins": 10
	})
	assertions.assert_true(not no_id.get("success", true), "缺少编号的拾取对象不应成功")
	assertions.assert_eq(no_id.get("message", ""), "这里什么也没有。", "缺少编号时应显示空提示")

	var restored = GameStateScript.new()
	restored.from_dictionary(state.to_dictionary())
	var road = repository.get_map("road_outskirts")
	var spawner = MapObjectSpawnerScript.new()
	var records = spawner.get_spawn_records(road, restored.map_state.resolved_objects, restored)
	assertions.assert_eq(_count_object(records, "pickup_roadside_bundle"), 0, "读档后已领取包裹不应再次生成")

	state.free()
	coin_only_state.free()
	invalid_state.free()
	restored.free()
	repository.free()

func _count_object(records: Array, object_id: String) -> int:
	var count := 0
	for record in records:
		if str(record.get("id", "")) == object_id:
			count += 1
	return count
```

- [ ] **Step 2: 接入 `tests/run_tests.gd`**

Add this preload after `TestShopSystemScript`:

```gdscript
const TestMapRewardSystemScript = preload("res://tests/test_map_reward_system.gd")
```

Add this suite immediately after `TestShopSystemScript.new()`:

```gdscript
		TestMapRewardSystemScript.new(),
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，`res://scripts/systems/map_reward_system.gd` 不存在。

- [ ] **Step 4: 实现 `scripts/systems/map_reward_system.gd`**

Create `scripts/systems/map_reward_system.gd`:

```gdscript
extends RefCounted

const MESSAGE_EMPTY := "这里什么也没有。"

var repository = null

func set_repository(next_repository) -> void:
	repository = next_repository

func claim_pickup(game_state, object_record: Dictionary) -> Dictionary:
	var object_id = str(object_record.get("id", ""))
	if game_state == null or game_state.party == null:
		return _failure(object_id)
	if object_id.is_empty():
		push_error("拾取对象缺少编号。")
		return _failure(object_id)
	if game_state.is_map_object_resolved(object_id):
		return _failure(object_id)

	var awarded_items = _award_items(game_state, object_record)
	var awarded_coins = _award_coins(game_state, object_record)
	if awarded_items.is_empty() and awarded_coins <= 0:
		return _failure(object_id)

	game_state.resolve_map_object(object_id)
	return {
		"success": true,
		"message": _build_message(awarded_items, awarded_coins),
		"items": awarded_items,
		"coins": awarded_coins,
		"object_id": object_id,
	}

func _award_items(game_state, object_record: Dictionary) -> Array:
	var awarded: Array = []
	var item_repository = _get_repository()
	var raw_items = object_record.get("reward_items", [])
	if typeof(raw_items) != TYPE_ARRAY:
		return awarded
	var amounts = object_record.get("reward_item_amounts", {})
	if typeof(amounts) != TYPE_DICTIONARY:
		amounts = {}

	for raw_item_id in raw_items:
		var item_id = str(raw_item_id)
		if item_id.is_empty():
			continue
		var item_data = item_repository.get_item(item_id) if item_repository != null else {}
		if item_data.is_empty():
			push_error("拾取奖励物品不存在：%s" % item_id)
			continue
		var amount = max(1, int(amounts.get(item_id, 1)))
		game_state.party.add_item(item_id, amount)
		awarded.append({
			"id": item_id,
			"name": str(item_data.get("name", item_id)),
			"amount": amount,
		})
	return awarded

func _award_coins(game_state, object_record: Dictionary) -> int:
	var coins = int(object_record.get("reward_coins", 0))
	if coins <= 0:
		return 0
	game_state.party.add_coins(coins)
	return coins

func _build_message(items: Array, coins: int) -> String:
	var parts: Array[String] = []
	for item in items:
		var name = str(item.get("name", "物品"))
		var amount = int(item.get("amount", 1))
		if amount > 1:
			parts.append("%s x%d" % [name, amount])
		else:
			parts.append(name)
	if coins > 0:
		parts.append("%d 文" % coins)
	if parts.is_empty():
		return MESSAGE_EMPTY
	return "获得：%s。" % "、".join(parts)

func _failure(object_id: String) -> Dictionary:
	return {
		"success": false,
		"message": MESSAGE_EMPTY,
		"items": [],
		"coins": 0,
		"object_id": object_id,
	}

func _get_repository():
	if repository != null:
		return repository
	var loop = Engine.get_main_loop()
	if loop != null and loop.root != null and loop.root.has_node("DataRepository"):
		return loop.root.get_node("DataRepository")
	return null
```

- [ ] **Step 5: 运行测试确认通过当前任务**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：16 个测试套件`。

- [ ] **Step 6: 提交**

```powershell
git add tests/test_map_reward_system.gd tests/run_tests.gd scripts/systems/map_reward_system.gd
git commit -m "feat: add map pickup reward system"
```

---

### Task 4: 地图场景接入 pickup 交互

**Files:**
- Create: `tests/test_pickup_map_screen.gd`
- Modify: `tests/run_tests.gd`
- Modify: `tests/test_interaction_system.gd`
- Modify: `scripts/scenes/map_interactable.gd`
- Modify: `scripts/scenes/map_screen_base.gd`

- [ ] **Step 1: 扩展 pickup 提示测试**

In `tests/test_interaction_system.gd`, add after the shop interactable assertion:

```gdscript
	var pickup_interactable = MapInteractableScript.new()
	pickup_interactable.setup({
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"position": {"x": 620, "y": 340},
		"radius": 56,
	})
	assertions.assert_eq(pickup_interactable.get_interaction_text(), "按 E 查看包裹", "包裹应显示查看提示")
	pickup_interactable.free()
```

- [ ] **Step 2: 写失败测试 `tests/test_pickup_map_screen.gd`**

Create `tests/test_pickup_map_screen.gd`:

```gdscript
extends RefCounted

const HudScript = preload("res://scripts/scenes/hud.gd")
const MapInteractableScript = preload("res://scripts/scenes/map_interactable.gd")
const MapScreenBaseScript = preload("res://scripts/scenes/map_screen_base.gd")

func run(assertions) -> void:
	var root = Engine.get_main_loop().root
	var repository = root.get_node("DataRepository")
	var game_state = root.get_node("GameState")
	repository.load_all()
	game_state.start_new_game()

	var screen = MapScreenBaseScript.new()
	screen.hud = HudScript.new()
	screen.hud._ready()
	screen.map_reward_system.set_repository(repository)

	var pickup_record = {
		"id": "pickup_roadside_bundle",
		"type": "pickup",
		"name": "路边包裹",
		"reward_items": ["herb_small"],
		"reward_item_amounts": {"herb_small": 1},
		"reward_coins": 20
	}
	var interactable = MapInteractableScript.new()
	interactable.setup(pickup_record)
	screen.interactables.append(interactable)

	var initial_herbs = game_state.party.get_item_count("herb_small")
	var initial_coins = game_state.party.coins
	screen._claim_pickup(pickup_record)

	assertions.assert_eq(screen.hud.message_label.text, "获得：小还丹、20 文。", "地图场景拾取后应显示奖励消息")
	assertions.assert_eq(game_state.party.get_item_count("herb_small"), initial_herbs + 1, "地图场景拾取后应增加小还丹")
	assertions.assert_eq(game_state.party.coins, initial_coins + 20, "地图场景拾取后应增加铜钱")
	assertions.assert_true(game_state.is_map_object_resolved("pickup_roadside_bundle"), "地图场景拾取后应标记对象已解决")
	assertions.assert_eq(screen.interactables.size(), 0, "地图场景拾取成功后应移除交互对象")

	screen.hud.free()
	screen.free()
```

- [ ] **Step 3: 接入 `tests/run_tests.gd`**

Add this preload after `TestShopMapScreenScript`:

```gdscript
const TestPickupMapScreenScript = preload("res://tests/test_pickup_map_screen.gd")
```

Add this suite immediately after `TestShopMapScreenScript.new()`:

```gdscript
		TestPickupMapScreenScript.new(),
```

- [ ] **Step 4: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL，`MapScreenBase` 缺少 `map_reward_system` 或 `_claim_pickup()`，或 pickup 提示断言失败。

- [ ] **Step 5: 实现 `scripts/scenes/map_interactable.gd` pickup 支持**

In `get_interaction_text()`, add this match arm after `"shop"`:

```gdscript
		"pickup":
			return "按 E 查看%s" % display_name
```

In `_read_color()`, add this match arm after `"shop"`:

```gdscript
		"pickup":
			return Color("#7c6f3a")
```

- [ ] **Step 6: 实现 `scripts/scenes/map_screen_base.gd` pickup 接线**

Add this preload after `ShopSystemScript`:

```gdscript
const MapRewardSystemScript = preload("res://scripts/systems/map_reward_system.gd")
```

Add this property after `shop_system`:

```gdscript
var map_reward_system = MapRewardSystemScript.new()
```

In `_create_ui()`, after `shop_system.set_repository(data_repository)`, add:

```gdscript
	map_reward_system.set_repository(data_repository)
```

Add these methods after `_open_shop()`:

```gdscript
func _claim_pickup(record: Dictionary) -> void:
	var result = map_reward_system.claim_pickup(_get_game_state(), record)
	hud.show_message(str(result.get("message", "这里什么也没有。")))
	if bool(result.get("success", false)):
		_remove_interactable_by_id(str(record.get("id", "")))
		_refresh_inventory_if_open()
		_refresh_shop_if_open()

func _remove_interactable_by_id(object_id: String) -> void:
	if object_id.is_empty():
		return
	for index in range(interactables.size() - 1, -1, -1):
		var interactable = interactables[index]
		if str(interactable.record.get("id", "")) != object_id:
			continue
		interactables.remove_at(index)
		if player != null and player.current_interactable == interactable:
			player.set_current_interactable(null)
		if interactable.get_parent() != null:
			interactable.get_parent().remove_child(interactable)
		interactable.queue_free()
```

This method must remain in `MapScreenBase`; do not put reward logic in `road_outskirts_screen.gd`.

- [ ] **Step 7: Add pickup handling to map-specific scenes**

In `scripts/scenes/foot_village_screen.gd`, no pickup branch is required because the village has no pickup objects in this slice.

In the new `road_outskirts_screen.gd` from Task 5, `_interact_with()` must call `_claim_pickup()` for `pickup` records. Task 5 creates that file.

- [ ] **Step 8: 运行测试确认当前已实现部分**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：17 个测试套件`。如果 Task 5 尚未创建 `road_outskirts_screen.gd`，这里仍应通过，因为本任务只测试 `MapScreenBase` 通用 pickup 接线。

- [ ] **Step 9: 提交**

```powershell
git add tests/test_interaction_system.gd tests/test_pickup_map_screen.gd tests/run_tests.gd scripts/scenes/map_interactable.gd scripts/scenes/map_screen_base.gd
git commit -m "feat: wire pickup rewards into map screen"
```

---

### Task 5: 村外官道场景和文档

**Files:**
- Create: `scripts/scenes/road_outskirts_screen.gd`
- Create: `scenes/road_outskirts.tscn`
- Modify: `README.md`
- Modify: `docs/godot-project-structure.md`

- [ ] **Step 1: 创建 `scripts/scenes/road_outskirts_screen.gd`**

Create `scripts/scenes/road_outskirts_screen.gd`:

```gdscript
extends "res://scripts/scenes/map_screen_base.gd"

func _ready() -> void:
	configure_map("road_outskirts", Vector2(120, 360), Color("#6f7658"), Color("#4b4f3d"))
	super._ready()

func _create_terrain() -> void:
	_add_background(Vector2(1280, 720))
	_add_obstacle(Rect2(0, 0, 1280, 24))
	_add_obstacle(Rect2(0, 696, 1280, 24))
	_add_obstacle(Rect2(0, 0, 24, 720))
	_add_obstacle(Rect2(1256, 0, 24, 720))
	_add_obstacle(Rect2(360, 130, 160, 90))
	_add_obstacle(Rect2(760, 470, 180, 100))

func _interact_with(interactable) -> void:
	if interactable == null:
		return
	match str(interactable.record.get("type", "")):
		"pickup":
			_claim_pickup(interactable.record)
		"notice":
			_read_notice(interactable.record)
		"exit":
			_transition_to_exit(interactable.record)

func _read_notice(record: Dictionary) -> void:
	var dialogue_id = str(record.get("dialogue_id", ""))
	if dialogue_id.is_empty():
		_open_dialogue("", "官道向东延伸，路旁尘土新起。")
	else:
		_open_dialogue(dialogue_id, "官道向东延伸，路旁尘土新起。")

func _update_quest_text() -> void:
	hud.set_quest_text("村外官道：查看路边动静")
```

- [ ] **Step 2: 创建 `scenes/road_outskirts.tscn`**

Create `scenes/road_outskirts.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/scenes/road_outskirts_screen.gd" id="1"]

[node name="RoadOutskirts" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: 更新 `README.md`**

In `README.md`, add this bullet after the existing pharmacy/money loop bullet:

```markdown
- 村外官道与地图规则基础切片：地图场景路径数据化、送信完成后开放官道、路边包裹拾取奖励和对象状态存档。
```

- [ ] **Step 4: 更新 `docs/godot-project-structure.md`**

In `docs/godot-project-structure.md`, add this section after “回合战斗与武学成长切片”:

```markdown
## 村外官道与地图规则基础切片

村外官道切片让 `data/maps.json` 声明地图场景路径、出口条件和拾取奖励。`GameState` 通过地图数据读取场景路径，`MapTransitionSystem` 校验任务状态后开放出口，`MapObjectSpawner` 根据任务状态和已解决对象过滤生成对象。`MapRewardSystem` 是拾取奖励发放入口，官道路边包裹领取后写入 `MapState.resolved_objects`，读档后不再生成。
```

- [ ] **Step 5: 验证官道场景可无头加载**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无脚本解析错误，进程退出码为 `0`。

- [ ] **Step 6: 运行完整测试**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：17 个测试套件`。

- [ ] **Step 7: 提交**

```powershell
git add scripts/scenes/road_outskirts_screen.gd scenes/road_outskirts.tscn README.md docs/godot-project-structure.md
git commit -m "feat: add road outskirts map scene"
```

---

### Task 6: 完整验证和人工验收

**Files:**
- Verify: full test suite
- Verify: Godot project load
- Verify: manual road outskirts flow

- [ ] **Step 1: 运行完整测试套件**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出包含 `测试通过：17 个测试套件`，进程退出码为 `0`。

- [ ] **Step 2: 验证项目可无头加载**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: PASS，无脚本解析错误，进程退出码为 `0`。

- [ ] **Step 3: 人工验收官道流程**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --path .
```

Manual checks:

```text
1. 从主菜单开始新游戏。
2. 从山道进入山脚村镇。
3. 未完成“送信到客栈”时，与村镇右侧官道出口交互。
4. 确认显示“脚夫说前路不太平，先把书信送到客栈再说。”，且不切换地图。
5. 与陈脚夫接任务，再与陆掌柜完成送信任务。
6. 再次与官道出口交互，确认进入村外官道。
7. 靠近路边包裹，提示显示“按 E 查看包裹”。
8. 按 E 领取，确认显示“获得：小还丹、20 文。”。
9. 打开背包确认小还丹数量增加，商店或后续状态确认铜钱增加 20。
10. 确认包裹从地图中消失。
11. 按 Esc 存档，回主菜单继续游戏。
12. 确认仍在正确地图/位置，包裹保持消失，奖励数量保持。
```

- [ ] **Step 4: 检查工作区**

Run:

```powershell
git status --short
```

Expected: 只允许出现既有未跟踪目录 `.spec-workflow/`。如果还有本切片代码改动，先确认是否漏提交。

## Self-Review

- Spec coverage: 计划覆盖 `scene_path` 数据化、`road_outskirts` 地图、送信完成后开放官道、条件对象过滤、`pickup` 对象、包裹奖励小还丹和铜钱、已解决对象存档恢复、`MapRewardSystem` 唯一入口、`MapScreenBase` 通用接线、`MapInteractable` 提示、README/结构文档更新和完整验证。
- Placeholder scan: 未发现空白待填项、空泛“补充处理”或“类似上面”的步骤；每个代码变更步骤都给出具体目标代码。
- Type consistency: `scene_path`、`road_outskirts`、`exit_to_road_outskirts`、`from_foot_village`、`required_quest_id`、`required_quest_status`、`pickup_roadside_bundle`、`reward_items`、`reward_item_amounts`、`reward_coins`、`MapRewardSystem.claim_pickup()`、`MapScreenBase._claim_pickup()` 在数据、测试和实现任务中保持一致。
