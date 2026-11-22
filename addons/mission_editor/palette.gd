@tool
extends RefCounted
## Éléments que le greffon pose sur une carte, rangés par catégorie, comme
## `tools/mapkit.py` (`MapBuilder`) les écrit : nœud, script ou scène,
## parent (`NavigationRegion3D` pour ce qui découpe la navigation, `Decor`
## pour le reste…) et réglages par défaut.
##
## Une entrée : {"id", "label", "category", "parent", "tool"} où `tool` vaut
## "point" (un clic) ou "line" (deux clics : début et fin).

const CATEGORIES: Array[String] = ["Décor", "Équipe", "Ennemis", "Civils", "Objectifs", "Extraction et véhicules"]

## Revêtements posés à la ligne : couleur, hauteur, largeur par défaut.
const SURFACES := {
	"road": {"color": Color(0.19, 0.19, 0.2), "y": 0.016, "width": 9.0},
	"sidewalk": {"color": Color(0.55, 0.54, 0.5), "y": 0.008, "width": 2.5},
	"track": {"color": Color(0.5, 0.42, 0.3), "y": 0.01, "width": 4.5},
}

const WALL_LENGTH := 6.0


## Toutes les entrées, dans l'ordre d'affichage.
static func entries() -> Array[Dictionary]:
	return [
		{"id": "building", "label": "Bâtiment", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "wall_line", "label": "Mur (tracé)", "category": "Décor", "parent": "NavigationRegion3D", "tool": "line"},
		{"id": "wall", "label": "Mur de 6 m", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "low_wall", "label": "Muret", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "crate", "label": "Caisse", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "bush", "label": "Haie / buisson", "category": "Décor", "parent": "Decor", "tool": "point"},
		{"id": "lamp", "label": "Lampadaire", "category": "Décor", "parent": "Lamps", "tool": "point"},
		{"id": "ladder", "label": "Échelle", "category": "Décor", "parent": "NavigationRegion3D", "tool": "point"},
		{"id": "road", "label": "Route", "category": "Décor", "parent": "Decor", "tool": "line"},
		{"id": "sidewalk", "label": "Trottoir", "category": "Décor", "parent": "Decor", "tool": "line"},
		{"id": "track", "label": "Piste", "category": "Décor", "parent": "Decor", "tool": "line"},
	]


static func find(id: String) -> Dictionary:
	for entry in entries():
		if entry["id"] == id:
			return entry
	return {}


## Nœuds à poser pour `id`, au point `at` (sol), cap `facing` (degrés, 0 =
## nord), ou de `at` à `to` pour un outil « ligne ». Les nœuds ne sont pas
## encore dans l'arbre ; `scene_root` sert à retrouver les ressources déjà
## présentes (maillages des revêtements).
static func make(id: String, at: Vector3, facing: float, to: Vector3, scene_root: Node) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	match id:
		"building":
			var building := Node3D.new()
			building.set_script(load("res://scripts/props/building.gd"))
			building.name = "Building"
			building.set("size", Vector2(8, 6))
			building.set("doors", [Vector3(0, 0, 0)] as Array[Vector3])
			nodes.append(building)
		"wall":
			nodes.append(_instance("res://scenes/props/wall.tscn", "Wall"))
		"low_wall":
			nodes.append(_instance("res://scenes/props/low_wall.tscn", "LowWall"))
		"crate":
			nodes.append(_instance("res://scenes/props/crate.tscn", "Crate"))
		"ladder":
			nodes.append(_instance("res://scenes/props/ladder.tscn", "Ladder"))
		"bush":
			var bush := Node3D.new()
			bush.set_script(load("res://scripts/props/hiding_spot.gd"))
			bush.name = "Bush"
			bush.set("size", Vector2(3, 2.4))
			nodes.append(bush)
		"lamp":
			nodes.append(_lamp())
		"wall_line":
			var length := at.distance_to(to)
			var count := maxi(1, ceili(length / WALL_LENGTH))
			var yaw := _yaw(at, to) - PI / 2.0
			for i in count:
				var wall := _instance("res://scenes/props/wall.tscn", "Wall")
				wall.transform = Transform3D(Basis(Vector3.UP, yaw), at.lerp(to, (i + 0.5) / count))
				nodes.append(wall)
			return nodes
		"road", "sidewalk", "track":
			nodes.append(_surface(id, at, to, scene_root))
			return nodes
	for node in nodes:
		node.transform = Transform3D(Basis(Vector3.UP, -deg_to_rad(facing)), at)
	return nodes


## Cap (radians, rotation autour de Y) pour regarder de `a` vers `b`.
static func _yaw(a: Vector3, b: Vector3) -> float:
	return atan2(-(b.x - a.x), -(b.z - a.z))


static func _instance(path: String, base_name: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = base_name
	return node


static func _lamp() -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	var post := MeshInstance3D.new()
	post.name = "Post"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.09
	cylinder.height = 4.0
	cylinder.radial_segments = 8
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.23, 0.24)
	steel.metallic = 0.6
	steel.roughness = 0.5
	cylinder.material = steel
	post.mesh = cylinder
	post.position.y = 2.0
	lamp.add_child(post)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.85, 0.55)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.8, 0.5)
	glow.emission_energy_multiplier = 3.0
	sphere.material = glow
	bulb.mesh = sphere
	bulb.position.y = 4.05
	lamp.add_child(bulb)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1, 0.8, 0.52)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.omni_attenuation = 1.4
	light.position.y = 3.9
	lamp.add_child(light)
	return lamp


## Bande de revêtement `kind` de `a` à `b`, prolongée d'une demi-largeur à
## chaque bout (les virages se recouvrent), comme `MapBuilder.track`.
static func _surface(kind: String, a: Vector3, b: Vector3, scene_root: Node) -> Node3D:
	var spec: Dictionary = SURFACES[kind]
	var width: float = spec["width"]
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := maxf(along.length(), 0.1)
	var dir := along / length
	var start := a - dir * width * 0.5
	var stop := b + dir * width * 0.5
	var node := MeshInstance3D.new()
	node.name = "Track"
	node.mesh = _surface_mesh(kind, scene_root)
	var side := Vector3(dir.z, 0.0, -dir.x) * width
	node.transform = Transform3D(Basis(side, Vector3.UP, stop - start), (start + stop) * 0.5 + Vector3.UP * float(spec["y"]))
	return node


## Maillage unité du revêtement `kind` : celui que la carte utilise déjà
## (même nom de ressource), sinon un nouveau.
static func _surface_mesh(kind: String, scene_root: Node) -> Mesh:
	var resource_name := "surface_" + kind
	if scene_root:
		for node in scene_root.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			if mesh and mesh.resource_name == resource_name:
				return mesh
	var box := BoxMesh.new()
	box.resource_name = resource_name
	box.size = Vector3(1, 0.02, 1)
	var material := StandardMaterial3D.new()
	material.albedo_color = SURFACES[kind]["color"]
	material.roughness = 1.0
	box.material = material
	return box
