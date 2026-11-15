class_name Minimap
extends Control
## Minicarte (touche M) : vue du dessus du niveau (`LevelPreview`), avec les
## opérateurs (jaunes une fois sélectionnés), le VIP, les ennemis (gris
## inconscients) et la zone vue par la caméra. Un clic y centre la caméra.

## Plus grand côté (pixels).
const SIZE := 200.0
const FRIEND := Color(0.4, 0.75, 1.0)
const SELECTED := Color(1.0, 0.85, 0.4)
const VIP := Color(1.0, 1.0, 1.0)
const ENEMY := Color(1.0, 0.3, 0.25)
const DOWN := Color(0.55, 0.55, 0.55)
## Intervalle entre deux tentatives de lire l'aperçu (pris à la fin du
## premier chargement).
const RETRY := 1.0

var level: Node3D
var area: Rect2 = Rect2(-30, -30, 60, 60)
var texture: Texture2D
var _retry_left: float = 0.0
var _key: String = ""


func setup(root: Node3D, key: String) -> void:
	level = root
	_key = key
	area = LevelPreview.bounds_of(root)
	var aspect := area.size.x / maxf(area.size.y, 0.01)
	custom_minimum_size = Vector2(SIZE, SIZE / aspect) if aspect >= 1.0 else Vector2(SIZE * aspect, SIZE)
	size = custom_minimum_size


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Clic : centrer la caméra"


func _process(delta: float) -> void:
	if level == null:
		return
	if texture == null:
		_retry_left -= delta
		if _retry_left <= 0.0:
			_retry_left = RETRY
			texture = LevelPreview.load_texture(_key)
	queue_redraw()


## Point de la minicarte → point du monde (au sol).
func to_world(point: Vector2) -> Vector3:
	var ratio := point / size
	return Vector3(area.position.x + ratio.x * area.size.x, 0.0, area.position.y + ratio.y * area.size.y)


## Point du monde → point de la minicarte.
func to_map(world: Vector3) -> Vector2:
	return Vector2((world.x - area.position.x) / area.size.x, (world.z - area.position.y) / area.size.y) * size


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var rig := level.find_child("CameraRig", true, false)
		if rig:
			rig.focus_on(to_world(click.position))
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.1, 0.1, 0.85))
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.9))
	if level == null:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead:
			_dot(enemy.global_position, DOWN if enemy.state == Enemy.State.STUNNED else ENEMY, 2.5)
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip and not vip.is_dead:
			_dot(vip.global_position, VIP, 3.0)
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead:
			_dot(unit.global_position, SELECTED if unit.is_selected else FRIEND, 3.5)
	_draw_view()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.55, 0.75, 0.9), false, 1.0)


func _dot(world: Vector3, color: Color, radius: float) -> void:
	var at := to_map(world)
	if Rect2(Vector2.ZERO, size).has_point(at):
		draw_circle(at, radius + 1.0, Color(0, 0, 0, 0.7))
		draw_circle(at, radius, color)


## Contour du sol vu par la caméra (coins de l'écran projetés au sol).
func _draw_view() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var corners: PackedVector2Array = []
	for corner: Vector2 in [Vector2.ZERO, Vector2(screen.x, 0), screen, Vector2(0, screen.y)]:
		var origin := camera.project_ray_origin(corner)
		var normal := camera.project_ray_normal(corner)
		if absf(normal.y) < 0.001:
			return
		var hit := origin + normal * (-origin.y / normal.y)
		corners.append(to_map(hit))
	corners.append(corners[0])
	draw_polyline(corners, Color(1, 1, 1, 0.8), 1.0)
