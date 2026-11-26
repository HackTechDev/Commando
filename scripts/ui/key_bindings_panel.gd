class_name KeyBindingsPanel
extends Control
## Écran « Touches du clavier » (options du menu pause, page Configuration
## du menu de démarrage) : une ligne par action réglable (`KeyBindings`),
## avec sa touche. Clic sur la touche, puis appui sur la nouvelle : elle est
## enregistrée aussitôt ; une touche déjà prise est échangée avec l'autre
## action. Échap annule l'attente d'une touche, ou ferme l'écran.

signal closed

const KEY_COLOR := Color(1.0, 0.85, 0.4)
const CHANGED_COLOR := Color(0.55, 0.85, 1.0)

## Action dont on attend la nouvelle touche (vide sinon).
var waiting: StringName = &""
var _was_paused: bool = false
var _buttons: Dictionary = {}
var _status: Label


func _ready() -> void:
	name = "KeyBindingsPanel"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	waiting = &""
	_status.text = "Clic sur une touche, puis appuyez sur la nouvelle."
	_refresh()
	visible = true
	(find_child("Close", true, false) as Button).grab_focus()


func close() -> void:
	if not visible:
		return
	waiting = &""
	visible = false
	get_tree().paused = _was_paused
	closed.emit()


func is_open() -> bool:
	return visible


## Attend la nouvelle touche de `action`.
func listen(action: StringName) -> void:
	waiting = action
	_refresh()
	_status.text = "« %s » : appuyez sur la nouvelle touche (Échap : annuler)." % KeyBindings.label_of(action)


## Donne la touche `code` à l'action en attente (appelé par `_input`).
func assign(code: Key) -> void:
	if waiting.is_empty():
		return
	var action := waiting
	waiting = &""
	var result := KeyBindings.rebind(Settings, action, code)
	if result["ok"]:
		var text := "« %s » : %s." % [KeyBindings.label_of(action), KeyNames.label(action)]
		if not String(result["message"]).is_empty():
			text += " " + String(result["message"])
		_status.text = text
		Sfx.play_ui(&"order")
	else:
		_status.text = result["message"]
		Sfx.play_ui(&"denied")
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not waiting.is_empty():
		get_viewport().set_input_as_handled()
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			waiting = &""
			_status.text = "Annulé."
			_refresh()
			return
		# Un modificateur seul : on attend la vraie touche.
		if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		assign(code)
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Libellés des touches (et de celle qu'on attend).
func _refresh() -> void:
	for action: StringName in _buttons:
		var button: Button = _buttons[action]
		if action == waiting:
			button.text = "…"
			button.add_theme_color_override(&"font_color", Color.WHITE)
			continue
		button.text = KeyNames.label(action)
		var changed := KeyBindings.key_of(action) != KeyBindings.default_of(action)
		button.add_theme_color_override(&"font_color", CHANGED_COLOR if changed else KEY_COLOR)
		button.tooltip_text = "Modifiée (d'origine : %s)" % KeyNames.of_physical(KeyBindings.default_of(action)) if changed else ""


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.97)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Touches du clavier"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 26)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	# Deux colonnes de rubriques.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 30)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	var boxes: Array[VBoxContainer] = []
	for i in 2:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(box)
		boxes.append(box)
	for index in KeyBindings.GROUPS.size():
		var group: Array = KeyBindings.GROUPS[index]
		var box := boxes[0 if index < 2 else 1]
		var heading := Label.new()
		heading.text = group[0]
		heading.add_theme_font_size_override(&"font_size", 18)
		heading.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
		box.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 12)
		grid.add_theme_constant_override(&"v_separation", 3)
		box.add_child(grid)
		for entry: Array in group[1]:
			var action: StringName = entry[0]
			if not InputMap.has_action(action):
				continue
			var label := Label.new()
			label.text = entry[1]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(label)
			var button := Button.new()
			button.name = String(action)
			button.custom_minimum_size = Vector2(110, 0)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(listen.bind(action))
			grid.add_child(button)
			_buttons[action] = button
	var note := Label.new()
	note.text = "Les touches suivent leur position sur le clavier. Maj, Ctrl et Échap sont réservées ; Maj donne les variantes (lampe, charge à retardement…)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	column.add_child(note)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(760, 0)
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	column.add_child(row)
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "Touches d'origine"
	reset.pressed.connect(func() -> void:
		waiting = &""
		KeyBindings.reset(Settings)
		_status.text = "Toutes les touches sont revenues à l'origine."
		_refresh())
	row.add_child(reset)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "Retour"
	close_button.pressed.connect(close)
	row.add_child(close_button)
