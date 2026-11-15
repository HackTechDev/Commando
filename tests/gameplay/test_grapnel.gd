extends LevelTest
## Grappin : lancé vers un point en hauteur, l'opérateur y monte à la corde,
## qui reste en place pour les autres.

const ROOF := Vector3(20, 3, 10)
const TERRACE := Vector3(27, 3.2, 10)

var alpha: Commando
var bravo: Commando


func _setup() -> void:
	await load_level()
	alpha = node("Units/Alpha")
	bravo = node("Units/Bravo")
	park(node("Enemies/Soldier1"))
	park(node("Enemies/TrainingDummy"), Vector3(-25, 0, -25))
	hide_from_enemies(node("Units/Charlie"))


func test_route_needs_a_wall_within_reach() -> void:
	await _setup()
	alpha.global_position = Vector3(20, 0, 16)
	await frames(2)
	var route := alpha.grapple_route(ROOF)
	assert_true(route["ok"], route.get("reason", ""))
	assert_eq(route["faces"].size(), 1)
	assert_almost_eq((route["foot"] as Vector3).z, 13.2, 0.25, "au pied du mur")
	assert_false(alpha.grapple_route(Vector3(20, 0, 20))["ok"], "pas de hauteur à gravir")
	alpha.global_position = Vector3(20, 0, 28)
	await frames(2)
	assert_true(alpha.grapple_route(ROOF)["ok"], "il ira au pied du mur")
	assert_false(alpha.grapple_route(Vector3(-4, 3, -8))["ok"], "dessus d'un mur : inaccessible")
	assert_false(alpha.grapple(ROOF), "sans grappin")
	assert_eq(alpha.current_hint(), Commando.Hint.NO_GRAPNEL, "il dit qu'il n'en a pas")
	alpha.grapnels = 1
	assert_false(alpha.grapple(Vector3(20, 0, 20)), "pas de hauteur")
	assert_eq(alpha.hint_text(), "Grappin : pas assez haut", "raison du refus affichée")


func test_operator_throws_the_grapnel_and_climbs_to_the_roof() -> void:
	await _setup()
	alpha.grapnels = 1
	assert_not_null(alpha._model.find_child("Grapnel", true, false), "grappin au flanc")
	alpha.global_position = Vector3(20, 0, 16)
	await frames(2)
	assert_true(alpha.grapple(ROOF))
	var thrown := await frames_until(func() -> bool: return alpha.grapnels == 0, 400)
	assert_gt(thrown, -1, "grappin lancé")
	var up := await frames_until(func() -> bool:
		return not alpha.is_traversing() and flat_distance(alpha.global_position, ROOF) < 0.8 and alpha.global_position.y > 2.8, 1500)
	assert_gt(up, -1, "monté sur le toit")
	assert_null(alpha._model.find_child("Grapnel", true, false), "plus de grappin")
	# La corde reste : Bravo l'emprunte à son tour.
	bravo.global_position = Vector3(21, 0, 16)
	bravo.move_to(ROOF + Vector3(1, 0, 1), false)
	var followed := await frames_until(func() -> bool:
		return not bravo.is_traversing() and bravo.global_position.y > 2.8, 1500)
	assert_gt(followed, -1, "Bravo monte par la corde")


func test_grapnel_over_stepped_terraces() -> void:
	await _setup()
	alpha.grapnels = 1
	alpha.global_position = Vector3(27, 0, 18)
	await frames(2)
	var route := alpha.grapple_route(TERRACE)
	assert_true(route["ok"], route.get("reason", ""))
	assert_eq(route["faces"].size(), 2, "deux ressauts")
	assert_true(alpha.grapple(TERRACE))
	var up := await frames_until(func() -> bool:
		return not alpha.is_traversing() and alpha.global_position.y > 3.0 and flat_distance(alpha.global_position, TERRACE) < 0.8, 1800)
	assert_gt(up, -1, "en haut des terrasses")
	# Et il redescend par la corde.
	alpha.move_to(Vector3(27, 0, 18), false)
	var down := await frames_until(func() -> bool:
		return flat_distance(alpha.global_position, Vector3(27, 0, 18)) < 0.6 and alpha.global_position.y < 0.2, 1800)
	assert_gt(down, -1, "redescendu")
