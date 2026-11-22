@tool
extends VBoxContainer
## Dock « Mission » du greffon : scène ouverte, avertissement sur les cartes
## générées, réglages de la carte, grille et palette des éléments à poser.

const Palette := preload("res://addons/mission_editor/palette.gd")

## Outil choisi dans la palette (vide : aucun).
signal tool_selected(id: String)
signal night_toggled(night: bool)
signal dress_code_selected(code: StringName)
signal grid_toggled(enabled: bool)

## Tenues de rigueur proposées (vide : aucune).
const DRESS_CODES: Array[StringName] = [&"", &"suit", &"casual", &"uniform"]

var _title: Label
var _warning: Label
var _night: CheckBox
var _dress: OptionButton
var _grid: CheckBox
var _status: Label
var _body: VBoxContainer
var _buttons: Dictionary = {}
var _group := ButtonGroup.new()
var _updating: bool = false


func _init() -> void:
	name = "Mission"
	custom_minimum_size = Vector2(220, 0)
	_title = Label.new()
	_title.text = "Aucune mission ouverte"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	_warning = Label.new()
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.3))
	_warning.visible = false
	add_child(_warning)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_section("Carte")
	_night = CheckBox.new()
	_night.text = "Nuit"
	_night.tooltip_text = "Carte de nuit : vue des ennemis réduite, jumelles abaissées d'office, éclairage de nuit."
	_night.toggled.connect(func(on: bool) -> void:
		if not _updating:
			night_toggled.emit(on))
	_body.add_child(_night)
	var dress_row := HBoxContainer.new()
	var dress_label := Label.new()
	dress_label.text = "Tenue de rigueur"
	dress_row.add_child(dress_label)
	_dress = OptionButton.new()
	for code in DRESS_CODES:
		_dress.add_item(_dress_name(code))
	_dress.item_selected.connect(func(index: int) -> void:
		if not _updating:
			dress_code_selected.emit(DRESS_CODES[index]))
	dress_row.add_child(_dress)
	_body.add_child(dress_row)
	_section("Pose")
	_grid = CheckBox.new()
	_grid.text = "Grille de 0,5 m"
	_grid.button_pressed = true
	_grid.toggled.connect(func(on: bool) -> void: grid_toggled.emit(on))
	_body.add_child(_grid)
	var hint := Label.new()
	hint.text = "Choisissez un élément, puis cliquez dans la vue 3D (deux clics pour un tracé). R / Maj+R : tourner de 15°. Clic droit ou Échap : arrêter."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	_body.add_child(hint)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)
	_group.allow_unpress = true
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var palette := VBoxContainer.new()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(palette)
	_body.add_child(scroll)
	for category in Palette.CATEGORIES:
		var entries := Palette.entries().filter(func(entry: Dictionary) -> bool: return entry["category"] == category)
		if entries.is_empty():
			continue
		var label := Label.new()
		label.text = category
		label.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
		palette.add_child(label)
		var flow := HFlowContainer.new()
		palette.add_child(flow)
		for entry in entries:
			var button := Button.new()
			button.text = entry["label"]
			button.toggle_mode = true
			button.button_group = _group
			button.tooltip_text = "Tracé : deux clics (début, fin)." if entry["tool"] == "line" else "Un clic pour poser."
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
	_body.visible = level
	_warning.visible = level and not generator.is_empty()
	if not level:
		_title.text = "Ouvrez une scène de mission (racine LevelRoot)." if root else "Aucune scène ouverte."
		return
	var info_path := MissionInfo.path_for(root.scene_file_path)
	var title := root.name as String
	if ResourceLoader.exists(info_path):
		var info := load(info_path) as MissionInfo
		if info and not info.title.is_empty():
			title = info.title
	_title.text = "Mission : %s\n%s" % [title, root.scene_file_path]
	_warning.text = "Carte générée par %s : une régénération écraserait les modifications faites ici (le générateur refuse d'écraser une scène modifiée depuis)." % generator
	_updating = true
	_night.button_pressed = root.get("night")
	_dress.selected = maxi(DRESS_CODES.find(root.get("dress_code")), 0)
	_updating = false


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
	var separator := HSeparator.new()
	_body.add_child(separator)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
	_body.add_child(label)


static func _dress_name(code: StringName) -> String:
	if code == &"":
		return "Aucune"
	if GearCatalog.CLOTHING.has(code):
		return GearCatalog.CLOTHING[code]["name"]
	return String(code)
