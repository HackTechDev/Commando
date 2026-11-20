extends LevelTest
## Didacticiel : ateliers, fenêtre d'astuces, objectifs et fin.

const TUTORIAL := "res://scenes/levels/tutorial/tutorial.tscn"

var _ended: Array = []


func before_each() -> void:
	super()
	_ended.clear()
	await load_level(TUTORIAL)
	EventBus.mission_ended.connect(_on_mission_ended)


func after_each() -> void:
	EventBus.mission_ended.disconnect(_on_mission_ended)
	super()


func _on_mission_ended(success: bool, message: String) -> void:
	_ended.append([success, message])


func _panel() -> TutorialPanel:
	return get_tree().get_first_node_in_group(TutorialPanel.GROUP) as TutorialPanel


func _station(station_name: String) -> TutorialStation:
	return node("Stations/" + station_name)


func _objective_status(id: String) -> Objectives.Status:
	return (node("HUD") as Hud).objectives.status_of(id)


func test_first_tip_is_shown_at_start() -> void:
	var panel := _panel()
	assert_not_null(panel, "fenêtre d'astuces")
	assert_eq(panel.shown_title(), "Se déplacer")
	assert_string_contains(panel.shown_text(), "Clic droit au sol")
	assert_eq(TutorialStation.all_in(get_tree()).size(), 8, "huit ateliers")
	assert_eq((node("HUD") as Hud).objectives.entries.size(), 8, "un objectif par atelier")
	assert_true(LevelCatalog.find(TUTORIAL).get("title", "") == "Didacticiel", "au catalogue")


func test_tip_texts_name_the_keys() -> void:
	for station in TutorialStation.all_in(get_tree()):
		var shown := TutorialPanel.format(station.text + station.done_text)
		assert_false(shown.contains("{"), "%s : toutes les touches remplacées" % station.title)
		assert_false(shown.contains("?[/b]"), "%s : actions connues de l'InputMap" % station.title)
	assert_string_contains(TutorialPanel.format("{dive}"), KeyNames.label(&"dive"))


func test_reaching_the_circle_completes_the_exercise() -> void:
	var alpha: Commando = node("Units/Alpha")
	var station := _station("Move")
	assert_false(station.is_done)
	alpha.global_position = station.goal_point()
	assert_gt(await frames_until(func() -> bool: return station.is_done, 30), -1, "exercice réussi")
	assert_eq(_objective_status("tuto_move"), Objectives.Status.DONE, "objectif rempli")
	assert_string_contains(_panel().shown_text(), "Exercice réussi")
	assert_eq(station.get_node("Sign").text, "✓")


func test_entering_a_station_shows_its_tip() -> void:
	var alpha: Commando = node("Units/Alpha")
	var panel := _panel()
	panel.hide_tip()
	alpha.global_position = _station("Run").global_position
	assert_gt(await frames_until(func() -> bool: return panel.shown_title() == "Courir et se baisser", 30), -1, "astuce de l'atelier")
	assert_eq(panel._step.text, "2 / 8")
	panel.hide_tip()
	assert_eq(panel.shown_text(), "", "masquée")
	assert_true(panel._reopen.visible, "bouton pour la rouvrir")
	panel.reopen()
	assert_eq(panel.shown_title(), "Courir et se baisser")


func test_climb_needs_the_roof() -> void:
	var alpha: Commando = node("Units/Alpha")
	var station := _station("Climb")
	var roof := station.goal_point()
	assert_almost_eq(roof.y, 3.0, 0.01, "cercle sur le toit")
	alpha.global_position = roof + Vector3(0, 0.2, 0)
	assert_gt(await frames_until(func() -> bool: return station.is_done, 30), -1, "sur le toit")


func test_dummies_are_blind_and_count_once_down() -> void:
	var alpha: Commando = node("Units/Alpha")
	var station := _station("Melee")
	var front: Enemy = node("Enemies/DummyFront")
	alpha.global_position = front.global_position - front.global_basis.z * 2.0
	await frames(60)
	assert_eq(front.state, Enemy.State.PATROL, "le mannequin ne voit rien")
	for path in station.targets:
		var dummy := station.get_node(path) as Enemy
		dummy.knock_out()
		dummy._stun_left = 0.05
	assert_gt(await frames_until(func() -> bool: return station.is_done, 30), -1, "trois mannequins neutralisés")
	await frames(10)
	assert_false(front.is_stunned(), "relevé, l'exercice reste réussi")
	assert_true(station.is_done)


func test_the_end_needs_every_exercise() -> void:
	var alpha: Commando = node("Units/Alpha")
	var finish := _station("Finish")
	alpha.global_position = finish.goal_point()
	assert_gt(await frames_until(func() -> bool: return _panel().shown_text().contains("Il reste"), 30), -1, "il reste des exercices")
	assert_eq(_ended.size(), 0, "pas encore fini")
	for station in TutorialStation.all_in(get_tree()):
		if station != finish:
			station.complete()
	assert_gt(await frames_until(func() -> bool: return not _ended.is_empty(), 30), -1, "fin du didacticiel")
	assert_true(_ended[0][0], "réussite")
	assert_eq(_objective_status("tuto_end"), Objectives.Status.DONE)


func test_the_roof_is_reached_by_the_ladder_and_targets_can_be_shot() -> void:
	var alpha: Commando = node("Units/Alpha")
	var climb := _station("Climb")
	alpha.global_position = climb.global_position
	await frames(5)
	alpha.move_to(climb.goal_point(), true)
	assert_gt(await frames_until(func() -> bool: return climb.is_done, 1200), -1, "monté par l'échelle")
	# Stand de tir : depuis l'atelier, Alpha abat une cible.
	var shoot := _station("Shoot")
	var target: Enemy = node("Enemies/TargetMiddle")
	alpha.global_position = shoot.global_position
	await frames(5)
	alpha.attack(target, false)
	assert_gt(await frames_until(func() -> bool: return target.is_dead, 1800), -1, "cible abattue")
