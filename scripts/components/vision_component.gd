class_name VisionComponent
extends Node3D
## Cône de vision d'un ennemi : détection des opérateurs et des VIP, et affichage au sol.
##
## Le cône regarde vers -Z du parent. Deux zones : proche (détection
## immédiate) et lointaine (cibles debout uniquement). La vue est occultée
## par les murs (couche 2).
##
## Le cône affiché coûte un rayon par segment : il n'est recalculé que si
## l'ennemi a bougé ou tourné, si un obstacle a été déplacé
## (`EventBus.navigation_obstacle_moved`), ou au plus tard toutes les
## `REFRESH_INTERVAL` secondes (portes, objets détruits). Hors de l'écran, il
## attend d'y revenir ; caméra très dézoomée, il a moins de segments.

enum Zone { NONE, NEAR, FAR }

const MASK_OCCLUDERS := 0b10
const GROUND_OFFSET := 0.06
## Déplacement (m) et rotation (rad) qui obligent à recalculer le cône.
const MOVE_TOLERANCE := 0.03
const TURN_TOLERANCE := 0.01
## Recalcul de sécurité, en secondes.
const REFRESH_INTERVAL := 1.0
## Taille de vue (caméra orthographique, m) au-delà de laquelle le nombre de
## segments diminue, et minimum de segments.
const DETAIL_VIEW_SIZE := 22.0
const MIN_SEGMENTS := 16

@export var config: VisionConfig
@export var calm_color := Color(0.25, 0.85, 0.35)
@export var suspicious_color := Color(1.0, 0.8, 0.15)
@export var alert_color := Color(1.0, 0.2, 0.15)
@export_range(0.0, 1.0) var near_alpha: float = 0.45
@export_range(0.0, 1.0) var far_alpha: float = 0.2

## Nombre de recalculs du cône (mesure du coût, tests).
var rebuild_count: int = 0

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _built_transform := Transform3D()
var _built_segments: int = 0
var _dirty: bool = true
var _since_build: float = 0.0


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
	# Pas dans l'aperçu de la carte (`LevelPreview`).
	instance.layers = LevelPreview.OVERLAY_LAYER
	add_child(instance)
	EventBus.navigation_obstacle_moved.connect(invalidate)


func _physics_process(delta: float) -> void:
	_since_build += delta
	var segments := _segments_for_view()
	if not _needs_rebuild(segments):
		return
	if not _is_on_screen():
		# Recalculé dès qu'il redeviendra visible.
		_dirty = true
		return
	_rebuild_cone(segments)


## Oblige à recalculer le cône à la prochaine image (obstacle déplacé).
func invalidate() -> void:
	_dirty = true


func _needs_rebuild(segments: int) -> bool:
	if _dirty or segments != _built_segments or _since_build >= REFRESH_INTERVAL:
		return true
	var current := global_transform
	if current.origin.distance_to(_built_transform.origin) > MOVE_TOLERANCE:
		return true
	return (-current.basis.z).angle_to(-_built_transform.basis.z) > TURN_TOLERANCE


## Segments du cône pour la vue actuelle : moins quand la caméra est très
## dézoomée (le cône y fait peu de pixels).
func _segments_for_view() -> int:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or camera.size <= DETAIL_VIEW_SIZE:
		return config.segments
	return maxi(MIN_SEGMENTS, int(config.segments * DETAIL_VIEW_SIZE / camera.size))


## Vrai si la boîte qui contient le cône est (au moins en partie) dans le
## champ de la caméra.
func _is_on_screen() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	var reach := config.far_range
	var box := AABB(global_position - Vector3(reach, 1.0, reach), Vector3(reach * 2.0, 3.0, reach * 2.0))
	for plane in camera.get_frustum():
		# Boîte entièrement du côté extérieur d'un plan : hors champ.
		var corner := Vector3(
			box.position.x if plane.normal.x > 0.0 else box.end.x,
			box.position.y if plane.normal.y > 0.0 else box.end.y,
			box.position.z if plane.normal.z > 0.0 else box.end.z)
		if plane.distance_to(corner) > 0.0:
			return false
	return true


## Zone du cône dans laquelle `target` est visible, ou `Zone.NONE`.
## Avec `ignore_posture` (ennemi en alerte), la zone lointaine voit aussi
## les cibles accroupies ou rampées.
func check(target: Unit, ignore_posture: bool = false) -> Zone:
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
	if SmokeCloud.blocks_sight(get_tree(), eye, aim):
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


func _rebuild_cone(segments: int) -> void:
	rebuild_count += 1
	_dirty = false
	_since_build = 0.0
	_built_transform = global_transform
	_built_segments = segments
	_mesh.clear_surfaces()
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * config.cone_ray_height
	var half_fov := deg_to_rad(config.fov_degrees) * 0.5
	var directions: Array[Vector3] = []
	var reaches: Array[float] = []
	for i in segments + 1:
		var angle := -half_fov + 2.0 * half_fov * float(i) / float(segments)
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
	for i in segments:
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
