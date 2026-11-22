class_name WeatherParticles
extends GPUParticles3D
## Précipitations (neige, pluie) : particules émises dans un volume centré
## sur le point du sol que vise la caméra, qu'il suit. Les particules
## restent dans le monde (`local_coords` faux) quand le volume se déplace :
## le coût est fixe, quelle que soit la taille de la carte. Effet visuel
## seul, sans effet sur la vue ni l'ouïe des gardes.

## Demi-côté (m) du volume, et hauteur d'où tombent les particules.
const EXTENT := 34.0
const HEIGHT := 16.0


## Réglages communs ; les sous-classes ajoutent `process_material` et
## `draw_pass_1`.
func _setup(count: int, life: float) -> void:
	amount = count
	lifetime = life
	preprocess = life
	local_coords = false
	visibility_aabb = AABB(Vector3(-EXTENT - 10.0, -HEIGHT - 4.0, -EXTENT - 10.0), Vector3(2.0 * EXTENT + 20.0, HEIGHT + 8.0, 2.0 * EXTENT + 20.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = true
	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


## Au-dessus du point du sol que vise la caméra.
func _follow_camera() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var forward := -camera.global_basis.z
	var origin := camera.global_position
	var focus := origin
	if absf(forward.y) > 0.01:
		focus = origin + forward * (-origin.y / forward.y)
	global_position = Vector3(focus.x, HEIGHT, focus.z)


## Boîte d'émission au sommet du volume, de demi-côté `EXTENT`.
static func falling_motion(speed_min: float, speed_max: float, gravity_y: float, wind: Vector3) -> ParticleProcessMaterial:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(EXTENT, 1.0, EXTENT)
	motion.direction = Vector3(0, -1, 0)
	motion.initial_velocity_min = speed_min
	motion.initial_velocity_max = speed_max
	motion.gravity = Vector3(wind.x, gravity_y, wind.z)
	return motion
