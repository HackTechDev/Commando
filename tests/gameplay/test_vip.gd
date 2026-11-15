extends LevelTest
## VIP à escorter (carte « Escorte ») : ordres (menu circulaire), suite,
## posture, cible des ennemis, évacuation et fin de mission.

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


func test_vip_waits_until_told_to_follow_and_copies_the_posture() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	await frames(30)
	assert_null(vip.leader, "il attend un ordre")
	assert_eq((vip.get_node("Status") as Label3D).text, "Attend")
	assert_false(vip.is_in_group(&"commandos"), "le VIP n'est pas un opérateur")
	assert_true(vip.find_child("Suit", true, false) != null, "tenue civile")
	assert_false(vip._model.is_armed, "sans arme")
	assert_false(vip.follow(null))
	assert_true(vip.follow(alpha))
	assert_eq(vip.leader, alpha)
	assert_string_contains((vip.get_node("Status") as Label3D).text, alpha.display_name)
	alpha.move_to(Vector3(0, 0, 13), false)
	var arrived := await frames_until(func() -> bool:
		return flat_distance(alpha.global_position, Vector3(0, 0, 13)) < 0.5 and vip.velocity.length() < 0.1, 600)
	assert_gt(arrived, -1, "Alpha arrivé, le VIP arrêté")
	var gap := flat_distance(vip.global_position, alpha.global_position)
	assert_between(gap, 1.0, 2.6, "le VIP se tient près de son guide")
	alpha.toggle_posture(SoldierModel.Posture.CROUCHED)
	await frames(3)
	assert_eq(vip.posture, SoldierModel.Posture.CROUCHED, "accroupi comme son guide")


func test_vip_stays_when_told_or_when_his_guide_dies() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	await frames(5)
	vip.follow(alpha)
	assert_true(vip.stay())
	assert_null(vip.leader)
	var start := vip.global_position
	alpha.move_to(alpha.global_position + Vector3(0, 0, 8), true)
	await frames(90)
	assert_lt(flat_distance(vip.global_position, start), 0.3, "il attend sur place")
	vip.follow(alpha)
	alpha.health.take_damage(1000.0)
	await frames(3)
	assert_null(vip.leader, "guide mort : il attend")
	assert_false(vip.follow(alpha), "on ne suit pas un mort")


func test_middle_click_on_the_vip_opens_his_orders_menu() -> void:
	await load_level(ESCORT)
	_park_enemies()
	var vip: Vip = node("Units/Vip")
	var alpha: Commando = node("Units/Alpha")
	var controller: PlayerController = node("HUD/PlayerController")
	var menu := controller.radial_menu()
	var camera := get_viewport().get_camera_3d()
	await frames(5)
	var at := camera.unproject_position(vip.global_position + Vector3.UP * 0.9)
	SelectionManager.select([] as Array[Commando], false)
	_middle_click(controller, at)
	assert_true(menu.is_open(), "menu ouvert sur le VIP")
	assert_false(menu.choose(&"follow"), "aucun opérateur sélectionné")
	menu.close()
	SelectionManager.select([alpha] as Array[Commando], false)
	_middle_click(controller, at)
	assert_true(menu.is_open())
	var option := menu.option_position(&"follow")
	assert_ne(option, Vector2.INF)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = option
	menu._gui_input(click)
	assert_false(menu.is_open(), "refermé après le choix")
	assert_eq(vip.leader, alpha, "il suit l'opérateur sélectionné")
	# Ailleurs que sur le VIP, ou en glissant (caméra) : pas de menu.
	_middle_click(controller, at + Vector2(300, 0))
	assert_false(menu.is_open())
	_middle_click(controller, at, Vector2(40, 0))
	assert_false(menu.is_open(), "glisser déplace la caméra")


func _middle_click(controller: PlayerController, at: Vector2, drag := Vector2.ZERO) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = at
	controller._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = at + drag
	controller._unhandled_input(release)


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
	assert_true(vip.follow(alpha))
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
