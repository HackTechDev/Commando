extends LevelTest
## Défense contre les coups des ennemis : parade, esquive, coup encaissé, et
## contre (ordre d'assommer donné pendant l'attaque ennemie).


## Met l'ennemi `enemy_path` en alerte face à Alpha, à portée de coup ;
## renvoie [Alpha, ennemi].
func _face_off(enemy_path: String, parry: float, dodge: float) -> Array:
	await load_level()
	var other := "Enemies/Soldier1" if enemy_path.ends_with("Dummy") else "Enemies/TrainingDummy"
	park(node(other), Vector3(25, 0, 25))
	var enemy: Enemy = node(enemy_path)
	enemy.stationary = true
	var alpha: Commando = node("Units/Alpha")
	alpha.health.reset(100000.0)
	own_stats(alpha).parry_chance = parry
	alpha.stats.dodge_chance = dodge
	alpha.global_position = enemy.global_position - enemy.global_basis.z * 1.2
	await frames(3)
	enemy.detection = 1.0
	return [alpha, enemy]


## Compte les attaques, parades, esquives et coups reçus pendant `count` images.
func _tally(alpha: Commando, enemy: Enemy, count: int) -> Dictionary:
	var tally := {"attacks": 0, "parry": 0, "dodge": 0, "hit": 0, "drift": 0.0}
	var start := alpha.global_position
	var was_attacking := false
	var was_defending := false
	var health := alpha.health.health
	for i in count:
		await get_tree().physics_frame
		if enemy.is_attacking() and not was_attacking:
			tally["attacks"] += 1
		was_attacking = enemy.is_attacking()
		var defending := alpha._defend_left > 0.0
		if defending and not was_defending:
			var move: SoldierModel.DefendMove = alpha.get_node("SoldierModel").defend_move
			tally["parry" if move == SoldierModel.DefendMove.PARRY else "dodge"] += 1
		was_defending = defending
		if alpha.health.health < health:
			tally["hit"] += 1
		health = alpha.health.health
		tally["drift"] = maxf(tally["drift"], alpha.global_position.distance_to(start))
	return tally


func test_parry_blocks_every_blow() -> void:
	var units := await _face_off("Enemies/TrainingDummy", 1.0, 0.0)
	var tally := await _tally(units[0], units[1], 600)
	assert_gt(tally["attacks"], 2, "le mannequin frappe : %s" % [tally])
	assert_eq(tally["parry"], tally["attacks"], "chaque coup est paré")
	assert_eq(tally["hit"], 0, "aucun coup reçu")


func test_dodge_steps_aside() -> void:
	var units := await _face_off("Enemies/TrainingDummy", 0.0, 1.0)
	var tally := await _tally(units[0], units[1], 600)
	assert_gt(tally["attacks"], 2, "%s" % [tally])
	assert_eq(tally["dodge"], tally["attacks"], "chaque coup est esquivé")
	assert_eq(tally["hit"], 0)
	assert_between(tally["drift"], 0.2, 0.8, "pas de côté")


func test_blows_land_without_defense() -> void:
	var units := await _face_off("Enemies/TrainingDummy", 0.0, 0.0)
	var tally := await _tally(units[0], units[1], 600)
	assert_gt(tally["attacks"], 2)
	assert_eq(tally["hit"], tally["attacks"], "chaque coup porte : %s" % [tally])


func test_armed_enemy_strikes_at_close_range() -> void:
	var units := await _face_off("Enemies/Soldier1", 1.0, 0.0)
	var tally := await _tally(units[0], units[1], 600)
	assert_gt(tally["attacks"], 2, "au contact, le soldat frappe au lieu de tirer : %s" % [tally])
	assert_eq(units[1].get_node("SoldierModel").strike_move, SoldierModel.StrikeMove.BUTT_STRIKE, "coup de crosse")


func test_counter_knocks_out_the_attacker() -> void:
	for enemy_path in ["Enemies/TrainingDummy", "Enemies/Soldier1"]:
		var units := await _face_off(enemy_path, 1.0, 0.0)
		var alpha: Commando = units[0]
		var enemy: Enemy = units[1]
		assert_gt(await frames_until(enemy.is_attacking, 300), -1, "%s attaque" % enemy_path)
		alpha.melee(enemy, Commando.MeleeKind.KNOCKOUT)
		assert_gt(await frames_until(enemy.is_stunned, 200), -1, "%s assommé par le contre" % enemy_path)
		assert_eq(alpha.health.health, alpha.health.max_health, "sans avoir été touché")
