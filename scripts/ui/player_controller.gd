class_name PlayerController
extends Control
## Entrées du joueur : sélection (clic, rectangle, touches), ordres de
## déplacement, d'attaque et postures. Dessine aussi le rectangle de sélection.
##
## Actions ciblées (couteau, assommer, lancer de couteau, caisse) : la touche
## ou le bouton arme l'action, puis un clic gauche sur un ennemi (ou une
## caisse) la confie à l'opérateur sélectionné le plus proche. Un clic droit,
## ou un clic ailleurs que sur une cible valable, l'annule.
##
## Clic du milieu (sans glisser, sinon c'est la caméra) sur un VIP : son menu
## circulaire d'ordres (« Suivre l'opérateur », « Attendre ici »).
##
## Le curseur change selon ce qu'il survole (`GameCursor`) : ennemi à
## abattre, cible de l'action armée, caisse ou corniche où grimper, VIP,
## endroit inaccessible.

signal pending_action_changed(action: StringName)

const ACTION_NONE := &""
const ACTION_KNIFE := &"knife"
const ACTION_KNOCKOUT := &"knockout"
const ACTION_THROW := &"throw"
const ACTION_CRATE := &"crate"
## Grenade : puis clic gauche au sol (ou sur un ennemi).
const ACTION_GRENADE := &"grenade"

const DRAG_THRESHOLD := 6.0
const RAY_LENGTH := 500.0
const MASK_GROUND := 0b011
const MASK_COMMANDOS := 0b100
## Ennemis actifs (couche 4) et assommés (couche 5).
const MASK_ENEMIES := 0b11000
## Intervalle (s) entre deux mises à jour du curseur.
const CURSOR_INTERVAL := 0.08
## Écart toléré entre un point visé et le maillage de navigation pour le
## dire accessible (le maillage flotte jusqu'à 0,5 m au-dessus du sol).
const REACH_TOLERANCE := 0.6
const REACH_HEIGHT := 1.0

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
## Clic du milieu en cours (position de l'appui), pour le distinguer d'un
## glissé de caméra.
var _middle_start: Vector2 = Vector2.INF
## Menu circulaire des ordres au VIP, et le VIP concerné.
var _radial: RadialMenu
var _menu_vip: Vip
var _cursor_left: float = 0.0


func _ready() -> void:
	_radial = RadialMenu.new()
	_radial.name = "RadialMenu"
	add_child(_radial)
	_radial.chosen.connect(_on_vip_order)
	_radial.closed.connect(func() -> void: _menu_vip = null)
	SelectionManager.selection_changed.connect(func(units: Array[Commando]) -> void:
		if units.is_empty():
			cancel_pending_action()
		else:
			Sfx.play_ui(&"select"))


## Arme l'action ciblée `action`, ou la désarme si elle l'était déjà.
func toggle_pending_action(action: StringName) -> void:
	if action == pending_action or SelectionManager.selected.is_empty():
		cancel_pending_action()
		return
	pending_action = action
	Sfx.play_ui(&"arm")
	_cursor_left = 0.0
	pending_action_changed.emit(pending_action)


## Désarme l'action ciblée en cours.
func cancel_pending_action() -> void:
	if pending_action == ACTION_NONE:
		return
	pending_action = ACTION_NONE
	_cursor_left = 0.0
	pending_action_changed.emit(pending_action)


func _process(delta: float) -> void:
	_cursor_left -= delta
	if _cursor_left > 0.0:
		return
	_cursor_left = CURSOR_INTERVAL
	var viewport := get_viewport()
	# Au-dessus de l'interface (boutons, portraits) : curseur normal.
	if viewport.gui_get_hovered_control() != null:
		GameCursor.apply(GameCursor.Kind.DEFAULT)
		return
	GameCursor.apply(cursor_kind_at(viewport.get_mouse_position()))


func _exit_tree() -> void:
	GameCursor.apply(GameCursor.Kind.DEFAULT)


## Curseur à afficher au point `screen_position` de l'écran.
func cursor_kind_at(screen_position: Vector2) -> GameCursor.Kind:
	if _radial.is_open() or get_viewport().get_camera_3d() == null:
		return GameCursor.Kind.DEFAULT
	if pending_action != ACTION_NONE:
		return _pending_cursor(screen_position)
	var unit_hit := _raycast(screen_position, MASK_COMMANDOS)
	var vip := unit_hit.get("collider") as Vip
	if vip and vip.takes_orders():
		return GameCursor.Kind.ORDERS
	if SelectionManager.selected.is_empty():
		return GameCursor.Kind.DEFAULT
	var enemy := _raycast(screen_position, MASK_ENEMIES).get("collider") as Enemy
	if enemy and not enemy.is_dead:
		return GameCursor.Kind.ATTACK
	var hit := _raycast(screen_position, MASK_GROUND)
	if hit.is_empty():
		return GameCursor.Kind.DEFAULT
	if _climbable_at(hit):
		return GameCursor.Kind.CLIMB
	return GameCursor.Kind.DEFAULT if _is_reachable(hit["position"]) else GameCursor.Kind.FORBIDDEN


## Curseur d'une action armée : sa cible, ou interdit hors d'une cible valable.
func _pending_cursor(screen_position: Vector2) -> GameCursor.Kind:
	match pending_action:
		ACTION_GRENADE:
			return GameCursor.Kind.GRENADE
		ACTION_CRATE:
			var crate := _raycast(screen_position, MASK_GROUND).get("collider") as Climbable
			return GameCursor.Kind.CRATE if crate and crate.movable else GameCursor.Kind.FORBIDDEN
	var enemy := _raycast(screen_position, MASK_ENEMIES).get("collider") as Enemy
	if enemy == null or enemy.is_dead:
		return GameCursor.Kind.FORBIDDEN
	return GameCursor.Kind.THROW if pending_action == ACTION_THROW else GameCursor.Kind.MELEE


## Caisse ou corniche où l'on peut se tenir sous le point `hit` (sinon null).
func _climbable_at(hit: Dictionary) -> Climbable:
	var climbable := hit["collider"] as Climbable
	if climbable and not climbable.can_stand_on:
		climbable = null
	if climbable == null and (hit["normal"] as Vector3).y > 0.7:
		climbable = Climbable.find_at(get_tree(), hit["position"])
	return climbable


## Vrai si `point` est sur le maillage de navigation (ou tout près).
func _is_reachable(point: Vector3) -> bool:
	var map := get_viewport().get_camera_3d().get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() < REACH_TOLERANCE \
			and absf(closest.y - point.y) < REACH_HEIGHT


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
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		var middle := event as InputEventMouseButton
		if middle.pressed:
			_middle_start = middle.position
		elif _middle_start != Vector2.INF:
			if _middle_start.distance_to(middle.position) < DRAG_THRESHOLD:
				if open_vip_menu(middle.position):
					get_viewport().set_input_as_handled()
			_middle_start = Vector2.INF
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
	elif event.is_action_pressed(&"action_crate"):
		# P lâche la caisse tenue ; sinon, arme l'action.
		if not SelectionManager.release_crates():
			toggle_pending_action(ACTION_CRATE)
	elif event.is_action_pressed(&"action_throw"):
		toggle_pending_action(ACTION_THROW)
	elif event.is_action_pressed(&"action_grenade"):
		toggle_pending_action(ACTION_GRENADE)
	elif event.is_action_pressed(&"action_plant"):
		_feedback(SelectionManager.plant_explosive())
	elif event.is_action_pressed(&"action_detonate"):
		_feedback(SelectionManager.detonate_explosives() > 0)
	elif event.is_action_pressed(&"action_medkit"):
		_feedback(SelectionManager.use_medkit())
	elif event.is_action_pressed(&"action_shield"):
		_feedback(SelectionManager.toggle_shield())
	elif event.is_action_pressed(&"switch_weapon"):
		SelectionManager.switch_weapons()
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
	# Caisse, ou dessus d'un mur où l'on peut se tenir (corniche). Un bidon
	# ne se gravit pas : on va à côté.
	var climbable := _climbable_at(hit)
	if climbable:
		SelectionManager.order_climb(climbable, run)
		_spawn_marker(climbable.get_top_position(), marker_run_color if run else marker_color)
		return
	var target: Vector3 = hit["position"]
	target.y = 0.0
	SelectionManager.order_move(target, run)
	_spawn_marker(target, marker_run_color if run else marker_color)


## Ouvre le menu d'ordres du VIP sous `screen_position`. Renvoie faux s'il
## n'y en a pas (ou s'il ne peut plus recevoir d'ordres).
func open_vip_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_COMMANDOS)
	var vip := hit.get("collider") as Vip
	if vip == null or not vip.takes_orders():
		return false
	cancel_pending_action()
	_menu_vip = vip
	var guide := _guide_for(vip)
	var options: Array[Dictionary] = [
		{"id": &"follow", "label": "Suivre l'opérateur",
			"detail": guide.display_name if guide else "Sélectionnez un opérateur",
			"enabled": guide != null},
		{"id": &"stay", "label": "Attendre ici", "enabled": vip.leader != null},
	]
	_radial.open(screen_position, options, vip.display_name)
	Sfx.play_ui(&"select")
	return true


## Menu d'ordres du VIP (pour l'interface et les tests).
func radial_menu() -> RadialMenu:
	return _radial


## Opérateur que suivra le VIP : le sélectionné, ou le sélectionné le plus
## proche de lui s'il y en a plusieurs.
func _guide_for(vip: Vip) -> Commando:
	var best: Commando = null
	for unit: Commando in SelectionManager.selected:
		if not is_instance_valid(unit) or unit.is_dead:
			continue
		if best == null or unit.global_position.distance_squared_to(vip.global_position) \
				< best.global_position.distance_squared_to(vip.global_position):
			best = unit
	return best


func _on_vip_order(id: StringName) -> void:
	var vip := _menu_vip
	_menu_vip = null
	if vip == null or not is_instance_valid(vip):
		return
	var accepted := false
	match id:
		&"follow":
			accepted = vip.follow(_guide_for(vip))
		&"stay":
			accepted = vip.stay()
	Sfx.play_ui(&"order" if accepted else &"denied")
	if accepted:
		_spawn_marker(vip.global_position, marker_color)


## Bip d'ordre reçu, ou de refus.
func _feedback(accepted: bool) -> void:
	if SelectionManager.selected.is_empty():
		return
	Sfx.play_ui(&"order" if accepted else &"denied")


func _use_pending_action(screen_position: Vector2) -> void:
	if pending_action == ACTION_GRENADE:
		var ground := _raycast(screen_position, MASK_GROUND)
		if not ground.is_empty():
			var point: Vector3 = ground["position"]
			if SelectionManager.order_grenade(point):
				_spawn_marker(point, marker_attack_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_CRATE:
		var crate_hit := _raycast(screen_position, MASK_GROUND)
		if crate_hit.has("collider") and crate_hit["collider"] is Climbable:
			var crate := crate_hit["collider"] as Climbable
			if SelectionManager.order_crate(crate, crate_hit["position"]):
				_spawn_marker(crate.global_position, marker_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	var hit := _raycast(screen_position, MASK_ENEMIES)
	if hit.has("collider") and hit["collider"] is Enemy:
		var enemy := hit["collider"] as Enemy
		if pending_action == ACTION_THROW:
			if SelectionManager.order_throw(enemy):
				_spawn_marker(enemy.global_position, marker_melee_color)
			else:
				Sfx.play_ui(&"denied")
		else:
			var kind := Commando.MeleeKind.KNIFE if pending_action == ACTION_KNIFE else Commando.MeleeKind.KNOCKOUT
			if SelectionManager.order_melee(enemy, kind):
				_spawn_marker(enemy.global_position, marker_melee_color)
			else:
				Sfx.play_ui(&"denied")
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
	var space := camera.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	# Un toit effacé (opérateur à l'intérieur) laisse passer les clics vers
	# l'intérieur du bâtiment.
	while not hit.is_empty() and Roof.is_revealed_body(hit["collider"]):
		query.exclude += [hit["rid"]]
		hit = space.intersect_ray(query)
	return hit


## Anneau éphémère indiquant la destination, et bip d'ordre reçu.
func _spawn_marker(at: Vector3, color: Color) -> void:
	Sfx.play_ui(&"order")
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
