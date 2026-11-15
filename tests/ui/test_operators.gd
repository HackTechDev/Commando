extends GutTest
## Personnalisation des opérateurs : profil et sauvegarde, modèle 3D, écran
## « Opérateurs » et accès depuis le menu.

const SAVE := "user://test_operators_ui.json"
## Réglages propres au test : la dernière carte jouée du joueur passerait
## sinon en tête du menu.
const SETTINGS_FILE := "user://test_operators_settings.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	Settings.use_file(SETTINGS_FILE)
	OperatorRoster.save_path = SAVE
	OperatorRoster.use(OperatorRoster.new())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func after_each() -> void:
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		get_tree().root.remove_child(scene)
		scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Settings.use_file(Settings.PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
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
	profile.body = &"female"
	profile.shield = 1
	return profile


func test_profile_survives_json() -> void:
	var profile := _custom()
	var copy := OperatorProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())), 1)
	for key in ["callsign", "name", "camo", "headwear", "balaclava", "primary", "secondary", "grenades", "medkit", "hair_style", "skin", "body", "shield"]:
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
	var body := screen.find_child("body", true, false) as OptionButton
	var female := GearCatalog.BODIES.keys().find(&"female")
	body.select(female)
	body.item_selected.emit(female)
	assert_eq(roster.operators[2].body, &"female", "morphologie choisie")
	assert_true(screen.model._female, "aperçu féminin")
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


func _open_screen() -> OperatorScreen:
	var screen := (load(OperatorScreen.SCENE) as PackedScene).instantiate() as OperatorScreen
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	await wait_process_frames(3)
	return screen


func _choose(screen: OperatorScreen, key: String, id: StringName, choices: Dictionary) -> void:
	var option := screen.find_child(key, true, false) as OptionButton
	var index := choices.keys().find(id)
	option.select(index)
	option.item_selected.emit(index)


func _key(keycode: Key, physical: Key = KEY_NONE, ctrl: bool = false, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical if physical != KEY_NONE else keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	return event


func test_undo_and_shortcuts() -> void:
	var screen := await _open_screen()
	var roster := OperatorRoster.current()
	assert_false(screen.can_undo(), "rien à annuler au départ")
	_choose(screen, "primary", &"dmr", GearCatalog.PRIMARY)
	assert_eq(roster.operators[0].primary, &"dmr")
	assert_true(screen.undo(), "annulé")
	assert_eq(roster.operators[0].primary, &"carbine", "retour à la carabine")
	assert_eq(OperatorRoster.load_file(SAVE).operators[0].primary, &"carbine", "annulation sauvegardée")
	var callsign := screen.find_child("Indicatif", true, false) as LineEdit
	for text in ["R", "Re", "Ren"]:
		callsign.text = text
		callsign.text_changed.emit(text)
	_choose(screen, "headwear", &"cap", GearCatalog.HEADWEAR)
	screen._input(_key(KEY_Z, KEY_W, true))
	assert_eq(roster.operators[0].headwear, &"helmet", "Ctrl+Z (touche logique Z) annule")
	screen.undo()
	assert_eq(roster.operators[0].callsign, "Alpha", "la saisie de l'indicatif s'annule d'un coup")
	assert_false(screen.can_undo())
	screen._input(_key(KEY_QUOTEDBL, KEY_2))
	assert_eq(screen.current, 1, "touche 2 (rangée du haut) : Bravo")
	screen._input(_key(KEY_KP_3))
	assert_eq(screen.current, 2, "pavé numérique 3 : Charlie")
	screen._input(_key(KEY_TAB))
	assert_eq(screen._tabs.current_tab, 1, "Tab : onglet suivant")
	screen._input(_key(KEY_TAB, KEY_TAB, false, true))
	screen._input(_key(KEY_TAB, KEY_TAB, false, true))
	assert_eq(screen._tabs.current_tab, screen._tabs.get_tab_count() - 1, "Maj+Tab : onglet précédent, en boucle")


func test_copy_look_and_weight_limit() -> void:
	var screen := await _open_screen()
	var roster := OperatorRoster.current()
	roster.operators[1].primary = &"smg"
	roster.operators[0].set_camo(&"snow")
	roster.operators[0].backpack = false
	screen.copy_look_to_team()
	for i in [1, 2]:
		assert_eq(roster.operators[i].camo, &"snow", "camouflage copié")
		assert_false(roster.operators[i].backpack, "accessoires copiés")
	assert_eq(roster.operators[1].primary, &"smg", "armement inchangé")
	assert_eq(roster.operators[2].callsign, "Charlie", "identité inchangée")
	screen.undo()
	assert_eq(roster.operators[1].camo, &"", "copie annulée d'un coup")
	assert_true(roster.operators[2].backpack)
	# Charge : au-delà du maximum, le changement est refusé.
	_choose(screen, "primary", &"dmr", GearCatalog.PRIMARY)
	for key: String in ["grenades", "explosives", "medkit"]:
		var spin := screen.find_child(key, true, false) as SpinBox
		spin.value = spin.max_value
	assert_lt(GearCatalog.load_of(roster.operators[0]), GearCatalog.MAX_LOAD + 0.01, "encore permis")
	_choose(screen, "secondary", &"machine_pistol", GearCatalog.SECONDARY)
	assert_eq(roster.operators[0].secondary, &"pistol", "trop lourd : refusé")
	assert_string_contains(screen._status.text, "Trop lourd")
	assert_eq((screen.find_child("secondary", true, false) as OptionButton).selected, GearCatalog.SECONDARY.keys().find(&"pistol"), "liste remise")
	assert_string_contains((screen.find_child("Load", true, false) as Label).text, "Lourde")


func test_saved_outfits_and_specialty() -> void:
	var screen := await _open_screen()
	var roster := OperatorRoster.current()
	roster.operators[0].set_camo(&"night")
	roster.operators[0].primary = &"smg"
	(screen.find_child("OutfitName", true, false) as LineEdit).text = "Nuit"
	(screen.find_child("SaveOutfit", true, false) as Button).pressed.emit()
	assert_eq(roster.operators[0].saved_outfits.size(), 1, "tenue enregistrée")
	roster.operators[0].set_camo(&"desert")
	roster.operators[0].primary = &"carbine"
	(screen.find_child("Wear1", true, false) as Button).pressed.emit()
	assert_eq(roster.operators[0].camo, &"night", "tenue remise")
	assert_eq(roster.operators[0].primary, &"smg", "armement de la tenue")
	var loaded := OperatorRoster.load_file(SAVE).operators[0]
	assert_eq(loaded.saved_outfits.size(), 1, "tenues sauvegardées")
	assert_eq(loaded.saved_outfits[0]["name"], "Nuit")
	_choose(screen, "specialty", &"marksman", GearCatalog.SPECIALTIES)
	(screen.find_child("SpecialtyOutfit", true, false) as Button).pressed.emit()
	assert_eq(roster.operators[0].primary, &"dmr", "tenue conseillée du tireur d'élite")
	assert_eq(roster.operators[0].headwear, &"boonie")
	assert_eq(roster.operators[0].camo, &"night", "camouflage gardé")
	assert_eq(OperatorRoster.load_file(SAVE).operators[0].specialty, &"marksman", "spécialité sauvegardée")
	assert_string_contains(screen._selectors[0].text, "Tireur d'élite")
	(screen.find_child("Delete1", true, false) as Button).pressed.emit()
	assert_eq(roster.operators[0].saved_outfits.size(), 0, "tenue supprimée")


func test_preview_follows_the_changes() -> void:
	var screen := await _open_screen()
	var roster := OperatorRoster.current()
	assert_eq(screen.portraits.size(), 3, "un portrait 3D par opérateur")
	assert_true(screen._selectors[0].icon is ViewportTexture)
	assert_eq(screen.backdrop, &"", "décor neutre sans camouflage")
	for button in screen.find_children("*", "Button", true, false):
		if (button as Button).text == "Désert":
			(button as Button).pressed.emit()
	assert_eq(screen.backdrop, &"desert", "décor du désert")
	assert_gt((screen.find_child("Backdrop", true, false) as Node3D).get_child_count(), 0, "éléments de décor")
	assert_eq(screen.portraits[0].outfit, roster.operators[0], "portrait mis à jour")
	_choose(screen, "headwear", &"beanie", GearCatalog.HEADWEAR)
	assert_eq(screen.focus, &"head", "cadrage sur la tête")
	_choose(screen, "primary", &"shotgun", GearCatalog.PRIMARY)
	assert_eq(screen.focus, &"weapon", "cadrage sur l'arme")
	(screen.find_child("knee_pads", true, false) as CheckBox).button_pressed = false
	assert_eq(screen.focus, &"legs", "cadrage sur les jambes")
	assert_not_null(screen.find_child("Comparison", true, false), "comparaison des armes")
	for id: StringName in [&"reload", &"throw", &"stab"]:
		screen.play(id)
		await wait_process_frames(20)
	screen.play(&"climb")
	assert_true((screen.find_child("ClimbCrate", true, false) as Node3D).visible, "caisse d'escalade")
	screen._anim_time = 1.2
	await wait_process_frames(2)
	assert_gt(screen.model.position.y, 0.5, "l'opérateur monte sur la caisse")
	screen.play(&"idle")
	assert_false((screen.find_child("ClimbCrate", true, false) as Node3D).visible)
	assert_eq(screen.model.position, Vector3.ZERO)


func test_briefing_suggests_the_map_camo() -> void:
	var roster := OperatorRoster.current()
	roster.operators[1].set_camo(&"snow")
	roster.operators[1].save_outfit("Désert")
	roster.operators[1].saved_outfits[0]["outfit"]["camo"] = "desert"
	var menu := (load(LevelCatalog.MENU_SCENE) as PackedScene).instantiate() as MainMenu
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await wait_process_frames(2)
	var play: Button = menu.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Jouer")[0]
	play.pressed.emit()
	assert_true(menu.briefing.visible, "préparation ouverte")
	assert_string_contains((menu.briefing.find_child("SuggestAll", true, false) as Button).text, "Woodland", "terrain d'essai : woodland conseillé")
	var outfits := menu.briefing.find_child("Outfit2", true, false) as OptionButton
	assert_eq(outfits.item_count, 2, "tenue actuelle et tenue enregistrée")
	outfits.select(1)
	outfits.item_selected.emit(1)
	assert_eq(roster.operators[1].camo, &"desert", "tenue enregistrée revêtue")
	(menu.briefing.find_child("Camo1", true, false) as Button).pressed.emit()
	assert_eq(roster.operators[0].camo, &"woodland", "camouflage conseillé pour Alpha")
	assert_eq(roster.operators[1].camo, &"desert", "les autres inchangés")
	(menu.briefing.find_child("SuggestAll", true, false) as Button).pressed.emit()
	for operator in roster.operators:
		assert_eq(operator.camo, &"woodland")
	assert_eq(OperatorRoster.load_file(SAVE).operators[2].camo, &"woodland", "sauvegardé")
	(menu.briefing.find_child("CancelBriefing", true, false) as Button).pressed.emit()
	assert_false(menu.briefing.visible, "annulé")
	assert_false(play.disabled, "rien n'est lancé")
