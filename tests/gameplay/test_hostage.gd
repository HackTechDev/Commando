extends LevelTest
## Bouclier humain : un ennemi saisi par derrière, tenu devant l'opérateur,
## qui avance lentement à l'arme de poing ; les autres ennemis retiennent
## leur tir.


func before_each() -> void:
	super()
	await load_level()


## Alpha saisit le mannequin par derrière.
func _take_dummy(alpha: Commando, dummy: Enemy) -> void:
	park(node("Enemies/Soldier1"))
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = 0.0
	alpha.global_position = dummy.global_position + dummy.global_basis.z * 2.0
	await frames(5)
	assert_true(alpha.melee(dummy, Commando.MeleeKind.HOSTAGE))
	assert_gt(await frames_until(func() -> bool: return alpha.hostage == dummy, 300), -1, "otage saisi")


func test_hostage_is_held_in_front_while_walking_slowly() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	await _take_dummy(alpha, dummy)
	assert_eq(dummy.state, Enemy.State.GRABBED)
	assert_eq(dummy.captor, alpha)
	assert_true(alpha.using_secondary, "arme de poing en main")
	await frames(20)
	assert_true(alpha._model.hostage_hold, "bras autour du cou")
	assert_false(alpha.weapon_slung)
	# Il avance lentement, l'otage devant lui.
	var start := alpha.global_position
	var goal := start + Vector3(4, 0, 0)
	alpha.move_to(goal, true)
	await frames(60)
	var speed := flat_distance(alpha.global_position, start)
	assert_almost_eq(speed, alpha.stats.walk_speed * Commando.HOSTAGE_SPEED, 0.25, "à pas lents, même en courant")
	var front := alpha.global_position - alpha.global_basis.z * SoldierModel.GRAB_DISTANCE
	assert_lt(flat_distance(dummy.global_position, front), 0.1, "l'otage reste devant")
	assert_almost_eq(angle_difference(dummy.rotation.y, alpha.rotation.y), 0.0, 0.05, "tourné comme lui")
	# Mains prises : ni grenade, ni changement de posture, ni second corps à corps.
	alpha.toggle_posture(SoldierModel.Posture.CROUCHED)
	assert_eq(alpha.posture, SoldierModel.Posture.STANDING, "reste debout")
	assert_false(alpha.throw_grenade(goal))
	assert_false(alpha.melee(node("Enemies/Soldier1"), Commando.MeleeKind.KNOCKOUT))
	assert_string_contains(alpha.hint_text(), "otage")


func test_the_hostage_menu_releases_or_knocks_out() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	await _take_dummy(alpha, dummy)
	var ids := PlayerController.melee_options(dummy).map(func(o: Dictionary) -> StringName: return o.id)
	assert_eq(ids, [&"release", &"knockout"], "menu de l'otage")
	alpha.release_hostage()
	assert_null(alpha.hostage)
	assert_null(dummy.captor)
	assert_ne(dummy.state, Enemy.State.GRABBED, "relâché")
	assert_eq(dummy.state, Enemy.State.ALERT, "il donne l'alerte")
	assert_false(alpha._model.hostage_hold)
	# De nouveau, puis assommé d'un coup.
	dummy.detection = 0.0
	dummy._update_state()
	await _take_dummy(alpha, dummy)
	assert_true(alpha.melee(dummy, Commando.MeleeKind.KNOCKOUT), "assommer l'otage")
	assert_true(dummy.is_stunned())
	assert_null(alpha.hostage)


func test_a_frontal_grab_is_refused() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	park(node("Enemies/Soldier1"))
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = 0.0
	alpha.global_position = dummy.global_position - dummy.global_basis.z * 2.0
	await frames(5)
	alpha.melee(dummy, Commando.MeleeKind.HOSTAGE)
	await frames(90)
	assert_null(alpha.hostage)
	assert_string_contains(alpha.hint_text(), "par derrière")


func test_enemies_hold_fire_when_the_hostage_covers() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var soldier: Enemy = node("Enemies/Soldier1")
	alpha.health.reset(10000.0)
	soldier.stationary = true
	soldier.stats = soldier.stats.duplicate() as EnemyStats
	soldier.stats.hit_chance_near = 1.0
	soldier.stats.hit_chance_far = 1.0
	# Alpha à 6 m devant le soldat, l'otage entre eux.
	alpha.global_position = soldier.global_position - soldier.global_basis.z * 6.0
	alpha.look_at(soldier.global_position, Vector3.UP)
	alpha.rotation.x = 0.0
	alpha.rotation.z = 0.0
	alpha.take_hostage(dummy)
	await frames(2)
	soldier.detection = 1.0
	var hp := alpha.health.health
	await frames(240)
	assert_eq(soldier.state, Enemy.State.ALERT)
	assert_gt(soldier.hesitations, 0, "il a voulu tirer")
	assert_eq(alpha.health.health, hp, "pas une balle")
	# L'otage lâché et écarté : il tire.
	alpha.release_hostage()
	park(dummy, Vector3(25, 0, 25))
	assert_gt(await frames_until(func() -> bool: return alpha.health.health < hp, 300), -1, "plus de couverture")


func test_the_hostage_escapes_when_the_operator_dies() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	await _take_dummy(alpha, dummy)
	alpha.health.take_damage(alpha.health.health)
	assert_null(dummy.captor)
	assert_eq(dummy.state, Enemy.State.ALERT)
