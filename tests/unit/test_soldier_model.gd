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


func test_enemies_have_their_own_kit() -> void:
	var guard := SoldierModel.new()
	guard.operator_helmet = false
	guard.name = "Guard"
	add_child_autofree(guard)
	assert_null(guard.find_child("Balaclava", true, false), "visage découvert")
	assert_not_null(guard.find_child("Face", true, false))
	assert_null(guard.find_child("NvgTube*", true, false), "pas de JVN")
	assert_null(guard.find_child("Backpack", true, false))
	assert_not_null(guard.find_child("Magazine", true, false), "fusil à chargeur courbe")


## Déplace le modèle de `velocity` (repère du modèle) pendant `seconds`.
func _slide(velocity: Vector3, seconds: float) -> void:
	model.move_ratio = velocity.length() / 1.6
	for i in int(seconds * 60.0):
		model.position += velocity / 60.0
		model._process(1.0 / 60.0)


func test_pushed_sideways_or_back_it_steps_instead_of_sliding() -> void:
	_run(0.2)
	_slide(Vector3(1.5, 0.0, 0.0), 0.5)
	var legs_apart: float = absf(model._leg_r.rotation.z) + absf(model._leg_l.rotation.z)
	assert_gt(model._sideways(), 0.9, "déplacement latéral mesuré")
	model._phase = 0.0
	_slide(Vector3(1.5, 0.0, 0.0), 0.4)
	assert_gt(legs_apart + absf(model._leg_r.rotation.z) + absf(model._leg_l.rotation.z), 0.1, "pas chassés")
	var phase: float = model._phase
	_slide(Vector3(0.0, 0.0, 1.5), 0.6)
	assert_gt(model._backward(), 0.9, "recul mesuré")
	assert_lt(model._phase, phase, "foulée à reculons")


func test_pickup_bends_down_then_stands_up() -> void:
	_run(0.5)
	var standing: float = model._hips.position.y
	model.play_pickup()
	_run(SoldierModel.PICKUP_DURATION * 0.5)
	assert_true(model.is_picking_up())
	assert_lt(model._hips.position.y, standing - 0.2, "accroupi pour ramasser")
	_run(1.0)
	assert_false(model.is_picking_up())
	assert_almost_eq(model._hips.position.y, standing, 0.03, "relevé")


func test_unarmed_guard_raises_the_fists() -> void:
	model.set_armed(false)
	_run(0.5)
	var hand: Node3D = model.find_child("ShoulderR", true, false).find_child("Hand", true, false)
	var low := hand.global_position.y
	model.guard_up = true
	_run(1.0)
	assert_gt(hand.global_position.y, low + 0.4, "poings à hauteur du visage")
	assert_gt(_finger_curl("ShoulderR"), 1.2, "poings serrés")


func test_every_primary_weapon_is_modelled() -> void:
	var outfit := OperatorProfile.defaults(0)
	for id: StringName in GearCatalog.PRIMARY:
		outfit.primary = id
		model.outfit = outfit
		assert_not_null(model._rifle_mag, "%s : chargeur" % id)
		assert_lt(model._flash.position.z, -0.4, "%s : bouche du canon devant" % id)
		assert_true(GearCatalog.WEIGHTS.has(id), "%s : poids" % id)


func test_civilian_wears_a_suit_without_military_gear() -> void:
	var civilian := SoldierModel.new()
	civilian.civilian = true
	var vip := Vip.new()
	civilian.outfit = vip.civilian_outfit()
	vip.free()
	add_child_autofree(civilian)
	civilian.set_armed(false)
	assert_not_null(civilian.find_child("Suit", true, false), "costume et cravate")
	for gear in ["Vest", "Backpack", "Radio", "Sidearm", "KneePad", "Balaclava"]:
		assert_null(civilian.find_child(gear, true, false), "pas de %s" % gear)
	assert_same(civilian._m_glove, civilian._m_skin, "mains nues")
	assert_false(civilian._rifle.visible, "sans arme")


func test_female_body_is_slimmer_and_beardless() -> void:
	var outfit := OperatorProfile.defaults(0)
	outfit.balaclava = false
	outfit.headwear = &"none"
	outfit.beard = &"full"
	outfit.hair_style = &"long"
	outfit.body = &"female"
	model.outfit = outfit
	assert_true(model._female)
	assert_almost_eq(model._body.scale.y, SoldierModel.FEMALE_SCALE, 0.001, "un peu plus petite")
	assert_null(model.find_child("Beard", true, false), "pas de barbe")
	assert_not_null(model.find_child("LongHair", true, false), "cheveux longs")
	assert_eq(model.find_children("Bust*", "", true, false).size(), 2)
	assert_ne((model.find_child("Face", true, false) as MeshInstance3D).mesh, SoldierModel._head_mesh(false), "visage plus fin")
	assert_eq(OperatorProfile.defaults(1).body, &"female", "Bravo : Inès Morel")
	# Les articulations ne changent pas : les animations restent valables.
	assert_eq(model.find_child("ShoulderR", true, false).position, model._shoulder_position(1.0))
	_run(1.0)
	model.posture = SoldierModel.Posture.PRONE
	_run(2.0)
	assert_false(model.is_changing_posture(), "se couche normalement")


func test_mouth_and_nose_sit_on_the_face() -> void:
	for body: StringName in [&"male", &"female"]:
		for beard: StringName in [&"none", &"stubble", &"full"]:
			var outfit := OperatorProfile.defaults(0)
			outfit.balaclava = false
			outfit.body = body
			outfit.beard = beard
			model.outfit = outfit
			var female := body == &"female"
			var mouth: Node3D = model.find_child("Mouth", true, false)
			var surface := SoldierModel.face_depth(0.0, SoldierModel.MOUTH_HEIGHT, female)
			# Lèvres à moitié enfoncées dans la peau ou dans la barbe.
			assert_between(mouth.position.z, surface - 0.03, surface + 0.006, "%s/%s : bouche contre le visage" % [body, beard])
			var nose := model.find_child("Nose", true, false) as MeshInstance3D
			var box := nose.get_aabb()
			assert_lt(box.position.z, SoldierModel.face_depth(0.0, 0.148, female) - 0.015, "%s : nez saillant" % body)
			assert_gt(box.end.z, SoldierModel.face_depth(0.0, 0.17, female), "%s : nez ancré dans le visage" % body)


func test_switch_to_sidearm_slings_the_rifle_then_draws_the_pistol() -> void:
	var outfit := OperatorProfile.defaults(0)
	outfit.shield = 1
	model.outfit = outfit
	_run(0.5)
	assert_true(model.is_weapon_ready())
	model.sidearm_drawn = true
	model.shield_raised = true
	_run(0.3)
	assert_false(model.is_weapon_ready(), "pas de tir pendant le changement")
	assert_null(model.find_child("SlungPrimary", true, false), "le fusil descend d'abord à la bretelle")
	assert_false(model.is_shield_up(), "le bouclier attend que le fusil ait quitté les mains")
	_run(0.6)
	var slung: Node3D = model.find_child("SlungPrimary", true, false)
	assert_not_null(slung, "fusil pendu à la bretelle")
	assert_true(slung.transform.is_equal_approx(model._rifle_slung), "sur le flanc, là où la bretelle l'a laissé")
	assert_lt(model._draw, 1.0, "le pistolet sort de l'étui")
	_run(1.0)
	assert_true(model.is_weapon_ready(), "pistolet en main")
	assert_true(model.is_shield_up())
	model.sidearm_drawn = false
	model.shield_raised = false
	_run(0.3)
	assert_not_null(model.find_child("SlungPrimary", true, false), "le pistolet rentre d'abord dans l'étui")
	_run(0.4)
	assert_null(model.find_child("SlungPrimary", true, false))
	assert_false(model.is_weapon_ready(), "le fusil remonte de la bretelle")
	_run(1.0)
	assert_true(model.is_weapon_ready(), "fusil en main")
