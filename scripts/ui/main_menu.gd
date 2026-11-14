class_name MainMenu
extends Control
## Menu de démarrage : choix de la carte (`LevelCatalog`), chargement en
## arrière-plan puis lancement du niveau.

@onready var _levels: VBoxContainer = %Levels
@onready var _status: Label = %Status
@onready var _quit: Button = %Quit

## Scène en cours de chargement, ou vide.
var _loading: String = ""


func _ready() -> void:
	# Revenir au menu remet l'alerte à zéro (elle ne se recalcule qu'en jeu).
	GameState.alert_level = GameState.AlertLevel.CALM
	_status.text = ""
	_quit.pressed.connect(func() -> void: get_tree().quit())
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
		button.pressed.connect(_start.bind(level))
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
