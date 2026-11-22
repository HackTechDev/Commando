@tool
extends RefCounted
## Carte de couverture des gardes : pour chaque case du sol, ce que les
## gardes en voient, avec les règles du jeu (`VisionComponent.zone_for`,
## obstacles de la couche 2, vue réduite la nuit) :
## - 2 : zone proche d'au moins un garde, on y est vu même accroupi ;
## - 1 : zone lointaine, on y est vu debout ;
## et le nombre de gardes qui la voient.
## Un garde en ronde est regardé à chaque point de son chemin et au milieu
## de chaque segment, tourné dans le sens de la marche ; un garde posté, à
## sa place et dans sa direction.

const Gizmos := preload("res://addons/mission_editor/gizmos.gd")

## Taille d'une case (m) et hauteur du dessin au-dessus du sol.
const CELL := 1.0
const LIFT := 0.08
## Hauteurs visées : opérateur accroupi (zone proche), debout (lointaine),
## comme `VisionComponent._target_height`.
const CROUCHED_HEIGHT := 0.8
const STANDING_HEIGHT := 1.4
const COLORS := {
	1: Color(1.0, 0.85, 0.2),
	2: Color(1.0, 0.25, 0.15),
}


## Case (x, z) -> [niveau 1 ou 2, nombre de gardes].
static func compute(root: Node) -> Dictionary:
	var cells := {}
	if not root is Node3D:
		return cells
	var space := (root as Node3D).get_world_3d().direct_space_state
	var night: bool = root.get("night") if root is LevelRoot else false
	for guard in root.find_children("*", "", true, true):
		if not guard is Enemy or guard.get("blind"):
			continue
		var vision := guard.get_node_or_null(^"VisionComponent") as Node3D
		var config := vision.get("config") as VisionConfig if vision else null
		if config == null:
			continue
		if night:
			config = config.duplicate() as VisionConfig
			config.far_range = maxf(config.near_range, config.far_range * LevelRoot.NIGHT_SIGHT)
		var seen := {}
		for view: Transform3D in viewpoints(guard as Node3D):
			_look(space, view, config, seen)
		for key: Vector2i in seen:
			var entry: Array = cells.get(key, [0, 0])
			entry[0] = maxi(entry[0], seen[key])
			entry[1] += 1
			cells[key] = entry
	return cells


## Positions et orientations (vers -Z) d'où regarde `guard`.
static func viewpoints(guard: Node3D) -> Array[Transform3D]:
	var views: Array[Transform3D] = [guard.global_transform]
	var path := Gizmos.patrol_of(guard)
	if path == null or path.curve == null or path.curve.point_count < 2:
		return views
	var points := PackedVector3Array()
	for i in path.curve.point_count:
		points.append(path.to_global(path.curve.get_point_position(i)))
	# La ronde boucle (retour au premier point) ; chaque point est regardé
	# dans les deux sens de marche.
	if points.size() > 2:
		points.append(points[0])
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		for at: Vector3 in [a, (a + b) * 0.5, b]:
			views.append(_facing(at, b - a))
			views.append(_facing(at, a - b))
	return views


static func _facing(at: Vector3, heading: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(-heading.x, -heading.z)), at)


## Cases vues depuis `view` : niveau le plus haut gardé dans `seen`.
static func _look(space: PhysicsDirectSpaceState3D, view: Transform3D, config: VisionConfig, seen: Dictionary) -> void:
	var eye := view.origin + Vector3.UP * config.eye_height
	var reach := ceili(config.far_range / CELL)
	var center := Vector2i(roundi(view.origin.x / CELL), roundi(view.origin.z / CELL))
	var inverse := view.affine_inverse()
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var key := center + Vector2i(dx, dz)
			var ground := Vector3(key.x * CELL, 0.0, key.y * CELL)
			var offset := inverse * ground
			offset.y = 0.0
			var zone := VisionComponent.zone_for(offset, SoldierModel.Posture.STANDING, config)
			if zone == VisionComponent.Zone.NONE:
				continue
			var level := 2 if zone == VisionComponent.Zone.NEAR else 1
			if seen.get(key, 0) >= level:
				continue
			var height := CROUCHED_HEIGHT if level == 2 else STANDING_HEIGHT
			var query := PhysicsRayQueryParameters3D.create(eye, ground + Vector3.UP * height, VisionComponent.MASK_OCCLUDERS)
			if space.intersect_ray(query).is_empty():
				seen[key] = level


## Dessin de la couverture `cells` : une case colorée par case vue, plus
## opaque quand plusieurs gardes la voient.
static func build_mesh(cells: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var half := CELL * 0.5
	for key: Vector2i in cells:
		var entry: Array = cells[key]
		var color: Color = COLORS[entry[0]]
		color.a = clampf(0.22 + 0.13 * (entry[1] - 1), 0.22, 0.6)
		var c := Vector3(key.x * CELL, LIFT, key.y * CELL)
		var corners := [c + Vector3(-half, 0, -half), c + Vector3(half, 0, -half), c + Vector3(half, 0, half), c + Vector3(-half, 0, half)]
		for index in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[index])
			colors.append(color)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
