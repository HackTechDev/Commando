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
		dummy._stun_left = 0.01
		await frames(30)
	dummy.global_position = Vector3(-14, 0, -6)
	dummy.rotation.y = PI / 2.0
	alpha.global_position = dummy.global_position + Vector3(0, 0, 3)
	await frames(5)
	alpha.melee(dummy, Commando.MeleeKind.KNOCKOUT)
	var done := func() -> bool: return dummy.is_stunned() and alpha._strike_left <= 0.0
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
		assert_true(move in [Move.UPPERCUT, Move.FRONT_KICK, Move.ROUNDHOUSE, Move.SIDE_KICK], "coup à mains nues ou de pied")
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
		if bravo._melee_target != null:
			max_sling[0] = maxf(max_sling[0], model._sling)
		return dummy.is_dead and bravo._strike_left <= 0.0
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
