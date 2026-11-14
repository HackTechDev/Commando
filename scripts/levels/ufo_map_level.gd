class_name UfoMapLevel
extends Node3D
## Construit un niveau à partir d'une carte source UFO:AI (`UfoMap`) lue à la
## volée dans le dossier des cartes (`AssetPaths.maps_dir`) : maillage
## texturé, collisions, caisses escaladables et déplaçables, opérateurs placés
## sur les points de départ, ennemis en faction sur les positions des aliens.
##
## À placer sous le `NavigationRegion3D` du niveau : son `_ready` s'exécute
## avant celui de `LevelRoot`, qui génère ensuite la navigation à partir des
## collisions créées ici.

## Pieds d'une unité sous l'origine de son point de départ (unités UFO:AI).
const FEET_BELOW_ORIGIN := 24.0
## Un brush visible pas plus haut que ceci est du sol (ne masque pas la vue).
const GROUND_MAX_HEIGHT := 8.0
## Faces lissées entre elles (drapeau « phong ») sous cet angle.
const PHONG_MAX_ANGLE := deg_to_rad(60.0)
const EPSILON := 0.01
const BASE_WINDING_SIZE := 16384.0
const DEFAULT_TEXTURE_SIZE := Vector2(256.0, 256.0)
## Caisse convertie en `Climbable` : cube de cette taille (unités UFO:AI),
## posé au sol, rien dessus.
## Durée maximale d'une tranche de construction avant d'afficher une image (µs).
const SLICE_USEC := 25000
const CRATE_SIZE := 32.0
const CRATE_TOLERANCE := 0.5
const CRATE_SCENE: PackedScene = preload("res://scenes/props/crate.tscn")
## Hauteur (m) du dessus d'un mur pour en faire des corniches : au-dessus de
## ce qu'on escalade depuis le sol, à portée depuis le dessus d'une caisse.
const LEDGE_MIN_HEIGHT := 1.5
const LEDGE_MAX_HEIGHT := 1.2 + Climbable.MAX_CLIMB_HEIGHT
## Place libre (m) au-dessus d'une corniche pour s'y tenir debout.
const LEDGE_HEADROOM := 1.8
const LAYER_GROUND := 1
const LAYER_WALLS := 2
## Textures techniques (invisibles) d'UFO:AI.
const TECHNICAL_PREFIX := "tex_common/"
const NON_SOLID_TEXTURES: Array[String] = ["tex_common/trigger", "tex_common/hint", "tex_common/origin", "tex_common/lightclip", "tex_common/weaponclip"]
## Axes de projection des textures de Quake 2 : normale de référence, axe
## horizontal, axe vertical de la texture.
const BASE_AXES: Array = [
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0)],
	[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)],
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
]

## Fichier de la carte, relatif au dossier des cartes.
@export var map_file: String = "training_a.map"
## Échelle : unités UFO:AI par mètre. Par défaut, une case de 32 unités fait
## 1,2 m, comme les caisses du jeu (animations d'escalade) ; un étage de
## 64 unités fait 2,4 m.
@export var units_per_meter: float = 32.0 / 1.2
## Les caisses de la carte (cubes d'une case posés au sol, rien dessus, dont
## toutes les textures commencent par l'un de ces préfixes) deviennent des
## caisses escaladables et déplaçables.
@export var movable_crates: bool = true
@export var crate_textures: PackedStringArray = ["tex_misc/box", "tex_misc/crate"]
## Convertit les bidons d'une case posés au sol en bidons qu'on pousse et
## qu'on tire (sans monter dessus).
@export var movable_barrels: bool = true
@export var barrel_textures: PackedStringArray = ["tex_misc/barrel"]
## Découpe le dessus des murs bas (accessibles depuis une caisse) en
## corniches où l'on peut se tenir.
@export var ledges: bool = true
## Opérateurs à placer sur les points de départ (`info_player_start`).
@export var units_parent: NodePath
## Ennemis créés sur les positions des aliens (`info_alien_start`).
@export var enemy_scene: PackedScene
@export var enemies_parent: NodePath
## Nombre maximal d'ennemis créés (-1 : tous).
@export var max_enemies: int = -1
## Caméra dont les limites sont réglées sur la carte.
@export var camera_rig: NodePath

## Emprise de la carte dans le monde (mètres), une fois construite.
var map_bounds: AABB
## Origine de la carte (unités UFO:AI) placée à l'origine du monde.
var _offset: Vector3 = Vector3.ZERO
var _materials: Dictionary = {}


## Émis quand le niveau est construit (géométrie, objets, unités placées).
signal built

## Vrai une fois le niveau construit.
var is_built: bool = false
## Étape en cours, pour l'écran de chargement.
var build_stage: String = ""


func _ready() -> void:
	_build_level()


## Construction répartie sur plusieurs images (l'écran de chargement reste
## animé) : lecture et découpe des brushes sur un fil de travail, puis
## maillages et collisions par tranches de `SLICE_USEC`.
func _build_level() -> void:
	build_stage = "Lecture de la carte"
	var path := AssetPaths.maps_dir().path_join(map_file)
	var loaded: Dictionary = await _run_in_thread(func() -> Dictionary:
		var parsed := UfoMap.load_file(path)
		if parsed == null:
			return {}
		return {"map": parsed, "solids": _collect_brushes(parsed)})
	if not is_inside_tree():
		return
	if loaded.is_empty():
		_finish_build()
		return
	var map: UfoMap = loaded["map"]
	var solids: Array[Dictionary] = loaded["solids"]
	_compute_offset(map, solids)
	build_stage = "Chargement des textures"
	await get_tree().process_frame
	_load_textures(solids)
	var crates := _extract_crates(solids)
	build_stage = "Construction du décor"
	await _build(solids)
	if not is_inside_tree():
		return
	_build_crates(crates)
	if ledges:
		_build_ledges(solids)
	await get_tree().process_frame
	TextureLibrary.apply_to_tree(self)
	_place_units(map)
	_spawn_enemies(map)
	_setup_camera()
	_finish_build()


func _finish_build() -> void:
	build_stage = ""
	is_built = true
	built.emit()


## Exécute `task` sur un fil de travail et rend son résultat, sans bloquer
## l'affichage.
func _run_in_thread(task: Callable) -> Variant:
	var result := []
	var id := WorkerThreadPool.add_task(func() -> void: result.append(task.call()), true)
	while not WorkerThreadPool.is_task_completed(id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	return result[0]


## Rend la main pour une image si la tranche de calcul en cours a dépassé
## `SLICE_USEC`. `slice` : [début de la tranche, en µs].
func _yield_if_slice_spent(slice: Array) -> void:
	if Time.get_ticks_usec() - slice[0] > SLICE_USEC:
		await get_tree().process_frame
		slice[0] = Time.get_ticks_usec()


## Point en unités UFO:AI → point du monde (Y vers le haut, mètres).
func to_world(point: Vector3) -> Vector3:
	var p := point - _offset
	return Vector3(p.x, p.z, -p.y) / units_per_meter


## Lacet UFO:AI (degrés, depuis +X autour de Z) → rotation Y de Godot.
static func yaw_to_world(angle_degrees: float) -> float:
	return deg_to_rad(angle_degrees - 90.0)


# --- Brushes ----------------------------------------------------------------

## Brushes retenus, avec leurs polygones : [{brush, polygons, kind}].
## `kind` : &"solid" (visible), &"clip" (invisible mais bloquant),
## &"passable" (visible, sans collision).
func _collect_brushes(map: UfoMap) -> Array[Dictionary]:
	var solids: Array[Dictionary] = []
	for entity in map.entities:
		if entity.classname().begins_with("trigger_"):
			continue
		for brush in entity.brushes:
			var kind := _brush_kind(brush)
			if kind == &"":
				continue
			var polygons := _brush_polygons(brush)
			if polygons.is_empty():
				continue
			solids.append({"brush": brush, "polygons": polygons, "kind": kind})
	return solids


func _brush_kind(brush: UfoMap.Brush) -> StringName:
	var contents := brush.contents()
	if contents & UfoMap.CONTENTS_ACTORCLIP:
		return &"clip"
	if brush.all_textures_start_with(TECHNICAL_PREFIX):
		for face in brush.faces:
			if NON_SOLID_TEXTURES.has(face.texture):
				return &""
		return &"clip"
	if contents & UfoMap.CONTENTS_PASSABLE:
		return &"passable"
	return &"solid"


## Polygone de chaque face (unités UFO:AI) : [{face, points}], points dans le
## sens trigonométrique autour de la normale.
func _brush_polygons(brush: UfoMap.Brush) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in brush.faces.size():
		var plane := brush.faces[i].plane
		var points := _base_winding(plane)
		for j in brush.faces.size():
			if j != i:
				points = _clip(points, brush.faces[j].plane)
				if points.size() < 3:
					break
		points = _cleanup(points)
		if points.size() < 3:
			continue
		if (points[1] - points[0]).cross(points[2] - points[0]).dot(plane.normal) < 0.0:
			points.reverse()
		result.append({"face": brush.faces[i], "points": points})
	return result


## Grand carré sur le plan, réduit ensuite par les autres plans du brush.
func _base_winding(plane: Plane) -> PackedVector3Array:
	var normal := plane.normal
	var up := Vector3(0, 0, 1) if absf(normal.z) < 0.9 else Vector3(1, 0, 0)
	var right := up.cross(normal).normalized()
	up = normal.cross(right).normalized()
	var center := normal * plane.d
	right *= BASE_WINDING_SIZE
	up *= BASE_WINDING_SIZE
	return PackedVector3Array([center - right + up, center + right + up, center + right - up, center - right - up])


## Garde la partie du polygone derrière le plan (intérieur du brush).
func _clip(points: PackedVector3Array, plane: Plane) -> PackedVector3Array:
	var out := PackedVector3Array()
	var count := points.size()
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		var da := plane.distance_to(a)
		var db := plane.distance_to(b)
		if da <= EPSILON:
			out.append(a)
		if (da < -EPSILON and db > EPSILON) or (da > EPSILON and db < -EPSILON):
			out.append(a.lerp(b, da / (da - db)))
	return out


## Aligne sur la grille les sommets qui en sont tout proches et supprime les
## doublons.
func _cleanup(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for point in points:
		var snapped := point.snapped(Vector3.ONE * 0.125)
		if point.distance_to(snapped) < 0.02:
			point = snapped
		if out.is_empty() or out[out.size() - 1].distance_to(point) > EPSILON * 10.0:
			out.append(point)
	while out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= EPSILON * 10.0:
		out.remove_at(out.size() - 1)
	return out


# --- Placement --------------------------------------------------------------

## Centre la carte horizontalement sur l'origine du monde, avec le sol des
## points de départ à y = 0.
func _compute_offset(map: UfoMap, solids: Array[Dictionary]) -> void:
	var bounds := AABB()
	var first := true
	for solid in solids:
		if solid["kind"] == &"clip":
			continue
		for polygon: Dictionary in solid["polygons"]:
			for point: Vector3 in polygon["points"]:
				if first:
					bounds = AABB(point, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(point)
	var center := bounds.get_center()
	var floor_z := bounds.position.z
	var starts := map.find_entities("info_player_start")
	if not starts.is_empty():
		floor_z = starts[0].origin().z - FEET_BELOW_ORIGIN
	_offset = Vector3(center.x, center.y, floor_z)
	var low := to_world(bounds.position)
	var high := to_world(bounds.end)
	map_bounds = AABB(low.min(high), (high - low).abs())


# --- Construction -----------------------------------------------------------

func _build(solids: Array[Dictionary]) -> void:
	var tools: Dictionary = {}
	var bodies: Dictionary = {}
	var slice := [Time.get_ticks_usec()]
	for solid in solids:
		await _yield_if_slice_spent(slice)
		if not is_inside_tree():
			return
		var kind: StringName = solid["kind"]
		var polygons: Array = solid["polygons"]
		if kind != &"clip":
			_add_faces(polygons, tools)
		if kind == &"passable":
			continue
		var body_name := &"Clip" if kind == &"clip" else (&"Ground" if _height(polygons) <= GROUND_MAX_HEIGHT else &"Walls")
		_add_collision(polygons, _body(bodies, body_name))
	var mesh := ArrayMesh.new()
	for key: String in tools:
		await _yield_if_slice_spent(slice)
		if not is_inside_tree():
			return
		var tool: SurfaceTool = tools[key]
		tool.generate_tangents()
		tool.commit(mesh)
	var geometry := MeshInstance3D.new()
	geometry.name = "Geometry"
	geometry.mesh = mesh
	add_child(geometry)
	for body: StaticBody3D in bodies.values():
		add_child(body)


func _load_textures(solids: Array[Dictionary]) -> void:
	var names: Array[String] = []
	for solid in solids:
		for polygon: Dictionary in solid["polygons"]:
			var face: UfoMap.Face = polygon["face"]
			if _is_visible(face) and not names.has(face.texture):
				names.append(face.texture)
	var all_names: Array[String] = names.duplicate()
	for texture_name in names:
		if not TextureLibrary.find_file(texture_name + "_nm").is_empty():
			all_names.append(texture_name + "_nm")
	TextureLibrary.load_textures(all_names)


func _is_visible(face: UfoMap.Face) -> bool:
	return not face.texture.begins_with(TECHNICAL_PREFIX) and not (face.surface & UfoMap.SURF_NODRAW)


func _height(polygons: Array) -> float:
	var low := INF
	var high := -INF
	for polygon: Dictionary in polygons:
		for point: Vector3 in polygon["points"]:
			low = minf(low, point.z)
			high = maxf(high, point.z)
	return high - low


## Ajoute les faces visibles aux outils de maillage (un par matériau), en
## coordonnées du monde relatives à `origin`.
func _add_faces(polygons: Array, tools: Dictionary, origin: Vector3 = Vector3.ZERO) -> void:
	for polygon: Dictionary in polygons:
		var face: UfoMap.Face = polygon["face"]
		if not _is_visible(face):
			continue
		var material := _material(face)
		var key := material.resource_name
		if not tools.has(key):
			var new_tool := SurfaceTool.new()
			new_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			new_tool.set_material(material)
			tools[key] = new_tool
		var tool: SurfaceTool = tools[key]
		var points: PackedVector3Array = polygon["points"]
		var normals := _vertex_normals(polygon, polygons)
		var uvs := _uvs(face, points)
		var world_points := PackedVector3Array()
		var world_normals := PackedVector3Array()
		for i in points.size():
			world_points.append(to_world(points[i]) - origin)
			var n := normals[i]
			world_normals.append(Vector3(n.x, n.z, -n.y))
		# Godot : faces avant dans le sens horaire vu de face.
		for i in range(1, points.size() - 1):
			for index in [0, i + 1, i]:
				tool.set_normal(world_normals[index])
				tool.set_uv(uvs[index])
				tool.add_vertex(world_points[index])


## Normales par sommet : celle de la face, ou la moyenne des faces voisines
## lissées (« phong ») du même brush, pour les tonneaux et autres formes rondes.
func _vertex_normals(polygon: Dictionary, polygons: Array) -> PackedVector3Array:
	var face: UfoMap.Face = polygon["face"]
	var points: PackedVector3Array = polygon["points"]
	var normals := PackedVector3Array()
	var smooth := face.surface & UfoMap.SURF_PHONG
	var min_dot := cos(PHONG_MAX_ANGLE)
	for point in points:
		var normal := face.plane.normal
		if smooth:
			normal = Vector3.ZERO
			for other: Dictionary in polygons:
				var other_face: UfoMap.Face = other["face"]
				if not (other_face.surface & UfoMap.SURF_PHONG):
					continue
				if other_face.plane.normal.dot(face.plane.normal) < min_dot:
					continue
				for other_point: Vector3 in other["points"]:
					if other_point.distance_to(point) < 0.05:
						normal += other_face.plane.normal
						break
			normal = normal.normalized() if normal.length_squared() > 0.0 else face.plane.normal
		normals.append(normal)
	return normals


## Coordonnées de texture d'UFO:AI (Quake 2) : projection sur les axes de
## référence, rotation, échelle (en texels par unité) et décalage en texels.
func _uvs(face: UfoMap.Face, points: PackedVector3Array) -> PackedVector2Array:
	var best := 0
	var best_dot := 0.0
	for i in BASE_AXES.size():
		var d := face.plane.normal.dot(BASE_AXES[i][0])
		if d > best_dot:
			best_dot = d
			best = i
	var axes: Array[Vector3] = [BASE_AXES[best][1], BASE_AXES[best][2]]
	var angle := deg_to_rad(face.rotation)
	var sin_a := sin(angle)
	var cos_a := cos(angle)
	var sv := 0 if axes[0].x != 0.0 else (1 if axes[0].y != 0.0 else 2)
	var tv := 0 if axes[1].x != 0.0 else (1 if axes[1].y != 0.0 else 2)
	for k in 2:
		var v := axes[k]
		var ns := cos_a * v[sv] - sin_a * v[tv]
		var nt := sin_a * v[sv] + cos_a * v[tv]
		v[sv] = ns
		v[tv] = nt
		axes[k] = v
	var scale_x := face.scale.x if face.scale.x != 0.0 else 1.0
	var scale_y := face.scale.y if face.scale.y != 0.0 else 1.0
	var texture := TextureLibrary.get_texture(face.texture)
	var size := texture.get_size() if texture else DEFAULT_TEXTURE_SIZE
	var uvs := PackedVector2Array()
	for point in points:
		var u := point.dot(axes[0]) / scale_x + face.shift.x
		var v := point.dot(axes[1]) / scale_y + face.shift.y
		uvs.append(Vector2(u / size.x, v / size.y))
	return uvs


## Matériau partagé par toutes les faces d'une même texture et d'un même rendu.
func _material(face: UfoMap.Face) -> StandardMaterial3D:
	var render_flags := face.surface & (UfoMap.SURF_LIGHT | UfoMap.SURF_BLEND33 | UfoMap.SURF_BLEND66 | UfoMap.SURF_ALPHATEST)
	var key := "%s|%d" % [face.texture, render_flags]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.resource_name = key
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.set_meta(&"albedo_source", face.texture)
	if not TextureLibrary.find_file(face.texture + "_nm").is_empty():
		material.normal_enabled = true
		material.set_meta(&"normal_source", face.texture + "_nm")
	if render_flags & UfoMap.SURF_LIGHT:
		material.emission_enabled = true
		material.set_meta(&"emission_source", face.texture)
	if render_flags & UfoMap.SURF_ALPHATEST:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	elif render_flags & (UfoMap.SURF_BLEND33 | UfoMap.SURF_BLEND66):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.33 if render_flags & UfoMap.SURF_BLEND33 else 0.66
	_materials[key] = material
	return material


func _body(bodies: Dictionary, body_name: StringName) -> StaticBody3D:
	if bodies.has(body_name):
		return bodies[body_name]
	# Ajouté à la scène par l'appelant une fois rempli : ajouter des milliers
	# de formes à un corps déjà dans la scène coûte une mise à jour physique
	# à chaque fois.
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = LAYER_WALLS if body_name == &"Walls" else LAYER_GROUND
	body.collision_mask = 0
	bodies[body_name] = body
	return body


func _add_collision(polygons: Array, body: StaticBody3D) -> void:
	var points := PackedVector3Array()
	for polygon: Dictionary in polygons:
		for point: Vector3 in polygon["points"]:
			var world := to_world(point)
			var known := false
			for existing in points:
				if existing.distance_squared_to(world) < 0.000001:
					known = true
					break
			if not known:
				points.append(world)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


# --- Caisses -----------------------------------------------------------------

## Retire de `solids` les caisses à convertir et les renvoie (avec leur
## emprise, en unités UFO:AI).
##
## Les cartes doublent souvent les objets d'un mur invisible (`actorclip`),
## parfois un seul pour plusieurs objets voisins, déplaçables ou non. Ce mur
## est découpé : l'emprise des objets convertis en est retirée, le reste
## (qui bloque le décor voisin) est conservé en pavés. Un objet touché par un
## mur invisible qui n'est pas un pavé (découpe impossible) reste fixe.
func _extract_crates(solids: Array[Dictionary]) -> Array[Dictionary]:
	var bounds: Array[AABB] = []
	for solid in solids:
		bounds.append(_bounds(solid["polygons"]))
	var candidates: Array[int] = []
	for i in solids.size():
		var prop := _prop_kind(solids[i], bounds[i])
		if prop != &"" and not _is_covered(i, solids, bounds):
			solids[i]["prop"] = prop
			candidates.append(i)
	var removed := {}
	var rejected := {}
	var cut: Dictionary = {}
	for i in solids.size():
		if solids[i]["kind"] != &"clip":
			continue
		var touched: Array[int] = []
		var clip := _footprint(bounds[i])
		for c in candidates:
			if clip.grow(-1.0).intersects(_footprint(bounds[c])):
				touched.append(c)
		if touched.is_empty():
			continue
		if _is_box(solids[i]["brush"]):
			cut[i] = touched
		else:
			for c in touched:
				rejected[c] = true
	var added: Array[Dictionary] = []
	for i: int in cut:
		removed[i] = true
		var pieces: Array[Rect2] = [_footprint(bounds[i])]
		for c: int in cut[i]:
			if not rejected.has(c):
				pieces = _subtract(pieces, _footprint(bounds[c]))
		for piece in pieces:
			added.append(_clip_block(piece, bounds[i].position.z, bounds[i].end.z))
	var crates: Array[Dictionary] = []
	for c in candidates:
		if rejected.has(c):
			continue
		solids[c]["bounds"] = bounds[c]
		crates.append(solids[c])
		removed[c] = true
	var kept: Array[Dictionary] = []
	for i in solids.size():
		if not removed.has(i):
			kept.append(solids[i])
	kept.append_array(added)
	solids.assign(kept)
	return crates


## `rects` privés de `hole` : chaque rectangle entamé est remplacé par les
## bandes qui restent autour (sans les bandes de moins d'une unité).
static func _subtract(rects: Array[Rect2], hole: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect in rects:
		var inter := rect.intersection(hole)
		if inter.size.x < 1.0 or inter.size.y < 1.0:
			result.append(rect)
			continue
		var pieces: Array[Rect2] = [
			Rect2(rect.position.x, rect.position.y, inter.position.x - rect.position.x, rect.size.y),
			Rect2(inter.end.x, rect.position.y, rect.end.x - inter.end.x, rect.size.y),
			Rect2(inter.position.x, rect.position.y, inter.size.x, inter.position.y - rect.position.y),
			Rect2(inter.position.x, inter.end.y, inter.size.x, rect.end.y - inter.end.y),
		]
		for piece in pieces:
			if piece.size.x >= 1.0 and piece.size.y >= 1.0:
				result.append(piece)
	return result


## Mur invisible en pavé (même forme que `_collect_brushes`, sans faces).
static func _clip_block(rect: Rect2, bottom: float, top: float) -> Dictionary:
	var points := PackedVector3Array()
	for z in [bottom, top]:
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			points.append(Vector3(corner.x, corner.y, z))
	return {"brush": null, "polygons": [{"points": points}], "kind": &"clip"}

## Emprise au sol (x, y d'UFO:AI).
static func _footprint(box: AABB) -> Rect2:
	return Rect2(box.position.x, box.position.y, box.size.x, box.size.y)


## Objet déplaçable : &"crate" (cube d'une case aux faces alignées sur les
## axes, textures de caisse), &"barrel" (une case de haut et de large,
## textures de bidon), ou &"" (décor). Dans les deux cas, posé au sol (niveau
## des points de départ).
func _prop_kind(solid: Dictionary, box: AABB) -> StringName:
	if solid["kind"] != &"solid":
		return &""
	var error := (box.size - Vector3.ONE * CRATE_SIZE).abs()
	if error[error.max_axis_index()] > CRATE_TOLERANCE:
		return &""
	if absf(box.position.z - _offset.z) > CRATE_TOLERANCE:
		return &""
	var brush: UfoMap.Brush = solid["brush"]
	if movable_crates and _is_box(brush) and _textured_with(brush, crate_textures):
		return &"crate"
	if movable_barrels and _textured_with(brush, barrel_textures):
		return &"barrel"
	return &""


## Vrai si toutes les faces visibles du brush portent une texture commençant
## par l'un des `prefixes`.
func _textured_with(brush: UfoMap.Brush, prefixes: PackedStringArray) -> bool:
	for face in brush.faces:
		if not _is_visible(face):
			continue
		var known := false
		for prefix in prefixes:
			known = known or face.texture.begins_with(prefix)
		if not known:
			return false
	return true


## Vrai si un autre brush visible repose sur le dessus de la caisse `index`
## (pile). Les murs invisibles, qui couvrent souvent toute une zone, ne
## comptent pas.
func _is_covered(index: int, solids: Array[Dictionary], bounds: Array[AABB]) -> bool:
	var box := bounds[index]
	var above := AABB(box.position + Vector3(1, 1, box.size.z - CRATE_TOLERANCE), Vector3(box.size.x - 2, box.size.y - 2, 8))
	for i in bounds.size():
		if i != index and solids[i]["kind"] != &"clip" and bounds[i].intersects(above):
			return true
	return false


func _bounds(polygons: Array) -> AABB:
	var box := AABB()
	var first := true
	for polygon: Dictionary in polygons:
		for point: Vector3 in polygon["points"]:
			if first:
				box = AABB(point, Vector3.ZERO)
				first = false
			else:
				box = box.expand(point)
	return box


## Crée un `Climbable` (scène des caisses du jeu) par caisse ou bidon de la
## carte, habillé de ses propres textures : MapCrateN, MapBarrelN.
func _build_crates(crates: Array[Dictionary]) -> void:
	var counts := {&"crate": 0, &"barrel": 0}
	for i in crates.size():
		var prop: StringName = crates[i]["prop"]
		counts[prop] += 1
		var box: AABB = crates[i]["bounds"]
		var base := to_world(Vector3(box.get_center().x, box.get_center().y, box.position.z))
		var size := Vector3(box.size.x, box.size.z, box.size.y) / units_per_meter
		var tools: Dictionary = {}
		_add_faces(crates[i]["polygons"], tools, base)
		var mesh := ArrayMesh.new()
		for key: String in tools:
			var tool: SurfaceTool = tools[key]
			tool.generate_tangents()
			tool.commit(mesh)
		var crate := CRATE_SCENE.instantiate() as Climbable
		crate.name = ("MapBarrel%d" if prop == &"barrel" else "MapCrate%d") % counts[prop]
		crate.can_stand_on = prop != &"barrel"
		crate.top_height = size.y
		crate.half_extent = maxf(size.x, size.z) * 0.5
		var view := crate.get_node("MeshInstance3D") as MeshInstance3D
		view.mesh = mesh
		view.transform = Transform3D.IDENTITY
		# Forme propre à la caisse (la ressource de la scène est partagée).
		var collision := crate.get_node("CollisionShape3D") as CollisionShape3D
		if prop == &"barrel":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = crate.half_extent
			cylinder.height = size.y
			collision.shape = cylinder
		else:
			var shape := BoxShape3D.new()
			shape.size = size
			collision.shape = shape
		collision.position = Vector3(0.0, size.y * 0.5, 0.0)
		crate.position = base
		add_child(crate)


# --- Corniches --------------------------------------------------------------

## Une corniche (`Climbable` fixe, sans collision propre : on se tient sur le
## mur) par case de la grille (32 unités) entièrement comprise dans le dessus
## plat d'un mur à portée d'escalade depuis une caisse, et dégagée au-dessus.
func _build_ledges(solids: Array[Dictionary]) -> void:
	var bounds: Array[AABB] = []
	for solid in solids:
		bounds.append(_bounds(solid["polygons"]))
	var count := 0
	for i in solids.size():
		if solids[i]["kind"] != &"solid":
			continue
		var top_face := PackedVector3Array()
		for polygon: Dictionary in solids[i]["polygons"]:
			if (polygon["face"] as UfoMap.Face).plane.normal.is_equal_approx(Vector3(0, 0, 1)):
				top_face = polygon["points"]
		if top_face.is_empty():
			continue
		var z := top_face[0].z
		var top := (z - _offset.z) / units_per_meter
		if top < LEDGE_MIN_HEIGHT or top > LEDGE_MAX_HEIGHT:
			continue
		var box := bounds[i]
		var start := (Vector2(box.position.x, box.position.y) / CRATE_SIZE).floor() * CRATE_SIZE
		var x := start.x
		while x < box.end.x - CRATE_TOLERANCE:
			var y := start.y
			while y < box.end.y - CRATE_TOLERANCE:
				var corner := Vector3(x, y, z)
				y += CRATE_SIZE
				if not _square_inside(top_face, Vector2(corner.x, corner.y)):
					continue
				var above := AABB(corner + Vector3(1, 1, CRATE_TOLERANCE), Vector3(CRATE_SIZE - 2, CRATE_SIZE - 2, LEDGE_HEADROOM * units_per_meter))
				if _is_blocked(above, i, solids, bounds):
					continue
				var center := corner + Vector3(CRATE_SIZE * 0.5, CRATE_SIZE * 0.5, 0.0)
				var ledge := Climbable.new()
				count += 1
				ledge.name = "Ledge%d" % count
				ledge.collision_layer = 0
				ledge.collision_mask = 0
				ledge.movable = false
				ledge.climbable_from_ground = false
				ledge.top_height = top
				ledge.half_extent = CRATE_SIZE * 0.5 / units_per_meter
				ledge.position = to_world(Vector3(center.x, center.y, _offset.z))
				ledge.add_to_group(&"climbables")
				add_child(ledge)
			x += CRATE_SIZE


## Vrai si la case de la grille de coin `corner` tient dans le polygone
## convexe `polygon` (sens trigonométrique vu de dessus).
static func _square_inside(polygon: PackedVector3Array, corner: Vector2) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(CRATE_SIZE, 0), Vector2(CRATE_SIZE, CRATE_SIZE), Vector2(0, CRATE_SIZE)]:
		var point := corner + offset
		for k in polygon.size():
			var a := Vector2(polygon[k].x, polygon[k].y)
			var b := Vector2(polygon[(k + 1) % polygon.size()].x, polygon[(k + 1) % polygon.size()].y)
			if (b - a).cross(point - a) < -CRATE_TOLERANCE * (b - a).length():
				return false
	return true


## Six faces alignées sur les axes.
func _is_box(brush: UfoMap.Brush) -> bool:
	if brush.faces.size() != 6:
		return false
	for face in brush.faces:
		var n := face.plane.normal.abs()
		if not is_equal_approx(n[n.max_axis_index()], 1.0):
			return false
	return true


## Vrai si un brush bloquant (visible ou invisible) autre que `index` occupe `region`.
func _is_blocked(region: AABB, index: int, solids: Array[Dictionary], bounds: Array[AABB]) -> bool:
	for i in bounds.size():
		if i != index and solids[i]["kind"] != &"passable" and bounds[i].intersects(region):
			return true
	return false


# --- Unités -----------------------------------------------------------------

func _place_units(map: UfoMap) -> void:
	var parent := get_node_or_null(units_parent)
	if parent == null:
		return
	var starts := map.find_entities("info_player_start")
	var index := 0
	for child in parent.get_children():
		var unit := child as Node3D
		if unit == null or index >= starts.size():
			continue
		unit.global_position = _feet(starts[index])
		unit.rotation.y = yaw_to_world(starts[index].angle())
		index += 1


func _spawn_enemies(map: UfoMap) -> void:
	var parent := get_node_or_null(enemies_parent) as Node3D
	if parent == null or enemy_scene == null:
		return
	var count := 0
	for start in _spread_starts(map.find_entities("info_alien_start"), map.find_entities("info_player_start")):
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.name = "Sentry%d" % (count + 1)
		enemy.stationary = true
		enemy.position = parent.to_local(_feet(start))
		enemy.rotation.y = yaw_to_world(start.angle())
		parent.add_child(enemy)
		count += 1


## Au plus `max_enemies` points de départ, répartis sur toute la carte : le
## plus éloigné des opérateurs d'abord, puis à chaque fois celui qui est le
## plus loin des points déjà retenus. Tous, dans l'ordre, sans limite.
func _spread_starts(starts: Array[UfoMap.Entity], players: Array[UfoMap.Entity]) -> Array[UfoMap.Entity]:
	if max_enemies < 0 or starts.size() <= max_enemies:
		return starts
	var chosen: Array[UfoMap.Entity] = []
	var player := players[0].origin() if not players.is_empty() else Vector3.ZERO
	var nearest: Array[float] = []
	for start in starts:
		nearest.append(start.origin().distance_to(player))
	while chosen.size() < max_enemies:
		var best := 0
		for i in starts.size():
			if nearest[i] > nearest[best]:
				best = i
		chosen.append(starts[best])
		for i in starts.size():
			nearest[i] = minf(nearest[i], starts[i].origin().distance_to(starts[best].origin()))
	return chosen


func _feet(entity: UfoMap.Entity) -> Vector3:
	return to_world(entity.origin() - Vector3(0, 0, FEET_BELOW_ORIGIN))


func _setup_camera() -> void:
	var rig := get_node_or_null(camera_rig) as Node3D
	if rig == null:
		return
	rig.set(&"bounds", AABB(Vector3(map_bounds.position.x, 0.0, map_bounds.position.z), Vector3(map_bounds.size.x, 0.0, map_bounds.size.z)))
	var parent := get_node_or_null(units_parent)
	if parent and parent.get_child_count() > 0:
		var sum := Vector3.ZERO
		for child in parent.get_children():
			sum += (child as Node3D).global_position
		var center := sum / parent.get_child_count()
		rig.global_position = Vector3(center.x, 0.0, center.z)
