extends LevelTest
## Écran de fin (5.6) : après un échec, proposer de recommencer.

var hud: Hud


func _setup() -> void:
	EndScreen.enabled = true
	await load_level()
	hud = node("HUD")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))


func after_each() -> void:
	EndScreen.enabled = false
	get_tree().paused = false
	super()


func _wait_open() -> bool:
	for i in 300:
		await get_tree().process_frame
		if hud.end_screen.is_open():
			return true
	return false


func test_operator_death_offers_a_restart() -> void:
	await _setup()
	var bravo: Commando = node("Units/Bravo")
	bravo.health.take_damage(1000.0)
	assert_true(await _wait_open(), "écran de fin affiché")
	assert_false(hud.end_screen.success)
	assert_eq(hud.end_screen.message, "ÉCHEC — Bravo tué")
	assert_true(get_tree().paused, "jeu en pause")
	var old := level
	(hud.end_screen.find_child("Restart", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	level = get_tree().current_scene
	assert_ne(level, old, "mission recommencée")
	if level is LevelRoot and not level.is_level_ready:
		await wait_for_signal(level.level_ready, 30.0)
	assert_false(get_tree().paused)
	assert_eq(get_tree().get_nodes_in_group(&"commandos").size(), 3, "tout le monde est revenu")


func test_continue_playing_after_the_end() -> void:
	await _setup()
	EventBus.mission_ended.emit(true, "RÉUSSITE — test")
	assert_true(await _wait_open())
	assert_true(hud.end_screen.success)
	(hud.end_screen.find_child("Continue", true, false) as Button).pressed.emit()
	assert_false(hud.end_screen.is_open())
	assert_false(get_tree().paused, "la partie continue")
	# Un autre événement de fin ne le rouvre pas.
	(node("Units/Alpha") as Commando).health.take_damage(1000.0)
	await frames(10)
	for i in 120:
		await get_tree().process_frame
	assert_false(hud.end_screen.is_open())
