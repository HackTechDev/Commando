@tool
class_name FacetModel
extends Node3D
## Base des véhicules construits en code (`TiltrotorModel`, `SabreModel`) :
## facettes à normales plates accumulées par matériau (`_materials`, clés
## `StringName`), puis réunies en un maillage par `_commit`.

var _materials: Dictionary = {}
var _tools: Dictionary = {}


func _plain(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _glow(color: Color) -> StandardMaterial3D:
	var material := _plain(color, 0.4, 0.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material


## Anneau octogonal chanfreiné de demi-largeur `w`, de `bottom` à `top`, dans
## le plan (`u`, `v`) autour de `origin`.
static func ring(origin: Vector3, u: Vector3, v: Vector3, w: float, bottom: float, top: float, chamfer_top: float, chamfer_bottom: float) -> PackedVector3Array:
	var flat: Array[Vector2] = [
		Vector2(w * 0.55, top), Vector2(w, top - chamfer_top), Vector2(w, bottom + chamfer_bottom), Vector2(w * 0.6, bottom),
		Vector2(-w * 0.6, bottom), Vector2(-w, bottom + chamfer_bottom), Vector2(-w, top - chamfer_top), Vector2(-w * 0.55, top),
	]
	var points := PackedVector3Array()
	for p in flat:
		points.append(origin + u * p.x + v * p.y)
	return points


## Triangle à normale plate, tourné vers l'extérieur (loin de `inside`).
func _tri(key: StringName, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
		normal = -normal
	else:
		# Face avant dans le sens des aiguilles d'une montre (Godot).
		var swap := b
		b = c
		c = swap
	if not _tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_materials[key])
		_tools[key] = tool
	var surface: SurfaceTool = _tools[key]
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x + point.z, point.y) * 0.5)
		surface.add_vertex(point)


func _quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_tri(key, a, b, c, inside)
	_tri(key, a, c, d, inside)


## Relie des anneaux successifs (même nombre de points) ; bouche les deux
## bouts. `material_for(section, segment)` choisit le matériau d'une facette.
func _loft(rings: Array[PackedVector3Array], material_for: Callable = Callable()) -> void:
	for s in rings.size() - 1:
		var a := rings[s]
		var b := rings[s + 1]
		var inside := (_centroid(a) + _centroid(b)) * 0.5
		for i in a.size():
			var j := (i + 1) % a.size()
			var key: StringName = material_for.call(s, i) if material_for.is_valid() else &"hull"
			# Clé vide : facette ouverte.
			if key != &"":
				_quad(key, a[i], a[j], b[j], b[i], inside)
	var cap_key: StringName = material_for.call(0, 0) if material_for.is_valid() else &"hull"
	var middle := (_centroid(rings[0]) + _centroid(rings[rings.size() - 1])) * 0.5
	for cap: PackedVector3Array in [rings[0], rings[rings.size() - 1]]:
		var center := _centroid(cap)
		# Le bout : son « intérieur » est vers le milieu de la pièce.
		var inside := center + (middle - center).normalized() * 0.01 if middle.distance_to(center) > 0.001 else middle
		for i in cap.size():
			_tri(cap_key, center, cap[i], cap[(i + 1) % cap.size()], inside)


static func _centroid(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


## Pavé (facettes plates) de centre `center` et de taille `size`.
func _box(key: StringName, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for face: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_quad(key, c[face[0]], c[face[1]], c[face[2]], c[face[3]], center)


## Cylindre d'axe `axis` (facettes), de `from` à `to`.
func _cylinder(key: StringName, from: Vector3, to: Vector3, radius: float, sides: int = 10) -> void:
	var axis := (to - from).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in sides:
		var angle := TAU * i / sides
		var offset := (u * cos(angle) + v * sin(angle)) * radius
		bottom.append(from + offset)
		top.append(to + offset)
	var inside := (from + to) * 0.5
	for i in sides:
		var j := (i + 1) % sides
		_quad(key, bottom[i], bottom[j], top[j], top[i], inside)
		_tri(key, from, bottom[i], bottom[j], inside)
		_tri(key, to, top[i], top[j], inside)


## Réunit les facettes accumulées en un maillage (une surface par matériau).
func _commit(node_name: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key: StringName in _tools:
		(_tools[key] as SurfaceTool).commit(mesh)
	_tools.clear()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance
