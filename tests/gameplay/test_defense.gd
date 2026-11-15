extends LevelTest
## Défense contre les coups des ennemis : parade, esquive, coup encaissé, et
## contre (ordre d'assommer donné pendant l'attaque ennemie).


## Met l'ennemi `enemy_path` en alerte face à Alpha, à portée de coup ;
## renvoie [Alpha, ennemi].
func _face_off(enemy_path: String, parry: float, dodge: float, auto: bool = true) -> Array:
	await load_level()
	Commando.auto_parry = auto
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
		var defending := alpha.is_defending()
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


## Pose un mur (couche « Murs ») de 2 m de côté, centré en `at`.
func _wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 0b10
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 2.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	level.add_child(wall)
	wall.global_position = at
	return wall


func test_dodge_goes_to_the_free_side() -> void:
	var units := await _face_off("Enemies/TrainingDummy", 0.0, 1.0)
	var alpha: Commando = units[0]
	var enemy: Enemy = units[1]
	# Mur à droite d'Alpha (vu face à l'ennemi), tout contre lui.
	var to_enemy := enemy.global_position - alpha.global_position
	to_enemy.y = 0.0
	var right := to_enemy.normalized().cross(Vector3.UP)
	var wall := _wall(alpha.global_position + right * 0.55 + Vector3.UP)
	wall.look_at(wall.global_position + right, Vector3.UP)
	wall.rotate_object_local(Vector3.UP, PI / 2.0)
	await frames(2)
	var sides: Array[float] = []
	var was_defending := false
	for i in 600:
		await get_tree().physics_frame
		if alpha.is_defending() and not was_defending:
			sides.append(alpha.get_node("SoldierModel").defend_side)
		was_defending = alpha.is_defending()
	assert_gt(sides.size(), 2, "esquives")
	for side in sides:
		assert_eq(side, -1.0, "toujours du côté libre")
	assert_eq(DefendGesture.free_side(alpha, enemy, right), -1.0)
	var other := _wall(alpha.global_position - right * 0.55 + Vector3.UP)
	other.global_transform.basis = wall.global_transform.basis
	await frames(2)
	assert_eq(DefendGesture.free_side(alpha, enemy, right), 0.0, "coincé : aucun côté")


func test_parry_key_blocks_only_when_pressed_in_time() -> void:
	var units := await _face_off("Enemies/TrainingDummy", 0.0, 0.0, false)
	var alpha: Commando = units[0]
	var enemy: Enemy = units[1]
	# Sans la touche, la parade automatique étant coupée : il encaisse.
	var tally := await _tally(alpha, enemy, 200)
	assert_gt(tally["attacks"], 0)
	assert_eq(tally["hit"], tally["attacks"], "sans la touche, chaque coup porte : %s" % [tally])
	# Touche pressée au début de l'élan : paré, et l'ennemi est déséquilibré.
	assert_gt(await frames_until(func() -> bool: return enemy.is_attacking(), 300), -1)
	var health := alpha.health.health
	assert_true(alpha.ready_parry())
	assert_false(alpha.ready_parry(), "pas deux fois de suite")
	assert_gt(await frames_until(alpha.is_defending, 60), -1, "parade")
	assert_eq(alpha._model.defend_move, SoldierModel.DefendMove.PARRY)
	assert_eq(alpha.health.health, health, "coup paré")
	assert_gt(await frames_until(enemy.is_off_balance, 30), -1, "ennemi déséquilibré")
	# Touche pressée trop tôt : la fenêtre est passée quand le coup arrive.
	assert_gt(await frames_until(func() -> bool: return not enemy.is_attacking() and not enemy.is_off_balance(), 300), -1)
	await frames(roundi(Commando.PARRY_COOLDOWN * 60.0) + 2)
	assert_true(alpha.ready_parry())
	await frames(roundi(Commando.PARRY_WINDOW * 60.0) + 5)
	assert_false(alpha.is_ready_to_parry(), "fenêtre refermée")

