extends LevelTest
## Écran de chargement : la navigation se génère en arrière-plan, jeu en
## pause, l'écran reste animé, puis le jeu démarre.


func after_each() -> void:
	get_tree().paused = false
	super()


func test_navigation_bakes_behind_a_loading_screen() -> void:
	var map_path := AssetPaths.maps_dir().path_join("training_b.map")
	if not FileAccess.file_exists(map_path):
		pending("Carte introuvable : %s" % map_path)
		return
	# Grande carte : plusieurs secondes de génération.
	level = load(TRAINING_B).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	var root := level as LevelRoot
	assert_false(root.is_level_ready)
	assert_true(get_tree().paused, "jeu en pause pendant le chargement")
	var screen := root.find_children("*", "LoadingScreen", false, false)
	assert_eq(screen.size(), 1, "écran de chargement affiché")
	if screen.size() == 1:
		assert_eq((screen[0].find_child("Title", true, false) as Label).text, "Entraînement B", "titre du niveau")
	# Construction de la carte sur plusieurs images, l'écran indiquant l'étape.
	var map: UfoMapLevel = node("NavigationRegion3D/Map")
	var stages: Array[String] = []
	while not map.is_built:
		if not stages.has(map.build_stage):
			stages.append(map.build_stage)
		await get_tree().process_frame
	assert_has(stages, "Construction du décor")
	assert_false(root.is_level_ready, "navigation pas encore prête")
	# Un ordre donné pendant le chargement n'est exécuté qu'une fois prêt.
	var alpha: Commando = node("Units/Alpha")
	var start := alpha.global_position
	alpha.move_to(start + Vector3(3, 0, 0), false)
	var frames_while_loading := 0
	var moved_while_loading := 0.0
	while not root.is_level_ready and frames_while_loading < 3000:
		moved_while_loading = maxf(moved_while_loading, alpha.global_position.distance_to(start))
		await get_tree().process_frame
		frames_while_loading += 1
	assert_true(root.is_level_ready, "navigation générée")
	assert_gt(frames_while_loading, 10, "l'affichage continue pendant la génération (pas d'écran figé)")
	assert_lt(moved_while_loading, 0.01, "personne ne bouge pendant le chargement")
	assert_false(get_tree().paused, "le jeu démarre")
	await get_tree().process_frame
	assert_eq(root.find_children("*", "LoadingScreen", false, false).size(), 0, "écran retiré")
	var navigation_map: RID = root.get_world_3d().navigation_map
	var on_mesh := NavigationServer3D.map_get_closest_point(navigation_map, start)
	assert_lt(on_mesh.distance_to(start), 0.3, "chemins disponibles dès le lancement")
	# L'ordre donné pendant le chargement s'exécute.
	await frames(120)
	assert_gt(alpha.global_position.distance_to(start), 1.0, "ordre exécuté une fois prêt")


func test_leaving_during_loading_does_not_leave_the_game_paused() -> void:
	level = load(SANDBOX).instantiate()
	get_tree().root.add_child(level)
	assert_true(get_tree().paused)
	_free_level()
	assert_false(get_tree().paused, "pause levée en quittant le niveau")


func test_sandbox_is_ready_quickly() -> void:
	await load_level(SANDBOX)
	assert_true((level as LevelRoot).is_level_ready)
	assert_false(get_tree().paused)
