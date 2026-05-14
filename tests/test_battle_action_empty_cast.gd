extends RefCounted

# 战棋空放：玩家选普攻或招式但目标格内无敌人。
# 行动应被接受，招式仍扣 MP，普攻不扣资源；同时通过 EventBus.tactical_action_resolved 通知 UI。

const TacticalCombatSystemScript = preload("res://scripts/systems/tactical_combat_system.gd")
const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")
const GameStateScript = preload("res://scripts/core/game_state.gd")

# unit_id 现在直接使用 actor_id，主角为 "hero_yun"。
# 普攻 action_id 在 resolve_action 中约定为 "attack"。

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()
	var sys = TacticalCombatSystemScript.new()
	sys.set_repository(repo)

	var gs = GameStateScript.new()
	gs.start_new_game()

	var bandit_gate = _find_object(repo.get_map("mountain_pass"), "enemy_bandit_gate")
	var ctx = bandit_gate.duplicate(true)
	ctx["source_map_id"] = "mountain_pass"
	ctx["source_object_id"] = "enemy_bandit_gate"

	var battle = sys.create_battle(gs, ctx, repo)
	var hero = battle.get_unit("hero_yun")
	assertions.assert_true(hero != null, "主角单位 hero_yun 应存在")
	if hero == null:
		repo.free()
		gs.free()
		return

	# 监听 EventBus 全局自动加载单例。
	var bus = Engine.get_main_loop().root.get_node("EventBus")
	assertions.assert_true(bus != null, "EventBus 单例应存在")
	var observer = ActionObserver.new()
	bus.tactical_action_resolved.connect(observer._on_resolved)

	# 普攻空放：target_cells = []
	var hero_hp_before = hero.hp
	var hero_mp_before = hero.mp
	var attack_result = sys.resolve_action(battle, "hero_yun", "attack", [])
	assertions.assert_true(bool(attack_result.get("success", false)), "普攻空放应被接受")
	assertions.assert_eq(hero.hp, hero_hp_before, "普攻空放不应改变主角气血")
	assertions.assert_eq(hero.mp, hero_mp_before, "普攻空放不应扣内力")
	assertions.assert_eq(observer.events.size(), 1, "普攻空放应触发一次 tactical_action_resolved")
	assertions.assert_eq(str(observer.events[0]["action_id"]), "attack", "普攻信号 action_id 应为 attack")

	# 招式空放：剑气漩 target_cells = [] → 仍扣 MP 8
	hero.mp = hero.max_mp
	var swirl_mp_before = hero.mp
	var swirl_result = sys.resolve_action(battle, "hero_yun", "sword_aura_swirl", [])
	assertions.assert_true(bool(swirl_result.get("success", false)), "剑气漩空放应被接受")
	assertions.assert_eq(hero.mp, swirl_mp_before - 8, "剑气漩空放仍应扣 8 点内力")
	assertions.assert_eq(observer.events.size(), 2, "剑气漩空放应再触发一次 tactical_action_resolved")
	assertions.assert_eq(str(observer.events[1]["action_id"]), "sword_aura_swirl", "招式信号 action_id 应为 sword_aura_swirl")
	assertions.assert_eq(int(observer.events[1]["target_count"]), 0, "招式空放信号 target_cells 应为 0 格")

	# 内力不足时仍应失败、不发信号
	hero.mp = 2
	var swirl_low_mp = sys.resolve_action(battle, "hero_yun", "sword_aura_swirl", [])
	assertions.assert_true(not bool(swirl_low_mp.get("success", false)), "内力不足时剑气漩空放仍应失败")
	assertions.assert_eq(observer.events.size(), 2, "失败时不应发 tactical_action_resolved 信号")

	bus.tactical_action_resolved.disconnect(observer._on_resolved)
	repo.free()
	gs.free()

func _find_object(map_data: Dictionary, object_id: String) -> Dictionary:
	for obj in map_data.get("objects", []):
		if str(obj.get("id", "")) == object_id:
			return obj
	return {}

class ActionObserver extends RefCounted:
	var events: Array = []
	func _on_resolved(unit_id: String, action_id: String, target_cells: Array) -> void:
		events.append({
			"unit_id": unit_id,
			"action_id": action_id,
			"target_count": target_cells.size(),
		})
