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
