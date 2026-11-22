@tool
class_name TutorialStation
extends Area3D
## Atelier du didacticiel : quand un opérateur entre dans la zone, une petite
## fenêtre (`TutorialPanel`) explique l'exercice. L'exercice est réussi
## selon `goal` :
## - REACH : un opérateur atteint le cercle `goal_offset` (au-dessus de
##   `goal_min_height` s'il faut grimper) ;
## - TARGETS_DOWN : les ennemis `targets` ont tous été neutralisés (morts
##   ou assommés, au moins une fois) ;
## - FINISH : fin du didacticiel, une fois tous les autres ateliers réussis.
## Réussi, il remplit l'objectif `objective_id` du journal ; au-dessus de
## l'atelier, un « ? » jaune devient un « ✓ » vert.

enum Goal { NONE, REACH, TARGETS_DOWN, FINISH }

const GROUP := &"tutorial_stations"
const PENDING_COLOR := Color(1.0, 0.85, 0.3)
const DONE_COLOR := Color(0.45, 0.95, 0.5)
const GOAL_COLOR := Color(0.3, 0.85, 1.0)
## Intervalle (s) de vérification des cibles.
const CHECK_INTERVAL := 0.25
## Hauteur (m) du repère « ? » au-dessus de l'atelier.
const SIGN_HEIGHT := 3.2

@export var title: String = ""
## Texte de l'astuce ; `{action}` : nom de la touche de cette action.
@export_multiline var text: String = ""
## Texte affiché à la réussite (la suite).
@export_multiline var done_text: String = ""
## Numéro de l'atelier (ordre de passage), affiché « n / total ».
@export var step: int = 0
@export var objective_id: StringName = &""
@export var size := Vector2(12.0, 6.0)
@export var goal: Goal = Goal.NONE
@export var goal_offset := Vector3.ZERO
@export var goal_radius: float = 1.5
@export var goal_min_height: float = -INF
@export var targets: Array[NodePath] = []
## Astuce affichée dès le début du niveau.
@export var show_at_start: bool = false

var is_done: bool = false
var _down: Dictionary = {}
var _check_left: float = 0.0
var _sign: Label3D
var _goal_marker: Node3D
## Fin refusée : rappel déjà affiché (jusqu'à ce qu'on sorte du cercle).
var _reminded: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_sign()
		if goal == Goal.REACH or goal == Goal.FINISH:
			_build_goal_marker()
		return
	add_to_group(GROUP)
	collision_layer = 0
	# Couche des unités du joueur.
	collision_mask = 0b100
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 3.0, size.y)
	shape.shape = box
	shape.position.y = 1.5
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_build_sign()
	if goal == Goal.REACH or goal == Goal.FINISH:
		_build_goal_marker()
	if show_at_start:
		_show_tip.call_deferred()
	# Une cible assommée peut se relever avant la vérification suivante.
	for path in targets:
		var enemy := get_node_or_null(path) as Enemy
		if enemy:
			enemy.state_changed.connect(func(state: Enemy.State) -> void:
				if state == Enemy.State.STUNNED:
					_down[path] = true)
			enemy.health.died.connect(func() -> void: _down[path] = true)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_done:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	match goal:
		Goal.REACH:
			if _someone_at_goal():
				complete()
		Goal.TARGETS_DOWN:
			if _targets_down():
				complete()
		Goal.FINISH:
			if _someone_at_goal():
				_try_finish()
			else:
				_reminded = false


## Point visé (cercle au sol) d'un atelier REACH ou FINISH.
func goal_point() -> Vector3:
	return global_transform * goal_offset


## Réussit l'exercice : objectif rempli, repère vert, astuce de la suite.
func complete() -> void:
	if is_done:
		return
	is_done = true
	if objective_id != &"":
		EventBus.objective_completed.emit(objective_id)
	_sign.text = "✓"
	_sign.modulate = DONE_COLOR
	if _goal_marker:
		_goal_marker.visible = false
	Sfx.play_ui(&"order")
	var panel := TutorialPanel.instance(get_tree())
	if panel:
		panel.show_done(title, done_text)


## Ateliers du niveau, dans l'ordre de passage.
static func all_in(tree: SceneTree) -> Array[TutorialStation]:
	var stations: Array[TutorialStation] = []
	for node in tree.get_nodes_in_group(GROUP):
		if node is TutorialStation:
			stations.append(node)
	stations.sort_custom(func(a: TutorialStation, b: TutorialStation) -> bool: return a.step < b.step)
	return stations


func _show_tip() -> void:
	var panel := TutorialPanel.instance(get_tree())
	if panel == null:
		return
	var total := TutorialStation.all_in(get_tree()).size()
	panel.show_tip(title, text, "%d / %d" % [step, total] if step > 0 else "")


func _on_body_entered(body: Node3D) -> void:
	if body is Commando and not is_done:
		_show_tip()


func _someone_at_goal() -> bool:
	var point := goal_point()
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead:
			continue
		if unit.global_position.y < goal_min_height:
			continue
		var offset := unit.global_position - point
		if Vector2(offset.x, offset.z).length() <= goal_radius:
			return true
	return false


func _targets_down() -> bool:
	if targets.is_empty():
		return false
	for path in targets:
		var enemy := get_node_or_null(path) as Enemy
		if enemy == null:
			continue
		if enemy.is_dead or enemy.is_stunned():
			_down[path] = true
		if not _down.has(path):
			return false
	return true


## Fin du didacticiel : seulement si tous les autres ateliers sont réussis ;
## sinon, la fenêtre dit lesquels restent.
func _try_finish() -> void:
	var missing: PackedStringArray = []
	for station in TutorialStation.all_in(get_tree()):
		if station != self and not station.is_done and station.goal != Goal.NONE:
			missing.append(station.title)
	if not missing.is_empty():
		if not _reminded:
			_reminded = true
			var panel := TutorialPanel.instance(get_tree())
			if panel:
				panel.show_tip(title, "Il reste des exercices à réussir : %s. Le journal ({toggle_objectives}) les liste." % ", ".join(missing))
		return
	complete()
	EventBus.mission_ended.emit(true, "DIDACTICIEL TERMINÉ")


func _build_sign() -> void:
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = "?"
	_sign.modulate = PENDING_COLOR
	_sign.font_size = 160
	_sign.outline_size = 24
	_sign.pixel_size = 0.006
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = false
	_sign.shaded = false
	_sign.position = Vector3(0.0, SIGN_HEIGHT, 0.0)
	add_child(_sign)


## Cercle lumineux au sol (ou sur le toit) du point à atteindre.
func _build_goal_marker() -> void:
	_goal_marker = Node3D.new()
	_goal_marker.name = "Goal"
	add_child(_goal_marker)
	_goal_marker.position = goal_offset
	var ring := TorusMesh.new()
	ring.inner_radius = goal_radius - 0.15
	ring.outer_radius = goal_radius
	ring.rings = 48
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(GOAL_COLOR, 0.85)
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.material_override = material
	mesh.scale = Vector3(1.0, 0.1, 1.0)
	mesh.position.y = 0.05
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_goal_marker.add_child(mesh)
	if goal == Goal.FINISH:
		var label := Label3D.new()
		label.text = "FIN"
		label.modulate = GOAL_COLOR
		label.font_size = 96
		label.pixel_size = 0.011
		label.rotation.x = -PI / 2.0
		label.position.y = 0.06
		label.shaded = false
		_goal_marker.add_child(label)
