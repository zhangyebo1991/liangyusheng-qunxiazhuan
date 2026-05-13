extends RefCounted

const DataRepositoryScript = preload("res://scripts/systems/data_repository.gd")

func run(assertions) -> void:
	var repo = DataRepositoryScript.new()
	repo.load_all()

	var w = repo.get_martial_art("sword_willow_sweep")
	assertions.assert_eq(str(w.get("name", "")), "回风拂柳", "应加载回风拂柳")
	var wt = w.get("tactical", {})
	assertions.assert_eq(str(wt.get("range_shape", "")), "fan", "回风拂柳 shape 应为 fan")
	assertions.assert_eq(int(wt.get("mp_cost", 0)), 6, "回风拂柳 mp_cost = 6")
	assertions.assert_eq(int(wt.get("damage_bonus", 0)), 5, "回风拂柳 damage_bonus = 5")
	assertions.assert_eq(int(w.get("proficiency_thresholds", [10,25,50])[0]), 10, "回风拂柳首阈值 = 10")

	var s = repo.get_martial_art("sword_all_directions")
	assertions.assert_eq(str(s.get("name", "")), "八方风雨", "应加载八方风雨")
	assertions.assert_eq(str(s.get("tactical", {}).get("range_shape", "")), "surround", "八方风雨 shape = surround")

	var p = repo.get_martial_art("sword_rainbow_pierce")
	assertions.assert_eq(str(p.get("name", "")), "长虹贯日", "应加载长虹贯日")
	assertions.assert_eq(str(p.get("tactical", {}).get("range_shape", "")), "pierce", "长虹贯日 shape = pierce")

	var r = repo.get_martial_art("sword_ring_aura")
	assertions.assert_eq(str(r.get("name", "")), "剑气环身", "应加载剑气环身")
	assertions.assert_eq(str(r.get("tactical", {}).get("range_shape", "")), "ring", "剑气环身 shape = ring")

	var hero = repo.get_actor("hero_yun")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_willow_sweep"), "主角应学会回风拂柳")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_all_directions"), "主角应学会八方风雨")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_rainbow_pierce"), "主角应学会长虹贯日")
	assertions.assert_true(hero.get("martial_arts", []).has("sword_ring_aura"), "主角应学会剑气环身")

	repo.free()
