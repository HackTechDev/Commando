class_name CameraRig
extends Node3D
## Rig de caméra isométrique : pivot au sol + Camera3D orthographique.
##
## Déplacement (touches, bord d'écran, glisser molette), zoom sur `size`,
## rotation libre et continue tant que la touche est maintenue, limites de
## déplacement.

@export var pitch_degrees: float = -35.264
@export var distance: float = 60.0
## Vitesse de déplacement, proportionnelle au zoom (en « tailles d'écran » par seconde).
@export var pan_speed: float = 1.1
@export var min_size: float = 5.0
@export var max_size: float = 40.0
@export var start_size: float = 18.0
@export var zoom_step: float = 1.15
@export var smoothing: float = 10.0
## Vitesse de rotation quand la touche est maintenue, en degrés par seconde.
@export var rotation_speed: float = 110.0
## Lissage de la rotation (plus petit = plus doux, avec plus d'inertie).
@export var rotation_smoothing: float = 8.0
@export var edge_scroll_enabled: bool = true
@export var edge_margin: float = 10.0
## Limites de déplacement du pivot (seuls X et Z sont utilisés).
@export var bounds: AABB = AABB(Vector3(-28.0, 0.0, -28.0), Vector3(56.0, 0.0, 56.0))

var _target_position: Vector3
var _target_yaw: float = deg_to_rad(45.0)
var _target_size: float
## Écouteur audio au-dessus du centre de la vue, plus haut quand on dézoome :
## les sons dépendent de ce qu'on regarde, pas de la position de la caméra
## orthographique (très éloignée).
var _listener: AudioListener3D

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_target_position = position
	_target_size = start_size
	rotation.y = _target_yaw
	_camera.rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)
	_camera.position = _camera.basis.z * distance
	_camera.size = _target_size
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()
	_update_listener()


func _process(delta: float) -> void:
	var input := Input.get_vector(&"camera_left", &"camera_right", &"camera_forward", &"camera_back")
	input += _edge_scroll()
	if input != Vector2.ZERO:
		var move := basis.x * input.x + basis.z * input.y
		_target_position += move * pan_speed * _camera.size * delta
	_clamp_target()
	var turn := Input.get_axis(&"camera_rotate_left", &"camera_rotate_right")
	_target_yaw += turn * deg_to_rad(rotation_speed) * delta

	var blend := 1.0 - exp(-smoothing * delta)
	position = position.lerp(_target_position, blend)
	_update_listener()
	rotation.y = lerpf(rotation.y, _target_yaw, 1.0 - exp(-rotation_smoothing * delta))
	_camera.size = lerpf(_camera.size, _target_size, blend)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_zoom_in"):
		set_zoom(_target_size / zoom_step)
	elif event.is_action_pressed(&"camera_zoom_out"):
		set_zoom(_target_size * zoom_step)
	elif event is InputEventMouseMotion and Input.is_action_pressed(&"camera_drag"):
		var motion := event as InputEventMouseMotion
		var units_per_pixel := _camera.size / float(get_viewport().get_visible_rect().size.y)
		var depth_factor := 1.0 / sin(deg_to_rad(absf(pitch_degrees)))
		_target_position += (-basis.x * motion.relative.x - basis.z * motion.relative.y * depth_factor) * units_per_pixel
		_clamp_target()


## Fixe le zoom (taille orthographique), borné.
func set_zoom(size: float) -> void:
	_target_size = clampf(size, min_size, max_size)


## Centre la caméra sur un point du monde.
func focus_on(world_position: Vector3) -> void:
	_target_position = Vector3(world_position.x, 0.0, world_position.z)
	_clamp_target()


func _edge_scroll() -> Vector2:
	if not edge_scroll_enabled or not get_window().has_focus():
		return Vector2.ZERO
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	var mouse := viewport.get_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO
	var result := Vector2.ZERO
	if mouse.x < edge_margin:
		result.x = -1.0
	elif mouse.x > size.x - edge_margin:
		result.x = 1.0
	if mouse.y < edge_margin:
		result.y = -1.0
	elif mouse.y > size.y - edge_margin:
		result.y = 1.0
	return result


func _clamp_target() -> void:
	_target_position.x = clampf(_target_position.x, bounds.position.x, bounds.end.x)
	_target_position.z = clampf(_target_position.z, bounds.position.z, bounds.end.z)


func _update_listener() -> void:
	if _listener:
		_listener.position = Vector3(0.0, 4.0 + _camera.size * 0.5, 0.0)
