@tool
extends RefCounted
## Animation des rondes et des trajets dans l'éditeur (bouton lecture et
## barre de temps du dock) : position de chaque unité mobile au temps `t`,
## avec les règles du jeu, et silhouettes qui la montrent.
## - garde en ronde : du point de départ au premier point de son chemin, puis
##   de point en point en boucle, à `EnemyStats.patrol_speed`, avec une pause
##   `patrol_pause` à chaque point (au premier aussi, même s'il y est posé) ;
## - pick-up armé : de sa place au premier point, puis en boucle à
##   `Technical.SPEED` ;
## - avion ennemi : le long de son chemin à `speed`, à `altitude`, et repris
##   au début (comme `EnemyAircraft._place`) ;
## - passant : aller-retour (ou boucle) à `speed`, depuis `start_at` ;
## - voiture : boucle à `cruise`, depuis `start_at`.
## Simplifications : trajets en ligne droite entre les points (la
## navigation contourne les obstacles en jeu), sans les arrêts imprévus
## (passant bloqué, voiture qui freine ou klaxonne, garde alerté).

const Coverage := preload("res://addons/mission_editor/coverage.gd")
const Gizmos := preload("res://addons/mission_editor/gizmos.gd")

## Durée de la barre de temps (s).
const DURATION := 180.0
const NAME := "MissionEditorTimeline"
const LIFT := 0.1
const COLORS := {
	"enemy": Color(1.0, 0.35, 0.2),
	"technical": Color(0.85, 0.3, 0.15),
	"aircraft": Color(0.8, 0.25, 0.25),
	"passerby": Color(0.35, 0.75, 1.0),
	"car": Color(0.9, 0.9, 0.95),
}


## Unités animées de la scène `root`.
static func movers(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in root.find_children("*", "", true, true):
		if node is Enemy or node is Technical or node is EnemyAircraft or node is SurveillanceDrone:
			var path := Gizmos.patrol_of(node)
			if path and path.curve and path.curve.point_count >= 2:
				found.append(node)
		elif (node is Passerby or node is TrafficCar) and (node.get("points") as PackedVector3Array).size() >= 2:
			found.append(node)
	return found


static func kind(node: Node) -> String:
	if node is Enemy:
		return "enemy"
	if node is Technical:
		return "technical"
	if node is EnemyAircraft or node is SurveillanceDrone:
		return "aircraft"
	if node is Passerby:
		return "passerby"
	return "car"


## Place et cap (vers -Z) de `node` au temps `t` (s), dans le monde.
static func pose(node: Node3D, t: float) -> Transform3D:
	match kind(node):
		"enemy":
			var stats: Resource = node.get("stats")
			var speed: float = stats.get("patrol_speed") if stats else 1.6
			var pause: float = stats.get("patrol_pause") if stats else 2.0
			return _patrol(node.global_position, _path_points(node), speed, maxf(pause, 0.0), t)
		"technical":
			return _patrol(node.global_position, _path_points(node), Technical.SPEED, 0.0, t)
		"aircraft":
			return _flight(node, t)
		"passerby":
			return _walk(node, t)
	return _drive(node, t)


static func _path_points(node: Node) -> PackedVector3Array:
	var path := Gizmos.patrol_of(node)
	var points := PackedVector3Array()
	for i in path.curve.point_count:
		points.append(path.to_global(path.curve.get_point_position(i)))
	return points


## Ronde : de `start` au premier point, puis en boucle (retour du dernier au
## premier), pause `pause` à chaque arrivée.
static func _patrol(start: Vector3, points: PackedVector3Array, speed: float, pause: float, t: float) -> Transform3D:
	var legs: Array = [[start, points[0]]]
	for i in points.size():
		legs.append([points[i], points[(i + 1) % points.size()]])
	var cycle := 0.0
	for i in range(1, legs.size()):
		cycle += (legs[i][0] as Vector3).distance_to(legs[i][1]) / speed + pause
	# Comme en jeu : arrivé au premier point (ou déjà dessus), pause, puis
	# le suivant.
	var first := start.distance_to(points[0]) / speed + pause
	var index := 0
	if t >= first:
		t = fposmod(t - first, maxf(cycle, 0.01))
		index = 1
	else:
		legs = [legs[0]]
	var heading := points[1] - points[0]
	while index < legs.size():
		var a: Vector3 = legs[index][0]
		var b: Vector3 = legs[index][1]
		var walk := a.distance_to(b) / speed
		if a.distance_to(b) > 0.01:
			heading = b - a
		if t < walk:
			return _at(a.lerp(b, t / maxf(walk, 0.0001)), heading)
		t -= walk
		if t < pause or index == legs.size() - 1:
			return _at(b, heading)
		t -= pause
		index += 1
	return _at(points[0], heading)


static func _flight(node: Node, t: float) -> Transform3D:
	var path := Gizmos.patrol_of(node)
	var curve := path.curve
	var length := curve.get_baked_length()
	var travelled := fposmod(float(node.get("speed")) * t, maxf(length, 0.01))
	var here := path.to_global(curve.sample_baked(travelled))
	var ahead := path.to_global(curve.sample_baked(fposmod(travelled + 4.0, maxf(length, 0.01))))
	return _at(here + Vector3.UP * float(node.get("altitude")), ahead - here)


## Passant : aller-retour (ou boucle si `loop`) depuis `start_at`.
static func _walk(node: Node3D, t: float) -> Transform3D:
	var points := _parent_points(node)
	var loop: bool = node.get("loop")
	if loop:
		points.append(points[0])
	var total := _length(points)
	var start_direction := -1.0 if node.get("backward") else 1.0
	var raw: float = float(node.get("start_at")) + start_direction * float(node.get("speed")) * t
	var direction := start_direction
	var at := fposmod(raw, total)
	if not loop:
		# Une longueur de tracé par trajet : un sur deux se fait à l'envers.
		var leg := floori(raw / total)
		if posmod(leg, 2) == 1:
			at = total - at
			direction = -start_direction
	var spot := _along(points, at)
	return _at(spot[0], (spot[1] as Vector3) * direction)


## Voiture : boucle à `cruise` depuis `start_at`.
static func _drive(node: Node3D, t: float) -> Transform3D:
	var points := _parent_points(node)
	points.append(points[0])
	var at := fposmod(float(node.get("start_at")) + float(node.get("cruise")) * t, _length(points))
	var spot := _along(points, at)
	return _at(spot[0], spot[1])


static func _parent_points(node: Node3D) -> PackedVector3Array:
	var frame := (node.get_parent() as Node3D).global_transform if node.get_parent() is Node3D else Transform3D.IDENTITY
	var points := PackedVector3Array()
	for point: Vector3 in node.get("points"):
		points.append(frame * point)
	return points


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return maxf(total, 0.01)


## Point à la distance `at` le long de `points`, et sens du segment.
static func _along(points: PackedVector3Array, at: float) -> Array:
	for i in range(1, points.size()):
		var span := points[i - 1].distance_to(points[i])
		if at <= span or i == points.size() - 1:
			return [points[i - 1].lerp(points[i], clampf(at / maxf(span, 0.0001), 0.0, 1.0)), points[i] - points[i - 1]]
		at -= span
	return [points[0], points[1] - points[0]]


static func _at(position: Vector3, heading: Vector3) -> Transform3D:
	var yaw := atan2(-heading.x, -heading.z) if Vector2(heading.x, heading.z).length() > 0.0001 else 0.0
	return Transform3D(Basis(Vector3.UP, yaw), position)


# --- Silhouettes --------------------------------------------------------------

## Silhouette de `node` : corps ou véhicule, cône de vue d'un garde, cercle
## de détection d'un avion (au sol, sous lui).
static func ghost(node: Node3D, night: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Ghost%s" % node.name
	var color: Color = COLORS[kind(node)]
	var body := MeshInstance3D.new()
	match kind(node):
		"enemy", "passerby":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.35
			capsule.height = 1.8
			body.mesh = capsule
			body.position.y = 0.9
		"technical":
			body.mesh = _box(Vector3(2.0, 1.6, 4.8))
			body.position.y = 0.8
		"car":
			body.mesh = _box(Vector3(1.8, 1.4, 4.3))
			body.position.y = 0.7
		"aircraft":
			body.mesh = _box(Vector3(9.0, 1.2, 7.0))
	body.material_override = _material(Color(color, 0.85))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	# Nez : de quel côté il va.
	var nose := MeshInstance3D.new()
	nose.mesh = _box(Vector3(0.25, 0.25, 0.8))
	nose.material_override = _material(Color(1, 1, 1, 0.9))
	nose.position = Vector3(0, body.position.y + 0.3, -1.0 if kind(node) in ["enemy", "passerby"] else -2.6)
	holder.add_child(nose)
	if node is Enemy:
		var config := Coverage.config_of(node, night)
		if config:
			holder.add_child(_cone(config))
	if node is EnemyAircraft or node is SurveillanceDrone:
		var radius := SurveillanceDrone.FOOTPRINT if node is SurveillanceDrone else (EnemyAircraft.NIGHT_RADIUS if night else EnemyAircraft.DAY_RADIUS)
		var disc := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius
		cylinder.height = 0.02
		disc.mesh = cylinder
		disc.material_override = _material(Color(color, 0.25))
		disc.name = "Spot"
		disc.top_level = true
		holder.add_child(disc)
	return holder


## Place la silhouette `holder` de `node` au temps `t`.
static func place(holder: Node3D, node: Node3D, t: float) -> void:
	holder.global_transform = pose(node, t)
	var spot := holder.get_node_or_null(^"Spot") as Node3D
	if spot:
		spot.global_position = Vector3(holder.global_position.x, LIFT, holder.global_position.z)


static func _cone(config: VisionConfig) -> MeshInstance3D:
	var faces := PackedVector3Array()
	var half := deg_to_rad(config.fov_degrees) * 0.5
	var steps := 20
	var colors := PackedColorArray()
	for i in steps:
		var a := -half + 2.0 * half * i / steps
		var b := -half + 2.0 * half * (i + 1) / steps
		var da := Vector3(sin(a), 0.0, -cos(a))
		var db := Vector3(sin(b), 0.0, -cos(b))
		for ring: Array in [[0.0, config.near_range, 0.35], [config.near_range, config.far_range, 0.15]]:
			var inner: float = ring[0]
			var outer: float = ring[1]
			var quad := [da * inner, db * inner, db * outer, da * inner, db * outer, da * outer]
			for v: Vector3 in quad:
				faces.append(v + Vector3.UP * LIFT)
				colors.append(Color(1.0, 0.35, 0.2, ring[2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = mesh
	cone.material_override = material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cone


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material
