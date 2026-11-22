@tool
extends EditorPlugin
## Greffon « Éditeur de mission » (voir MISSION_EDITOR.md).
##
## - Aperçu des textures externes sur la scène ouverte, retirées le temps de
##   chaque enregistrement (`TexturePreview`).
## - Dock « Mission » : réglages de la carte (nuit, tenue de rigueur), grille,
##   palette des éléments à poser, avertissement sur les cartes générées.
## - Pose au clic dans la vue 3D, sur le sol (plan y = 0), avec annulation.

const TexturePreview := preload("res://addons/mission_editor/texture_preview.gd")
const Dock := preload("res://addons/mission_editor/dock.gd")
const Palette := preload("res://addons/mission_editor/palette.gd")

## Pas de la grille magnétique (m) et de la rotation (degrés).
const GRID_STEP := 0.5
const ROTATION_STEP := 15.0
## Raccourcis du greffon (Éditeur > Paramètres de l'éditeur > Raccourcis).
const SHORTCUTS := {
	"mission_editor/rotate_right": {"key": KEY_R, "shift": false, "label": "Tourner de 15° (sens horaire)"},
	"mission_editor/rotate_left": {"key": KEY_R, "shift": true, "label": "Tourner de 15° (sens inverse)"},
	"mission_editor/cancel": {"key": KEY_ESCAPE, "shift": false, "label": "Arrêter la pose"},
}
## Éclairage selon le moment : fond, lumière ambiante, soleil ou lune
## (mêmes valeurs que `tools/mapkit.py`).
const LIGHTING := {
	false: {"background_color": Color(0.55, 0.62, 0.7), "ambient_light_color": Color(0.66, 0.66, 0.64), "ambient_light_energy": 0.65,
		"light_color": Color(1, 0.96, 0.9), "light_energy": 1.1},
	true: {"background_color": Color(0.01, 0.015, 0.03), "ambient_light_color": Color(0.2, 0.25, 0.4), "ambient_light_energy": 0.22,
		"light_color": Color(0.6, 0.7, 1), "light_energy": 0.16},
}

var _textures := TexturePreview.new()
var _dock: Control
## Outil de la palette en cours (vide : aucun), cap de pose (degrés, 0 =
## nord), point visé au sol et début d'un tracé (INF : aucun).
var _tool: String = ""
var _facing: float = 0.0
var _point: Vector3 = Vector3.INF
var _start: Vector3 = Vector3.INF
var _camera: Camera3D


## Nom de la métadonnée du moteur qui désigne le greffon (scénarios de
## vérification).
const META := &"mission_editor"


func _enter_tree() -> void:
	Engine.set_meta(META, self)
	_register_shortcuts()
	_dock = Dock.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.tool_selected.connect(_on_tool_selected)
	_dock.night_toggled.connect(_on_night_toggled)
	_dock.dress_code_selected.connect(_on_dress_code_selected)
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	# Annulation d'un réglage de la carte : le dock suit.
	get_undo_redo().version_changed.connect(_refresh_dock)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	_on_scene_changed.call_deferred(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	Engine.remove_meta(META)
	scene_changed.disconnect(_on_scene_changed)
	scene_saved.disconnect(_on_scene_saved)
	get_undo_redo().version_changed.disconnect(_refresh_dock)
	_textures.revert()
	remove_control_from_docks(_dock)
	_dock.queue_free()


# --- Textures ---------------------------------------------------------------

## Avant tout enregistrement (et changement d'onglet, perte du focus…),
## les textures quittent les matériaux ; elles reviennent juste après,
## une fois l'enregistrement fait.
func _apply_changes() -> void:
	_textures.revert()
	_reapply.call_deferred()


func _save_external_data() -> void:
	_textures.revert()
	_reapply.call_deferred()


func _refresh_textures() -> void:
	_textures.revert()
	_reapply()


func _reapply() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root is LevelRoot:
		_textures.apply(root)


func _on_scene_saved(path: String) -> void:
	_reapply.call_deferred()
	# Un fichier de mission enregistré : le catalogue du jeu le relira.
	LevelCatalog.reload()


func _on_scene_changed(root: Node) -> void:
	_textures.revert()
	_cancel_tool()
	_dock.show_scene(root, generator_of(root))
	if root is LevelRoot:
		_textures.apply(root)


func _refresh_dock() -> void:
	var root := EditorInterface.get_edited_scene_root()
	_dock.show_scene(root, generator_of(root))


## Script qui génère la carte `root` (`tools/gen_<dossier>.py`), ou vide.
static func generator_of(root: Node) -> String:
	if root == null or root.scene_file_path.is_empty():
		return ""
	var folder := root.scene_file_path.get_base_dir().get_file()
	var path := "res://tools/gen_%s.py" % folder
	return path.trim_prefix("res://") if FileAccess.file_exists(path) else ""


# --- Réglages de la carte ---------------------------------------------------

func _on_night_toggled(night: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot:
		return
	var undo := get_undo_redo()
	undo.create_action("Carte de nuit" if night else "Carte de jour")
	undo.add_do_property(root, &"night", night)
	undo.add_undo_property(root, &"night", root.get("night"))
	var preset: Dictionary = LIGHTING[night]
	var environment := root.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if environment and environment.environment:
		for key: String in ["background_color", "ambient_light_color", "ambient_light_energy"]:
			undo.add_do_property(environment.environment, key, preset[key])
			undo.add_undo_property(environment.environment, key, environment.environment.get(key))
	for light_name: String in ["Sun", "Moon"]:
		var light := root.get_node_or_null(NodePath(light_name)) as DirectionalLight3D
		if light:
			for key: String in ["light_color", "light_energy"]:
				undo.add_do_property(light, key, preset[key])
				undo.add_undo_property(light, key, light.get(key))
	undo.commit_action()


func _on_dress_code_selected(code: StringName) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot:
		return
	var undo := get_undo_redo()
	undo.create_action("Tenue de rigueur")
	undo.add_do_property(root, &"dress_code", code)
	undo.add_undo_property(root, &"dress_code", root.get("dress_code"))
	undo.commit_action()


# --- Pose -------------------------------------------------------------------

func _on_tool_selected(id: String) -> void:
	_tool = id
	_start = Vector3.INF
	_update_status()
	update_overlays()


func _cancel_tool() -> void:
	_tool = ""
	_start = Vector3.INF
	_point = Vector3.INF
	if _dock:
		_dock.clear_tool()
		_update_status()
	update_overlays()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _tool.is_empty() or not EditorInterface.get_edited_scene_root() is LevelRoot:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_camera = camera
	var settings := EditorInterface.get_editor_settings()
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if settings.is_shortcut("mission_editor/cancel", event):
			_cancel_tool()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if settings.is_shortcut("mission_editor/rotate_right", event):
			_facing = fposmod(_facing + ROTATION_STEP, 360.0)
		elif settings.is_shortcut("mission_editor/rotate_left", event):
			_facing = fposmod(_facing - ROTATION_STEP, 360.0)
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_update_status()
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		_point = ground_point(camera, (event as InputEventMouseMotion).position, _dock.grid_enabled())
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.is_pressed():
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_tool()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if button.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_point = ground_point(camera, button.position, _dock.grid_enabled())
		if _point == Vector3.INF:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		var entry := Palette.find(_tool)
		if entry.get("tool") == "line" and _start == Vector3.INF:
			_start = _point
		elif entry.get("tool") == "line":
			if _start.distance_to(_point) > 0.2:
				place(_tool, _start, _facing, _point)
			_start = Vector3.INF
		else:
			place(_tool, _point, _facing)
		_update_status()
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Point du sol (plan y = 0) sous la position `screen` de la vue `camera`,
## aimanté à la grille si `snap` ; INF si le rayon ne touche pas le sol.
static func ground_point(camera: Camera3D, screen: Vector2, snap: bool) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return Vector3.INF
	var point: Vector3 = hit
	if snap:
		point = Vector3(snappedf(point.x, GRID_STEP), 0.0, snappedf(point.z, GRID_STEP))
	return point


## Pose l'élément `id` de la palette (voir `Palette.make`), en une action
## annulable. Renvoie les nœuds posés.
func place(id: String, at: Vector3, facing: float, to: Vector3 = Vector3.INF) -> Array[Node3D]:
	var root := EditorInterface.get_edited_scene_root()
	var entry := Palette.find(id)
	if root == null or entry.is_empty():
		return []
	var nodes := Palette.make(id, at, facing, to, root)
	if nodes.is_empty():
		return nodes
	var undo := get_undo_redo()
	undo.create_action("Poser : %s" % entry["label"])
	var parent := _parent_for(root, entry["parent"], undo)
	for node in nodes:
		# Nœuds à enregistrer : le nœud et ses enfants créés par la palette,
		# relevés avant l'entrée dans l'arbre (les enfants qu'un script
		# construit en aperçu ne doivent pas l'être) ; d'une scène instanciée,
		# la racine seule.
		var owned: Array[Node] = [node]
		if node.scene_file_path.is_empty():
			owned.append_array(node.find_children("*", "", true, false))
		undo.add_do_method(parent, &"add_child", node, true)
		for item in owned:
			undo.add_do_property(item, &"owner", root)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, &"remove_child", node)
	undo.commit_action()
	_select(nodes)
	# Textures externes sur les nouveaux éléments aussi.
	_refresh_textures.call_deferred()
	return nodes


## Parent `path` (relatif à la racine) ; créé dans l'action `undo` s'il
## manque (`Decor`, `Lamps`…).
func _parent_for(root: Node, path: String, undo: EditorUndoRedoManager) -> Node:
	var parent := root.get_node_or_null(NodePath(path))
	if parent:
		return parent
	var created := Node3D.new()
	created.name = path.get_file()
	var holder := root.get_node_or_null(NodePath(path.get_base_dir())) if path.contains("/") else root
	undo.add_do_method(holder, &"add_child", created, true)
	undo.add_do_property(created, &"owner", root)
	undo.add_do_reference(created)
	undo.add_undo_method(holder, &"remove_child", created)
	return created


func _select(nodes: Array[Node3D]) -> void:
	var selection := EditorInterface.get_selection()
	selection.clear()
	for node in nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			selection.add_node(node)


func _update_status() -> void:
	if _dock == null:
		return
	if _tool.is_empty():
		_dock.set_status("")
		return
	var entry := Palette.find(_tool)
	var text := "%s — cap %d°" % [entry.get("label", _tool), int(_facing)]
	if entry.get("tool") == "line":
		text += " — cliquez la fin du tracé" if _start != Vector3.INF else " — cliquez le début du tracé"
	_dock.set_status(text)


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if _tool.is_empty() or _camera == null or _point == Vector3.INF:
		return
	if _camera.is_position_behind(_point):
		return
	var color := Color(0.4, 1.0, 0.5)
	var at := _camera.unproject_position(_point)
	overlay.draw_arc(at, 10.0, 0.0, TAU, 24, color, 2.0)
	if _start != Vector3.INF and not _camera.is_position_behind(_start):
		var from := _camera.unproject_position(_start)
		overlay.draw_line(from, at, color, 2.0)
		overlay.draw_string(overlay.get_theme_default_font(), (from + at) * 0.5 + Vector2(6, -6), "%.1f m" % _start.distance_to(_point),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	elif Palette.find(_tool).get("tool") == "point":
		var radians := deg_to_rad(_facing)
		var ahead := _point + Vector3(sin(radians), 0.0, -cos(radians)) * 2.0
		if not _camera.is_position_behind(ahead):
			overlay.draw_line(at, _camera.unproject_position(ahead), color, 2.0)


func _register_shortcuts() -> void:
	var settings := EditorInterface.get_editor_settings()
	for path: String in SHORTCUTS:
		if settings.has_shortcut(path):
			continue
		var spec: Dictionary = SHORTCUTS[path]
		var key := InputEventKey.new()
		key.physical_keycode = spec["key"]
		key.shift_pressed = spec["shift"]
		var shortcut := Shortcut.new()
		shortcut.resource_name = spec["label"]
		shortcut.events = [key]
		settings.add_shortcut(path, shortcut)
