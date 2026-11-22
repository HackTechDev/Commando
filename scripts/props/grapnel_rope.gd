class_name GrapnelRope
extends Node3D
## Grappin lancé vers un point en hauteur et sa corde. `plan` cherche, sur
## la ligne entre le point visé et l'opérateur, le relief à gravir : les
## ressauts (faces) entre le sol de l'opérateur et celui du point, et le pied
## de la corde. Une fois le grappin accroché (`launch`), la corde épouse ce
## relief et devient un passage de navigation (`TraversalLink`, de type
## corde) : l'opérateur, ses coéquipiers et les ennemis peuvent l'emprunter.

signal anchored

## Portée horizontale du lancer (du pied de la corde au point visé) et
## dénivelé permis.
const MAX_RANGE := 10.0
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 9.0
## Pas d'échantillonnage du relief (m), et dénivelé qui marque une face.
const STEP := 0.2
const FACE_DROP := 0.3
## Distance du pied de la corde à la face la plus basse.
const FOOT_DISTANCE := 0.7
## Distance du point d'arrivée, en haut, au bord de la face la plus haute.
const TOP_INSET := 0.7
## Durée du vol du grappin.
const FLIGHT_TIME := 0.7
const MASK_GROUND := 0b011
## Corde d'escalade orangée, bien visible sur la roche ; écartée de la paroi.
const ROPE_COLOR := Color(0.95, 0.5, 0.12)
const ROPE_THICKNESS := 0.035
const WALL_GAP := 0.06

## Résultat de `plan` utilisé pour construire la corde.
var anchor: Vector3
var link: TraversalLink
var _plan: Dictionary
var _hook: Node3D
var _flight: float = -1.0
var _from: Vector3


## Cherche comment monter de `from` (pieds de l'opérateur) jusqu'à `target`
## (un point en hauteur, sur le maillage de navigation). Renvoie
## {"ok": bool, "reason": String, "foot", "top", "anchor": Vector3,
## "faces": Array[Vector4] (x, z de la face, sol bas, sol haut ; du pied au
## sommet)}. `map` : carte de navigation à consulter (à défaut, celle du
## monde ; la vérification de l'éditeur de mission passe la sienne).
static func plan(world: World3D, from: Vector3, target: Vector3, map: RID = RID()) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if not map.is_valid():
		map = world.navigation_map
	var space := world.direct_space_state
	var on_mesh := NavigationServer3D.map_get_closest_point(map, target)
	if Vector2(on_mesh.x - target.x, on_mesh.z - target.z).length() > 0.6 or absf(on_mesh.y - target.y) > 1.0:
		result["reason"] = "point inaccessible"
		return result
	if target.y - from.y < MIN_HEIGHT:
		result["reason"] = "pas assez haut"
		return result
	var toward := Vector3(from.x - target.x, 0.0, from.z - target.z)
	if toward.length() < 1.0:
		result["reason"] = "trop près"
		return result
	var direction := toward.normalized()
	# Profil du sol, du point visé vers l'opérateur.
	var limit := minf(toward.length() + 2.0, MAX_RANGE + FOOT_DISTANCE)
	var heights: Array[float] = []
	var top := target.y
	var distance := 0.0
	while distance <= limit:
		var point := target + direction * distance
		var height := _ground_height(space, point, top + 2.5, from.y - 1.5)
		if is_nan(height):
			# Pile sur une arête : on mesure un peu plus loin.
			height = _ground_height(space, point + direction * 0.05, top + 2.5, from.y - 1.5)
		if is_nan(height):
			break
		if height > top + FACE_DROP:
			result["reason"] = "obstacle"
			return result
		heights.append(height)
		distance += STEP
	# Faces (de haut en bas), puis pied : au niveau de l'opérateur, à
	# `FOOT_DISTANCE` de la dernière face.
	var faces: Array[Vector4] = []
	var foot_index := -1
	for i in range(1, heights.size()):
		var drop := heights[i - 1] - heights[i]
		if drop > FACE_DROP:
			var at := target + direction * (STEP * (i - 0.5))
			faces.append(Vector4(at.x, at.z, heights[i], heights[i - 1]))
		elif drop < -FACE_DROP:
			result["reason"] = "relief trop accidenté"
			return result
		var low := absf(heights[i] - from.y) < 0.4
		if low and not faces.is_empty() and STEP * i - _face_distance(faces[-1], target, direction) >= FOOT_DISTANCE:
			foot_index = i
			break
	if faces.is_empty() or foot_index < 0:
		result["reason"] = "aucune paroi à gravir"
		return result
	var foot := target + direction * (STEP * foot_index)
	foot.y = heights[foot_index]
	if Vector2(foot.x - target.x, foot.z - target.z).length() > MAX_RANGE:
		result["reason"] = "trop loin"
		return result
	var rise := target.y - foot.y
	if rise > MAX_HEIGHT:
		result["reason"] = "trop haut"
		return result
	var foot_mesh := NavigationServer3D.map_get_closest_point(map, foot)
	if Vector2(foot_mesh.x - foot.x, foot_mesh.z - foot.z).length() > 0.5:
		result["reason"] = "pied de la paroi inaccessible"
		return result
	var first := faces[0]
	var top_point := Vector3(first.x, first.w, first.y) - direction * TOP_INSET
	if _face_distance(first, target, direction) < TOP_INSET:
		top_point = Vector3(target.x, first.w, target.z)
	faces.reverse()
	result["ok"] = true
	result["foot"] = foot
	result["top"] = top_point
	result["anchor"] = target
	result["faces"] = faces
	return result


static func _face_distance(face: Vector4, target: Vector3, direction: Vector3) -> float:
	return Vector2(face.x - target.x, face.y - target.z).dot(Vector2(direction.x, direction.z))


## Hauteur du sol sous `point` (rayon de `above` à `below`), ou NAN.
static func _ground_height(space: PhysicsDirectSpaceState3D, point: Vector3, above: float, below: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, above, point.z), Vector3(point.x, below, point.z), MASK_GROUND)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		return NAN
	return (hit["position"] as Vector3).y


## Crée le grappin, lancé de `hand` selon `route` (résultat de `plan`).
static func launch(parent: Node, hand: Vector3, route: Dictionary) -> GrapnelRope:
	var rope := GrapnelRope.new()
	rope.name = "GrapnelRope"
	rope._plan = route
	rope.anchor = route["anchor"]
	rope._from = hand
	parent.add_child(rope)
	rope._start_flight()
	return rope


func _start_flight() -> void:
	_hook = _build_hook()
	add_child(_hook)
	_hook.global_position = _from
	_flight = 0.0


func _process(delta: float) -> void:
	if _flight < 0.0:
		return
	_flight = minf(_flight + delta / FLIGHT_TIME, 1.0)
	# Parabole au-dessus du point visé.
	var arc := 4.0 * _flight * (1.0 - _flight) * (1.5 + 0.15 * _from.distance_to(anchor))
	_hook.global_position = _from.lerp(anchor, _flight) + Vector3.UP * arc
	_draw_rope([_from, _hook.global_position])
	if _flight >= 1.0:
		_flight = -1.0
		_hook.global_position = anchor + Vector3.UP * 0.05
		_draw_rope(rope_points())
		_add_link()
		Sfx.play_at(&"ricochet", anchor, -6.0)
		anchored.emit()


## Points de la corde posée : du grappin, sur le bord des faces, jusqu'au sol
## au pied de la dernière.
func rope_points() -> PackedVector3Array:
	var points := PackedVector3Array([anchor + Vector3.UP * 0.05])
	var faces: Array = _plan["faces"].duplicate()
	faces.reverse()
	var foot_point: Vector3 = _plan["foot"]
	var out := Vector3(foot_point.x - anchor.x, 0.0, foot_point.z - anchor.z).normalized() * WALL_GAP
	for face: Vector4 in faces:
		points.append(Vector3(face.x, face.w + 0.04, face.y) + out)
		points.append(Vector3(face.x, face.z + 0.04, face.y) + out)
	var foot: Vector3 = _plan["foot"]
	points.append(foot + Vector3.UP * 0.04)
	return points


func _add_link() -> void:
	link = TraversalLink.new()
	link.name = "Link"
	link.kind = TraversalLink.Kind.ROPE
	link.faces = _plan["faces"]
	add_child(link)
	link.global_transform = Transform3D.IDENTITY
	link.start_position = _plan["foot"]
	link.end_position = _plan["top"]


func _draw_rope(points: PackedVector3Array) -> void:
	var old := get_node_or_null(^"Rope")
	if old:
		remove_child(old)
		old.queue_free()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		_add_strand(mesh, points[i], points[i + 1], ROPE_THICKNESS)
	mesh.surface_end()
	var rope := MeshInstance3D.new()
	rope.name = "Rope"
	rope.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = ROPE_COLOR
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rope.material_override = material
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope)


## Brin de corde de section carrée de `from` à `to`.
static func _add_strand(mesh: ImmediateMesh, from: Vector3, to: Vector3, size: float) -> void:
	var axis := to - from
	if axis.length_squared() < 0.000001:
		return
	axis = axis.normalized()
	var helper := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u := axis.cross(helper).normalized() * size
	var v := axis.cross(u).normalized() * size
	for side: Array in [[u, v], [v, -u], [-u, -v], [-v, u]]:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		mesh.surface_set_normal((a + b).normalized())
		mesh.surface_add_vertex(from + a)
		mesh.surface_add_vertex(to + a)
		mesh.surface_add_vertex(to + b)
		mesh.surface_add_vertex(from + a)
		mesh.surface_add_vertex(to + b)
		mesh.surface_add_vertex(from + b)


## Grappin : hampe et trois griffes recourbées.
func _build_hook() -> Node3D:
	var hook := Node3D.new()
	hook.name = "Hook"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.32, 0.34)
	material.metallic = 0.8
	material.roughness = 0.4
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.018
	cylinder.height = 0.28
	shaft.mesh = cylinder
	shaft.material_override = material
	shaft.position.y = 0.14
	hook.add_child(shaft)
	for i in 3:
		var prong := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, 0.14)
		prong.mesh = box
		prong.material_override = material
		var angle := TAU * i / 3.0
		prong.position = Vector3(sin(angle) * 0.06, 0.03, cos(angle) * 0.06)
		prong.rotation = Vector3(-0.6, angle, 0.0)
		hook.add_child(prong)
	return hook
