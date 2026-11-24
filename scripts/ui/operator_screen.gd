class_name OperatorScreen
extends Control
## Écran « Opérateurs » (depuis le menu principal) : personnalisation des
## trois opérateurs de l'équipe (`OperatorRoster`), avec aperçu 3D qui tourne
## sur un socle, dans un décor assorti au camouflage. Chaque changement est
## sauvegardé aussitôt, peut être annulé (Ctrl+Z) et s'applique en mission.
##
## Raccourcis : 1 à 3 choisissent l'opérateur, Tab / Maj+Tab changent
## d'onglet, Ctrl+Z annule, Échap revient au menu.

const SCENE := "res://scenes/ui/operator_screen.tscn"
## Rotation automatique du socle (rad/s) et pause après un glissé (s).
const TURN_SPEED := 0.45
const TURN_PAUSE := 2.5
## Rotation par pixel glissé.
const DRAG_TURN := 0.012
## Distance de la caméra au modèle (m) : bornes et pas de la molette.
const ZOOM_MIN := 1.3
const ZOOM_MAX := 4.5
const ZOOM_STEP := 0.25
## Cadrage sur la partie modifiée : durée (s) avant de revenir à la vue
## d'ensemble, vitesse de la caméra, et rotation du socle qui montre l'arme
## (trois quarts avant droit).
const FOCUS_HOLD := 4.0
const CAMERA_SMOOTH := 5.0
const WEAPON_YAW := PI + 0.85
## L'escalade se montre de profil (la caisse à droite de l'image).
const CLIMB_YAW := PI / 2.0 + 0.35
## Cadrages : distance de la caméra (m) et hauteur visée par posture
## (debout, accroupi, couché).
const FOCUS: Dictionary = {
	&"head": {"distance": 1.1, "height": [1.6, 1.12, 0.42]},
	&"torso": {"distance": 1.7, "height": [1.2, 0.8, 0.35]},
	&"weapon": {"distance": 2.1, "height": [1.2, 0.82, 0.35]},
	&"legs": {"distance": 1.9, "height": [0.55, 0.4, 0.25]},
}
## Animations de l'aperçu : nom affiché.
const ANIMATIONS: Dictionary = {
	&"idle": "Repos",
	&"walk": "Marche",
	&"run": "Course",
	&"crouch": "Accroupi",
	&"prone": "Couché",
	&"aim": "Visée",
	&"reload": "Rechargement",
	&"throw": "Lancer de couteau",
	&"stab": "Coup de couteau",
	&"climb": "Escalade",
}
## Boucles des animations de geste : durée du geste et du cycle (s).
const GESTURES: Dictionary = {
	&"reload": [2.0, 2.8],
	&"throw": [0.8, 1.8],
	&"stab": [0.6, 1.5],
	&"climb": [1.4, 2.8],
}
## Caisse de l'animation d'escalade : hauteur, profondeur et avancée de
## l'opérateur jusqu'au-dessus.
const CRATE_HEIGHT := 1.0
const CRATE_DEPTH := 1.0
const CLIMB_ADVANCE := 0.9
## Annulations mémorisées au plus.
const HISTORY_SIZE := 50
## Accessoires : partie du corps cadrée quand on les change.
const ACCESSORY_PARTS: Dictionary = {
	&"balaclava": &"head", &"nvg": &"head", &"headset": &"head", &"vest": &"torso",
	&"backpack": &"torso", &"radio": &"torso", &"knee_pads": &"legs", &"sunglasses": &"head",
}
## Caractéristiques comparées des armes principales : nom affiché.
const COMPARED: Array[String] = ["Portée", "Dégâts", "Cadence", "Chargeur", "Discrétion"]
## Rayon de bruit (m) d'une arme considérée comme sans aucune discrétion.
const LOUDEST := 24.0

## Opérateur modifié (0 à 2).
var current: int = 0
## Ouvert par-dessus la préparation de mission (et non comme une scène) :
## « Retour » referme l'écran (signal `closed`) au lieu de revenir au menu.
var embedded: bool = false
## Opérateur affiché à l'ouverture.
var start_index: int = 0

signal closed
var roster: OperatorRoster
## Modèle de l'aperçu.
var model: SoldierModel
var zoom: float = 3.0
var animation: StringName = &"idle"
## Partie cadrée (`FOCUS`, ou `full` : vue d'ensemble).
var focus: StringName = &"full"
## Décor affiché (camouflage, vide : uni).
var backdrop: StringName = &"none"
## Confirmation avant de remettre l'opérateur par défaut.
var reset_dialog: ConfirmDialog
## Modèles des portraits des sélecteurs (visage).
var portraits: Array[SoldierModel] = []

var _selectors: Array[Button] = []
var _tabs: TabContainer
var _turntable: Node3D
var _camera: Camera3D
var _turn_pause: float = 0.0
var _dragging: bool = false
var _focus_left: float = 0.0
var _camera_height: float = 1.0
var _camera_distance: float = 3.0
var _anim_time: float = 0.0
var _status: Label
var _undo: Button
var _animation_buttons: Dictionary = {}
## Décor : sol, ciel, soleil, éléments, caisse d'escalade.
var _ground_material: StandardMaterial3D
var _environment: Environment
var _sun: DirectionalLight3D
var _props: Node3D
var _crate: MeshInstance3D
## Contrôles des onglets, rafraîchis quand on change d'opérateur.
var _name_edit: LineEdit
var _callsign_edit: LineEdit
var _option_buttons: Dictionary = {}
var _checks: Dictionary = {}
var _spins: Dictionary = {}
var _swatches: Dictionary = {}
## Motifs par vêtement : {clé du profil: {camouflage: bouton}}.
var _part_camo_buttons: Dictionary = {}
var _camo_buttons: Dictionary = {}
## Boutons de tenue (`GearCatalog.CLOTHING`) et description de la tenue choisie.
var _clothing_buttons: Dictionary = {}
var _clothing_info: Label
var _weapon_info: Label
var _secondary_info: Label
var _specialty_info: Label
var _compare_bars: Array = []
var _compare_heads: Array[Label] = []
var _load_bar: ProgressBar
var _load_fill: StyleBoxFlat
var _load_label: Label
var _outfit_name: LineEdit
var _outfit_list: VBoxContainer
var _refreshing: bool = false
## Annulation : états successifs de l'équipe (profils en JSON), l'état
## courant, et la clé du dernier changement (les frappes au clavier d'un même
## champ ne font qu'une annulation).
var _history: Array[Array] = []
var _snapshot: Array = []
var _merge_key: String = ""


func _ready() -> void:
	roster = OperatorRoster.current()
	_snapshot = _capture()
	var background := ColorRect.new()
	background.color = Color(0.11, 0.13, 0.12)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	column.add_child(_build_header())
	column.add_child(_build_selectors())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 16)
	column.add_child(body)
	body.add_child(_build_preview())
	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.custom_minimum_size = Vector2(500, 0)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_add_tab("Identité", _build_identity())
	_add_tab("Tenue", _build_outfit())
	_add_tab("Accessoires", _build_accessories())
	_add_tab("Armement", _build_armament())
	_add_tab("Tenues enregistrées", _build_saved_outfits())
	column.add_child(_build_footer())
	reset_dialog = ConfirmDialog.new("Réinitialiser", "", "Réinitialiser", reset_current)
	add_child(reset_dialog)
	select(start_index)
	_refresh_portraits()
	if embedded:
		(find_child("Back", true, false) as Button).text = "Retour à la préparation"


## Modifie l'opérateur `index` (0 à 2).
func select(index: int) -> void:
	current = clampi(index, 0, roster.operators.size() - 1)
	for i in _selectors.size():
		_selectors[i].set_pressed_no_signal(i == current)
	_merge_key = ""
	_refresh_controls()
	_update_preview()


func profile() -> OperatorProfile:
	return roster.operators[current]


## Remet l'opérateur modifié à son profil par défaut (et sauvegarde).
func reset_current() -> void:
	roster.reset(current)
	_refresh_controls()
	_changed()


## Annule le dernier changement. Renvoie faux s'il n'y a rien à annuler.
func undo() -> bool:
	if _history.is_empty():
		return false
	_restore(_history.pop_back())
	_snapshot = _capture()
	_merge_key = ""
	_after_restore()
	_set_status("Changement annulé")
	return true


func can_undo() -> bool:
	return not _history.is_empty()


## Donne la tenue (camouflage, couleurs, couvre-chef et accessoires) de
## l'opérateur courant aux deux autres ; leur armement ne change pas.
func copy_look_to_team() -> void:
	for i in roster.operators.size():
		if i != current:
			roster.operators[i].copy_look_from(profile())
	_changed(true, "", &"full")
	_refresh_portraits()


## Revêt la tenue conseillée pour la spécialité de l'opérateur courant.
func wear_specialty_outfit() -> void:
	profile().wear_specialty_outfit()
	_refresh_controls()
	_changed(true, "", &"full")


## Enregistre la tenue portée sous `title`. Renvoie faux si la liste est pleine.
func save_outfit(title: String) -> bool:
	if not profile().save_outfit(title):
		_set_status("%d tenues au plus : supprimez-en une." % OperatorProfile.MAX_SAVED_OUTFITS)
		return false
	_refresh_controls()
	_changed(false)
	return true


## Revêt la tenue enregistrée numéro `index`.
func wear_outfit(index: int) -> void:
	profile().wear_outfit(profile().saved_outfits[index]["outfit"])
	_refresh_controls()
	_changed(true, "", &"full")


func delete_outfit(index: int) -> void:
	profile().saved_outfits.remove_at(index)
	_refresh_controls()
	_changed(false)


## Lance l'animation `id` de l'aperçu (`ANIMATIONS`).
func play(id: StringName) -> void:
	animation = id
	_anim_time = 0.0
	for key: StringName in _animation_buttons:
		(_animation_buttons[key] as Button).set_pressed_no_signal(key == id)
	_apply_animation()


## Cadre la partie `part` (`FOCUS`) quelques secondes, ou la vue d'ensemble
## (`full`).
func focus_on(part: StringName) -> void:
	focus = part if FOCUS.has(part) else &"full"
	_focus_left = FOCUS_HOLD if FOCUS.has(part) else 0.0
	if focus != &"full":
		_turn_pause = FOCUS_HOLD


func back_to_menu() -> void:
	if embedded:
		closed.emit()
		queue_free()
		return
	get_tree().change_scene_to_file(LevelCatalog.MENU_SCENE)


func _process(delta: float) -> void:
	if _focus_left > 0.0:
		_focus_left -= delta
		if _focus_left <= 0.0:
			focus = &"full"
	var hold := focus != &"full" or (animation == &"climb" and _turn_pause <= 0.0)
	if hold and not _dragging:
		# Face à la caméra, trois quarts droit pour l'arme, de profil pour
		# l'escalade.
		var yaw := PI
		if focus == &"weapon":
			yaw = WEAPON_YAW
		elif focus == &"full":
			yaw = CLIMB_YAW
		_turntable.rotation.y = lerp_angle(_turntable.rotation.y, yaw, 1.0 - exp(-CAMERA_SMOOTH * delta))
	elif _turn_pause > 0.0:
		_turn_pause -= delta
	elif not _dragging:
		_turntable.rotation.y += TURN_SPEED * delta
	_animate_gesture(delta)
	_place_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_menu()


## Raccourcis clavier (sauf pendant la saisie d'un texte).
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if key.ctrl_pressed and key.keycode == KEY_Z:
		undo()
	elif key.keycode == KEY_TAB:
		var count := _tabs.get_tab_count()
		_tabs.current_tab = (_tabs.current_tab + (count - 1 if key.shift_pressed else 1)) % count
	elif not key.ctrl_pressed and not key.alt_pressed and _digit(key) >= 1 and _digit(key) <= roster.operators.size():
		select(_digit(key) - 1)
	else:
		return
	get_viewport().set_input_as_handled()


## Chiffre de la touche (rangée du haut, quelle que soit la disposition du
## clavier, ou pavé numérique), ou -1.
static func _digit(key: InputEventKey) -> int:
	if key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		return key.physical_keycode - KEY_0
	if key.keycode >= KEY_KP_1 and key.keycode <= KEY_KP_9:
		return key.keycode - KEY_KP_0
	return -1


# --- Construction ------------------------------------------------------------

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var title := Label.new()
	title.text = "OPÉRATEURS"
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Color(0.85, 0.9, 0.82))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_undo = Button.new()
	_undo.name = "Undo"
	_undo.text = "Annuler  (Ctrl+Z)"
	_undo.tooltip_text = "Annuler le dernier changement."
	_undo.disabled = true
	_undo.pressed.connect(undo)
	row.add_child(_undo)
	var back := Button.new()
	back.name = "Back"
	back.text = "Retour au menu"
	back.pressed.connect(back_to_menu)
	row.add_child(back)
	return row


## Portraits cliquables des trois opérateurs (visage en 3D, numéro, indicatif,
## nom).
func _build_selectors() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var group := ButtonGroup.new()
	for i in roster.operators.size():
		var button := Button.new()
		button.name = "Operator%d" % (i + 1)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(230, 76)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = "Touche %d" % (i + 1)
		button.icon = _build_portrait(i)
		button.pressed.connect(select.bind(i))
		row.add_child(button)
		_selectors.append(button)
	_refresh_selectors()
	return row


## Petite vue 3D du visage de l'opérateur `index`, pour son sélecteur.
func _build_portrait(index: int) -> Texture2D:
	var face := FacePortrait.build(self, 64, null, "Portrait%d" % (index + 1))
	portraits.append(face["model"])
	return face["texture"]


func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var container := SubViewportContainer.new()
	container.name = "Preview"
	container.stretch = true
	container.custom_minimum_size = Vector2(420, 420)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	column.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = 0.8
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.03
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	world.add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(-0.8, 0.5, 0.0)
	_sun.shadow_enabled = true
	world.add_child(_sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, PI + 0.6, 0.0)
	fill.light_energy = 0.35
	world.add_child(fill)
	# Sol du décor et socle.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.position.y = -0.1
	_ground_material = StandardMaterial3D.new()
	_ground_material.roughness = 0.95
	ground.material_override = _ground_material
	world.add_child(ground)
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.65
	disc.height = 0.1
	base.mesh = disc
	base.position.y = -0.05
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.24, 0.26, 0.25)
	stone.roughness = 0.9
	base.material_override = stone
	world.add_child(base)
	_props = Node3D.new()
	_props.name = "Backdrop"
	world.add_child(_props)
	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_turntable.rotation.y = PI
	world.add_child(_turntable)
	model = SoldierModel.new()
	model.name = "Model"
	model.silent = true
	_turntable.add_child(model)
	# Caisse de l'animation d'escalade, devant l'opérateur.
	_crate = MeshInstance3D.new()
	_crate.name = "ClimbCrate"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, CRATE_HEIGHT, CRATE_DEPTH)
	_crate.mesh = box
	_crate.position = Vector3(0.0, CRATE_HEIGHT * 0.5, -0.45 - CRATE_DEPTH * 0.5)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.34, 0.2)
	wood.roughness = 0.9
	_crate.material_override = wood
	_crate.visible = false
	_turntable.add_child(_crate)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)
	_apply_backdrop(&"")
	# Animations et aide.
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override(&"h_separation", 6)
	buttons.add_theme_constant_override(&"v_separation", 6)
	var group := ButtonGroup.new()
	for id: StringName in ANIMATIONS:
		var button := Button.new()
		button.name = "Animation_" + String(id)
		button.text = ANIMATIONS[id]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(play.bind(id))
		buttons.add_child(button)
		_animation_buttons[id] = button
	column.add_child(buttons)
	var hint := Label.new()
	hint.text = "Glisser : faire pivoter  •  Molette : zoom  •  1-3 : opérateur  •  Tab : onglet  •  Ctrl+Z : annuler"
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)
	(_animation_buttons[&"idle"] as Button).button_pressed = true
	return column


func _build_identity() -> Control:
	var box := _section_box()
	_name_edit = _line_edit(box, "Nom", 24, func(text: String) -> void:
		profile().name = text.strip_edges()
		_changed(false, "name"))
	_callsign_edit = _line_edit(box, "Indicatif", 16, func(text: String) -> void:
		var callsign := text.strip_edges()
		profile().callsign = callsign if not callsign.is_empty() else OperatorProfile.defaults(current).callsign
		_changed(false, "callsign"))
	_option(box, "Spécialité", &"specialty", _names(GearCatalog.SPECIALTIES), &"full")
	_specialty_info = _note(box, "")
	var suggested := Button.new()
	suggested.name = "SpecialtyOutfit"
	suggested.text = "Revêtir la tenue conseillée"
	suggested.tooltip_text = "Arme, couvre-chef, sac et équipement adaptés à la spécialité (le camouflage ne change pas)."
	suggested.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	suggested.pressed.connect(wear_specialty_outfit)
	box.add_child(suggested)
	_heading(box, "Visage")
	_option(box, "Morphologie", &"body", GearCatalog.BODIES, &"full")
	_swatch_row(box, &"skin", GearCatalog.SKINS, func(i: int) -> void: profile().skin = i, &"head")
	_option(box, "Barbe", &"beard", GearCatalog.BEARDS, &"head")
	_option(box, "Nez", &"nose", _names(GearCatalog.NOSES), &"head")
	_option(box, "Mâchoire", &"jaw", _names(GearCatalog.JAWS), &"head")
	_option(box, "Yeux", &"eyes", _names(GearCatalog.EYES), &"head")
	_option(box, "Cicatrice", &"scar", GearCatalog.SCARS, &"head")
	_option(box, "Peinture", &"face_paint", GearCatalog.FACE_PAINTS, &"head")
	_heading(box, "Cheveux")
	_option(box, "Coupe", &"hair_style", GearCatalog.HAIR_STYLES, &"head")
	_swatch_row(box, &"hair_color", GearCatalog.HAIR_COLORS, func(i: int) -> void: profile().hair_color = i, &"head")
	_note(box, "Le visage se voit sans cagoule (onglet Accessoires).")
	return box


func _build_outfit() -> Control:
	var box := _section_box()
	_heading(box, "Tenue")
	var dresses := HFlowContainer.new()
	var dress_group := ButtonGroup.new()
	for id: StringName in GearCatalog.CLOTHING:
		var button := Button.new()
		button.text = GearCatalog.CLOTHING[id]["name"]
		button.toggle_mode = true
		button.button_group = dress_group
		button.pressed.connect(func() -> void:
			profile().set_clothing(id)
			_refresh_controls()
			_changed(true, "", &"full"))
		dresses.add_child(button)
		_clothing_buttons[id] = button
	box.add_child(dresses)
	_clothing_info = Label.new()
	_clothing_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clothing_info.add_theme_font_size_override("font_size", 13)
	box.add_child(_clothing_info)
	_note(box, "En tenue civile, sans équipement militaire en vue ni arme en main, on se fond dans la foule : repéré bien plus lentement si la mission s'y prête, surtout dans la tenue de l'occasion. Seul le pistolet-mitrailleur se cache sous la veste.")
	_heading(box, "Camouflage (haut, et pantalon assorti)")
	var camos := HFlowContainer.new()
	var group := ButtonGroup.new()
	var ids: Array[StringName] = [&""]
	ids.append_array(GearCatalog.CAMOS.keys())
	for id in ids:
		var button := Button.new()
		button.text = "Uni" if id.is_empty() else GearCatalog.CAMOS[id]["name"]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func() -> void:
			if id.is_empty():
				profile().camo = &""
			else:
				profile().set_camo(id)
			_refresh_controls()
			_changed(true, "", &"full"))
		camos.add_child(button)
		_camo_buttons[id] = button
	box.add_child(camos)
	for entry: Array in [["Haut", "top_color", true, &"torso"], ["Pantalon", "pants_color", true, &"legs"], ["Gilet et équipement", "vest_color", false, &"torso"], ["Couvre-chef", "headwear_color", false, &"head"]]:
		_heading(box, entry[0])
		var key := StringName(entry[1])
		var plain: bool = entry[2]
		# Motif propre au vêtement (le haut prend celui choisi plus haut).
		if key != &"top_color":
			_part_camo_row(box, StringName(String(key).replace("_color", "_camo")), entry[3])
		_swatch_row(box, key, GearCatalog.PALETTE, func(i: int) -> void:
			profile().set(key, GearCatalog.PALETTE[i])
			# Une couleur unie choisie pour le haut ou le pantalon remplace le camouflage.
			if plain:
				_clear_camo(key), entry[3], func(color: Color) -> void:
			profile().set(key, color)
			if plain:
				_clear_camo(key))
	return box


## Couleur unie choisie pour `key` : le haut perd son camouflage (et le
## pantalon assorti avec lui), le pantalon le sien seulement.
func _clear_camo(key: StringName) -> void:
	if key == &"pants_color":
		profile().pants_camo = &""
	else:
		profile().camo = &""


## Rangée de motifs pour un vêtement (`key` : `pants_camo`, `vest_camo`,
## `headwear_camo`) : uni, un camouflage, ou (pantalon) comme le haut.
func _part_camo_row(box: Container, key: StringName, part: StringName) -> void:
	var row := HFlowContainer.new()
	row.name = String(key)
	var group := ButtonGroup.new()
	var ids: Array[StringName] = []
	if key == &"pants_camo":
		ids.append(OperatorProfile.SAME_CAMO)
	ids.append(&"")
	ids.append_array(GearCatalog.CAMOS.keys())
	var buttons := {}
	for id in ids:
		var button := Button.new()
		button.text = "Comme le haut" if id == OperatorProfile.SAME_CAMO else ("Uni" if id.is_empty() else GearCatalog.CAMOS[id]["name"])
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override(&"font_size", 12)
		button.pressed.connect(func() -> void:
			profile().set(key, id)
			_refresh_controls()
			_changed(true, "", part))
		row.add_child(button)
		buttons[id] = button
	box.add_child(row)
	_part_camo_buttons[key] = buttons


func _build_accessories() -> Control:
	var box := _section_box()
	_option(box, "Couvre-chef", &"headwear", GearCatalog.HEADWEAR, &"head")
	_heading(box, "Accessoires")
	for key: StringName in GearCatalog.ACCESSORIES:
		var check := CheckBox.new()
		check.name = String(key)
		check.text = GearCatalog.ACCESSORIES[key]
		check.toggled.connect(func(on: bool) -> void:
			if _refreshing:
				return
			profile().set(key, on)
			_changed(true, "", ACCESSORY_PARTS[key]))
		box.add_child(check)
		_checks[key] = check
	return box


func _build_armament() -> Control:
	var box := _section_box()
	_option(box, "Arme principale", &"primary", _names(GearCatalog.PRIMARY), &"weapon")
	_weapon_info = _note(box, "")
	box.add_child(_build_comparison())
	_option(box, "Arme secondaire", &"secondary", _names(GearCatalog.SECONDARY), &"legs")
	_secondary_info = _note(box, "")
	_heading(box, "Équipement")
	for key: StringName in GearCatalog.EQUIPMENT:
		var entry: Dictionary = GearCatalog.EQUIPMENT[key]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (%.1f kg)" % [entry["name"], GearCatalog.WEIGHTS[key]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = String(key)
		spin.min_value = 0
		spin.max_value = entry["max"]
		spin.value_changed.connect(func(value: float) -> void:
			if _refreshing:
				return
			profile().set(key, int(value))
			_changed(true, "", &"torso"))
		row.add_child(spin)
		box.add_child(row)
		_spins[key] = spin
	_note(box, "En mission : H change d'arme (l'opérateur dégaine seul son arme secondaire quand l'autre est à sec), N lance une grenade, Maj + N une grenade assourdissante, ; un fumigène, ù un obus de 40 mm (lance-grenades M320, monté sous le canon des fusils d'assaut, porté seul sinon ; 1,5 kg dès le premier obus), K pose une charge et L la fait sauter, J soigne le blessé le plus proche, U lève le bouclier (il faut une arme secondaire). Le couteau de combat est toujours emporté ; la hachette s'utilise au corps à corps (clic du milieu sur l'ennemi).")
	return box


## Comparaison des armes principales : une ligne par arme, une barre par
## caractéristique (relative à la meilleure), l'arme choisie en surbrillance.
func _build_comparison() -> Control:
	var grid := GridContainer.new()
	grid.name = "Comparison"
	grid.columns = 1 + COMPARED.size()
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 3)
	grid.add_child(Control.new())
	for title: String in COMPARED:
		var head := Label.new()
		head.text = title
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_size_override(&"font_size", 12)
		grid.add_child(head)
	var values := _comparison_values()
	for row in COMPARED.size():
		_compare_bars.append([] as Array[ProgressBar])
	var column := 0
	for id: StringName in GearCatalog.PRIMARY:
		var name_label := Label.new()
		name_label.text = GearCatalog.PRIMARY[id]["short"]
		name_label.add_theme_font_size_override(&"font_size", 12)
		grid.add_child(name_label)
		_compare_heads.append(name_label)
		for row in COMPARED.size():
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(48, 10)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.value = values[row][column][0]
			bar.tooltip_text = "%s — %s : %s" % [GearCatalog.PRIMARY[id]["name"], COMPARED[row], values[row][column][1]]
			grid.add_child(bar)
			(_compare_bars[row] as Array).append(bar)
		column += 1
	return grid


## Valeurs comparées : [caractéristique][arme] → [part de la meilleure, texte].
static func _comparison_values() -> Array:
	var raw: Array = []
	for id: StringName in GearCatalog.PRIMARY:
		var stats: Dictionary = GearCatalog.PRIMARY[id]["stats"]
		var noise: float = stats["gunshot_noise_radius"]
		raw.append([
			[float(stats["fire_range"]), "%d m" % stats["fire_range"]],
			[float(stats["fire_damage"]), "%d" % stats["fire_damage"] if float(stats.get("fire_damage_far", -1.0)) < 0.0 else "%d → %d" % [stats["fire_damage"], stats["fire_damage_far"]]],
			[1.0 / float(stats["fire_interval"]), "%.1f tirs/s" % (1.0 / float(stats["fire_interval"]))],
			[float(stats["magazine_size"]), "%d (+%d)" % [stats["magazine_size"], stats["reserve_ammo"]]],
			[maxf(LOUDEST - noise, 1.0), "bruit à %d m%s" % [noise, "" if stats["suppressed"] else ", sans silencieux"]],
		])
	var result: Array = []
	for row in COMPARED.size():
		var best := 0.0
		for weapon: Array in raw:
			best = maxf(best, weapon[row][0])
		result.append(raw.map(func(weapon: Array) -> Array: return [weapon[row][0] / best, weapon[row][1]]))
	return result


func _build_saved_outfits() -> Control:
	var box := _section_box()
	_note(box, "Enregistrez la tenue portée (apparence et armement) pour la remettre plus tard, ici ou avant une mission.")
	var row := HBoxContainer.new()
	_outfit_name = LineEdit.new()
	_outfit_name.name = "OutfitName"
	_outfit_name.placeholder_text = "Nom de la tenue (ex. : Nuit, Désert…)"
	_outfit_name.max_length = 24
	_outfit_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_outfit_name)
	var save := Button.new()
	save.name = "SaveOutfit"
	save.text = "Enregistrer la tenue"
	save.pressed.connect(func() -> void:
		if save_outfit(_outfit_name.text):
			_outfit_name.text = "")
	_outfit_name.text_submitted.connect(func(_text: String) -> void: save.pressed.emit())
	row.add_child(save)
	box.add_child(row)
	_outfit_list = VBoxContainer.new()
	_outfit_list.name = "Outfits"
	_outfit_list.add_theme_constant_override(&"separation", 6)
	box.add_child(_outfit_list)
	return box


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var reset := Button.new()
	reset.name = "Reset"
	reset.text = "Réinitialiser l'opérateur"
	reset.pressed.connect(func() -> void:
		reset_dialog.dialog_text = "Remettre %s dans sa tenue par défaut ?" % profile().callsign
		reset_dialog.ask())
	row.add_child(reset)
	var copy := Button.new()
	copy.name = "CopyLook"
	copy.text = "Même tenue pour l'équipe"
	copy.tooltip_text = "Donner le camouflage, les couleurs, le couvre-chef et les accessoires de cet opérateur aux deux autres (leur armement ne change pas)."
	copy.pressed.connect(copy_look_to_team)
	row.add_child(copy)
	var load_box := VBoxContainer.new()
	load_box.custom_minimum_size = Vector2(260, 0)
	_load_label = Label.new()
	_load_label.name = "Load"
	_load_label.add_theme_font_size_override(&"font_size", 13)
	load_box.add_child(_load_label)
	_load_bar = ProgressBar.new()
	_load_bar.custom_minimum_size = Vector2(0, 10)
	_load_bar.show_percentage = false
	_load_bar.max_value = GearCatalog.MAX_LOAD
	_load_fill = StyleBoxFlat.new()
	_load_bar.add_theme_stylebox_override(&"fill", _load_fill)
	load_box.add_child(_load_bar)
	load_box.tooltip_text = "Charge portée. Jusqu'à %d kg : aucune gêne ; jusqu'à %d kg : 8 %% plus lent ; jusqu'à %d kg : 18 %% plus lent et l'équipement s'entend en courant." % [
		GearCatalog.LOAD_TIERS[0]["limit"], GearCatalog.LOAD_TIERS[1]["limit"], GearCatalog.LOAD_TIERS[2]["limit"]]
	row.add_child(load_box)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.modulate = Color(1, 1, 1, 0.65)
	row.add_child(_status)
	return row


# --- Petits contrôles -------------------------------------------------------

func _add_tab(title: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_child(content)
	scroll.add_child(margin)
	_tabs.add_child(scroll)


func _section_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 8)
	return box


func _heading(box: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(0.75, 0.85, 0.7))
	box.add_child(label)


func _note(box: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 13)
	label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(label)
	return label


func _line_edit(box: Container, title: String, length: int, on_change: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.name = title
	edit.max_length = length
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(text: String) -> void:
		if not _refreshing:
			on_change.call(text))
	row.add_child(edit)
	box.add_child(row)
	return edit


## Liste déroulante liée à la propriété `key` du profil (`choices` : id → nom) ;
## `part` est la partie du corps cadrée quand elle change.
func _option(box: Container, title: String, key: StringName, choices: Dictionary, part: StringName) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.name = String(key)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = choices.keys()
	for id: StringName in ids:
		option.add_item(choices[id])
	option.item_selected.connect(func(index: int) -> void:
		if _refreshing:
			return
		profile().set(key, ids[index])
		_refresh_controls()
		_changed(true, "", part))
	row.add_child(option)
	box.add_child(row)
	_option_buttons[key] = [option, ids]


## Rangée de pastilles de couleur ; `on_pick` reçoit l'indice choisi.
## `on_free` (facultatif) : couleur libre choisie au sélecteur placé en fin
## de rangée (`ColorPickerButton`), en plus de la palette.
func _swatch_row(box: Container, key: StringName, colors: Array[Color], on_pick: Callable, part: StringName, on_free: Callable = Callable()) -> void:
	var row := HFlowContainer.new()
	row.name = String(key)
	row.add_theme_constant_override(&"h_separation", 4)
	row.add_theme_constant_override(&"v_separation", 4)
	var buttons: Array[Button] = []
	for i in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(28, 28)
		button.tooltip_text = "#" + colors[i].to_html(false)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = colors[i]
			style.set_corner_radius_all(4)
			style.set_border_width_all(2 if state != "normal" else 1)
			style.border_color = Color(0.9, 0.9, 0.85) if state != "normal" else Color(0, 0, 0, 0.5)
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(func() -> void:
			on_pick.call(i)
			_refresh_controls()
			_changed(true, "", part))
		row.add_child(button)
		buttons.append(button)
	var picker: ColorPickerButton = null
	if on_free.is_valid():
		picker = ColorPickerButton.new()
		picker.name = "Free"
		picker.custom_minimum_size = Vector2(44, 28)
		picker.text = "…"
		picker.tooltip_text = "Couleur libre"
		picker.edit_alpha = false
		picker.color_changed.connect(func(color: Color) -> void:
			on_free.call(color)
			_refresh_controls()
			# Les retouches successives au sélecteur ne font qu'une annulation.
			_changed(true, String(key), part))
		row.add_child(picker)
	box.add_child(row)
	_swatches[key] = [buttons, colors, picker]


func _names(entries: Dictionary) -> Dictionary:
	var names := {}
	for id: StringName in entries:
		names[id] = entries[id]["name"]
	return names


# --- Mise à jour -------------------------------------------------------------

## Le profil a changé : refus si un opérateur devient trop chargé, sinon
## mémorisation pour l'annulation (`merge` : les changements successifs de
## même clé n'en font qu'un), aperçu (si `rebuild`), cadrage sur `part`,
## portraits et sauvegarde.
func _changed(rebuild: bool = true, merge: String = "", part: StringName = &"") -> void:
	for operator in roster.operators:
		var weight := GearCatalog.load_of(operator)
		if weight > GearCatalog.MAX_LOAD + 0.001:
			var callsign := operator.callsign
			_restore(_snapshot)
			_after_restore()
			Sfx.play_ui(&"denied")
			_set_status("Trop lourd pour %s : %.1f kg (%d kg au plus)" % [callsign, weight, GearCatalog.MAX_LOAD])
			return
	if merge.is_empty() or merge != _merge_key:
		_history.append(_snapshot)
		if _history.size() > HISTORY_SIZE:
			_history.pop_front()
	_merge_key = merge
	_snapshot = _capture()
	_undo.disabled = false
	if rebuild:
		_update_preview()
		portraits[current].outfit = profile()
	if not part.is_empty():
		focus_on(part)
	_refresh_selectors()
	_refresh_load()
	_save()


func _save() -> void:
	var error := roster.save()
	_set_status("Sauvegardé" if error == OK else "Échec de la sauvegarde (%s)" % error_string(error))


func _set_status(text: String) -> void:
	_status.text = text


## Profils de l'équipe, au format JSON.
func _capture() -> Array:
	return roster.operators.map(func(operator: OperatorProfile) -> Dictionary: return operator.to_dict())


func _restore(state: Array) -> void:
	for i in state.size():
		roster.operators[i] = OperatorProfile.from_dict(state[i], i)


## Tout l'écran d'après l'équipe restaurée, puis sauvegarde.
func _after_restore() -> void:
	_undo.disabled = _history.is_empty()
	_refresh_controls()
	_update_preview()
	_refresh_portraits()
	_refresh_selectors()
	_save()


func _refresh_selectors() -> void:
	for i in _selectors.size():
		var operator := roster.operators[i]
		var specialty: String = GearCatalog.SPECIALTIES[operator.specialty]["name"]
		_selectors[i].text = "%d  %s\n    %s\n    %s" % [i + 1, operator.callsign, operator.name, specialty]


func _refresh_portraits() -> void:
	for i in portraits.size():
		portraits[i].outfit = roster.operators[i]


func _refresh_load() -> void:
	var weight := GearCatalog.load_of(profile())
	var tier := GearCatalog.load_tier(weight)
	var index := GearCatalog.LOAD_TIERS.find(tier)
	_load_label.text = "Charge : %.1f / %d kg — %s" % [weight, GearCatalog.MAX_LOAD, tier["name"]]
	_load_bar.value = weight
	_load_fill.bg_color = [Color(0.35, 0.75, 0.4), Color(0.9, 0.72, 0.25), Color(0.9, 0.35, 0.25)][index]


## Contrôles des onglets d'après le profil de l'opérateur courant.
func _refresh_controls() -> void:
	_refreshing = true
	var operator := profile()
	if _name_edit.text != operator.name:
		_name_edit.text = operator.name
	if _callsign_edit.text != operator.callsign:
		_callsign_edit.text = operator.callsign
	for key: StringName in _option_buttons:
		var option: OptionButton = _option_buttons[key][0]
		option.select((_option_buttons[key][1] as Array).find(operator.get(key)))
	for key: StringName in _checks:
		var check: CheckBox = _checks[key]
		check.button_pressed = operator.get(key)
	var nvg: CheckBox = _checks[&"nvg"]
	nvg.disabled = operator.headwear != &"helmet"
	nvg.tooltip_text = "Se fixe sur le casque balistique." if nvg.disabled else ""
	for key: StringName in _spins:
		(_spins[key] as SpinBox).value = operator.get(key)
	for key: StringName in _swatches:
		var buttons: Array[Button] = _swatches[key][0]
		var colors: Array[Color] = _swatches[key][1]
		var value: Variant = operator.get(key)
		var in_palette := false
		for i in buttons.size():
			var chosen: bool = (value == i) if value is int else (value as Color).is_equal_approx(colors[i])
			in_palette = in_palette or chosen
			buttons[i].modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.75)
			buttons[i].text = "✓" if chosen else ""
		var picker: ColorPickerButton = _swatches[key][2]
		if picker and value is Color:
			picker.color = value
			picker.text = "" if not in_palette else "…"
	for id: StringName in _camo_buttons:
		(_camo_buttons[id] as Button).set_pressed_no_signal(id == operator.camo)
	for key: StringName in _part_camo_buttons:
		var buttons: Dictionary = _part_camo_buttons[key]
		for id: StringName in buttons:
			(buttons[id] as Button).set_pressed_no_signal(id == operator.get(key))
	for id: StringName in _clothing_buttons:
		(_clothing_buttons[id] as Button).set_pressed_no_signal(id == operator.clothing)
	_clothing_info.text = GearCatalog.CLOTHING[operator.clothing]["description"]
	_weapon_info.text = GearCatalog.PRIMARY[operator.primary]["description"]
	_secondary_info.text = GearCatalog.SECONDARY[operator.secondary]["description"]
	var chosen := GearCatalog.PRIMARY.keys().find(operator.primary)
	for column in _compare_heads.size():
		var highlight := Color.WHITE if column == chosen else Color(1, 1, 1, 0.35)
		_compare_heads[column].modulate = highlight
		for bars: Array in _compare_bars:
			(bars[column] as ProgressBar).modulate = highlight
	var specialty: Dictionary = GearCatalog.SPECIALTIES[operator.specialty]
	_specialty_info.text = specialty["description"]
	_refresh_outfit_list()
	_refresh_load()
	_refreshing = false


func _refresh_outfit_list() -> void:
	for child in _outfit_list.get_children():
		_outfit_list.remove_child(child)
		child.queue_free()
	var outfits := profile().saved_outfits
	if outfits.is_empty():
		_note(_outfit_list, "Aucune tenue enregistrée pour %s." % profile().callsign)
	for i in outfits.size():
		var row := HBoxContainer.new()
		var label := Label.new()
		var data: Dictionary = outfits[i]["outfit"]
		var camo := String(data.get("camo", ""))
		label.text = "%s  —  %s, %s" % [outfits[i]["name"], "uni" if camo.is_empty() else GearCatalog.CAMOS[StringName(camo)]["name"],
				GearCatalog.PRIMARY.get(StringName(str(data.get("primary", "carbine"))), GearCatalog.PRIMARY[&"carbine"])["short"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var wear := Button.new()
		wear.name = "Wear%d" % (i + 1)
		wear.text = "Porter"
		wear.pressed.connect(wear_outfit.bind(i))
		row.add_child(wear)
		var delete := Button.new()
		delete.name = "Delete%d" % (i + 1)
		delete.text = "Supprimer"
		delete.pressed.connect(delete_outfit.bind(i))
		row.add_child(delete)
		_outfit_list.add_child(row)


func _update_preview() -> void:
	model.outfit = profile()
	_apply_backdrop(profile().camo)
	_apply_animation()


## Décor assorti au camouflage `camo` : couleurs du sol et du ciel, lumière
## et éléments (arbres, sapins, rochers, murets).
func _apply_backdrop(camo: StringName) -> void:
	if camo == backdrop:
		return
	backdrop = camo
	var entry: Dictionary = GearCatalog.BACKDROPS.get(camo, GearCatalog.BACKDROPS[&""])
	_environment.background_color = entry["sky"]
	_environment.fog_light_color = entry["sky"]
	_environment.ambient_light_color = entry["ambient"]
	_ground_material.albedo_color = entry["ground"]
	_sun.light_color = entry["sun"]
	_sun.light_energy = entry["energy"]
	for child in _props.get_children():
		_props.remove_child(child)
		child.free()
	var kind: StringName = entry["props"]
	if kind.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ground: Color = entry["ground"]
	for i in 9:
		# Derrière et sur les côtés du socle, jamais entre la caméra et l'opérateur.
		var angle := lerpf(PI * 0.95, PI * 2.05, float(i) / 8.0) + rng.randf_range(-0.12, 0.12)
		var distance := rng.randf_range(4.5, 9.0)
		var spot := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var prop := _prop(kind, rng, ground)
		prop.position = spot
		prop.rotation.y = rng.randf() * TAU
		_props.add_child(prop)


func _prop(kind: StringName, rng: RandomNumberGenerator, ground: Color) -> Node3D:
	var prop := Node3D.new()
	var size_factor := rng.randf_range(0.7, 1.3)
	match kind:
		&"trees":
			_prop_mesh(prop, _cylinder_mesh(0.12, 0.15, 2.0), Vector3(0, 1.0, 0) * size_factor, Color(0.3, 0.22, 0.14))
			_prop_mesh(prop, _sphere_mesh(0.9), Vector3(0, 2.3, 0) * size_factor, Color(0.2, 0.32, 0.14).darkened(rng.randf() * 0.2))
		&"pines":
			_prop_mesh(prop, _cylinder_mesh(0.1, 0.12, 1.2), Vector3(0, 0.6, 0) * size_factor, Color(0.3, 0.24, 0.18))
			_prop_mesh(prop, _cylinder_mesh(0.0, 0.8, 1.6), Vector3(0, 1.6, 0) * size_factor, Color(0.82, 0.86, 0.88))
			_prop_mesh(prop, _cylinder_mesh(0.0, 0.55, 1.2), Vector3(0, 2.4, 0) * size_factor, Color(0.88, 0.91, 0.93))
		&"rocks":
			var rock := _prop_mesh(prop, _sphere_mesh(0.7), Vector3(0, 0.15, 0), ground.darkened(0.25 + rng.randf() * 0.15))
			rock.scale = Vector3(1.2, 0.6, 0.9) * size_factor
		&"walls":
			var wall := BoxMesh.new()
			wall.size = Vector3(2.2, 1.3, 0.3)
			_prop_mesh(prop, wall, Vector3(0, 0.65, 0), Color(0.5, 0.5, 0.49).darkened(rng.randf() * 0.2))
			if rng.randf() < 0.4:
				_prop_mesh(prop, _cylinder_mesh(0.3, 0.3, 0.9), Vector3(0.0, 0.45, 0.6), Color(0.3, 0.33, 0.28))
	return prop


func _prop_mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


static func _cylinder_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


static func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _apply_animation() -> void:
	model.move_ratio = {&"walk": 1.0, &"run": 2.0}.get(animation, 0.0)
	match animation:
		&"crouch":
			model.posture = SoldierModel.Posture.CROUCHED
		&"prone":
			model.posture = SoldierModel.Posture.PRONE
		_:
			model.posture = SoldierModel.Posture.STANDING
	model.aiming = animation == &"aim"
	# Mains libres pour lancer, frapper au couteau et grimper.
	model.weapon_slung = animation in [&"throw", &"stab", &"climb"]
	model.strike_with_knife = true
	model.strike_move = SoldierModel.StrikeMove.UPPERCUT
	model.reload_progress = -1.0
	model.throw_progress = -1.0
	model.strike_progress = -1.0
	model.climb_progress = -1.0
	model.climb_descending = false
	model.climb_jump = false
	model.position = Vector3.ZERO
	_crate.visible = animation == &"climb"


## Gestes en boucle (rechargement, lancer, coup, escalade).
func _animate_gesture(delta: float) -> void:
	if not GESTURES.has(animation):
		return
	_anim_time += delta
	var timing: Array = GESTURES[animation]
	var t := fmod(_anim_time, timing[1]) / float(timing[0])
	var progress := t if t <= 1.0 else -1.0
	match animation:
		&"reload":
			model.reload_progress = progress
		&"throw":
			model.throw_progress = progress
		&"stab":
			model.strike_progress = progress
		&"climb":
			model.climb_progress = progress
			# Le geste avance l'opérateur ; arrivé, il reste debout sur la caisse.
			var u := minf(t, 1.0)
			model.position = Vector3(0.0, SoldierModel.sample_keys(Commando.CLIMB_UP_HEIGHT, u) * CRATE_HEIGHT,
					-SoldierModel.sample_keys(Commando.CLIMB_UP_FORWARD, u) * CLIMB_ADVANCE)


func _place_camera(delta: float = 0.0) -> void:
	var posture := {&"crouch": 1, &"prone": 2}.get(animation, 0) as int
	var target_height: float
	var target_distance: float
	if FOCUS.has(focus):
		target_height = FOCUS[focus]["height"][posture]
		target_distance = FOCUS[focus]["distance"]
	else:
		# Plus on est près, plus on vise la tête (plus bas accroupi ou couché).
		var head: float = [1.5, 1.1, 0.4][posture]
		var middle: float = [0.95, 0.65, 0.3][posture]
		target_height = lerpf(head, middle, (zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN))
		target_distance = zoom
	target_height += model.position.y
	var blend := 1.0 if delta <= 0.0 else 1.0 - exp(-CAMERA_SMOOTH * delta)
	_camera_height = lerpf(_camera_height, target_height, blend)
	_camera_distance = lerpf(_camera_distance, target_distance, blend)
	var eye := Vector3(0.0, _camera_height + _camera_distance * 0.18, _camera_distance)
	_camera.transform = Transform3D(Basis(), eye).looking_at(Vector3(0.0, _camera_height, 0.0))


func _on_preview_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
				_turn_pause = TURN_PAUSE
				if button.pressed:
					focus_on(&"full")
			MOUSE_BUTTON_WHEEL_UP:
				zoom = maxf(zoom - ZOOM_STEP, ZOOM_MIN)
				focus_on(&"full")
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = minf(zoom + ZOOM_STEP, ZOOM_MAX)
				focus_on(&"full")
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_turntable.rotation.y += motion.relative.x * DRAG_TURN
		_turn_pause = TURN_PAUSE
