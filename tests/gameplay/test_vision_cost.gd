extends LevelTest
## Coût du cône de vision : recalculé seulement si l'ennemi bouge ou tourne,
## si un obstacle est déplacé, ou de loin en loin ; pas hors de l'écran.

var enemy: Enemy
var vision: VisionComponent


func _setup() -> void:
	await load_level()
	enemy = node("Enemies/TrainingDummy")
	park(node("Enemies/Soldier1"))
	enemy.set_physics_process(false)
	# Au centre de la vue de départ.
	enemy.global_position = Vector3(2, 0, -1)
	vision = enemy.get_node("VisionComponent")
	await frames(3)


func test_still_cone_is_not_recomputed_every_frame() -> void:
	await _setup()
	var count := vision.rebuild_count
	await frames(30)
	assert_lte(vision.rebuild_count - count, 1, "immobile : au plus un recalcul de sécurité")
	enemy.rotation.y += 0.3
	await frames(2)
	assert_gt(vision.rebuild_count, count + 0, "il a tourné")
	count = vision.rebuild_count
	EventBus.navigation_obstacle_moved.emit()
	await frames(2)
	assert_eq(vision.rebuild_count, count + 1, "obstacle déplacé")


func test_off_screen_cone_waits() -> void:
	await _setup()
	enemy.global_position = Vector3(200, 0, 200)
	await frames(2)
	var count := vision.rebuild_count
	for i in 10:
		enemy.rotation.y += 0.2
		await frames(1)
	assert_eq(vision.rebuild_count, count, "hors de l'écran")
	enemy.global_position = Vector3(2, 0, -1)
	await frames(2)
	assert_gt(vision.rebuild_count, count, "de retour à l'écran")


func test_fewer_segments_when_zoomed_out() -> void:
	await _setup()
	var camera := get_viewport().get_camera_3d()
	camera.size = 18.0
	assert_eq(vision._segments_for_view(), vision.config.segments)
	camera.size = 40.0
	assert_lt(vision._segments_for_view(), vision.config.segments)
	assert_gte(vision._segments_for_view(), VisionComponent.MIN_SEGMENTS)
