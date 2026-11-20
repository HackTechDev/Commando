class_name Tiltrotor
extends StaticBody3D
## Convertible posé au sol (`TiltrotorModel`) : obstacle (marche, vue, balles)
## et cible de sabotage. Une explosion proche de la coque (charge, grenade)
## le détruit : le réservoir saute à son tour (souffle autour de l'appareil),
## l'épave brûle, l'objectif `objective_id` est rempli et, si `ends_mission`,
## la mission est réussie peu après.
##
## Repère : celui du modèle (avant vers -Z, posé au sol).

const GROUP := &"vehicles"
const LAYER_OCCLUDERS := 0b10
## Une explosion détruit l'appareil si la coque est à moins de cette part de
## son rayon d'effet.
const BLAST_SHARE := 0.6
## Explosion du réservoir : rayon, dégâts au centre, bruit.
const FUEL_RADIUS := 7.0
const FUEL_DAMAGE := 140.0
const FUEL_NOISE := 45.0
## Délai (s) entre la destruction et la fin de mission.
const END_DELAY := 3.0

@export var livery: TiltrotorModel.Livery = TiltrotorModel.Livery.OLIVE
@export var tail_number: String = "07"
@export_range(2, 6) var blade_count: int = 3
## Tours par seconde des rotors (0 : arrêtés).
@export var rotor_speed: float = 0.0
@export var objective_id: StringName = &"aircraft_destroyed"
@export var ends_mission: bool = true

var is_destroyed: bool = false
var model: TiltrotorModel
## Boîtes de la coque (repère local) : fuselage, ailes, nacelles.
var hull_boxes: Array[AABB] = []
var _fire: Node3D


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = LAYER_OCCLUDERS
	collision_mask = 0
	model = TiltrotorModel.new()
	model.name = "Model"
	model.livery = livery
	model.tail_number = tail_number
	model.blade_count = blade_count
	model.rotor_speed = rotor_speed
	add_child(model)
	# Fuselage jusqu'au sol (on ne passe pas dessous), ailes, nacelles
	# jusqu'au sol aussi.
	hull_boxes.append(AABB(Vector3(-2.1, 0.0, -8.3), Vector3(4.2, 4.0, 16.3)))
	for z in TiltrotorModel.WINGS:
		var span := absf(TiltrotorModel.NACELLES[0 if z < 0.0 else 2].x)
		hull_boxes.append(AABB(Vector3(-span, TiltrotorModel.WING_HEIGHT - 0.3, z - 1.2), Vector3(span * 2.0, 0.6, 2.4)))
	for at in TiltrotorModel.NACELLES:
		var half := TiltrotorModel.NACELLE_HALF
		hull_boxes.append(AABB(Vector3(at.x - half.x, 0.0, at.y - half.y), Vector3(half.x * 2.0, TiltrotorModel.NACELLE_TOP, half.y * 2.0)))
	for box in hull_boxes:
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = box.size
		shape.shape = cube
		shape.position = box.get_center()
		add_child(shape)


## Distance de `point` (monde) à la coque.
func distance_to_hull(point: Vector3) -> float:
	var local := to_local(point)
	var best := INF
	for box in hull_boxes:
		var nearest := local.clamp(box.position, box.end)
		best = minf(best, local.distance_to(nearest))
	return best


## Explosion de rayon `radius` en `at` (`Explosion`) : détruit l'appareil si
## elle est assez près de la coque.
func blast(at: Vector3, radius: float) -> void:
	if not is_destroyed and distance_to_hull(at) <= radius * BLAST_SHARE:
		destroy()


## Détruit l'appareil : réservoir qui saute, épave en feu, objectif rempli.
func destroy() -> void:
	if is_destroyed:
		return
	_set_wrecked()
	Explosion.detonate(get_parent(), global_position + Vector3.UP * 1.5, FUEL_RADIUS, FUEL_DAMAGE, FUEL_NOISE)
	EventBus.objective_completed.emit(objective_id)
	if ends_mission:
		get_tree().create_timer(END_DELAY, false).timeout.connect(func() -> void:
			EventBus.mission_ended.emit(true, "RÉUSSITE — appareil détruit"))


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"destroyed": is_destroyed}


func load_state(data: Dictionary) -> void:
	if data.get("destroyed", false) and not is_destroyed:
		_set_wrecked()


func _set_wrecked() -> void:
	is_destroyed = true
	model.set_wrecked()
	_fire = _make_fire()
	add_child(_fire)


## Flammes et colonne de fumée sur l'épave.
func _make_fire() -> Node3D:
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position = Vector3(0.0, 3.0, 0.5)
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 48
	flames.lifetime = 0.9
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(1.2, 0.3, 3.5)
	flames.direction = Vector3.UP
	flames.spread = 15.0
	flames.gravity = Vector3(0, 2.5, 0)
	flames.initial_velocity_min = 1.0
	flames.initial_velocity_max = 2.5
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.35
	flame_mesh.height = 0.7
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.vertex_color_use_as_albedo = true
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mesh.material = flame_material
	flames.mesh = flame_mesh
	var flame_colors := Gradient.new()
	flame_colors.set_color(0, Color(1.0, 0.55, 0.12, 0.95))
	flame_colors.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flames.color_ramp = flame_colors
	fire.add_child(flames)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 40
	smoke.lifetime = 5.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.2
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.4, 1.2, 0)
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.2
	smoke.position.y = 1.0
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.6
	smoke_mesh.height = 1.2
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 4
	var smoke_material := flame_material.duplicate() as StandardMaterial3D
	smoke_mesh.material = smoke_material
	smoke.mesh = smoke_mesh
	var smoke_colors := Gradient.new()
	smoke_colors.set_color(0, Color(0.12, 0.11, 0.1, 0.7))
	smoke_colors.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	smoke.color_ramp = smoke_colors
	fire.add_child(smoke)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 3.0
	light.omni_range = 9.0
	fire.add_child(light)
	return fire
