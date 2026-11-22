@tool
class_name Building
extends Node3D
## Bâtiment où l'on entre : quatre murs percés de portes (`Door`) et de
## fenêtres (`WallWindow`), un sol et un toit plat. Quand un opérateur est à
## l'intérieur, il s'affiche en coupe : le toit et le haut des murs
## s'effacent en fondu (les clics les traversent alors, `is_revealed_body`),
## pour qu'on voie l'intérieur ; ils restent solides (vue, balles, marche).
## Un corps déposé à l'intérieur est à l'abri des regards (`Enemy.is_hidden_body`).
##
## Repère : centré sur l'origine, au sol. Côtés : 0 vers +Z, 1 vers +X,
## 2 vers -Z, 3 vers -X ; une ouverture se place par son décalage le long du
## côté (de gauche à droite, vu de l'extérieur).

const GROUP := &"buildings"
const LAYER_OCCLUDERS := 0b10
## Hauteur jusqu'à laquelle les murs restent affichés en coupe.
const CUT_HEIGHT := 1.2
const FADE_TIME := 0.3
const CHECK_INTERVAL := 0.1
const ROOF_THICKNESS := 0.2
const ROOF_OVERHANG := 0.15

## Emprise au sol (x, z), hauteur et épaisseur des murs.
@export var size := Vector2(8.0, 6.0)
@export var wall_height: float = 3.0
@export var thickness: float = 0.3
## Portes : (côté, décalage, verrouillée 0 ou 1).
@export var doors: Array[Vector3] = [Vector3(0, 0, 0)]
## Fenêtres : (côté, décalage).
@export var windows: Array[Vector2] = []
@export var wall_color := Color(0.72, 0.66, 0.6)
@export var wall_texture: String = "tex_ctp1/bricks_g_1.jpg"
@export var roof_color := Color(0.33, 0.3, 0.28)
@export var floor_color := Color(0.42, 0.36, 0.3)

## Vrai quand le bâtiment est affiché en coupe (un opérateur dedans).
var is_cut: bool = false
var built_doors: Array[Door] = []
var built_windows: Array[WallWindow] = []
var roof_body: StaticBody3D

## Maillages qui s'effacent en coupe (toit, haut des murs).
var _cut_meshes: Array[MeshInstance3D] = []
var _wall_bodies: Array[StaticBody3D] = []
var _fade: float = 0.0
var _check_left: float = 0.0
var _wall_material: StandardMaterial3D


## Bâtiment dont l'intérieur contient `point`, ou null.
static func at(tree: SceneTree, point: Vector3) -> Building:
	for node in tree.get_nodes_in_group(GROUP):
		var building := node as Building
		if building and building.contains(point):
			return building
	return null


## Vrai si `collider` (touché en `point`) est une partie effacée d'un
## bâtiment vu en coupe : le toit, ou le haut d'un mur.
static func is_revealed_body(collider: Object, point: Vector3 = Vector3.INF) -> bool:
	var body := collider as Node
	if body == null or not body.has_meta(&"building"):
		return false
	var building := body.get_meta(&"building") as Building
	if building == null or not building.is_cut:
		return false
	if body == building.roof_body:
		return true
	return point != Vector3.INF and point.y > building.global_position.y + CUT_HEIGHT


## Vrai si `point` est à l'intérieur (entre les murs, sous le toit).
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) < size.x * 0.5 - thickness and absf(local.z) < size.y * 0.5 - thickness \
		and local.y > -0.5 and local.y < wall_height


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
	for side in 4:
		_build_side(side)
	_build_floor()
	_build_roof()


## Repère d'un côté : centre du mur, direction le long du mur (de gauche à
## droite vu de dehors), normale vers l'extérieur, longueur.
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


func _build_side(side: int) -> void:
	var frame := _side_frame(side)
	var along: Vector3 = frame["along"]
	var out: Vector3 = frame["out"]
	var center: Vector3 = frame["center"]
	var length: float = frame["length"]
	var basis := Basis(along, Vector3.UP, out)
	# Ouvertures de ce côté : [début, fin, porte (Vector3) ou fenêtre (Vector2)].
	var openings: Array[Array] = []
	for door in doors:
		if int(door.x) == side:
			var width := 1.1
			openings.append([door.y - width * 0.5, door.y + width * 0.5, door])
	for window in windows:
		if int(window.x) == side:
			var width := 1.2
			openings.append([window.y - width * 0.5, window.y + width * 0.5, window])
	openings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var body := StaticBody3D.new()
	body.name = "Wall%d" % side
	body.collision_layer = LAYER_OCCLUDERS
	body.collision_mask = 0
	body.set_meta(&"building", self)
	body.transform = Transform3D(basis, center)
	add_child(body)
	_wall_bodies.append(body)
	var cursor := -length * 0.5
	for opening in openings:
		var start: float = maxf(opening[0], cursor)
		_wall_block(body, cursor, start, 0.0, wall_height)
		var middle := (float(opening[0]) + float(opening[1])) * 0.5
		var place := Transform3D(basis, center + along * middle)
		if opening[2] is Vector3:
			var spec: Vector3 = opening[2]
			var door := Door.new()
			door.name = "Door%d" % built_doors.size()
			door.width = float(opening[1]) - float(opening[0])
			door.wall_thickness = thickness
			door.locked = spec.z > 0.5
			door.transform = place
			add_child(door)
			built_doors.append(door)
			_wall_block(body, opening[0], opening[1], door.height, wall_height)
		else:
			var window := WallWindow.new()
			window.name = "Window%d" % built_windows.size()
			window.width = float(opening[1]) - float(opening[0])
			window.wall_height = wall_height
			window.thickness = thickness
			window.color = wall_color
			window.texture = wall_texture
			window.transform = place
			window.set_meta(&"building", self)
			add_child(window)
			built_windows.append(window)
		cursor = opening[1]
	_wall_block(body, cursor, length * 0.5, 0.0, wall_height)


## Bloc de mur de `from` à `to` (le long du côté), de `bottom` à `top` :
## une forme et deux maillages (sous et au-dessus de la hauteur de coupe).
func _wall_block(body: StaticBody3D, from: float, to: float, bottom: float, top: float) -> void:
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
		if part.x >= CUT_HEIGHT - 0.001:
			_cut_meshes.append(mesh)


## Sol intérieur : un plancher affiché (le sol de la carte porte les unités).
func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = size - Vector2.ONE * thickness
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = floor_color
	material.roughness = 0.9
	floor_mesh.material_override = material
	floor_mesh.position.y = 0.015
	add_child(floor_mesh)


func _build_roof() -> void:
	roof_body = StaticBody3D.new()
	roof_body.name = "Roof"
	roof_body.collision_layer = LAYER_OCCLUDERS
	roof_body.collision_mask = 0
	roof_body.set_meta(&"building", self)
	roof_body.position.y = wall_height + ROOF_THICKNESS * 0.5
	add_child(roof_body)
	var extent := Vector3(size.x + ROOF_OVERHANG * 2.0, ROOF_THICKNESS, size.y + ROOF_OVERHANG * 2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent
	shape.shape = box
	roof_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = extent
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = roof_color
	material.roughness = 0.9
	mesh.material_override = material
	roof_body.add_child(mesh)
	_cut_meshes.append(mesh)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		var occupied := false
		for node in get_tree().get_nodes_in_group(&"commandos"):
			var unit := node as Commando
			if unit and not unit.is_dead and contains(unit.global_position + Vector3.UP * 0.3):
				occupied = true
				break
		if occupied != is_cut:
			set_cut(occupied)
	var goal := 1.0 if is_cut else 0.0
	if not is_equal_approx(_fade, goal):
		_fade = move_toward(_fade, goal, delta / FADE_TIME)
		_apply_fade()


## Affiche le bâtiment en coupe (`cut`) ou entier.
func set_cut(cut: bool) -> void:
	is_cut = cut
	for door in built_doors:
		door.set_cutaway(cut)
	for window in built_windows:
		window.set_cutaway(cut)


func _apply_fade() -> void:
	for mesh in _cut_meshes:
		MeshFade.apply(mesh, _fade)
		mesh.visible = _fade < 0.999
