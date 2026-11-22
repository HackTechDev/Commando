extends LevelTest
## Corps à corps de face et de flanc : coups pour assommer (poings, pieds,
## crosse), couteau, arme à la bretelle pendant l'approche.

const Move := SoldierModel.StrikeMove


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/Soldier1"))
	hide_from_enemies(node("Units/Alpha"))


## Assomme le mannequin depuis son flanc ; renvoie le coup utilisé, ou -1.
func _knock_out_from_side(alpha: Commando, dummy: Enemy) -> int:
	if dummy.is_stunned():
		dummy.stunned_behavior.left = 0.01
		await frames(30)
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = PI / 2.0
	alpha.global_position = dummy.global_position + Vector3(0, 0, 3)
	await frames(5)
	alpha.melee(dummy, Commando.MeleeKind.KNOCKOUT)
	var done := func() -> bool: return dummy.is_stunned() and not alpha.is_striking()
	if await frames_until(done, 400) < 0:
		return -1
	return alpha.get_node("SoldierModel").strike_move


func test_bare_hands_knockouts_vary_without_repeating() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.weapon_slung = true
	var moves: Array[int] = []
	for i in 6:
		moves.append(await _knock_out_from_side(alpha, dummy))
	assert_false(moves.has(-1), "six coups, six ennemis assommés : %s" % [moves])
	for move in moves:
		assert_true(move in [Move.UPPERCUT, Move.FRONT_KICK, Move.ROUNDHOUSE, Move.SIDE_KICK, Move.JAB_HOOK], "coup à mains nues ou de pied")
	for i in range(1, moves.size()):
		assert_ne(moves[i], moves[i - 1], "jamais deux fois le même coup de suite")
	await frames(40)
	var model: SoldierModel = alpha.get_node("SoldierModel")
	assert_almost_eq(model._hips.rotation.y, 0.0, 0.01, "bassin remis droit après les coups de pied")


func test_weapon_in_hands_uses_butt_strike() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.weapon_slung = false
	var max_sling := [0.0]
	var model: SoldierModel = alpha.get_node("SoldierModel")
	var probe := func() -> void: max_sling[0] = maxf(max_sling[0], model._sling)
	get_tree().physics_frame.connect(probe)
	var move := await _knock_out_from_side(alpha, dummy)
	get_tree().physics_frame.disconnect(probe)
	assert_eq(move, Move.BUTT_STRIKE)
	assert_almost_eq(max_sling[0], 0.0, 0.01, "l'arme reste en main")


func test_crouched_knockout_is_an_uppercut() -> void:
	var alpha: Commando = node("Units/Alpha")
	alpha.weapon_slung = true
	alpha.toggle_posture(SoldierModel.Posture.CROUCHED)
	await frames(30)
	var move := await _knock_out_from_side(alpha, node("Enemies/TrainingDummy"))
	assert_eq(move, Move.UPPERCUT, "pas de coup de pied accroupi")


func test_knife_slings_weapon_during_approach_then_takes_it_back() -> void:
	var bravo: Commando = node("Units/Bravo")
	hide_from_enemies(bravo)
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var model: SoldierModel = bravo.get_node("SoldierModel")
	bravo.global_position = dummy.global_position + Vector3(5, 0, 0)
	await frames(5)
	bravo.melee(dummy, Commando.MeleeKind.KNIFE)
	var max_sling := [0.0]
	var done := func() -> bool:
		if bravo.melee_target() != null:
			max_sling[0] = maxf(max_sling[0], model._sling)
		return dummy.is_dead and not bravo.is_striking()
	assert_gt(await frames_until(done, 400), -1, "mannequin tué")
	assert_almost_eq(max_sling[0], 1.0, 0.01, "arme à la bretelle pendant l'approche")
	await frames(80)
	assert_almost_eq(model._sling, 0.0, 0.01, "arme reprise en main")


func test_front_knife_makes_victim_scream() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var noises: Array[StringName] = []
	var listener := func(_at: Vector3, _radius: float, kind: StringName) -> void: noises.append(kind)
	EventBus.noise_emitted.connect(listener)
	# Devant lui (le regard est -Z local).
	alpha.global_position = dummy.global_position - dummy.global_basis.z * 2.5
	await frames(5)
	assert_false(dummy.is_behind(alpha.global_position))
	alpha.melee(dummy, Commando.MeleeKind.KNIFE)
	assert_gt(await frames_until(func() -> bool: return dummy.is_dead, 400), -1)
	EventBus.noise_emitted.disconnect(listener)
	assert_has(noises, &"scream", "cri de la victime poignardée de face")


func test_very_close_knockouts_are_elbow_or_knee() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.weapon_slung = true
	var moves: Array[int] = []
	for i in 4:
		if dummy.is_stunned():
			dummy.stunned_behavior.left = 0.01
			await frames(30)
		dummy.global_position = Vector3(-14, 0, -6)
		dummy.rotation.y = PI / 2.0
		# Au contact, sur son flanc.
		alpha.global_position = dummy.global_position + Vector3(0, 0, 0.85)
		await frames(5)
		var start := alpha.global_position
		alpha._start(StrikeGesture.new(alpha, dummy, Commando.MeleeKind.KNOCKOUT))
		var closest := [10.0]
		var done := func() -> bool:
			closest[0] = minf(closest[0], flat_distance(alpha.global_position, dummy.global_position))
			return dummy.is_stunned() and not alpha.is_striking()
		assert_gt(await frames_until(done, 300), -1, "assommé")
		moves.append(alpha.get_node("SoldierModel").strike_move)
		assert_lt(closest[0], flat_distance(start, dummy.global_position) - 0.1, "il s'avance au contact")
	for move in moves:
		assert_true(move in [Move.ELBOW, Move.KNEE], "coude ou genou : %s" % [moves])
	for i in range(1, moves.size()):
		assert_ne(moves[i], moves[i - 1], "en alternance")


func test_jab_then_hook_knocks_out_on_the_second_blow() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	alpha.weapon_slung = true
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = PI / 2.0
	alpha.global_position = dummy.global_position + Vector3(0, 0, 1.2)
	await frames(30)
	var gesture := StrikeGesture.new(alpha, dummy, Commando.MeleeKind.KNOCKOUT)
	gesture.forced_move = Move.JAB_HOOK
	alpha._start(gesture)
	var model: SoldierModel = dummy.get_node("SoldierModel")
	# Le direct touche sans assommer.
	assert_gt(await frames_until(func() -> bool: return model._hit_time < 0.05, 60), -1, "direct encaissé")
	assert_false(dummy.is_stunned(), "debout après le direct")
	assert_between(alpha._model.strike_progress, 0.25, 0.5, "au premier tiers de l'enchaînement")
	# Le crochet assomme.
	assert_gt(await frames_until(dummy.is_stunned, 60), -1, "crochet : assommé")
	assert_gt(alpha._model.strike_progress, 0.7, "au second coup")


func _middle_click(controller: PlayerController, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = at
	controller._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	controller._unhandled_input(release)


func test_sweep_from_the_melee_menu_floors_the_enemy_briefly() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	var controller: PlayerController = node("HUD/PlayerController")
	var menu := controller.radial_menu()
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = PI / 2.0
	alpha.global_position = dummy.global_position + Vector3(0, 0, 3)
	await frames(10)
	var camera := get_viewport().get_camera_3d()
	var at := camera.unproject_position(dummy.global_position + Vector3.UP * 1.0)
	SelectionManager.select([] as Array[Commando], false)
	_middle_click(controller, at)
	assert_false(menu.is_open(), "sans opérateur sélectionné : pas de menu")
	SelectionManager.select([alpha] as Array[Commando], false)
	_middle_click(controller, at)
	assert_true(menu.is_open(), "menu de corps à corps sur l'ennemi")
	assert_ne(menu.option_position(&"sweep"), Vector2.INF, "balayage proposé")
	assert_true(menu.choose(&"sweep"))
	var swept := [false]
	var down := func() -> bool:
		swept[0] = swept[0] or alpha._model.strike_move == Move.SWEEP and alpha._model.strike_progress >= 0.0
		return dummy.is_stunned()
	assert_gt(await frames_until(down, 400), -1, "jambes fauchées : au sol")
	assert_true(swept[0], "coup de pied bas")
	assert_almost_eq(dummy.stunned_behavior.left, dummy.stats.stun_duration * StrikeGesture.SWEEP_STUN_RATIO, 0.2, "sonné moins longtemps")
	assert_false(alpha.melee(dummy, Commando.MeleeKind.SWEEP), "on ne balaie pas un homme à terre")


func test_hip_throw_then_ground_punch() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = 0.0
	# De face (le mannequin n'est pas en alerte : pas de garde).
	alpha.global_position = dummy.global_position - dummy.global_basis.z * 3.0
	await frames(5)
	var start := dummy.global_position
	assert_true(alpha.melee(dummy, Commando.MeleeKind.THROW))
	assert_gt(await frames_until(dummy.is_stunned, 400), -1, "il bascule")
	assert_eq(alpha._model.strike_move, Move.HIP_THROW)
	assert_lt(dummy.stunned_behavior.left, StrikeGesture.THROW_STUN + 0.1, "sonné un instant seulement")
	var lifted := [0.0]
	var landed := func() -> bool:
		lifted[0] = maxf(lifted[0], dummy.global_position.y - start.y)
		return alpha._model.strike_move == Move.GROUND_PUNCH
	assert_gt(await frames_until(landed, 200), -1, "projeté au sol")
	assert_gt(lifted[0], 0.2, "soulevé par-dessus la hanche")
	assert_lt(dummy.global_position.y - start.y, 0.05, "retombé au sol")
	# Il le frappe au sol : assommé pour de bon.
	var punched := func() -> bool: return alpha._model.strike_move == Move.GROUND_PUNCH and dummy.stunned_behavior.left > StrikeGesture.THROW_STUN + 1.0
	assert_gt(await frames_until(punched, 200), -1, "frappe au sol")
	assert_gt(dummy.stunned_behavior.left, dummy.stats.stun_duration - 2.0, "assommé")
	assert_gt(await frames_until(func() -> bool: return not alpha.is_striking(), 200), -1)
	assert_true(dummy.is_stunned())
