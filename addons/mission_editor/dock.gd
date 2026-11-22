@tool
extends VBoxContainer
## Dock « Mission » du greffon : scène ouverte, avertissement sur les cartes
## générées, nouvelle mission, vérification et essai, informations de la
## mission (objectifs et leurs cibles), réglages de la carte, trajet
## sélectionné, grille et palette des éléments à poser.

const Palette := preload("res://addons/mission_editor/palette.gd")
const MissionTargets := preload("res://addons/mission_editor/mission_targets.gd")

## Outil choisi dans la palette (vide : aucun).
signal tool_selected(id: String)
signal night_toggled(night: bool)
signal dress_code_selected(code: StringName)
signal grid_toggled(enabled: bool)
## Informations de la mission : à ouvrir dans l'inspecteur, à créer.
signal info_edit_requested
signal info_create_requested
## Un objectif cliqué : nœuds de sa cible à sélectionner.
signal nodes_selected(nodes: Array)
## Trajet sélectionné : ajouter ou retirer un point.
signal route_point_added
signal route_point_removed
## Nouvelle mission dans `scenes/levels/<folder>/`.
signal new_mission_requested(folder: String)
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
var _night: CheckBox
var _dress: OptionButton
var _route_box: VBoxContainer
var _route_label: Label
var _new_folder: LineEdit
var _new_status: Label
var _report_box: VBoxContainer
var _grid: CheckBox
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
	var new_row := HBoxContainer.new()
	_new_folder = LineEdit.new()
	_new_folder.placeholder_text = "dossier (ex. raid_desert)"
	_new_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_folder.text_submitted.connect(func(text: String) -> void: new_mission_requested.emit(text.strip_edges()))
	new_row.add_child(_new_folder)
	var create := Button.new()
	create.text = "Nouvelle mission"
	create.tooltip_text = "Crée scenes/levels/<dossier>/<dossier>.tscn (terrain, équipe, extraction) et son mission.tres, puis l'ouvre."
	create.pressed.connect(func() -> void: new_mission_requested.emit(_new_folder.text.strip_edges()))
	new_row.add_child(create)
	add_child(new_row)
	_new_status = _label("", WARN_COLOR)
	_new_status.visible = false
	add_child(_new_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

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
	_body.add_child(_label("Choisissez un élément, puis cliquez dans la vue 3D (deux clics pour un tracé). R / Maj+R : tourner de 15°. Clic droit ou Échap : arrêter.", DIM_COLOR))
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


## Informations de la mission `root` (null : pas encore de fichier).
static func info_of(root: Node) -> MissionInfo:
	if root == null or root.scene_file_path.is_empty():
		return null
	var path := MissionInfo.path_for(root.scene_file_path)
	return load(path) as MissionInfo if ResourceLoader.exists(path) else null


func _show_info(root: Node, info: MissionInfo) -> void:
	for child in _info_box.get_children():
		child.queue_free()
	_info_button.set_meta(&"create", info == null)
	if info == null:
		_info_box.add_child(_label("Pas encore d'informations : la mission n'apparaît pas dans le jeu.", WARN_COLOR))
		_info_button.text = "Créer les informations"
		return
	_info_button.text = "Modifier dans l'inspecteur"
	_info_box.add_child(_label("Camouflage conseillé : %s" % info.camo, DIM_COLOR))
	if info.objectives.is_empty():
		_info_box.add_child(_label("Aucun objectif.", WARN_COLOR))
	var found := MissionTargets.targets(root)
	for objective in info.objectives:
		if objective == null:
			continue
		var nodes: Variant = MissionTargets.targets_of(objective.id, found)
		var line := Button.new()
		line.flat = true
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := objective.text if not objective.text.is_empty() else objective.id
		if nodes == null:
			line.text = "• %s (suivi par le jeu)" % text
			line.add_theme_color_override(&"font_color", DIM_COLOR)
		elif (nodes as Array).is_empty():
			line.text = "⚠ %s : aucune cible sur la carte (%s)" % [text, objective.id]
			line.add_theme_color_override(&"font_color", WARN_COLOR)
		else:
			var names: Array = (nodes as Array).slice(0, 3).map(func(n: Node) -> String: return String(n.name))
			line.text = "✓ %s → %s%s" % [text, ", ".join(names), "…" if (nodes as Array).size() > 3 else ""]
			line.add_theme_color_override(&"font_color", OK_COLOR)
			line.tooltip_text = "Cliquez pour sélectionner la cible."
			line.pressed.connect(func() -> void: nodes_selected.emit(nodes))
		_info_box.add_child(line)


## Résultat de « Vérifier » (`Checker.check`) ; vide : efface.
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


## Message sous « Nouvelle mission » (vide : aucun).
func set_new_mission_status(text: String) -> void:
	_new_status.text = text
	_new_status.visible = not text.is_empty()


## Trajet de `node` (passant, voiture) à modifier ; null : aucun.
func show_route(node: Node) -> void:
	_route_box.visible = node != null
	if node:
		_route_label.text = "Trajet de %s : %d points" % [node.name, (node.get("points") as PackedVector3Array).size()]


## Relâche le bouton de l'outil en cours.
func clear_tool() -> void:
	var pressed := _group.get_pressed_button()
	if pressed:
		pressed.button_pressed = false


func set_status(text: String) -> void:
	_status.text = text


func grid_enabled() -> bool:
	return _grid.button_pressed


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
	var how := "Tracé : deux clics (début, fin)." if tool == "line" else "Un clic pour poser."
	match id:
		"patrol":
			return how + " Le garde fait la ronde de ce tracé ; ajoutez des points en sélectionnant le chemin (PatrolPaths)."
		"technical":
			return how + " Le pick-up suit ce tracé ; ajoutez des points en sélectionnant le chemin (PatrolPaths)."
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
			return how + " Point d'arrivée des renforts ; ils foncent vers le dépôt (`target`) quand `start_objective` est rempli."
		"ied":
			return how + " Mine artisanale (engin explosif improvisé)."
	return how


static func _dress_name(code: StringName) -> String:
	if code == &"":
		return "Aucune"
	if GearCatalog.CLOTHING.has(code):
		return GearCatalog.CLOTHING[code]["name"]
	return String(code)
