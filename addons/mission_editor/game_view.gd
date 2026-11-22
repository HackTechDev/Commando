@tool
extends Window
## Fenêtre « Vue du jeu » de l'éditeur de mission : la scène ouverte vue par
## la caméra du jeu, réglée d'après le `CameraRig` de la carte (angle,
## distance, zoom de départ et ses bornes, limites de déplacement). Le zoom
## fixe la hauteur vue, comme en jeu ; la largeur suit celle de la fenêtre
## (16:9 en jeu, `project.godot`). Glisser (clic gauche ou milieu) déplace la
## vue, dans les limites de la caméra ; la molette zoome ; les boutons
## tournent de 45° et reviennent au départ. Les repères de l'éditeur
## n'y sont pas, la carte de couverture et les silhouettes de l'animation
## si.

## Pas de rotation des boutons (degrés).
const TURN_STEP := 45.0

var _viewport: SubViewport
var _camera: Camera3D
var _zoom_label: Label
## Réglages lus sur le `CameraRig`.
var _rig: Node3D
var _pivot := Vector3.ZERO
var _yaw: float = 45.0
var _size: float = 18.0
var _dragging: bool = false


func _init() -> void:
	title = "Vue du jeu"
	size = Vector2i(980, 600)
	min_size = Vector2i(480, 320)
	wrap_controls = true
	transient = true
	exclusive = false
	visible = false
	close_requested.connect(hide)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	for spec: Array in [["⟲ 45°", -TURN_STEP], ["⟳ 45°", TURN_STEP]]:
		var turn := Button.new()
		turn.text = spec[0]
		turn.tooltip_text = "Tourner la vue (en jeu : rotation de la caméra)."
		var step: float = spec[1]
		turn.pressed.connect(func() -> void: rotate_view(step))
		bar.add_child(turn)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.tooltip_text = "Dézoomer (molette)."
	zoom_out.pressed.connect(func() -> void: zoom_view(1))
	bar.add_child(zoom_out)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.tooltip_text = "Zoomer (molette)."
	zoom_in.pressed.connect(func() -> void: zoom_view(-1))
	bar.add_child(zoom_in)
	var start := Button.new()
	start.text = "Départ"
	start.tooltip_text = "Revenir à la vue du début de la mission (place du CameraRig, zoom de départ)."
	start.pressed.connect(reset_view)
	bar.add_child(start)
	_zoom_label = Label.new()
	bar.add_child(_zoom_label)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_view_input)
	box.add_child(container)
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.5
	_camera.far = 200.0
	_camera.current = true
	_viewport.add_child(_camera)


## Montre la scène `root` (une mission) depuis le départ de sa caméra.
func show_scene(root: Node) -> void:
	_rig = root.get_node_or_null(^"CameraRig") as Node3D if root else null
	if root is Node3D:
		_viewport.world_3d = (root as Node3D).get_world_3d()
	reset_view()


func reset_view() -> void:
	_pivot = _rig.global_position if _rig else Vector3.ZERO
	_pivot.y = 0.0
	_yaw = 45.0
	_size = _rig.get("start_size") if _rig else 18.0
	_apply()


func rotate_view(degrees: float) -> void:
	_yaw = fposmod(_yaw + degrees, 360.0)
	_apply()


## Zoom d'un cran (`zoom_step` du CameraRig), dans ses bornes.
func zoom_view(direction: int) -> void:
	var step: float = _rig.get("zoom_step") if _rig else 1.15
	_size = clampf(_size * pow(step, direction), _setting("min_size", 5.0), _setting("max_size", 40.0))
	_apply()


## Déplace le centre de la vue de `delta` (m), dans les limites de la caméra.
func pan_view(delta: Vector3) -> void:
	_pivot += delta
	var bounds: AABB = _rig.get("bounds") if _rig else AABB()
	if bounds.size != Vector3.ZERO:
		_pivot.x = clampf(_pivot.x, bounds.position.x, bounds.end.x)
		_pivot.z = clampf(_pivot.z, bounds.position.z, bounds.end.z)
	_apply()


func _setting(key: String, fallback: float) -> float:
	return _rig.get(key) if _rig and _rig.get(key) != null else fallback


## Caméra placée comme `CameraRig._ready` : pivot au sol tourné de `_yaw`,
## caméra inclinée de `pitch_degrees` à `distance`.
func _apply() -> void:
	var pivot := Transform3D(Basis(Vector3.UP, deg_to_rad(_yaw)), _pivot)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(_setting("pitch_degrees", -35.264)))
	_camera.global_transform = pivot * Transform3D(tilt, tilt.z * _setting("distance", 60.0))
	_camera.size = _size
	_zoom_label.text = "  zoom %.1f (%.0f à %.0f), cap %d°, centre (%.0f, %.0f)" % [_size, _setting("min_size", 5.0), _setting("max_size", 40.0), int(_yaw), _pivot.x, _pivot.z]


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_view(-1)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_view(1)
	elif event is InputEventMouseMotion and _dragging:
		# Un pixel vaut `size / hauteur` m à l'écran ; le sol est vu en
		# biais : la profondeur est étirée de 1 / sin(inclinaison).
		var motion := (event as InputEventMouseMotion).relative
		var per_pixel := _size / maxf(_viewport.size.y, 1.0)
		var right := _camera.global_basis.x
		var ahead := Vector3(-_camera.global_basis.z.x, 0.0, -_camera.global_basis.z.z).normalized()
		var stretch := 1.0 / maxf(absf(sin(deg_to_rad(_setting("pitch_degrees", -35.264)))), 0.1)
		pan_view((-right * motion.x + ahead * motion.y * stretch) * per_pixel)
