extends LevelTest
## Journal d'objectifs, minicarte, options (5.7).

const SETTINGS_FILE := "user://test_settings.cfg"

var hud: Hud
var collected: Array = []


func _setup(path: String = SANDBOX) -> void:
	await load_level(path)
	hud = node("HUD")
	collected.clear()
	EventBus.mission_ended.connect(_collect)


func after_each() -> void:
	if EventBus.mission_ended.is_connected(_collect):
		EventBus.mission_ended.disconnect(_collect)
	get_tree().paused = false
	Settings.use_file(Settings.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	super()


func _collect(success: bool, message: String) -> void:
	collected.append([success, message])


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	(node("HUD/PlayerController") as PlayerController)._unhandled_input(event)


func test_neutralizing_every_enemy_completes_the_training() -> void:
	await _setup()
	var objectives := hud.objectives
	assert_eq(objectives.entries.size(), 2, "objectifs du terrain d'essai")
	assert_eq(objectives.status_of("all_enemies_down"), Objectives.Status.PENDING)
	(node("Enemies/Soldier1") as Enemy).health.take_damage(1000.0)
	(node("Enemies/TrainingDummy") as Enemy).knock_out()
	var done := await frames_until(func() -> bool: return objectives.is_over, 120)
	assert_gt(done, -1, "mission terminée")
	assert_eq(objectives.status_of("all_enemies_down"), Objectives.Status.DONE)
	assert_eq(objectives.status_of("no_operator_lost"), Objectives.Status.DONE, "condition remplie à la réussite")
	assert_eq(collected, [[true, "RÉUSSITE — sentinelles neutralisées"]])


func test_losing_an_operator_fails_the_mission() -> void:
	await _setup()
	park(node("Enemies/Soldier1"))
	(node("Units/Charlie") as Commando).health.take_damage(1000.0)
	assert_eq(hud.objectives.status_of("no_operator_lost"), Objectives.Status.FAILED)
	assert_eq(collected, [[false, "ÉCHEC — Charlie tué"]])
	assert_true(hud.objectives_panel.lines().has("✗  Ne perdre aucun opérateur"))


func test_extraction_is_announced_by_the_zone() -> void:
	await _setup("res://scenes/levels/escort/escort.tscn")
	var objectives := hud.objectives
	assert_true(objectives.has_objective("vip_extracted"))
	EventBus.objective_completed.emit(&"vip_extracted")
	assert_true(collected.is_empty(), "la zone annonce elle-même la fin")
	EventBus.mission_ended.emit(true, "RÉUSSITE — VIP évacué")
	assert_eq(objectives.status_of("vip_alive"), Objectives.Status.DONE)


func test_journal_and_minimap_toggle() -> void:
	await _setup()
	var panel := hud.objectives_panel
	assert_true(panel.visible, "affiché au début")
	_press(&"toggle_objectives")
	assert_false(panel.visible)
	_press(&"toggle_objectives")
	assert_true(panel.visible)
	assert_true(hud.minimap.visible)
	_press(&"toggle_minimap")
	assert_false(hud.minimap.visible)
	_press(&"toggle_minimap")
	assert_true(hud.minimap.visible)


func test_minimap_click_centers_the_camera() -> void:
	await _setup()
	var map := hud.minimap
	var point := Vector3(4.0, 0.0, -6.0)
	assert_lt(map.to_world(map.to_map(point)).distance_to(point), 0.01, "aller-retour")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.to_map(point)
	map._gui_input(click)
	var rig := level.find_child("CameraRig", true, false)
	var target: Vector3 = rig._target_position
	assert_lt(Vector2(target.x - point.x, target.z - point.z).length(), 0.5, "caméra centrée")


func test_options_are_saved_and_lead_back_to_the_pause_menu() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	Settings.use_file(SETTINGS_FILE)
	await _setup()
	hud.pause_menu.open()
	(hud.pause_menu.find_child("Options", true, false) as Button).pressed.emit()
	assert_true(hud.options.is_open())
	var slider := hud.options.find_child("VolumeSFX", true, false) as HSlider
	slider.value = 0.5
	assert_almost_eq(Settings.volume(&"SFX"), 0.5, 0.001)
	(hud.options.find_child("EdgeScroll", true, false) as CheckBox).button_pressed = false
	assert_false(Settings.edge_scroll())
	hud.options.close()
	assert_true(hud.pause_menu.is_open(), "retour au menu pause")
	hud.pause_menu.close()
	assert_false(get_tree().paused)
