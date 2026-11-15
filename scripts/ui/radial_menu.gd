class_name RadialMenu
extends Control
## Menu circulaire : les options forment une couronne autour du point
## cliqué, la première en haut, les suivantes dans le sens horaire. Survol
## pour mettre en évidence, clic gauche pour choisir. Un clic droit ou du
## milieu, Échap, ou un clic hors de la couronne le ferment sans rien choisir.
##
## Une option : {"id": StringName, "label": String, "detail": String
## (facultatif, sous le nom), "enabled": bool (vrai par défaut)}.

signal chosen(id: StringName)
signal closed

## Rayons (pixels) de la couronne, écart entre deux secteurs (radians),
## distance des noms au bord de la couronne.
const OUTER := 70.0
const INNER := 28.0
const GAP := 0.06
const LABEL_MARGIN := 14.0
const ARC_POINTS := 24

@export var fill := Color(0.08, 0.1, 0.12, 0.85)
@export var hover_fill := Color(0.2, 0.55, 0.9, 0.95)
@export var disabled_fill := Color(0.18, 0.18, 0.18, 0.7)
@export var border := Color(0.6, 0.8, 1.0, 0.9)
@export var text_color := Color(0.95, 0.95, 0.95)
@export var disabled_text := Color(0.6, 0.6, 0.6)

## Titre au centre de la couronne.
var title: String = ""

var _options: Array[Dictionary] = []
var _center := Vector2.ZERO
var _hover: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Ouvre le menu centré sur `at` (coordonnées de l'écran) avec `options`.
func open(at: Vector2, options: Array[Dictionary], menu_title: String = "") -> void:
	_options = options
	_center = at
	title = menu_title
	_hover = _option_at(get_local_mouse_position())
	visible = true
	queue_redraw()


## Ferme le menu sans rien choisir.
func close() -> void:
	if not visible:
		return
	visible = false
	_hover = -1
	closed.emit()


func is_open() -> bool:
	return visible


## Choisit l'option `id` (si elle est active), puis ferme le menu. Renvoie
## vrai si elle a été choisie.
func choose(id: StringName) -> bool:
	for option in _options:
		if option["id"] == id and option.get("enabled", true):
			visible = false
			_hover = -1
			chosen.emit(id)
			return true
	return false


## Milieu du secteur de l'option `id` (coordonnées de l'écran), ou
## `Vector2.INF` si elle n'y est pas.
func option_position(id: StringName) -> Vector2:
	for i in _options.size():
		if _options[i]["id"] == id:
			return _center + _direction(i) * (INNER + OUTER) * 0.5
	return Vector2.INF


func _direction(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * index / maxf(_options.size(), 1)
	return Vector2(cos(angle), sin(angle))


## Option sous le point `point`, ou -1 (centre, ou hors de la couronne).
func _option_at(point: Vector2) -> int:
	var offset := point - _center
	var distance := offset.length()
	if _options.is_empty() or distance < INNER or distance > OUTER + LABEL_MARGIN * 2.0:
		return -1
	var sector := TAU / _options.size()
	var angle := fposmod(offset.angle() + PI / 2.0 + sector * 0.5, TAU)
	return int(angle / sector) % _options.size()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var hover := _option_at((event as InputEventMouseMotion).position)
		if hover != _hover:
			_hover = hover
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			var index := _option_at(button.position)
			if index < 0 or not choose(_options[index]["id"]):
				if index < 0:
					close()
				else:
					Sfx.play_ui(&"denied")
		elif button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			close()
	accept_event()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if _options.is_empty():
		return
	var font := get_theme_default_font()
	draw_circle(_center, OUTER + 4.0, Color(0.0, 0.0, 0.0, 0.35))
	var sector := TAU / _options.size()
	for i in _options.size():
		var option := _options[i]
		var enabled: bool = option.get("enabled", true)
		var middle := -PI / 2.0 + sector * i
		var half := sector * 0.5 - GAP if _options.size() > 1 else PI
		var points := PackedVector2Array()
		for k in ARC_POINTS + 1:
			var a := middle - half + 2.0 * half * k / ARC_POINTS
			points.append(_center + Vector2(cos(a), sin(a)) * OUTER)
		for k in ARC_POINTS + 1:
			var a := middle + half - 2.0 * half * k / ARC_POINTS
			points.append(_center + Vector2(cos(a), sin(a)) * INNER)
		var color := disabled_fill if not enabled else (hover_fill if i == _hover else fill)
		draw_colored_polygon(points, color)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, border if enabled else disabled_text, 1.5, true)
		# Nom (et précision) à l'extérieur de la couronne, aligné selon le côté.
		var direction := _direction(i)
		var anchor := _center + direction * (OUTER + LABEL_MARGIN)
		var lines: Array[String] = [option["label"]]
		if not String(option.get("detail", "")).is_empty():
			lines.append(option["detail"])
		var height := 18.0 * lines.size()
		var top := anchor.y - height * 0.5
		if direction.y < -0.5:
			top = anchor.y - height
		elif direction.y > 0.5:
			top = anchor.y
		for line_index in lines.size():
			var size := 16 if line_index == 0 else 13
			var width := font.get_string_size(lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var x := anchor.x - width * 0.5
			if direction.x > 0.5:
				x = anchor.x
			elif direction.x < -0.5:
				x = anchor.x - width
			var y := top + 18.0 * line_index + 14.0
			var tint := text_color if enabled else disabled_text
			if line_index > 0:
				tint = tint.darkened(0.2)
			draw_string_outline(font, Vector2(x, y), lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
			draw_string(font, Vector2(x, y), lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)
	if not title.is_empty():
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, _center + Vector2(-width * 0.5, 5.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, border)
