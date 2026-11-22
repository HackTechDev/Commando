@tool
extends VBoxContainer
## Dock « Mission » du greffon : scène ouverte, avertissement sur les cartes
## générées, nouvelle mission, vérification et essai, informations de la
## mission (objectifs et leurs cibles), réglages de la carte, trajet
## sélectionné, grille et palette des éléments à poser.

const Palette := preload("res://addons/mission_editor/palette.gd")
const MissionTargets := preload("res://addons/mission_editor/mission_targets.gd")
const Events := preload("res://addons/mission_editor/events.gd")

## Outil choisi dans la palette (vide : aucun).
signal tool_selected(id: String)
signal night_toggled(night: bool)
signal dress_code_selected(code: StringName)
signal grid_toggled(enabled: bool)
## Informations de la mission : à ouvrir dans l'inspecteur, à créer.
signal info_edit_requested
signal info_create_requested
## Objectifs modifiés dans le dock : nouvelle liste de [identifiant, texte].
signal objectives_edited(objectives: Array)
## Un objectif cliqué : nœuds de sa cible à sélectionner.
signal nodes_selected(nodes: Array)
## Trajet sélectionné : ajouter ou retirer un point.
signal route_point_added
signal route_point_removed
## Carte de couverture des gardes affichée ou non.
signal coverage_toggled(on: bool)
## Limites de la caméra à caler sur le terrain.
signal camera_fit_requested
## Fenêtre « Vue du jeu » demandée.
signal game_view_requested
## Animation des rondes et des trajets : lecture ou pause, temps choisi sur
## la barre, vitesse, retour au début (silhouettes retirées).
signal timeline_play_toggled(on: bool)
signal timeline_time_changed(time: float)
signal timeline_speed_changed(factor: float)
signal timeline_reset
## Nouvelle mission dans `scenes/levels/<folder>/`.
signal new_mission_requested(folder: String)
## Réglage d'un événement scripté changé dans la section Événements.
signal event_changed(event: Node3D, property: StringName, value: Variant)
## « Tracer une zone » : outil de zone pour cet événement.
signal event_zone_requested(event: Node3D)
## Bâtiment dessiné : retirer le dernier élément ("rooms", "openings",
## "stairs") ; étage des pièces, ouvertures et volées à poser.
signal plan_remove_requested(kind: String)
signal plan_storey_changed(storey: int)
## Boutons « Vérifier » et « Essayer ».
signal check_requested
signal play_requested

## Tenues de rigueur proposées (vide : aucune).
const DRESS_CODES: Array[StringName] = [&"", &"suit", &"casual", &"uniform"]
const OK_COLOR := Color(0.5, 0.9, 0.55)
const WARN_COLOR := Color(1.0, 0.7, 0.3)
const DIM_COLOR := Color(0.7, 0.7, 0.7)

var _title: Label
var _warning: Label
var _info_box: VBoxContainer
var _info_button: Button
## Lignes des objectifs : refaites seulement quand la liste change (pas
## pendant une saisie) ; sinon, seul l'état des cibles est mis à jour.
var _objectives_signature: String = "-"
var _objective_rows: Array[Dictionary] = []
var _rebuilding: bool = false
var _night: CheckBox
var _dress: OptionButton
var _route_box: VBoxContainer
## Section Événements : une fiche par événement ; `_event_rows` : événement →
## ses réglages (mis à jour sans refaire les fiches tant que la liste ne
## change pas).
var _events_box: VBoxContainer
var _event_rows: Dictionary = {}
var _events_signature: String = "-"
var _plan_storey: SpinBox
var _plan_label: Label
var _plan_buttons: HBoxContainer
var _route_label: Label
## Sols proposés pour une nouvelle mission (couleurs dans le greffon,
## `GROUNDS`, comme `tools/mapkit.py`).
const GROUND_LABELS := {"grass": "Herbe", "desert": "Désert", "sand": "Sable", "dirt": "Terre", "rock": "Roche", "urban": "Ville"}
## Animation : durée de la barre de temps (s, comme `timeline.gd`) et
## vitesses proposées.
const TIMELINE_DURATION := 180.0
const TIMELINE_SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]
## Taille d'un côté du terrain d'une nouvelle mission (m).
const NEW_SIZE_MIN := 40
const NEW_SIZE_MAX := 200

var _new_folder: LineEdit
var _new_status: Label
var _new_width: SpinBox
var _new_depth: SpinBox
var _new_ground: OptionButton
var _new_night: CheckBox
## Fond de la nouvelle mission : terrain plat, ou une carte UFO:AI.
var _new_background: OptionButton
var _new_guards: CheckBox
var _report_box: VBoxContainer
var _summary: Button
var _on_save: CheckBox
var _scroll: ScrollContainer
var _grid: CheckBox
var _surface: CheckBox
var _coverage: CheckBox
var _coverage_legend: Label
var _play: Button
var _time_slider: HSlider
var _time_label: Label
var _status: Label
var _body: VBoxContainer
var _buttons: Dictionary = {}
var _group := ButtonGroup.new()
var _updating: bool = false


func _init() -> void:
	name = "Mission"
	custom_minimum_size = Vector2(240, 0)
	_title = Label.new()
	_title.text = "Aucune mission ouverte"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_warning = _label("", WARN_COLOR)
	_warning.visible = false
	add_child(_warning)
	# Résumé de la dernière vérification, toujours visible ; un clic montre
	# le rapport.
	_summary = Button.new()
	_summary.flat = true
	_summary.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.tooltip_text = "Cliquez pour voir le rapport (section Vérification)."
	_summary.visible = false
	_summary.pressed.connect(func() -> void: _scroll.ensure_control_visible(_report_box))
	add_child(_summary)
	var new_row := HBoxContainer.new()
	_new_folder = LineEdit.new()
	_new_folder.placeholder_text = "dossier (ex. raid_desert)"
	_new_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_folder.text_submitted.connect(func(text: String) -> void: new_mission_requested.emit(text.strip_edges()))
	new_row.add_child(_new_folder)
	var create := Button.new()
	create.text = "Nouvelle mission"
	create.tooltip_text = "Crée scenes/levels/<dossier>/<dossier>.tscn (terrain de la taille et du sol choisis, de jour ou de nuit, équipe au sud, extraction au nord) et son mission.tres, puis l'ouvre."
	create.pressed.connect(func() -> void: new_mission_requested.emit(_new_folder.text.strip_edges()))
	new_row.add_child(create)
	add_child(new_row)
	# Terrain de la nouvelle mission : taille, sol, jour ou nuit.
	var terrain_row := HBoxContainer.new()
	_new_width = _size_box("Largeur du terrain (m, ouest-est)")
	terrain_row.add_child(_new_width)
	terrain_row.add_child(_label("×", Color(0, 0, 0, 0)))
	_new_depth = _size_box("Profondeur du terrain (m, nord-sud)")
	terrain_row.add_child(_new_depth)
	terrain_row.add_child(_label("m", Color(0, 0, 0, 0)))
	_new_ground = OptionButton.new()
	_new_ground.tooltip_text = "Couleur du sol de la nouvelle mission (et de ses pistes)."
	for ground: String in GROUND_LABELS:
		_new_ground.add_item(GROUND_LABELS[ground])
		_new_ground.set_item_metadata(_new_ground.item_count - 1, ground)
	_new_ground.select(GROUND_LABELS.keys().find("grass"))
	terrain_row.add_child(_new_ground)
	_new_night = CheckBox.new()
	_new_night.text = "Nuit"
	_new_night.tooltip_text = "La nouvelle mission commence de nuit (modifiable ensuite dans la section Carte)."
	terrain_row.add_child(_new_night)
	add_child(terrain_row)
	var background_row := HBoxContainer.new()
	_new_background = OptionButton.new()
	_new_background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_background.tooltip_text = "Fond de la nouvelle mission : terrain plat (taille et sol ci-dessus), ou une carte UFO:AI du dossier des cartes, construite comme en jeu, à compléter de ses propres éléments."
	_new_background.item_selected.connect(func(_index: int) -> void: _update_background())
	background_row.add_child(_new_background)
	_new_guards = CheckBox.new()
	_new_guards.text = "Gardes"
	_new_guards.button_pressed = true
	_new_guards.tooltip_text = "Carte UFO:AI : un garde posté sur chaque départ d'alien (loin de l'équipe), à garder, déplacer ou supprimer."
	background_row.add_child(_new_guards)
	add_child(background_row)
	fill_backgrounds()
	_new_status = _label("", WARN_COLOR)
	_new_status.visible = false
	add_child(_new_status)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	_section("Vérification")
	var check_row := HBoxContainer.new()
	var check := Button.new()
	check.text = "Vérifier"
	check.tooltip_text = "Équipe, objectifs et leurs cibles, rondes, nombre de gardes, chemins à pied depuis le départ."
	check.pressed.connect(func() -> void: check_requested.emit())
	check_row.add_child(check)
	var play := Button.new()
	play.text = "Essayer"
	play.tooltip_text = "Enregistre la scène et la lance seule, comme depuis le choix des missions."
	play.pressed.connect(func() -> void: play_requested.emit())
	check_row.add_child(play)
	_body.add_child(check_row)
	_on_save = CheckBox.new()
	_on_save.text = "Vérifier à chaque enregistrement"
	_on_save.button_pressed = true
	_on_save.tooltip_text = "Après chaque Ctrl+S, la vérification tourne seule ; son résumé s'affiche sous le titre du dock."
	_body.add_child(_on_save)
	_report_box = VBoxContainer.new()
	_body.add_child(_report_box)

	_section("Informations")
	_info_box = VBoxContainer.new()
	_body.add_child(_info_box)
	_info_button = Button.new()
	_info_button.pressed.connect(func() -> void:
		if _info_button.get_meta(&"create", false):
			info_create_requested.emit()
		else:
			info_edit_requested.emit())
	_body.add_child(_info_button)

	_section("Carte")
	_night = CheckBox.new()
	_night.text = "Nuit"
	_night.tooltip_text = "Carte de nuit : vue des ennemis réduite, jumelles abaissées d'office, éclairage de nuit."
	_night.toggled.connect(func(on: bool) -> void:
		if not _updating:
			night_toggled.emit(on))
	_body.add_child(_night)
	var dress_row := HBoxContainer.new()
	var dress_label := _label("Tenue de rigueur")
	# Dans une rangée, une étiquette à la ligne n'aurait pas de largeur.
	dress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	dress_row.add_child(dress_label)
	_dress = OptionButton.new()
	for code in DRESS_CODES:
		_dress.add_item(_dress_name(code))
	_dress.item_selected.connect(func(index: int) -> void:
		if not _updating:
			dress_code_selected.emit(DRESS_CODES[index]))
	dress_row.add_child(_dress)
	_body.add_child(dress_row)
	var fit := Button.new()
	fit.text = "Caler les limites de la caméra sur le terrain"
	fit.tooltip_text = "Limites de déplacement de la caméra (cadre bleu dans la vue) à 2 m des bords du terrain. Pour les retoucher, sélectionnez CameraRig et tirez les poignées des bords."
	fit.pressed.connect(func() -> void: camera_fit_requested.emit())
	_body.add_child(fit)
	var game_view := Button.new()
	game_view.text = "Vue du jeu"
	game_view.tooltip_text = "Ouvre une fenêtre qui montre la carte sous l'angle et le zoom de la caméra du jeu (départ du CameraRig) ; glisser pour la déplacer, molette pour zoomer."
	game_view.pressed.connect(func() -> void: game_view_requested.emit())
	_body.add_child(game_view)
	_coverage = CheckBox.new()
	_coverage.text = "Couverture des gardes"
	_coverage.tooltip_text = "Colore le sol selon ce que voient les gardes (postés, et sur toute leur ronde), avec les règles du jeu et la nuit."
	_coverage.toggled.connect(func(on: bool) -> void:
		_coverage_legend.visible = on
		coverage_toggled.emit(on))
	_body.add_child(_coverage)
	_coverage_legend = _label("Rouge : vu même accroupi (zone proche). Jaune : vu debout (zone lointaine). Plus soutenu : plusieurs gardes. Recalculée à chaque changement.", DIM_COLOR)
	_coverage_legend.visible = false
	_body.add_child(_coverage_legend)

	_section("Animation")
	_body.add_child(_label("Rondes, pick-ups, avions, passants et voitures se déplacent comme en jeu (silhouettes, cône de vue des gardes).", DIM_COLOR))
	var play_row := HBoxContainer.new()
	_play = Button.new()
	_play.toggle_mode = true
	_play.text = "▶ Lecture"
	_play.tooltip_text = "Anime les unités mobiles dans la vue 3D, en boucle sur 3 minutes."
	_play.toggled.connect(func(on: bool) -> void:
		_play.text = "⏸ Pause" if on else "▶ Lecture"
		if not _updating:
			timeline_play_toggled.emit(on))
	play_row.add_child(_play)
	var rewind := Button.new()
	rewind.text = "⏮"
	rewind.tooltip_text = "Revenir au début et retirer les silhouettes."
	rewind.pressed.connect(func() -> void: timeline_reset.emit())
	play_row.add_child(rewind)
	var speed := OptionButton.new()
	speed.tooltip_text = "Vitesse de l'animation."
	for factor: float in TIMELINE_SPEEDS:
		speed.add_item("× %d" % int(factor))
	speed.item_selected.connect(func(index: int) -> void: timeline_speed_changed.emit(TIMELINE_SPEEDS[index]))
	play_row.add_child(speed)
	_time_label = _label("0,0 s")
	_time_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	play_row.add_child(_time_label)
	_body.add_child(play_row)
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = TIMELINE_DURATION
	_time_slider.step = 0.1
	_time_slider.tooltip_text = "Temps écoulé depuis le début de la mission."
	_time_slider.value_changed.connect(func(value: float) -> void:
		_time_label.text = _seconds(value)
		if not _updating:
			timeline_time_changed.emit(value))
	_body.add_child(_time_slider)

	_section("Événements")
	_body.add_child(_label("Renforts et pick-ups qui arrivent (catégorie Événements de la palette) : ce qui les déclenche, quand et combien. Une zone de déclenchement les appelle quand un opérateur y entre.", DIM_COLOR))
	_events_box = VBoxContainer.new()
	_body.add_child(_events_box)

	_section("Relief et bâtiments dessinés")
	_body.add_child(_label("Plateau : deux clics aux coins, une rampe au sud (côtés, rampes et hauteur dans l'inspecteur). Bâtiment dessiné : une pièce par rectangle (deux clics) ; la première crée le bâtiment, les suivantes s'ajoutent au bâtiment sélectionné. Portes et fenêtres : un clic près d'un mur. Escalier : un clic au bas de la volée, R pour son sens ; il monte d'un étage.", DIM_COLOR))
	var storey_row := HBoxContainer.new()
	storey_row.add_child(_inline_label("Étage"))
	_plan_storey = SpinBox.new()
	_plan_storey.min_value = 0
	_plan_storey.max_value = 9
	_plan_storey.tooltip_text = "Étage des pièces, portes, fenêtres et escaliers à poser (0 : rez-de-chaussée)."
	_plan_storey.value_changed.connect(func(value: float) -> void: plan_storey_changed.emit(int(value)))
	storey_row.add_child(_plan_storey)
	_body.add_child(storey_row)
	_plan_label = _label("", DIM_COLOR)
	_body.add_child(_plan_label)
	_plan_buttons = HBoxContainer.new()
	for spec: Array in [["Retirer la dernière pièce", "rooms"], ["… ouverture", "openings"], ["… escalier", "stairs"]]:
		var remove_last := Button.new()
		remove_last.text = spec[0]
		var kind: String = spec[1]
		remove_last.pressed.connect(func() -> void: plan_remove_requested.emit(kind))
		_plan_buttons.add_child(remove_last)
	_body.add_child(_plan_buttons)
	show_plan(null)

	_route_box = VBoxContainer.new()
	_route_box.visible = false
	_body.add_child(_route_box)
	_route_box.add_child(HSeparator.new())
	_route_label = _label("", Color(0.55, 0.8, 1.0))
	_route_box.add_child(_route_label)
	_route_box.add_child(_label("Faites glisser les poignées dans la vue 3D.", DIM_COLOR))
	var route_row := HBoxContainer.new()
	var add := Button.new()
	add.text = "Ajouter un point"
	add.pressed.connect(func() -> void: route_point_added.emit())
	route_row.add_child(add)
	var remove := Button.new()
	remove.text = "Retirer le dernier"
	remove.pressed.connect(func() -> void: route_point_removed.emit())
	route_row.add_child(remove)
	_route_box.add_child(route_row)

	_section("Pose")
	_grid = CheckBox.new()
	_grid.text = "Grille de 0,5 m"
	_grid.button_pressed = true
	_grid.toggled.connect(func(on: bool) -> void: grid_toggled.emit(on))
	_body.add_child(_grid)
	_surface = CheckBox.new()
	_surface.text = "Sur les toits et les étages"
	_surface.tooltip_text = "Pose sur la surface visée (toit, plancher, dessus d'un mur) ; décochée : toujours au sol. Revêtements, bâtiments et civils vont toujours au sol."
	_surface.button_pressed = true
	_body.add_child(_surface)
	_body.add_child(_label("Choisissez un élément, puis cliquez dans la vue 3D (deux clics pour un tracé ; une ronde : un clic par point, double-clic ou Entrée pour finir). R / Maj+R : tourner de 15°. Clic droit ou Échap : arrêter.", DIM_COLOR))
	_status = _label("")
	_body.add_child(_status)
	_group.allow_unpress = true
	for category in Palette.CATEGORIES:
		var entries := Palette.entries().filter(func(entry: Dictionary) -> bool: return entry["category"] == category)
		if entries.is_empty():
			continue
		_body.add_child(_label(category, Color(0.55, 0.8, 1.0)))
		var flow := HFlowContainer.new()
		_body.add_child(flow)
		for entry in entries:
			var button := Button.new()
			button.text = entry["label"]
			button.toggle_mode = true
			button.button_group = _group
			button.tooltip_text = _tooltip(entry["id"], entry["tool"])
			var id: String = entry["id"]
			button.toggled.connect(func(on: bool) -> void:
				if on:
					tool_selected.emit(id)
				elif _group.get_pressed_button() == null:
					tool_selected.emit(""))
			flow.add_child(button)
			_buttons[id] = button
	show_scene(null)


## Affiche la scène ouverte `root` (null ou autre qu'un niveau : panneau
## inactif) ; `generator` : script qui produit la carte (vide : aucun).
func show_scene(root: Node, generator: String = "") -> void:
	var level := root is LevelRoot
	_body.get_parent().visible = level
	_warning.visible = level and not generator.is_empty()
	if not level:
		_title.text = "Ouvrez une scène de mission (racine LevelRoot)." if root else "Aucune scène ouverte."
		return
	var info := info_of(root)
	var title := info.title if info and not info.title.is_empty() else String(root.name)
	_title.text = "Mission : %s\n%s" % [title, root.scene_file_path]
	_warning.text = "Carte générée par %s : une régénération écraserait les modifications faites ici (le générateur refuse d'écraser une scène modifiée depuis)." % generator
	_updating = true
	_night.button_pressed = root.get("night")
	_dress.selected = maxi(DRESS_CODES.find(root.get("dress_code")), 0)
	_updating = false
	_show_info(root, info)
	show_events(root, info)


## Informations de la mission `root` (null : pas encore de fichier).
static func info_of(root: Node) -> MissionInfo:
	if root == null or root.scene_file_path.is_empty():
		return null
	var path := MissionInfo.path_for(root.scene_file_path)
	return load(path) as MissionInfo if ResourceLoader.exists(path) else null


func _show_info(root: Node, info: MissionInfo) -> void:
	_info_button.set_meta(&"create", info == null)
	var signature := "none" if info == null else "%s|%s" % [info.get_instance_id(), "|".join(_pairs(info).map(func(pair: Array) -> String: return "%s=%s" % pair))]
	if signature != _objectives_signature:
		_objectives_signature = signature
		_build_objectives(info)
	if info == null:
		return
	# État des cibles de chaque objectif (la carte a pu changer).
	var found := MissionTargets.targets(root)
	for row in _objective_rows:
		var mark: Button = row["mark"]
		var id: String = row["id"]
		var nodes: Variant = MissionTargets.targets_of(id, found)
		for connection in mark.pressed.get_connections():
			mark.pressed.disconnect(connection["callable"])
		if nodes == null:
			mark.text = "•"
			mark.tooltip_text = "Suivi par le jeu, sans cible sur la carte."
			mark.add_theme_color_override(&"font_color", DIM_COLOR)
		elif (nodes as Array).is_empty():
			mark.text = "⚠"
			mark.tooltip_text = "Aucune cible sur la carte pour « %s »." % id
			mark.add_theme_color_override(&"font_color", WARN_COLOR)
		else:
			var names: Array = (nodes as Array).slice(0, 3).map(func(n: Node) -> String: return String(n.name))
			mark.text = "✓"
			mark.tooltip_text = "Cible : %s%s. Cliquez pour la sélectionner." % [", ".join(names), "…" if (nodes as Array).size() > 3 else ""]
			mark.add_theme_color_override(&"font_color", OK_COLOR)
			mark.pressed.connect(func() -> void: nodes_selected.emit(nodes))


## Objectifs de `info` : [[identifiant, texte], …].
static func _pairs(info: MissionInfo) -> Array:
	var pairs: Array = []
	for objective in info.objectives:
		if objective:
			pairs.append([objective.id, objective.text])
	return pairs


func _build_objectives(info: MissionInfo) -> void:
	# Le champ qui avait le focus le perd en sortant de l'arbre : sa
	# validation ne doit pas porter sur la nouvelle liste.
	_rebuilding = true
	for child in _info_box.get_children():
		_info_box.remove_child(child)
		child.queue_free()
	_rebuilding = false
	_objective_rows.clear()
	if info == null:
		_info_box.add_child(_label("Pas encore d'informations : la mission n'apparaît pas dans le jeu.", WARN_COLOR))
		_info_button.text = "Créer les informations"
		return
	_info_button.text = "Titre, description, camouflage : inspecteur"
	_info_box.add_child(_label("Camouflage conseillé : %s" % info.camo, DIM_COLOR))
	var pairs := _pairs(info)
	if pairs.is_empty():
		_info_box.add_child(_label("Aucun objectif.", WARN_COLOR))
	for index in pairs.size():
		var pair: Array = pairs[index]
		var row := HBoxContainer.new()
		_info_box.add_child(row)
		var mark := Button.new()
		mark.flat = true
		row.add_child(mark)
		var choice := OptionButton.new()
		choice.tooltip_text = "Identifiant suivi par le jeu : ce qui remplit l'objectif."
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ids: Array[String] = MissionObjective.KNOWN_IDS.duplicate()
		if not pair[0] in ids:
			ids.push_front(pair[0])
		for id in ids:
			choice.add_item(id)
		choice.select(ids.find(pair[0]))
		choice.item_selected.connect(func(item: int) -> void:
			var edited := _pairs(info)
			var before: String = edited[index][0]
			edited[index][0] = ids[item]
			# Texte encore celui proposé pour l'ancien identifiant : suit.
			if edited[index][1] == MissionTargets.suggested_text(before) or (edited[index][1] as String).is_empty():
				edited[index][1] = MissionTargets.suggested_text(ids[item])
			objectives_edited.emit(edited))
		row.add_child(choice)
		for spec: Array in [["↑", -1, "Monter"], ["↓", 1, "Descendre"]]:
			var move := Button.new()
			move.text = spec[0]
			move.tooltip_text = "%s l'objectif (ordre du journal en jeu)." % spec[2]
			var step: int = spec[1]
			move.disabled = index + step < 0 or index + step >= pairs.size()
			move.pressed.connect(func() -> void:
				var edited := _pairs(info)
				var moved: Array = edited.pop_at(index)
				edited.insert(index + step, moved)
				objectives_edited.emit(edited))
			row.add_child(move)
		var remove := Button.new()
		remove.text = "✕"
		remove.tooltip_text = "Retirer l'objectif."
		remove.pressed.connect(func() -> void:
			var edited := _pairs(info)
			edited.remove_at(index)
			objectives_edited.emit(edited))
		row.add_child(remove)
		var text := LineEdit.new()
		text.text = pair[1]
		text.placeholder_text = "Texte du journal"
		text.tooltip_text = "Texte affiché dans le journal des objectifs ; Entrée ou quitter le champ pour valider."
		var commit := func(_value: String = "") -> void:
			if _rebuilding or not text.is_inside_tree():
				return
			var edited := _pairs(info)
			if index < edited.size() and edited[index][1] != text.text:
				edited[index][1] = text.text
				objectives_edited.emit(edited)
		text.text_submitted.connect(commit)
		text.focus_exited.connect(commit)
		_info_box.add_child(text)
		_objective_rows.append({"mark": mark, "id": pair[0], "text": text, "choice": choice})
	var add := OptionButton.new()
	add.tooltip_text = "Ajoute un objectif à la fin de la liste, avec un texte proposé à reprendre."
	add.add_item("+ Ajouter un objectif…")
	for id in MissionObjective.KNOWN_IDS:
		if not id.begins_with("tuto_"):
			add.add_item(id)
	add.item_selected.connect(func(item: int) -> void:
		if item == 0:
			return
		var id := add.get_item_text(item)
		var edited := _pairs(info)
		edited.append([id, MissionTargets.suggested_text(id)])
		objectives_edited.emit(edited))
	_info_box.add_child(add)


## Fiches des événements scriptés de `root` : déclenchement (objectif de la
## mission, zones), délai, soldats, pick-up, annonce.
func show_events(root: Node, info: MissionInfo) -> void:
	var events := Events.events(root)
	# Fiches refaites si la liste change (ajout, retrait, renommage).
	var signature := ",".join(events.map(func(n: Node) -> String: return "%d:%s" % [n.get_instance_id(), n.name]))
	if signature != _events_signature:
		_events_signature = signature
		for child in _events_box.get_children():
			child.queue_free()
		_event_rows.clear()
		if events.is_empty():
			_events_box.add_child(_label("Aucun événement sur la carte.", DIM_COLOR))
		for event in events:
			_event_rows[event] = _event_card(event)
	var objectives: Array[StringName] = [&""]
	if info:
		for objective in info.objectives:
			if objective and not objective.id.is_empty():
				objectives.append(StringName(objective.id))
	_updating = true
	for event: Node3D in events:
		var row: Dictionary = _event_rows[event]
		var trigger := Events.trigger_text(root, event)
		var summary: Label = row["summary"]
		summary.text = "%s — après %s s : %s%s" % [("déclenché par " + trigger) if not trigger.is_empty() else "⚠ rien ne le déclenche", _number(event.get("delay")), Events.arrival_text(event), "" if event.get("announce") else ", sans annonce"]
		summary.add_theme_color_override(&"font_color", DIM_COLOR if not trigger.is_empty() else WARN_COLOR)
		var choice: OptionButton = row["objective"]
		var current: StringName = event.get("start_objective")
		var listed := objectives.duplicate()
		if not current in listed:
			listed.append(current)
		choice.clear()
		for id in listed:
			choice.add_item("aucun (zones seules)" if id == &"" else String(id))
			choice.set_item_metadata(choice.item_count - 1, id)
		choice.select(listed.find(current))
		(row["delay"] as SpinBox).value = event.get("delay")
		(row["count"] as SpinBox).value = event.get("count")
		(row["technical"] as CheckBox).button_pressed = event.get("technical")
		(row["announce"] as CheckBox).button_pressed = event.get("announce")
	_updating = false


func _event_card(event: Node3D) -> Dictionary:
	var card := VBoxContainer.new()
	_events_box.add_child(card)
	var head := HBoxContainer.new()
	card.add_child(head)
	var name_button := Button.new()
	name_button.flat = true
	name_button.text = "◆ %s" % event.name
	name_button.add_theme_color_override(&"font_color", Color(1.0, 0.5, 0.85))
	name_button.tooltip_text = "Sélectionner l'événement."
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.pressed.connect(func() -> void: nodes_selected.emit([event]))
	head.add_child(name_button)
	var zone := Button.new()
	zone.text = "Tracer une zone"
	zone.tooltip_text = "Deux clics dans la vue 3D : coins opposés d'une zone qui déclenche cet événement quand un opérateur y entre."
	zone.pressed.connect(func() -> void: event_zone_requested.emit(event))
	head.add_child(zone)
	var summary := _label("")
	card.add_child(summary)
	var start_row := HBoxContainer.new()
	card.add_child(start_row)
	start_row.add_child(_inline_label("Objectif déclencheur"))
	var objective := OptionButton.new()
	objective.tooltip_text = "Objectif de la mission dont la réussite lance le compte à rebours (start_objective)."
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.item_selected.connect(func(index: int) -> void:
		if not _updating:
			event_changed.emit(event, &"start_objective", objective.get_item_metadata(index)))
	start_row.add_child(objective)
	var numbers := HBoxContainer.new()
	card.add_child(numbers)
	numbers.add_child(_inline_label("Délai"))
	var delay := _event_spin(event, &"delay", 0, 600, 1, "Secondes entre le déclenchement et l'arrivée.")
	numbers.add_child(delay)
	numbers.add_child(_inline_label("s  Soldats"))
	var count := _event_spin(event, &"count", 0, 12, 1, "Soldats qui arrivent (0 : le pick-up seul).")
	numbers.add_child(count)
	var flags := HBoxContainer.new()
	card.add_child(flags)
	var technical := _event_check(event, &"technical", "Pick-up armé", "Un pick-up armé arrive avec eux.")
	flags.add_child(technical)
	var announce := _event_check(event, &"announce", "Annoncé", "Compte à rebours et arrivée affichés en haut de l'écran ; décoché : arrivée par surprise.")
	flags.add_child(announce)
	return {"summary": summary, "objective": objective, "delay": delay, "count": count, "technical": technical, "announce": announce}


func _event_spin(event: Node3D, property: StringName, low: float, high: float, step: float, tip: String) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = step
	box.tooltip_text = tip
	box.value_changed.connect(func(value: float) -> void:
		if not _updating:
			event_changed.emit(event, property, int(value) if property == &"count" else value))
	return box


func _event_check(event: Node3D, property: StringName, text: String, tip: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.tooltip_text = tip
	check.toggled.connect(func(on: bool) -> void:
		if not _updating:
			event_changed.emit(event, property, on))
	return check


static func _inline_label(text: String) -> Label:
	var label := _label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value).replace(".", ",")


## Appuie sur le bouton de la palette `id` (l'outil est choisi).
func press_tool(id: String) -> void:
	if _buttons.has(id):
		(_buttons[id] as Button).button_pressed = true


## Résultat de « Vérifier » (`Checker.check`) ; vide : efface.
func check_on_save() -> bool:
	return _on_save.button_pressed


## Résumé du rapport `report` sous le titre : nombre d'erreurs et
## d'avertissements, origine (`reason`) et heure. Masqué si `report` est vide.
func show_summary(report: Array, reason: String) -> void:
	_summary.visible = not report.is_empty()
	if report.is_empty():
		return
	var errors := report.filter(func(item: Dictionary) -> bool: return item["level"] == "error").size()
	var warnings := report.filter(func(item: Dictionary) -> bool: return item["level"] == "warning").size()
	var counts: Array[String] = []
	if errors > 0:
		counts.append("%d erreur%s" % [errors, "s" if errors > 1 else ""])
	if warnings > 0:
		counts.append("%d avertissement%s" % [warnings, "s" if warnings > 1 else ""])
	var mark := "✗" if errors > 0 else ("⚠" if warnings > 0 else "✓")
	var time := Time.get_time_dict_from_system()
	_summary.text = "%s Vérification (%s, %02d:%02d) : %s" % [mark, reason, time["hour"], time["minute"], ", ".join(counts) if not counts.is_empty() else "aucun problème"]
	_summary.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4) if errors > 0 else (WARN_COLOR if warnings > 0 else OK_COLOR))


func show_report(report: Array) -> void:
	for child in _report_box.get_children():
		child.queue_free()
	for item: Dictionary in report:
		var line := Button.new()
		line.flat = true
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark: String = {"error": "✗", "warning": "⚠", "ok": "✓"}[item["level"]]
		line.text = "%s %s" % [mark, item["text"]]
		line.add_theme_color_override(&"font_color", {"error": Color(1.0, 0.45, 0.4), "warning": WARN_COLOR, "ok": OK_COLOR}[item["level"]])
		var nodes: Array = item["nodes"]
		if not nodes.is_empty():
			line.tooltip_text = "Cliquez pour sélectionner."
			line.pressed.connect(func() -> void: nodes_selected.emit(nodes))
		_report_box.add_child(line)


## Temps de l'animation affiché (sans émettre de signal), et lecture.
func show_time(time: float, playing: bool) -> void:
	_updating = true
	_time_slider.value = time
	_time_label.text = _seconds(time)
	_play.button_pressed = playing
	_updating = false


static func _seconds(time: float) -> String:
	return ("%.1f s" % time).replace(".", ",")


## Réglages de la nouvelle mission : {"size": Vector2, "ground", "night"}.
func new_mission_options() -> Dictionary:
	return {
		"size": Vector2(_new_width.value, _new_depth.value),
		"ground": String(_new_ground.get_selected_metadata()),
		"night": _new_night.button_pressed,
		"ufo_map": String(_new_background.get_selected_metadata()),
		"guards": _new_guards.button_pressed,
	}


## Liste des fonds : terrain plat, puis les cartes UFO:AI entières du
## dossier des cartes (fichiers `.map` à sa racine, comme le choix des
## missions du jeu).
func fill_backgrounds() -> void:
	_new_background.clear()
	_new_background.add_item("Terrain plat")
	_new_background.set_item_metadata(0, "")
	for file in ufo_maps():
		_new_background.add_item("Carte UFO:AI : %s" % file.get_basename())
		_new_background.set_item_metadata(_new_background.item_count - 1, file)
	_update_background()


static func ufo_maps() -> Array[String]:
	var found: Array[String] = []
	var dir := AssetPaths.maps_dir()
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() == "map":
				found.append(file)
	found.sort()
	return found


## Taille et sol ne valent que pour le terrain plat ; « Gardes » que pour
## une carte UFO:AI.
func _update_background() -> void:
	var flat := String(_new_background.get_selected_metadata()).is_empty()
	_new_width.editable = flat
	_new_depth.editable = flat
	_new_ground.disabled = not flat
	_new_guards.disabled = flat


func _size_box(tip: String) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = NEW_SIZE_MIN
	box.max_value = NEW_SIZE_MAX
	box.step = 10
	box.value = 80
	box.tooltip_text = tip
	return box


## Message sous « Nouvelle mission » (vide : aucun).
func set_new_mission_status(text: String) -> void:
	_new_status.text = text
	_new_status.visible = not text.is_empty()


## Trajet de `node` (passant, voiture) à modifier ; null : aucun.
func show_route(node: Node) -> void:
	_route_box.visible = node != null
	if node:
		_route_label.text = "Trajet de %s : %d points" % [node.name, (node.get("points") as PackedVector3Array).size()]


## Bâtiment dessiné sélectionné (`node`), ou aucun.
func show_plan(node: Node) -> void:
	_plan_buttons.visible = node != null
	if node == null:
		_plan_label.text = "Aucun bâtiment dessiné sélectionné : une pièce tracée en crée un."
		return
	var counts := {}
	var levels: PackedInt32Array = node.get("room_storeys")
	var rooms: Array = node.get("rooms")
	for i in rooms.size():
		var storey := levels[i] if i < levels.size() else 0
		counts[storey] = counts.get(storey, 0) + 1
	var parts: Array[String] = []
	var keys := counts.keys()
	keys.sort()
	for storey: int in keys:
		parts.append("étage %d : %d" % [storey, counts[storey]])
	_plan_label.text = "%s : %d pièce%s (%s), %d ouverture%s, %d escalier%s." % [node.name, rooms.size(), "s" if rooms.size() > 1 else "", ", ".join(parts),
		(node.get("openings") as Array).size(), "s" if (node.get("openings") as Array).size() > 1 else "",
		(node.get("stairs") as Array).size(), "s" if (node.get("stairs") as Array).size() > 1 else ""]


func plan_storey() -> int:
	return int(_plan_storey.value)


## Relâche le bouton de l'outil en cours.
func clear_tool() -> void:
	var pressed := _group.get_pressed_button()
	if pressed:
		pressed.button_pressed = false


func set_status(text: String) -> void:
	_status.text = text


func grid_enabled() -> bool:
	return _grid.button_pressed


func coverage_enabled() -> bool:
	return _coverage.button_pressed


func surface_enabled() -> bool:
	return _surface.button_pressed


func _section(text: String) -> void:
	_body.add_child(HSeparator.new())
	_body.add_child(_label(text, Color(0.55, 0.8, 1.0)))


static func _label(text: String, color: Color = Color(0, 0, 0, 0)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color.a > 0.0:
		label.add_theme_color_override(&"font_color", color)
	return label


static func _tooltip(id: String, tool: String) -> String:
	var how: String = {"line": "Tracé : deux clics (début, fin).", "route": "Ronde : un clic par point, double-clic ou Entrée pour finir, Retour arrière pour retirer le dernier point."}.get(tool, "Un clic pour poser.")
	match id:
		"patrol":
			return how + " Le garde fait la ronde de ce tracé et revient au premier point ; le chemin (PatrolPaths) se modifie ensuite avec les outils de Godot."
		"technical":
			return how + " Le pick-up suit ce tracé en boucle ; le chemin (PatrolPaths) se modifie ensuite avec les outils de Godot."
		"traffic":
			return "Deux clics : coins opposés du rectangle de rues. Les voitures tournent dans le sens inverse des aiguilles d'une montre."
		"passerby":
			return how + " Le passant marche en aller-retour sur ce tracé."
		"operator":
			return how + " Prend le nom et le numéro suivants (Alpha, Bravo…)."
		"extraction":
			return how + " Objectif « extracted » : toute l'équipe dans la zone."
		"barrier":
			return how + " Le cap (R / Maj+R) suit la route : la barrière se pose en travers, un muret de chaque côté."
		"aircraft":
			return how + " L'avion survole ce trajet (PatrolPaths) à `altitude` m ; ajoutez des points en sélectionnant le chemin."
		"reinforcements":
			return how + " Point d'arrivée des renforts ; ils foncent vers le dépôt (`target`) quand `start_objective` est rempli, ou quand un opérateur entre dans une de leurs zones de déclenchement. Réglages dans la section Événements."
		"arrival":
			return how + " Un pick-up armé arrive ici sans annonce, quelques secondes après l'entrée d'un opérateur dans sa zone de déclenchement (à tracer ensuite), et fonce vers la zone."
		"terrace":
			return "Deux clics : coins opposés du dessus. Plateau de 2 m, une rampe au sud ; hauteur, rampes (côté, décalage) et couleurs dans l'inspecteur. Une échelle contre un flanc y fait monter aussi."
		"plan_room":
			return "Deux clics : coins opposés de la pièce, à l'étage choisi (section Relief et bâtiments dessinés). Ajoutée au bâtiment dessiné sélectionné, ou à celui où l'on clique ; sinon, un nouveau bâtiment. Deux pièces qui se touchent partagent leur mur."
		"plan_door":
			return "Un clic près d'un mur (1 m au plus) du bâtiment dessiné, à l'étage choisi : porte de 1,2 m, comme celles de l'immeuble (verrouillée : genre 2 dans `openings`, inspecteur)."
		"plan_window":
			return "Un clic près d'un mur du bâtiment dessiné, à l'étage choisi : fenêtre (appui 0,9 m, linteau 2,1 m) ; on voit au travers."
		"plan_stairs":
			return "Un clic au bas de la volée, à l'étage choisi ; R / Maj+R : sens de la montée. Elle monte d'un étage ; la dalle au-dessus est percée."
		"trigger_zone":
			return "Deux clics : coins opposés de la zone. Elle déclenche l'événement sélectionné (ou choisi par « Tracer une zone » dans la section Événements, sinon le dernier sans zone) quand un opérateur y entre. Coins à poignées pour la retoucher."
		"ied":
			return how + " Mine artisanale (engin explosif improvisé)."
	return how


static func _dress_name(code: StringName) -> String:
	if code == &"":
		return "Aucune"
	if GearCatalog.CLOTHING.has(code):
		return GearCatalog.CLOTHING[code]["name"]
	return String(code)
