@tool
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
## Hauteur libre (m) d'un endroit où passer : un peu moins qu'un homme
## debout, pour passer sous les linteaux des portes.
const ROOF_HEADROOM := 1.5
## Surface minimale (en cases) d'un toit : en deçà (linteau au-dessus d'une
## porte), il reste affiché.
const ROOF_MIN_CELLS := 4
## Taille des cases de la grille de recherche des brushes (unités UFO:AI).
const GRID_SIZE := 64.0
## Pas (unités UFO:AI) de la grille des endroits où l'on tient debout,
## parcourue depuis les points de départ pour trouver les intérieurs.
const ROOF_STEP := 16.0
## Dénivelé maximal (m) entre deux points voisins de cette grille.
const ROOF_MAX_RISE := 0.5
## Écart maximal (m) entre les plafonds de deux cases voisines d'un même toit
## (pente d'un toit sur une case, pas une marche de linteau à linteau).
const ROOF_JOIN_HEIGHT := 0.75
## Durée maximale d'une tranche de construction avant d'afficher une image (µs).
const SLICE_USEC := 25000
## Cache du repérage des toits, une entrée par carte. Changer
## `ROOF_CACHE_VERSION` dès que le repérage change.
const ROOF_CACHE_DIR := "user://roof_cache"
## Dossier du cache utilisé (les tests prennent le leur, pour ne pas vider
## celui du joueur).
static var roof_cache_dir: String = ROOF_CACHE_DIR
const ROOF_CACHE_VERSION := 1
## Caisse convertie en `Climbable` : cube de cette taille (unités UFO:AI),
## posé au sol, rien dessus.
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
## Carte à construire quand `map_file` est vide (niveau générique
## `ufo_map.tscn`, lancé depuis le menu pour une carte hors catalogue).
static var requested_map: String = ""
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
## Toits effaçables : quand un opérateur entre dans un bâtiment, son toit
## s'efface pour qu'on voie l'intérieur (`Roof`).
@export var reveal_roofs: bool = true
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
## Part des sentinelles qui font une ronde autour de leur poste (les autres
## restent fixes). Les rondes sont tracées une fois la navigation prête.
@export_range(0.0, 1.0) var patrol_ratio: float = 0.5

## Fils de calcul en cours (`_run_in_thread`).
var _threads: Array[Thread] = []
## Caméra dont les limites sont réglées sur la carte.
@export var camera_rig: NodePath

## Emprise de la carte dans le monde (mètres), une fois construite.
var map_bounds: AABB
## Origine de la carte (unités UFO:AI) placée à l'origine du monde.
var _offset: Vector3 = Vector3.ZERO
var _materials: Dictionary = {}
## Toits repérés par `_find_roofs` : [{areas, floors, ceilings, ceiling}]
## (monde).
var _roofs: Array[Dictionary] = []


## Émis quand le niveau est construit (géométrie, objets, unités placées).
signal built

## Vrai une fois le niveau construit.
var is_built: bool = false
## Vrai si les toits ont été lus dans le cache (`roof_cache_dir`).
var roofs_from_cache: bool = false
## Étape en cours, pour l'écran de chargement.
var build_stage: String = ""


func _ready() -> void:
	_build_level()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_see_through()


func _exit_tree() -> void:
	WorldMaterial.set_see_through([] as Array[Vector3])
	# Niveau quitté pendant un calcul : on attend la fin du fil.
	for thread in _threads:
		thread.wait_to_finish()
	_threads.clear()


## Le décor s'efface entre la caméra et chaque opérateur vivant.
func _update_see_through() -> void:
	var points: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and points.size() < WorldMaterial.SEE_THROUGH_SLOTS:
			points.append(unit.global_position)
	WorldMaterial.set_see_through(points)


## Construction répartie sur plusieurs images (l'écran de chargement reste
## animé) : lecture et découpe des brushes sur un fil de travail, puis
## maillages et collisions par tranches de `SLICE_USEC`.
func _build_level() -> void:
	build_stage = "Lecture de la carte"
	if map_file.is_empty():
		map_file = requested_map
	var path := AssetPaths.maps_dir().path_join(map_file)
	var result: Variant = await _run_in_thread(func() -> Dictionary:
		var parsed := UfoMap.load_file(path)
		if parsed == null:
			return {}
		return {"map": parsed, "solids": _collect_brushes(parsed)})
	if not is_inside_tree():
		return
	var loaded: Dictionary = result
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
	if reveal_roofs:
		build_stage = "Repérage des toits"
		await get_tree().process_frame
		var seeds := PackedVector3Array()
		for start in map.find_entities("info_player_start") + map.find_entities("info_alien_start"):
			seeds.append(start.origin())
		var cache_key := _roof_cache_key(path, solids.size())
		roofs_from_cache = _load_roof_cache(cache_key, solids)
		if not roofs_from_cache:
			await _run_in_thread(func() -> bool:
				_find_roofs(solids, seeds)
				return true)
			_save_roof_cache(cache_key, solids)
	build_stage = "Construction du décor"
	await _build(solids)
	if not is_inside_tree():
		return
	_build_crates(crates)
	if ledges:
		_build_ledges(solids)
	await get_tree().process_frame
	TextureLibrary.apply_to_tree(self)
	if Engine.is_editor_hint():
		# Aperçu dans l'éditeur : le décor seul (unités, ennemis et caméra
		# restent tels qu'enregistrés).
		_finish_build()
		return
	_place_units(map)
	_spawn_enemies(map)
	_setup_camera()
	_finish_build()


func _finish_build() -> void:
	build_stage = ""
	is_built = true
	built.emit()


## Exécute `task` sur un fil à lui et rend son résultat, sans bloquer
## l'affichage. Un fil dédié plutôt que le `WorkerThreadPool` : dans la suite
## de tests, une tâche du pool restait parfois sans jamais démarrer.
func _run_in_thread(task: Callable) -> Variant:
	# Export Web sans fils, ou aperçu dans l'éditeur (un fil à part y restait
	# parfois bloqué) : la tâche tourne d'un bloc dans le fil principal.
	if OS.has_feature("nothreads") or Engine.is_editor_hint():
		await get_tree().process_frame
		return task.call()
	var thread := Thread.new()
	_threads.append(thread)
	thread.start(task)
	while thread.is_alive():
		await get_tree().process_frame
		if not is_inside_tree():
			return null
	_threads.erase(thread)
	return thread.wait_to_finish()


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
	# Par toit : outils de maillage et corps de collision à part.
	var roof_tools: Dictionary = {}
	var slice := [Time.get_ticks_usec()]
	for solid in solids:
		await _yield_if_slice_spent(slice)
		if not is_inside_tree():
			return
		var kind: StringName = solid["kind"]
		var polygons: Array = solid["polygons"]
		var roof: int = solid.get("roof", -1)
		if kind != &"clip":
			if roof >= 0:
				if not roof_tools.has(roof):
					roof_tools[roof] = {}
				_add_faces(polygons, roof_tools[roof])
			else:
				_add_faces(polygons, tools)
		if kind == &"passable":
			continue
		if roof >= 0:
			_add_collision(polygons, _body(bodies, StringName("RoofBody%d" % (roof + 1)), LAYER_WALLS))
			continue
		var body_name := &"Clip" if kind == &"clip" else (&"Ground" if _height(polygons) <= GROUND_MAX_HEIGHT else &"Walls")
		_add_collision(polygons, _body(bodies, body_name))
	var geometry := MeshInstance3D.new()
	geometry.name = "Geometry"
	geometry.mesh = await _commit(tools, slice)
	if not is_inside_tree():
		return
	add_child(geometry)
	for body_name: StringName in bodies:
		if not String(body_name).begins_with("RoofBody"):
			add_child(bodies[body_name])
	var roof_nodes: Array[Roof] = []
	for roof: int in roof_tools:
		var node := Roof.new()
		node.name = "Roof%d" % (roof + 1)
		node.areas = _roofs[roof]["areas"]
		node.floors = _roofs[roof]["floors"]
		node.ceilings = _roofs[roof]["ceilings"]
		node.ceiling = _roofs[roof]["ceiling"]
		node.view = MeshInstance3D.new()
		node.view.name = "View"
		node.view.mesh = await _commit(roof_tools[roof], slice)
		if not is_inside_tree():
			return
		node.add_child(node.view)
		node.prepare_reveal()
		node.body = bodies.get(StringName("RoofBody%d" % (roof + 1)))
		if node.body:
			node.add_child(node.body)
		add_child(node)
		roof_nodes.append(node)
	# Étages : un toit au-dessus d'un autre s'efface avec lui.
	for lower in roof_nodes:
		for upper in roof_nodes:
			if upper != lower and upper.ceiling > lower.ceiling and upper.overlaps(lower):
				upper.below.append(lower)


## Maillage des surfaces de `tools` (une par matériau), par tranches.
func _commit(tools: Dictionary, slice: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key: String in tools:
		await _yield_if_slice_spent(slice)
		if not is_inside_tree():
			return mesh
		var tool: SurfaceTool = tools[key]
		tool.generate_tangents()
		tool.commit(mesh)
	return mesh


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
## Matériau du décor (`WorldMaterial`) : s'efface autour des opérateurs.
func _material(face: UfoMap.Face) -> ShaderMaterial:
	var render_flags := face.surface & (UfoMap.SURF_LIGHT | UfoMap.SURF_BLEND33 | UfoMap.SURF_BLEND66 | UfoMap.SURF_ALPHATEST)
	var key := "%s|%d" % [face.texture, render_flags]
	if _materials.has(key):
		return _materials[key]
	var blend := WorldMaterial.Blend.OPAQUE
	if render_flags & UfoMap.SURF_ALPHATEST:
		blend = WorldMaterial.Blend.SCISSOR
	elif render_flags & (UfoMap.SURF_BLEND33 | UfoMap.SURF_BLEND66):
		blend = WorldMaterial.Blend.ALPHA
	var material := WorldMaterial.create(blend)
	material.resource_name = key
	material.set_meta(&"albedo_source", face.texture)
	if not TextureLibrary.find_file(face.texture + "_nm").is_empty():
		material.set_meta(&"normal_source", face.texture + "_nm")
	if render_flags & UfoMap.SURF_LIGHT:
		material.set_meta(&"emission_source", face.texture)
	if blend == WorldMaterial.Blend.ALPHA:
		material.set_shader_parameter(&"albedo_color", Color(1, 1, 1, 0.33 if render_flags & UfoMap.SURF_BLEND33 else 0.66))
	_materials[key] = material
	return material


func _body(bodies: Dictionary, body_name: StringName, layer: int = -1) -> StaticBody3D:
	if bodies.has(body_name):
		return bodies[body_name]
	# Ajouté à la scène par l'appelant une fois rempli : ajouter des milliers
	# de formes à un corps déjà dans la scène coûte une mise à jour physique
	# à chaque fois.
	var body := StaticBody3D.new()
	body.name = body_name
	if layer < 0:
		layer = LAYER_WALLS if body_name == &"Walls" else LAYER_GROUND
	body.collision_layer = layer
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


# --- Toits ------------------------------------------------------------------

## Repère les toits. Les cartes ne les signalent pas, et la hauteur ne suffit
## pas (des dalles de sol posées sur du vide caché ressemblent à des
## plafonds) : on parcourt, depuis les points de départ (`seeds`, unités de la
## carte), les endroits où l'on tient debout, de proche en proche
## (`ROOF_STEP`, marches de `ROOF_MAX_RISE` au plus, sans traverser les murs
## minces). Un brush visible qui couvre l'un d'eux est un plafond. Les
## plafonds d'un même espace forment un toit, avec ce qui repose dessus
## (parapets, étage inaccessible). Un toit qui couvre moins de
## `ROOF_MIN_CELLS` cases (linteau) reste dans le décor.
## Calcul pur, lancé sur un fil de travail ; marque `solid["roof"]`.
## Le résultat est mis en cache par carte (`_save_roof_cache`).
func _find_roofs(solids: Array[Dictionary], seeds: PackedVector3Array) -> void:
	_roofs.clear()
	var bounds: Array[AABB] = []
	for solid in solids:
		bounds.append(_bounds(solid["polygons"]))
		# Plans des faces, pour le calcul vertical (vide : pavé, sans face).
		var planes: Array[Plane] = []
		for polygon: Dictionary in solid["polygons"]:
			if not polygon.has("face"):
				planes.clear()
				break
			planes.append(polygon["face"].plane)
		solid["planes"] = planes
	var grid := _grid(bounds)
	var headroom := ROOF_HEADROOM * units_per_meter
	# Cases couvertes par chaque plafond : {brush: {case: (plafond, sol)}}.
	var covered := _covered_cells(solids, bounds, grid, seeds, headroom)
	# Un même toit : plafonds au-dessus de cases voisines, à moins de
	# `ROOF_JOIN_HEIGHT` l'un de l'autre (pans d'un toit à deux pentes). Des plafonds qui se touchent ne suffisent
	# pas : les dalles de sol qui couvrent une tranchée touchent tout le
	# terrain. Union-find.
	var parent := {}
	for i: int in covered:
		parent[i] = i
	var by_cell := {}
	for i: int in covered:
		for cell: Vector2i in covered[i]:
			if not by_cell.has(cell):
				by_cell[cell] = []
			by_cell[cell].append([i, covered[i][cell].x])
	for cell: Vector2i in by_cell:
		for step: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]:
			for a: Array in by_cell[cell]:
				for b: Array in by_cell.get(cell + step, []):
					if a[0] != b[0] and absf(a[1] - b[1]) < ROOF_JOIN_HEIGHT * units_per_meter:
						parent[_find(parent, a[0])] = _find(parent, b[0])
	var groups := {}
	for i: int in covered:
		var root: int = _find(parent, i)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(i)
	var kept: Array[Array] = []
	for members: Array in groups.values():
		var cells := {}
		for i: int in members:
			for cell: Vector2i in covered[i]:
				if not cells.has(cell) or covered[i][cell].x < cells[cell].x:
					cells[cell] = covered[i][cell]
		if cells.size() * ROOF_STEP * ROOF_STEP < ROOF_MIN_CELLS * CRATE_SIZE * CRATE_SIZE - 1.0:
			continue
		for i: int in members:
			solids[i]["roof"] = kept.size()
		kept.append([members, cells])
	for roof in kept.size():
		var members: Array = kept[roof][0]
		var cells: Dictionary = kept[roof][1]
		var ceiling := INF
		for height: Vector2 in cells.values():
			ceiling = minf(ceiling, height.x)
		_add_riders(roof, members, ceiling, solids, bounds, grid)
		var areas: Array[Rect2] = []
		var floors: Array[float] = []
		var ceilings: Array[float] = []
		_cells_to_areas(cells, areas, floors, ceilings)
		_roofs.append({"areas": areas, "floors": floors, "ceilings": ceilings, "ceiling": to_world(Vector3(0, 0, ceiling)).y})


## Parcours en largeur des endroits où l'on tient debout (sol dessiné),
## depuis `seeds`.
## Renvoie, pour chaque brush visible juste au-dessus de l'un d'eux, les cases
## couvertes, la hauteur de son dessous et celle du sol :
## {brush: {case: Vector2(z plafond, z sol)}}.
func _covered_cells(solids: Array[Dictionary], bounds: Array[AABB], grid: Dictionary, seeds: PackedVector3Array, headroom: float) -> Dictionary:
	var rise := ROOF_MAX_RISE * units_per_meter
	var columns := {}
	var seen := {}
	var queue: Array[Vector3i] = []
	for seed in seeds:
		var cell := Vector2i(floori(seed.x / ROOF_STEP), floori(seed.y / ROOF_STEP))
		var spans := _spans(cell * 2 + Vector2i.ONE, columns, solids, bounds, grid, headroom)
		# L'espace où se tient la graine : le sol le plus haut sous elle.
		var best := -1
		for k in spans.size():
			if spans[k][0] <= seed.z + CRATE_SIZE * 0.5:
				best = k
		if best >= 0 and spans[best][3]:
			var node := Vector3i(cell.x, cell.y, best)
			if not seen.has(node):
				seen[node] = true
				queue.append(node)
	var covered := {}
	var head := 0
	while head < queue.size():
		var node := queue[head]
		head += 1
		var cell := Vector2i(node.x, node.y)
		var span: Array = columns[cell * 2 + Vector2i.ONE][node.z]
		var owner: int = span[2]
		if owner >= 0:
			if not covered.has(owner):
				covered[owner] = {}
			covered[owner][cell] = Vector2(span[1], span[0])
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			var spans := _spans(next * 2 + Vector2i.ONE, columns, solids, bounds, grid, headroom)
			# Point à mi-chemin : un mur mince tombe entre deux centres de case.
			var middle := _spans(cell * 2 + Vector2i.ONE + step, columns, solids, bounds, grid, headroom)
			for k in spans.size():
				var other: Array = spans[k]
				if not other[3] or absf(other[0] - span[0]) > rise or minf(other[1], span[1]) - maxf(other[0], span[0]) < headroom:
					continue
				if not _passes(middle, span, other, rise, headroom):
					continue
				var key := Vector3i(next.x, next.y, k)
				if not seen.has(key):
					seen[key] = true
					queue.append(key)
	return covered


## Espaces libres d'au moins `headroom` de haut à la verticale du point
## `fine` d'une grille de demi-cases (centre de la case c : 2c + 1 ; milieu
## entre deux cases : entre les deux), mis en cache dans `columns` : [[sol, plafond, brush du plafond]], de bas
## en haut ; plafond INF et brush -1 à ciel ouvert, brush -2 sous un mur
## invisible ; dernier élément : sol dessiné (le sol d'un vide caché, que
## personne ne voit, porte une texture technique). Le vide sous le brush le plus bas ne compte
## pas (pas de sol).
func _spans(fine: Vector2i, columns: Dictionary, solids: Array[Dictionary], bounds: Array[AABB], grid: Dictionary, headroom: float) -> Array:
	if columns.has(fine):
		return columns[fine]
	var at := Vector2(fine) * (ROOF_STEP * 0.5)
	var ranges := []
	for j: int in grid.get(Vector2i(floori(at.x / GRID_SIZE), floori(at.y / GRID_SIZE)), []):
		if solids[j]["kind"] == &"passable":
			continue
		var box := bounds[j]
		if at.x < box.position.x or at.x > box.end.x or at.y < box.position.y or at.y > box.end.y:
			continue
		var extent := _vertical_extent(solids[j], box, at)
		if extent.x < extent.y:
			ranges.append([extent.x, extent.y, j])
	ranges.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var spans := []
	var top := -INF
	var floor_owner := -1
	for part: Array in ranges:
		if top > -INF and part[0] - top >= headroom:
			# Un mur invisible au-dessus n'est pas un toit.
			var owner: int = part[2]
			if solids[owner]["kind"] != &"solid":
				owner = -2
			spans.append([top, part[0], owner, _top_visible(solids[floor_owner], at)])
		if part[1] > top:
			top = part[1]
			floor_owner = part[2]
	if top > -INF:
		spans.append([top, INF, -1, _top_visible(solids[floor_owner], at)])
	columns[fine] = spans
	return spans


## Vrai si l'un des espaces `middle` (point à mi-chemin) relie `span` à
## `other` : sol à moins de `rise` des deux, `headroom` libre au-dessus.
static func _passes(middle: Array, span: Array, other: Array, rise: float, headroom: float) -> bool:
	var floor_low := maxf(other[0], span[0])
	var ceiling: float = minf(other[1], span[1])
	for m: Array in middle:
		if absf(m[0] - span[0]) <= rise and absf(m[0] - other[0]) <= rise and minf(m[1], ceiling) - maxf(m[0], floor_low) >= headroom:
			return true
	return false


## Partie (z mini, z maxi) d'un brush traversée par la verticale du point
## `at` ; vide (x >= y) si elle ne le traverse pas.
static func _vertical_extent(solid: Dictionary, box: AABB, at: Vector2) -> Vector2:
	var low := box.position.z
	var high := box.end.z
	# Sans plans (morceau de mur invisible découpé) : un pavé.
	for plane: Plane in solid["planes"]:
		var rest := plane.d - plane.normal.x * at.x - plane.normal.y * at.y
		if absf(plane.normal.z) < 0.0001:
			if rest < -0.01:
				return Vector2.ZERO
		elif plane.normal.z > 0.0:
			high = minf(high, rest / plane.normal.z)
		else:
			low = maxf(low, rest / plane.normal.z)
	return Vector2(low, high)


## Vrai si la face du dessus d'un brush, à la verticale du point `at`, est
## dessinée.
func _top_visible(solid: Dictionary, at: Vector2) -> bool:
	var best: Dictionary = {}
	var high := INF
	for polygon: Dictionary in solid["polygons"]:
		if not polygon.has("face"):
			return false
		var plane: Plane = polygon["face"].plane
		if plane.normal.z < 0.0001:
			continue
		var z := (plane.d - plane.normal.x * at.x - plane.normal.y * at.y) / plane.normal.z
		if z < high:
			high = z
			best = polygon
	return not best.is_empty() and _is_visible(best["face"])


## Ajoute au toit `roof` ce qui repose sur lui, de proche en proche :
## au-dessus de son plafond, touchant une de ses pièces et sans en déborder
## de plus d'une case (pour ne pas emporter un terrain voisin plus haut).
func _add_riders(roof: int, members: Array, ceiling: float, solids: Array[Dictionary], bounds: Array[AABB], grid: Dictionary) -> void:
	var queue: Array = members.duplicate()
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var grown := bounds[i].grow(1.0)
		var room := bounds[i].grow(CRATE_SIZE)
		for j in _neighbours(grown, grid):
			if solids[j].has("roof") or solids[j]["kind"] == &"clip" or bounds[j].position.z < ceiling - CRATE_TOLERANCE:
				continue
			if not grown.intersects(bounds[j]):
				continue
			var box := bounds[j]
			if box.position.x < room.position.x or box.end.x > room.end.x or box.position.y < room.position.y or box.end.y > room.end.y:
				continue
			solids[j]["roof"] = roof
			queue.append(j)


## Cases couvertes (`cells` : {case: Vector2(z plafond, z sol)}) →
## rectangles du monde (x, z) avec la hauteur du sol et du plafond de chacun,
## en regroupant les cases voisines d'une même rangée aux mêmes hauteurs.
func _cells_to_areas(cells: Dictionary, areas: Array[Rect2], floors: Array[float], ceilings: Array[float]) -> void:
	var sorted: Array = cells.keys()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var k := 0
	while k < sorted.size():
		var first: Vector2i = sorted[k]
		var heights: Vector2 = cells[first]
		var last := first
		while k + 1 < sorted.size() and sorted[k + 1] == last + Vector2i.RIGHT and cells[sorted[k + 1]].is_equal_approx(heights):
			k += 1
			last = sorted[k]
		k += 1
		var low := to_world(Vector3(first.x * ROOF_STEP, first.y * ROOF_STEP, heights.x))
		var high := to_world(Vector3((last.x + 1) * ROOF_STEP, (last.y + 1) * ROOF_STEP, heights.x))
		areas.append(Rect2(minf(low.x, high.x), minf(low.z, high.z), absf(high.x - low.x), absf(high.z - low.z)))
		floors.append(to_world(Vector3(0, 0, heights.y)).y)
		ceilings.append(low.y)


## Grille des brushes par case de `GRID_SIZE` (emprise au sol).
static func _grid(bounds: Array[AABB]) -> Dictionary:
	var grid := {}
	for i in bounds.size():
		var box := bounds[i]
		for gx in range(floori(box.position.x / GRID_SIZE), floori(box.end.x / GRID_SIZE) + 1):
			for gy in range(floori(box.position.y / GRID_SIZE), floori(box.end.y / GRID_SIZE) + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(i)
	return grid


## Brushes de la grille dont la case touche l'emprise de `box`.
static func _neighbours(box: AABB, grid: Dictionary) -> Array[int]:
	var found := {}
	for gx in range(floori(box.position.x / GRID_SIZE), floori(box.end.x / GRID_SIZE) + 1):
		for gy in range(floori(box.position.y / GRID_SIZE), floori(box.end.y / GRID_SIZE) + 1):
			for j: int in grid.get(Vector2i(gx, gy), []):
				found[j] = true
	var result: Array[int] = []
	result.assign(found.keys())
	return result


static func _find(parent: Dictionary, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


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
	var patrollers: Array[Enemy] = []
	for start in _spread_starts(map.find_entities("info_alien_start"), map.find_entities("info_player_start")):
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.name = "Sentry%d" % (count + 1)
		enemy.stationary = true
		enemy.position = parent.to_local(_feet(start))
		enemy.rotation.y = yaw_to_world(start.angle())
		parent.add_child(enemy)
		# Une sentinelle sur deux (selon `patrol_ratio`), en alternance.
		if floorf((count + 1) * patrol_ratio) > floorf(count * patrol_ratio):
			patrollers.append(enemy)
		count += 1
	var level := _level_root()
	if level and not patrollers.is_empty():
		level.level_ready.connect(_plan_patrols.bind(patrollers), CONNECT_ONE_SHOT)


func _level_root() -> LevelRoot:
	var node := get_parent()
	while node and not node is LevelRoot:
		node = node.get_parent()
	return node as LevelRoot


## Trace la ronde de chaque sentinelle de `patrollers` (`patrol_route`).
func _plan_patrols(patrollers: Array[Enemy]) -> void:
	for enemy in patrollers:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var route := patrol_route(enemy.get_world_3d().navigation_map, enemy.global_position, -enemy.global_basis.z)
		if route.size() > 1:
			enemy.set_patrol(route)


## Longueur (m) visée pour chaque branche d'une ronde, et détour toléré.
const PATROL_REACH: Array[float] = [12.0, 9.0, 6.0]
const PATROL_MIN_LEG := 4.0
const PATROL_DETOUR := 1.7
const PATROL_DIRECTIONS := 12

## Ronde autour du poste `post` : deux points atteignables, de part et
## d'autre (le premier du côté où regarde la sentinelle, `facing`), au même
## étage, par des chemins sans grand détour. La sentinelle revient à son
## poste entre les deux : [poste, A, poste, B]. Un seul point trouvé : un
## aller-retour. Vide si rien ne convient (elle reste fixe).
static func patrol_route(nav_map: RID, post: Vector3, facing: Vector3) -> Array[Vector3]:
	var start := NavigationServer3D.map_get_closest_point(nav_map, post)
	var base := atan2(facing.x, facing.z)
	var found: Array[Vector3] = []
	var found_dirs: Array[Vector3] = []
	for reach in PATROL_REACH:
		for k in PATROL_DIRECTIONS:
			# Directions de plus en plus écartées de celle du regard.
			var step := (k + 1) / 2
			var angle := base + (TAU / PATROL_DIRECTIONS) * step * (1.0 if k % 2 == 0 else -1.0)
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			if found_dirs.any(func(other: Vector3) -> bool: return other.dot(dir) > -0.2):
				continue
			var point := _patrol_point(nav_map, start, dir, reach)
			if point != Vector3.INF:
				found.append(point)
				found_dirs.append(dir)
			if found.size() == 2:
				return [start, found[0], start, found[1]] as Array[Vector3]
	if found.size() == 1:
		return [start, found[0]] as Array[Vector3]
	return [] as Array[Vector3]


## Point atteignable à environ `reach` m de `start` dans la direction `dir`,
## ou `Vector3.INF`.
static func _patrol_point(nav_map: RID, start: Vector3, dir: Vector3, reach: float) -> Vector3:
	var point := NavigationServer3D.map_get_closest_point(nav_map, start + dir * reach)
	var offset := point - start
	if absf(offset.y) > 0.6 or Vector2(offset.x, offset.z).length() < PATROL_MIN_LEG:
		return Vector3.INF
	var path := NavigationServer3D.map_get_path(nav_map, start, point, true)
	if path.is_empty() or path[path.size() - 1].distance_to(point) > 0.5:
		return Vector3.INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	if length > Vector2(offset.x, offset.z).length() * PATROL_DETOUR + 1.0:
		return Vector3.INF
	return point


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


## Clé du cache des toits : carte (chemin, date, taille), nombre de brushes
## et version du repérage.
static func _roof_cache_key(path: String, solid_count: int) -> String:
	var size := 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		size = file.get_length()
	return "%d|%s|%d|%d|%d" % [ROOF_CACHE_VERSION, path, FileAccess.get_modified_time(path), size, solid_count]


static func _roof_cache_file(key: String) -> String:
	return roof_cache_dir.path_join("%s.bin" % key.md5_text())


## Relit le repérage des toits en cache. Faux s'il n'y est pas.
func _load_roof_cache(key: String, solids: Array[Dictionary]) -> bool:
	var file := FileAccess.open(_roof_cache_file(key), FileAccess.READ)
	if file == null:
		return false
	var data: Variant = file.get_var()
	if not (data is Dictionary) or data.get("key") != key:
		return false
	var marks: PackedInt32Array = data["marks"]
	if marks.size() != solids.size():
		return false
	_roofs.clear()
	for entry: Dictionary in data["roofs"]:
		var areas: Array[Rect2] = []
		areas.assign(entry["areas"])
		var floors: Array[float] = []
		floors.assign(entry["floors"])
		var ceilings: Array[float] = []
		ceilings.assign(entry["ceilings"])
		_roofs.append({"areas": areas, "floors": floors, "ceilings": ceilings, "ceiling": entry["ceiling"]})
	for i in solids.size():
		if marks[i] >= 0:
			solids[i]["roof"] = marks[i]
	return true


func _save_roof_cache(key: String, solids: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(roof_cache_dir)
	var file := FileAccess.open(_roof_cache_file(key), FileAccess.WRITE)
	if file == null:
		return
	var marks := PackedInt32Array()
	for solid in solids:
		marks.append(solid.get("roof", -1))
	var roofs: Array = []
	for roof in _roofs:
		roofs.append({"areas": Array(roof["areas"]), "floors": Array(roof["floors"]), "ceilings": Array(roof["ceilings"]), "ceiling": roof["ceiling"]})
	file.store_var({"key": key, "marks": marks, "roofs": roofs})
