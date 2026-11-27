class_name UnitPortrait
extends PanelContainer
## Portrait d'un opérateur dans le HUD : vie, posture, munitions, sélection.
## Clic : sélectionner (Maj : ajouter). Double clic : centrer la caméra.

const POSTURE_NAMES: Dictionary = {
	SoldierModel.Posture.STANDING: "Debout",
	SoldierModel.Posture.CROUCHED: "Accroupi",
	SoldierModel.Posture.PRONE: "Rampé",
}

@export var selected_border := Color(0.25, 0.65, 1.0)
@export var normal_border := Color(0.3, 0.34, 0.3, 0.9)
@export var healthy_color := Color(0.35, 0.8, 0.4)
@export var wounded_color := Color(0.9, 0.25, 0.2)

var _unit: Commando
var _style: StyleBoxFlat
var _fill: StyleBoxFlat

@onready var _number: Label = %Number
@onready var _name: Label = %Name
@onready var _health: ProgressBar = %Health
@onready var _health_text: Label = %HealthText
@onready var _status: Label = %Status
@onready var _ammo: Label = %Ammo
@onready var _no_knife: Label = %NoKnife
## Équipement restant (grenades, charges, trousses), sous la vie.
var _gear: Label
## Endurance (course, port d'un corps), sous la vie.
var _stamina: ProgressBar
var _stamina_fill: StyleBoxFlat
const STAMINA_COLOR := Color(0.85, 0.75, 0.3)
const WINDED_COLOR := Color(0.6, 0.45, 0.25)
## Visage 3D de l'opérateur (à gauche de l'en-tête), sa vue et son modèle.
var _face: TextureRect
var _face_view: SubViewport
var _face_model: SoldierModel
const FACE_SIZE := 62


## Associe le portrait à une unité.
func setup(unit: Commando) -> void:
	_unit = unit
	_style = (get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override(&"panel", _style)
	_fill = (_health.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate()
	_health.add_theme_stylebox_override(&"fill", _fill)
	_gear = Label.new()
	_gear.name = "Gear"
	_gear.add_theme_font_size_override(&"font_size", 12)
	_gear.modulate = Color(1, 1, 1, 0.75)
	_gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Rows.add_child(_gear)
	_stamina = ProgressBar.new()
	_stamina.name = "Stamina"
	_stamina.show_percentage = false
	_stamina.custom_minimum_size = Vector2(0, 4)
	_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina.tooltip_text = "Endurance : la course et le port d'un corps l'épuisent"
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = STAMINA_COLOR
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.35)
	_stamina.add_theme_stylebox_override(&"fill", _stamina_fill)
	_stamina.add_theme_stylebox_override(&"background", back)
	$Rows.add_child(_stamina)
	$Rows.move_child(_stamina, _health.get_index() + 1)
	_build_face(unit)
	_number.text = str(unit.unit_index)
	_name.text = unit.display_name
	if unit.profile and not unit.profile.name.is_empty():
		tooltip_text = "%s « %s »" % [unit.profile.name, unit.profile.callsign]
	unit.selected_changed.connect(func(_selected: bool) -> void: _refresh())
	unit.posture_changed.connect(func(_posture: SoldierModel.Posture) -> void: _refresh())
	unit.evacuated.connect(_refresh)
	EventBus.unit_damaged.connect(_on_unit_event.unbind(1))
	EventBus.unit_ammo_changed.connect(_on_unit_event)
	EventBus.unit_died.connect(_on_unit_event)
	_refresh()


## Visage 3D, à la tenue de l'opérateur, sur toute la hauteur de la carte. Grimace
## quand il est blessé ; figé (plus rendu) quand il est mort ou évacué.
func _build_face(unit: Commando) -> void:
	var face := FacePortrait.build(self, FACE_SIZE * 2, unit.profile, "Face", 0.55, 0.6)
	_face_view = face["viewport"]
	_face_model = face["model"]
	_face = TextureRect.new()
	_face.name = "Face"
	_face.texture = face["texture"]
	_face.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rows := $Rows as Control
	var line := HBoxContainer.new()
	line.name = "Line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 8)
	add_child(line)
	rows.reparent(line)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_face)
	line.move_child(_face, 0)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _unit.is_dead or _unit.is_evacuated:
		return
	SelectionManager.select([_unit] as Array[Commando], Input.is_action_pressed(&"select_additive"))
	if button.double_click:
		var rig := get_viewport().get_camera_3d().get_parent() as CameraRig
		if rig:
			rig.focus_on(_unit.global_position)


func _process(_delta: float) -> void:
	if _unit == null or _stamina == null:
		return
	_stamina.value = _unit.stamina * 100.0
	_stamina_fill.bg_color = WINDED_COLOR if _unit.winded else STAMINA_COLOR
	_stamina.visible = not (_unit.is_dead or _unit.is_evacuated) and _unit.stamina < 0.999


func _on_unit_event(unit: Node3D) -> void:
	if unit == _unit:
		_refresh()


func _refresh() -> void:
	var ratio := _unit.health.health / _unit.health.max_health
	_health.value = ratio * 100.0
	_health_text.text = "%d PV" % roundi(_unit.health.health)
	_fill.bg_color = wounded_color.lerp(healthy_color, ratio)
	_style.border_color = selected_border if _unit.is_selected else normal_border
	if _face:
		# Blessé : visage rougi ; mort : gris, plus rendu.
		_face.modulate = Color(1.0, 0.55 + 0.45 * ratio, 0.55 + 0.45 * ratio)
		_face_view.render_target_update_mode = SubViewport.UPDATE_DISABLED if _unit.is_dead or _unit.is_evacuated else SubViewport.UPDATE_WHEN_VISIBLE
		if _unit.is_dead:
			_face.modulate = Color(0.5, 0.5, 0.5)
	if _unit.is_dead or _unit.is_evacuated:
		_status.text = "Évacué" if _unit.is_evacuated else "Mort"
		_ammo.text = ""
		_gear.visible = false
		_no_knife.visible = false
		modulate = Color(1.0, 1.0, 1.0, 0.45)
		return
	modulate = Color.WHITE
	_status.text = POSTURE_NAMES[_unit.posture] + (" · boite" if _unit.is_limping() else "")
	if _unit.is_reloading():
		_ammo.text = "Rechargement…"
	elif not _unit.has_ammo():
		_ammo.text = "À sec"
	else:
		_ammo.text = "%s%d / %d" % ["Sec. " if _unit.using_secondary else "", _unit.ammo_in_magazine, _unit.ammo_reserve]
	var gear: Array[String] = []
	if _unit.grenades > 0:
		gear.append("Grenades %d" % _unit.grenades)
	if _unit.smoke_grenades > 0:
		gear.append("Fumigènes %d" % _unit.smoke_grenades)
	if _unit.stun_grenades > 0:
		gear.append("Assourdissantes %d" % _unit.stun_grenades)
	if _unit.lamp_on:
		gear.append("Lampe allumée" if _unit.using_secondary else "Lampe (arme de poing)")
	if _unit.tasers > 0:
		gear.append("Taser %d" % _unit.tasers)
	if _unit.jammers > 0:
		gear.append("Brouilleur %d" % _unit.jammers)
	if _unit.launcher_grenades > 0:
		gear.append("40 mm %d" % _unit.launcher_grenades)
	if _unit.launcher_smoke > 0:
		gear.append("40 mm fum. %d" % _unit.launcher_smoke)
	if _unit.launcher_gas > 0:
		gear.append("40 mm lacry. %d" % _unit.launcher_gas)
	if _unit.hatchets > 0:
		gear.append("Hachette")
	if _unit.explosives > 0:
		gear.append("Charges %d" % _unit.explosives)
	if _unit.medkits > 0:
		gear.append("Trousse")
	if _unit.has_documents:
		gear.append("Documents")
	_gear.text = "  •  ".join(gear)
	_gear.visible = not gear.is_empty()
	# Couteau de lancer : rappel discret tant qu'il n'est pas ramassé.
	_no_knife.visible = _unit.throwing_knives < _unit.stats.throwing_knives
	_ammo.modulate = wounded_color if _unit.ammo_in_magazine == 0 else Color.WHITE
