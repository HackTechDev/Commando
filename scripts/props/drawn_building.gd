@tool
class_name DrawnBuilding
extends Tower
## Bâtiment dessiné pièce par pièce (éditeur de mission) : des pièces
## rectangulaires (`rooms`), chacune à un étage (`room_storeys`), des
## ouvertures (`openings` : portes et fenêtres, sans battant) et des volées
## d'escalier (`stairs`). Les murs suivent le bord des pièces ; deux pièces
## qui se touchent partagent leur mur. Chaque niveau a une dalle sous les
## pièces de l'étage et au-dessus de celles de l'étage inférieur (leur toit),
## percée au-dessus des volées qui y arrivent.
##
## Hérite de l'immeuble (`Tower`) sa coupe : quand un opérateur est dedans,
## l'étage le plus bas occupé s'affiche en coupe et tout ce qui est au-dessus
## s'efface ; même chose pour le niveau de vue choisi par le joueur. Les
## réglages propres à l'immeuble (`size`, `doors`, `windows`) ne servent
## pas : l'emprise est celle des pièces.
##
## Repère : au sol ; pièces, ouvertures et volées en coordonnées locales
## (x, z), aimantées par l'éditeur à la grille.

## Portes : de vraies portes (`Door`, comme l'immeuble : battant, passage
## de navigation, crochetables si verrouillées) ; fenêtres : ouvertures
## (appui et linteau de l'immeuble), on voit au travers.
## Une ouverture se place sur le mur le plus proche, à cette distance au
## plus (m).
const SNAP := 1.0
## Pente des volées (degrés) et largeur (m).
const FLIGHT_SLOPE := 31.0
const FLIGHT_WIDTH := 1.6
const KIND_DOOR := 0
const KIND_WINDOW := 1
const KIND_LOCKED_DOOR := 2

## Pièces : rectangles (x, z) du repère local.
@export var rooms: Array[Rect2] = []:
	set(value):
		rooms = value
		_queue_rebuild()
## Étage de chaque pièce (0 : rez-de-chaussée), dans l'ordre de `rooms`.
@export var room_storeys: PackedInt32Array = []:
	set(value):
		room_storeys = value
		_queue_rebuild()
## Ouvertures : (x, z, étage, genre : 0 porte, 1 fenêtre, 2 porte
## verrouillée).
@export var openings: Array[Vector4] = []:
	set(value):
		openings = value
		_queue_rebuild()
## Volées : (x, z, étage de départ, sens : 0 vers +Z, 1 vers +X, 2 vers -Z,
## 3 vers -X) ; (x, z) est le milieu du bas de la volée.
@export var stairs: Array[Vector4] = []:
	set(value):
		stairs = value
		_queue_rebuild()

var _rebuild_queued: bool = false


func _ready() -> void:
	_build_plan()


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## Refait la construction (réglage changé dans l'éditeur, annulation).
func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	_parts.clear()
	built_doors.clear()
	_build_plan()
	update_gizmos()


func _build_plan() -> void:
	storeys = 1
	for i in rooms.size():
		storeys = maxi(storeys, storey_of_room(i) + 1)
	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = wall_color
	_wall_material.roughness = 0.95
	_wall_material.uv1_triplanar = true
	_wall_material.uv1_world_triplanar = true
	if not wall_texture.is_empty():
		_wall_material.set_meta(&"albedo_source", wall_texture)
	_stair_material = _plain(stair_color)
	for storey in storeys:
		_build_walls(storey)
		_build_ground_floor(storey)
	for level in range(1, storeys + 1):
		_build_level_slab(level)
	for i in stairs.size():
		_build_flight(i)


func storey_of_room(index: int) -> int:
	return room_storeys[index] if index < room_storeys.size() else 0


## Pièces de l'étage `storey`.
func rooms_at(storey: int) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for i in rooms.size():
		if storey_of_room(i) == storey:
			found.append(rooms[i])
	return found


# --- Murs ---------------------------------------------------------------------

## Murs de l'étage `storey` : lignes {clé : [axe, coordonnée, intervalles]}.
## Axe "x" : mur à x constant, le long de z ; "z" : à z constant, le long
## de x. Intervalles réunis : deux pièces qui se touchent n'ont qu'un mur.
func wall_lines(storey: int) -> Dictionary:
	var lines := {}
	for room in rooms_at(storey):
		for spec: Array in [["z", room.position.y, room.position.x, room.end.x], ["z", room.end.y, room.position.x, room.end.x],
				["x", room.position.x, room.position.y, room.end.y], ["x", room.end.x, room.position.y, room.end.y]]:
			var key := "%s%.2f" % [spec[0], spec[1]]
			if not lines.has(key):
				lines[key] = [spec[0], spec[1], []]
			(lines[key][2] as Array).append(Vector2(spec[2], spec[3]))
	for key: String in lines:
		lines[key][2] = _union(lines[key][2])
	return lines


static func _union(spans: Array) -> Array:
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array = []
	for span: Vector2 in spans:
		if not merged.is_empty() and span.x <= (merged[-1] as Vector2).y + 0.01:
			merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, span.y))
		else:
			merged.append(span)
	return merged


## Mur où tombe l'ouverture `opening` : [clé de la ligne, position le long
## du mur], ou [] si aucun mur n'est à moins de `SNAP`.
func opening_wall(opening: Vector4, lines: Dictionary) -> Array:
	var best: Array = []
	var best_distance := SNAP
	for key: String in lines:
		var line: Array = lines[key]
		var across: float = opening.x if line[0] == "x" else opening.y
		var along: float = opening.y if line[0] == "x" else opening.x
		var distance := absf(across - float(line[1]))
		if distance > best_distance:
			continue
		for span: Vector2 in line[2]:
			if along >= span.x and along <= span.y:
				best = [key, along]
				best_distance = distance
	return best


func _build_walls(storey: int) -> void:
	var lines := wall_lines(storey)
	var holes := {}
	for opening in openings:
		if int(opening.z) != storey:
			continue
		var wall := opening_wall(opening, lines)
		if wall.is_empty():
			continue
		var door := int(opening.w) != KIND_WINDOW
		var width := DOOR_WIDTH if door else WINDOW_WIDTH
		var top_of := LINTEL
		if door:
			top_of = _add_door(lines[wall[0]], float(wall[1]), storey, int(opening.w) == KIND_LOCKED_DOOR)
		(holes.get_or_add(wall[0], []) as Array).append([float(wall[1]) - width * 0.5, float(wall[1]) + width * 0.5, 0.0 if door else SILL, top_of])
	var body := _body("Walls%d" % storey, LAYER_OCCLUDERS)
	body.position.y = storey * storey_height
	var top := storey_height
	for key: String in lines:
		var line: Array = lines[key]
		var cuts: Array = holes.get(key, [])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for span: Vector2 in line[2]:
			# Prolongé d'une demi-épaisseur : les coins se ferment.
			var from := span.x - thickness * 0.5
			var to := span.y + thickness * 0.5
			var at := from
			for cut: Array in cuts:
				var a: float = cut[0]
				var b: float = cut[1]
				if b <= from or a >= to:
					continue
				_wall_piece(body, line, at, a, 0.0, top, storey)
				_wall_piece(body, line, a, b, 0.0, cut[2], storey)
				_wall_piece(body, line, a, b, cut[3], top, storey)
				at = b
			_wall_piece(body, line, at, to, 0.0, top, storey)


## Porte (`Door`) dans le mur `line`, à `along` le long du mur ; renvoie sa
## hauteur (bas du linteau).
func _add_door(line: Array, along: float, storey: int, locked: bool) -> float:
	var vertical: bool = line[0] == "x"
	var c: float = line[1]
	var door := Door.new()
	door.name = "Door%d" % built_doors.size()
	door.width = DOOR_WIDTH
	door.wall_thickness = thickness
	door.locked = locked
	# Repère de la porte : x le long du mur, z en travers (son passage).
	var basis := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT) if vertical else Basis.IDENTITY
	var at := Vector3(c, storey * storey_height, along) if vertical else Vector3(along, storey * storey_height, c)
	door.transform = Transform3D(basis, at)
	add_child(door)
	built_doors.append(door)
	return door.height


## Morceau de mur de la ligne `line`, de `from` à `to` le long du mur, de
## `bottom` à `top` (au-dessus du sol de l'étage) : une boîte de collision,
## et deux maillages (bas et haut, coupés à `CUT_HEIGHT` pour la coupe).
func _wall_piece(body: StaticBody3D, line: Array, from: float, to: float, bottom: float, top: float, storey: int) -> void:
	if to - from <= 0.01 or top - bottom <= 0.01:
		return
	var vertical: bool = line[0] == "x"
	var c: float = line[1]
	var length := to - from
	var middle := (from + to) * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(thickness, top - bottom, length) if vertical else Vector3(length, top - bottom, thickness)
	shape.shape = box
	shape.position = Vector3(c, (bottom + top) * 0.5, middle) if vertical else Vector3(middle, (bottom + top) * 0.5, c)
	body.add_child(shape)
	var cut := clampf(CUT_HEIGHT, bottom, top)
	for part: Vector2 in [Vector2(bottom, cut), Vector2(cut, top)]:
		if part.y - part.x <= 0.01:
			continue
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(thickness, part.y - part.x, length) if vertical else Vector3(length, part.y - part.x, thickness)
		mesh.mesh = cube
		mesh.material_override = _wall_material
		mesh.position = Vector3(c, (part.x + part.y) * 0.5, middle) if vertical else Vector3(middle, (part.x + part.y) * 0.5, c)
		body.add_child(mesh)
		_register(mesh, &"high" if part.x >= CUT_HEIGHT - 0.001 else &"low", storey)


# --- Sols et dalles -------------------------------------------------------------

## Sol du rez-de-chaussée (décor, sans collision : le terrain porte).
func _build_ground_floor(storey: int) -> void:
	if storey != 0:
		return
	var body := _body("Floor0", 0)
	var material := _plain(floor_color)
	for piece in _disjoint(rooms_at(0)):
		_block(body, Vector3(piece.size.x, 0.04, piece.size.y), Vector3(piece.get_center().x, 0.02, piece.get_center().y), material, &"low", 0, false)


## Dalle du niveau `level` : sol des pièces de l'étage `level`, toit de
## celles de l'étage inférieur, percée au-dessus des volées qui y arrivent.
func _build_level_slab(level: int) -> void:
	var holes: Array[Rect2] = []
	for i in stairs.size():
		if int(stairs[i].z) == level - 1:
			holes.append(flight_rect(i))
	var floors := _without(_disjoint(rooms_at(level)), holes)
	var roofs := _without(_without(_disjoint(rooms_at(level - 1)), rooms_at(level)), holes)
	var body := _body("Slab%d" % level, LAYER_SLABS)
	var y := level * storey_height - SLAB * 0.5
	for spec: Array in [[floors, _plain(floor_color)], [roofs, _plain(roof_color)]]:
		for piece: Rect2 in spec[0]:
			_block(body, Vector3(piece.size.x, SLAB, piece.size.y), Vector3(piece.get_center().x, y, piece.get_center().y), spec[1], &"slab", level)


## Rectangles qui se recouvrent → rectangles disjoints, même surface.
static func _disjoint(rects: Array[Rect2]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect in rects:
		var pieces: Array[Rect2] = [rect]
		for kept in result:
			pieces = _subtract_all(pieces, kept)
		result.append_array(pieces)
	return result


static func _without(rects: Array[Rect2], holes: Array[Rect2]) -> Array[Rect2]:
	var result := rects
	for hole in holes:
		result = _subtract_all(result, hole)
	return result


static func _subtract_all(rects: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect in rects:
		if not rect.intersects(hole):
			result.append(rect)
			continue
		var cut := rect.intersection(hole)
		# Bandes au-dessus et au-dessous du trou, puis à gauche et à droite.
		for piece: Rect2 in [
			Rect2(rect.position.x, rect.position.y, rect.size.x, cut.position.y - rect.position.y),
			Rect2(rect.position.x, cut.end.y, rect.size.x, rect.end.y - cut.end.y),
			Rect2(rect.position.x, cut.position.y, cut.position.x - rect.position.x, cut.size.y),
			Rect2(cut.end.x, cut.position.y, rect.end.x - cut.end.x, cut.size.y),
		]:
			if piece.size.x > 0.01 and piece.size.y > 0.01:
				result.append(piece)
	return result


# --- Escaliers ------------------------------------------------------------------

## Direction (repère local) d'un sens de volée.
static func direction_of(sense: int) -> Vector3:
	return [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][posmod(sense, 4)]


## Longueur au sol d'une volée.
func flight_run() -> float:
	return storey_height / tan(deg_to_rad(FLIGHT_SLOPE))


## Emprise (x, z) de la volée `index`.
func flight_rect(index: int) -> Rect2:
	var flight := stairs[index]
	var start := Vector3(flight.x, 0.0, flight.y)
	var ahead := direction_of(int(flight.w))
	var side := ahead.cross(Vector3.UP).abs() * FLIGHT_WIDTH * 0.5
	var end := start + ahead * flight_run()
	var a := Vector2(minf(start.x, end.x) - side.x, minf(start.z, end.z) - side.z)
	var b := Vector2(maxf(start.x, end.x) + side.x, maxf(start.z, end.z) + side.z)
	return Rect2(a, b - a)


## Volée `index` : rampe que la navigation suit (couche des dalles), et des
## marches dessinées dessus.
func _build_flight(index: int) -> void:
	var flight := stairs[index]
	var storey := int(flight.z)
	var ahead := direction_of(int(flight.w))
	var foot := Vector3(flight.x, storey * storey_height, flight.y)
	var head := foot + ahead * flight_run() + Vector3.UP * storey_height
	var up := (head - foot).normalized()
	var across := ahead.cross(Vector3.UP).normalized()
	var normal := across.cross(up).normalized()
	var basis := Basis(across, normal, -up)
	var body := _body("Flight%d" % index, LAYER_SLABS)
	var length := foot.distance_to(head)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FLIGHT_WIDTH, 0.2, length)
	shape.shape = box
	shape.transform = Transform3D(basis, (foot + head) * 0.5 - normal * 0.1)
	body.add_child(shape)
	var steps := maxi(2, roundi(storey_height / 0.2))
	for i in steps:
		var rise := storey_height / steps
		var tread := flight_run() / steps
		var step_size := Vector3(FLIGHT_WIDTH, rise * (i + 1), tread)
		if ahead.x != 0.0:
			step_size = Vector3(tread, rise * (i + 1), FLIGHT_WIDTH)
		var center := foot + ahead * tread * (i + 0.5) + Vector3.UP * rise * (i + 1) * 0.5
		_block(body, step_size, center, _stair_material, &"ramp", storey, false)


# --- Étages (coupe) ---------------------------------------------------------------

## Étage (0 : rez-de-chaussée, `storeys` : toit) où se trouve `point` à
## l'intérieur d'une pièce, ou sur le toit d'une pièce ; -1 dehors.
func storey_of(point: Vector3) -> int:
	return _storey_at(to_local(point), thickness)


func _content_storey(point: Vector3) -> int:
	return _storey_at(to_local(point), 0.0)


func _storey_at(local: Vector3, margin: float) -> int:
	if local.y < -0.5 or local.y > storeys * storey_height + 3.0:
		return -1
	var storey := clampi(floori((local.y + 0.3) / storey_height), 0, storeys)
	var spot := Vector2(local.x, local.z)
	for level: int in [storey, storey - 1]:
		if level < 0:
			continue
		for room in rooms_at(level):
			if room.grow(-margin).has_point(spot):
				return storey
	return -1
