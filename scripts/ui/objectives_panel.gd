class_name ObjectivesPanel
extends PanelContainer
## Journal des objectifs (touche O) : chaque objectif de la mission et son
## état (en cours, rempli, manqué). Affiché quelques secondes au début de la
## mission, puis à la demande.

## Durée d'affichage au début de la mission.
const INTRO_TIME := 6.0
const COLORS: Dictionary = {
	Objectives.Status.PENDING: Color(0.92, 0.92, 0.88),
	Objectives.Status.DONE: Color(0.45, 0.9, 0.5),
	Objectives.Status.FAILED: Color(1.0, 0.4, 0.35),
}
const MARKS: Dictionary = {
	Objectives.Status.PENDING: "•",
	Objectives.Status.DONE: "✓",
	Objectives.Status.FAILED: "✗",
}

var objectives: Objectives
var _lines: VBoxContainer
var _intro_left: float = INTRO_TIME


func setup(source: Objectives) -> void:
	objectives = source
	objectives.changed.connect(refresh)
	refresh()


func _ready() -> void:
	name = "ObjectivesPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.08, 0.82)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	var title := Label.new()
	title.text = "OBJECTIFS  [%s]" % KeyNames.label(&"toggle_objectives")
	title.add_theme_font_size_override(&"font_size", 13)
	title.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
	column.add_child(title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override(&"separation", 2)
	column.add_child(_lines)


func _process(delta: float) -> void:
	if _intro_left > 0.0:
		_intro_left -= delta
		if _intro_left <= 0.0:
			visible = false


## Ouvre ou ferme le journal.
func toggle() -> void:
	_intro_left = 0.0
	visible = not visible


func refresh() -> void:
	if _lines == null or objectives == null:
		return
	for child in _lines.get_children():
		child.queue_free()
	for entry in objectives.entries:
		var line := Label.new()
		var status: Objectives.Status = entry["status"]
		line.text = "%s  %s" % [MARKS[status], entry["text"]]
		line.add_theme_font_size_override(&"font_size", 14)
		line.add_theme_color_override(&"font_color", COLORS[status])
		_lines.add_child(line)
	# Un objectif qui change d'état s'affiche un moment.
	if not visible:
		visible = true
		_intro_left = INTRO_TIME / 2.0


## Textes affichés (tests).
func lines() -> Array[String]:
	var result: Array[String] = []
	for entry in objectives.entries:
		result.append("%s  %s" % [MARKS[entry["status"]], entry["text"]])
	return result
