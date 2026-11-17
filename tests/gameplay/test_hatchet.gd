extends LevelTest
## Hachette : arme de corps à corps qui tue même de face, sans cri mais
## bruyamment ; achève un ennemi au sol.

var _noises: Array = []
var _roster: OperatorRoster


func before_each() -> void:
	super()
	_noises.clear()
	_roster = OperatorRoster.new()
	_roster.operators[0].hatchet = 1
	OperatorRoster.use(_roster)
	await load_level()
	park(node("Enemies/Soldier1"))
	EventBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	OperatorRoster.use(OperatorRoster.new())
	super()


func _on_noise(_at: Vector3, _radius: float, kind: StringName) -> void:
	_noises.append(kind)


func test_hatchet_kills_from_the_front_without_a_scream() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_eq(alpha.hatchets, 1, "équipée")
	# Pris de court (il ne l'a pas vu venir) : pas de garde levée.
	hide_from_enemies(alpha)
	alpha.global_position = dummy.global_position - dummy.global_basis.z * 3.0
	await frames(3)
	assert_true(alpha.melee(dummy, Commando.MeleeKind.HATCHET), "ordre accepté")
	var model: SoldierModel = alpha.get_node("SoldierModel")
	assert_gt(await frames_until(func() -> bool: return model.strike_move == SoldierModel.StrikeMove.HATCHET_CHOP and model._hatchet.visible, 300), -1, "hachette en main")
	assert_gt(await frames_until(func() -> bool: return dummy.is_dead, 300), -1, "tué de face")
	assert_has(_noises, &"melee", "le choc s'entend")
	assert_does_not_have(_noises, &"scream", "pas de cri")
	assert_gt(await frames_until(func() -> bool: return not model._hatchet.visible, 200), -1, "rangée après le coup")


func test_hatchet_finishes_a_stunned_enemy() -> void:
	var alpha: Commando = node("Units/Alpha")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	hide_from_enemies(alpha)
	dummy.knock_out()
	alpha.global_position = dummy.global_position + Vector3(2.0, 0, 0)
	await frames(3)
	assert_true(alpha.melee(dummy, Commando.MeleeKind.HATCHET))
	assert_gt(await frames_until(func() -> bool: return dummy.is_dead, 400), -1, "achevé au sol")


func test_without_a_hatchet_the_order_is_refused() -> void:
	var bravo: Commando = node("Units/Bravo")
	var dummy: Enemy = node("Enemies/TrainingDummy")
	assert_eq(bravo.hatchets, 0)
	assert_false(bravo.melee(dummy, Commando.MeleeKind.HATCHET))
	assert_string_contains(bravo.hint_text(), "Pas de hachette")
	SelectionManager.select([bravo] as Array[Commando])
	var option: Dictionary = PlayerController.melee_options(dummy).filter(func(o: Dictionary) -> bool: return o.id == &"hatchet")[0]
	assert_false(option.enabled, "grisée sans hachette")
	SelectionManager.select([node("Units/Alpha")] as Array[Commando])
	option = PlayerController.melee_options(dummy).filter(func(o: Dictionary) -> bool: return o.id == &"hatchet")[0]
	assert_true(option.enabled, "proposée avec")
	SelectionManager.clear()


func test_hatchet_is_saved_and_bounded() -> void:
	var alpha: Commando = node("Units/Alpha")
	var before := alpha.save_state()
	alpha.hatchets = 0
	alpha.load_state(before)
	assert_eq(alpha.hatchets, 1)
	assert_eq(OperatorProfile.from_dict({"hatchet": 5}, 0).hatchet, 1, "une seule")
	assert_gt(GearCatalog.load_of(_roster.operators[0]), GearCatalog.load_of(OperatorProfile.defaults(0)), "elle pèse")
