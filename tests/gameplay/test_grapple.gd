extends LevelTest
## Prises par derrière (étranglement, égorgement) et lutte d'un ennemi en
## alerte attaqué de face.

const Move := SoldierModel.StrikeMove

var _noises: Array[StringName] = []


func before_each() -> void:
	super()
	_noises.clear()
	await load_level()
	EventBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	super()


func _on_noise(_at: Vector3, _radius: float, kind: StringName) -> void:
	_noises.append(kind)


## Attaque le mannequin par derrière ; renvoie [vu saisi, distance minimale
## pendant la prise].
func _from_behind(kind: Commando.MeleeKind, kill_operator_midway := false) -> Array:
	park(node("Enemies/Soldier1"))
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 3.0
	await frames(5)
	assert_true(dummy.is_behind(alpha.global_position))
	alpha.melee(dummy, kind)
	var grabbed := false
	var min_distance := INF
	for i in 600:
		await get_tree().physics_frame
		if dummy.state == Enemy.State.GRABBED:
			grabbed = true
		if alpha.is_grappling():
			min_distance = minf(min_distance, flat_distance(alpha.global_position, dummy.global_position))
			if kill_operator_midway and (alpha._gesture as StrikeGesture).left < 1.5:
				alpha.health.take_damage(500.0)
				kill_operator_midway = false
		if not alpha.is_striking() and alpha.melee_target() == null and i > 20:
			break
	await frames(30)
	return [grabbed, min_distance]


func test_choke_from_behind_knocks_out_silently() -> void:
	var result := await _from_behind(Commando.MeleeKind.KNOCKOUT)
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_eq(node("Units/Alpha").get_node("SoldierModel").strike_move, Move.CHOKE)
	assert_true(result[0], "victime saisie")
	assert_almost_eq(result[1], 0.45, 0.05, "l'opérateur se colle dans son dos")
	assert_true(dummy.is_stunned(), "assommé")
	assert_false(dummy.is_dead)
	assert_eq(_noises, [&"help"] as Array[StringName], "rien qu'un cri étouffé")
	assert_eq(node("Units/Alpha").get_collision_exceptions().size(), 0, "exception de collision retirée")


func test_throat_cut_from_behind_kills_silently_falling_forward() -> void:
	var result := await _from_behind(Commando.MeleeKind.KNIFE)
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_eq(node("Units/Alpha").get_node("SoldierModel").strike_move, Move.THROAT_CUT)
	assert_true(result[0], "victime saisie")
	assert_true(dummy.is_dead)
	await frames(90)
	# Chute vers l'avant : il finit face contre terre (tangage négatif).
	assert_almost_eq(dummy.get_node("SoldierModel")._body.rotation.x, -PI / 2.0, 0.1, "tombe vers l'avant")
	assert_eq(_noises, [] as Array[StringName], "aucun bruit")


func test_victim_is_released_if_operator_dies_during_choke() -> void:
	await _from_behind(Commando.MeleeKind.KNOCKOUT, true)
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_true(node("Units/Alpha").is_dead)
	assert_ne(dummy.state, Enemy.State.GRABBED, "libéré")
	assert_false(dummy.get_node("SoldierModel").grabbed)
	assert_false(dummy.is_stunned(), "pas assommé")


func test_alert_enemy_shoves_back_a_frontal_attacker() -> void:
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))
	var alpha: Commando = node("Units/Alpha")
	alpha.health.reset(10000.0)
	# Sans parade ni esquive, pas de contre : seule la lutte est en jeu.
	own_stats(alpha).parry_chance = 0.0
	alpha.stats.dodge_chance = 0.0
	var soldier: Enemy = node("Enemies/Soldier1")
	soldier.stationary = true
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 3.0
	await frames(5)
	soldier.detection = 1.0
	await frames(30)
	assert_eq(soldier.state, Enemy.State.ALERT)
	assert_true(soldier.resists(alpha.global_position), "de face et en alerte : il résiste")
	var model: SoldierModel = soldier.get_node("SoldierModel")
	assert_false(soldier.is_guarding(), "à 3 m : pas encore en garde")
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 2.0
	await frames(5)
	assert_true(soldier.is_guarding(), "cible proche : garde levée")
	assert_true(model.guard_up, "arme en travers de la poitrine")
	assert_false(model.aiming, "il ne vise pas en garde")
	alpha.melee(soldier, Commando.MeleeKind.KNOCKOUT)
	var shoved := func() -> bool: return model.shove_progress >= 0.0
	assert_gt(await frames_until(shoved, 150), -1, "il repousse l'opérateur")
	var closest := flat_distance(alpha.global_position, soldier.global_position)
	await frames(60)
	assert_gt(flat_distance(alpha.global_position, soldier.global_position), closest + 0.5, "l'opérateur recule")
	assert_null(alpha.melee_target(), "l'ordre de corps à corps est annulé")
	assert_string_contains(alpha.hint_text(), "En garde", "le joueur sait pourquoi")
	assert_false(soldier.is_stunned())
	assert_false(soldier.is_dead)
