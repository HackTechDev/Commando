class_name UfoMap
extends RefCounted
## Lecture d'une carte source UFO:AI (`.map`, format Radiant de Quake 2) :
## une liste d'entités (propriétés texte) dont certaines portent des brushes,
## volumes convexes décrits par leurs plans.
##
## Ligne d'une face : `( x y z ) ( x y z ) ( x y z ) texture décalage_x
## décalage_y rotation échelle_x échelle_y contenu surface valeur`.
## Coordonnées d'origine : Z vers le haut, 32 unités par case de déplacement.

## Drapeaux de contenu (brush) et de surface (face) d'UFO:AI.
const CONTENTS_ACTORCLIP := 0x10000
const CONTENTS_PASSABLE := 0x20000
const CONTENTS_LIGHTCLIP := 0x80000
const CONTENTS_WEAPONCLIP := 0x2000000
const SURF_LIGHT := 0x1
const SURF_BLEND33 := 0x10
const SURF_BLEND66 := 0x20
const SURF_NODRAW := 0x80
const SURF_PHONG := 0x400
const SURF_ALPHATEST := 0x4000


class Face:
	## Plan sortant : les points du brush vérifient `normal.dot(p) <= d`.
	var plane: Plane
	var texture: String
	var shift: Vector2
	var rotation: float
	var scale: Vector2
	var contents: int
	var surface: int
	var value: int


class Brush:
	var faces: Array[Face] = []

	## Union des drapeaux de contenu de ses faces.
	func contents() -> int:
		var flags := 0
		for face in faces:
			flags |= face.contents
		return flags

	## Vrai si toutes ses faces portent une texture de `prefix`.
	func all_textures_start_with(prefix: String) -> bool:
		for face in faces:
			if not face.texture.begins_with(prefix):
				return false
		return true


class Entity:
	var properties: Dictionary = {}
	var brushes: Array[Brush] = []

	func classname() -> String:
		return str(properties.get("classname", ""))

	## Position en unités de la carte (Z vers le haut).
	func origin() -> Vector3:
		var parts := str(properties.get("origin", "0 0 0")).split(" ", false)
		if parts.size() < 3:
			return Vector3.ZERO
		return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())

	## Orientation en degrés (lacet, autour de Z, depuis +X).
	func angle() -> float:
		return str(properties.get("angle", "0")).to_float()


var entities: Array[Entity] = []


## Lit le fichier `path` ; renvoie null (avec une erreur) s'il est illisible.
static func load_file(path: String) -> UfoMap:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Carte illisible : %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var map := UfoMap.new()
	if not map.parse(file.get_as_text()):
		push_error("Carte mal formée : %s" % path)
		return null
	return map


## Analyse le texte d'une carte. Renvoie false s'il est mal formé.
func parse(text: String) -> bool:
	var entity: Entity = null
	var brush: Brush = null
	var depth := 0
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		if line == "{":
			depth += 1
			if depth == 1:
				entity = Entity.new()
			elif depth == 2:
				brush = Brush.new()
			else:
				return false
		elif line == "}":
			if depth == 2:
				entity.brushes.append(brush)
			elif depth == 1:
				entities.append(entity)
			else:
				return false
			depth -= 1
		elif depth == 1 and line.begins_with("\""):
			var parts := line.split("\"")
			if parts.size() >= 4:
				entity.properties[parts[1]] = parts[3]
		elif depth == 2 and line.begins_with("("):
			var face := _parse_face(line)
			if face == null:
				return false
			brush.faces.append(face)
	return depth == 0


## Entités de la classe `classname`.
func find_entities(classname: String) -> Array[Entity]:
	var found: Array[Entity] = []
	for entity in entities:
		if entity.classname() == classname:
			found.append(entity)
	return found


func _parse_face(line: String) -> Face:
	var close := line.rfind(")")
	var coords := line.substr(0, close).replace("(", " ").replace(")", " ").split(" ", false)
	var rest := line.substr(close + 1).split(" ", false)
	if coords.size() != 9 or rest.size() < 6:
		return null
	var points: Array[Vector3] = []
	for i in 3:
		points.append(Vector3(coords[i * 3].to_float(), coords[i * 3 + 1].to_float(), coords[i * 3 + 2].to_float()))
	var normal := (points[0] - points[1]).cross(points[2] - points[1])
	if normal.length_squared() < 0.000001:
		return null
	normal = normal.normalized()
	var face := Face.new()
	face.plane = Plane(normal, normal.dot(points[1]))
	face.texture = rest[0]
	face.shift = Vector2(rest[1].to_float(), rest[2].to_float())
	face.rotation = rest[3].to_float()
	face.scale = Vector2(rest[4].to_float(), rest[5].to_float())
	if rest.size() >= 9:
		face.contents = rest[6].to_int()
		face.surface = rest[7].to_int()
		face.value = rest[8].to_int()
	return face
