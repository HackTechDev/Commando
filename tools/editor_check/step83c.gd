@tool
extends RefCounted
## Scénario du point 8.3 c : fenêtre « Vue du jeu ». Capture la vue de
## départ (`editor_83c_<carte>.png`, à comparer avec le jeu lancé) et
## vérifie zoom, rotation et déplacement dans les limites.

static func run(tree: SceneTree, out: String) -> void:
	var plugin = Engine.get_meta(&"mission_editor")
	var root := EditorInterface.get_edited_scene_root()
	var view: Window = plugin.show_game_view()
	# Contenu au format du jeu (16:9) sous la barre d'outils.
	view.size = Vector2i(1280, 720 + 40)
	for k in 10:
		await RenderingServer.frame_post_draw
	var viewport: SubViewport = view.get("_viewport")
	var camera: Camera3D = view.get("_camera")
	var rig := root.get_node("CameraRig") as Node3D
	print("TEST fenêtre visible %s, rendu %s, caméra %s, taille %.1f" % [view.visible, viewport.size, camera.global_position.snapped(Vector3.ONE * 0.01), camera.size])
	viewport.get_texture().get_image().save_png(out + "/editor_83c_%s.png" % root.name.to_lower())
	for k in 12:
		view.call("zoom_view", 1)
	print("TEST douze crans de dézoom : %.1f (max %s)" % [camera.size, rig.get("max_size")])
	for k in 20:
		view.call("zoom_view", -1)
	print("TEST vingt crans de zoom : %.1f (min %s)" % [camera.size, rig.get("min_size")])
	view.call("rotate_view", 45.0)
	print("TEST tourné : cap %.0f°" % view.get("_yaw"))
	view.call("pan_view", Vector3(500, 0, -500))
	print("TEST déplacé très loin : centre %s, limites %s" % [view.get("_pivot"), rig.get("bounds")])
	view.call("reset_view")
	print("TEST départ : centre %s, cap %.0f°, taille %.1f" % [view.get("_pivot"), view.get("_yaw"), camera.size])
	# Autre scène : la fenêtre la suit.
	EditorInterface.open_scene_from_path("res://scenes/levels/night/night.tscn")
	for k in 10:
		await tree.process_frame
	print("TEST autre scène (%s) : fenêtre visible %s, centre %s" % [EditorInterface.get_edited_scene_root().name, view.visible, view.get("_pivot")])
