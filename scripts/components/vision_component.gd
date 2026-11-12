class_name VisionComponent
extends Node3D
## Cône de vision d'un ennemi : détection des commandos et affichage au sol.
##
## Le cône regarde vers -Z du parent. Deux zones : proche (détection
## immédiate) et lointaine (cibles debout uniquement). La vue est occultée
## par les murs (couche 2).

enum Zone { NONE, NEAR, FAR }

const MASK_OCCLUDERS := 0b10
const GROUND_OFFSET := 0.06

@export var config: VisionConfig
@export var calm_color := Color(0.25, 0.85, 0.35)
@export var suspicious_color := Color(1.0, 0.8, 0.15)
@export var alert_color := Color(1.0, 0.2, 0.15)
@export_range(0.0, 1.0) var near_alpha: float = 0.45
@export_range(0.0, 1.0) var far_alpha: float = 0.2

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = calm_color
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _physics_process(_delta: float) -> void:
	_rebuild_cone()


## Zone du cône dans laquelle `target` est visible, ou `Zone.NONE`.
## Avec `ignore_posture` (ennemi en alerte), la zone lointaine voit aussi
## les cibles accroupies ou rampées.
func check(target: Commando, ignore_posture: bool = false) -> Zone:
	var offset := to_local(target.global_position)
	offset.y = 0.0
	var posture := SoldierModel.Posture.STANDING if ignore_posture else target.posture
	var zone := zone_for(offset, posture, config)
	if zone == Zone.NONE:
		return Zone.NONE
	var eye := global_position + Vector3.UP * config.eye_height
	var aim := target.global_position + Vector3.UP * _target_height(target.posture)
	var query := PhysicsRayQueryParameters3D.create(eye, aim, MASK_OCCLUDERS)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return Zone.NONE
	return zone


## Logique pure : zone pour une position exprimée dans le repère du cône
## (sans tenir compte des obstacles).
static func zone_for(local_offset: Vector3, posture: SoldierModel.Posture, vision: VisionConfig) -> Zone:
	var planar := Vector2(local_offset.x, local_offset.z)
	var distance := planar.length()
	if distance > vision.far_range:
		return Zone.NONE
	if distance > 0.001:
		var angle := absf(atan2(planar.x, -planar.y))
		if angle > deg_to_rad(vision.fov_degrees) * 0.5:
			return Zone.NONE
	if distance <= vision.near_range:
		return Zone.NEAR
	return Zone.FAR if posture == SoldierModel.Posture.STANDING else Zone.NONE


## Couleur du cône selon l'état de l'ennemi.
func set_cone_color(color: Color) -> void:
	_material.albedo_color = color


func _target_height(posture: SoldierModel.Posture) -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return 0.8
		SoldierModel.Posture.PRONE:
			return 0.25
	return 1.4


func _rebuild_cone() -> void:
	_mesh.clear_surfaces()
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * config.cone_ray_height
	var half_fov := deg_to_rad(config.fov_degrees) * 0.5
	var directions: Array[Vector3] = []
	var reaches: Array[float] = []
	for i in config.segments + 1:
		var angle := -half_fov + 2.0 * half_fov * float(i) / float(config.segments)
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		var world_direction := global_basis * direction
		var query := PhysicsRayQueryParameters3D.create(origin, origin + world_direction * config.far_range, MASK_OCCLUDERS)
		var hit := space.intersect_ray(query)
		var reach := config.far_range
		if not hit.is_empty():
			reach = origin.distance_to(hit["position"])
		directions.append(direction)
		reaches.append(reach)

	var up := Vector3.UP * GROUND_OFFSET
	var near_color := Color(1.0, 1.0, 1.0, near_alpha)
	var far_color := Color(1.0, 1.0, 1.0, far_alpha)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in config.segments:
		var near_a := minf(reaches[i], config.near_range)
		var near_b := minf(reaches[i + 1], config.near_range)
		_mesh.surface_set_color(near_color)
		_mesh.surface_add_vertex(up)
		_mesh.surface_add_vertex(up + directions[i] * near_a)
		_mesh.surface_add_vertex(up + directions[i + 1] * near_b)
		if reaches[i] > config.near_range or reaches[i + 1] > config.near_range:
			var far_a := maxf(reaches[i], near_a)
			var far_b := maxf(reaches[i + 1], near_b)
			_mesh.surface_set_color(far_color)
			_mesh.surface_add_vertex(up + directions[i] * near_a)
			_mesh.surface_add_vertex(up + directions[i] * far_a)
			_mesh.surface_add_vertex(up + directions[i + 1] * far_b)
			_mesh.surface_add_vertex(up + directions[i] * near_a)
			_mesh.surface_add_vertex(up + directions[i + 1] * far_b)
			_mesh.surface_add_vertex(up + directions[i + 1] * near_b)
	_mesh.surface_end()
