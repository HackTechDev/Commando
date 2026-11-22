@tool
class_name Tower
extends Node3D
## Immeuble à étages : `storeys` niveaux de `storey_height` m, des dalles
## solides entre eux, un toit-terrasse accessible bordé d'un parapet, et un
## escalier à volées alternées le long du mur nord (côté -Z).
##
## Escalier : deux couloirs côte à côte le long du mur nord. Les étages pairs
## montent dans le couloir contre le mur, vers +X ; les impairs dans le
## couloir voisin, vers -X. Un palier à chaque bout permet de passer d'une
## volée à l'autre. Chaque dalle est percée au-dessus de la volée qui y
## arrive. Une volée est une rampe (pente d'environ 31°) que la navigation
## suit ; des marches la dessinent.
##
## Coupe : quand un opérateur est dedans, l'étage le plus bas occupé
## s'affiche en coupe et tout ce qui est au-dessus s'efface en fondu (murs,
## dalles, volées). Le niveau de vue choisi par le joueur (`Roof.view_level`,
## touches d'étage) fait de même. Les parties effacées laissent passer les
## clics (`is_revealed_body`) mais restent solides (vue, balles, marche).
##
## Repère : centré sur l'origine, au sol. Côtés et ouvertures comme
## `Building` : 0 vers +Z, 1 vers +X, 2 vers -Z, 3 vers -X ; décalage le
## long du côté, de gauche à droite vu de dehors.

const GROUP := &"towers"
## Dalles et volées : sol (marche, clics) et obstacle (vue, balles).
const LAYER_SLABS := 0b11
const LAYER_OCCLUDERS := 0b10
const CUT_HEIGHT := 1.2
const FADE_TIME := 0.3
const CHECK_INTERVAL := 0.1
const SLAB := 0.25
const PARAPET := 1.0
## Escalier : largeur d'un couloir, longueur d'une volée, des paliers (m),
## nombre de marches dessinées par volée.
const LANE := 2.0
const RUN := 5.4
const LANDING := 1.6
const STEPS := 16
## Épaisseur de la cloison entre les couloirs (m) : assez pour que la
## navigation la contourne de tout le rayon des unités.
const DIVIDER := 0.3
## Fenêtres : largeur, appui, linteau (m, depuis le sol de l'étage).
const WINDOW_WIDTH := 1.3
const SILL := 0.9
const LINTEL := 2.1
const DOOR_WIDTH := 1.2
## Contenu masqué au-dessus de la coupe (caisses, cachettes, ennemis et
## corps) ; les opérateurs restent toujours affichés.
const CONTENT_GROUPS: Array[StringName] = [&"climbables", &"hiding_spots", &"all_enemies"]

@export var storeys: int = 5
@export var storey_height: float = 3.2
## Emprise au sol (x, z) et épaisseur des murs.
@export var size := Vector2(16.0, 12.0)
@export var thickness: float = 0.3
## Portes du rez-de-chaussée : (côté, décalage, verrouillée 0 ou 1).
@export var doors: Array[Vector3] = [Vector3(0, 0, 0)]
## Fenêtres, à chaque étage : (côté, décalage). Au rez-de-chaussée, une
## porte au même endroit l'emporte.
@export var windows: Array[Vector2] = []
@export var wall_color := Color(0.62, 0.6, 0.56)
@export var wall_texture: String = "tex_ctp1/bricks_g_1.jpg"
@export var floor_color := Color(0.45, 0.42, 0.38)
@export var roof_color := Color(0.3, 0.3, 0.3)
@export var stair_color := Color(0.5, 0.48, 0.44)

## Étage affiché en coupe (tout ce qui est au-dessus est effacé), ou -1.
var cut_storey: int = -1
var built_doors: Array[Door] = []

## Parties qui s'effacent : {"mesh", "kind", "storey", "fade"}. `kind` :
## &"low" (bas de mur), &"high" (haut de mur), &"slab" (dalle d'un étage,
## `storey` = étage dont elle est le sol), &"ramp", &"parapet".
var _parts: Array[Dictionary] = []
var _check_left: float = 0.0
var _wall_material: StandardMaterial3D
var _stair_material: StandardMaterial3D
var _settled: bool = true
## Contenu masqué par la coupe (rendu visible quand elle change).
var _hidden_content: Array[Node3D] = []


## Immeuble dont l'intérieur contient `point`, ou null.
static func at(tree: SceneTree, point: Vector3) -> Tower:
	for node in tree.get_nodes_in_group(GROUP):
		var tower := node as Tower
		if tower and tower.storey_of(point) >= 0 and tower.storey_of(point) < tower.storeys:
			return tower
	return null


## Vrai si `collider`, touché en `point`, est une partie effacée d'un
## immeuble en coupe : au-dessus de la hauteur de coupe de l'étage affiché.
static func is_revealed_body(collider: Object, point: Vector3 = Vector3.INF) -> bool:
	var body := collider as Node
	if body == null or not body.has_meta(&"tower"):
		return false
	var tower := body.get_meta(&"tower") as Tower
	if tower == null or tower.cut_storey < 0 or point == Vector3.INF:
		return false
	return point.y > tower.global_position.y + tower.cut_storey * tower.storey_height + CUT_HEIGHT


## Étage (0 : rez-de-chaussée, `storeys` : toit) où se trouve `point` à
## l'intérieur, ou -1 dehors.
func storey_of(point: Vector3) -> int:
	var local := to_local(point)
	if absf(local.x) >= size.x * 0.5 - thickness or absf(local.z) >= size.y * 0.5 - thickness:
		return -1
	if local.y < -0.5 or local.y > storeys * storey_height + 3.0:
		return -1
	return clampi(floori((local.y + 0.3) / storey_height), 0, storeys)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)


func _ready() -> void:
	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = wall_color
	_wall_material.roughness = 0.95
	_wall_material.uv1_triplanar = true
	_wall_material.uv1_world_triplanar = true
	if not wall_texture.is_empty():
		_wall_material.set_meta(&"albedo_source", wall_texture)
	_stair_material = _plain(stair_color)
	for storey in storeys:
		for side in 4:
			_build_side(side, storey)
		_build_divider(storey)
		_build_ramp(storey)
	for level in range(1, storeys + 1):
		_build_slab(level)
	_build_parapet()


func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _body(name_hint: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_hint
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta(&"tower", self)
	add_child(body)
	return body


func _register(mesh: MeshInstance3D, kind: StringName, storey: int) -> void:
	_parts.append({"mesh": mesh, "kind": kind, "storey": storey, "fade": 0.0})


## Boîte de collision et maillage (repère de `body`).
func _block(body: StaticBody3D, size_: Vector3, at: Vector3, material: Material, kind: StringName, storey: int, collide: bool = true) -> MeshInstance3D:
	if size_.x <= 0.01 or size_.y <= 0.01 or size_.z <= 0.01:
		return null
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size_
		shape.shape = box
		shape.position = at
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size_
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = at
	body.add_child(mesh)
	_register(mesh, kind, storey)
	return mesh


# --- Murs -----------------------------------------------------------------------

func _side_frame(side: int) -> Dictionary:
	var hx := size.x * 0.5 - thickness * 0.5
	var hz := size.y * 0.5 - thickness * 0.5
	match side:
		0:
			return {"center": Vector3(0, 0, hz), "along": Vector3.RIGHT, "out": Vector3.BACK, "length": size.x}
		1:
			return {"center": Vector3(hx, 0, 0), "along": Vector3.FORWARD, "out": Vector3.RIGHT, "length": size.y - 2.0 * thickness}
		2:
			return {"center": Vector3(0, 0, -hz), "along": Vector3.LEFT, "out": Vector3.FORWARD, "length": size.x}
	return {"center": Vector3(-hx, 0, 0), "along": Vector3.BACK, "out": Vector3.LEFT, "length": size.y - 2.0 * thickness}


## Murs du côté `side` à l'étage `storey`, percés de fenêtres (et des portes
## au rez-de-chaussée).
func _build_side(side: int, storey: int) -> void:
	var frame := _side_frame(side)
	var along: Vector3 = frame["along"]
	var length: float = frame["length"]
	var base := storey * storey_height
	var basis := Basis(along, Vector3.UP, frame["out"])
	var body := _body("Wall%d_%d" % [storey, side], LAYER_OCCLUDERS)
	body.transform = Transform3D(basis, (frame["center"] as Vector3) + Vector3.UP * base)
	# Ouvertures : [début, fin, porte (Vector3) ou fenêtre (Vector2)].
	var openings: Array[Array] = []
	if storey == 0:
		for door in doors:
			if int(door.x) == side:
				openings.append([door.y - DOOR_WIDTH * 0.5, door.y + DOOR_WIDTH * 0.5, door])
	for window in windows:
		if int(window.x) != side:
			continue
		var start := window.y - WINDOW_WIDTH * 0.5
		var end := window.y + WINDOW_WIDTH * 0.5
		if openings.any(func(other: Array) -> bool: return start < other[1] and end > other[0]):
			continue
		openings.append([start, end, window])
	openings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := -length * 0.5
	for opening in openings:
		_wall_block(body, cursor, opening[0], 0.0, storey_height, storey)
		if opening[2] is Vector3:
			var spec: Vector3 = opening[2]
			var door := Door.new()
			door.name = "Door%d" % built_doors.size()
			door.width = DOOR_WIDTH
			door.wall_thickness = thickness
			door.locked = spec.z > 0.5
			door.transform = Transform3D(basis, (frame["center"] as Vector3) + along * (float(opening[0]) + float(opening[1])) * 0.5)
			add_child(door)
			built_doors.append(door)
			_wall_block(body, opening[0], opening[1], door.height, storey_height, storey)
		else:
			_wall_block(body, opening[0], opening[1], 0.0, SILL, storey)
			_wall_block(body, opening[0], opening[1], LINTEL, storey_height, storey)
		cursor = opening[1]
	_wall_block(body, cursor, length * 0.5, 0.0, storey_height, storey)


## Bloc de mur, coupé en deux maillages à la hauteur de coupe.
func _wall_block(body: StaticBody3D, from: float, to: float, bottom: float, top: float, storey: int) -> void:
	if to - from <= 0.01 or top - bottom <= 0.01:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(to - from, top - bottom, thickness)
	shape.shape = box
	shape.position = Vector3((from + to) * 0.5, (bottom + top) * 0.5, 0.0)
	body.add_child(shape)
	var cut := clampf(CUT_HEIGHT, bottom, top)
	for part: Vector2 in [Vector2(bottom, cut), Vector2(cut, top)]:
		if part.y - part.x <= 0.01:
			continue
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(to - from, part.y - part.x, thickness)
		mesh.mesh = cube
		mesh.material_override = _wall_material
		mesh.position = Vector3((from + to) * 0.5, (part.x + part.y) * 0.5, 0.0)
		body.add_child(mesh)
		_register(mesh, &"high" if part.x >= CUT_HEIGHT - 0.001 else &"low", storey)


# --- Escalier -------------------------------------------------------------------

## Bornes de l'intérieur (x0, x1, z0, z1, repère local).
func _interior() -> Rect2:
	return Rect2(-size.x * 0.5 + thickness, -size.y * 0.5 + thickness, size.x - 2.0 * thickness, size.y - 2.0 * thickness)


## Bas et haut de volée (x) et couloir (z de début) de la volée `storey`.
func _flight(storey: int) -> Dictionary:
	var inside := _interior()
	var x0 := inside.position.x + LANDING
	var x1 := x0 + RUN
	var z := inside.position.y + (0.0 if storey % 2 == 0 else LANE)
	return {"from": x0 if storey % 2 == 0 else x1, "to": x1 if storey % 2 == 0 else x0, "z": z, "x0": x0, "x1": x1}


## Volée de l'étage `storey` vers le suivant : rampe et marches.
func _build_ramp(storey: int) -> void:
	var flight := _flight(storey)
	var from: float = flight["from"]
	var to: float = flight["to"]
	var z: float = float(flight["z"]) + LANE * 0.5
	var low := Vector3(from, storey * storey_height, z)
	var high := Vector3(to, (storey + 1) * storey_height, z)
	var direction := (high - low).normalized()
	var length := low.distance_to(high) + 0.3
	var up := direction.cross(Vector3.BACK if to > from else Vector3.FORWARD).normalized()
	if up.y < 0.0:
		up = -up
	var basis := Basis(direction, up, direction.cross(up)).orthonormalized()
	var body := _body("Ramp%d" % storey, LAYER_SLABS)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.2, LANE)
	shape.shape = box
	shape.transform = Transform3D(basis, (low + high) * 0.5 - up * 0.1)
	body.add_child(shape)
	# Limon (plan incliné sous les marches) et marches.
	var stringer := MeshInstance3D.new()
	var plank := BoxMesh.new()
	plank.size = Vector3(length - 0.3, 0.12, LANE)
	stringer.mesh = plank
	stringer.material_override = _stair_material
	stringer.transform = Transform3D(basis, (low + high) * 0.5 - up * 0.16)
	body.add_child(stringer)
	_register(stringer, &"ramp", storey)
	var tread := RUN / STEPS
	var rise := storey_height / STEPS
	var sign_x := signf(to - from)
	for i in STEPS:
		var step := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(tread, rise, LANE)
		step.mesh = cube
		step.material_override = _stair_material
		step.position = Vector3(from + sign_x * tread * (i + 0.5), storey * storey_height + rise * (i + 0.5), z)
		body.add_child(step)
		_register(step, &"ramp", storey)


## Cloison entre les deux couloirs de l'escalier, sur la longueur des volées.
func _build_divider(storey: int) -> void:
	var flight := _flight(0)
	var x0: float = flight["x0"]
	var x1: float = flight["x1"]
	var z := _interior().position.y + LANE
	var body := _body("Divider%d" % storey, LAYER_OCCLUDERS)
	body.position = Vector3((x0 + x1) * 0.5, storey * storey_height, z)
	var top := storey_height - SLAB
	var cut := minf(CUT_HEIGHT, top)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, top, DIVIDER)
	shape.shape = box
	shape.position.y = top * 0.5
	body.add_child(shape)
	for part: Vector2 in [Vector2(0.0, cut), Vector2(cut, top)]:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(x1 - x0, part.y - part.x, DIVIDER)
		mesh.mesh = cube
		mesh.material_override = _wall_material
		mesh.position.y = (part.x + part.y) * 0.5
		body.add_child(mesh)
		_register(mesh, &"high" if part.x > 0.0 else &"low", storey)


# --- Dalles et toit -------------------------------------------------------------

## Dalle du niveau `level` (sol de cet étage ; `storeys` : toit), percée
## au-dessus de la volée qui y arrive, avec un garde-corps le long du vide.
func _build_slab(level: int) -> void:
	var inside := _interior()
	var flight := _flight(level - 1)
	var hole := Rect2(float(flight["x0"]), float(flight["z"]), RUN, LANE)
	var top := level * storey_height
	var body := _body("Slab%d" % level, LAYER_SLABS)
	var material := _plain(roof_color if level == storeys else floor_color)
	var y := top - SLAB * 0.5
	var ax0 := inside.position.x
	var ax1 := inside.end.x
	var az0 := inside.position.y
	var az1 := inside.end.y
	var pieces: Array[Rect2] = [
		Rect2(ax0, az0, hole.position.x - ax0, az1 - az0),
		Rect2(hole.end.x, az0, ax1 - hole.end.x, az1 - az0),
		Rect2(hole.position.x, az0, hole.size.x, hole.position.y - az0),
		Rect2(hole.position.x, hole.end.y, hole.size.x, az1 - hole.end.y),
	]
	for piece in pieces:
		_block(body, Vector3(piece.size.x, SLAB, piece.size.y), Vector3(piece.get_center().x, y, piece.get_center().y), material, &"slab", level)
	# Garde-corps (décor) côté pièce, et au bout opposé à l'arrivée.
	var rail := _plain(Color(0.2, 0.2, 0.22))
	var open_z := hole.end.y
	_block(body, Vector3(RUN, 0.06, 0.06), Vector3(hole.get_center().x, top + 1.0, open_z), rail, &"slab", level, false)
	for i in 5:
		_block(body, Vector3(0.05, 1.0, 0.05), Vector3(hole.position.x + RUN * i / 4.0, top + 0.5, open_z), rail, &"slab", level, false)
	var dead_end: float = flight["from"]
	_block(body, Vector3(0.06, 0.06, LANE), Vector3(dead_end, top + 1.0, hole.get_center().y), rail, &"slab", level, false)


## Parapet autour du toit-terrasse.
func _build_parapet() -> void:
	var body := _body("Parapet", LAYER_OCCLUDERS)
	body.position.y = storeys * storey_height
	var material := _wall_material
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var t := thickness
	_block(body, Vector3(size.x, PARAPET, t), Vector3(0, PARAPET * 0.5, hz - t * 0.5), material, &"parapet", storeys)
	_block(body, Vector3(size.x, PARAPET, t), Vector3(0, PARAPET * 0.5, -hz + t * 0.5), material, &"parapet", storeys)
	_block(body, Vector3(t, PARAPET, size.y - 2.0 * t), Vector3(hx - t * 0.5, PARAPET * 0.5, 0), material, &"parapet", storeys)
	_block(body, Vector3(t, PARAPET, size.y - 2.0 * t), Vector3(-hx + t * 0.5, PARAPET * 0.5, 0), material, &"parapet", storeys)


# --- Coupe ----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		var level := _wanted_cut()
		if level != cut_storey:
			cut_storey = level
			_settled = false
			for door in built_doors:
				door.set_cutaway(cut_storey == 0)
		_update_content()
	if not _settled:
		_update_fades(delta)


## Étage à afficher en coupe : le plus bas occupé par un opérateur (le toit
## ne coupe rien), borné par le niveau de vue choisi ; -1 : aucun.
func _wanted_cut() -> int:
	var level := -1
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead:
			continue
		var storey := storey_of(unit.global_position + Vector3.UP * 0.3)
		if storey >= 0 and storey < storeys and (level < 0 or storey < level):
			level = storey
	if Roof.view_level >= 0 and Roof.view_level < storeys:
		level = Roof.view_level if level < 0 else mini(level, Roof.view_level)
	return level


## Masque ce qui se trouve dans l'immeuble au-dessus de l'étage coupé (une
## unité qui y monte ou en descend est réévaluée à chaque contrôle).
func _update_content() -> void:
	var still: Array[Node3D] = []
	if cut_storey >= 0:
		for group in CONTENT_GROUPS:
			for node in get_tree().get_nodes_in_group(group):
				var item := node as Node3D
				if item == null:
					continue
				var storey := _content_storey(item.global_position)
				if storey > cut_storey:
					item.visible = false
					still.append(item)
	for item in _hidden_content:
		if is_instance_valid(item) and not still.has(item):
			item.visible = true
	_hidden_content = still


## Étage d'un objet posé dans l'immeuble (toit compris), ou -1 dehors.
func _content_storey(point: Vector3) -> int:
	var local := to_local(point)
	if absf(local.x) >= size.x * 0.5 or absf(local.z) >= size.y * 0.5:
		return -1
	if local.y < -0.5 or local.y > storeys * storey_height + 3.0:
		return -1
	return clampi(floori((local.y + 0.3) / storey_height), 0, storeys)


## Vrai si la partie doit être effacée pour la coupe `level`.
func _hidden(part: Dictionary, level: int) -> bool:
	if level < 0:
		return false
	var storey: int = part["storey"]
	match part["kind"]:
		&"low", &"ramp":
			return storey > level
		&"high":
			return storey >= level
		&"slab":
			return storey > level
	return true


func _update_fades(delta: float) -> void:
	var settled := true
	for part in _parts:
		var goal := 1.0 if _hidden(part, cut_storey) else 0.0
		var fade: float = part["fade"]
		if is_equal_approx(fade, goal):
			continue
		fade = move_toward(fade, goal, delta / FADE_TIME)
		part["fade"] = fade
		var mesh := part["mesh"] as MeshInstance3D
		MeshFade.apply(mesh, fade)
		mesh.visible = fade < 0.999
		if not is_equal_approx(fade, goal):
			settled = false
	_settled = settled
