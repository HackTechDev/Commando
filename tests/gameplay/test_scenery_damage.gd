extends LevelTest
## Dégâts au décor (2.14 a) : caisses détruites tout près d'une explosion,
## projetées plus loin ; murs fragiles abattus.

const MASK_OCCLUDERS := 0b10


func before_each() -> void:
	super()
	await load_level()
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"), Vector3(25, 0, 25))


func _blast(at: Vector3, radius: float = 4.0) -> void:
	Explosion.detonate(get_tree().current_scene, at, radius, 0.0, 10.0)
	await frames(30)


func _blocked(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_OCCLUDERS)
	return not get_tree().root.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func test_a_crate_next_to_the_blast_is_destroyed() -> void:
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	var at := crate.global_position + Vector3(-1.0, 0, 0)
	var saved := crate.save_state()
	await _blast(at)
	assert_true(crate.is_broken, "détruite")
	assert_false(crate.is_in_group(&"climbables"), "on ne peut plus y monter")
	assert_false(_blocked(at + Vector3(0, 0.6, 0), crate.global_position + Vector3(1.5, 0.6, 0)), "plus d'obstacle")
	assert_gt(get_tree().current_scene.find_children("*", "Debris", true, false).size(), 0, "éclats")
	crate.load_state(saved)
	await frames(3)
	assert_false(crate.is_broken, "rechargée intacte")
	assert_true(crate.is_in_group(&"climbables"))


func test_a_crate_further_away_is_thrown_back() -> void:
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	var start := crate.global_position
	var at := start + Vector3(-3.0, 0, 0)
	await _blast(at)
	assert_false(crate.is_broken, "intacte")
	assert_gt(crate.global_position.x - start.x, 0.3, "projetée loin de l'explosion")
	assert_almost_eq(crate.global_position.z, start.z, 0.05, "dans l'axe du souffle")


func test_a_crate_outside_the_blast_or_occupied_does_not_move() -> void:
	var crate: Climbable = node("NavigationRegion3D/Crate4")
	var start := crate.global_position
	await _blast(start + Vector3(-6.0, 0, 0))
	assert_eq(crate.global_position, start, "hors du souffle")
	crate.occupant = node("Units/Alpha")
	await _blast(start + Vector3(-1.0, 0, 0))
	assert_false(crate.is_broken, "quelqu'un dessus : elle tient")
	crate.occupant = null


func test_fragile_wall_breaks_and_opens_a_way() -> void:
	var wall: FragileWall = node("NavigationRegion3D/FragileWall")
	var front := wall.global_position + Vector3(0, 1.0, -2.0)
	var back := wall.global_position + Vector3(0, 1.0, 2.0)
	assert_true(_blocked(front, back), "le mur arrête la vue")
	await _blast(wall.global_position + Vector3(0, 0, -6.0))
	assert_false(wall.is_broken, "trop loin")
	var saved := wall.save_state()
	await _blast(wall.global_position + Vector3(0.5, 0, -1.5))
	assert_true(wall.is_broken, "abattu")
	assert_false(_blocked(front, back), "passage ouvert")
	# La navigation passe désormais par la brèche.
	var nav_map := get_tree().root.get_world_3d().navigation_map
	var crossed := await frames_until(func() -> bool:
		var path := NavigationServer3D.map_get_path(nav_map, front - Vector3(0, 1, 0), back - Vector3(0, 1, 0), true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		return path.size() > 0 and length < 4.5, 300)
	assert_gt(crossed, -1, "chemin direct par la brèche")
	wall.load_state(saved)
	await frames(3)
	assert_false(wall.is_broken, "rechargé debout")
	assert_true(_blocked(front, back))
