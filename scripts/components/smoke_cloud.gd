class_name SmokeCloud
extends Node3D
## Nuage d'une grenade fumigène : enfle en quelques secondes, dure, puis se
## dissipe. Tant qu'il est épais, il coupe la vue des ennemis
## (`blocks_sight`) : un regard qui le traverse, ou qui en part, ne voit rien.
## Il gêne aussi la visée des opérateurs qui tirent au travers
## (`Commando.SMOKE_AIM_FACTOR`). Il dérive avec le vent de la carte
## (`LevelRoot.wind`), d'autant plus qu'il est formé.

const GROUP := &"smoke_clouds"
## Rayon (m) du nuage formé.
const RADIUS := 4.0
## Hauteur (m) du centre du nuage, et son aplatissement vertical.
const CENTER_HEIGHT := 1.3
const FLATTEN := 0.6
## Montée (s), durée totale (s), et dissipation finale (s).
const GROW_TIME := 2.0
const LIFETIME := 16.0
const FADE_TIME := 3.0
## En deçà de cette épaisseur (0 à 1), le nuage ne cache plus rien.
const OPAQUE_FROM := 0.35

var _time: float = 0.0
## Dérive (m/s) : le vent de la carte.
var drift := Vector3.ZERO
var _particles: CPUParticles3D
var _material: StandardMaterial3D


## Fait naître un nuage au point `at` (au sol).
static func spawn(parent: Node, at: Vector3) -> SmokeCloud:
	var cloud := SmokeCloud.new()
	parent.add_child(cloud)
	cloud.global_position = at
	return cloud


## Vrai si un nuage assez épais coupe le segment de `from` à `to`.
static func blocks_sight(tree: SceneTree, from: Vector3, to: Vector3) -> bool:
	for node in tree.get_nodes_in_group(GROUP):
		var cloud := node as SmokeCloud
		if cloud and cloud.density() >= OPAQUE_FROM and cloud.crosses(from, to):
			return true
	return false


## Épaisseur du nuage (0 à 1) : monte, se maintient, se dissipe.
func density() -> float:
	var grow := clampf(_time / GROW_TIME, 0.0, 1.0)
	var fade := clampf((LIFETIME - _time) / FADE_TIME, 0.0, 1.0)
	return minf(grow, fade)


## Rayon courant (m).
func radius() -> float:
	return RADIUS * (0.35 + 0.65 * clampf(_time / GROW_TIME, 0.0, 1.0))


## Vrai si le segment `from`–`to` passe dans le nuage (ellipsoïde aplati).
func crosses(from: Vector3, to: Vector3) -> bool:
	var center := global_position + Vector3.UP * CENTER_HEIGHT
	var squash := Vector3(1.0, 1.0 / FLATTEN, 1.0)
	var a := (from - center) * squash
	var b := (to - center) * squash
	var segment := b - a
	var t := 0.0
	if segment.length_squared() > 0.0001:
		t = clampf(-a.dot(segment) / segment.length_squared(), 0.0, 1.0)
	return (a + segment * t).length() <= radius()


## Vent de la carte en cours (`LevelRoot.wind`), nul hors d'un niveau.
static func wind_of(tree: SceneTree) -> Vector3:
	var level := tree.current_scene as LevelRoot if tree else null
	if level == null:
		return Vector3.ZERO
	return Vector3(level.wind.x, 0.0, level.wind.z)


func _ready() -> void:
	add_to_group(GROUP)
	drift = wind_of(get_tree())
	_particles = CPUParticles3D.new()
	_particles.amount = 90
	_particles.lifetime = 4.0
	_particles.preprocess = 0.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 0.6
	_particles.direction = Vector3.UP
	_particles.spread = 90.0
	_particles.initial_velocity_min = 0.6
	_particles.initial_velocity_max = 2.0
	# Bouffées poussées par le vent (en plus de la dérive du nuage).
	_particles.gravity = Vector3(drift.x * 0.4, 0.08, drift.z * 0.4)
	_particles.damping_min = 0.6
	_particles.damping_max = 1.0
	_particles.scale_amount_min = 1.6
	_particles.scale_amount_max = 2.6
	# Chaque bouffée naît petite, enfle, puis s'éteint en rétrécissant (pas de
	# fondu par couleur de particule : sous Godot 4.7, les couleurs des
	# premières bouffées sortaient noires, une tache sombre au cœur du nuage).
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(0.2, 0.85))
	grow.add_point(Vector2(0.7, 1.0))
	grow.add_point(Vector2(1.0, 0.0))
	_particles.scale_amount_curve = grow
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.albedo_texture = _puff_texture()
	_material.albedo_color = Color(0.82, 0.83, 0.8, 0.55)
	puff.material = _material
	_particles.mesh = puff
	_particles.position.y = 0.5
	# Les bouffées, transparentes, ne projettent pas d'ombre.
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	Sfx.play_at(&"whoosh", global_position, -4.0)
	EventBus.noise_emitted.emit(global_position, 4.0, &"smoke")


func _physics_process(delta: float) -> void:
	_time += delta
	global_position += drift * delta * clampf(_time / GROW_TIME, 0.0, 1.0)
	var r := radius()
	_particles.emission_sphere_radius = r * 0.55
	_particles.position.y = 0.4 + 0.4 * clampf(_time / GROW_TIME, 0.0, 1.0)
	_material.albedo_color.a = 0.55 * density()
	if _time >= LIFETIME - _particles.lifetime and _particles.emitting:
		_particles.emitting = false
	if _time >= LIFETIME:
		queue_free()


## Tache ronde aux bords doux, pour chaque bouffée.
static func _puff_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture
