class_name MainMenu
extends Control
## Menu de démarrage : choix de la carte (`LevelCatalog`), préparation de la
## mission (tenues et camouflage conseillé), chargement en arrière-plan puis
## lancement du niveau ; accès à l'écran « Opérateurs ».

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


func _ready() -> void:
	# Revenir au menu remet l'alerte à zéro (elle ne se recalcule qu'en jeu).
	GameState.alert_level = GameState.AlertLevel.CALM
	_status.text = ""
	quit_dialog = ConfirmDialog.for_quit(self)
	add_child(quit_dialog)
	_quit.pressed.connect(quit_dialog.ask)
	_operators.pressed.connect(open_operators)
	var first: Button = null
	for level in LevelCatalog.LEVELS:
		var button := _add_level(level)
		if first == null and not button.disabled:
			first = button
	if first:
		first.grab_focus()


func _add_level(level: Dictionary) -> Button:
	var card := PanelContainer.new()
	_levels.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var title := Label.new()
	title.text = level["title"]
	title.add_theme_font_size_override(&"font_size", 22)
	texts.add_child(title)
	var description := Label.new()
	description.text = level["description"]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(1, 1, 1, 0.75)
	texts.add_child(description)
	var button := Button.new()
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
	panel.custom_minimum_size = Vector2(820, 0)
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
		var suggest := Button.new()
		suggest.name = "Camo%d" % (i + 1)
		suggest.text = "Camouflage conseillé"
		suggest.disabled = operator.camo == camo
		suggest.pressed.connect(apply_suggested_camo.bind(i))
		row.add_child(suggest)
		_briefing_rows.add_child(row)


func _start(level: Dictionary) -> void:
	if not _loading.is_empty():
		return
	_loading = level["scene"]
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
