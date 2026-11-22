@tool
extends RefCounted
## Scénario du point 8.2 b : contrôles de placement. Pose sur le Terrain
## d'essai des fautes voulues et affiche le rapport de « Vérifier ».

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var alpha := root.get_node("Units/Alpha") as Node3D
	var bounds: AABB = root.get_node("CameraRig").get("bounds")
	print("TEST Alpha en %s, limites de la caméra %s" % [alpha.global_position, bounds])
	print("TEST rapport avant :")
	for item: Dictionary in await plugin.check():
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	# Limites de la caméra resserrées, pour un élément sur le terrain mais
	# hors de vue.
	bounds = AABB(Vector3(-12, 0, -12), Vector3(24, 0, 24))
	root.get_node("CameraRig").set("bounds", bounds)
	var far := bounds.end.x + 14.0
	# Garde dans un mur ; caisses l'une dans l'autre ; opérateur sur Alpha ;
	# garde qui regarde Alpha à 6 m ; garde hors du terrain ; garde loin des
	# limites de la caméra.
	var wall: Node3D = plugin.place("wall", Vector3(20, 0, -20), 0.0)[0]
	var walled: Node3D = plugin.place("guard", Vector3(20, 0, -20), 0.0)[0]
	plugin.place("crate", Vector3(25, 0, 25), 0.0)
	plugin.place("crate", Vector3(25.3, 0, 25.2), 0.0)
	plugin.place("operator", alpha.global_position + Vector3(0.3, 0, 0), 0.0)
	var watcher: Node3D = plugin.place("guard", alpha.global_position + Vector3(0, 0, -6), 180.0)[0]
	plugin.place("guard", Vector3(80, 0, 0), 0.0)
	plugin.place("guard", Vector3(far, 0, -6), 0.0)
	# Rondes : un point en l'air ; un point dans un enclos fermé.
	plugin.place("patrol", Vector3(-20, 0, 25), 0.0, Vector3.INF, PackedVector3Array([Vector3(-20, 0, 25), Vector3(-14, 0, 25), Vector3(-14, 6, 20)]))
	for side: Array in [[Vector3(-31, 0, -31), Vector3(-25, 0, -31)], [Vector3(-25, 0, -31), Vector3(-25, 0, -25)], [Vector3(-25, 0, -25), Vector3(-31, 0, -25)], [Vector3(-31, 0, -25), Vector3(-31, 0, -31)]]:
		plugin.place("wall_line", side[0], 0.0, side[1])
	plugin.place("patrol", Vector3(-20, 0, -28), 0.0, Vector3.INF, PackedVector3Array([Vector3(-20, 0, -28), Vector3(-28, 0, -28)]))
	print("TEST poses : mur %s, garde muré %s, guetteur %s, enclos à (-28, -28)" % [wall.name, walled.name, watcher.name])
	for k in 3:
		await tree.physics_frame
	print("TEST rapport après :")
	for item: Dictionary in await plugin.check():
		print("TEST   [%s] %s → %s" % [item["level"], item["text"], (item["nodes"] as Array).map(func(n: Node) -> String: return String(n.name) if n else "?")])
