@tool
class_name Snowfall
extends WeatherParticles
## Chute de neige (cartes polaires) : flocons qui tombent en biais en
## tourbillonnant.

## Nombre de flocons.
@export var flakes: int = 2600:
	set(value):
		flakes = value
		_reconfigure()
## Vue lointaine des gardes (part qui reste) et ouïe des bruits discrets :
## la neige qui tombe cache et étouffe.
@export_range(0.2, 1.0) var sight_factor: float = 0.75
@export_range(0.2, 1.0) var hearing_factor: float = 0.85
## Traces de pas des opérateurs dans la neige, que les gardes suivent
## (`SnowTracks`).
@export var tracks: bool = true
## Vent (m/s) : dérive des flocons.
@export var wind := Vector3(0.8, 0.0, 0.35):
	set(value):
		wind = value
		_reconfigure()


func _start_game() -> void:
	if tracks:
		var prints := SnowTracks.new()
		prints.name = "Tracks"
		add_child(prints, false, Node.INTERNAL_MODE_BACK)


func sight() -> float:
	return sight_factor


func hearing() -> float:
	return hearing_factor


func _configure(particles: GPUParticles3D) -> void:
	var motion := falling_motion(1.6, 2.6, -0.6, wind)
	motion.spread = 12.0
	motion.scale_min = 0.6
	motion.scale_max = 1.4
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.6
	motion.turbulence_noise_scale = 3.0
	particles.process_material = motion
	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.albedo_color = Color(1, 1, 1, 0.9)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.material = look
	particles.draw_pass_1 = flake
	_setup(particles, flakes, 7.0)
