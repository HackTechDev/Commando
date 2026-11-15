class_name MainMenu
extends Control
## Menu de démarrage : choix de la carte (`LevelCatalog`, puis les autres
## cartes UFO:AI du dossier), avec aperçu et dernière carte jouée en tête de
## liste ; préparation de la mission (tenues et camouflage conseillé),
## chargement en arrière-plan puis lancement du niveau ; accès à l'écran
## « Opérateurs ».

## Taille des vignettes d'aperçu.
const THUMB_SIZE := Vector2(150, 96)

@onready var _levels: VBoxContainer = %Levels
@onready var _status: Label = %Status
@onready var _quit: Button = %Quit
@onready var _operators: Button = %Operators

## Scène en cours de chargement, ou vide.
var _loading: String = ""
## Confirmation avant de quitter.
var quit_dialog: ConfirmDialog
## Préparation de la mission, ouverte par « Jouer ».
var briefing: Control
var _briefing_level: Dictionary = {}
var _briefing_rows: VBoxContainer
var _briefing_camo: Label
var _suggest_all: Button
var _briefing_preview: Control
var _briefing_objectives: VBoxContainer
## Écran « Opérateurs » ouvert depuis la préparation, ou null.
var operator_editor: OperatorScreen

## Taille de l'aperçu de la carte dans la préparation.
const BRIEFING_PREVIEW_SIZE := Vector2(320, 200)


func _ready() -> void:
	# Revenir au menu remet l'alerte à zéro (elle ne se recalcule qu'en jeu).
	GameState.alert_level = GameState.AlertLevel.CALM
	_status.text = ""
	quit_dialog = ConfirmDialog.for_quit(self)
	add_child(quit_dialog)
	_quit.pressed.connect(quit_dialog.ask)
	_operators.pressed.connect(open_operators)
	var first: Button = null
	var last: Button = null
	var last_key := Settings.last_level()
	var extras_shown := false
	for level in LevelCatalog.all_levels():
		if level.get("extra", false) and not extras_shown:
			extras_shown = true
			var heading := Label.new()
			heading.name = "ExtraHeading"
			heading.text = "AUTRES CARTES UFO:AI DU DOSSIER (non adaptées)"
			heading.add_theme_font_size_override(&"font_size", 16)
			_levels.add_child(heading)
		var button := _add_level(level, LevelCatalog.key_of(level) == last_key)
		if first == null and not button.disabled:
			first = button
		if LevelCatalog.key_of(level) == last_key and not button.disabled:
			last = button
	# La dernière carte jouée passe en tête de liste, sélectionnée.
	if last:
		_levels.move_child(last.get_parent().get_parent(), 0)
		first = last
	if first:
		first.grab_focus()


## Bouton « Jouer » de la carte de clé `key` (tests), ou null.
func play_button(key: String) -> Button:
	for card in _levels.get_children():
		if card.get_meta(&"key", "") == key:
			return card.find_child("Play", true, false) as Button
	return null


func _add_level(level: Dictionary, is_last: bool = false) -> Button:
	var card := PanelContainer.new()
	card.set_meta(&"key", LevelCatalog.key_of(level))
	_levels.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)
	row.add_child(preview_of(level, THUMB_SIZE))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var title := Label.new()
	title.text = level["title"] + ("   — dernière partie" if is_last else "")
	title.add_theme_font_size_override(&"font_size", 22)
	texts.add_child(title)
	var description := Label.new()
	description.text = level["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(1, 1, 1, 0.75)
	texts.add_child(description)
	var button := Button.new()
	button.name = "Play"
	button.text = "Jouer"
	button.custom_minimum_size = Vector2(110, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	var reason := LevelCatalog.unavailable_reason(level)
	if reason.is_empty():
		button.pressed.connect(open_briefing.bind(level))
	else:
		button.disabled = true
		button.tooltip_text = reason
		var warning := Label.new()
		warning.text = reason
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_color_override(&"font_color", Color(1.0, 0.6, 0.3))
		warning.add_theme_font_size_override(&"font_size", 13)
		texts.add_child(warning)
	return button


## Vignette d'aperçu du niveau `level` (vue du dessus enregistrée après une
## première partie), ou cadre d'attente.
static func preview_of(level: Dictionary, size: Vector2) -> Control:
	var texture := LevelPreview.load_texture(LevelCatalog.key_of(level))
	if texture:
		var picture := TextureRect.new()
		picture.name = "Preview"
		picture.texture = texture
		picture.custom_minimum_size = size
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return picture
	var frame := PanelContainer.new()
	frame.name = "NoPreview"
	frame.custom_minimum_size = size
	var hint := Label.new()
	hint.text = "Aperçu après\nune première partie"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	frame.add_child(hint)
	return frame


## Ouvre l'écran de personnalisation des opérateurs.
func open_operators() -> void:
	if _loading.is_empty():
		get_tree().change_scene_to_file(OperatorScreen.SCENE)


## Ouvre la préparation de la mission `level` : tenue de chaque opérateur
## (tenues enregistrées) et camouflage conseillé pour la carte.
func open_briefing(level: Dictionary) -> void:
	if not _loading.is_empty():
		return
	if briefing == null:
		_build_briefing()
	_briefing_level = level
	var camo := LevelCatalog.suggested_camo(level)
	var camo_name: String = GearCatalog.CAMOS[camo]["name"]
	(briefing.find_child("BriefingTitle", true, false) as Label).text = "Préparation — %s" % level["title"]
	_briefing_camo.text = "Camouflage conseillé pour cette carte : %s" % camo_name
	for child in _briefing_preview.get_children():
		child.queue_free()
	_briefing_preview.add_child(preview_of(level, BRIEFING_PREVIEW_SIZE))
	for child in _briefing_objectives.get_children():
		if child.name != "ObjectivesTitle":
			child.queue_free()
	for objective in LevelCatalog.objectives_of(level):
		var line := Label.new()
		line.text = "•  " + String(objective["text"])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_briefing_objectives.add_child(line)
	_suggest_all.text = "Toute l'équipe en %s" % camo_name
	_refresh_briefing()
	briefing.visible = true
	(briefing.find_child("Launch", true, false) as Button).grab_focus()


## Lance la mission préparée (l'équipe est sauvegardée).
func launch_mission() -> void:
	if _briefing_level.is_empty():
		return
	OperatorRoster.current().save()
	briefing.visible = false
	_start(_briefing_level)


func close_briefing() -> void:
	if briefing:
		briefing.visible = false


## Donne le camouflage conseillé à l'opérateur `index`, ou à toute l'équipe
## (-1).
func apply_suggested_camo(index: int = -1) -> void:
	var camo := LevelCatalog.suggested_camo(_briefing_level)
	var roster := OperatorRoster.current()
	for i in roster.operators.size():
		if index < 0 or index == i:
			roster.operators[i].set_camo(camo)
	roster.save()
	_refresh_briefing()


func _unhandled_input(event: InputEvent) -> void:
	if briefing and briefing.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_briefing()


func _build_briefing() -> void:
	briefing = Control.new()
	briefing.name = "Briefing"
	briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(briefing)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	briefing.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.1, 0.98)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.name = "BriefingTitle"
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)
	# Aperçu de la carte et objectifs.
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override(&"separation", 18)
	column.add_child(overview)
	_briefing_preview = CenterContainer.new()
	_briefing_preview.name = "BriefingPreview"
	overview.add_child(_briefing_preview)
	_briefing_objectives = VBoxContainer.new()
	_briefing_objectives.name = "Objectives"
	_briefing_objectives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing_objectives.add_theme_constant_override(&"separation", 6)
	overview.add_child(_briefing_objectives)
	var objectives_title := Label.new()
	objectives_title.name = "ObjectivesTitle"
	objectives_title.text = "OBJECTIFS"
	objectives_title.add_theme_font_size_override(&"font_size", 16)
	objectives_title.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
	_briefing_objectives.add_child(objectives_title)
	var camo_row := HBoxContainer.new()
	_briefing_camo = Label.new()
	_briefing_camo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camo_row.add_child(_briefing_camo)
	_suggest_all = Button.new()
	_suggest_all.name = "SuggestAll"
	_suggest_all.pressed.connect(apply_suggested_camo.bind(-1))
	camo_row.add_child(_suggest_all)
	column.add_child(camo_row)
	_briefing_rows = VBoxContainer.new()
	_briefing_rows.add_theme_constant_override(&"separation", 8)
	column.add_child(_briefing_rows)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override(&"separation", 10)
	var cancel := Button.new()
	cancel.name = "CancelBriefing"
	cancel.text = "Annuler"
	cancel.pressed.connect(close_briefing)
	buttons.add_child(cancel)
	var launch := Button.new()
	launch.name = "Launch"
	launch.text = "Lancer la mission"
	launch.pressed.connect(launch_mission)
	buttons.add_child(launch)
	column.add_child(buttons)


## Une ligne par opérateur : indicatif, tenue et charge, tenues enregistrées,
## camouflage conseillé.
func _refresh_briefing() -> void:
	for child in _briefing_rows.get_children():
		_briefing_rows.remove_child(child)
		child.queue_free()
	var roster := OperatorRoster.current()
	var camo := LevelCatalog.suggested_camo(_briefing_level)
	for i in roster.operators.size():
		var operator := roster.operators[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var label := Label.new()
		label.name = "Summary%d" % (i + 1)
		var weight := GearCatalog.load_of(operator)
		label.text = "%d  %s — %s, %s, %.1f kg" % [i + 1, operator.callsign,
				"uni" if operator.camo.is_empty() else GearCatalog.CAMOS[operator.camo]["name"],
				GearCatalog.PRIMARY[operator.primary]["short"], weight]
		if operator.camo != camo:
			label.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.4))
			label.tooltip_text = "Camouflage différent de celui conseillé."
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var outfits := OptionButton.new()
		outfits.name = "Outfit%d" % (i + 1)
		outfits.custom_minimum_size = Vector2(200, 0)
		outfits.add_item("Tenue actuelle")
		for entry in operator.saved_outfits:
			outfits.add_item(entry["name"])
		outfits.disabled = operator.saved_outfits.is_empty()
		outfits.tooltip_text = "Tenues enregistrées dans l'écran « Opérateurs »."
		outfits.item_selected.connect(func(item: int) -> void:
			if item > 0:
				operator.wear_outfit(operator.saved_outfits[item - 1]["outfit"])
				roster.save()
				_refresh_briefing())
		row.add_child(outfits)
		var edit := Button.new()
		edit.name = "Edit%d" % (i + 1)
		edit.text = "Modifier la tenue…"
		edit.tooltip_text = "Tenue, accessoires, armement et équipement de %s." % operator.callsign
		edit.pressed.connect(open_operator_editor.bind(i))
		row.add_child(edit)
		var suggest := Button.new()
		suggest.name = "Camo%d" % (i + 1)
		suggest.text = "Camouflage conseillé"
		suggest.disabled = operator.camo == camo
		suggest.pressed.connect(apply_suggested_camo.bind(i))
		row.add_child(suggest)
		_briefing_rows.add_child(row)


## Ouvre l'écran « Opérateurs » par-dessus la préparation, sur l'opérateur
## `index` ; à sa fermeture, la préparation reflète les changements.
func open_operator_editor(index: int) -> void:
	if operator_editor:
		return
	operator_editor = (load(OperatorScreen.SCENE) as PackedScene).instantiate() as OperatorScreen
	operator_editor.embedded = true
	operator_editor.start_index = index
	operator_editor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(operator_editor)
	operator_editor.closed.connect(func() -> void:
		operator_editor = null
		_refresh_briefing()
		(briefing.find_child("Launch", true, false) as Button).grab_focus())


func _start(level: Dictionary) -> void:
	if not _loading.is_empty():
		return
	_loading = level["scene"]
	if level.get("extra", false):
		UfoMapLevel.requested_map = level["map"]
	Settings.set_last_level(LevelCatalog.key_of(level))
	Sfx.play_ui(&"order")
	_status.text = "Chargement de « %s »…" % level["title"]
	for button in _levels.find_children("*", "Button", true, false):
		(button as Button).disabled = true
	ResourceLoader.load_threaded_request(_loading)


func _process(_delta: float) -> void:
	if _loading.is_empty():
		return
	var progress := []
	match ResourceLoader.load_threaded_get_status(_loading, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_status.text = "Chargement… %d %%" % int(progress[0] * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(_loading) as PackedScene
			_loading = ""
			get_tree().change_scene_to_packed(scene)
		_:
			_status.text = "Échec du chargement de %s" % _loading
			_loading = ""
			for button in _levels.find_children("*", "Button", true, false):
				(button as Button).disabled = not (button as Button).tooltip_text.is_empty()
