class_name TutorialPanel
extends PanelContainer
## Petite fenêtre d'astuce du didacticiel, à gauche de l'écran : titre,
## numéro d'étape, texte où les touches (`{action}`) sont remplacées par leur
## nom sur le clavier du joueur. Le jeu continue pendant qu'elle est
## affichée. × la ferme ; le bouton « ? » qui reste alors la rouvre.

const KEY_COLOR := Color(1.0, 0.85, 0.4)
const TITLE_COLOR := Color(0.55, 0.8, 1.0)
const DONE_COLOR := Color(0.45, 0.95, 0.5)
const WIDTH := 380.0
const GROUP := &"tutorial_panel"

var _title: Label
var _step: Label
var _body: RichTextLabel
var _reopen: Button
## Dernière astuce affichée : [titre, texte, étape].
var _last: Array = []


## Fenêtre du HUD de la scène en cours, créée à la première demande.
static func instance(tree: SceneTree) -> TutorialPanel:
	var existing := tree.get_first_node_in_group(GROUP) as TutorialPanel
	if existing:
		return existing
	var host := tree.current_scene.get_node_or_null(^"HUD/PlayerController") as Control
	if host == null:
		return null
	var panel := TutorialPanel.new()
	host.add_child(panel)
	return panel


## Remplace `{action}` par le nom de la touche de cette action, en couleur.
static func format(text: String) -> String:
	var result := ""
	var rest := text
	while true:
		var open := rest.find("{")
		var close := rest.find("}", open + 1)
		if open < 0 or close < 0:
			result += rest
			break
		var action := StringName(rest.substr(open + 1, close - open - 1))
		result += rest.substr(0, open)
		result += "[color=#%s][b]%s[/b][/color]" % [KEY_COLOR.to_html(false), KeyNames.label(action)]
		rest = rest.substr(close + 1)
	return result


func _ready() -> void:
	name = "TutorialPanel"
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.9)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	add_theme_stylebox_override(&"panel", style)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 8)
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override(&"font_size", 18)
	_title.add_theme_color_override(&"font_color", TITLE_COLOR)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_step = Label.new()
	_step.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	header.add_child(_step)
	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.flat = true
	close.tooltip_text = "Masquer l'astuce"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_tip)
	header.add_child(close)
	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(WIDTH - 28.0, 0.0)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_body)
	# À gauche, sous la minicarte.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_reopen = Button.new()
	_reopen.name = "TutorialReopen"
	_reopen.text = "?  Astuce"
	_reopen.tooltip_text = "Rouvrir la dernière astuce"
	_reopen.focus_mode = Control.FOCUS_NONE
	_reopen.pressed.connect(reopen)
	get_parent().add_child.call_deferred(_reopen)
	_reopen.visible = false
	visible = false


## Affiche l'astuce `title` / `text` ; `step` (ex. « 2 / 7 ») en haut à droite.
func show_tip(title: String, text: String, step: String = "") -> void:
	_last = [title, text, step]
	_title.text = title
	_step.text = step
	_body.text = format(text)
	visible = true
	_reopen.visible = false
	reset_size()
	_place()
	Sfx.play_ui(&"select")


## Affiche un exercice réussi, puis `text` (la suite).
func show_done(title: String, text: String) -> void:
	show_tip(title, "[color=#%s][b]✓ Exercice réussi.[/b][/color] %s" % [DONE_COLOR.to_html(false), text], _last[2] if _last.size() > 2 else "")


func hide_tip() -> void:
	visible = false
	_reopen.visible = not _last.is_empty()
	_place()


## Rouvre la dernière astuce masquée.
func reopen() -> void:
	if _last.is_empty():
		return
	visible = true
	_reopen.visible = false


## Texte affiché (sans balises), pour les tests.
func shown_text() -> String:
	return _body.get_parsed_text() if visible else ""


func shown_title() -> String:
	return _title.text if visible else ""


func _place() -> void:
	var height := get_combined_minimum_size().y
	position = Vector2(16.0, maxf(240.0, (get_parent_area_size().y - height) * 0.5))
	if _reopen and _reopen.is_inside_tree():
		_reopen.position = Vector2(16.0, position.y)
