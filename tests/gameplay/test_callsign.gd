extends LevelTest
## Indicatif (call-sign) affiché au-dessus de chaque opérateur.


func test_each_operator_shows_its_callsign() -> void:
	await load_level()
	for unit: Commando in node("Units").get_children():
		var label := unit.get_node_or_null(^"Callsign") as Label3D
		assert_not_null(label, "indicatif de %s" % unit.name)
		if label == null:
			continue
		assert_eq(label.text, unit.display_name)
		assert_true(label.visible)
		assert_gt(label.global_position.y, unit.global_position.y + 1.7, "au-dessus de la tête")


func test_callsign_follows_selection_and_death() -> void:
	await load_level()
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"))
	var alpha: Commando = node("Units/Alpha")
	var label := alpha.get_node(^"Callsign") as Label3D
	SelectionManager.select([alpha] as Array[Commando])
	assert_eq(label.modulate, Commando.CALLSIGN_SELECTED, "mis en valeur une fois sélectionné")
	SelectionManager.clear()
	assert_eq(label.modulate, Commando.CALLSIGN_COLOR)
	var standing := label.position.y
	alpha.toggle_posture(SoldierModel.Posture.PRONE)
	await frames(30)
	assert_lt(label.position.y, standing, "plus bas quand il rampe")
	alpha.health.take_damage(1000.0)
	await frames(2)
	assert_false(label.visible, "effacé à la mort")
