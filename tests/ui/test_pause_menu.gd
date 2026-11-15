extends LevelTest
## Menu pause (Échap) et ses pages.

var controller: PlayerController
var hud: Hud


func _setup() -> void:
	await load_level()
	controller = node("HUD/PlayerController")
	hud = node("HUD")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))


func after_each() -> void:
	get_tree().paused = false
	super()


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_escape_opens_and_closes_the_pause_menu() -> void:
	await _setup()
	controller._unhandled_input(_escape())
	assert_true(hud.pause_menu.is_open())
	assert_true(get_tree().paused)
	hud.pause_menu._unhandled_input(_escape())
	assert_false(hud.pause_menu.is_open())
	assert_false(get_tree().paused, "la partie reprend")


func test_escape_first_cancels_an_armed_action() -> void:
	await _setup()
	SelectionManager.select([node("Units/Alpha")] as Array[Commando])
	controller.toggle_pending_action(PlayerController.ACTION_KNIFE)
	controller._unhandled_input(_escape())
	assert_eq(controller.pending_action, PlayerController.ACTION_NONE)
	assert_false(hud.pause_menu.is_open())


func test_help_from_the_menu_comes_back_to_it() -> void:
	await _setup()
	hud.pause_menu.open()
	(hud.pause_menu.find_child("Help", true, false) as Button).pressed.emit()
	assert_true(hud.help.is_open())
	assert_true(get_tree().paused)
	hud.help.close()
	assert_true(hud.pause_menu.is_open(), "retour au menu pause")
	assert_true(get_tree().paused)
	(hud.pause_menu.find_child("Resume", true, false) as Button).pressed.emit()
	assert_false(get_tree().paused)


func test_cancelled_confirmation_comes_back_to_the_menu() -> void:
	await _setup()
	hud.pause_menu.open()
	(hud.pause_menu.find_child("Menu", true, false) as Button).pressed.emit()
	assert_true(hud.menu_dialog.visible)
	hud.menu_dialog.canceled.emit()
	hud.menu_dialog.hide()
	assert_true(hud.pause_menu.is_open())
	hud.pause_menu.close()
	assert_false(get_tree().paused)


func test_restart_reloads_the_level() -> void:
	await _setup()
	var old := level
	var alpha: Commando = node("Units/Alpha")
	alpha.global_position += Vector3(3, 0, 0)
	hud.pause_menu.open()
	(hud.pause_menu.find_child("Restart", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	level = get_tree().current_scene
	assert_ne(level, old, "nouvelle scène")
	if level is LevelRoot and not level.is_level_ready:
		await wait_for_signal(level.level_ready, 30.0)
	assert_false(get_tree().paused)
