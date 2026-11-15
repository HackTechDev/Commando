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


func test_face_shows_effort_and_pain() -> void:
	var outfit := OperatorProfile.defaults(0)
	outfit.balaclava = false
	model.outfit = outfit
	model._rebuild()
	var mouth: Node3D = model.find_child("Mouth", true, false)
	_run(0.5)
	var rest := mouth.scale.y
	model.strike_progress = 0.3
	_run(0.3)
	assert_lt(mouth.scale.y, rest, "lèvres serrées pendant l'effort")
	model.strike_progress = -1.0
	model.grabbed = true
	_run(0.5)
	assert_gt(mouth.scale.y, rest * 1.5, "bouche ouverte de douleur")


func test_clothes_have_folds_and_seams() -> void:
	assert_not_null(model._m_uniform.normal_texture, "relief du tissu")
	assert_true(model._m_uniform.uv1_triplanar, "plaqué sans UV")
	assert_same(model._m_gear.normal_texture, model._m_uniform.normal_texture, "texture générée une seule fois")


func test_specialty_changes_the_silhouette() -> void:
	assert_null(model.find_child("Specialty", true, false), "rien sans spécialité")
	var outfit := OperatorProfile.defaults(0)
	outfit.specialty = &"medic"
	model.outfit = outfit
	model._rebuild()
	assert_not_null(model.find_child("Specialty", true, false), "sac de soins")
	assert_eq(model.find_children("Armband", "", true, false).size(), 2, "brassards aux deux bras")
