extends LevelTest
## Curseur contextuel : il indique ce qu'un clic ferait à l'endroit survolé.

var controller: PlayerController
var camera: Camera3D
var alpha: Commando
var enemy: Enemy


func _setup() -> void:
	await load_level()
	controller = node("HUD/PlayerController")
	camera = get_viewport().get_camera_3d()
	alpha = node("Units/Alpha")
	enemy = node("Enemies/Soldier1")
	park(enemy, Vector3(3, 0, -0.5))
	park(node("Enemies/TrainingDummy"))
	# Les corps déplacés ne comptent pour les rayons qu'à l'image suivante.
	await frames(2)


func _kind_at(point: Vector3) -> GameCursor.Kind:
	return controller.cursor_kind_at(camera.unproject_position(point))


func test_cursor_follows_what_is_under_the_mouse() -> void:
	await _setup()
	SelectionManager.clear()
	assert_eq(_kind_at(enemy.global_position + Vector3.UP), GameCursor.Kind.DEFAULT, "rien de sélectionné")
	SelectionManager.select([alpha] as Array[Commando])
	assert_eq(_kind_at(enemy.global_position + Vector3.UP), GameCursor.Kind.ATTACK, "ennemi : tirer")
	assert_eq(_kind_at(Vector3(5, 1.2, 5)), GameCursor.Kind.CLIMB, "dessus d'une caisse : grimper")
	assert_eq(_kind_at(Vector3(1, 0, 6)), GameCursor.Kind.DEFAULT, "sol accessible")
	assert_eq(_kind_at(Vector3(-4, 3, -8)), GameCursor.Kind.FORBIDDEN, "dessus d'un mur : inaccessible")
	assert_eq(_kind_at(Vector3(20, 3, 10)), GameCursor.Kind.DEFAULT, "toit du bunker, par l'échelle")


func test_cursor_shows_the_target_of_an_armed_action() -> void:
	await _setup()
	SelectionManager.select([alpha] as Array[Commando])
	controller.toggle_pending_action(PlayerController.ACTION_KNIFE)
	assert_eq(_kind_at(enemy.global_position + Vector3.UP), GameCursor.Kind.MELEE)
	assert_eq(_kind_at(Vector3(1, 0, 6)), GameCursor.Kind.FORBIDDEN, "pas de cible")
	controller.toggle_pending_action(PlayerController.ACTION_THROW)
	assert_eq(_kind_at(enemy.global_position + Vector3.UP), GameCursor.Kind.THROW)
	controller.toggle_pending_action(PlayerController.ACTION_CRATE)
	assert_eq(_kind_at(Vector3(5, 0.6, 5.6)), GameCursor.Kind.CRATE)
	controller.toggle_pending_action(PlayerController.ACTION_GRENADE)
	assert_eq(_kind_at(Vector3(1, 0, 6)), GameCursor.Kind.GRENADE)
	controller.cancel_pending_action()


func test_cursor_images() -> void:
	for kind: GameCursor.Kind in GameCursor.COLORS:
		var image := GameCursor.texture(kind).get_image()
		assert_eq(image.get_size(), Vector2i(32, 32))
		assert_true(image.get_used_rect().size.x > 10, "dessin visible")
	GameCursor.apply(GameCursor.Kind.ATTACK)
	assert_eq(GameCursor.current(), GameCursor.Kind.ATTACK)
	GameCursor.apply(GameCursor.Kind.DEFAULT)
	assert_eq(GameCursor.current(), GameCursor.Kind.DEFAULT)
