@tool
extends RefCounted
## Scénario du point 8.2 d : chemins par une corde de grappin. Sur le
## Terrain d'essai, une extraction sur le toit d'un bâtiment sans échelle
## (corde possible) et une cible sur le toit d'un bâtiment aux murs de
## 10 m (trop haut pour une corde). Écrit les lancers trouvés dans
## `ropes_<carte>.json`, pour l'essai en jeu.

const Palette := preload("res://addons/mission_editor/palette.gd")


static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var building: Node3D = plugin.place("building", Vector3(18, 0, -18), 0.0)[0]
	# Murs de 10 m : réglés avant la construction (dans `_ready`).
	var tower: Node3D = Palette.make("building", Vector3(-20, 0, -21), 0.0, Vector3.INF, root)[0]
	tower.set("wall_height", 10.0)
	root.get_node("NavigationRegion3D").add_child(tower, true)
	tower.owner = root
	for k in 5:
		await tree.process_frame
	var roof := _roof(root, Vector3(18, 0, -18))
	var tower_roof := _roof(root, Vector3(-20, 0, -21))
	print("TEST bâtiment %s, toit à %.2f m ; haut bâtiment %s, toit à %.2f m" % [building.name, roof, tower.name, tower_roof])
	var zone: Node3D = plugin.place("extraction", Vector3(18, roof, -18), 0.0)[0]
	var generator: Node3D = plugin.place("generator", Vector3(-20, tower_roof, -21), 0.0)[0]
	print("TEST extraction %s en %s, groupe %s en %s" % [zone.name, zone.position, generator.name, generator.position])
	var started := Time.get_ticks_msec()
	var report: Array = await plugin.check()
	print("TEST vérification en %d ms :" % (Time.get_ticks_msec() - started))
	for item: Dictionary in report:
		print("TEST   [%s] %s" % [item["level"], item["text"]])
	EditorInterface.save_scene()
	for k in 5:
		await tree.process_frame
	print("TEST enregistrée")


## Hauteur du dessus visé en `at` (rayon vertical contre le sol et le décor).
static func _roof(root: Node, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40.0, at + Vector3.DOWN, 0b11)
	var hit := (root as Node3D).get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0
