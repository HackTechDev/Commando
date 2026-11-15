extends GutTest
## Personnalisation des opérateurs : profil et sauvegarde, modèle 3D, écran
## « Opérateurs » et accès depuis le menu.

const SAVE := "user://test_operators_ui.json"


func before_each() -> void:
	OperatorRoster.save_path = SAVE
	OperatorRoster.use(OperatorRoster.new())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func after_each() -> void:
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		get_tree().root.remove_child(scene)
		scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	OperatorRoster.save_path = "user://test_operators.json"
	OperatorRoster.use(OperatorRoster.new())


func _custom() -> OperatorProfile:
	var profile := OperatorProfile.defaults(1)
	profile.callsign = "Faucon"
	profile.name = "Léa Martin"
	profile.set_camo(&"snow")
	profile.headwear = &"boonie"
	profile.balaclava = false
	profile.primary = &"dmr"
	profile.secondary = &"none"
	profile.grenades = 3
	profile.medkit = 1
	profile.hair_style = &"mohawk"
	return profile


func test_profile_survives_json() -> void:
	var profile := _custom()
	var copy := OperatorProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())), 1)
	for key in ["callsign", "name", "camo", "headwear", "balaclava", "primary", "secondary", "grenades", "medkit", "hair_style", "skin"]:
		assert_eq(copy.get(key), profile.get(key), key)
	assert_eq(copy.top_color.to_html(false), profile.top_color.to_html(false), "couleur du haut")


func test_invalid_values_fall_back_to_defaults() -> void:
	var copy := OperatorProfile.from_dict({"primary": "laser", "grenades": 99, "skin": -4, "callsign": "  ", "top_color": "pas une couleur"}, 2)
	var defaults := OperatorProfile.defaults(2)
	assert_eq(copy.primary, defaults.primary, "arme inconnue ignorée")
	assert_eq(copy.grenades, GearCatalog.EQUIPMENT[&"grenades"]["max"], "nombre borné")
	assert_eq(copy.skin, 0, "indice borné")
	assert_eq(copy.callsign, "Charlie", "indicatif vide : celui par défaut")
	assert_true(copy.top_color.is_equal_approx(defaults.top_color), "couleur invalide ignorée")


func test_roster_saves_and_loads() -> void:
	var roster := OperatorRoster.new()
	roster.operators[1] = _custom()
	assert_eq(roster.save(SAVE), OK)
	var loaded := OperatorRoster.load_file(SAVE)
	assert_eq(loaded.operators[1].callsign, "Faucon")
	assert_eq(loaded.operators[1].primary, &"dmr")
	assert_eq(loaded.operators[0].callsign, "Alpha", "les autres gardent leurs valeurs")
	assert_eq(OperatorRoster.load_file("user://absent.json").operators[2].callsign, "Charlie", "sans fichier : défauts")
	roster.reset(1)
	assert_eq(roster.operators[1].callsign, "Bravo", "réinitialisé")


func test_weapon_changes_fire_settings() -> void:
	var base := load("res://data/units/operator.tres") as UnitStats
	var dmr := GearCatalog.apply_weapon(base, &"dmr")
	assert_eq(dmr.fire_range, 24.0)
	assert_eq(dmr.magazine_size, 5)
	assert_eq(base.fire_range, 16.0, "réglages de base inchangés")
	assert_false(GearCatalog.apply_weapon(base, &"shotgun").suppressed, "fusil de combat sans silencieux")
	var carbine := GearCatalog.apply_weapon(base, &"carbine")
	for key in ["fire_range", "fire_interval", "fire_damage", "magazine_size", "reserve_ammo", "gunshot_noise_radius"]:
		assert_eq(carbine.get(key), base.get(key), "la carabine reprend les réglages de base : " + key)


func test_model_follows_the_outfit() -> void:
	var model := SoldierModel.new()
	add_child_autofree(model)
	assert_not_null(model.find_child("Helmet", true, false), "casque par défaut")
	assert_not_null(model.find_child("Balaclava", true, false), "cagoule par défaut")
	model.outfit = _custom()
	assert_null(model.find_child("Helmet", true, false), "chapeau de brousse à la place du casque")
	assert_not_null(model.find_child("Headwear", true, false))
	assert_not_null(model.find_child("Face", true, false), "visage découvert")
	assert_null(model.find_child("Sidearm", true, false), "sans arme secondaire")
	assert_eq(model.find_children("Grenade*", "", true, false).size(), 3, "trois grenades")
	assert_not_null(model.find_child("Medkit", true, false))
	assert_not_null(model.find_child("Scope", true, false), "lunette du fusil de précision")
	var body := model.find_child("Body", false, false)
	assert_eq(model.get_child_count(), 1, "l'ancien modèle est remplacé")
	assert_not_null(body)


func test_screen_edits_and_saves() -> void:
	var screen := (load(OperatorScreen.SCENE) as PackedScene).instantiate() as OperatorScreen
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	await wait_process_frames(3)
	var roster := OperatorRoster.current()
	screen.find_child("Operator3", true, false).pressed.emit()
	assert_eq(screen.current, 2, "Charlie sélectionné")
	var callsign := screen.find_child("Indicatif", true, false) as LineEdit
	assert_eq(callsign.text, "Charlie")
	callsign.text = "Renard"
	callsign.text_changed.emit("Renard")
	assert_eq(roster.operators[2].callsign, "Renard")
	assert_true(FileAccess.file_exists(SAVE), "sauvegardé aussitôt")
	assert_eq(OperatorRoster.load_file(SAVE).operators[2].callsign, "Renard")
	var primary := screen.find_child("primary", true, false) as OptionButton
	primary.select(1)
	primary.item_selected.emit(1)
	assert_eq(roster.operators[2].primary, &"smg")
	var headwear := screen.find_child("headwear", true, false) as OptionButton
	var none := GearCatalog.HEADWEAR.keys().find(&"none")
	headwear.select(none)
	headwear.item_selected.emit(none)
	assert_null(screen.model.find_child("Helmet", true, false), "aperçu mis à jour")
	for button in screen.find_children("*", "Button", true, false):
		if (button as Button).text == "Woodland":
			(button as Button).pressed.emit()
	assert_eq(roster.operators[2].camo, &"woodland")
	screen.play(&"crouch")
	assert_eq(screen.model.posture, SoldierModel.Posture.CROUCHED)
	screen.play(&"aim")
	assert_true(screen.model.aiming)
	var turn := (screen.find_child("Turntable", true, false) as Node3D).rotation.y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	screen._on_preview_input(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(50, 0)
	screen._on_preview_input(drag)
	assert_gt((screen.find_child("Turntable", true, false) as Node3D).rotation.y, turn, "glisser fait pivoter")
	var zoom := screen.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	screen._on_preview_input(wheel)
	assert_lt(screen.zoom, zoom, "molette : zoom")
	screen.reset_current()
	assert_eq(roster.operators[2].callsign, "Charlie", "réinitialisé")
	assert_eq(callsign.text, "Charlie", "champ mis à jour")
	assert_eq(OperatorRoster.load_file(SAVE).operators[2].primary, &"carbine", "réinitialisation sauvegardée")


func test_menu_opens_operator_screen_and_back() -> void:
	var menu := (load(LevelCatalog.MENU_SCENE) as PackedScene).instantiate() as MainMenu
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await wait_process_frames(2)
	(menu.find_child("Operators", true, false) as Button).pressed.emit()
	await wait_process_frames(3)
	assert_true(get_tree().current_scene is OperatorScreen, "écran Opérateurs ouvert")
	(get_tree().current_scene.find_child("Back", true, false) as Button).pressed.emit()
	await wait_process_frames(3)
	assert_true(get_tree().current_scene is MainMenu, "retour au menu")
