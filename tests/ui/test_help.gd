extends LevelTest
## Page d'aide en cours de partie (touche H) : ouverture, pause, fermeture,
## touches lues dans l'InputMap.

var controller: PlayerController
var help: HelpOverlay


func _setup() -> void:
	await load_level()
	controller = node("HUD/PlayerController")
	help = node("HUD/HelpOverlay")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))


func after_each() -> void:
	get_tree().paused = false
	super()


func _event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_help_opens_with_its_key_and_pauses_the_game() -> void:
	await _setup()
	assert_false(help.is_open())
	controller._unhandled_input(_event(&"toggle_help"))
	assert_true(help.is_open(), "page ouverte")
	assert_true(get_tree().paused, "jeu en pause")
	# Pendant l'aide, le contrôleur n'accepte aucun ordre.
	controller._unhandled_input(_event(&"tactical_pause"))
	assert_false(controller.tactical_paused)
	help._unhandled_input(_event(&"toggle_help"))
	assert_false(help.is_open(), "refermée par la même touche")
	assert_false(get_tree().paused, "la partie reprend")


func test_escape_or_click_closes_the_help() -> void:
	await _setup()
	help.open()
	help._unhandled_input(_event(&"ui_cancel"))
	assert_false(help.is_open(), "Échap")
	help.open()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	help._gui_input(click)
	assert_false(help.is_open(), "clic")
	assert_false(get_tree().paused)


func test_help_keeps_the_tactical_pause() -> void:
	await _setup()
	controller.set_tactical_pause(true)
	controller._unhandled_input(_event(&"toggle_help"))
	assert_true(help.is_open(), "ouverte pendant la pause tactique")
	help.close()
	assert_true(get_tree().paused, "toujours en pause tactique")
	assert_true(controller.tactical_paused)
	controller.set_tactical_pause(false)


func test_help_lists_the_keys_of_the_input_map() -> void:
	await _setup()
	assert_eq(help.keys_for("Recharger"), KeyNames.label(&"reload"))
	assert_eq(help.keys_for("Arme secondaire / principale"), KeyNames.label(&"switch_weapon"))
	assert_ne(KeyNames.label(&"switch_weapon"), KeyNames.label(&"toggle_help"), "H n'est plus l'arme secondaire")
	assert_string_contains(help.keys_for("Grappin, puis clic sur un point en hauteur"), KeyNames.label(&"action_grapple"))
	# Toutes les actions citées existent dans l'InputMap.
	for section: Array in HelpOverlay.SECTIONS:
		for line: Array in section[1]:
			for key: Variant in line[0]:
				if key is StringName:
					assert_true(InputMap.has_action(key), "action %s" % key)
