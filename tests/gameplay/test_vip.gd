extends LevelTest
## VIP à escorter (carte « Escorte ») : ralliement, suite, posture, cible des
## ennemis, évacuation et fin de mission.

const ESCORT := "res://scenes/levels/escort/escort.tscn"

var _ended: Array = []


func before_each() -> void:
	super()
	_ended.clear()
	EventBus.mission_ended.connect(_on_mission_ended)


func after_each() -> void:
	EventBus.mission_ended.disconnect(_on_mission_ended)
	super()


func _on_mission_ended(success: bool, message: String) -> void:
	_ended.append([success, message])


func _park_enemies() -> void:
	var spot := 0
	for enemy: Enemy in node("Enemies").get_children():
		park(enemy, Vector3(-28 + spot * 2.0, 0, 28))
		spot += 1


func test_vip_follows_the_nearest_operator_and_copies_his_posture() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	await frames(5)
	assert_not_null(vip.leader, "rallié à un opérateur proche")
	assert_false(vip.is_in_group(&"commandos"), "le VIP n'est pas un opérateur")
	assert_true(vip.find_child("Suit", true, false) != null, "tenue civile")
	assert_false(vip._model.is_armed, "sans arme")
	# Les deux autres partent loin : Alpha reste le seul guide possible.
	for other: Commando in [node("Units/Bravo"), node("Units/Charlie")]:
		other.global_position += Vector3(-24, 0, 0)
	vip.leader = null
	await frames(2)
	assert_eq(vip.leader, alpha)
	alpha.move_to(Vector3(0, 0, 13), false)
	var arrived := await frames_until(func() -> bool:
		return flat_distance(alpha.global_position, Vector3(0, 0, 13)) < 0.5 and vip.velocity.length() < 0.1, 600)
	assert_gt(arrived, -1, "Alpha arrivé, le VIP arrêté")
	var gap := flat_distance(vip.global_position, alpha.global_position)
	assert_between(gap, 1.0, 2.6, "le VIP se tient près de son guide")
	alpha.toggle_posture(SoldierModel.Posture.CROUCHED)
	await frames(3)
	assert_eq(vip.posture, SoldierModel.Posture.CROUCHED, "accroupi comme son guide")


func test_vip_waits_alone_when_operators_leave() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	await frames(5)
	var start := vip.global_position
	for name in ["Alpha", "Bravo", "Charlie"]:
		var unit: Commando = node("Units/" + name)
		unit.global_position += Vector3(0, 0, -20)
	await frames(60)
	assert_null(vip.leader, "guide perdu")
	assert_lt(flat_distance(vip.global_position, start), 0.3, "il attend sur place")


func test_enemies_target_the_vip_and_his_death_fails_the_mission() -> void:
	await load_level(ESCORT)
	_park_enemies()
	for name in ["Alpha", "Bravo", "Charlie"]:
		hide_from_enemies(node("Units/" + name))
	var vip: Vip = node("Units/Vip")
	var sentry: Enemy = node("Enemies/Sentry")
	sentry.set_physics_process(true)
	# Face au VIP, à portée de tir.
	sentry.global_position = vip.global_position + Vector3(0, 0, -8)
	sentry.rotation.y = PI
	var died := await frames_until(func() -> bool: return vip.is_dead, 1200)
	assert_gt(died, -1, "le VIP est abattu")
	await frames(2)
	assert_eq(sentry._target, null, "plus de cible une fois le VIP mort")
	assert_eq(_ended.size(), 1)
	assert_false(_ended[0][0], "mission échouée")
	assert_string_contains(_ended[0][1], "VIP")


func test_vip_led_into_the_zone_completes_the_mission() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	var zone: ExtractionZone = node("Extraction")
	# Au dernier abri avant la zone, le VIP sur ses talons.
	alpha.global_position = Vector3(18, 0, -11)
	vip.global_position = Vector3(18, 0, -9)
	await frames(5)
	assert_eq(vip.leader, alpha)
	assert_eq(zone.progress(), Vector2i(0, 1))
	alpha.move_to(zone.global_position + Vector3(-2, 0, 0), true)
	var evacuated := await frames_until(func() -> bool: return vip.is_evacuated, 900)
	assert_gt(evacuated, -1, "le VIP entre dans la zone")
	assert_eq(zone.progress(), Vector2i(1, 1))
	assert_true(zone.is_over)
	assert_eq(_ended.size(), 1)
	assert_true(_ended[0][0], "mission réussie")
	assert_false(vip.is_in_group(&"vips"), "à l'abri, plus pris pour cible")
	# Il reste dans la zone même si son guide repart.
	alpha.move_to(Vector3(18, 0, -11), true)
	await frames(180)
	assert_lt(flat_distance(vip.global_position, zone.global_position), 3.0, "il reste dans la zone")
