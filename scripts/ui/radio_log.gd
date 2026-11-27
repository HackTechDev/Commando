class_name RadioLog
extends VBoxContainer
## Messages radio de la mission (`EventBus.radio_message`) : aube qui
## approche, relève de la garde, poste qui ne répond plus. En haut au
## centre, sous le bandeau des renforts ; chaque ligne s'efface après
## `SHOW_TIME` s, les plus anciennes d'abord (`MAX_LINES` au plus).

const SHOW_TIME := 6.0
const FADE_TIME := 1.0
const MAX_LINES := 3
const COLOR := Color(0.75, 0.95, 0.7)


func _ready() -> void:
	name = "RadioLog"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 96.0
	alignment = BoxContainer.ALIGNMENT_BEGIN
	EventBus.radio_message.connect(add_line)


## Ajoute `text` (préfixé « Radio : ») et joue le grésillement.
func add_line(text: String) -> void:
	var label := Label.new()
	label.text = "Radio : %s" % text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", 17)
	label.add_theme_color_override(&"font_color", COLOR)
	label.add_theme_constant_override(&"outline_size", 6)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	label.set_meta(&"left", SHOW_TIME)
	add_child(label)
	while get_child_count() > MAX_LINES:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	Sfx.play_ui(&"radio")


## Textes affichés (tests).
func lines() -> Array[String]:
	var texts: Array[String] = []
	for child in get_children():
		texts.append((child as Label).text)
	return texts


func _process(delta: float) -> void:
	for child in get_children():
		var label := child as Label
		var left: float = label.get_meta(&"left") - delta
		label.set_meta(&"left", left)
		label.modulate.a = clampf(left / FADE_TIME, 0.0, 1.0)
		if left <= 0.0:
			label.queue_free()
