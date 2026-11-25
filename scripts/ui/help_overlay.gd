class_name HelpOverlay
extends Control
## Page d'aide en cours de partie (touche H) : toutes les commandes, par
## rubrique, avec les touches lues dans l'InputMap (selon la disposition du
## clavier). Le jeu est en pause tant qu'elle est ouverte. H, Échap ou un clic
## la referment.

## Rubriques : titre, puis lignes [touches, description]. Une touche est le
## nom d'une action de l'InputMap (`&"…"`), ou un texte affiché tel quel.
const SECTIONS: Array = [
	["Sélection et déplacement", [
		[["Clic gauche", "rectangle"], "Sélectionner (Maj : ajouter)"],
		[["1 à 6"], "Sélectionner un opérateur (rangée des chiffres ; Ctrl : centrer la caméra sur lui)"],
		[["Clic droit"], "Marcher (double clic : courir)"],
		[["Clic droit en route"], "S'arrêter (le clic suivant : nouvelle destination)"],
		[["Clic droit sur une caisse"], "Grimper dessus"],
		[["Clic droit sur une porte"], "L'ouvrir, la fermer ou la crocheter"],
		[["Clic droit sur le convertible"], "Monter à bord (soute) ; en vol, porte ouverte : hélitreuillage"],
		[["Clic milieu sur un opérateur à bord"], "Porte, canon, ravitaillement, monter / atterrir, altitude, déplacer, élinguer, rappel, piloter"],
		[["Clic milieu sur un opérateur au sol"], "Radio : renvoyer l'appareil, diversion, appeler l'extraction"],
		[["Clic droit sur le Sabre"], "Monter à bord (cinq places)"],
		[["Clic droit sur l'hexapode"], "Monter à bord (cinq places, dans la caisse)"],
		[["Clic milieu sur l'hexapode, passager sélectionné"], "Descendre, commandes, tourelle et feu de la gatling"],
		[["Clic droit sur une barrière"], "La lever ou la baisser (à pied ; en Sabre, on la force)"],
		[["Clic droit sur une mine balisée"], "La désamorcer (à pied ; un éclaireur devant le véhicule les repère)"],
		[["Clic milieu sur le Sabre, opérateur à pied"], "Menu du véhicule : abri, ralenti, ravitaillement, plateau, réparer"],
		[["Clic droit au sol, passager du Sabre"], "Rouler jusque-là (il faut quelqu'un au volant ; Maj : point de passage)"],
		[["Clic milieu sur un passager du Sabre"], "Descendre, débarquer à l'arrivée, volant, tourelle, armes, phares, moteur"],
		[["Clic droit sur le convertible, passager du Sabre"], "Garer le Sabre dans la soute (rampe abaissée)"],
		[["Clic droit sur un toit"], "Y monter par l'échelle, enjamber les murets"],
		[[&"posture_crouch", &"posture_prone"], "Accroupi / rampé"],
		[[&"dive"], "Roulade vers le curseur"],
		[[&"stop"], "Annuler l'ordre en cours"],
	]],
	["Combat", [
		[["Clic droit sur un ennemi"], "Tirer, de sa place (hors de portée : rapprochez l'opérateur)"],
		[[&"action_knife"], "Couteau, puis clic gauche sur l'ennemi"],
		[[&"action_knockout"], "Assommer, puis clic gauche sur l'ennemi"],
		[["Clic milieu sur un ennemi"], "Corps à corps au choix (désarmer, otage…)"],
		[[&"action_throw"], "Lancer : couteau (clic sur un ennemi), caillou (clic au sol)"],
		[[&"parry"], "Parer : au moment où l'ennemi frappe"],
		[[&"action_grenade"], "Grenade, puis clic au sol"],
		[[&"action_smoke"], "Fumigène, puis clic au sol"],
		[[[&"action_variant", &"action_grenade"]], "Grenade assourdissante, puis clic au sol"],
		[[&"action_launcher"], "Lance-grenades M320 (40 mm), puis clic au sol"],
		[[[&"action_variant", &"action_smoke"]], "Obus fumigène de 40 mm (M320), puis clic au sol"],
		[[[&"action_variant", &"action_launcher"]], "Obus lacrymogène de 40 mm (M320), puis clic au sol"],
		[[&"action_fire_at"], "Tir libre, puis clic sur un mur ou un objet"],
		[[&"action_carry"], "Porter un corps (clic dessus) / le déposer"],
		[[&"reload"], "Recharger"],
		[[&"switch_weapon"], "Arme secondaire / principale"],
		[[[&"action_variant", &"switch_weapon"]], "Lampe de l'arme de poing (HK45)"],
		[[&"action_sling"], "Arme à la bretelle"],
		[[&"action_shield"], "Lever le bouclier"],
	]],
	["Équipement et objets", [
		[[&"action_plant"], "Poser une charge"],
		[[[&"action_variant", &"action_plant"]], "Poser une charge à retardement (10 s)"],
		[[&"action_detonate"], "Mise à feu des charges"],
		[[&"action_medkit"], "Soigner"],
		[[&"action_crate"], "Pousser / tirer une caisse"],
		[[[&"action_variant", &"action_crate"]], "Faire pivoter la caisse tenue (45°)"],
		[[&"action_grapple"], "Grappin, puis clic sur un point en hauteur"],
		[["Clic milieu sur le VIP"], "Ordres au VIP"],
	]],
	["Tactique", [
		[[&"tactical_pause"], "Pause tactique (les ordres restent possibles)"],
		[[&"plan_orders"], "Ordres simultanés : préparer"],
		[[&"execute_orders"], "Ordres simultanés : exécuter"],
		[[&"ui_cancel"], "Menu pause (reprendre, recommencer, options…)"],
		[[&"toggle_objectives"], "Journal des objectifs"],
		[[&"toggle_minimap"], "Minicarte (clic : centrer la caméra)"],
		[[&"toggle_nvg"], "Abaisser ou relever les jumelles : vue verte (opérateurs avec JVN)"],
	]],
	["Caméra", [
		[[&"camera_forward", &"camera_left", &"camera_back", &"camera_right"], "Déplacer (aussi : flèches, bord d'écran)"],
		[["Clic milieu", "glisser"], "Déplacer"],
		[["Molette"], "Zoom"],
		[[&"camera_rotate_left", &"camera_rotate_right"], "Rotation (maintenir)"],
		[[&"camera_focus"], "Centrer sur la sélection"],
		[[&"view_level_down", &"view_level_up"], "Étage affiché : descendre / monter"],
		[[&"toggle_help"], "Afficher / masquer cette aide"],
	]],
]

const KEY_COLOR := Color(1.0, 0.85, 0.4)

signal closed

var _was_paused: bool = false


func _ready() -> void:
	name = "HelpOverlay"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


## Ouvre ou ferme la page.
func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	closed.emit()


func is_open() -> bool:
	return visible


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_help"):
		close()
		get_viewport().set_input_as_handled()


## Touches d'une ligne : actions (`StringName`) ou textes séparés par « / » ;
## un tableau d'actions est une combinaison (« Maj + K »).
static func _keys_text(keys: Array) -> String:
	var parts: PackedStringArray = []
	for key: Variant in keys:
		if key is Array:
			var combo: PackedStringArray = []
			for action: StringName in key:
				combo.append(KeyNames.label(action))
			parts.append(" + ".join(combo))
		else:
			parts.append(KeyNames.label(key) if key is StringName else String(key))
	return " / ".join(parts)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.95)
	style.border_color = Color(0.35, 0.55, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 14)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "Aide — commandes"
	title.add_theme_font_size_override(&"font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 36)
	layout.add_child(columns)
	# Deux colonnes de rubriques.
	var column_boxes: Array[VBoxContainer] = []
	for i in 2:
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 14)
		columns.add_child(box)
		column_boxes.append(box)
	for index in SECTIONS.size():
		var section: Array = SECTIONS[index]
		var box := column_boxes[0 if index < 2 else 1]
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_size_override(&"font_size", 18)
		heading.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
		box.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 18)
		grid.add_theme_constant_override(&"v_separation", 4)
		box.add_child(grid)
		for line: Array in section[1]:
			var keys := Label.new()
			keys.text = _keys_text(line[0])
			keys.add_theme_color_override(&"font_color", KEY_COLOR)
			grid.add_child(keys)
			var text := Label.new()
			text.text = line[1]
			grid.add_child(text)
	var footer := Label.new()
	footer.text = "%s, Échap ou clic : fermer — le jeu est en pause." % KeyNames.label(&"toggle_help")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.7))
	layout.add_child(footer)


## Texte des touches affichées pour la ligne de description `text` (tests).
func keys_for(text: String) -> String:
	for section: Array in SECTIONS:
		for line: Array in section[1]:
			if line[1] == text:
				return _keys_text(line[0])
	return ""
