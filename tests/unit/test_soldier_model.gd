extends GutTest
## `SoldierModel` : mains, visage et gestes (le modèle est animé par code).

var model: SoldierModel


func before_each() -> void:
	model = SoldierModel.new()
	model.silent = true
	add_child_autofree(model)


## Laisse le modèle s'animer pendant `seconds` secondes simulées.
func _run(seconds: float) -> void:
	for i in int(seconds * 60.0):
		model._process(1.0 / 60.0)


func _finger_curl(shoulder: String) -> float:
	var finger: Node3D = model.find_child(shoulder, true, false).find_child("Finger1", true, false)
	return absf(finger.rotation.z)


func test_fingers_close_on_the_weapon_and_relax_without_it() -> void:
	_run(1.0)
	var holding := _finger_curl("ShoulderR")
	assert_gt(holding, 1.2, "poing serré sur la poignée")
	model.set_armed(false)
	_run(1.0)
	assert_lt(_finger_curl("ShoulderR"), holding * 0.5, "main détendue sans arme")
	model.crate_grip = true
	_run(1.0)
	assert_lt(_finger_curl("ShoulderL"), 0.3, "main ouverte contre la caisse")


func test_eyes_follow_the_target_and_close_when_dead() -> void:
	var lid: Node3D = model.find_child("Eyelid", true, false)
	var iris: Node3D = model.find_child("Iris", true, false)
	var rest := iris.position
	# Cible sur sa gauche (le modèle regarde vers -Z).
	model.look_target = model.global_position + Vector3(-4.0, 1.6, -2.0)
	_run(1.0)
	assert_gt(model.find_child("Head", true, false).rotation.y, 0.3, "tête tournée vers la cible")
	assert_lt(iris.position.x, rest.x, "iris tourné vers la cible")
	model._blink_wait = 100.0
	_run(0.5)
	assert_lt(lid.scale.y, 0.2, "œil ouvert")
	model.is_dead = true
	_run(0.2)
	assert_almost_eq(lid.scale.y, 1.0, 0.01, "yeux fermés une fois mort")
