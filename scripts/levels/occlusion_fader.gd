class_name OcclusionFader
extends Node
## Occlusion des cartes faites main : un mur, un bâtiment ou un décor
## solide (couche des occultants) entre la caméra et un opérateur s'estompe
## en fondu, pour qu'on voie l'opérateur derrière. Les cartes UFO:AI ont
## leur propre découpe (`WorldMaterial`) et le convertible son propre
## fondu : ils ne sont pas concernés.
##
## Toutes les `CHECK_INTERVAL` s, des rayons partent de la caméra vers le
## buste et la tête de chaque opérateur vivant ; chaque corps touché sur le
## trajet (jusqu'à `MAX_LAYERS`) voit ses maillages estompés
## (`MeshFade.occlude`), puis rendus quand plus rien n'est caché derrière.
## Un corps estompé laisse passer les clics (`is_faded_body`).

const MASK_OCCLUDERS := 0b10
const CHECK_INTERVAL := 0.1
## Opacité retirée à un décor qui cache un opérateur (1 : invisible).
const FADE := 0.75
const FADE_TIME := 0.25
## Corps traversés au plus par rayon.
const MAX_LAYERS := 4
## Hauteurs visées sur l'opérateur, selon la posture.
const AIM_HEIGHTS := {
	SoldierModel.Posture.STANDING: [0.9, 1.6],
	SoldierModel.Posture.CROUCHED: [0.5, 1.0],
	SoldierModel.Posture.PRONE: [0.25],
}
## Recul du point de départ des rayons, le long de l'axe de la caméra (m).
const RAY_BACK := 120.0
const FADED_META := &"occlusion_faded"

## Corps estompés ou en train de revenir : corps → {"meshes", "fade"}.
var _bodies: Dictionary = {}
## Corps exclus une fois pour toutes (carte UFO:AI, convertible, sans
## maillage) : identifiant → vrai.
var _ignored: Dictionary = {}
var _wanted: Dictionary = {}
var _check_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Vrai si `collider` est un décor estompé par l'occlusion : un clic le
## traverse.
static func is_faded_body(collider: Object) -> bool:
	var node := collider as Node
	return node != null and node.get_meta(FADED_META, false)


## Nombre de corps estompés (tests, mise au point).
func faded_count() -> int:
	return _wanted.size()


func _physics_process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_wanted = _find_occluders()
	for body: Variant in _wanted:
		if not _bodies.has(body):
			_bodies[body] = {"meshes": _meshes_of(body as Node), "fade": 0.0}
	var gone: Array = []
	for body: Variant in _bodies:
		if not is_instance_valid(body):
			gone.append(body)
			continue
		var entry: Dictionary = _bodies[body]
		var goal := FADE if _wanted.has(body) else 0.0
		var fade: float = entry["fade"]
		(body as Node).set_meta(FADED_META, goal > 0.0)
		if is_equal_approx(fade, goal):
			if goal == 0.0:
				gone.append(body)
			continue
		fade = move_toward(fade, goal, delta * FADE / FADE_TIME)
		entry["fade"] = fade
		for mesh: MeshInstance3D in entry["meshes"]:
			if is_instance_valid(mesh):
				MeshFade.occlude(mesh, fade)
	for body: Variant in gone:
		if is_instance_valid(body):
			(body as Node).remove_meta(FADED_META)
		_bodies.erase(body)


## Corps entre la caméra et un opérateur.
func _find_occluders() -> Dictionary:
	var found := {}
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return found
	var forward := -camera.global_basis.z
	var space := camera.get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead or not unit.visible:
			continue
		for height: float in AIM_HEIGHTS.get(unit.posture, AIM_HEIGHTS[SoldierModel.Posture.STANDING]):
			var target := unit.global_position + Vector3.UP * height
			var from := target - forward * RAY_BACK
			if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
				from = camera.global_position
			var query := PhysicsRayQueryParameters3D.create(from, target, MASK_OCCLUDERS, [unit.get_rid()] as Array[RID])
			for layer in MAX_LAYERS:
				var hit := space.intersect_ray(query)
				if hit.is_empty():
					break
				var body := hit["collider"] as CollisionObject3D
				query.exclude += [hit["rid"]]
				if body and not _ignored.has(body.get_instance_id()):
					if _is_candidate(body):
						found[body] = true
					else:
						_ignored[body.get_instance_id()] = true
	return found


## Décor que l'occlusion peut estomper : corps fixe, hors carte UFO:AI et
## hors convertible, avec des maillages.
func _is_candidate(body: CollisionObject3D) -> bool:
	if not body is StaticBody3D or body is Tiltrotor:
		return false
	var parent := body.get_parent()
	while parent:
		if parent is UfoMapLevel or parent is Tiltrotor:
			return false
		parent = parent.get_parent()
	return not _meshes_of(body).is_empty()


## Maillages d'un corps : ses descendants, sans entrer dans un autre corps.
func _meshes_of(body: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is CollisionObject3D:
				continue
			if child is MeshInstance3D and (child as MeshInstance3D).mesh:
				meshes.append(child)
			stack.append(child)
	return meshes
