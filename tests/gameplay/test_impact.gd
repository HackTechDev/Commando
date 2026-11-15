extends LevelTest
## Retour visuel des tirs : impact des balles manquées sur les obstacles,
## gerbe et chiffre de dégâts sur une cible touchée.


func _find(name_prefix: String) -> Node:
	for child in level.get_children():
		if child.name.begins_with(name_prefix):
			return child
	return null


func test_missed_bullet_stops_on_the_first_obstacle() -> void:
	await load_level()
	await frames(2)
	# Mur sud de la cour du sandbox, en z = -2 (épaisseur 0,5 m).
	var end := ShotImpact.land(level, Vector3(-4, 1.3, 3), Vector3(-4, 1.3, 1))
	assert_almost_eq(end.z, -1.75, 0.05, "arrêtée sur la face du mur")
	assert_not_null(_find("Impact"), "gerbe de poussière")
	# Rien derrière : elle continue un peu au-delà du point visé.
	var free := ShotImpact.land(level, Vector3(0, 1.3, 30), Vector3(0, 1.3, 40))
	assert_almost_eq(free.z, 44.0, 0.05)


func test_damage_number_rises_and_fades() -> void:
	await load_level()
	var label := ShotImpact.damage_label(level, Vector3(0, 2, 0), 25.0, ShotImpact.DAMAGE_ENEMY)
	assert_eq(label.text, "-25")
	await frames(20)
	assert_gt(label.global_position.y, 2.2, "il monte")
	assert_lt(label.modulate.a, 1.0, "il s'efface")
	await frames(60)
	assert_false(is_instance_valid(label), "puis disparaît")


func test_enemy_hit_shows_the_damage_on_the_operator() -> void:
	await load_level()
	var alpha: Commando = node("Units/Alpha")
	var enemy: Enemy = node("Enemies/Soldier1")
	park(node("Enemies/TrainingDummy"))
	for name in ["Bravo", "Charlie"]:
		hide_from_enemies(node("Units/" + name))
	alpha.global_position = Vector3(0, 0, 2)
	enemy.stationary = true
	enemy.global_position = Vector3(0, 0, -6)
	enemy.rotation.y = PI
	var health := alpha.health.health
	var hurt := await frames_until(func() -> bool: return alpha.health.health < health, 600)
	assert_gt(hurt, -1, "touché")
	var label := _find("Damage") as Label3D
	assert_not_null(label, "chiffre des dégâts")
	if label:
		assert_eq(label.modulate.r, ShotImpact.DAMAGE_FRIEND.r)
