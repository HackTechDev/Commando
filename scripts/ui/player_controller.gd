class_name PlayerController
extends Control
## Entrées du joueur : sélection (clic, rectangle, touches), ordres de
## déplacement, d'attaque et postures. Dessine aussi le rectangle de sélection.
##
## Actions ciblées (couteau, assommer, lancer de couteau) : la touche ou le bouton arme l'action,
## puis un clic gauche sur un ennemi la confie à l'opérateur sélectionné le plus
## proche. Un clic droit, ou un clic ailleurs que sur un ennemi, l'annule.

signal pending_action_changed(action: StringName)

const ACTION_NONE := &""
const ACTION_KNIFE := &"knife"
const ACTION_KNOCKOUT := &"knockout"
const ACTION_THROW := &"throw"

const DRAG_THRESHOLD := 6.0
const RAY_LENGTH := 500.0
const MASK_GROUND := 0b011
const MASK_COMMANDOS := 0b100
## Ennemis actifs (couche 4) et assommés (couche 5).
const MASK_ENEMIES := 0b11000

@export var box_fill := Color(0.2, 0.6, 1.0, 0.15)
@export var box_border := Color(0.3, 0.7, 1.0, 0.9)
## Un clic droit sur un obstacle grimpable (caisse) y fait monter une unité.
@export var marker_color := Color(0.3, 0.9, 0.4)
@export var marker_run_color := Color(1.0, 0.75, 0.2)
@export var marker_attack_color := Color(1.0, 0.25, 0.2)
@export var marker_melee_color := Color(0.75, 0.4, 1.0)

## Action ciblée en attente d'un clic sur un ennemi (`ACTION_NONE` sinon).
var pending_action: StringName = ACTION_NONE

var _dragging: bool = false
var _drag_start: Vector2
var _drag_end: Vector2


func _ready() -> void:
	SelectionManager.selection_changed.connect(func(units: Array[Commando]) -> void:
		if units.is_empty():
			cancel_pending_action())


## Arme l'action ciblée `action`, ou la désarme si elle l'était déjà.
func toggle_pending_action(action: StringName) -> void:
	if action == pending_action or SelectionManager.selected.is_empty():
		cancel_pending_action()
		return
	pending_action = action
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	pending_action_changed.emit(pending_action)


## Désarme l'action ciblée en cours.
func cancel_pending_action() -> void:
	if pending_action == ACTION_NONE:
		return
	pending_action = ACTION_NONE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	pending_action_changed.emit(pending_action)


func _unhandled_input(event: InputEvent) -> void:
	if pending_action != ACTION_NONE and event is InputEventMouseButton:
		if event.is_action_pressed(&"select"):
			_use_pending_action((event as InputEventMouseButton).position)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"order"):
			cancel_pending_action()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if event.is_action_pressed(&"select"):
			_dragging = true
			_drag_start = button.position
			_drag_end = button.position
		elif event.is_action_released(&"select") and _dragging:
			_dragging = false
			queue_redraw()
			_finish_selection()
		elif event.is_action_pressed(&"order"):
			_order(button.position, button.double_click)
	elif event is InputEventMouseMotion and _dragging:
		_drag_end = (event as InputEventMouseMotion).position
		queue_redraw()
	elif event.is_action_pressed(&"posture_crouch"):
		SelectionManager.toggle_posture(SoldierModel.Posture.CROUCHED)
	elif event.is_action_pressed(&"posture_prone"):
		SelectionManager.toggle_posture(SoldierModel.Posture.PRONE)
	elif event.is_action_pressed(&"action_knife"):
		toggle_pending_action(ACTION_KNIFE)
	elif event.is_action_pressed(&"action_knockout"):
		toggle_pending_action(ACTION_KNOCKOUT)
	elif event.is_action_pressed(&"action_throw"):
		toggle_pending_action(ACTION_THROW)
	elif event.is_action_pressed(&"action_sling"):
		SelectionManager.toggle_sling()
	elif event.is_action_pressed(&"reload"):
		SelectionManager.reload()
	elif event.is_action_pressed(&"stop"):
		SelectionManager.stop()
	elif event.is_action_pressed(&"camera_focus"):
		_focus_camera()
	else:
		for index in range(1, 7):
			if event.is_action_pressed("select_unit_%d" % index):
				_select_by_index(index)
				break


func _draw() -> void:
	if _dragging and _drag_start.distance_to(_drag_end) >= DRAG_THRESHOLD:
		var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
		draw_rect(rect, box_fill)
		draw_rect(rect, box_border, false, 1.5)


func _commandos() -> Array[Commando]:
	var result: Array[Commando] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		if node is Commando:
			result.append(node as Commando)
	return result


func _finish_selection() -> void:
	var additive := Input.is_action_pressed(&"select_additive")
	var picked: Array[Commando] = []
	if _drag_start.distance_to(_drag_end) < DRAG_THRESHOLD:
		var hit := _raycast(_drag_end, MASK_COMMANDOS)
		if hit.has("collider") and hit["collider"] is Commando:
			picked.append(hit["collider"] as Commando)
	else:
		var camera := get_viewport().get_camera_3d()
		var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
		for unit in _commandos():
			var center := unit.global_position + Vector3.UP * 0.9
			if rect.has_point(camera.unproject_position(center)):
				picked.append(unit)
	if picked.is_empty() and additive:
		return
	SelectionManager.select(picked, additive)


func _select_by_index(index: int) -> void:
	for unit in _commandos():
		if unit.unit_index == index:
			SelectionManager.select([unit] as Array[Commando], Input.is_action_pressed(&"select_additive"))
			return


## Clic droit : attaque si un ennemi est visé, sinon déplacement.
func _order(screen_position: Vector2, run: bool) -> void:
	if SelectionManager.selected.is_empty():
		return
	var enemy_hit := _raycast(screen_position, MASK_ENEMIES)
	if enemy_hit.has("collider") and enemy_hit["collider"] is Enemy:
		var enemy := enemy_hit["collider"] as Enemy
		SelectionManager.order_attack(enemy, run)
		_spawn_marker(enemy.global_position, marker_attack_color)
		return
	var hit := _raycast(screen_position, MASK_GROUND)
	if hit.is_empty():
		return
	if hit["collider"] is Climbable:
		var climbable := hit["collider"] as Climbable
		SelectionManager.order_climb(climbable, run)
		_spawn_marker(climbable.get_top_position(), marker_run_color if run else marker_color)
		return
	var target: Vector3 = hit["position"]
	target.y = 0.0
	SelectionManager.order_move(target, run)
	_spawn_marker(target, marker_run_color if run else marker_color)


func _use_pending_action(screen_position: Vector2) -> void:
	var hit := _raycast(screen_position, MASK_ENEMIES)
	if hit.has("collider") and hit["collider"] is Enemy:
		var enemy := hit["collider"] as Enemy
		if pending_action == ACTION_THROW:
			if SelectionManager.order_throw(enemy):
				_spawn_marker(enemy.global_position, marker_melee_color)
		else:
			var kind := Commando.MeleeKind.KNIFE if pending_action == ACTION_KNIFE else Commando.MeleeKind.KNOCKOUT
			if SelectionManager.order_melee(enemy, kind):
				_spawn_marker(enemy.global_position, marker_melee_color)
	cancel_pending_action()


func _focus_camera() -> void:
	if SelectionManager.selected.is_empty():
		return
	var rig := get_viewport().get_camera_3d().get_parent() as CameraRig
	if rig:
		rig.focus_on(SelectionManager.selected[0].global_position)


func _raycast(screen_position: Vector2, mask: int) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


## Anneau éphémère indiquant la destination.
func _spawn_marker(at: Vector3, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.28
	mesh.outer_radius = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(marker)
	marker.global_position = at + Vector3.UP * 0.04
	var tween := marker.create_tween().set_parallel(true)
	tween.tween_property(marker, "scale", Vector3.ONE * 0.3, 0.6)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(marker.queue_free)
