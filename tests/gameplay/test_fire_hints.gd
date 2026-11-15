extends LevelTest
## Lignes de vue bloquées (4.8) : l'opérateur dit pourquoi il ne tire pas
## ou ne lance pas.

var alpha: Commando
var soldier: Enemy


func _setup() -> void:
	await load_level()
	alpha = node("Units/Alpha")
	soldier = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"))
	hide_from_enemies(alpha)
	SelectionManager.select([alpha] as Array[Commando])


func _label() -> Label3D:
	return alpha.get_node(^"Hint") as Label3D


func test_out_of_range_then_firing() -> void:
	await _setup()
	alpha.global_position = Vector3(0, 0, 8)
	park(soldier, Vector3(0, 0, 8 + alpha.stats.fire_range + 6.0))
	alpha.attack(soldier, false)
	await frames(3)
	assert_eq(alpha.current_hint(), Commando.Hint.OUT_OF_RANGE)
	await get_tree().process_frame
	assert_true(_label().visible)
	assert_eq(_label().text, "Hors de portée")
	alpha.stop()
	await frames(5)
	await get_tree().process_frame
	assert_eq(alpha.current_hint(), Commando.Hint.NONE, "plus d'ordre, plus de message")
	assert_false(_label().visible)


func test_wall_in_the_way() -> void:
	await _setup()
	# Le mur sud de l'enclos (-4, 0, -2) entre l'opérateur et l'ennemi.
	alpha.global_position = Vector3(-4, 0, 1)
	park(soldier, Vector3(-4, 0, -5))
	alpha.attack(soldier, false)
	await frames(3)
	assert_eq(alpha.current_hint(), Commando.Hint.OBSTACLE)


func test_refused_orders_say_why() -> void:
	await _setup()
	alpha.ammo_in_magazine = 0
	alpha.ammo_reserve = 0
	alpha._holstered_ammo = Vector2i.ZERO
	alpha.attack(soldier, false)
	assert_eq(alpha.current_hint(), Commando.Hint.NO_AMMO, "à sec")
	alpha.throwing_knives = 0
	assert_false(alpha.throw_knife(soldier))
	assert_eq(alpha.current_hint(), Commando.Hint.NO_KNIFE)
	alpha.grenades = 0
	assert_false(alpha.throw_grenade(Vector3(0, 0, 4)))
	assert_eq(alpha.current_hint(), Commando.Hint.NO_GRENADE)
	var cleared := false
	for i in 400:
		await get_tree().process_frame
		if alpha.current_hint() == Commando.Hint.NONE:
			cleared = true
			break
	assert_true(cleared, "le message s'efface")
