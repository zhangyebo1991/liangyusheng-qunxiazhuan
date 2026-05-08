extends RefCounted

const CombatResultScript = preload("res://scripts/domain/combat_result.gd")

func resolve_duel(attacker, defender, martial_art):
	var result = CombatResultScript.new()
	var raw_damage = attacker.attack + martial_art.power - defender.defense
	result.damage = maxi(1, raw_damage)
	result.rounds = 1

	if result.damage >= defender.hp:
		result.winner_id = attacker.id
		result.loser_id = defender.id
		result.log.append("%s 使出%s，击败了%s。" % [attacker.name, martial_art.name, defender.name])
	else:
		result.winner_id = defender.id
		result.loser_id = attacker.id
		result.log.append("%s 使出%s，未能击败%s。" % [attacker.name, martial_art.name, defender.name])

	return result
