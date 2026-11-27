extends LevelTest
## Déguisement pris sur l'ennemi : uniforme d'un soldat assommé
## (`DisguiseGesture`), repérage ralenti par les soldats, pas par
## l'officier.

const MAP := "res://scenes/levels/mobile_command/mobile_command.tscn"

var unit: Commando
var guard: Enemy


func before_each() -> void:
	super()
	await load_level(MAP)
	unit = level.get_tree().get_nodes_in_group(&"commandos")[0]
	guard = node("Enemies/MidPatrol")
	guard.global_position = unit.global_position + Vector3(2.5, 0, 0)
	await wait_physics_frames(1)
	guard.knock_out()


func _dress() -> void:
	assert_true(unit.melee(guard, Commando.MeleeKind.DISGUISE))
	await frames_until(func() -> bool: return unit.disguised, 60 * 10)


func test_menu_offers_the_uniform_of_a_downed_soldier() -> void:
	var entry: Dictionary = PlayerController.melee_options(guard).filter(func(o: Dictionary) -> bool: return o["id"] == &"disguise")[0]
	assert_true(entry["enabled"])
	var dog := node("Enemies/Dog") as Enemy
	dog.knock_out()
	assert_false(Enemy.can_be_stripped(dog), "pas d'uniforme sur un chien")


func test_operator_wears_the_uniform() -> void:
	await _dress()
	assert_true(unit.disguised)
	assert_true(guard.stripped)
	assert_false(Enemy.can_be_stripped(guard), "déjà dévêtu")
	assert_eq(unit.blend_factor(), Commando.BLEND_DISGUISE)
	unit.posture = SoldierModel.Posture.CROUCHED
	assert_eq(unit.blend_factor(), 1.0, "accroupi, il ne passe plus pour un garde")


func test_soldier_is_fooled_but_not_the_officer() -> void:
	await _dress()
	unit.posture = SoldierModel.Posture.STANDING
	for other in level.get_tree().get_nodes_in_group(&"commandos"):
		if other != unit:
			(other as Node3D).global_position += Vector3(0, 0, 40)
	guard.global_position += Vector3(0, 0, 45)
	var results := {}
	for name: String in ["StairGuard", "OpsOfficer"]:
		var watcher := node("Enemies/" + name) as Enemy
		watcher.global_position = unit.global_position + Vector3(0, 0, -9)
		watcher.look_at(unit.global_position, Vector3.UP)
		watcher.detection = 0.0
		await wait_seconds(1.5)
		results[name] = watcher.detection
		watcher.global_position += Vector3(0, 0, -60)
	assert_lt(results["StairGuard"], 0.5, "le soldat s'y trompe")
	assert_gt(results["OpsOfficer"], 0.8, "l'officier ne s'y trompe pas")
