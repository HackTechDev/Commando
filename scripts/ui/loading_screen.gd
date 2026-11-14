class_name LoadingScreen
extends CanvasLayer
## Écran de chargement affiché par-dessus le niveau pendant que la navigation
## se génère en arrière-plan (le jeu est en pause, cet écran seul s'anime).

## Intervalle entre deux étapes de l'animation des points, en secondes.
const DOT_INTERVAL := 0.35

var _status: Label
var _stage: String = "Préparation"
var _dots: int = 0
var _elapsed: float = 0.0


func _init(title: String = "") -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color(0.11, 0.12, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bloque les clics destinés au niveau et au HUD.
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	center.add_child(column)
	var heading := Label.new()
	heading.name = "Title"
	heading.text = title if not title.is_empty() else "Chargement"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override(&"font_size", 32)
	heading.add_theme_color_override(&"font_color", Color(0.86, 0.9, 0.82))
	column.add_child(heading)
	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override(&"font_color", Color(0.7, 0.74, 0.7))
	column.add_child(_status)
	_refresh()


## Étape affichée sous le titre (sans les points animés).
func set_status(stage: String) -> void:
	if stage.is_empty() or stage == _stage:
		return
	_stage = stage
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DOT_INTERVAL:
		_elapsed = 0.0
		_dots = (_dots + 1) % 4
		_refresh()


func _refresh() -> void:
	# Points de largeur fixe (espaces insécables) : le texte ne bouge pas.
	_status.text = _stage + ".".repeat(_dots) + " ".repeat(3 - _dots)
