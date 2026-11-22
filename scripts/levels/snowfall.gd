class_name Snowfall
extends GPUParticles3D
## Chute de neige (cartes polaires) : flocons qui tombent en biais, dans un
## volume centré sur ce que regarde la caméra (il la suit). Les flocons
## restent dans le monde (`local_coords` faux) quand le volume se déplace.

## Demi-côté (m) du volume de chute, et hauteur d'où tombent les flocons.
const EXTENT := 34.0
const HEIGHT := 16.0

## Nombre de flocons.
@export var flakes: int = 2600
## Vent (m/s) : dérive des flocons.
@export var wind := Vector3(0.8, 0.0, 0.35)


func _ready() -> void:
	name = "Snowfall"
	amount = flakes
	lifetime = 7.0
	preprocess = 7.0
	local_coords = false
	visibility_aabb = AABB(Vector3(-EXTENT - 10.0, -HEIGHT - 4.0, -EXTENT - 10.0), Vector3(2.0 * EXTENT + 20.0, HEIGHT + 8.0, 2.0 * EXTENT + 20.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(EXTENT, 1.0, EXTENT)
	motion.direction = Vector3(0, -1, 0)
	motion.spread = 12.0
	motion.initial_velocity_min = 1.6
	motion.initial_velocity_max = 2.6
	motion.gravity = Vector3(wind.x, -0.6, wind.z)
	motion.scale_min = 0.6
	motion.scale_max = 1.4
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.6
	motion.turbulence_noise_scale = 3.0
	process_material = motion
	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.albedo_color = Color(1, 1, 1, 0.9)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.material = look
	draw_pass_1 = flake
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
